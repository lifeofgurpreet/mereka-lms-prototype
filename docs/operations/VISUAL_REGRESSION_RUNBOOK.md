# Visual Regression Runbook

_Audience: Platform Engineering • Last updated: 2026-02-17_

## Purpose

Procedures for maintaining visual regression baselines and triaging false positives.

## Baseline Management

### Updating Baselines

When a visual change is intentional (new footer, theme update, etc.):

```bash
# Capture new baseline (desktop)
./scripts/qa/visual-regression-test.sh --update-baseline --env production

# Capture mobile baseline
./scripts/qa/visual-regression-test.sh --update-baseline --viewport mobile --env production
```

Baselines are stored in `var/screenshots/baseline/` (gitignored).

### Bootstrap (First Run)

On a fresh clone or after major visual changes:

```bash
# Capture initial baselines for both viewports
./scripts/qa/visual-regression-test.sh --update-baseline
./scripts/qa/visual-regression-test.sh --update-baseline --viewport mobile
```

## Running Regression Checks

```bash
# Desktop regression (default)
./scripts/qa/visual-regression-test.sh

# Mobile regression
./scripts/qa/visual-regression-test.sh --viewport mobile

# Against production
./scripts/qa/visual-regression-test.sh --env production
```

## Diff Analysis

When a regression is detected:
1. Check `var/screenshots/diff/` for highlighted difference images
2. Compare `var/screenshots/baseline/<page>.png` vs `var/screenshots/current/<page>.png`
3. Determine if change is intentional or regression

## False Positive Triage

Common false positives:
| Cause | Symptom | Resolution |
|-------|---------|------------|
| Dynamic content (dates, counts) | Small pixel diff (<5%) | Threshold handles this automatically |
| Font rendering differences | Subtle anti-aliasing changes | Update baseline on reference machine |
| Animation timing | Elements in different states | Add `waitForTimeout` or `waitForSelector` |
| Ad/banner changes | Third-party content changed | Mask dynamic regions in script |

### Decision Tree

1. Is the diff > 5% threshold? → YES → Investigate
2. Is the visual change intentional? → YES → Update baseline
3. Is it a known false positive pattern? → YES → Document and ignore
4. None of the above → File as regression bug

## Accessibility Checks

```bash
# Run axe-core against 4 core journeys
./scripts/qa/verify-ui-accessibility.sh --target https://academyv2.mereka.io

# Local
./scripts/qa/verify-ui-accessibility.sh --target http://apps.localhost
```

### Interpreting Results

- **PASS**: 0 critical/serious violations
- **WARN**: Serious but not critical violations (should fix before next release)
- **FAIL**: Critical violations (blocks release)

Detailed JSON reports are saved to a temp directory (printed in output).

## CI Integration

Both checks are syntax-verified in CI. Full runtime checks require a live deployment target.

## Related Scripts

- `scripts/qa/visual-regression-test.sh` — Playwright screenshot capture + ImageMagick diff
- `scripts/qa/visual-regression-branding.sh` — Branding-specific visual regression
- `scripts/qa/verify-ui-accessibility.sh` — Axe-core accessibility checks
- `scripts/qa/verify-contrast-compliance.sh` — WCAG AA contrast ratio verification (static)
