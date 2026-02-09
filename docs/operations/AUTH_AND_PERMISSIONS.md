# Authentication and Permissions (Open edX + Authentik)
_Last updated: 2026-02-07_

This document explains how authentication (login) and authorization (permissions) work in the Mereka Open edX ecosystem.

## Summary

- **Authentik (OIDC)** answers: "Who are you?"
- **Open edX (LMS/CMS)** and **other Django services** (Discovery, Credentials, Ecommerce) answer: "What can you do?"

By default, **permissions do not sync from Authentik into Open edX**. Logging in via OIDC will create/link a user account, but **staff/superuser** and **CourseCreator** are controlled in each service database.

## Multisite Reality (Multiple Domains)

This platform serves multiple "microsite" domains from the same Open edX stack:
- `academyv2.mereka.io` (primary)
- `academy.biji-biji.com` (Biji microsite)
- `skillourfuture.academy.mereka.io` (Skillourfuture microsite)

Canonical hostname registry (includes aliases like Preview and all ecosystem services):
- `docs/operations/OPENEDX_HOSTNAMES.md`

Implications:
- Sessions do **not** carry across different root domains (expected).
- Studio and MFEs must still redirect to the **correct** LMS domain for the microsite, otherwise SSO looks "missing" even when Authentik is fine.

## Required Platform Admins

These humans must have full permissions in production and dev:
- `gurpreet@biji-biji.com`
- `malasari@mereka.my`

Enforce (idempotent):
```bash
./scripts/infra/ensure-platform-admins.sh
```

This now also enforces org-level ownership roles in LMS:
- `OrgStaffRole`
- `OrgInstructorRole`
for each active organization (`MEREKA`, `BIJIBIJI`, `SKILLOURFUTURE`).

Hardening (prevents drift automatically at runtime):
- K8s sets `MEREKA_PLATFORM_ADMIN_EMAILS` for the core services.
- Each service adds a small middleware that:
  - keeps the listed users as staff/superuser
  - redirects `/admin/login/` to `/login/` (SSO entrypoint) for consistent UX in Discovery/Credentials/Ecommerce

## Access Control Matrix (What Is "Super Admin" Where?)

| Component | Authentication (Who are you?) | Authorization (What can you do?) | "Super admin" meaning | Where it is set | How we verify |
|---|---|---|---|---|---|
| Authentik (`auth0.mereka.io`) | Authentik login | Authentik groups/roles + MFA requirements | Authentik admin UI access | `scripts/infra/ensure-authentik-hardening.sh` | `scripts/infra/ensure-authentik-hardening.sh --verify` |
| LMS (Open edX) | OIDC via Authentik (plus optional native login) | Django user flags (`is_staff`, `is_superuser`) + org roles + per-course roles | `is_superuser=true` in LMS DB + org ownership roles | `scripts/infra/ensure-platform-admins.sh` + runtime allowlist (`MEREKA_PLATFORM_ADMIN_EMAILS`) | `scripts/infra/ensure-platform-admins.sh --verify` + `scripts/qa/verify-org-role-ownership.sh both` |
| CMS/Studio (Open edX) | Uses LMS session; `/signin` redirects to LMS `/login` | Django user flags + `CourseCreator` | `is_superuser=true` plus `CourseCreator(state=granted)` | `scripts/infra/ensure-platform-admins.sh` + runtime allowlist | `scripts/infra/ensure-platform-admins.sh --verify` |
| Discovery | OAuth to LMS (`/login/edx-oauth2/`) | Django user flags | `is_superuser=true` in Discovery DB | `scripts/infra/ensure-platform-admins.sh` + runtime allowlist | `scripts/infra/ensure-platform-admins.sh --verify` |
| Credentials | OAuth to LMS (`/login/edx-oauth2/`) | Django user flags | `is_superuser=true` in Credentials DB | `scripts/infra/ensure-platform-admins.sh` + runtime allowlist | `scripts/infra/ensure-platform-admins.sh --verify` |
| Ecommerce | OAuth to LMS (`/login/edx-oauth2/`) | Django user flags | `is_superuser=true` in Ecommerce DB | `scripts/infra/ensure-platform-admins.sh` + runtime allowlist | `scripts/infra/ensure-platform-admins.sh --verify` |
| Notes (`notes.*`) | API-first (used by LMS); no separate SSO UI | API permissions | Not an admin UI surface | N/A | `scripts/qa/verify-auth-surfaces.sh` (expects Notes API banner) |
| Forum (`forum.*`) | API-first (used by LMS); no separate SSO UI | API permissions | Not an admin UI surface | N/A | `scripts/qa/verify-auth-surfaces.sh` (expects `401` unauth) |

One-line answer to “am I super admin of everything?”:
- In the **Open edX ecosystem**, both Gurpreet and Malasari are enforced as `is_superuser` everywhere (LMS/CMS/Discovery/Credentials/Ecommerce).
- In **Authentik**, only Gurpreet is an admin.

## Authentik Admin (Separate)

Authentik has its own admin permissions which are **independent** of Open edX.

Policy:
- **Gurpreet** is an Authentik admin (superuser)
- **Malasari** is **not** an Authentik admin

Verify/apply:
```bash
./scripts/infra/ensure-authentik-admin.sh --verify
./scripts/infra/ensure-authentik-admin.sh --apply
```

Authentik admin MFA policy (required for Authentik admins only):
```bash
./scripts/infra/ensure-authentik-admin-mfa.sh --verify
./scripts/infra/ensure-authentik-admin-mfa.sh --apply
```

Recommended single entrypoint (runs admin policy + redirect URI allowlist + admin MFA):
```bash
./scripts/infra/ensure-authentik-hardening.sh --verify
./scripts/infra/ensure-authentik-hardening.sh --apply
```

## Open edX (LMS/CMS) Permission Levels

Global flags (site-wide):
- `is_active`: user can log in
- `is_staff`: enables staff UI features and can be granted Django admin access
- `is_superuser`: full Django admin (effectively "super admin" for LMS/CMS)

Studio course creation:
- `CourseCreator(state=granted)`: required for "New Course" to work in Studio

Per-course roles:
- Assigned in Studio (Course Team) and apply to a single course.

## How Login Works

### LMS/CMS

Two flows exist and should continue to work:
- **Native Open edX login**: `/login`
- **Authentik OIDC (SSO)**: `/auth/login/oidc/` then callback to `/auth/complete/oidc`

### Studio (Important)

Studio does not expose the LMS `/auth/login/oidc/` entrypoint. The canonical Studio entrypoint is:
- `/signin` (redirects to the matching LMS `/login`)

Expected behavior:
- `https://studio.academyv2.mereka.io/signin` redirects to `https://academyv2.mereka.io/login?...`
- `https://studio.academy.biji-biji.com/signin` redirects to `https://academy.biji-biji.com/login?...`

### Discovery/Credentials/Ecommerce Admin Access

These services have Django Admin sites (`/admin/`). By default, Django would render a username/password login at
`/admin/login/`, but we harden these services to **redirect `/admin/login/` to `/login/`** so admin access always
starts from SSO.

To access admin as a platform admin:
1. Log in via SSO first:
   - `https://discovery.academyv2.mereka.io/login/`
   - `https://credentials.academyv2.mereka.io/login/`
   - `https://ecommerce.academyv2.mereka.io/login/`
2. Then open `/admin/`

If you get a 403 after SSO, you are missing `is_staff` in that service; run:
```bash
./scripts/infra/ensure-platform-admins.sh
```

## Verification (Recommended)

These checks confirm that SSO entrypoints exist across the ecosystem.

### Public redirect checks (from your machine)

```bash
# LMS OIDC entrypoint (should 302 to Authentik)
curl -sS -I https://academyv2.mereka.io/auth/login/oidc/ | sed -n '1,8p'

# Services that use LMS OAuth (should 302 to /login/edx-oauth2/)
for svc in discovery credentials ecommerce; do
  echo "== $svc =="
  curl -sS -I "https://${svc}.academyv2.mereka.io/login/" | sed -n '1,8p'
done
```

For full auth-surface validation (including OIDC `sessionid` cookie `Domain=` checks and PKCE redirect markers):
```bash
./scripts/qa/verify-auth-surfaces.sh prod
```

For real callback/session validation (credentialed browser canary):
```bash
RUN_AUTHENTICATED_SSO_CANARY=1 AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1 \
  ./scripts/qa/verify-auth-hardening.sh --env prod --mode public
```
or direct:
```bash
./scripts/qa/verify-authenticated-sso-canary.sh --env prod
```

Canary wiring posture (workflow + GitHub secrets/variable):
```bash
./scripts/qa/audit-authenticated-sso-canary-wiring.sh
STRICT=1 ./scripts/qa/audit-authenticated-sso-canary-wiring.sh
```

### Cluster permission verification (prod + dev)

```bash
./scripts/infra/ensure-platform-admins.sh --verify
STRICT=1 ./scripts/qa/verify-org-role-ownership.sh both
```

### One report (recommended for ops tickets)

```bash
./scripts/qa/audit-auth-access.sh
```

This includes:
- Public auth surface checks (OIDC/OAuth redirects, admin-login redirect, MFE config)
- OIDC PKCE contract checks (`code_challenge_method` + `code_challenge` on `/auth/login/oidc/` redirects)
- Authentik hardening verification
- OIDC user password-state guard (`Your account is disabled` regression detector)
- Platform admin permission verification (DB flags + CourseCreator)
- Canonical hostname drift check (expected vs deployed)
- Service endpoint sanity (routes are wired)
- Course data sanity report (read-only, reports modulestore backend + counts)

To paste into tickets/Slack as JSON:
```bash
./scripts/qa/audit-auth-access.sh --json
```

Full operational gate (auth + multisite + observability + Velero + Grafana):
```bash
./scripts/qa/run-operations-gates.sh --env both
```

Dedicated multisite governance gate (site config + org ownership + auth surfaces + hostname drift):
```bash
CHECK_TIMEOUT_SECONDS=900 ./scripts/qa/run-multisite-governance-gates.sh --env both
```

Atlas path + alert routing guard (recommended before production rollout):
```bash
./scripts/qa/verify-atlas-modulestore-path.sh --mode all
./scripts/qa/verify-alert-routing.sh
```

Note:
- `run-operations-gates.sh` enables alert-routing verification by default.
- Set `RUN_AUTHENTICATED_SSO_CANARY=1` to include the credentialed SSO canary in consolidated gates.

### Multisite configuration verification (prod)

This checks that each microsite has a `Site` + `SiteConfiguration` and that
`LMS_ROOT_URL`/`CMS_ROOT_URL` are correct.

```bash
STRICT=1 ./scripts/qa/verify-multisite-config.sh prod
```

### OIDC provider config verification (prod + dev)

If `/auth/login/oidc/` 500s with "Can't fetch setting of a disabled backend/provider.", the
**OIDC provider config** is missing/disabled for the current site.

Verify (kubectl required, no secrets):
```bash
./scripts/qa/verify-oidc-provider-configs.sh
```

Notes:
- The script verifies the domains configured in `scripts/shared/config.sh` (prod vs dev).
- The script fails if the latest provider config resolves an empty secret (`get_setting("SECRET")`), which protects against Authentik token exchange failures (`Invalid client secret`).
- The script also enforces the provider display-name contract (`Sign in with Mereka`) by default.
- `OAuth2ProviderConfig` is a versioned ConfigurationModel. If you need to "fix" it,
  the safest approach is to **create a new enabled row** (do not try to edit old rows to
  disable them, that can create new versions and accidentally make a disabled version "current").

## What Does Not Sync (By Default)

- Authentik groups do not automatically map to Open edX `is_staff`/`is_superuser`.
- Open edX permissions do not flow back into Authentik.

If you want true role sync, the typical approach is:
- Add a stable claim (e.g., `groups`) in Authentik for "platform-admin"
- Add a custom social-auth pipeline step in each service to grant permissions based on that claim

This is not implemented today; we use an idempotent enforcement script instead.
