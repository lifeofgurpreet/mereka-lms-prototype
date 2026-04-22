# Post-Deploy E2E Status Contexts

> Runbook: understanding the two distinct GitHub commit status contexts emitted by
> `.github/workflows/post-deploy-e2e.yml` and how to triage failures correctly.

## Context Map

| `run_mode`      | Status context          | Meaning |
|-----------------|-------------------------|---------|
| `e2e`           | `dev-runtime/e2e`       | Live app runtime health — staging or active env. Failures here are app-runtime failures. |
| `prod-parked`   | `prod-parked-state/auth`| Legacy parked-production control-plane residue check. Current policy does not invoke this lane. |

## dev-runtime/e2e

Set when `run_mode=e2e` (all non-parked environments). This context is the authoritative runtime
gate. A red check here means the live application has a real regression.

**Triage**: Investigate app logs, pod health, and recent deploys. Escalate to on-call.

### MFE Host Derivation

Post-deploy Playwright tests MUST derive learner MFE hosts through
`tests/e2e/support/urls.ts`. Do not copy local `apps.<host>` helpers into
individual specs.

Canonical host rules:

| LMS host | MFE host |
|----------|----------|
| `academyv2.mereka.io` | `apps.academyv2.mereka.io` |
| `academyv2.mereka.dev` | `apps.academyv2.mereka.dev` |
| `staging.academyv2.mereka.io` | `staging.apps.academyv2.mereka.io` |
| `apps.<tenant-host>` | unchanged |

If a failure shows `getaddrinfo ENOTFOUND apps.staging.academyv2.mereka.io`,
classify it as an E2E source/test truth bug unless DNS authority explicitly
adds that host. The primary staging MFE host is `staging.apps.academyv2.mereka.io`.

## prod-parked-state/auth

Set when `run_mode=prod-parked`. This fires only if `PROD_RUNTIME_MODE=parked` in
`config/runtime-proof-policy.env`. As of 2026-04-22, current source truth sets
`PROD_RUNTIME_MODE=live`, so automatic post-deploy runs use the staging
`dev-runtime/e2e` lane.

**Classification when active: CONTROL-PLANE DEBT — legacy GKE-era parked-state residue. NOT an app-runtime failure.**

The parked-state lane verifies old parked-state invariants rather than the live
application. A failure here means:

- The parked-state verifier (`scripts/qa/verify-prod-parked-state.sh`) detected an anomaly in the
  legacy parked-state surface, OR
- A control-plane invariant (secret schema, frozen replica count) changed unexpectedly.

**Do NOT treat `prod-parked-state/auth` failures as app downtime.** The live production app runs
on `rke2-prod`. Automatic post-deploy checks currently target staging because
CI runners do not yet have `rke2-prod` kubectl access. Use explicit
`workflow_dispatch` production proof when an operator needs cross-cluster live
runtime verification.

## Policy Source

Context values are driven by `config/runtime-proof-policy.env`:

```
POST_DEPLOY_WORKFLOW_RUN_ENV=staging
PROD_RUNTIME_MODE=live
PROD_PARKED_STATUS_CONTEXT=prod-parked-state/auth
```

If `POST_DEPLOY_WORKFLOW_RUN_ENV` is changed to `production` while
`PROD_RUNTIME_MODE=live`, workflow-run post-deploy checks will use
`dev-runtime/e2e` for production.

## Related

- `config/runtime-proof-policy.env` — authoritative policy flags
- `scripts/qa/verify-prod-parked-state.sh` — parked-state verifier
- `docs/adr/` — see ADR for GKE decommission rationale
