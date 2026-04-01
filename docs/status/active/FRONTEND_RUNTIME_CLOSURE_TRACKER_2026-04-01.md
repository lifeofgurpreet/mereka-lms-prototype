# Frontend Runtime Closure Tracker (2026-04-01)

Flat backlog of every user-facing surface that needs audit, fix, or explicit deferral.
Three tenants: Mereka (default), Skill Our Future (SOF), Biji-Biji (BB).

## Verified State (with browser proof)

### A. Auth + Redirect Closure — PROVEN

| Surface | Main | BB | SOF | Evidence |
|---------|------|-----|-----|----------|
| `/login` redirect | `apps.academyv2.../authn/login` | `apps.biji-biji.../authn/login` | `apps.skillourfuture.../authn/login` | curl + screenshot |
| `/register` redirect | `apps.academyv2.../authn/register` | `apps.biji-biji.../authn/register` | `apps.skillourfuture.../authn/register` | curl |
| MFE login page identity | Magenta, M-mark, "Mereka Academy" | Black, hand logo, "Biji-Biji Academy" | Purple, 1°F logo, "Skill Our Future Academy" | screenshot |
| `/api/mfe_config/v1` AUTHN_MICROFRONTEND_URL | `apps.academyv2.../authn` | `apps.biji-biji.../authn` | `apps.skillourfuture.../authn` | curl |
| `/dashboard` unauthenticated | 302 → `/login?next=/dashboard` | 302 → `/login?next=/dashboard` | 302 → `/login?next=/dashboard` | curl |

**Root cause fixed**: bbi-infrastructure PR #2291 — stale inline `MerekaLoginRedirectMiddleware` in ConfigMap only handled `/login`. Synced with app repo's `mereka_multisite.py` to add `/register`, login_session, mfe_config rewriting. No image rebuild needed.

### B. `/dashboard` Ownership — CONFIG PROVEN, BROWSER PENDING

- `LEARNER_HOME_MICROFRONTEND_URL` = `https://apps.academyv2.mereka.dev/learner-dashboard/`
- `LEARNER_HOME_MFE_REDIRECT_PERCENTAGE` = 100
- Waffle flag `learner_home.redirect_to_microfrontend` = `everyone=True`
- **Verdict**: Authenticated users SHOULD redirect to MFE learner-dashboard. Needs real browser login to prove.

### C. Tenant Identity on MFE Pages — PROVEN

All three login pages show visibly distinct tenant identity (screenshot proof):
- Mereka: magenta palette, M-mark logo
- BB: black palette, hand logo
- SOF: purple palette, 1°F logo

Django-rendered pages (header/footer) already use `configuration_helpers.get_value()` for tenant-aware logo and platform_name. Tenant brand logos added in PR #1278 (merged). **Image rebuild in progress** to include new static assets.

### D. `/courses` — WORKING

- Returns 200 with 26 courses
- Search sidebar with facets (Modes, Availability, Orgs, Interest, Language)
- Uses Elasticsearch (intentional — Meilisearch swap breaks `/courses`)
- Course cards render; MCT-migrated images that 404 get gradient background
- Footer renders correctly with dark v2 design
- Screenshot proof captured

### E. Footer — WORKING

- MFE footer data chain: `build_mereka_public_footer()` → `MFE_CONFIG["MEREKA_PUBLIC_FOOTER"]` → config API → `footer.js`
- Django LMS footer: uses `configuration_helpers.get_value('platform_name')` for tenant-aware brand name
- Dark v2 footer visible on `/courses` screenshot with all 4 zones

### F. Language Selector — DEFERRED

- No additional languages configured beyond English
- Requires Transifex translation import (build-time) + DarkLangConfig admin setup (runtime)
- Not a code issue — admin/content task

### G. ArgoCD Health — CLEAN

- `mereka-lms-dev`: Synced Healthy (was Degraded earlier, now resolved)
- Enterprise worker high restart counts (subsidy: 158, access: 128, catalog: 109) are pre-existing and unrelated to frontend lane

## Surfaces Summary

| # | Surface | Status | Blocking? |
|---|---------|--------|-----------|
| 1 | Auth redirects (all tenants) | PROVEN | No |
| 2 | MFE login page identity | PROVEN | No |
| 3 | MFE config API rewriting | PROVEN | No |
| 4 | `/courses` page | WORKING | No |
| 5 | Django header/footer tenant-awareness | CODE READY, awaiting image rebuild | No |
| 6 | Tenant brand logos in theme | MERGED (#1278), build in progress | No |
| 7 | `/dashboard` authenticated landing | CONFIG CORRECT, needs browser proof | No |
| 8 | Studio auth callback | OAUTH2 CLIENT CORRECT, needs browser proof | Unproven |
| 9 | Language selector | DEFERRED (admin task) | No |
| 10 | Course card images (MCT migration) | DATA ISSUE, gradient fallback works | No |

## What Requires Image Rebuild (in progress)

- PR #1278: Tenant brand logos (BB/SOF) added to theme static images
- After rebuild + promote: BB/SOF Django pages will show correct tenant logos

## What Still Needs Real Browser Login Proof

1. Authenticated `/dashboard` → MFE learner-dashboard redirect
2. Studio login callback round-trip
3. `next` parameter survival through auth chain

These require an actual authenticated session (SSO via Authentik), not just curl.

## Screenshots

Captured at `/tmp/lms-screenshots/`:
- `main-homepage.png` — Mereka hero, CTA buttons, header
- `bb-homepage.png` — BB tenant with Mereka header (pre-image-rebuild)
- `sof-homepage.png` — SOF tenant with Mereka header (pre-image-rebuild)
- `main-courses-full.png` — 26 courses, search sidebar, dark footer
- `main-login-v2.png` — Mereka MFE login (magenta)
- `bb-login-v2.png` — BB MFE login (black)
- `sof-login-v2.png` — SOF MFE login (purple)
