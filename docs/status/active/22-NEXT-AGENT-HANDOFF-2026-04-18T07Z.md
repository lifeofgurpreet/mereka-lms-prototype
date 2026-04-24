---
title: Next Agent Handoff — Session Close 2026-04-18T~07Z
type: handoff
owner: operator-next
observed_at: 2026-04-18T07:00Z
supersedes: none
---

# Next Agent Handoff — Session Close 2026-04-18T~07Z

You are inheriting the Mereka LMS operator surface mid-sprint. Start here,
not at `21-NEW-AGENT-24H-KICKOFF-2026-04-18.md` — that kickoff reflects
state before this session's closures.

## Rule Zero: Don't Inherit Narrative

Use prior output as a lead, not as ground truth. Verify live state before
trusting any claim below. Commands to re-prove are in §6.

## 1. What's Closed This Session

### RC-05 — operationally closed, live-proven

- Source fix: `bbi-infrastructure#3202` merged 2026-04-18T06:01:02Z (`a1f7936b`)
- Local PID-1 probe (`/bin/sh -c 'ps -o comm= -p 1 | grep -qE celery|python'`) replaces broker-broadcast
- Live cluster proof: cms-worker + lms-worker Ready on new ReplicaSets created 06:16:03Z
- Argo `health=Healthy`, rev matches `bbi-infrastructure origin/main`
- Full evidence: `docs/status/active/evidence/rc02-102a56a07d/RC-05-LIVE-CLOSURE-EVIDENCE-2026-04-18.md` (`mereka-lms#1813` merged)

### RC-02 — reproducible from VPS

- Source fix: `mereka-lms#1806` (merged before this session)
- Verifier now prefers sibling `release-object-projection-schema.yaml` + `.sha256` in the evidence packet
- Live verification: `bash scripts/qa/verify-release-object.sh docs/status/active/evidence/rc02-102a56a07d/release-object.json` → PASS (no platform-control-plane checkout required)
- Negative tests verified: missing schema → exit 1 clean diagnostic; bad checksum → exit 1 clean mismatch

### S1–S5, S7 roadmap closures

| Node | PR | State | Notes |
|---|---|---|---|
| S1 preflight | `mereka-lms#1805` | open, CI running | `bin/preflight` script + runbook |
| S2 RC-02 | `mereka-lms#1806` | merged (pre-session) | |
| S3 RC-05 | `bbi-infrastructure#3202` | merged | |
| S4 parked-state split | `mereka-lms#1812` | open, CI re-running after rebase | `status_context: dev-runtime/e2e` vs `prod-parked-state/auth` |
| S5 workflow reclassify | `mereka-lms#1811` | merged | 3 misleading GKE-auth step names renamed |
| S7 stale overlay cleanup | `bbi-infrastructure#3203` | merged | |

## 2. What's Still Open

### Open PRs (all mine, all green or one CI-pending)

- `mereka-lms#1805` — Day-1 deliverables (S1 preflight + diagnoses). Currently `BEHIND` after rebase; CI re-running.
- `mereka-lms#1812` — S4 parked-state status context split. Currently `BEHIND` after rebase; CI re-running with my verification-catalog regen fix on latest commit.
- `mereka-lms#1808` — planning packet (draft, NOT closure-track).
- `bbi-infrastructure#3219` — files bead `infrastructure-nj48` for the Argo sync-stuck defect.

### Open defect follow-ups

1. **`infrastructure-nj48` (P2, bbi-infrastructure)** — Argo silent-sync-stuck on `mereka-lms-dev`. 15-min gap between RC-05 merge and actual spec apply. `autoHealAttemptsCount` reached 29 without error. Manual unblock: `kubectl -n argocd annotate application <name> argocd.argoproj.io/refresh=hard --overwrite`. Root cause is NOT known; hypothesis #1 (field-manager conflict on probe) was RETRACTED in the bead after investigator error was caught.
2. **Authn `SESSION_COOKIE_DOMAIN` console warning** — NOT REPRODUCED from static HTML or JS chunk analysis. Requires live browser session on `apps.academyv2.mereka.dev/authn/login` to prove or disprove definitively. Not a release blocker.

### Deferred roadmap nodes

- **S6 promotion reliability** — depends on S2+S3+S4. S2/S3 closed, S4 is in CI. Scope is outlined in §5 below.

## 3. Current Live Runtime State (captured 2026-04-18T06:26Z)

- Argo `mereka-lms-dev`: `sync=Synced health=Healthy` at `rev=5f84789c` (matches bbi-infrastructure origin/main)
- Deployments: lms 1/1, cms 1/1, mfe 1/1, lms-worker, cms-worker, caddy all Ready
- Product surfaces (200 on all):
  - Dev shared-mereka: `https://apps.academyv2.mereka.dev/api/mfe_config/v1`
  - Dev SOF: `https://apps.skillourfuture.academyv2.mereka.dev/api/mfe_config/v1`
  - Dev biji-biji: `https://apps.biji-biji.academyv2.mereka.dev/api/mfe_config/v1`
  - Prod biji-biji: `https://apps.academy.biji-biji.com/api/mfe_config/v1`
  - Dev Mereka theme: `https://apps.academyv2.mereka.dev/theme/core.min.css`
- 0 `ModuleNotFoundError`/`ImportError` in last 1000 LMS+CMS log lines

## 4. Env/Domain/Cluster Axes (verified)

- **Canonical SoT:** `config/active-surface-inventory.yaml` v1.5.0 (generated from `deploy/k8s/tenancy/tenant-registry.yaml`)
- **Dev** (`nonprod-rke2`, ns `mereka-lms-dev`): `*.academyv2.mereka.dev` (shared-mereka), `*.biji-biji.academyv2.mereka.dev`, `*.skillourfuture.academyv2.mereka.dev`. Also `*.mereka.dev` profiles-dev (separate surface, same ns).
- **Staging** (`nonprod-rke2`, ns `stg-mereka-lms`): `*.staging.academyv2.mereka.io` (shared-mereka), `*.staging.academy.biji-biji.com` (biji-biji), `*.staging.skillourfuture.academy.mereka.io` (SOF, 6 enumerated legacy + migration surfaces)
- **Production** (`rke2-prod`, ns `mereka-lms`):
  - Mereka: `*.academyv2.mereka.io`
  - Biji-Biji: `*.academy.biji-biji.com`
  - SOF: `skillourfuture.academy.mereka.io` (canonical) + migration targets `*.academyv2.mereka.io` (no DNS/TLS yet)

## 5. Top 5 Next Moves

### Move 1 — Merge pending PRs

`mereka-lms#1805`, `#1812`, `bbi-infrastructure#3219` are all green/CI-pending.
Merge them in order; each subsequent rebase is short (no conflicts expected).
After merge, re-run a live-spec check to confirm nothing regressed.

### Move 2 — Ship Argo autoHeal Prometheus alert + hard-refresh runbook

An implementor agent attempted this and may have opened a PR on
`bbi-infrastructure`. Confirm, review, land. If the agent didn't complete,
spec is:

- Alert: `ArgoAppSelfHealStuck` — fire when `autoHealAttemptsCount > 5` for `10m`
- Runbook: `docs/runbooks/argocd/argo-sync-stuck-recovery.md`
- Platform-wide value: prevents future silent-sync-stuck incidents from hiding

### Move 3 — Root-cause the Argo sync-stuck defect (bead `infrastructure-nj48`)

Hypothesis #1 (SSA probe-field conflict) is RETRACTED. Remaining hypotheses:
- Admission webhook (Kyverno mutating policies: `add-pvc-protection-to-critical-namespaces`, `inject-ghcr-imagepullsecret`) may use full-resource-replacement PatchType rather than JSONPatch
- ArgoCD comparison cache staleness (expiry=30s; but comparison_ms=4-8s per cycle seems fast enough)
- ArgoCD reposerver git cache (`reposerver.cache.expiration: 30m`)

Method:
- Reproduce by merging a probe-only change to a throwaway Deployment in a test app; watch ArgoCD logs + controller metrics; confirm the silent-sync-stuck pattern reproduces and narrow the trigger.
- Useful debug flags: `--show-managed-fields=true` on kubectl (default hides them since v1.21)

### Move 4 — Scope S6 promotion reliability as concrete work

S6 depends on S2+S3+S4. S2/S3 closed; S4 in CI. Once S4 merges:

**S6 proposed subtasks:**
1. **Audit promotion chain timing.** Instrument `promote-dev-image.yml` (and equivalent staging/prod) to emit per-step timestamps to `ci-metrics.mereka.dev`. Target: identify p50/p95 promotion latency from app-repo merge → bbi-infrastructure PR opened → Argo sync → live deploy. Currently opaque.
2. **Retry-lifetime for transient Trivy / Cosign failures.** Observed failing Trivy download and SBOM-generation transients during RC-05 window. No retry loop in the scan jobs. Add bounded retry with backoff, not infinite loops.
3. **Post-merge release-proof verifier in bbi-infrastructure.** After a `chore(mereka-lms): promote dev images` PR merges, auto-run `scripts/qa/verify-release-object.sh` on the newly-promoted bundle to confirm schema + checksum integrity. Surfaces RC-02-style drift before it reaches prod.
4. **Harden the silent-sync-stuck recovery path from moves 2+3 into the release contract.** Gate promotion-to-staging on "Argo has actually realized the desired image" (compare pod imageIDs to expected digest) rather than just Argo sync=Synced.
5. **Documented rollback drill.** Timed exercise where an operator reverts a merged promotion PR and validates the cluster returns to the prior image within a target SLO.

### Move 5 — Handle the authn SESSION_COOKIE_DOMAIN claim definitively

Run a real browser session on `https://apps.academyv2.mereka.dev/authn/login`, watch console for any `SESSION_COOKIE_DOMAIN` or `browser-router` warnings. If none, close the open follow-up with a one-line verdict. If reproduced, trace the source (likely `frontend-platform` getConfig() with misconfigured env).

Tool: the `claude-chrome` or `agent-browser` skill works.

## 6. Re-Prove Truth on Arrival

Don't trust anything above without re-verifying. Minimum first 10 commands:

```bash
# 1. Host + time
hostname && date -u +%FT%TZ

# 2. Repo state (both)
cd ~/projects/k8s/mereka-lms && git status --short --branch && git rev-parse HEAD main origin/main
cd ~/projects/k8s/bbi-infrastructure && git status --short --branch && git rev-parse HEAD main origin/main

# 3. Argo (digest-match proof)
kubectl -n argocd get application mereka-lms-dev -o jsonpath='sync={.status.sync.status} health={.status.health.status} rev={.status.sync.revision}{"\n"}'
cd ~/projects/k8s/bbi-infrastructure && git rev-parse origin/main

# 4. Deploy readiness
kubectl -n mereka-lms-dev get deploy lms cms mfe lms-worker cms-worker caddy -o json | jq -r '.items[] | [.metadata.name, (.status.readyReplicas // 0|tostring)+"/"+(.spec.replicas|tostring), .spec.template.spec.containers[0].image] | @tsv'

# 5. Live probe spec (confirm RC-05 fix is still present)
kubectl -n mereka-lms-dev get deploy cms-worker -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.exec.command}'

# 6. Product surface sweep
for url in apps.academyv2.mereka.dev apps.skillourfuture.academyv2.mereka.dev apps.biji-biji.academyv2.mereka.dev apps.academy.biji-biji.com; do echo "$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "https://$url/api/mfe_config/v1") https://$url/api/mfe_config/v1"; done

# 7. PR states
for pr in 1805 1808 1812 1813; do gh pr view $pr --repo Biji-Biji-Initiative/mereka-lms --json number,state,mergeStateStatus --jq '.'; done
for pr in 3219; do gh pr view $pr --repo Biji-Biji-Initiative/bbi-infrastructure --json number,state,mergeStateStatus --jq '.'; done

# 8. RC-02 reproduce
cd ~/projects/k8s/mereka-lms && bash scripts/qa/verify-release-object.sh docs/status/active/evidence/rc02-102a56a07d/release-object.json

# 9. Module errors
kubectl logs -n mereka-lms-dev -l app.kubernetes.io/name=lms --tail=1000 | grep -cE "ModuleNotFoundError|ImportError"
kubectl logs -n mereka-lms-dev -l app.kubernetes.io/name=cms --tail=1000 | grep -cE "ModuleNotFoundError|ImportError"

# 10. Argo autoHeal health
kubectl -n argocd get application mereka-lms-dev -o jsonpath='autoHealAttempts={.status.operationState.operation.sync.autoHealAttemptsCount}{"\n"}'
```

## 7. Things Not To Do

- Do NOT start MFE Sprint A implementation (user-forbidden this 48h block)
- Do NOT do broad GKE/GCP string cleanup (user-forbidden, classification-only per `15-ACTIVE-CONTROL-PLANE-SURFACE-CLASSIFICATION-2026-04-18.md`)
- Do NOT touch `gcp-gke-auth` composite action internals (Bucket C — serves surviving external deps)
- Do NOT reopen broad conveyor architecture
- Do NOT treat `Argo sync=Synced` as deploy-realization proof; verify via live spec comparison (bead `infrastructure-nj48` documents why)
- Do NOT use `kubectl -o json` for managedFields work; use `--show-managed-fields=true` (the default strips them)
- Do NOT use `gh pr edit` on bbi-infrastructure PRs — GraphQL Projects-classic deprecation breaks it. Use `gh api -X PATCH /repos/.../pulls/<n> -f body="..."` instead.

## 8. Process Notes From This Session

- CI has a `Crown-jewel pre-flight` gate on PRs that touch `apps/mereka-lms/**`, `apps/<other-crown-jewel>/**`, etc. Required body format is regex-strict: `## Crown-jewel pre-flight` header (lowercase 'p'), `Crown jewel(s) touched: <list>` line, 5 specific literal checklist substrings. See `config/crown-jewel-registry.yaml` + `scripts/qa/verify-pr-has-crownjewel-preflight.sh`.
- `workflow_dispatch` on Policy Guards SKIPS `crown-jewel-preflight-check` (it's `pull_request`-gated). Retrigger via empty commit.
- Catalog-drift pattern: when a PR adds/changes docs, you often need to regenerate three files: `docs/catalog.json`, `generated/catalogs/docs-catalog.json` (via `tools/docs/verify/build-doc-catalog.py`), AND `verification/catalogs/verification_catalog.json` (via `scripts/qa/generate-verification-catalog.py`). Do it ONCE after all content changes are staged, then single commit. Don't loop regen-amend-regen.
- Merge sequence under branch protection: PRs need to be up-to-date with `origin/main` for `--admin` squash-merge to succeed. When main advances, re-rebase + force-push before retry.
