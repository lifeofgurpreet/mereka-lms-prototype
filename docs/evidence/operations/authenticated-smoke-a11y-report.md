# Authenticated Smoke + A11y Evidence Report

Bead: 2dcy.3
Acceptance criteria: AC-FRONT-031, AC-FRONT-032, AC-FRONT-033, AC-FRONT-034

## Summary

| Check | Result |
| ----- | ------ |
| Authenticated route manifest (AC-FRONT-031) | PASS |
| Runbook-grade smoke path (AC-FRONT-032) | PASS |
| WCAG AA contrast validation (AC-FRONT-033) | PASS |
| Evidence report (AC-FRONT-034) | PASS |

## Pass/Fail Detail

The verification script `scripts/qa/verify-authenticated-smoke-a11y.sh`
runs the following checks:

1. **Route manifest** -- at least 3 authenticated routes covering
   `/dashboard`, `/account`, and `/admin` with both learner and
   staff auth levels.
2. **Runbook doc** -- runbook exists at
   `docs/ops/runbooks/AUTHENTICATED_SMOKE_A11Y.md` with required
   sections (route manifest, running instructions, failure handling).
3. **WCAG AA contrast** -- 5 colour pairs validated against the
   4.5:1 minimum for normal text using the WCAG 2.x relative
   luminance formula.
4. **This report** -- evidence artifact with pass/fail output and
   failure handling guidance.

All checks pass in CI as of the initial commit.

## Failure Handling

If any check fails:

- **Route manifest failure** -- add the missing route to the
  `AUTHENTICATED_ROUTES` array in
  `scripts/qa/verify-authenticated-smoke-a11y.sh`.
- **Runbook doc failure** -- verify
  `docs/ops/runbooks/AUTHENTICATED_SMOKE_A11Y.md` exists and
  contains sections for route manifest, running instructions,
  and failure handling.
- **Contrast failure** -- update the colour token in
  `infrastructure/tutor/themes/mereka/scss/_tokens.scss` and
  `assets/branding/tokens.css` to meet the 4.5:1 ratio.
- **Evidence report failure** -- this file must exist at
  `docs/evidence/operations/authenticated-smoke-a11y-report.md`.
