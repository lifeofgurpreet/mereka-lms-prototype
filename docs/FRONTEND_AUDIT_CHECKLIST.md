# Frontend Audit Checklist

**Purpose**: Structured review of Mereka Academy frontend quality for leadership review.
**Last verified**: 2026-02-17

## UX Quality

| Check | Status | Evidence |
|-------|--------|----------|
| All MFE routes return HTTP 200 | PASS | `verify-mfe-branding.sh` (56 PASS) |
| No "page unavailable" screens on primary flows | PASS | `/account/settings` redirects to `/account/` |
| Login/registration flow works end-to-end | PASS | `/authn/login` serves React SPA |
| Learner dashboard loads | PASS | `/learner-dashboard/` HTTP 200 |
| Course player loads | PASS | `/learning` HTTP 200 |
| Studio authoring loads via both paths | PASS | `/authoring/` and `/course-authoring/` HTTP 200 |

## Branding Consistency

| Check | Status | Evidence |
|-------|--------|----------|
| LMS uses Mereka theme | PASS | `DEFAULT_SITE_THEME = mereka` (runtime confirmed) |
| Custom MerekaFooter in all MFEs | PASS | Plugin + apply-patches.sh wiring verified |
| No "Powered by Open edX" on production | PASS | AC-UI-007 negative checks |
| No default Open edX logo references | PASS | AC-UI-007 checks |
| Google Fonts stripped from SCSS | PASS | Plugin strips imports pre-asset build |
| Design tokens synced from Figma | PASS | `tokens.css` with provenance tracking |

**Script**: `scripts/qa/verify-theme-consistency.sh` (13 PASS / 0 FAIL)

## Routing

| Check | Status | Evidence |
|-------|--------|----------|
| 11 MFE routes configured in Caddyfile | PASS | authn, account, learning, profile, discussions, gradebook, learner-dashboard, communications, ora-grading, authoring, course-authoring |
| `/u/:username` profile routes work | PASS | Dedicated Caddy matcher |
| `/orders` and `/payment` proxy to payments-gateway | PASS | reverse_proxy to payments-gateway:8080 |
| `/api/mfe_config/v1` proxied to LMS | PASS | reverse_proxy with Host passthrough |
| `/login_refresh` proxied to LMS | PASS | JWT cookie refresh endpoint |
| authoring ↔ course-authoring symlink | PASS | Startup command normalizes directory names |

## Version Pinning

| Check | Status | Evidence |
|-------|--------|----------|
| MFE image pinned (not `:latest`) | PASS | `20260208-mfe-discussions-pass4-c17df16` |
| OpenEdX image pinned | PASS | `20260210-v21-mfe-only-b988d63` |
| Version tracking doc maintained | PASS | `docs/architecture/MFE_VERSIONS.md` |
| No `:latest` tags in deployment manifests | PASS | 0 occurrences in `deployments.yml` |

**Script**: `scripts/qa/verify-mfe-version-pinning.sh` (9 PASS / 0 FAIL)

## Visual Regression

| Check | Status | Notes |
|-------|--------|-------|
| Screenshot capture script exists | PASS | `scripts/qa/visual-regression-test.sh` |
| 10 critical pages defined | PASS | LMS homepage, login, dashboard, course player, studio, profile, etc. |
| Baseline captured | PENDING | Awaiting stable runtime post-1zj8 fix |
| Diff threshold configured | PASS | 5% pixel difference threshold |

## Plugin-Slot Wiring

| Check | Status | Evidence |
|-------|--------|----------|
| MerekaFooter defined in Tutor plugin | PASS | `mereka_lms.py` mfe-env-config patch |
| PLUGIN_SLOTS forward-compatible registration | PASS | try/except for `tutormfe.hooks.PLUGIN_SLOTS` |
| apply-patches.sh fallback wiring | PASS | RenderWidget replacement (defense-in-depth) |
| FPF dependency installed in MFE build | PASS | `@openedx/frontend-plugin-framework@^1.8.0` |
| CI gate for slot wiring | PASS | `.github/workflows/ci.yml` mfe-footer-slot job |
| Plugin-slot inventory documented | PASS | `docs/architecture/MFE_PLUGIN_SLOT_INVENTORY.md` — 100+ slots across 14 MFEs |
| Comprehensive wiring integrity check | PASS | `verify-plugin-slot-wiring.sh` (28 PASS) — plugin ↔ patches ↔ inventory |
| CI gate for wiring integrity | PASS | `.github/workflows/ci.yml` plugin-slot-wiring job |

**Scripts**:
- `scripts/qa/verify-mfe-footer-slot.sh` (16 PASS / 0 FAIL)
- `scripts/qa/verify-plugin-slot-wiring.sh` (28 PASS / 0 FAIL)

## Token Correctness

| Check | Status | Evidence |
|-------|--------|----------|
| All --mereka-* token references resolve | PASS | `verify-token-definitions.sh` (10 PASS) |
| tokens.css has >= 80 properties | PASS | 110 properties found |
| tokens.css balanced braces | PASS | Structural check |
| Key colors bridged in _tokens.scss | PASS | teal, magenta, blue |
| No undefined --pgn-* references | PASS | All Paragon tokens bridged |
| CI gate for token definitions | PASS | `.github/workflows/ci.yml` token-definitions job |

**Script**: `scripts/qa/verify-token-definitions.sh` (10 PASS / 0 FAIL)

## Route Mapping Integrity

| Check | Status | Evidence |
|-------|--------|----------|
| Caddyfile ↔ branding verifier routes in sync | PASS | `verify-mfe-route-drift.sh` (32 PASS) |
| /authoring and /course-authoring both serve course-authoring | PASS | Dual-path check |
| /u profile route serves profile directory | PASS | Special route check |
| /orders and /payment proxy to payments-gateway | PASS | Deprecated route proxy check |
| CI gate for route drift | PASS | `.github/workflows/ci.yml` mfe-route-drift job |

**Script**: `scripts/qa/verify-mfe-route-drift.sh` (32 PASS / 0 FAIL)

## Build & Deploy Safety

| Check | Status | Evidence |
|-------|--------|----------|
| Custom app drift guard | PASS | `verify-custom-app-drift.sh` (54 PASS) |
| CI gate for drift regression | PASS | `.github/workflows/ci.yml` custom-app-drift job |
| 21/21 custom apps in Docker image | PASS | Plugin `_CUSTOM_APPS` list |
| Kustomize ConfigMap persistence | PASS | `configMapGenerator` with content hashing |

## Release Blockers

| Blocker | Status | Owner |
|---------|--------|-------|
| Custom app crashloops (1zj8) | FIXED (code) | WhiteCliff (runtime deploy) |
| Visual regression baseline | PENDING | Requires stable runtime |
| Accessibility audit | NOT STARTED | Future epic |
| Performance baseline (LCP, FID) | NOT STARTED | Future epic |

## Verification Commands

```bash
# Full branding check (AC-UI-001/005-008)
./scripts/qa/verify-mfe-branding.sh

# Theme consistency (AC-UI-002)
./scripts/qa/verify-theme-consistency.sh

# Version pinning (AC-UI-004)
./scripts/qa/verify-mfe-version-pinning.sh

# Custom app drift (1zj8 guard)
./scripts/qa/verify-custom-app-drift.sh

# Footer plugin-slot wiring
./scripts/qa/verify-mfe-footer-slot.sh

# Token definition correctness (3klj guard)
./scripts/qa/verify-token-definitions.sh

# MFE route mapping drift (3464 guard)
./scripts/qa/verify-mfe-route-drift.sh

# Plugin-slot wiring integrity (qp0k guard)
./scripts/qa/verify-plugin-slot-wiring.sh

# Visual regression (AC-UI-003) — requires Playwright
./scripts/qa/visual-regression-test.sh --update-baseline
```
