# Wave 2B — Auth/OIDC/Session Overlay Decomposition

Date: 2026-03-16

## Auth/Session Override Map

### Settings removed from overlay (10)

| Setting | Base Value | Overlay Value | Classification |
|---------|-----------|---------------|---------------|
| SESSION_COOKIE_SAMESITE | "None" | "None" | Redundant |
| CSRF_COOKIE_SAMESITE | "None" | "None" | Redundant |
| SESSION_COOKIE_SECURE | True | True | Redundant |
| CSRF_COOKIE_SECURE | True | True | Redundant |
| OAUTH_ENFORCE_SECURE | False | False | Redundant |
| CORS_ORIGIN_ALLOW_ALL | False | False | Redundant |
| ENABLE_AUTHN_MICROFRONTEND | True | True | Redundant |
| ENABLE_THIRD_PARTY_AUTH | True | True | Redundant |
| ENABLE_OAUTH2_PROVIDER | not in base | True | Moved to base |
| ENABLE_NEW_BULK_EMAIL_EXPERIENCE | True | True | Redundant |
| JWT_AUTH["JWT_AUDIENCE"] | "openedx" | "openedx" | Redundant |

### Settings retained in overlay (legitimate env wiring)

| Setting | Why retained |
|---------|-------------|
| JWT_AUTH["JWT_ISSUER"] | Env-specific URL |
| JWT_AUTH["JWT_SECRET_KEY"] | Env-specific secret ref |
| JWT_AUTH["JWT_PRIVATE_SIGNING_JWK"] | Env-specific secret ref |
| JWT key derivation block | Structurally tied to JWT_ISSUER |
| SESSION_COOKIE_DOMAIN | Env-specific domain (.academyv2.mereka.dev) |
| CSRF_COOKIE_DOMAIN | Env-specific domain |
| SOCIAL_AUTH_OIDC_OIDC_ENDPOINT | Env-specific Authentik URL |
| MerekaCookieDomainMiddleware | Complex app behavior — deferred to Wave 2C |

## Extraction Slice

10 redundant auth/session settings removed from the dev overlay.
1 missing feature flag (ENABLE_OAUTH2_PROVIDER) moved to app-repo base.

## Guardrail Landed

Auth-specific blocklist in `verify-settings-ownership.sh`:
- 6 Django settings blocklisted: SESSION_COOKIE_SAMESITE, CSRF_COOKIE_SAMESITE, SESSION_COOKIE_SECURE, CSRF_COOKIE_SECURE, OAUTH_ENFORCE_SECURE, CORS_ORIGIN_ALLOW_ALL
- 4 FEATURES blocklisted: ENABLE_AUTHN_MICROFRONTEND, ENABLE_THIRD_PARTY_AUTH, ENABLE_OAUTH2_PROVIDER, ENABLE_NEW_BULK_EMAIL_EXPERIENCE

## Remaining Auth-Related Overlay Debt

| Item | Lines | Wave |
|------|-------|------|
| MerekaCookieDomainMiddleware | ~80 | 2C |
| Site resolution logic (patch_sites_framework) | ~30 | 2C |
| OIDC env-specific endpoint config | ~10 | Retained (env wiring) |
| JWT env-specific issuer/key block | ~30 | Retained (env wiring) |
| ALLOWED_HOSTS list | ~20 | Retained (env wiring) |
| CORS/CSRF origin whitelist population | ~15 | Retained (env wiring) |

## Recommended Wave 2C

**Target**: MerekaCookieDomainMiddleware + patch_sites_framework.
These are ~110 lines of pure application behavior (cookie domain
resolution, site framework patching) currently in the dev overlay.
They should move to the app-repo base as importable modules.
