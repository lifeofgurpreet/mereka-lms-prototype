# Middleware Verification
_Audience: Platform operators and release engineers • Owner: Platform Team • Last verified: 2026-04-10 • Status: canonical_

Use this runbook to verify that the deployed middleware stack and custom Django
apps are present and ordered correctly in the current lane.

This is the maintained deployment-verification companion for the middleware
lane. Use [DEPLOYMENT_RUNBOOK.md](DEPLOYMENT_RUNBOOK.md) as the deployment
entry point, then use this doc once middleware verification is the selected
lane. It complements, but does not replace:

- [MIDDLEWARE_TROUBLESHOOTING.md](MIDDLEWARE_TROUBLESHOOTING.md)
- [site-down.md](site-down.md)
- [architecture/MFE_OAUTH_FIX_DEPLOYMENT.md](architecture/MFE_OAUTH_FIX_DEPLOYMENT.md)
- [../../reference/architecture/TUTOR_PATCHES_INVENTORY.md](../../reference/architecture/TUTOR_PATCHES_INVENTORY.md)
- [../../../specs/platform-middleware-custom-apps_spec.md](../../../specs/platform-middleware-custom-apps_spec.md)

## Current Boundary

As of 2026-04-10:

- the middleware stack and custom apps are already deployed platform behavior,
  not speculative design
- this runbook owns how to verify the stack in a live or rendered-settings
  context
- use the troubleshooting companion when the expected behavior is missing or
  contradictory

## What To Verify

The current verification lane covers:

- forwarded-header normalization
- cookie-domain middleware ordering
- platform-admin middleware presence
- `mfe_oauth_fix` custom app and middleware presence
- `openedx_prometheus` installation and `/metrics` exposure

## Quick Verification Checklist

Confirm all of the following:

1. the expected middleware entries are present
2. forwarded-header middleware is early enough to normalize proxy headers
3. cookie middleware is ordered correctly relative to session handling
4. `mfe_oauth_fix` is installed and active for `/api/mfe_context`
5. `openedx_prometheus` is installed and `/metrics` resolves in the expected
   lane

## Operator Sequence

Use this order for a real verification pass:

1. prove rendered middleware order
2. prove auth/cookie behavior on the intended host
3. prove MFE OAuth provider injection for `/api/mfe_context`
4. prove `/metrics` exposure and host/header handling
5. record which part failed before switching to troubleshooting

## Verification Routes

### 1. Settings / order verification

Use the current verification scripts first:

- `scripts/qa/verify-middleware-order.sh`
- `scripts/qa/verify-auth-hardening.sh`
- `scripts/qa/verify-oidc-cookie-middleware-order.sh`

If rendered settings are available, verify the relevant middleware entries are
present in the expected order.

Minimum expected coverage:

- forwarded-header normalization appears before downstream trust decisions
- cookie-domain handling does not trail the session/cookie logic incorrectly
- platform-admin middleware is present
- `mfe_oauth_fix` and `openedx_prometheus` are actually installed

### 2. Auth and cookie verification

Use:

- `scripts/qa/verify-auth-surfaces.sh`
- `scripts/qa/verify-auth-sso-enterprise.sh`

Focus on:

- tenant-correct login/callback behavior
- cookie domain scoping
- secure forwarded-proto detection

### 3. MFE OAuth provider verification

Use:

- `scripts/qa/test-mfe-oauth-fix.sh`

Confirm:

- `/api/mfe_context` is not returning an empty provider array when enabled
- provider naming is normalized correctly for the current lane

### 4. Metrics exposure verification

Confirm:

- `openedx_prometheus` is installed
- `/metrics` returns Prometheus text output
- internal scrape paths do not regress because of host-header rejection

Use the observability/on-call playbooks for the broader scrape pipeline once the
endpoint itself is proven.

## Verification Verdict Classes

| Result | Meaning |
| --- | --- |
| order clean, runtime clean | middleware lane is behaving as expected |
| order clean, runtime wrong | move to troubleshooting; likely behavior or host-specific regression |
| order wrong | fix source/render path first, then re-verify |
| `/metrics` wrong but auth path clean | keep this in the middleware/observability lane, not a general auth incident |

## Evidence Expectations

Any middleware verification pass should leave:

- target lane or environment
- settings/order evidence
- auth/cookie proof where relevant
- MFE OAuth proof where relevant
- metrics endpoint proof where relevant

## Related

- Troubleshooting: [MIDDLEWARE_TROUBLESHOOTING.md](MIDDLEWARE_TROUBLESHOOTING.md)
- Runtime incidents: [site-down.md](site-down.md)
- MFE OAuth fix detail: [architecture/MFE_OAUTH_FIX_DEPLOYMENT.md](architecture/MFE_OAUTH_FIX_DEPLOYMENT.md)
- Patch inventory: [../../reference/architecture/TUTOR_PATCHES_INVENTORY.md](../../reference/architecture/TUTOR_PATCHES_INVENTORY.md)
