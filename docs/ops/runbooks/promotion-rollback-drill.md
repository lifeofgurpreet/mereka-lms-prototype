---
title: Promotion Rollback Drill (SLO ≤ 10 minutes)
type: runbook
owner: platform-release
observed_at: 2026-04-18
status: executable
---

# Promotion Rollback Drill (SLO ≤ 10 minutes)

> **Audience**: Platform operators doing a timed drill of the promotion rollback path.
> **Bead**: `mereka-lms-lb4c.5` (P3, child of S6 promotion reliability `mereka-lms-lb4c`).
> **Related**: Bead `infrastructure-nj48` (Argo silent-sync-stuck), `ArgoAppSelfHealStuck` runbook.
> **SLO**: From "bad commit noticed" to "cluster pods on prior digest" in ≤ 10 minutes.

## Purpose

This drill exercises the full promotion rollback path so operators know exactly how long revert takes under realistic conditions, and so we discover friction before a real incident forces us to learn it. It is an executable exercise, not a read-only doctrine.

## When to run

- Once per quarter minimum
- After any major change to the promotion conveyor (ApplicationSet, syncOption, retry topology)
- After onboarding a new platform-release owner

## Prerequisites

- `kubectl` access to the non-prod cluster context (`kubectl config use-context rke2-nonprod`)
- `gh` CLI authenticated with write on `Biji-Biji-Initiative/bbi-infrastructure`
- ArgoCD UI access or `argocd` CLI authenticated
- A stopwatch or scripted timer
- 30 minutes of uninterrupted focus (the 10-min SLO is for the rollback itself; the drill wraps diagnostic + evidence capture around it)

## Drill Target

- **Cluster**: `rke2-nonprod`
- **Namespace**: `mereka-lms-dev`
- **Argo Application**: `mereka-lms-dev`
- **Source repo**: `Biji-Biji-Initiative/bbi-infrastructure`
- **Path**: `apps/mereka-lms/overlays/profiles/dev`

The drill MUST run against dev, NEVER staging or production. Production has a manual `syncPolicy` per existing convention; drilling there would require operator-initiated sync anyway.

## Drill Procedure

### Phase 0 — Capture baseline (T-5 min, not counted toward SLO)

1. Record current promoted commit SHA:
   ```bash
   kubectl -n argocd get application mereka-lms-dev -o jsonpath='{.status.sync.revision}{"\n"}'
   ```
   Save as `BASELINE_SHA`.

2. Record current pod imageIDs:
   ```bash
   kubectl -n mereka-lms-dev get pods -o json | \
     jq -r '.items[] | select(.metadata.name|test("^(lms|cms|mfe|lms-worker|cms-worker)-")) |
            [.metadata.name, (.status.containerStatuses[0].imageID // "-")] | @tsv' \
     > /tmp/rollback-drill-baseline-pods.tsv
   ```

3. Start the stopwatch. Record `T_0` = current wall-clock.

### Phase 1 — Inject a "bad promotion" (T = 0–2 min)

1. In `bbi-infrastructure`, create a branch that reverts the most recent `chore(mereka-lms): promote dev images` merge. Merge it immediately to `main` via `gh pr merge --admin --squash`. **This is the "bad promotion" you're simulating.**

   Actually — simpler: just create an empty revert-PR that reverts ONE commit in `apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` to a 1-day-older image pin. Merge to main.

2. Record timestamp: `T_BAD_MERGE`.

### Phase 2 — Detect the regression (T = 2–4 min)

1. Watch Argo reconcile the "bad" change:
   ```bash
   watch -n 10 'kubectl -n argocd get application mereka-lms-dev \
     -o jsonpath="sync={.status.sync.status} health={.status.health.status} rev={.status.sync.revision}{\"\\n\"}"'
   ```

2. Confirm cluster pods moved to the older digest:
   ```bash
   bash scripts/qa/verify-pods-on-digest.sh \
     --namespace mereka-lms-dev \
     --selector app.kubernetes.io/name=cms-worker \
     --digest <baseline-digest>
   # Expected: FAIL (pods on the bad/older digest)
   ```

3. Record `T_DETECTED`.

### Phase 3 — Execute rollback (T = 4–8 min)

1. Revert the bad merge on `bbi-infrastructure`:
   ```bash
   gh pr create --base main --head <revert-branch> --title "revert: drill rollback" --body "Rollback drill per mereka-lms-lb4c.5"
   gh pr merge <num> --admin --squash
   ```

2. Wait for Argo to reconcile (may take 1–3 min; pay attention to the `ArgoAppSelfHealStuck` pattern — if autoHealAttemptsCount climbs without live spec change within 5 min, issue hard-refresh annotation):
   ```bash
   kubectl -n argocd annotate application mereka-lms-dev argocd.argoproj.io/refresh=hard --overwrite
   ```

3. Record `T_REVERT_MERGED` and `T_RECONCILE_STARTED`.

### Phase 4 — Confirm rollback landed (T = 8–10 min)

1. Confirm cluster pods are back on baseline digest:
   ```bash
   bash scripts/qa/verify-pods-on-digest.sh \
     --namespace mereka-lms-dev \
     --selector app.kubernetes.io/name=cms-worker \
     --digest ${BASELINE_DIGEST}
   # Expected: PASS
   ```

2. Confirm Argo `health=Healthy` and `sync.revision` matches the revert-merge commit.

3. Confirm product surfaces still 200 (minimum smoke):
   ```bash
   for url in apps.academyv2.mereka.dev/api/mfe_config/v1 apps.skillourfuture.academyv2.mereka.dev/api/mfe_config/v1; do
     echo "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 https://$url) https://$url"
   done
   ```

4. Record `T_COMPLETE`. Compute SLO: `T_COMPLETE - T_BAD_MERGE`.

### Phase 5 — Evidence capture (T+0, not counted toward SLO)

Write to `docs/ops/evidence/rollback-drill-<YYYY-MM-DD>.md`:

- Baseline SHA + digests
- Timing breakdown (T_BAD_MERGE → T_DETECTED → T_REVERT_MERGED → T_RECONCILE_STARTED → T_COMPLETE)
- Whether the SLO was met (≤ 10 min)
- Any friction or surprises encountered (e.g., hard-refresh needed? CI delay? secret rotation intervening?)
- One actionable follow-up to reduce time next drill

## SLO Classifications

| Time (T_COMPLETE - T_BAD_MERGE) | Grade | Meaning |
|---------------------------------|-------|---------|
| ≤ 10 min | PASS | Drill SLO met |
| 10–20 min | MARGINAL | Document friction points; file follow-ups |
| > 20 min | FAIL | File P1 bead to reduce rollback latency |
| Hard-refresh required | DEGRADED | Reference bead `infrastructure-nj48`; root cause still open |

## What this drill does NOT test

- Multi-tenant rollback (all 3 tenants share the same Deployment; reverting a single image reverts all)
- Staging or prod rollback (manual syncPolicy, different SLO)
- Data-plane rollback (DB migrations; separate runbook under `docs/ops/runbooks/db-rollback-*.md`)
- Secret rotation during rollback
- Registry unavailability
- GHCR rate limit at the moment of revert pull

## Next-drill evolution

Each run, enrich this runbook with one new edge case discovered during the drill. The point is to move the SLO class DOWN over time, not to prove it's always green.

## Closes

Bead `mereka-lms-lb4c.5` (P3, child of S6 promotion reliability `mereka-lms-lb4c`).
