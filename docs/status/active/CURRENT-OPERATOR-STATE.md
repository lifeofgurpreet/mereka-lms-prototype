---
title: Current Operator State
type: rolling-state
owner: platform-release
status: active
---

# Current Operator State

This is the rolling operator authority file.

Do not treat older numbered handoff / session docs as current truth unless
their durable content has been reconciled into this file.

## Purpose

Use this file to keep four things aligned:

1. live platform truth
2. repo / PR truth
3. tracker truth (`br`)
4. next move truth

Routing rule:

- this file answers **what is true now**
- `IMPLEMENTER-MARCHING-ORDERS.md` answers **what an implementer should do
  next**

If these diverge, repair the divergence before or during execution. Do not let
stale prose outrank live evidence.

## Primary Coordination Surfaces

1. this file
2. `IMPLEMENTER-MARCHING-ORDERS.md`
3. `br`
4. current git / PR state
5. current cluster / runtime state

## Operating Rules

- tracker truth + live truth beat stale prose
- when auditing repo surfaces, do not assume the current checkout branch equals
  `origin/main`
- patch merged defects on `main` instead of narrating around them
- keep the bead graph current
- keep this file current
- prefer one rolling authority file over many timestamped status docs
- if a numbered doc is created, fold its durable truth back into this file
- do not rely on ambient kubectl context for dev checks
- when in doubt, verify before claiming progress

## Refresh Procedure

At the start of a working loop:

1. refresh repo truth
2. compare current checkout branch truth to `origin/main` if repo inventory
   matters for the current task
3. refresh PR truth
4. refresh live cluster / runtime truth
5. refresh the bead graph
6. repair this file if it drifted
7. choose the lane using `IMPLEMENTER-MARCHING-ORDERS.md`
8. execute the highest-leverage ready sprint slice

At the end of a working loop:

1. re-check live truth
2. re-check queue truth
3. update beads
4. update this file
5. write the next exact move

## Standing Priorities

Use fresh evidence to order the queue, but generally prefer work in this order:

1. merged defects on `main`
2. realization-truth and release-safety gaps
3. runtime verification gaps
4. PR queue hardening / CI fixes
5. operator runbook hardening
6. status / governance work that reduces future drift

## Tracker Notes

Use `br` as the task graph.

Current warning:

- tracker reads are useful, but tracker mutation is not yet fully trustworthy
- `.beads/issues.jsonl` currently contains `10` non-conforming legacy IDs
- `.beads/` also carries a real corruption / recovery history

Before non-trivial tracker surgery, read:

- `TRACKER-HYGIENE-RECOVERY-PLAN.md`

If the queue is weak:
- create missing beads
- split oversized beads
- add dependencies
- re-prioritize honestly

Do not wait for a perfect graph before working, but do not keep executing from a
broken graph either.

## Known Durable Workstreams

These workstreams are durable even when specific PR numbers change:

- release / promotion truth
- realization truth
- rollback drill quality
- runtime pod / digest verification
- retry semantics hardening
- operator handoff / state automation
- truth-repair governance

## Current Live Truth









_Observed at `2026-04-18T13:39Z` (UTC). Every kubectl command below pins `--context rke2-nonprod` because ambient context on `ssh mereka` drifts to `rke2-prod` between sessions._

- Dev cluster: `rke2-nonprod`
  - Argo app state: `sync=Synced health=Healthy`
  - revision: `c6f4bdb292e8ddcfdcd5a51dbc25bf18fafe296b`
  - auto-heal count: `33`
  - deployment readiness summary: caddy:1/1, clickhouse:1/1, cms:1/1, cms-worker:1/1, credentials:1/1, discovery:1/1, elasticsearch:1/1, elasticsearch-exporter:1/1, enterprise-access:1/1, enterprise-access-worker:1/1, enterprise-admin-portal:1/1, enterprise-catalog:1/1, enterprise-catalog-worker:1/1, enterprise-learner-portal:1/1, enterprise-subsidy:1/1, license-manager:1/1, lms:1/1, lms-worker:1/1, meilisearch:1/1, mfe:1/1, mongodb:1/1, mongodb-exporter:1/1, mux-delivery-monitor:0/0, mysql:1/1, mysql-exporter:1/1, notes:1/1, payments-gateway:1/1, postgresql-payments:1/1, preview-redirect:1/1, ralph:1/1, redis:1/1, redis-exporter:1/1, smtp:1/1, superset:1/1, superset-worker:1/1, superset-worker-beat:1/1, xqueue:1/1
  - ambient kubectl context at generation: `rke2-nonprod`
- Notable runtime observations: (machine output: none. Add manually if you observed something the dashboard would miss.)

Re-prove command:
```bash
kubectl --context rke2-nonprod -n argocd get application mereka-lms-dev   -o jsonpath='sync={.status.sync.status} health={.status.health.status} rev={.status.sync.revision}{"
"}'
```
If the output of that command disagrees with the table above, trust the command, not this file.

## Current Queue Truth









_Queue snapshot at `2026-04-18T13:39Z`._

### Open PRs — `Biji-Biji-Initiative/mereka-lms`

- [#1834](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1834) BLOCKED — feat(ci): argo-sync-chain-watcher workflow — argo_sync_started / argo_sync_finished stages (bead lb4c.6)
- [#1833](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1833) BLOCKED — feat(ci): pod-image-realized-emit workflow (bead lb4c.6)
- [#1832](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1832) BLOCKED — feat(ci): wire emit-promotion-chain-metrics.sh bbi_pr_opened stage (bead lb4c.6, companion to #1828)
- [#1831](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1831) BLOCKED — docs(status): planner pack for tracker hygiene, Tier-A scripts, and MFE frontier
- [#1830](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1830) BLOCKED — feat(ci): wrap MFE Trivy scan with run-with-retry.sh (S6.2 wire-in, bead lb4c.7 companion to #1829)
- [#1829](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1829) BLOCKED — feat(ci): wrap OpenEdX Trivy scan with run-with-retry.sh (S6.2 wire-in, bead lb4c.7)
- [#1828](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1828) BLOCKED — feat(ci): wire emit-promotion-chain-metrics.sh into build-tutor-images (app_merge stage, bead lb4c.6)
- [#1825](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1825) BLOCKED — feat(governance): verify-retraction-sweep.sh (doctrine Rule 2 enforcement, y69t.2)
- [#1824](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1824) BLOCKED — feat(governance): verify-runbook-executable.sh (doctrine Rule 3 enforcement, y69t.1)
- [#1808](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1808) DIRTY — docs(status): add planning packet for conveyor stabilization and MFE program
- [#1798](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1798) BEHIND — Add Backstage catalog-info.yaml
- [#1791](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1791) DIRTY — docs(observability): purge VPS-Grafana debt + align cache refs with ADR-024/025
- [#1787](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1787) BEHIND — chore: bump protobufjs from 7.5.4 to 7.5.5 in /services/hubspot-webhook/functions
- [#1768](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1768) DIRTY — ci(fastlane): expand dedicated lane coverage to 9 meaningful jobs
- [#1743](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1743) BEHIND — chore: bump tutor from 21.0.2 to 21.0.3
- [#1709](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1709) BEHIND — build(deps): bump follow-redirects from 1.15.11 to 1.16.0 in /services/hubspot-webhook/functions
- [#1628](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1628) BEHIND — ci: bump actions/upload-artifact from 7.0.0 to 7.0.1

### Open PRs — `Biji-Biji-Initiative/bbi-infrastructure`

- [#3280](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3280) BEHIND — feat: enable agent-e checkpointer gc dry run
- [#3279](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3279) BEHIND — feat(ci): emit bbi_pr_merged promotion-chain metric on promotion-PR merge (bead mereka-lms-lb4c.6)
- [#3278](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3278) BEHIND — fix(argocd): honor ignoreDifferences in dev/staging + seed velero/external-secrets drift rules
- [#3277](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3277) UNKNOWN — chore(team-analytics): bump worker digest to 38de2a7e (post-#369/#370)
- [#3276](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3276) BEHIND — fix(appproject): allow backstage-{dev,staging,prod} namespaces in apps-* AppProjects
- [#3273](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3273) BEHIND — feat(team-analytics): pipeline-stale-alert CronJob every 30 min
- [#3272](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3272) BEHIND — fix(grizzly-drift): swap bitnami/git for bitnamilegacy archive
- [#3260](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3260) UNKNOWN — fix(s6.3): create missing _verify-release-object-inline.sh helper (closes run 24601299133 failure)
- [#3257](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3257) BEHIND — feat(kyverno): wire drill-scope-guardrail into overlays (drill.17 follow-up)
- [#3256](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3256) BEHIND — feat(monitoring): Postgres DR alert pack (bkp.PG.12)
- [#3254](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3254) BEHIND — feat(monitoring): authentik-worker alert rules (perf-opt-03 follow-on)
- [#3252](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3252) BEHIND — fix(argocd): use replace sync for kyverno prod crds
- [#3251](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3251) BEHIND — fix(argocd): allow backstage in apps-prod project
- [#3250](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3250) BEHIND — fix(argocd): normalize prod external-secret drift ignores
- [#3246](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3246) BEHIND — feat(authentik-prod): pg_stat_statements (perf-opt-01 v2)
- [#3238](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3238) UNKNOWN — feat(mereka-lms): add 7 missing singleton PDBs (bead tokm.11 Phase 0a)
- [#3233](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3233) UNKNOWN — feat(qa+docs): hairpin synthetic probe + 2 runbooks (bead tokm.16)
- [#3232](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3232) BEHIND — feat(rke2-prod): declarative per-CP-node config templates (Phase 0f, plan #3200)
- [#3231](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3231) UNKNOWN — feat(kyverno): prod validate require-worker-placement (Audit)
- [#3230](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3230) UNKNOWN — feat(kyverno): mutate worker nodeSelector for prod pods (pilot: infisical + mereka-prod)

### Last merges to `main` — `Biji-Biji-Initiative/mereka-lms`

- [#1827](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1827) 8d0e8b37f5a6 — chore(governance): remove 6 stale orphan-allowlist entries
- [#1826](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1826) 99316cd6d68b — docs(governance): wire Truth Repair Doctrine into generator + loop prompt + README (y69t.3)
- [#1823](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1823) 4883682f189d — docs(doctrine): Truth Repair Doctrine — 5-rule source-of-truth discipline (bead y69t)
- [#1822](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1822) 2381c72eea0f — feat(governance): rolling operator-state generator (bead mereka-lms-5dz5)
- [#1821](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1821) 14c2978eb1de — fix(runbook): derive BASELINE_DIGEST + pin --context in rollback drill
- [#1820](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1820) 74641ed38220 — docs(session): formal closure report — 2026-04-18 operator surface sprint

### Last merges to `main` — `Biji-Biji-Initiative/bbi-infrastructure`

- [#3275](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3275) 9db83ba1a9dc — fix(logical-backup-cron): chart default → library/postgres digest
- [#3274](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3274) c6f4bdb292e8 — fix(kyverno): digest-pin bitnami/kubectl across dev+staging+prod (10 refs)
- [#3271](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3271) df20902b11c3 — docs(dr): B2 hardening — SSE-B2 + lifecycle shipped, Object Lock migration plan (sec.2)
- [#3270](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3270) 280b033c0f76 — fix(agent-e): restore prod bootstrap ownership of static infra apps
- [#3268](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3268) 4a9c8e2e9726 — fix(team-analytics): disable AUTO_APPLY_MIGRATIONS (worker preflight blocker)
- [#3267](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3267) 80bb1e8f009c — fix(agent-e): harden minio post-job security context

### Ready work from `br ready` (top 8)

```
1. [● P1] [task] mereka-lms-1kwf.1: Footer parity: port Mereka Frontend v2 footer into LMS/MFEs (plugin-first)
2. [● P1] [task] mereka-lms-jj97.11: Raw build telemetry schema: store facts, derive warm/cold/partial in views
3. [● P0] [epic] mereka-lms-0z5g: [PLANNING] Reconcile Build Authority Phase 2 against proven truth and user steering memos
4. [● P1] [task] mereka-lms-v5vj: Verify DR: run audit-velero.sh and prove backup/restore works
5. [● P0] [bug] mereka-lms-cm9c: STRUCTURAL: Studio tenant SSO redirect goes to wrong authn page + multiple truth sources
6. [● P1] [task] mereka-lms-q69f: Script First-Class Program: tier promotion/runtime/governance scripts, score them, and burn highest-risk gaps
7. [● P1] [task] mereka-lms-m0u5: MFE issue map -> executable backlog: browser proof, semantic gaps, selector debt, runtime-config consistency
8. [● P2] [task] mereka-lms-xwmn: Archive 70+ stale status files and move GKE_LOKI_FORWARDING.md
```

## Active Implementer Tranche

The raw open-PR snapshot above is not the same thing as the active tranche.

Implementers should treat the following as the real live queue unless fresh
evidence promotes something else:

1. the current in-flight high-leverage PR chain
   - governance / doctrine / planner-pack work already in motion
   - release / realization / safety fixes already close to landing
2. merged defects on `main`
3. tracker reliability only when explicitly working the tracker lane
4. `mereka-lms-q69f` script first-class hardening
5. `mereka-lms-m0u5` MFE executable frontier
6. rollback / DR evidence lanes (`lb4c.9`, `v5vj`)

Do **not** interpret every older open PR in the snapshot as “work this next.”
Many are background, stale, external, or outside the current tranche. Use
`IMPLEMENTER-MARCHING-ORDERS.md` to decide which open queue actually deserves
attention.

## Next Exact Move









_Computed at `2026-04-18T13:39Z`. Replace this with a specific action for the next loop iteration._

Current checkout: branch `docs/final-deliverables-rc07-closed-20260418`, HEAD `355b5c3e0` — _docs(status): hour-6 — #1827 merged; +#1830 MFE retry wrap; +#1832 truthful bbi_pr_opened poll_.

Default next move if nothing else is obviously higher-leverage:

1. Re-prove live truth (see re-prove command in Current Live Truth).
2. Inspect BLOCKED / BEHIND PRs above; rebase or fix CI failures for the top of the queue.
3. Claim the top `br ready` item that retires a named failure class (P0/P1 beats P2 housekeeping).
4. Regenerate this file at end of slice with `bash scripts/governance/generate-current-operator-state.sh`.

Before ending a loop, write the next concrete action here so the next iteration can start without oral context. Canonical authority here is the last human-authored sentence on this line — the default text above is a floor, not a plan.

### Pointed next move (set 2026-04-18T13:40Z)

**Planner/reviewer lane update:** live dev is still healthy, but the most
important active diagnosis is now tracker recovery, not the older S6.1 summary
below.

Live truth just re-proven:

- dev Argo app: `sync=Synced health=Healthy rev=c6f4bdb292e8ddcfdcd5a51dbc25bf18fafe296b`
- all six deploys still `1/1`

Planner-pack queue:

- `mereka-lms#1831` is still `OPEN`, `MERGEABLE`, auto-merge armed, and blocked
  only on normal CI fan-out
- the most recent failing signal was `Static Validation Precheck`; the PR is not
  conceptually blocked, just still moving through CI

Tracker diagnosis has strengthened materially:

1. Legacy-ID normalization is still required:
   - `10` legacy rows remain the prerequisite cleanup
2. But normalization is **not sufficient**:
   - a repo-root normalized rebuild still times out
   - then leaves malformed SQLite/WAL state
3. The config/prefix contradiction is now proven:
   - `br config get issue-prefix` returns `mereka-lms`
   - `strace` proves `br sync --import-only --rebuild` opens both:
     - `~/.beads/config.yaml`
     - repo-local `.beads/config.yaml`
   - yet the same rebuild still logs:
     - `Auto-detected prefix from JSONL (no prefix configured) detected_prefix=mereka`
4. Therefore the remaining bug is in rebuild/import behavior, not merely in
   missing config files or legacy IDs
5. Subset probing points to nondeterministic importer/storage behavior, not one
   poisonous row:
   - `1..10` normalized rows succeed
   - `20` rows are flaky across repeated runs
   - `50+` rows usually timeout and/or poison the store
6. Bare `BR_DATA_DIR=...` probes are not trustworthy final validation; use full
   repo-root checkouts/worktrees for health checks

Next loop iteration should:

1. Re-check `#1831` and let auto-merge fire if CI clears.
2. Keep `CURRENT-OPERATOR-STATE.md` as the authority surface; do not let the
   older S6.1 queue summary become the planning anchor.
3. If `#1831` is still open, continue the tracker lane:
   - isolate why rebuild ignores/eclipses configured `issue-prefix`
   - keep using repo-root normalized repros, not bare `.beads` dirs
4. If `#1831` lands, fold the latest tracker findings onto `main` and seed the
   next tracker-repair bead for:
   - rebuild-path config handling / prefix derivation
   - nondeterministic malformed SQLite/WAL output after timed-out normalized rebuild
5. Only after the tracker lane is well-framed should the loop pivot back to the
   next large implementation frontier (`q69f`, `m0u5`, `cm9c`, `v5vj`)

---

### Slice 82 — 2026-04-20T03:45Z (two CI-platform defects root-caused, both fixed durably)

**NOTE**: The generator-authored sections above reflect 2026-04-18T13:39Z truth
(stale). Current reality is slices 60–82 inclusive — see commit log on `main`
for slice-wrap authority. This slice's additions below are the live, authoritative
update.

#### Two defects surfaced by PR #1906 build failure

PR #1906 (Authn MFE `getMerekaShellCopy` runtime-helper fix) merged to `main` as
`9bbb5bfb6e20ca9a1a2ced3032e0286b467bcb95`. Its Build Tutor Images run
[`24641484520`](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/runs/24641484520)
finished with **both Build OpenEdX Image and Build MFE Image marked failure**,
yet both images are actually present in GHCR with valid digests.

**Defect 1 — fastlane containerd race** (OpenEdX job). Host `vmi3220759` runs
15 concurrent GHA runner services using the containerd snapshotter. One
runner's job-completed `docker builder prune -af` wiped ingest blobs that
another runner's concurrent `docker pull` was mid-write. Post-push verify
scripts are the race victim.

**FIX SHIPPED on VPS** (SSH'd via tailscale; non-harness host):
- `/usr/local/lib/gha-fastlane/cleanup.sh` now wraps prune in `flock` +
  skips when other `Runner.Worker spawnclient` processes are active;
  force-override at disk >92%.
- Mirrored to SOT `/root/scripts/ci/fastlane-build-cleanup.sh` so
  `bootstrap-fastlane-build-host.sh` preserves the fix.
- Evidence: `docs/ops/evidence/fastlane-containerd-race-fix-2026-04-20.md`
  (on branch `docs/obs-audit-2026-04-20`, PR #1914 which is conflicting
  on stale base — content valuable; PR will need rebase or replacement).

**Defect 2 — ci-metrics-receiver fatal dependency** (MFE job). The composite
action `push-build-metrics` at `bbi-infrastructure/.github/actions/` used
`set -euo pipefail` + `curl --fail-with-body`. When `ci-metrics.mereka.dev`
returned 502, the metrics step failed fatally, cascading to skip post-push
scans + SLSA + dispatch. Root: ci-metrics-receiver PM2 app is **dead on
mereka-coding VPS** (port 9250 not listening, no uvicorn process). Caddy
gets 502 because upstream is down.

**FIX SHIPPED**:
- **`bbi-infrastructure#3377`** — makes `push-build-metrics` non-fatal per
  ADR-025 §5 (observability not release gate). 3-attempt exponential
  backoff then warn-and-continue. Missing metrics-file also becomes
  warn-and-continue.
- **NOT YET FIXED**: ci-metrics-receiver itself being down on
  `mereka-coding`. Per CLAUDE.md, that host is the active coding harness
  and I must not mutate its PM2/systemd state without explicit user
  authorization. Proposed restart documented; user-gated.

**MFE digest verified in GHCR** despite CI-job failure:
```
ghcr.io/biji-biji-initiative/mereka-lms/mfe:9bbb5bfb6e20ca9a1a2ced3032e0286b467bcb95
  → amd64 manifest sha256:1a702c93554cf00f0d2197cd4a1a01aa733a99ce1c8648939c818b4b4e3cfe06
```

#### State of #1906 fix

- Source: merged to `main` (`9bbb5bfb`).
- Images: built and pushed to GHCR with correct tags.
- Dispatch chain: **did not fire** because MFE job marked failure.
- Runtime: **not yet live on dev** — mfe deploy still on pre-#1906 image.
- Promotion PR: **not opened** because `Dispatch Dev Promotion` step was
  skipped.

**Once `bbi-infrastructure#3377` merges and next mereka-lms push happens,
the chain should complete autonomously.** If user wants #1906 live now, two
options:
  a) Restart ci-metrics-receiver on mereka-coding (requires authorization),
     then trigger an empty-commit push to main to re-run Build Tutor Images.
  b) Wait for bbi-infra#3377 to merge; then push empty commit.

#### Shipped this slice

- **bbi-infrastructure#3377** — non-fatal push-build-metrics action (observability-sink-must-not-gate-release).
- **VPS fix on `vmi3220759`** — `cleanup.sh` race guard (serializes docker prune across 15 shared runners).

#### Open items at slice-82 close

- `mereka-lms#1914` (observability world-class audit, 22 beads queued) — conflicting on stale base; content valuable in evidence doc; needs either a rebase or a replacement PR with the same artifacts.
- ci-metrics-receiver PM2 restart — user-gated.
- #1906 runtime verification — gated on dispatch chain re-running after #3377 merges.
- OBS-001..OBS-006 (P0 beads from slice-81 audit) — tracker corrupted, cannot file via `br`; roster preserved in `docs/ops/evidence/observability-audit-2026-04-20.md`.

#### Pointed Next Move (slice 82)

1. **Merge `bbi-infrastructure#3377`** — unblocks all future builds regardless of ci-metrics state.
2. **Decide on ci-metrics-receiver restart** — either user-authorize or leave until #3377 lands (after which it no longer gates anything).
3. **Re-open world-class obs audit PR** cleanly on a fresh base (evidence docs at `docs/ops/evidence/observability-audit-2026-04-20.md` + `docs/ops/evidence/fastlane-containerd-race-fix-2026-04-20.md` exist on branch `docs/obs-audit-2026-04-20`).
4. **#1906 runtime verification**: once dispatch chain re-fires, verify via `kubectl --context rke2-nonprod -n mereka-lms-dev exec deploy/mfe -- grep -rln getMerekaShellCopy /openedx/dist/authn/`.

---

### Slice 83 — 2026-04-20T05:15Z (dispatch chain proven end-to-end, #1906 LIVE on dev)

**End-to-end dispatch chain proven in one unbroken run:**

1. `bbi-infrastructure#3377` merged at 02:28:01Z — non-fatal metrics action live on bbi-infra main.
2. Replayed build `24641484520` (originally failed on #1906 SHA `9bbb5bfb`) re-run via `gh run rerun --failed`. Every downstream job green including the two defects that originally killed it:
   - Post-push OpenEdX Scan: SUCCESS (fastlane containerd race fix holding)
   - MFE metrics post-push: warn-and-continue per the new composite action (ci-metrics-receiver on mereka-coding is still down but no longer blocks)
3. `Dispatch Dev Promotion` fired → opened `bbi-infrastructure#3384` at 03:01:08Z pinning:
   - openedx: `9bbb5bfb@sha256:ef91636faa850ee12c125d86943088c87696223d8ce05252c3534a9c73a07007`
   - mfe: `9bbb5bfb@sha256:4aa93530e225c6aaf01869d535df76e49704c840fbabdb8ca1a88c5836a8d385`
4. Promotion PR auto-merged after `gh api PUT /pulls/3384/update-branch` (BEHIND on main due to unrelated churn). Crown-jewel preflight + policy-guards + gitleaks + Seer all PASS.
5. ArgoCD hard-refresh → synced to bbi-infra `36dfc7cc` (#3384 merge commit).
6. MFE pod rolled to new image. Old pod terminated; new pod `mfe-78fd8f68cd-pxwlw` Ready.

**Runtime proof (authoritative, live HTTPS):**

- `kubectl exec deploy/mfe -- grep -l getMerekaShellCopy /openedx/dist/authn/*.js` → `/openedx/dist/authn/app.7674109da3e00c36e195.js` ✅
- `curl -sL https://apps.academyv2.mereka.dev/authn/login | grep -oE 'app\.[a-f0-9]+\.js'` → `app.7674109da3e00c36e195.js` (same bundle, served through Caddy + ingress)
- `curl -sL https://apps.academyv2.mereka.dev/authn/app.7674109da3e00c36e195.js | grep -c getMerekaShellCopy` → 1

The `getMerekaShellCopy is not defined` ReferenceError that caused the blank-Authn-shell class of failure (RCB-10 successor) is **closed at runtime on dev**.

**Durable fixes shipped this cycle (all proven out live):**

| Fix | Location | Proof |
|---|---|---|
| Fastlane containerd race | `/usr/local/lib/gha-fastlane/cleanup.sh` v2 on `vmi3220759` (tmpfiles.d + flock + per-user fallback + pgrep double-zero fix) | OpenEdX + MFE scans all green on replay |
| ci-metrics non-fatal | `bbi-infrastructure#3377` → composite action warns-and-continues | Build succeeded with ci-metrics.mereka.dev still returning 502 |
| Dispatch chain | Full push→build→scan→SLSA→release-bundle→dispatch→promote→Argo→pod-roll→runtime proven in one organic replay | From merge of #3377 to live runtime: ~10 min |

**Concurrent PR queue (auto-merge armed):**

- `mereka-lms#1916` — Wave 9 absence-tolerance for 5 verifiers + 2 registry entries + inventory regen + catalog regen.
- `mereka-lms#1917` — Clean re-PR of observability audit + fastlane fix evidence. Blocked on the same Wave 9 defects #1916 fixes; cascades on merge.
- `mereka-lms#1915` — slice 82 state doc update. Same blocker pattern.

**Open residuals (non-blocking):**

- ci-metrics-receiver on mereka-coding still down (P2, user-gated). No longer blocks CI.
- Tracker SQLite still corrupted (user-gated repair).
- 22 observability audit beads (6 P0) captured in evidence doc; bead filing gated on tracker repair.

## Pointed Next Move (slice 83)

1. Let #1916 CI cycle finish — should clear now that catalog is regenerated. Auto-merge fires.
2. After #1916 merges, rebase #1915 + #1917 onto main so they pick up Wave 9 fixes.
3. Close loop with one final state-doc slice summarizing the three-PR queue cleared.
4. Resume regular operator queue: m0u5.10.1 Learning MFE diagnosis, remaining Wave 9 cleanup, tracker repair (user-gated).

---

### Slice 84 — 2026-04-20T05:05Z (auth allowlist short-term unblock, #1919 tracking epic)

**User discovery**: pushed back on earlier narrow finding ("missing env var") — real issue is
**role-authority fragmentation** across 6 planes with no canonical contract and no reconciler.
Fadlan was operationally real but absent from every config file in both repos.

**Short-term unblock shipped live (2026-04-20T04:48Z)**:

Ran `ensure-platform-admins.sh --apply --admins <8-CSV>` across:
- `rke2-nonprod / mereka-lms-dev` → fadlan + eugene@mereka.my CREATED
- `rke2-nonprod / stg-mereka-lms` → fadlan + eugene@mereka.my CREATED
- `rke2-prod / mereka-lms` → fadlan + eugene@mereka.my CREATED

Plus Django-shell demote of legacy `admin@greentactsolutions.com` on dev + staging
(is_active=False, is_staff=False, is_superuser=False). Never existed on prod.

**Live verified (all 3 envs)**: 8 humans (gurpreet, malasari, miranda, hira, eugene×2, faiz, fadlan)
are `is_active=True, is_staff=True, is_superuser=True` across LMS + CMS (CourseCreator) +
Discovery + Credentials.

**Durable PRs opened + auto-merge armed**:

- `mereka-lms#1920` — adds fadlan to `ensure-platform-admins.sh` default CSV + rewrites
  `ADMIN_LOGIN_GUIDE.md` to list all 8 humans + mark as baseline-not-canonical.
- `bbi-infrastructure#3394` — syncs Authentik admin group blueprint with 5 missing humans
  (malasari, eugene×2, faiz, fadlan). Preserves `!If`+`!Find` pattern for PVC-wipe safety.

**Tracking epic opened**: [mereka-lms#1919 — Unified Platform-Access Contract](https://github.com/Biji-Biji-Initiative/mereka-lms/issues/1919)

Issue body captures the user's strategic reframe:
- Real object is `(person, principals, roles, environments, realization targets)` — NOT "list of emails"
- 6 disagreeing truth surfaces (Authentik bindings, LMS DB, env var, script, docs, synthetic accounts)
- 6-tranche execution plan (T0 freeze blast radius → T1 inventory matrix → T2 canonical registry →
  T3 replace hardcoded lists → T4 build `accessctl` reconciler with both first-login + periodic repair →
  T5 prove DB-reset survival)
- 6 CI gates (G1-G6)
- 10 proposed beads (auth-access-01 through -10)
- Called out as P1 operational drift, not "fixed"

**Team verification request** posted as comment on #1919 with per-human checklist.

**Open residuals from this slice**:
- Staging still has both `miranda@mereka.my` and `miranda@mereka.io` active — awaiting
  user decision whether `.io` should be demoted.
- `MEREKA_PLATFORM_ADMIN_EMAILS` env var still empty on all 3 envs → middleware backstop
  still dead. Needs separate bbi-infra PR populating the overlay patches (Tranche 3).
- ci-metrics-receiver restart on mereka-coding — still user-gated (P2, no longer CI-gating).

## Pointed Next Move (slice 84)

1. Wait on #1916 aggregator re-run to clear (all sub-checks passed; only umbrella was cancelled).
2. Monitor #1920 + #3394 for auto-merge.
3. If user answers on staging `miranda.io` drift + ci-metrics restart: execute.
4. Otherwise continue existing queue: m0u5.10.1, Wave 9 cleanup, tracker repair.

---

### Slice 85 — 2026-04-20T08:30–09:55Z (sprint queue Tier 1 execution begins)

**Context**: #1927 (RC_CHECKLIST + NEXT-SPRINT-QUEUE.md) merged at start of
slice. That gave a 13-item tiered roadmap — began draining Tier 1 items
while older cascade PRs (#1918/#1921/#1924/#1926) continued waiting on CI
rebases.

**Shipped this slice (auto-merge armed, all 4 green on Process Invariants +
Dependency Review as of push time)**:

- **[#1928](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1928)** `fix(mfe): surface SESSION_COOKIE_DOMAIN through MFE_CONFIG API`
  — Tier 1 #3, one-line plugin change in `_mereka_lms/lms_settings.py`.
  Evidence confirmed: bundle has `SESSION_COOKIE_DOMAIN:"MISSING_ENV_VAR".SESSION_COOKIE_DOMAIN`
  → `undefined` at runtime. MFE config API was silent on the key. Fix uses
  Django `SESSION_COOKIE_DOMAIN` as single source of truth.
- **[#1929](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1929)** `chore(obs): rename stale gke-production → rke2-production Promtail label`
  — Tier 1 #4 (OBS-006) app-repo half. Zero runtime effect — file is
  PLATFORM_SHARED shadow — but prevents dormant config from broadcasting
  wrong label on re-consumption.
- **[bbi-infrastructure#3461](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3461)** OBS-006 bbi-infra mirror.
  Minor detour: `git commit` accidentally scooped 9 other staged files from
  another agent's temporal-oidc work; reset and recommitted clean (1 file).
- **[#1930](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1930)** `feat(obs): schedule Authn MFE smoke` — Tier 1 #5 (OBS-003 phase 1).
  Scheduled cron `*/5 * * * *` dev, `*/15 * * * *` prod. Removed
  `continue-on-error: true` silent-fail posture. Split critical vs soft
  keys in `smoke-authn-mfe.sh` — critical keys still fail, soft keys warn
  (tracked as beads).

**Defects uncovered by scheduled smoke posture**:
- `LOGIN_ISSUE_SUPPORT_LINK` missing from MFE config API → bead
  `mereka-lms-jdsx` opened P2. (Was silently hidden by prior `--dry-run +
  continue-on-error: true` workflow.)
- `SESSION_COOKIE_DOMAIN` missing from MFE config API → fix is PR #1928.

**Currently armed for auto-merge** (7 PRs in mereka-lms, 1 in bbi-infra):
- `#1918`, `#1921`, `#1924`, `#1926`, `#1928`, `#1929`, `#1930`
- `bbi-infrastructure#3461`

**Tier 1 remaining (not yet started)**:
- **Tier 1 #1** (OBS-001): MFE client-side Sentry SDK — cross-lane
  (plugin hook in mereka-lms + DSN env plumbing in bbi-infra). Non-trivial;
  needs a dedicated slice.
- **Tier 1 #2** (auth-allowlist-03): `MEREKA_PLATFORM_ADMIN_EMAILS` env
  var population — BLOCKED on #1919 Tranche 3 (other agent, bbi-infra
  `render-lms-admin-emails.sh` generator).

## Pointed Next Move (slice 85)

1. Wait for current auto-merge cascade to drain. Once #1928 lands, its
   promotion chain produces new MFE image digests; after pods roll, hit
   `curl -s 'https://apps.academyv2.mereka.dev/api/mfe_config/v1?mfe=authn' | jq '.SESSION_COOKIE_DOMAIN'`
   and confirm `.academyv2.mereka.dev` surfaces. Then the smoke WARN should
   flip to PASS on the scheduled run and RC_CHECKLIST row 18 can be ticked.
2. Once #1924 + #1926 land, the queue-truth section (lines 149–233 above)
   becomes obsolete — the generator writes to `CURRENT-OPERATOR-STATE.snapshot.md`
   now and the pruned section stays out of this file.
3. Start Tier 1 #1 (OBS-001 MFE Sentry). Scope the first PR narrowly:
   plugin hook + `MFE_CONFIG["SENTRY_DSN"]` wiring + dev-only DSN in
   bbi-infra overlay. Staging/prod DSNs follow once dev Sentry is receiving
   events.
4. Tier 1 #2 stays blocked on #1919 T3 — watch for the bbi-infra
   `render-lms-admin-emails.sh` generator PR to land and rebase overlays.
