---
spec: branding-system_spec.md
tier: 1
status: draft
last_updated: "2026-02-10"
---

# Test Plan: Branding System

**Source Spec**: `specs/branding-system_spec.md`

## Test Infrastructure

This project does not use a JS/Python test framework for branding verification. All tests are bash-based shell verificationscripts and manual visual checks, consistent with the existingtest infrastructure:

| Test Type | Tool | Location |
|-----------|------|----------|
| `shell_verification` | Bash scripts | `scripts/branding/verify-*.sh`, `scripts/qa/verify-*.sh` |
| `smoke_test` | Bash scripts + curl | `scripts/qa/verify-public-branding.sh`, `scripts/branding/run-branding-gates.sh` |
| `manual_verification` | Human checklist | Documented inlinebelow |

## Acceptance Criteria Test Matrix

| AC # | Test Case | Type | File / Command | Mocks/Fixtures |
|------|-----------|------|----------------|----------------|
| AC-001 | Mereka logo visible on LMS homepage: script fetcheshomepage HTML, extracts logo `src`, confirms it references themed Mereka logo path and returns HTTP 200 with >2KB body | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_homepage_brand_logo`) | Live prod endpoint |
| AC-001 | Source logos exist in theme directory: `logo.png`,`logo-horizontal.png`, SVG variants all present in `lms/static/images/` | `shell_verification` | `scripts/branding/verify-logo-setup.sh` | None (file existence) |
| AC-002 | Mereka logo visible on Studio homepage: script confirms Studio homepage contains "Mereka" text and themed CSS link resolves | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_studio_brand_css`) | Live prod endpoint |
| AC-002 | Studio theme SCSS imports shared tokens and compiles | `shell_verification` | `scripts/branding/verify-branding-health.sh` (CMS theme checks) | None (file content) |
| AC-003 | Custom MerekaFooter renders on authn MFE: script fetches `/authn/login`, confirms MFE shell + Mereka branding markers in compiled CSS | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_mfe_authn_surface`) | Live prod endpoint |
| AC-003 | MerekaFooter renders on account, profile, learningMFEs | `manual_verification` | Navigate to each MFE surface and confirm footer contains "Mereka Academy", contact emails, partner links | None |
| AC-004 | Favicon loads correctly: script confirms `/theming/asset/mereka/images/favicon.ico` returns HTTP 200 | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_any_follow_200` for favicon) | Live prod endpoint |
| AC-004 | Favicon source file exists in theme | `shell_verification` | `scripts/branding/verify-branding-health.sh` (checks`favicon.ico` in assets/branding/) | None (file existence) |
| AC-005 | Custom fonts load without Google Fonts: homepage override CSS contains Poppins + Lato `@font-face` declarations with local `.woff2` references | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_homepage_brand_fonts` + `check_css_fonts`) | Live prod endpoint |
| AC-005 | Font source files exist in all theme directories |`shell_verification` | `scripts/branding/verify-branding-health.sh` (font section checks Poppins + Lato in common, lms, cms,mfe) | None (file existence) |
| AC-006 | Zero Google Fonts references in compiled CSS | `shell_verification` | `grep "fonts.googleapis.com" tutor_env/env/build/openedx/lms/static/css/*.css` returns empty (manual after build) | Requires built openedx image |
| AC-006 | Studio CSS has no Google Fonts imports | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_studio_brand_css` checks for `fonts.googleapis.com`) | Live prod endpoint |
| AC-007 | `verify-branding-health.sh` exits 0 | `shell_verification` | `scripts/branding/verify-branding-health.sh` | None|
| AC-007 | Full branding gate suite passes | `shell_verification` | `BRANDING_LEVEL=deep scripts/branding/run-branding-gates.sh prod` | Live prod endpoint |
| AC-008 | Theme applies on academyv2.mereka.io | `smoke_test`| `scripts/qa/verify-public-branding.sh prod` (primary domainchecks) | Live prod endpoint |
| AC-008 | Theme applies on academy.biji-biji.com | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (extra hostsloop checks biji-biji.com) | Live prod endpoint |
| AC-009 | Studio preview shows Mereka branding | `smoke_test`| `scripts/qa/verify-studio-authoring-branding.sh prod` | Live prod endpoint |
| AC-009 | Studio CSS contains branded selectors (create-course, outline, xblock) | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_studio_brand_css`) | Liveprod endpoint |
| AC-010 | Login page shows Mereka branding: MFE authn page has Mereka gradient markers, branding tokens in compiled CSS | `smoke_test` | `scripts/qa/verify-public-branding.sh prod` (function `check_mfe_authn_surface`) | Live prod endpoint |
| AC-010 | Login page visual confirmation | `manual_verification` | Navigate to `apps.academyv2.mereka.io/authn/login`, confirm Mereka logo, gradient, Poppins/Lato fonts, no Open edX defaults | None |

## Edge Case / Negative Tests

| Edge Case | Test Case | Type | File / Command | Mocks/Fixtures |
|-----------|-----------|------|----------------|----------------|
| EC-1: Logo not appearing | After `apply-patches.sh`, confirmlogos synced to build dir; if missing, `verify-logo-setup.sh`fails with clear error | `shell_verification` | `scripts/branding/verify-logo-setup.sh` | None |
| EC-2: Google Fonts still loading | After build, grep compiled CSS for `fonts.googleapis.com`; verify `verify-branding-health.sh` catches it; verify `check_studio_brand_css` catches iton live | `shell_verification` + `smoke_test` | `scripts/branding/verify-branding-health.sh` + `scripts/qa/verify-public-branding.sh prod` | None / Live endpoint |
| EC-3: MFE footer not rendering | Verify `env.config.jsx` patch applied; if not, `verify-branding-health.sh` section 3 fails on MFE SCSS checks; live check via `check_mfe_authn_surface`| `shell_verification` + `smoke_test` | `scripts/branding/verify-branding-health.sh` + `scripts/qa/verify-public-branding.sh prod` | None / Live endpoint |
| EC-4: Font files missing | `verify-branding-health.sh` section 2 checks all 9 required font files across 4 directories (common, lms, cms, mfe); any missing = failure | `shell_verification` | `scripts/branding/verify-branding-health.sh` | None |
| EC-5: Theme cache invalidation | After branding update, `collectstatic --clear` and hard refresh; verify new branding revision marker in live CSS via `check_css_fonts` | `smoke_test` |`scripts/qa/verify-public-branding.sh prod` (branding revision marker check) | Live endpoint |
| EC-6: Override CSS drift between common/lms/cms | `verify-branding-css.sh` checks that common, LMS, and CMS override CSS files are byte-identical | `shell_verification` | `scripts/branding/verify-branding-css.sh` | None |
| EC-7: Token drift from design system | `verify-token-drift.sh` checks that SCSS tokens match canonical design system export | `shell_verification` | `scripts/branding/verify-token-drift.sh` | None |

## NFR Tests

| NFR | Test Case | Type | Method |
|-----|-----------|------|--------|
| Asset size < 5 MB | `du -sh infrastructure/tutor/themes/mereka/` per subdirectory | `shell_verification` | Manual or scripted `du` check |
| No external font requests | `grep "fonts.googleapis.com"` incompiled CSS + live CSS check | `shell_verification` + `smoke_test` | `verify-branding-health.sh` + `verify-public-branding.sh` |
| WCAG 2.1 AA contrast | Spot-check brand colors against contrast ratios | `manual_verification` | Use contrast checker toolon Mereka teal/magenta against white/dark backgrounds |
| Logo alt text | Inspect rendered HTML for `alt` attributes on logo `<img>` tags | `manual_verification` | Browser dev tools on LMS homepage |

## Test Execution Order

1. **Source gate first** (no network required): `scripts/branding/verify-branding-health.sh`
2. **CSS verification**: `scripts/branding/verify-branding-css.sh`
3. **Token drift check**: `scripts/branding/verify-token-drift.sh`
4. **Logo setup check**: `scripts/branding/verify-logo-setup.sh`
5. **Full source + live gate**: `BRANDING_LEVEL=deep scripts/branding/run-branding-gates.sh prod`
6. **Manual visual checks**: Login page, MFE footer across surfaces, favicon, Studio preview

## Pass Criteria

All acceptance criteria are met when:
- `scripts/branding/verify-branding-health.sh` exits 0
- `BRANDING_LEVEL=deep scripts/branding/run-branding-gates.shprod` exits 0
- Manual visual checks confirm Mereka branding on login, MFE surfaces, and Studio preview
- `grep "fonts.googleapis.com" tutor_env/env/build/openedx/lms/static/css/*.css` returns empty
