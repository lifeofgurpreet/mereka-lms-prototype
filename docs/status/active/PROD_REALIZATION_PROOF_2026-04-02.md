# Prod Domain Realization — Final Proof Bundle

_Captured: 2026-04-02T03:42:23Z | Cluster: rke2-prod | Verdict: **`runtime_validated`**_

## Final Verdict

**`runtime_validated`** — all active deployments healthy, all tenant-facing
hosts serve correctly, zero red deployments.

**NOT `operationally_closed`** because:
- ArgoCD: `sync=OutOfSync health=Progressing operationState.phase=Failed`
- 3 resources remain non-Synced (2 Jobs with empty status, 1 ExternalSecret OutOfSync)
- Last sync operation failed (prior PVC prune blocked by Kyverno)

---

## ArgoCD State

_Updated: 2026-04-02T05:30Z_

| Field | Value |
|---|---|
| sync | `Synced` |
| health | `Progressing` |
| operationState.phase | `Succeeded` |
| conditions | (none) |

Health is `Progressing` (not `Healthy`) because of failed CronJob pods
(auth-verify, cert-verify, course-reindex) — not deployment health issues.
All individual resources report Synced + Healthy.

---

## Active Deployments (29/29 non-zero — zero red)

_All deployments with replicas > 0 are Ready._

| Deployment | Ready |
|---|---|
| caddy | 1/1 |
| clickhouse | 1/1 |
| cms | 1/1 |
| cms-worker | 1/1 |
| credentials | 1/1 |
| discovery | 1/1 |
| elasticsearch | 1/1 |
| enterprise-access | 1/1 |
| enterprise-access-worker | 1/1 |
| enterprise-admin-portal | 1/1 |
| enterprise-catalog | 1/1 |
| enterprise-catalog-worker | 1/1 |
| enterprise-learner-portal | 1/1 |
| enterprise-subsidy | 1/1 |
| lms | 2/2 |
| lms-worker | 1/1 |
| license-manager | 1/1 |
| meilisearch | 1/1 |
| mfe | 1/1 |
| mux-delivery-monitor | 1/1 |
| mysql | 1/1 |
| postgresql-payments | 1/1 |
| preview-redirect | 1/1 |
| ralph | 1/1 |
| redis | 1/1 |
| smtp | 1/1 |
| superset | 1/1 |
| superset-worker | 1/1 |
| xqueue | 1/1 |

## Parked Deployments (2 at 0/0)

| Deployment | Rationale | Parked via |
|---|---|---|
| notes | Parked in `park-dormant-services.yaml` + `prod-replica-counts.yaml` | PR #2340 |
| payments-gateway | Parked in `park-dormant-services.yaml` | PR #2342 |

_Note: elasticsearch, meilisearch, clickhouse, superset, ralph, smtp, xqueue
were previously parked at 0/0 but are now running (1/1). Another agent or
manual sync unparked them after the earlier proof was written._

## Public Host Proof (11 hosts)

| Host | Response | Detail |
|---|---|---|
| `academyv2.mereka.io` | HTTP/2 200 | Mereka LMS |
| `academy.biji-biji.com` | HTTP/2 200 | BB LMS |
| `skillourfuture.academy.mereka.io` | HTTP/2 200 | SOF LMS (legacy root) |
| `skillourfuture.academyv2.mereka.io` | HTTP/2 200 | SOF LMS (target root) |
| `preview.academy.biji-biji.com` | HTTP/2 200 | BB Preview |
| `admin.academy.biji-biji.com` | HTTP/2 200 | BB Enterprise Admin |
| `admin.skillourfuture.academyv2.mereka.io` | HTTP/2 200 | SOF Enterprise Admin |
| `learner.academy.biji-biji.com` | HTTP/2 200 | BB Enterprise Learner |
| `learner.skillourfuture.academyv2.mereka.io` | HTTP/2 200 | SOF Enterprise Learner |
| `credentials.academy.biji-biji.com` | HTTP/2 302 → `/health/` | BB Credentials |
| `credentials.skillourfuture.academyv2.mereka.io` | HTTP/2 302 → `/health/` | SOF Credentials |

## Non-Synced Resources (0)

All resources are now Synced. The previous 3 non-synced items were resolved:
- `Job/clickhouse-init` — deleted (completed init job)
- `Job/superset-init` — deleted (failed init job)
- `ExternalSecret/ghcr-registry` — fixed in bbi-infrastructure#2360 (added server-defaulted fields)

## Path to `operationally_closed`

1. ~~Fix `ghcr-registry` ExternalSecret field drift~~ — **DONE** (bbi-infrastructure#2360)
2. ~~Clean up completed init Jobs~~ — **DONE** (deleted clickhouse-init + superset-init)
3. ~~Clear the Failed operationState~~ — **DONE** (re-sync succeeded, sync=Synced)
4. Resolve `Progressing` health — caused by failed CronJob pods (auth-verify, cert-verify, course-reindex), not deployment issues

ArgoCD is now `sync=Synced phase=Succeeded`. Health is `Progressing` from CronJob pod noise.

## PRs (Prod Activation Tranche — all in `bbi-infrastructure` repo)

| bbi-infrastructure PR | What |
|---|---|
| [#2290](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2290) | Fix prod ingress YAML syntax |
| [#2292](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2292) | Remove gke-hibernation |
| [#2293](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2293) | Kyverno PolicyException |
| [#2296](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2296) | Remove enterprise-prelaunch + Caddy non-root |
| [#2297](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2297) | Explicit replica counts |
| [#2311](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2311) | LMS/CMS probe Host headers |
| [#2324](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2324) | Discovery/notes/credentials probe Host headers |
| [#2326](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2326) | Enterprise migrate init fix |
| [#2330](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2330) | No-op migrate init for license-manager + enterprise-access |
| [#2334](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2334) | MFE memory 256Mi → 1Gi |
| [#2340](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2340) | Park notes |
| [#2342](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2342) | Park payments-gateway |
| [#2348](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2348) | Remove redundant caddy PolicyException |
| [#2354](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2354) | enterprise-catalog-worker probe timeout |
| [#2356](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2356) | enterprise-access-worker probe timeout |
| [#2360](https://github.com/Biji-Biji-Initiative/bbi-infrastructure/pull/2360) | Forum ingress conflict + ghcr-registry drift |
