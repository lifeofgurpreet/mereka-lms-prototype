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
