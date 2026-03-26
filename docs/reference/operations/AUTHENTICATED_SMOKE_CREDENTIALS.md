# Authenticated Smoke Credentials Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-26 • Status: canonical_

This reference records how authenticated smoke credentials are handled.

## Current credential model

- Credentials are injected by environment variables, never hardcoded in docs or scripts.
- The standard variables are:
  - `SSO_USERNAME`
  - `SSO_PASSWORD`
  - `VISUAL_SMOKE_DOMAIN`
- GitHub Actions uses dedicated secrets for smoke and canary flows.

## Current operational use

- authenticated visual smoke and screenshot capture
- SSO canary verification
- post-login regression checks for learner and operator surfaces
- canonical staging proof lanes wire `env_scope=staging` through `.github/workflows/smoke-authenticated.yml` while keeping credentials env-injected

## Read next

- [`../../ops/runbooks/VISUAL_SMOKE_BASELINE.md`](../../ops/runbooks/VISUAL_SMOKE_BASELINE.md)
- [`SSO_CANARY.md`](SSO_CANARY.md)
- `.github/workflows/smoke-authenticated.yml`

## Verification

- `bash scripts/qa/verify-authenticated-ui-smoke.sh`
- `bash scripts/qa/verify-visual-smoke-baseline.sh`
