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

If these diverge, repair the divergence before or during execution. Do not let
stale prose outrank live evidence.

## Primary Coordination Surfaces

1. this file
2. `br`
3. current git / PR state
4. current cluster / runtime state

## Operating Rules

- tracker truth + live truth beat stale prose
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
2. refresh PR truth
3. refresh live cluster / runtime truth
4. refresh the bead graph
5. repair this file if it drifted
6. execute the highest-leverage ready sprint slice

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


_Observed at `2026-04-18T11:14Z` (UTC). Every kubectl command below pins `--context rke2-nonprod` because ambient context on `ssh mereka` drifts to `rke2-prod` between sessions._

- Dev cluster: `rke2-nonprod`
  - Argo app state: `sync=Synced health=Healthy`
  - revision: `fc9e8260afed35d90c93d56af5cab1946fc3ad4e`
  - auto-heal count: `32`
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


_Queue snapshot at `2026-04-18T11:14Z`._

### Open PRs — `Biji-Biji-Initiative/mereka-lms`

- [#1822](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1822) BLOCKED — feat(governance): rolling operator-state generator (bead mereka-lms-5dz5)
- [#1819](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1819) BLOCKED — feat(ci): bounded-retry wrapper for transient Trivy/SBOM failures (S6.2)
- [#1818](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1818) BLOCKED — feat(ci): emit-promotion-chain-metrics.sh helper (closes S6.1 / bead mereka-lms-lb4c.1)
- [#1808](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1808) BEHIND — docs(status): add planning packet for conveyor stabilization and MFE program
- [#1798](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1798) BEHIND — Add Backstage catalog-info.yaml
- [#1791](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1791) DIRTY — docs(observability): purge VPS-Grafana debt + align cache refs with ADR-024/025
- [#1787](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1787) BEHIND — chore: bump protobufjs from 7.5.4 to 7.5.5 in /services/hubspot-webhook/functions
- [#1768](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1768) DIRTY — ci(fastlane): expand dedicated lane coverage to 9 meaningful jobs
- [#1743](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1743) BEHIND — chore: bump tutor from 21.0.2 to 21.0.3
- [#1709](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1709) BEHIND — build(deps): bump follow-redirects from 1.15.11 to 1.16.0 in /services/hubspot-webhook/functions
- [#1628](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1628) BEHIND — ci: bump actions/upload-artifact from 7.0.0 to 7.0.1

### Open PRs — `Biji-Biji-Initiative/bbi-infrastructure`

- [#3265](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3265) UNKNOWN — feat(team-analytics): bump digests + WEBHOOK_DEFAULT_TENANT_ID for data-integrity release
- [#3263](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3263) UNKNOWN — fix(dr): reconcile infisical drift + fix Alertmanager paths (resolves 2u09.126, addresses 2u09.60)
- [#3260](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3260) BEHIND — fix(s6.3): create missing _verify-release-object-inline.sh helper (closes run 24601299133 failure)
- [#3258](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3258) UNKNOWN — fix(infisical-pg-backup): override removed Bitnami image with digest-pinned postgres
- [#3257](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3257) BEHIND — feat(kyverno): wire drill-scope-guardrail into overlays (drill.17 follow-up)
- [#3256](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3256) BEHIND — feat(monitoring): Postgres DR alert pack (bkp.PG.12)
- [#3254](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3254) BEHIND — feat(monitoring): authentik-worker alert rules (perf-opt-03 follow-on)
- [#3253](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3253) UNKNOWN — fix(appset): calcom-prod include base path in manifest-generate-paths
- [#3252](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3252) UNKNOWN — fix(argocd): use replace sync for kyverno prod crds
- [#3251](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3251) UNKNOWN — fix(argocd): allow backstage in apps-prod project
- [#3250](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3250) UNKNOWN — fix(argocd): normalize prod external-secret drift ignores
- [#3246](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3246) UNKNOWN — feat(authentik-prod): pg_stat_statements (perf-opt-01 v2)
- [#3240](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3240) UNKNOWN — feat(kyverno): drill-scope-guardrail policy (drill.17)
- [#3238](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3238) UNKNOWN — feat(mereka-lms): add 7 missing singleton PDBs (bead tokm.11 Phase 0a)
- [#3233](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3233) UNKNOWN — feat(qa+docs): hairpin synthetic probe + 2 runbooks (bead tokm.16)
- [#3232](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3232) UNKNOWN — feat(rke2-prod): declarative per-CP-node config templates (Phase 0f, plan #3200)
- [#3231](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3231) BEHIND — feat(kyverno): prod validate require-worker-placement (Audit)
- [#3230](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3230) BEHIND — feat(kyverno): mutate worker nodeSelector for prod pods (pilot: infisical + mereka-prod)
- [#3229](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3229) BEHIND — feat(observability): Argo selfHeal-stuck alert + hard-refresh recovery runbook (bead nj48)
- [#3227](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3227) UNKNOWN — feat(dr): Grafana dashboard for observability self-monitoring (sf.4 follow-up)

### Last merges to `main` — `Biji-Biji-Initiative/mereka-lms`

- [#1823](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1823) 4883682f189d — docs(doctrine): Truth Repair Doctrine — 5-rule source-of-truth discipline (bead y69t)
- [#1821](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1821) 14c2978eb1de — fix(runbook): derive BASELINE_DIGEST + pin --context in rollback drill
- [#1820](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1820) 74641ed38220 — docs(session): formal closure report — 2026-04-18 operator surface sprint
- [#1817](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1817) 6c22f0caa000 — docs(runbook): S6.5 promotion rollback drill with 10-min SLO (closes bead mereka-lms-lb4c.5)
- [#1816](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1816) db832b7893d8 — feat(qa): verify-pods-on-digest helper (closes S6.4 / bead mereka-lms-lb4c.4)
- [#1815](https://github.com/Biji-Biji-Initiative/mereka-lms/pull/1815) 157961208e1f — chore(beads): file S6 promotion reliability parent + 5 children

### Last merges to `main` — `Biji-Biji-Initiative/bbi-infrastructure`

- [#3264](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3264) fc9e8260afed — fix(agent-e): set prod backup endpoint
- [#3262](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3262) a8c38797f3f5 — fix(agent-e): use admin credentials for prod backups
- [#3261](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3261) 9887e32f5b42 — feat(qa): preventive gate for authentik postgres preload-lib vs image availability
- [#3259](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3259) 2c57c03a44a5 — fix(agent-e): promote prod runtime to proven digest
- [#3255](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3255) a3173588b54b — docs(dr): temporal drill playbook (drill.15)
- [#3249](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/3249) 5d69260de7e4 — feat(pdb): add PDBs for calcom-api-v2 and kyverno-cleanup-controller

### Ready work from `br ready` (top 8)

```
1. [● P1] [task] mereka-lms-1kwf.1: Footer parity: port Mereka Frontend v2 footer into LMS/MFEs (plugin-first)
2. [● P1] [task] mereka-lms-jj97.11: Raw build telemetry schema: store facts, derive warm/cold/partial in views
3. [● P0] [epic] mereka-lms-0z5g: [PLANNING] Reconcile Build Authority Phase 2 against proven truth and user steering memos
4. [● P0] [task] mereka-lms-acl1: Merge promotion PR #3071 and verify dev convergence at 74eb96d9bc5
5. [● P1] [task] mereka-lms-v5vj: Verify DR: run audit-velero.sh and prove backup/restore works
6. [● P0] [bug] mereka-lms-cm9c: STRUCTURAL: Studio tenant SSO redirect goes to wrong authn page + multiple truth sources
7. [● P1] [task] mereka-lms-lb4c.4: S6.4: Gate promotion-to-staging on actual pod imageID match, not Argo sync=Synced
8. [● P2] [task] mereka-lms-xwmn: Archive 70+ stale status files and move GKE_LOKI_FORWARDING.md
```

## Next Exact Move


_Computed at `2026-04-18T11:14Z`. Replace this with a specific action for the next loop iteration._

Current checkout: branch `feat/operator-state-generator`, HEAD `54c51ef20` — _fix(governance): status:rolling / status:active for status-only docs_.

Default next move if nothing else is obviously higher-leverage:

1. Re-prove live truth (see re-prove command in Current Live Truth).
2. Inspect BLOCKED / BEHIND PRs above; rebase or fix CI failures for the top of the queue.
3. Claim the top `br ready` item that retires a named failure class (P0/P1 beats P2 housekeeping).
4. Regenerate this file at end of slice with `bash scripts/governance/generate-current-operator-state.sh`.

Before ending a loop, write the next concrete action here so the next iteration can start without oral context. Canonical authority here is the last human-authored sentence on this line — the default text above is a floor, not a plan.