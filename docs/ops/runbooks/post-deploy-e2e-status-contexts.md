# Post-Deploy E2E Status Contexts

> Runbook: understanding the two distinct GitHub commit status contexts emitted by
> `.github/workflows/post-deploy-e2e.yml` and how to triage failures correctly.

## Context Map

| `run_mode`      | Status context          | Meaning |
|-----------------|-------------------------|---------|
| `e2e`           | `dev-runtime/e2e`       | Live app runtime health — staging or active env. Failures here are app-runtime failures. |
| `prod-parked`   | `prod-parked-state/auth`| Decommissioned GKE control-plane residue check. Failures here are NOT app-runtime failures. |

## dev-runtime/e2e

Set when `run_mode=e2e` (all non-parked environments). This context is the authoritative runtime
gate. A red check here means the live application has a real regression.

**Triage**: Investigate app logs, pod health, and recent deploys. Escalate to on-call.

## prod-parked-state/auth

Set when `run_mode=prod-parked`. This fires only when `PROD_RUNTIME_MODE=parked` in
`config/runtime-proof-policy.env`.

**Classification: CONTROL-PLANE DEBT — decommissioned GKE residue. NOT an app-runtime failure.**

The GKE `mereka-lms` namespace is frozen at 0 replicas (decommissioned). The `prod-parked-state`
lane verifies the parked state remains stable (no unexpected replica drift, no secret rotation
breaking the frozen config). A failure here means:

- The parked-state verifier (`scripts/qa/verify-prod-parked-state.sh`) detected an anomaly in the
  decommissioned GKE namespace, OR
- A control-plane invariant (secret schema, frozen replica count) changed unexpectedly.

**Do NOT treat `prod-parked-state/auth` failures as app downtime.** The live production app runs
on RKE2 (`rke2-nonprod` cluster), not GKE. The staging lane (`dev-runtime/e2e`) is the
authoritative runtime proof until GKE debt is fully cleared.

## Policy Source

Context values are driven by `config/runtime-proof-policy.env`:

```
PROD_RUNTIME_MODE=parked
PROD_PARKED_STATUS_CONTEXT=prod-parked-state/auth
```

When `PROD_RUNTIME_MODE` is flipped to `active`, the workflow automatically switches to
`dev-runtime/e2e` for production as well.

## Related

- `config/runtime-proof-policy.env` — authoritative policy flags
- `scripts/qa/verify-prod-parked-state.sh` — parked-state verifier
- `docs/adr/` — see ADR for GKE decommission rationale
