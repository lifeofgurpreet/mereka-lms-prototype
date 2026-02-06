# Auth Hardening Spec
_Last updated: 2026-02-06_

## Goals

1. Remove “tribal knowledge” from authentication and permissions.
2. Make admin access consistent across the Open edX ecosystem.
3. Make drift detectable (CI) and self-healing (runtime backstops + idempotent scripts).

## Scope (Current Ecosystem)

Core:
- LMS (`academyv2.mereka.io`)
- Studio/CMS (`studio.academyv2.mereka.io`)
- MFE Apps (`apps.academyv2.mereka.io`)

Ecosystem services:
- Discovery (`discovery.academyv2.mereka.io`)
- Credentials (`credentials.academyv2.mereka.io`)
- Ecommerce (`ecommerce.academyv2.mereka.io`)
- Authentik (`auth0.mereka.io`)

## Policy

Platform admins (Open edX ecosystem):
- `gurpreet@biji-biji.com`
- `malasari@mereka.my`

Authentik admin (separate):
- Gurpreet only

## Implementation (What We Built)

### 1) Idempotent enforcement scripts

- `scripts/infra/ensure-platform-admins.sh`
  - Ensures platform admins are staff/superuser everywhere, and CourseCreator is granted in CMS.
  - Runs on both prod + dev contexts.

- `scripts/infra/ensure-authentik-admin.sh`
  - Ensures only Gurpreet is in Authentik `authentik Admins` group.

### 2) Runtime hardening (prevents drift)

K8s injects `MEREKA_PLATFORM_ADMIN_EMAILS` into LMS/CMS/Discovery/Credentials/Ecommerce.

Each service includes a small middleware:
- If an authenticated user is in `MEREKA_PLATFORM_ADMIN_EMAILS`, ensure `is_active/is_staff/is_superuser`.
- For CMS: also ensure `CourseCreator(state=granted, all_organizations=True)`.
- For Discovery/Credentials/Ecommerce: redirect `/admin/login/` to `/login/` so admin access always starts from SSO.

### 3) Verification (no credentials)

- `scripts/qa/verify-auth-surfaces.sh {prod|dev}`
  - LMS OIDC entrypoint redirects to Authentik authorize
  - Discovery/Credentials/Ecommerce `/login/` redirects to `/login/edx-oauth2/`
  - (Optional strict mode) `/admin/login/` redirects to `/login/`

### 4) Continuous verification (CI)

The existing `.github/workflows/public-health-check.yml` now runs:
- `./scripts/qa/verify-auth-surfaces.sh prod`
- `./scripts/qa/verify-auth-surfaces.sh dev`

## Acceptance Criteria

1. `./scripts/qa/verify-auth-surfaces.sh prod` passes in CI.
2. `./scripts/qa/verify-auth-surfaces.sh dev` passes in CI.
3. `./scripts/infra/ensure-platform-admins.sh --verify` reports OK for both contexts.
4. `./scripts/infra/ensure-authentik-admin.sh --verify` reports OK.
5. Gurpreet + Malasari can:
   - create courses in Studio
   - access LMS Django admin
   - access Discovery/Credentials/Ecommerce admin after SSO login

## Future Hardening (Optional)

If you want true “role sync” (instead of a platform-admin allowlist), the next step is:
- Authentik: emit a stable claim like `groups: ["platform-admin"]`
- LMS: map that claim to Open edX authorization
- Services: propagate from LMS via edx-oauth2 userinfo and map into local staff/superuser

This is higher-risk because it expands the trusted surface area for privilege escalation; the current allowlist approach is intentionally tight.

