# Middleware Troubleshooting
_Audience: Platform operators and release engineers • Owner: Platform Team • Last verified: 2026-04-10 • Status: canonical_

Use this runbook when the platform middleware stack or custom Django apps appear
to be present but are behaving incorrectly.

This is the current owner for middleware troubleshooting guidance. It
complements, but does not replace:

- [MIDDLEWARE_VERIFICATION.md](MIDDLEWARE_VERIFICATION.md)
- [site-down.md](site-down.md)
- [architecture/MFE_OAUTH_FIX_DEPLOYMENT.md](architecture/MFE_OAUTH_FIX_DEPLOYMENT.md)
- [../../reference/architecture/TUTOR_PATCHES_INVENTORY.md](../../reference/architecture/TUTOR_PATCHES_INVENTORY.md)
- [../../../specs/platform-middleware-custom-apps_spec.md](../../../specs/platform-middleware-custom-apps_spec.md)

## Current Boundary

As of 2026-04-10:

- the middleware stack is current platform runtime behavior
- the most important failure modes are auth/cookie breakage, empty MFE provider
  state, and metrics scrape regressions
- do not patch symptoms directly in a live pod without source-of-truth changes

## Triage Order

When middleware behavior is suspected:

1. verify the stack and order first with
   [MIDDLEWARE_VERIFICATION.md](MIDDLEWARE_VERIFICATION.md)
2. decide whether the failure is:
   - auth/cookie order
   - forwarded-header normalization
   - MFE OAuth provider injection
   - Prometheus endpoint exposure
3. collect settings/runtime evidence before changing source

## Common Failure Classes

### 1. Authentik login returns but the user is not signed in

Likely class:

- cookie-domain or session-order regression

Use:

- [site-down.md](site-down.md) issue `7a`
- `scripts/qa/verify-oidc-cookie-middleware-order.sh`
- `scripts/qa/verify-auth-surfaces.sh`

### 2. Studio or auth callbacks treat HTTPS traffic as HTTP

Likely class:

- forwarded-header normalization regression

Use:

- [site-down.md](site-down.md) issue `7a2`
- the rendered middleware order/settings evidence

### 3. MFE login page shows empty OAuth providers

Likely class:

- `mfe_oauth_fix` not installed, not loaded, or not mutating the response as
  expected

Use:

- [architecture/MFE_OAUTH_FIX_DEPLOYMENT.md](architecture/MFE_OAUTH_FIX_DEPLOYMENT.md)
- `scripts/qa/test-mfe-oauth-fix.sh`

### 4. Prometheus scrape sees `DisallowedHost` or `/metrics` regressions

Likely class:

- forwarded-header or host-rewrite regression
- `openedx_prometheus` not installed or not mounted correctly

Use:

- `curl` or in-cluster endpoint checks
- the patch inventory and rendered settings evidence

### 5. Platform-admin escalation behaves inconsistently

Likely class:

- platform-admin middleware not loaded
- canonical admin email set missing or drifted
- a user/email collision is being misread as expected elevation

Use:

- rendered settings and env evidence for the platform-admin email source
- middleware verification first, then source/config ownership

### 6. Middleware order changed after Tutor regeneration or patch refresh

Likely class:

- rendered settings drift
- patch injection drift
- custom-app install path drift

Use:

- `scripts/qa/verify-middleware-order.sh`
- `scripts/qa/verify-tutor-patches.sh`
- [../../reference/architecture/TUTOR_PATCHES_INVENTORY.md](../../reference/architecture/TUTOR_PATCHES_INVENTORY.md)

## Recovery Principles

- fix ordering and app-installation problems in source, not by hot-patching
  live containers
- treat rendered Tutor settings and build patches as part of the root cause
- preserve current-lane proof after the fix, especially for auth and metrics
- separate middleware-order bugs from higher-layer auth symptoms before
  selecting the owner doc or code path

## Evidence Expectations

Any middleware incident should leave:

- failing host/path
- middleware or app component involved
- rendered-settings or runtime proof of the bad state
- source fix location
- post-fix verification evidence

## Related

- Verification: [MIDDLEWARE_VERIFICATION.md](MIDDLEWARE_VERIFICATION.md)
- Runtime incidents: [site-down.md](site-down.md)
- MFE OAuth detail: [architecture/MFE_OAUTH_FIX_DEPLOYMENT.md](architecture/MFE_OAUTH_FIX_DEPLOYMENT.md)
- Patch inventory: [../../reference/architecture/TUTOR_PATCHES_INVENTORY.md](../../reference/architecture/TUTOR_PATCHES_INVENTORY.md)
