# Frontend Phase 2/QA Smoke Evidence (2026-02-28)

## Scope

This evidence run captures frontend branding smoke artifacts and QA gate outputs after slot expansion + email branding updates.

## Commands Run

```bash
./scripts/qa/capture-branding-screenshots.sh prod
./scripts/qa/verify-mfe-route-smoke.sh --env prod
./scripts/qa/verify-a11y-contrast-focus.sh
./scripts/qa/verify-lighthouse-budgets.sh
./scripts/qa/verify-email-template-multilang.sh
```

## Artifacts

- Screenshot bundle: `var/screenshots/prod/20260228T144430Z`
- Screenshot count: `21` PNG files
- MFE route smoke artifacts: `/tmp/mfe-route-smoke-20260228-145946` (`results.json` included)

## Results

### Branding Screenshots

- `capture-branding-screenshots.sh prod` completed successfully.
- Public LMS/Studio/MFE/ecommerce/credentials/forum/notes surfaces were captured into the bundle above.

### MFE Route Smoke

- `verify-mfe-route-smoke.sh --env prod` completed successfully.
- Summary: `PASS=33`, `WARN=0`, `FAIL=0`
- Route mapping, HTTP shell response checks, and lightweight route-level a11y checks all passed.

### Accessibility Gate

- `verify-a11y-contrast-focus.sh`: `PASS=28`, `WARN=3`, `FAIL=0`
- Notable warnings:
  - Placeholder/caption contrast (`ink-300` on surface) below 4.5:1 (documented non-blocking warning)
  - One focus-context `box-shadow:none` warning in minified core CSS
  - CI wiring warning for the a11y gate script
- Resolved in follow-up hardening:
  - Added canonical `--pgn-focus-ring-color` token bridge through `tokens.css` → generator → `_tokens.scss`.

### Lighthouse Budget Gate

- `verify-lighthouse-budgets.sh`: `PASSED=14`, `FAILED=0`
- Required paths, JS/CSS ceilings, INP/FID policy, CLS, and LCP budgets all passed.

### Email Template Branding Gate

- `verify-email-template-multilang.sh`: `PASS=11`, `FAIL=0`, `WARN=5`
- New branding checks passed for:
  - `password_reset.html` branded gradient shell + primary fallback color
  - `enrollment.html` accent fallback
  - `welcome.html` support footer link
  - `certificate.html` branded shell + primary/accent fallbacks + pill CTA styling
  - `campaign.html` unsubscribe footer
  - `marketing_promo.html` pill CTA styling
- Existing warnings remain on untranslated (`ms`, `zh`) template variants and ACE config visibility from local config files.

## Remaining Work

- Cross-browser live UI verification (Chrome/Firefox/Safari + mobile viewport) remains a separate runtime/manual tranche.
- MFE image rebuild + deployment verification remains required for production runtime confirmation.

## Addendum — Slot Expansion + Selector Exception Retirement

### Additional Commands Run

```bash
AGENT_BROWSER_TIMEOUT_SECONDS=20 ./scripts/qa/capture-branding-screenshots.sh prod
./scripts/qa/verify-mfe-plugin-slots.sh
./scripts/qa/verify-selector-to-slot-migration.sh
./scripts/qa/verify-mfe-footer-slot-migration.sh
./scripts/qa/verify-mfe-selector-hardening.sh
./scripts/qa/verify-no-dom-overrides.sh
./scripts/qa/verify-migration-lock.sh
./scripts/qa/verify-css-scoping.sh
```

### Additional Artifacts

- Screenshot bundle: `var/screenshots/prod/20260228T150928Z`
- Screenshot count: `20` PNG files

### Additional Results

- `verify-mfe-plugin-slots.sh`: `PASS=50`, `WARN=0`, `FAIL=0`
  - Slot registry now verifies 23 namespaced slot IDs, including:
    - `learner_dashboard.course_card_action.v1`
    - `catalog.catalog_card.v1`
    - `catalog.catalog_filters.v1`
    - `account.account_settings_field.v1`
- `verify-selector-to-slot-migration.sh`: `PASS=32`, `FAIL=0`
- `verify-mfe-footer-slot-migration.sh`: `PASS=42`, `FAIL=0`
- `verify-mfe-selector-hardening.sh`: `PASS=25`, `WARN=0`, `FAIL=0`
- `verify-no-dom-overrides.sh`: `PASS=14`, `FAIL=0`
- `verify-migration-lock.sh`: `PASS=9`, `FAIL=0`
- `verify-css-scoping.sh`: `PASS=59`, `WARN=0`, `FAIL=0`

## Addendum — Cross-Browser Re-Run After Slot Source Alignment

### Command Run

```bash
./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --cross-browser
```

### Runtime Results

- Total: `9 passed`, `0 failed` in `2.8m`
- Projects passed:
  - `chromium` (authn-login, learner-dashboard, account-settings)
  - `firefox` (authn-login, learner-dashboard, account-settings)
  - `mobile-chrome` (authn-login, learner-dashboard, account-settings)
- WebKit/mobile-Safari:
  - Auto-disabled by launcher probe because host dependencies are not installed on this runner.
  - This remains a host-environment prerequisite, not an app-level regression.
- Log:
  - `var/qa/cross-browser-branding-smoke-prod-20260228T163310Z.log`

## Addendum — Lighthouse Budget Re-Run

### Command Run

```bash
./scripts/qa/verify-lighthouse-budgets.sh
```

### Result

- `PASSED=14`, `FAILED=0`
- Coverage + thresholds still pass for:
  - required MFE routes (`/authn/login`, `/dashboard`, `/learning/course`, `/profile`, `/account`, `/discussions`)
  - resource ceilings (JS/CSS)
  - INP/FID policy
  - CLS and LCP budget constraints

## Addendum — Unified Performance Spot-Check Wrapper

### Command Run

```bash
./scripts/qa/verify-frontend-performance-spotcheck.sh
```

### Result

- Wrapper summary: `PASS=2`, `FAIL=0`
- Includes:
  - `verify-lighthouse-budgets.sh` (`PASSED=14`, `FAILED=0`)
  - `verify-paragon-runtime.sh` (artifact/budget checks pass; runtime URL checks remain warning-only unless `--runtime-url` is supplied)

## Addendum — Transactional Email Branding Expansion

### Commands Run

```bash
./scripts/qa/verify-email-template-multilang.sh
```

### Result

- `PASS=15`, `FAIL=0`, `WARN=5`
- Added branded-shell marker coverage and template updates for:
  - `account_activation.html`
  - `course_announcement.html`
  - `deadline.html`
- Existing warnings remain unchanged (missing `ms`/`zh` localized variants + ACE config visibility from local config files).

### Policy Outcome

- Legacy `.page__account-settings` wrapper selector is removed from active CSS.
- Account styling path is now slot-owned through:
  - `org.openedx.frontend.account.account_settings_tab.v1`
  - `org.openedx.frontend.account.account_settings_field.v1`

## Addendum — Cross-Browser Branding Smoke Automation

### New Automation

- Added `tests/e2e/tests/branding-smoke.spec.ts`
  - Verifies authn + learner-dashboard + account-settings routes expose `PARAGON_THEME` runtime manifest.
  - Verifies hashed core theme assets are present in the HTML contract (`paragon-theme-core.*.css`, `brand-theme-core.*.css`).
  - Captures route screenshots per project.
- Added `scripts/qa/verify-cross-browser-branding-smoke.sh`
  - Supports `--env prod|dev`.
  - Supports `--cross-browser` mode (chromium, firefox, mobile-chrome, and webkit/mobile-safari when host deps are available).
  - Includes WebKit launch probe with explicit fallback (`webkit_enabled=0`) when host dependencies are missing.

### Runtime Results

- `./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod`
  - `PASS=3`, `FAIL=0` (Chromium)
  - Log: `var/qa/cross-browser-branding-smoke-prod-20260228T155501Z.log`
- `./scripts/qa/verify-cross-browser-branding-smoke.sh --env prod --cross-browser`
  - `PASS=9`, `FAIL=0` (Chromium + Firefox + mobile Chrome)
  - WebKit/Safari projects were auto-disabled due missing host runtime deps.
  - Log: `var/qa/cross-browser-branding-smoke-prod-20260228T160129Z.log`

## Addendum — Confirmed Ulmo Slot Expansion

### Additional Commands Run

```bash
python3 -m py_compile infrastructure/tutor/plugins/mereka_lms.py
./scripts/qa/verify-mfe-plugin-slots.sh
./scripts/qa/verify-selector-to-slot-migration.sh
./scripts/qa/verify-mfe-footer-slot-migration.sh
./scripts/qa/verify-mfe-slot-source-alignment.sh
./scripts/qa/verify-mfe-selector-hardening.sh
./scripts/qa/verify-css-scoping.sh
```

### Additional Results

- `verify-mfe-plugin-slots.sh`: `PASS=48`, `WARN=0`, `FAIL=0`
  - Plugin now declares 22 namespaced slot IDs.
  - Newly wired confirmed Ulmo slot IDs:
    - `org.openedx.frontend.authoring.course_unit_sidebar.v1`
    - `org.openedx.frontend.layout.header_learning.v1`
    - `org.openedx.frontend.learning.course_tab_links.v1`
    - `org.openedx.frontend.account.id_verification_page.v1`
  - Retired unconfirmed slot IDs from active wiring:
    - `org.openedx.frontend.learning.course_header.v1`
    - `org.openedx.frontend.learning.course_tabs.v1`
    - `org.openedx.frontend.account.account_settings_tab.v1`
    - `org.openedx.frontend.account.account_settings_field.v1`
    - `org.openedx.frontend.authoring.course_outline_header.v1`
- `verify-selector-to-slot-migration.sh`: `PASS=31`, `FAIL=0`
- `verify-mfe-footer-slot-migration.sh`: `PASS=41`, `FAIL=0`
- `verify-mfe-slot-source-alignment.sh`: `PASS=10`, `WARN=13`, `FAIL=0`
  - All slots tied to locally available MFE source checkouts (`authn`, `account`, `profile`, `learning`, `authoring`) are source-confirmed.
  - Remaining warnings are expected for slot families without local source checkouts in this workspace (`learner_dashboard`, `catalog`, and non-learning `layout.*` surfaces).
- `verify-mfe-selector-hardening.sh`: `PASS=25`, `WARN=0`, `FAIL=0`
- `verify-css-scoping.sh`: `PASS=59`, `WARN=0`, `FAIL=0`

## Addendum — Learning Slot Coverage Expansion (33 Active Slots)

### Commands Run

```bash
python3 -m py_compile infrastructure/tutor/plugins/mereka_lms.py
./scripts/qa/verify-mfe-plugin-slots.sh
./scripts/qa/verify-mfe-slot-source-alignment.sh
./scripts/qa/verify-email-template-multilang.sh
```

### Results

- `verify-mfe-plugin-slots.sh`: `PASS=48`, `WARN=0`, `FAIL=0`
  - Plugin now declares **33 namespaced slot IDs**.
  - New learning slots wired:
    - `org.openedx.frontend.learning.course_breadcrumbs.v1`
    - `org.openedx.frontend.learning.learner_tools.v1`
    - `org.openedx.frontend.learning.progress_tab_course_grade.v1`
    - `org.openedx.frontend.learning.progress_tab_related_links.v1`
    - `org.openedx.frontend.learning.progress_tab_certificate_status_main_body.v1`
    - `org.openedx.frontend.learning.progress_tab_certificate_status_side_panel.v1`
    - `org.openedx.frontend.learning.progress_tab_grade_breakdown.v1`
    - `org.openedx.frontend.learning.unit_title.v1`
    - `org.openedx.frontend.learning.sequence_navigation.v1`
    - `org.openedx.frontend.learning.course_outline_sidebar_trigger.v1`
    - `org.openedx.frontend.learning.course_outline_mobile_sidebar_trigger.v1`
- `verify-mfe-slot-source-alignment.sh`: `PASS=21`, `WARN=13`, `FAIL=0`
  - All new learning slot IDs are confirmed in the local Ulmo learning MFE source checkout.
  - Remaining warnings are expected for slot families without local source checkouts in this workspace (`learner_dashboard`, `catalog`, non-learning `layout.*`).
- `verify-email-template-multilang.sh`: `PASS=21`, `FAIL=0`, `WARN=5`
  - Branded marker checks now cover 15 HTML templates including `feedback`, `forum`, `grade`, `maintenance_notice`, `re_engagement`, and `survey`.
