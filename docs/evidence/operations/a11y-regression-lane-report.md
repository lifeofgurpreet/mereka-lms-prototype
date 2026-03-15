# A11y Regression Lane Evidence Report

Bead: 2dcy.3
Acceptance criteria: AC-FRONT-071, AC-FRONT-072, AC-FRONT-073,
AC-FRONT-074, AC-FRONT-075

## Summary

| Check | Result |
| ----- | ------ |
| Parent script route coverage (AC-FRONT-071) | PASS |
| Parent script contrast validation (AC-FRONT-072) | PASS |
| Source-level a11y checks (AC-FRONT-073) | PASS |
| Evidence artifact capture (AC-FRONT-074) | PASS |
| Parent bead reference (AC-FRONT-075) | PASS |

## Pass/Fail Detail

The verification script
`scripts/qa/verify-a11y-regression-lane.sh` validates:

1. **Route coverage** -- parent script
   `verify-authenticated-smoke-a11y.sh` defines at least 3
   routes covering `/dashboard` and `/account`.
2. **Contrast validation** -- parent script contains the WCAG
   contrast computation block with 4.5:1 threshold.
3. **Source-level a11y** -- Mereka theme SCSS defines
   `:focus` styling rules with `box-shadow` focus rings,
   a non-transparent `--mereka-mfe-focus` token, and plugin
   contract sources inject `role="contentinfo"` and `<nav>`
   landmarks.
4. **This report** -- evidence artifact exists.
5. **Runbook** -- a11y regression lane runbook exists at
   `docs/ops/runbooks/A11Y_REGRESSION_LANE.md` covering
   `/authn/login`, `/dashboard`, `/account/settings`.

All checks pass in CI as of the initial commit.

## Follow-up Blockers

No outstanding blockers. All source-level a11y checks pass.

## Failure Handling

If any check fails:

- **Route coverage** -- ensure
  `scripts/qa/verify-authenticated-smoke-a11y.sh` has the
  `AUTHENTICATED_ROUTES` array with at least 3 entries.
- **Contrast validation** -- ensure the parent script
  contains the `python3` WCAG contrast block.
- **Source-level a11y** -- verify `mereka.scss` has `:focus`
  rules with `box-shadow` and `--mereka-mfe-focus` token.
  Verify plugin contract sources define landmarks.
- **Evidence report** -- this file must exist at
  `docs/evidence/operations/a11y-regression-lane-report.md`.
- **Runbook** -- verify
  `docs/ops/runbooks/A11Y_REGRESSION_LANE.md` exists and
  covers the required routes.
