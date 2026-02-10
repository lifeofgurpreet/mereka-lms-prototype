# Auth Hardening Spec
_Last updated: 2026-02-10_

## Goals

1. Remove “tribal knowledge” from authentication and permissions.
2. Make admin access consistent across the Open edX ecosystem.
3. Make drift detectable (CI) and self-healing (runtime backstops + idempotent scripts).

## Scope (Current Ecosystem)

Core:
- LMS microsites:
  - `academyv2.mereka.io`
  - `preview.academyv2.mereka.io` (alias)
  - `academy.biji-biji.com`
  - `skillourfuture.academy.mereka.io`
- Studio/CMS:
  - `studio.academyv2.mereka.io`
  - `studio.academy.biji-biji.com`
- MFE Apps:
  - `apps.academyv2.mereka.io`
  - `apps.academy.biji-biji.com`

Ecosystem services:
- Discovery (`discovery.academyv2.mereka.io`)
- Credentials (`credentials.academyv2.mereka.io`)
- Ecommerce (`ecommerce.academyv2.mereka.io`)
- Notes (`notes.academyv2.mereka.io`) (API-first)
- Forum (`forum.academyv2.mereka.io`) (API-first; UI is embedded in LMS)
- Authentik (`auth0.mereka.io`)

Canonical hostname list:
- `docs/operations/OPENEDX_HOSTNAMES.md`

## Policy

Platform admins (Open edX ecosystem):
- `gurpreet@biji-biji.com`
- `malasari@mereka.my`

Authentik admin (separate):
- Gurpreet only

## Implementation (What We Built)

### 1) Idempotent enforcement scripts

- `scripts/infra/ensure-platform-admins.sh`
  - Ensures platform admins are staff/superuser everywhere, CourseCreator is granted in CMS, and org roles (`OrgStaffRole` + `OrgInstructorRole`) are present for every active org in LMS.
  - Runs on both prod + dev contexts.

- `scripts/infra/ensure-authentik-admin.sh`
  - Ensures only Gurpreet is in Authentik `authentik Admins` group.

- `scripts/infra/ensure-authentik-admin-mfa.sh`
  - Requires MFA for Authentik admins only (gated by `authentik Admins` group membership).
  - Does not force MFA for normal LMS users.

- `scripts/infra/ensure-authentik-oidc-redirect-uris.sh`
  - Ensures Authentik OIDC redirect URIs include **every LMS hostname** we serve (microsites + aliases + dev).
  - Prevents “redirect_uri mismatch” breakages when adding domains.

- `scripts/infra/ensure-authentik-hardening.sh`
  - Single entrypoint to `--verify`/`--apply` all Authentik hardening (admin policy, redirect URI allowlist, admin MFA).

### 2) Runtime hardening (prevents drift)

K8s injects `MEREKA_PLATFORM_ADMIN_EMAILS` into LMS/CMS/Discovery/Credentials/Ecommerce.

Each service includes a small middleware:
- If an authenticated user is in `MEREKA_PLATFORM_ADMIN_EMAILS`, ensure `is_active/is_staff/is_superuser`.
- For CMS: also ensure `CourseCreator(state=granted, all_organizations=True)`.
- For Discovery/Credentials/Ecommerce: redirect `/admin/login/` to `/login/` so admin access always starts from SSO.

LMS/CMS also include multisite hardening middleware:
- Resolves the current "tenant site" based on request host (apps./studio./preview. map to the tenant LMS domain)
- Rewrites cookie domains per-request so we never emit invalid cookie `Domain=` across different roots (`mereka.io` vs `biji-biji.com`)
- Normalizes multi-valued forwarded headers (`X-Forwarded-Proto`, etc.) so Django reliably detects HTTPS behind Cloudflare/Ingress.
  (Prevents Studio from generating `next=http://...` URLs and breaking OAuth callback state.)

### 3) Verification (no credentials)

- `scripts/qa/verify-auth-surfaces.sh {prod|dev}`
  - LMS OIDC entrypoint redirects to Authentik authorize
  - Preview alias domain OIDC entrypoint redirects to Authentik authorize
  - Studio `/signin` redirects to the correct LMS `/login` for the microsite
  - Studio home page MUST NOT contain insecure `next=http://...` links (proxy forwarded-proto drift guard)
  - Biji MFE config must point to `academy.biji-biji.com` + `studio.academy.biji-biji.com`
  - Discovery/Credentials/Ecommerce `/login/` redirects to `/login/edx-oauth2/`
  - (Optional strict mode) `/admin/login/` redirects to `/login/`
  - Notes: must return an API banner (API-first, no SSO UI)
  - Forum: must return `401` unauthenticated (API-first, no SSO UI)

- `scripts/qa/list-openedx-hostnames.sh --env prod|dev|both`
  - Compares expected hostnames (from `scripts/shared/config.sh`) vs deployed Ingress hosts (prod + dev).

### 3.2) Operator audit report (verify-only)

For one consolidated report (good for tickets / incident notes):

```bash
./scripts/qa/audit-auth-access.sh --env both --mode all
```

It aggregates:
- public auth surface checks
- platform admin permission verification
- Authentik admin policy + redirect URI allowlist verification
- multisite + org-role ownership + OIDC provider config verification
- OIDC user password-state verification (detects disabled-account regression)
- hostname registry drift checks

### 3.1) Internal verification (kubectl, no secrets)

- `scripts/qa/verify-oidc-provider-configs.sh`
  - Verifies the **latest** `OAuth2ProviderConfig` for `backend_name=oidc` is enabled/visible for the configured sites.
  - Verifies the latest config resolves a **non-empty effective secret** (`get_setting("SECRET")`).
  - Verifies provider display name contract (default: `Sign in with Mereka`).
  - This directly prevents `/auth/login/oidc/` from 500ing with "Can't fetch setting of a disabled backend/provider."
  - This also prevents callback regressions where token exchange fails with `Invalid client secret`.
  - Domain coverage is derived from `scripts/shared/config.sh`:
    - prod: `academyv2.mereka.io`, `academy.biji-biji.com`, `skillourfuture.academy.mereka.io`
    - dev: `academyv2.mereka.dev`
  - By default it runs with `--env auto`, which infers prod vs dev from the kube context name (`kind*` => dev).

- `scripts/qa/verify-oidc-user-password-state.sh`
  - Verifies active OIDC-linked users do not have unusable LMS passwords.
  - Prevents callback/session failures that surface as `Your account is disabled`.
  - Optional remediation mode (`--fix`) sets strong random passwords for affected active OIDC users.

### 3.3) Credentialed callback/session verification (browser canary)

- `scripts/qa/verify-authenticated-sso-canary.sh --env prod|dev|both`
  - Runs a real browser OIDC login flow:
    - `/auth/login/oidc/` -> Authentik login form -> `/auth/complete/oidc/` callback
  - Verifies the post-login browser session can access `/api/user/v1/me` (expects HTTP 200).
  - Verifies dashboard navigation stays authenticated (does not bounce to login/Auth0).
  - Writes failure screenshots to `var/auth-sso-canary/`.
  - Uses env-only secrets (never CLI args):
    - `SSO_CANARY_EMAIL[_PROD|_DEV]`
    - `SSO_CANARY_PASSWORD[_PROD|_DEV]`
  - Integration flags:
    - `RUN_AUTHENTICATED_SSO_CANARY=1`
    - `AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1`
  - GitHub wiring helpers:
    - Audit wiring status:
      - `./scripts/qa/audit-authenticated-sso-canary-wiring.sh`
      - `STRICT=1 ./scripts/qa/audit-authenticated-sso-canary-wiring.sh`
    - Configure repo secrets/variable:
      - `SSO_CANARY_EMAIL_PROD=... SSO_CANARY_PASSWORD_PROD=... ./scripts/infra/configure-github-authenticated-sso-canary.sh --enable-runtime-gate`

### 4) Continuous verification (CI)

The existing `.github/workflows/public-health-check.yml` now runs:
- `./scripts/qa/verify-auth-surfaces.sh prod`
- `./scripts/qa/verify-auth-surfaces.sh dev`

## Acceptance Criteria

1. `./scripts/qa/verify-auth-surfaces.sh prod` passes in CI.
2. `./scripts/qa/verify-auth-surfaces.sh dev` passes in CI.
3. `./scripts/infra/ensure-platform-admins.sh --verify` reports OK for both contexts.
4. `./scripts/infra/ensure-authentik-admin.sh --verify` reports OK.
5. `./scripts/infra/ensure-authentik-admin-mfa.sh --verify` reports OK.
6. `./scripts/infra/ensure-authentik-hardening.sh --verify` reports OK.
7. `STRICT=1 ./scripts/qa/verify-multisite-config.sh` reports correct multisite governance values per microsite:
   `SiteConfiguration.enabled=true`, LMS/CMS/MFE roots, `THEME_NAME`, and `course_org_filter`.
   (Use `STRICT=1 ./scripts/qa/verify-multisite-config.sh prod` explicitly when running from a laptop.)
8. `STRICT=1 ./scripts/qa/verify-org-role-ownership.sh both` passes:
   each org exists and has staff/instructor ownership, and both platform admins hold both org roles.
9. Gurpreet + Malasari can:
   - create courses in Studio
   - access LMS Django admin
   - access Discovery/Credentials/Ecommerce admin after SSO login
10. `./scripts/qa/verify-oidc-provider-configs.sh` passes (operator run).
11. Authentik logs do not show `Invalid client secret` for `client_id=mereka-lms` during SSO callback tests.
12. `./scripts/qa/verify-oidc-user-password-state.sh --env prod` passes (no affected active OIDC users).
13. `./scripts/qa/verify-authenticated-sso-canary.sh --env prod` passes with dedicated canary credentials.
14. `STRICT=1 ./scripts/qa/audit-authenticated-sso-canary-wiring.sh` passes:
    runtime workflow contract is present, prod canary secrets exist, and `RUN_AUTHENTICATED_SSO_CANARY=true` is set.

Convenience:
- `CHECK_TIMEOUT_SECONDS=300 ./scripts/qa/verify-auth-hardening.sh --env both --mode all`
  runs the full suite (public + internal) with bounded per-check timeouts.
- `./scripts/gen/update-openedx-hostnames-doc.sh` regenerates `docs/operations/OPENEDX_HOSTNAMES.md`.
- `./scripts/qa/verify-atlas-modulestore-path.sh --mode all` verifies modulestore remains Atlas-backed (repo + runtime).
- `./scripts/qa/verify-alert-routing.sh` verifies runtime alert policies/channels and routing health.
- `CHECK_TIMEOUT_SECONDS=1200 ./scripts/qa/run-operations-gates.sh --env both`
  runs consolidated auth + observability + Velero + Grafana gates.
- `RUN_AUTHENTICATED_SSO_CANARY=1 AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1 ./scripts/qa/run-operations-gates.sh --env prod`
  enables callback/session canary enforcement inside the consolidated gate.

## Future Hardening (Optional)

If you want true “role sync” (instead of a platform-admin allowlist), the next step is:
- Authentik: emit a stable claim like `groups: ["platform-admin"]`
- LMS: map that claim to Open edX authorization
- Services: propagate from LMS via edx-oauth2 userinfo and map into local staff/superuser

This is higher-risk because it expands the trusted surface area for privilege escalation; the current allowlist approach is intentionally tight.
