# Environment Parity + Auth Recurrence Eradication

Date: 2026-03-16

## Dev vs Staging Parity Matrix

### Build Identity

| Component | Dev | Staging | Same? |
|-----------|-----|---------|-------|
| LMS image | openedx:8a7f2476 | openedx:d7f015d2 | **NO** |
| CMS image | openedx:8a7f2476 | openedx:d7f015d2 | **NO** |
| MFE image | mfe:e6adf950 | mfe:d7f015d2 | **NO** |

Images differ. Staging uses an older build (d7f015d2) while dev
uses a newer one (8a7f2476). This explains visual/UI differences.
Image parity is an intentional promotion pipeline concern, not
a settings bug.

### Auth/Session Config (before fix)

| Setting | Dev | Staging | App Base | Correct? |
|---------|-----|---------|----------|----------|
| SESSION_COOKIE_SAMESITE | "None" | **"Lax"** | "None" | Staging WRONG |
| CSRF_COOKIE_SAMESITE | "None" | **not set** | "None" | Staging WRONG |
| SESSION_COOKIE_DOMAIN | ".academyv2.mereka.dev" | None | None | Both use middleware |
| CSRF_COOKIE_DOMAIN | ".academyv2.mereka.dev" | None | None | Both use middleware |

### Auth/Session Config (after fix — PR #1859)

| Setting | Dev | Staging | Parity? |
|---------|-----|---------|---------|
| SESSION_COOKIE_SAMESITE | "None" | "None" | YES |
| CSRF_COOKIE_SAMESITE | "None" | "None" | YES |

### MFE Config

| Key | Dev | Staging (before) | Staging (after) |
|-----|-----|-------------------|-----------------|
| COURSE_AUTHORING_URL | /authoring | /course-authoring | /authoring |
| Redundant MFE keys | Removed (Wave 2A) | Present | Removed |

## Staging Login Failure Root Cause

**SESSION_COOKIE_SAMESITE = "Lax"** in the staging overlay.

The OIDC login flow traverses: `staging.academyv2.mereka.io` →
`auth0.mereka.dev` (Authentik) → `staging.academyv2.mereka.io`.
With SameSite=Lax, the session cookie set during `/auth/login/oidc/`
is not reliably sent during the Authentik callback redirect because
the redirect is cross-site (different registrable domain). The user
appears to log in successfully but the session is lost.

The dev overlay had the same bug historically and was fixed with
explicit comments documenting the failure. The staging overlay was
never updated.

## Why UI Looks Different Between Environments

**Different MFE images.** Dev runs `mfe:e6adf950` (newer). Staging
runs `mfe:d7f015d2` (older). The MFE image contains the compiled
React bundles, Paragon theme CSS, and branding assets. Different
images = different visual state.

This is NOT a settings/config issue. It is an image promotion
pipeline concern. The intended flow is: dev gets new images first,
then staging, then prod. The visual difference is expected during
the promotion gap.

## Fixes Landed

### PR #1859 (bbi-infrastructure)
- SESSION_COOKIE_SAMESITE: "Lax" → "None"
- CSRF_COOKIE_SAMESITE: added "None"
- COURSE_AUTHORING_MICROFRONTEND_URL: /course-authoring → /authoring
- 11 redundant MFE_CONFIG keys removed (Wave 2A parity)
- 2 redundant auth settings removed (Wave 2B parity)
- 1 redundant INDIGO_ENABLE_DARK_TOGGLE removed

### Anti-recurrence guard
- verify-env-auth-parity.sh: checks SESSION_COOKIE_SAMESITE and
  CSRF_COOKIE_SAMESITE are consistent across all overlays
- Registered in CI scripts list

## Accepted Environment Differences

| Difference | Reason | Intentional? |
|------------|--------|-------------|
| Different image tags | Promotion pipeline | YES |
| Different hostnames/domains | Env-specific | YES |
| Different cookie domains | Env-specific (middleware handles) | YES |
| Different OIDC endpoints | Env-specific Authentik instances | YES |

## Recommended Next Lane

**Wave 2C**: MerekaCookieDomainMiddleware + patch_sites_framework
extraction. ~110 lines of app behavior in overlay → move to app
repo as importable modules.

Alternatively: **Image promotion pipeline** — establish a governed
promotion path so staging catches up to dev image tags automatically.
