# Authenticated Smoke & A11y Report

**Bead:** 2dcy.3
**ACs:** AC-FRONT-031, AC-FRONT-032, AC-FRONT-033, AC-FRONT-034
**Date:** 2026-02-18

---

## Authenticated Route Manifest

Routes verified by `scripts/qa/verify-authenticated-smoke-a11y.sh`:

| Route | Auth Level | Description |
|---|---|---|
| `/dashboard` | learner | Learner dashboard — course list and progress |
| `/account/settings` | learner | Account settings — profile, preferences |
| `/learning/course/{course_id}/home` | learner | Course home — per-enrolment entry point |
| `/admin/` | staff | Django admin — staff/superuser management panel |
| `/cms/` | staff | Studio CMS — course authoring entry point |

**Total routes:** 5 (3 learner + 2 staff)
**Minimum required:** 3
**Status:** PASS

---

## Contrast Validation Results

WCAG 2.1 AA minimum for normal text: **4.5:1**

Formula used: `L = 0.2126*R_lin + 0.7152*G_lin + 0.0722*B_lin`
Contrast: `(lighter + 0.05) / (darker + 0.05)`

| Color Pair | Foreground | Background | Ratio | Result |
|---|---|---|---|---|
| Body text (ink-900) on white | `#000000` | `#ffffff` | 21.00:1 | PASS |
| Secondary text (ink-700) on white | `#4a494a` | `#ffffff` | 8.96:1 | PASS |
| Link color (blue) on white | `#295cad` | `#ffffff` | 6.50:1 | PASS |
| White on blue (primary button) | `#ffffff` | `#295cad` | 6.50:1 | PASS |
| White on magenta | `#ffffff` | `#ab3b78` | 5.79:1 | PASS |

> **Known deviation — white on teal (#2d898b): 4.15:1.**
> The teal token fails WCAG AA 4.5:1 for normal text. It is used in `.mereka-badge`
> (0.75rem uppercase) and active tab gradients. A follow-up task exists to either darken
> the teal token to `#236b6d` (≈5.1:1) or switch badge text to ink-900. Tracked separately
> from this gate — the gate tests the 5 primary body/surface pairs listed above.

---

## Pass/Fail Summary

| AC | Description | Result |
|---|---|---|
| AC-FRONT-031 | Authenticated route manifest (≥3 routes, learner + staff) | PASS |
| AC-FRONT-032 | Runbook-grade smoke path + runbook doc exists | PASS |
| AC-FRONT-033 | WCAG AA 4.5:1 contrast for 5 color pairs | PASS (1 warning) |
| AC-FRONT-034 | Evidence report with pass/fail + failure guidance | PASS |

**Overall: PASS**

---

## Failure Handling Guidance

### If a contrast pair fails in future

1. Run `./scripts/qa/verify-authenticated-smoke-a11y.sh` and note the failing line:
   ```
   ❌ FAIL  3.50:1  Link color (blue #295cad) on white (#ffffff)  (need >= 4.5:1)
   ```
2. Locate the source color in:
   - `assets/branding/tokens.css` — canonical token values
   - `infrastructure/tutor/themes/mereka/scss/_tokens.scss` — SCSS variables
3. Adjust the token value to increase contrast. Use https://webaim.org/resources/contrastchecker/ to validate.
4. Run `./scripts/branding/verify-token-drift.sh` to confirm no unintended drift.
5. Update the ratio in this evidence report table.
6. Re-run the gate to confirm PASS.

### If a required route is removed from the LMS

1. Update `AUTHENTICATED_ROUTES` in `scripts/qa/verify-authenticated-smoke-a11y.sh`.
2. Replace the removed route with an equivalent authenticated route at the same or higher auth level.
3. Update the route table in `docs/operations/AUTHENTICATED_SMOKE_A11Y.md` and this report.
4. Open a follow-up bead if the route removal represents a functional regression.

### If the CI job `authenticated-smoke-a11y` fails unexpectedly

1. Check if a new script or doc was deleted or renamed.
2. Verify all four referenced files exist:
   - `scripts/qa/verify-authenticated-smoke-a11y.sh`
   - `docs/operations/AUTHENTICATED_SMOKE_A11Y.md`
   - `docs/operations/evidence/authenticated-smoke-a11y-report.md`
3. Check for Python availability on the CI runner (`python3 --version`).
4. Re-run the script locally to reproduce.
