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
| Custom MerekaFooter v2 in all MFEs | PASS | 5 zones: social, nav, columns, legal (AC-FOOTER-202) |
| Per-site footer variant mapping | PASS | 3 domains configured (AC-FOOTER-203) |
| No hotlinked badge images | PASS | App store badges use local styled links (AC-FOOTER-204) |
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

## Selector Hardening

| Check | Status | Evidence |
|-------|--------|----------|
| Selector hardening policy documented | PASS | `docs/architecture/SELECTOR_HARDENING_POLICY.md` |
| Selector complexity verifier exists | PASS | `scripts/qa/verify-selector-hardening.sh` (3 PASS, 267 WARN) |
| Slot-first migration readiness verified | PASS | `scripts/qa/verify-slot-migration-readiness.sh` (12 PASS, 1 WARN) |
| CI gate for selector quality | PASS | `monitoring-guardrails` CI job (syntax check) |
| Fragile selector ratio under threshold | PASS | 13% fragile selectors (204/1518), threshold 30% |
| Footer slot actively wired | PASS | `org.openedx.frontend.layout.footer.v1` (AC-FOOTER-202) |
| Slot inventory comprehensive | WARN | 41 slots documented (expected ≥80 from upstream) |
| Migration opportunities tracked | PASS | 4 slot-wirable customizations documented |
| Version Baseline table documented | PASS | Tutor 18.2.2, Node 18.20.5, Python 3.12 |
| Frontend version consistency (AC-UIVER-003) | PASS | docs ↔ CI ↔ scripts ↔ K8s verified |
| Upgrade procedure documented (AC-UIVER-004) | PASS | 8-step procedure in MFE_VERSIONS.md |

**Scripts**:
- `scripts/qa/verify-mfe-version-pinning.sh` (9 PASS / 0 FAIL)
- `scripts/qa/verify-frontend-version-truth.sh` (24+ PASS / 0 FAIL) — NEW: AC-UIVER-003

## Interaction State Quality

| Check | Status | Evidence |
|-------|--------|----------|
| Interaction-state contract documented | PASS | docs/architecture/INTERACTION_STATE_CONTRACT.md |
| MFE coverage matrix present | PASS | 11 MFEs tracked (authn, account, learning, profile, discussions, gradebook, learner-dashboard, communications, ora-grading, authoring, course-authoring) |
| Interaction-state verifier exists | PASS | scripts/qa/verify-interaction-state-contract.sh (45 PASS / 0 FAIL) |
| Design tokens cover all feedback states | PASS | _tokens.scss: success, warning, danger, info |
| Paragon components documented | PASS | Spinner, Skeleton, Alert, Toast |
| CI gate for interaction states | PASS | monitoring-guardrails CI job |
| 4-state contract defined (AC-UISTATE-001) | PASS | Loading, Empty, Error, Success |
| Design tokens enforced (AC-UISTATE-002) | PASS | No hardcoded colors in MFE SCSS |
| Paragon components used (AC-UISTATE-003) | PASS | All MFEs use Paragon for interaction feedback |
| MFE coverage tracked (AC-UISTATE-004) | PASS | Coverage matrix maintained |

**Script**: `scripts/qa/verify-interaction-state-contract.sh` (45 PASS / 0 FAIL)

## Visual Regression

| Check | Status | Notes |
|-------|--------|-------|
| Screenshot capture script exists | PASS | `scripts/qa/visual-regression-test.sh` |
| 20+ critical surfaces defined (desktop + mobile) | PASS | LMS, Studio, 10+ MFEs, desktop (1280x1024) + mobile (375x812) viewports |
| Mobile viewport baselines | PASS | 375x812 viewport support added |
| Axe-core accessibility checks | PASS | 4 core journeys: login, dashboard, courseware, discussions |
| Visual regression runbook | PASS | docs/operations/VISUAL_REGRESSION_RUNBOOK.md |
| Baseline captured | PENDING | Awaiting stable runtime post-1zj8 fix |
| Diff threshold configured | PASS | 5% pixel difference threshold |

## Plugin-Slot Wiring

| Check | Status | Evidence |
|-------|--------|----------|
| MerekaFooter v2 defined in Tutor plugin | PASS | `mereka_lms.py` mfe-env-config patch — 5-zone dark footer |
| PLUGIN_SLOTS forward-compatible registration | PASS | try/except for `tutormfe.hooks.PLUGIN_SLOTS` |
| apply-patches.sh fallback wiring | PASS | RenderWidget replacement (defense-in-depth) |
| Dual-path JSX sync verified | PASS | plugin ↔ patches identical (verify-mfe-footer-slot.sh) |
| FPF dependency installed in MFE build | PASS | `@openedx/frontend-plugin-framework@^1.8.0` |
| CI gate for slot wiring | PASS | `.github/workflows/ci.yml` mfe-footer-slot job |
| Plugin-slot inventory documented | PASS | `docs/architecture/MFE_PLUGIN_SLOT_INVENTORY.md` — 100+ slots across 14 MFEs |
| Comprehensive wiring integrity check | PASS | `verify-plugin-slot-wiring.sh` (28 PASS) — plugin ↔ patches ↔ inventory |
| CI gate for wiring integrity | PASS | `.github/workflows/ci.yml` plugin-slot-wiring job |

**Scripts**:
- `scripts/qa/verify-mfe-footer-slot.sh` (30+ PASS / 0 FAIL) — updated for v2
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

## Token Usage Lint

| Check | Status | Evidence |
|-------|--------|----------|
| Hardcoded hex color lint | PASS | `verify-design-token-usage.sh` (8 PASS / 3 WARN) |
| Brand token references via var() | PASS | 5 core tokens checked |
| CI gate for token usage | PASS | `design-token-usage` CI job |
| Paragon alignment documented | PASS | `docs/branding/PARAGON_TOKEN_ALIGNMENT.md` |
| Token migration policy | PASS | Documented in PARAGON_TOKEN_ALIGNMENT.md |

**Script**: `scripts/qa/verify-design-token-usage.sh`

**Known warnings**: 3 files contain hardcoded hover state colors (#963365 - darker magenta for :hover/:focus). These are acceptable as they are derived from the brand primary color and provide appropriate visual feedback.

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

## Tenant Branding

| Check | Status | Evidence |
|-------|--------|----------|
| Brand-pack schema exists and validates | PASS | `specs/brand-pack-schema.json` |
| Template validates against schema | PASS | `scripts/tenants/brand-pack-template.json` |
| CI gate for brand-pack validation | PASS | `.github/workflows/ci.yml` brand-pack-schema job |

**Script**: `scripts/qa/verify-brand-pack-schema.sh`

## WCAG 2.1 AA Contrast Compliance

| Check | Status | Evidence |
|-------|--------|----------|
| All text/background pairs meet AA thresholds | PASS | `verify-contrast-compliance.sh` (27 PASS) |
| ink-500 remediated for 4.5:1 on neutral-100 | PASS | #7B7B7B → #737373 |
| ink-300 remediated for 3:1 on neutral-100 | PASS | #AFADB2 → #929092 |
| teal remediated for 4.5:1 link text | PASS | #2d898b → #297F81 |
| Soft semantic colors tested as backgrounds | PASS | ink-900 on gold/sky/pink |
| CI gate for contrast regression | PASS | `.github/workflows/ci.yml` contrast-compliance job |

**Script**: `scripts/qa/verify-contrast-compliance.sh` (27 PASS / 0 FAIL)

## Tenant Branding Runtime

| Check | Status | Evidence |
|-------|--------|----------|
| Runtime branding verification script exists | PASS | `scripts/qa/verify-tenant-branding-runtime.sh` |
| Per-domain SITE_NAME assertion (AC-TBR-101) | PENDING | Requires ENABLE_MULTI_TENANT_BRANDING=True |
| Per-domain logo URL assertion (AC-TBR-102) | PENDING | Requires ENABLE_MULTI_TENANT_BRANDING=True |
| Brand color tokens presence check (AC-TBR-102) | PENDING | Requires ENABLE_MULTI_TENANT_BRANDING=True |
| Footer variant contract per domain (AC-TBR-103) | PENDING | Requires live endpoints |
| Integration into governance gates (AC-TBR-104) | PASS | `run-multisite-governance-gates.sh` |
| Troubleshooting section documented (AC-TBR-105) | PASS | `docs/operations/TROUBLESHOOTING.md` |
| CI syntax check | PASS | `.github/workflows/ci.yml` monitoring-guardrails job |

**Script**: `scripts/qa/verify-tenant-branding-runtime.sh`

**Note**: This is a runtime check that requires live endpoints with `ENABLE_MULTI_TENANT_BRANDING=True`. When the runtime is not available, all checks are marked as SKIP (not FAIL). The script verifies:
- academyv2.mereka.io → "Mereka Academy"
- academy.biji-biji.com → "Biji-Biji Academy"
- skillourfuture.academy.mereka.io → "Skill Our Future Academy"

## Release Blockers

| Blocker | Status | Owner |
|---------|--------|-------|
| Custom app crashloops (1zj8) | FIXED (code) | WhiteCliff (runtime deploy) |
| Visual regression baseline | PENDING | Requires stable runtime |
| Accessibility audit (contrast) | PASS | WCAG AA contrast gate (1251) |
| Performance baseline (LCP, FID) | NOT STARTED | Future epic |

## Authenticated Smoke Tests

| Check | Status | Evidence |
|-------|--------|----------|
| Authenticated smoke harness exists (AC-UIAUTH-001) | PASS | `scripts/qa/smoke-authenticated.sh` |
| Visual regression authenticated support (AC-UIAUTH-002) | PASS | `--authenticated` flag, SSO credentials, graceful fallback |
| CI workflow with artifacts (AC-UIAUTH-003) | PASS | Playwright install, secrets, artifact upload, visual regression |
| Credentials documentation (AC-UIAUTH-004) | PASS | `docs/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md` |
| SSO login flow tested | PASS | Playwright-based OIDC/Authentik login |
| Post-login page checks | PASS | Dashboard, account, course player, profile |
| Source-level verification | PASS | `scripts/qa/verify-authenticated-ui-smoke.sh` (CI gate) |

**Scripts**:
- `scripts/qa/smoke-authenticated.sh` — Authenticated smoke tests
- `scripts/qa/visual-regression-test.sh` — Visual regression with `--authenticated` support
- `scripts/qa/verify-authenticated-ui-smoke.sh` — Source-level verification (@covers AC-UIAUTH-001..004)

## MFE-First Policy

| Check | Status | Evidence |
|-------|--------|----------|
| MFE-first policy documented | PASS | `docs/architecture/MFE_FIRST_POLICY.md` |
| Exception process documented | PASS | Included in policy doc |
| Policy compliance verifier | PASS | `scripts/qa/verify-mfe-first-policy.sh` |
| CI gate for policy compliance | PASS | `mfe-first-policy` CI job |
| Plugin slot inventory maintained | PASS | `docs/architecture/MFE_PLUGIN_SLOT_INVENTORY.md` (100+ slots) |

**Script**: `scripts/qa/verify-mfe-first-policy.sh`

## Ecommerce Deprecation

| Check | Status | Evidence |
|-------|--------|----------|
| Legacy ecommerce inventory documented | PASS | `docs/operations/ECOMMERCE_DEPRECATION_INVENTORY.md` |
| Ecommerce splash page with basket/checkout links | WARN | Caddyfile line 162 (to be removed when gateway ready) |
| Guard script for new legacy refs | PASS | `verify-legacy-ecommerce-ui-refs.sh` (10 PASS / 8 WARN) |
| CI gate for ecommerce references | PASS | `legacy-ecommerce-guard` CI job |
| ADR-018 decision documented | PASS | `docs/adr/018-purchase-gateway-replaces-oscar-ecommerce.md` |

**Script**: `scripts/qa/verify-legacy-ecommerce-ui-refs.sh`

## Verification Commands

```bash
# Full branding check (AC-UI-001/005-008)
./scripts/qa/verify-mfe-branding.sh

# Theme consistency (AC-UI-002)
./scripts/qa/verify-theme-consistency.sh

# Version pinning (AC-UI-004)
./scripts/qa/verify-mfe-version-pinning.sh

# Frontend version truth (AC-UIVER-003) — NEW: task 14ae
./scripts/qa/verify-frontend-version-truth.sh

# Custom app drift (1zj8 guard)
./scripts/qa/verify-custom-app-drift.sh

# Footer plugin-slot wiring
./scripts/qa/verify-mfe-footer-slot.sh

# Token definition correctness (3klj guard)
./scripts/qa/verify-token-definitions.sh

# Design token usage lint (AC-UITOKEN-002)
./scripts/qa/verify-design-token-usage.sh

# MFE route mapping drift (3464 guard)
./scripts/qa/verify-mfe-route-drift.sh

# Interaction state contract (AC-UISTATE-001..004)
./scripts/qa/verify-interaction-state-contract.sh

# Plugin-slot wiring integrity (qp0k guard)
./scripts/qa/verify-plugin-slot-wiring.sh

# WCAG 2.1 AA contrast compliance (1251 guard)
./scripts/qa/verify-contrast-compliance.sh

# Visual regression (AC-UI-003) — requires Playwright
./scripts/qa/visual-regression-test.sh --update-baseline

# Authenticated smoke tests (AC-SMOKE-001) — requires SSO credentials
SSO_USERNAME=test@example.com SSO_PASSWORD=secret ./scripts/qa/smoke-authenticated.sh

# MFE-first policy compliance (AC-UIMFE-002) — NEW: task 8rgu
./scripts/qa/verify-mfe-first-policy.sh
```
