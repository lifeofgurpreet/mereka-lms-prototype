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

- `verify-email-template-multilang.sh`: `PASS=7`, `FAIL=0`, `WARN=5`
- New branding checks passed for:
  - `password_reset.html` branded gradient shell + primary fallback color
  - `enrollment.html` accent fallback
  - `welcome.html` support footer link
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

### Policy Outcome

- Legacy `.page__account-settings` wrapper selector is removed from active CSS.
- Account styling path is now slot-owned through:
  - `org.openedx.frontend.account.account_settings_tab.v1`
  - `org.openedx.frontend.account.account_settings_field.v1`
