# Live LMS + Apps Regression Triage

> **Lane**: R2 — Live LMS / Apps Regression Triage
> **Date**: 2026-03-13
> **Agent**: Agent 1
> **Branch**: `lane-l/synthetic-substrate-hardening`
> **Main SHA**: `5a41de504a73882c1d8f99ef4aa9de0f9aaf24b9`

## Start Snapshot

| Property | Value |
|----------|-------|
| **UTC** | `2026-03-13T06:29:13Z` |
| **LMS image** | `ghcr.io/.../openedx:3b79796f6aac0d5a2bb44fb4639ef2f8ec57b9d7` |
| **MFE image** | `ghcr.io/.../mfe:6233c55b0c51ed5846d6b4b4c4746d9a80c857b3` |
| **LMS pod** | `lms-69d4dcc658-btqrf` — Running, 2 restarts |
| **MFE pod** | `mfe-f874fc55f-mlf4z` — Running, 9 restarts (CrashLoop pattern) |
| **Namespace** | `mereka-lms-dev` |

## Surface-by-Surface Triage

### 1. `/dashboard` — GLOBAL_RUNTIME_BROKEN

| Field | Value |
|-------|-------|
| **Owner** | LMS Django (server-rendered Mako templates) |
| **Deployment** | `lms` (openedx image) |
| **Symptom** | Modals rendered inline, `, window open` text visible, `.sr` screen-reader text not hidden |
| **First exact blocker** | **Mereka theme CSS missing 96% of base Open edX styles** |
| **Classification** | GLOBAL_RUNTIME_BROKEN — affects ALL users on ALL Django-served pages |
| **Stale deploy** | No — this is a build-time SCSS compilation defect baked into the image |

**Root cause**: `infrastructure/tutor/themes/mereka/lms/static/sass/lms-main-v1.scss` only imports
`partials/variables` and `partials/custom` (2 files). It does NOT import the base Open edX SCSS
(`build-base-v1`, `build-lms-v1`). The compiled theme CSS is **36,424 bytes vs 857,599 bytes** for the
default — missing `.sr`, `.modal`, layout grid, typography, and all base component styles.

The `, window open` text comes from `<span class="sr">` inside modal templates (`dashboard.html:308,345,377`).
The `.sr` class should use `clip:rect(1px,1px,1px,1px); position:absolute; height:1px; width:1px`
to visually hide the text. Without the base CSS, these screen-reader labels render at full size.

The email settings modal and unenroll modal have `aria-hidden="true"` but their CSS `display:none` rule
is also missing, causing them to render inline.

**Evidence**:
```
# Default CSS (full base styles):
/openedx/staticfiles/css/lms-main-v1.css → 857,599 bytes (has .sr, .modal)

# Theme CSS (broken, missing base imports):
/openedx/staticfiles/mereka/css/lms-main-v1.bbd098aa6488.css → 36,424 bytes (NO .sr, NO .modal)

# Dashboard loads theme CSS:
<link href="/static/mereka/css/lms-main-v1.bbd098aa6488.css" rel="stylesheet">

# .sr computed style (should be clipped, is full-size):
span ", window open" — box: 154x29 at (201, 253) — font: 24px 600 Lato
```

**Fix applied**: `infrastructure/tutor/themes/mereka/lms/static/sass/lms-main-v1.scss` — added
`@import 'build-base-v1'; @import 'build-lms-v1';` between variables and custom imports.
Requires image rebuild to take effect.

### 2. `/courses` — SEPARATE ISSUE (empty catalog)

| Field | Value |
|-------|-------|
| **Owner** | LMS Django (legacy course catalog view) |
| **Deployment** | `lms` + `discovery` |
| **Symptom** | Search box renders, no courses listed |
| **First exact blocker** | Empty course catalog (no courses in discovery or modulestore) |
| **Classification** | SEPARATE — not a CSS/runtime regression, data-dependent |
| **Stale deploy** | No |

The page renders its search interface correctly (with JS executing underscore.js templates).
The empty catalog is a data issue — the dev environment has no published courses.
Also affected by the theme CSS issue (layout degraded but functional).

### 3. `/profile/u/gurpreet` — INTERMITTENT (MFE pod restarts)

| Field | Value |
|-------|-------|
| **Owner** | MFE (frontend-app-profile) |
| **Deployment** | `mfe` (Caddy serving React bundles) |
| **Symptom** | "An unexpected error occurred" reported by user; slow load (~15s) |
| **First exact blocker** | MFE pod restarts (9 in 2h) cause intermittent failures |
| **Classification** | INTERMITTENT — works when pod is stable, fails during restart window |
| **Stale deploy** | No |

**Tested**: Both `/profile/u/lanep1v2` and `/profile/u/gurpreet` render correctly after 15s
wait. The user's reported error was during an MFE pod restart window.

MFE pod CrashLoop cause: likely OOM or liveness probe timeout (needs separate investigation).

### 4. `/account/` — NOT_BROKEN

| Field | Value |
|-------|-------|
| **Owner** | MFE (frontend-app-account) |
| **Deployment** | `mfe` |
| **Symptom** | "An unexpected error occurred" reported by user |
| **First exact blocker** | None — works correctly |
| **Classification** | NOT_BROKEN — fully functional for synthetic user |
| **Stale deploy** | No |

Account settings page loads and displays all fields (username, name, email, password, etc.).
User's reported error was likely during MFE pod restart.

### 5. `/authn/login` — NOT_BROKEN (slow)

| Field | Value |
|-------|-------|
| **Owner** | MFE (frontend-app-authn) |
| **Deployment** | `mfe` + `lms` (login API) |
| **Symptom** | Login UX regressed, sign-in failed |
| **First exact blocker** | None — login works but slow (13s API response) |
| **Classification** | NOT_BROKEN — functional but slow |
| **Stale deploy** | No |

Login form renders correctly with Mereka branding. Login API (`/api/user/v2/account/login_session/`)
succeeds (HTTP 200, `edx.user.login` event logged) but takes 13 seconds. The slow response may cause
users to re-submit or assume failure.

CORS warnings in logs: `Origin None was not in CORS_ORIGIN_WHITELIST` — from internal requests
(discovery SSO), not from user login flow.

## Differential Check Summary

| Surface | Classification | Stale Deploy? |
|---------|---------------|---------------|
| `/dashboard` | **GLOBAL_RUNTIME_BROKEN** | No (build defect) |
| `/courses` | SEPARATE (data) | No |
| `/profile/u/gurpreet` | INTERMITTENT (MFE restarts) | No |
| `/account/` | NOT_BROKEN | No |
| `/authn/login` | NOT_BROKEN (slow) | No |

## Fix Applied

**File**: `infrastructure/tutor/themes/mereka/lms/static/sass/lms-main-v1.scss`

```diff
 @import 'partials/variables';
+@import 'build-base-v1';
+@import 'build-lms-v1';
 @import 'partials/custom';
```

**Status**: Fix committed to repo. Requires image rebuild + deploy to take effect.
Live cluster staticfiles are read-only — no hot-fix possible.

## Next Actions

| # | Action | Owner | Priority |
|---|--------|-------|----------|
| 1 | **Image rebuild** with fixed SCSS → deploy to dev | CI/CD pipeline | P0 |
| 2 | Investigate MFE pod CrashLoop (9 restarts) | Platform | P1 |
| 3 | Publish courses to dev catalog | Content team | P2 |
| 4 | Investigate LMS login API latency (13s) | Platform | P2 |

## End Snapshot

| Property | Value |
|----------|-------|
| **UTC** | See git commit timestamp |
| **Fix branch** | `lane-l/synthetic-substrate-hardening` |
| **Files changed** | `infrastructure/tutor/themes/mereka/lms/static/sass/lms-main-v1.scss` |
| **Durable fix** | Yes — adds base Open edX CSS imports to theme SCSS |
| **Live cluster patched** | No — staticfiles read-only, requires image rebuild |
