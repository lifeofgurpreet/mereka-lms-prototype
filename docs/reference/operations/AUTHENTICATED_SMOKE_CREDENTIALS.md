# Authenticated Smoke Credentials Reference
_Audience: Platform Operators • Owner: Platform Team • Last verified: 2026-03-27 • Status: canonical_

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
- the manual `smoke-authenticated.yml` workflow defaults to `env_scope=staging`
- prod smoke and canary execution remain explicit opt-in paths, not the default proof lane

## Test user requirements

- each smoke user or canary user must be a real test user account with a working login for its target environment
- the staging canary user is the canonical default proof identity for the authenticated smoke lane
- prod smoke users are maintained only for explicit prod verification and should not be treated as the default test account

## Credential rotation

- rotate smoke and canary credentials in GitHub secrets whenever the underlying test user password changes
- update the matching `SSO_CANARY_*` or `SMOKE_SSO_*` secret family for the affected environment in the same change window
- re-run `bash scripts/qa/verify-authenticated-ui-smoke.sh` after rotation to confirm the workflow wiring still matches the expected secret contract

## Read next

- [`../../ops/runbooks/VISUAL_SMOKE_BASELINE.md`](../../ops/runbooks/VISUAL_SMOKE_BASELINE.md)
- [`SSO_CANARY.md`](SSO_CANARY.md)
- `.github/workflows/smoke-authenticated.yml`

## Verification

- `bash scripts/qa/verify-authenticated-ui-smoke.sh`
- `bash scripts/qa/verify-visual-smoke-baseline.sh`
