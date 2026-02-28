# Frontend Phase 2/QA Smoke Evidence (2026-02-28)

## Scope

This evidence run captures frontend branding smoke artifacts and QA gate outputs after slot expansion + email branding updates.

## Commands Run

```bash
./scripts/qa/capture-branding-screenshots.sh prod
./scripts/qa/verify-a11y-contrast-focus.sh
./scripts/qa/verify-lighthouse-budgets.sh
./scripts/qa/verify-email-template-multilang.sh
```

## Artifacts

- Screenshot bundle: `var/screenshots/prod/20260228T144430Z`
- Screenshot count: `21` PNG files

## Results

### Branding Screenshots

- `capture-branding-screenshots.sh prod` completed successfully.
- Public LMS/Studio/MFE/ecommerce/credentials/forum/notes surfaces were captured into the bundle above.

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
