# RC-05 / RC-06 Runtime + Product-Surface Matrix — Artifact 102a56a07d

**Date:** 2026-04-18 probe time ~ 01:17Z

## 3-Tenant Product-Surface Matrix

| Tenant | Landing (root) | `/authn/login` | `/theme/core.min.css` | `/theme/mereka-brand.min.css` | `/api/mfe_config/v1?mfe=learning` |
|---|---|---|---|---|---|
| `academyv2.mereka.dev` / `apps.academyv2.mereka.dev` | 200 / 302 | 200 | 200 | 200 | 200 |
| `skillourfuture.academyv2.mereka.dev` / `apps.skillourfuture.academyv2.mereka.dev` | 200 / 302 | 200 | 200 | 200 | 200 |
| `academy.biji-biji.com` / `apps.academy.biji-biji.com` | 200 / 302 | 200 | 200 | 200 | 200 |

Notes: `apps.*` returning 302 on root is correct (MFE shell redirects `/` to `/learning`, `/authn/login`, etc. per configuration).

## Tenant Isolation (MFE Config API)

| Tenant (apps.*) | LMS_BASE_URL | SITE_NAME | LOGO_URL |
|---|---|---|---|
| `apps.academyv2.mereka.dev` | `https://academyv2.mereka.dev` | `Mereka Academy` | `.../theme/logo-horizontal.svg` (Mereka default) |
| `apps.skillourfuture.academyv2.mereka.dev` | `https://skillourfuture.academyv2.mereka.dev` | `Skill Our Future Academy` | `.../theme/skillourfuture/logo-horizontal.svg` |
| `apps.academy.biji-biji.com` | `https://academy.biji-biji.com` | `Biji-Biji Academy` | `.../theme/biji-biji/logo-horizontal.svg` |

Each tenant returns its **own** `LMS_BASE_URL`, `SITE_NAME`, and tenant-prefixed `LOGO_URL`. Pre-#1797 this was broken (all three returned the Mereka default). The SiteConfiguration seed + CMS OAuth middleware extension is operational.

## Runtime Workload Readiness

| Deployment | Ready / Desired | Image digest | Note |
|---|---|---|---|
| `lms` | 1/1 | `d17ae77f…` | ✓ serving |
| `cms` | 1/1 | `d17ae77f…` | ✓ serving |
| `lms-worker` | 2/3 | `d17ae77f…` | 1 replica wedged on `wk-04-sin1` |
| `cms-worker` | 1/2 | `d17ae77f…` | 1 replica wedged on `wk-04-sin1` |
| `mfe` | 1/1 | `377923c0…` | ✓ serving |
| `caddy`, `mysql`, `mongodb`, `redis`, `meilisearch`, `elasticsearch`, all enterprise services, `clickhouse`, `superset`, `ralph`, `xqueue`, `notes`, `credentials`, `discovery`, `preview-redirect`, `smtp` | all 1/1 | — | ✓ serving |

## E2E Gate Classification (run `24591547989`)

**Classification: TEST-INFRA / WORKFLOW DEBT — NOT RC-05, NOT RC-06.**

Evidence:
- Failing job: `Verify Production Parked State`
- Failing step: `Authenticate to GCP and get GKE credentials`
- `GATE_ENVIRONMENT: production` was set for a build of `102a56a07d` (a dev-build commit)
- Memory authority: GKE is **decommissioned** (all workloads on RKE2); production parked-state check against dead GKE infrastructure always fails
- The gate validates a pre-cutover parked-state contract against infrastructure that no longer exists

Recommendation (file as follow-on bead, not this cycle's work):
- Either remove the Post-Deploy E2E Gate workflow entirely (retire the production parked-state check), or
- Repoint it at the actual staging/dev E2E suite and gate only on real runtime checks

## Worker Probe Defect (filed separately)

`cms-worker` and `lms-worker` readinessProbe (PR #3166, bead `q5yz`) uses `celery -A {cms,lms} inspect ping -t 15` with `timeoutSeconds: 20`. Live measurement on a currently-Ready replica returns in 19.9s — at the edge of the timeout window. Replicas on node `mereka-np-k8s-wk-04-sin1` (9 pods scheduled, highest density in cluster) consistently exceed the window and never report Ready. Same-pod self-ping via `--destination=celery@HOSTNAME` also fails with `No nodes replied within time constraint` in 27s — indicating broker-reply round-trip wedged.

**Category:** RC-05 runtime regression introduced by `q5yz` fix itself.
**Recommendation:** either lengthen probe command/container timeouts (`celery inspect ping -t 30` + `timeoutSeconds: 45`), or swap to a local port/process liveness check that does not traverse the Celery broker. Out of scope for this charter cycle; file as new bead.

## Verdict

**RC-05 (runtime): CONDITIONAL CLOSE.** Serving replicas healthy. Degraded-but-serving state on workers due to probe defect.
**RC-06 (product-surface): CLOSED.** 3-tenant matrix green; tenant isolation proven; all MFE assets served.

## Next Smallest Decisive Move on This Lane

File the readinessProbe defect as a bead (P2) with the measurement evidence. Do **not** patch the probe as part of this charter — keep RC-07 graduation clean.
