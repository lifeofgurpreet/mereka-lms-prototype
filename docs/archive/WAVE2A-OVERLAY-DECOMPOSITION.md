# Wave 2A — Overlay Decomposition (Frontend/Routing/Theming Slice)

Date: 2026-03-16

## Frontend/Routing/Theming Override Map

### Keys in BOTH repos before Wave 2A (13 total)

| Key | Base Value | Overlay | Classification | Action |
|-----|-----------|---------|----------------|--------|
| ENABLE_ASSETS_PAGE | "true" | "true" | **Redundant literal** | REMOVED |
| ENABLE_HOME_PAGE_COURSE_API_V2 | "true" | "true" | **Redundant literal** | REMOVED |
| ENABLE_PROGRESS_GRAPH_SETTINGS | "true" | "true" | **Redundant literal** | REMOVED |
| ENABLE_TAGGING_TAXONOMY_PAGES | "true" | "true" | **Redundant literal** | REMOVED |
| SCHEDULE_EMAIL_SECTION | True | True | **Redundant literal** | REMOVED |
| INDIGO_ENABLE_DARK_TOGGLE | True | True | **Redundant literal** | REMOVED |
| ACCOUNT_SETTINGS_URL | from variable | same variable | **Redundant derivation** | REMOVED |
| DISCUSSIONS_MFE_BASE_URL | from variable | same variable | **Redundant derivation** | REMOVED |
| ECOMMERCE_BASE_URL | from variable | same variable | **Redundant derivation** | REMOVED |
| ORDER_HISTORY_URL | from variable | same variable | **Redundant derivation** | REMOVED |
| COURSE_AUTHORING_MICROFRONTEND_URL | from base URL | hardcoded URL | Env override | RETAINED |
| LEARNING_BASE_URL | from base URL | hardcoded URL | Env override | RETAINED |
| ACCOUNT_PROFILE_URL | from variable | hardcoded URL | Env override | RETAINED |
| DISABLE_ENTERPRISE_LOGIN | from env var | True | Policy override | RETAINED |

### Keys ONLY in overlay (11 — all env-specific URLs)

| Key | Justification |
|-----|---------------|
| BASE_URL, LMS_BASE_URL, LOGIN_URL, LOGOUT_URL | Env hostname |
| MARKETING_SITE_BASE_URL, STUDIO_BASE_URL | Env hostname |
| DISCOVERY_API_BASE_URL | Env hostname |
| FAVICON_URL, LOGO_URL, LOGO_WHITE_URL, LOGO_TRADEMARK_URL | Env MFE host prefix |

These are legitimate environment wiring — they derive from
env-specific hostnames that differ between dev/staging/prod.

## Extraction Slice

**10 redundant MFE_CONFIG keys removed from dev overlay.**

Chosen because:
- Zero runtime risk — base produces identical values
- This is exactly the class of duplication that caused the
  Studio URL incident
- Removes 10 potential future contradiction points

## What Was Deleted / Moved / Retained

**Deleted from overlay** (10 keys):
- 6 identical literals (feature flags)
- 4 same-derivation variable references

**Retained in overlay** (4 keys):
- COURSE_AUTHORING_MICROFRONTEND_URL — env-specific URL
- LEARNING_BASE_URL — env-specific URL
- ACCOUNT_PROFILE_URL — env-specific URL
- DISABLE_ENTERPRISE_LOGIN — env-specific policy

**Retained values are legitimate** because they supply
environment-specific hostnames that the base can't determine.

## Anti-Regression Guard

Added to `verify-settings-ownership.sh`:

1. **Comment-line exclusion**: grep now skips `#` comment lines
   when extracting MFE_CONFIG keys (fixes false positives)

2. **Blocklist**: 6 app-owned keys are explicitly blocklisted.
   If they reappear in the overlay, CI fails immediately:
   - ENABLE_ASSETS_PAGE
   - ENABLE_HOME_PAGE_COURSE_API_V2
   - ENABLE_PROGRESS_GRAPH_SETTINGS
   - ENABLE_TAGGING_TAXONOMY_PAGES
   - SCHEDULE_EMAIL_SECTION
   - INDIGO_ENABLE_DARK_TOGGLE

## Runtime Proof

| Route | Status |
|-------|--------|
| /authn/login | 200 |
| /account | 200 |
| /authoring/home | 200 |
| /courses | 200 + 4 mereka CSS refs |
| /dashboard | 302 (expected) |
| COURSE_AUTHORING_MICROFRONTEND_URL | /authoring |
| ACCOUNT_SETTINGS_URL | /account/ |

## Remaining Wave 2 Debt

The dev overlay (`production-staging.py`) went from 1069 to ~1059
lines. The reduction is small because this slice targeted only
MFE_CONFIG key duplication, not the broader behavioral logic.

Remaining categories for future waves:

| Category | Est. Lines | Wave |
|----------|-----------|------|
| OIDC/auth logic | ~200 | 2B |
| Enterprise/catalog config | ~100 | 2C |
| Monitoring/metrics wiring | ~80 | 2D |
| CORS/CSRF/cookie logic | ~60 | 2E |
| Remaining env-URL derivation | ~150 | 2F |
| Multisite/site-config logic | ~80 | Already in base (Wave 1) |

## Recommended Wave 2B

**Target**: OIDC/auth logic in the overlay (~200 lines).
This includes Authentik configuration, OIDC backend registration,
session/cookie settings, and OAuth2 provider setup.

**Why**: Auth logic is app behavior, not environment wiring.
The overlay should only supply the Authentik hostname and client
credentials, not the entire OIDC integration pattern.
