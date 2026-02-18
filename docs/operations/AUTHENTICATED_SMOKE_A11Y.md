# Authenticated Smoke & Accessibility Gates

**Bead:** 2dcy.3
**ACs:** AC-FRONT-031, AC-FRONT-032, AC-FRONT-033, AC-FRONT-034
**Script:** `scripts/qa/verify-authenticated-smoke-a11y.sh`

---

## What This Covers

This runbook covers two interlocking quality gates for the Mereka LMS frontend:

1. **Authenticated Route Manifest** — a documented list of at least 3 learner and admin pages that require authentication to access, used as the target set for smoke and accessibility tests.
2. **WCAG AA Contrast Validation** — automated checks that key brand color pairs meet the WCAG 2.1 AA minimum contrast ratio of 4.5:1 for normal text.

Both gates run in CI on every push and pull request via the `authenticated-smoke-a11y` job.

---

## Authenticated Route Manifest

The following routes are covered by this gate. All require a valid session cookie or redirect to `/authn/login`.

| Route | Auth Level | Expected Behaviour |
|---|---|---|
| `/dashboard` | learner | Learner dashboard — enrolled course list and progress |
| `/account/settings` | learner | Account settings — profile, email, preferences |
| `/learning/course/{course_id}/home` | learner | Course home — per-enrolment course entry point |
| `/admin/` | staff | Django admin — staff and superuser management panel |
| `/cms/` | staff | Studio CMS — course authoring entry point |

**Minimum requirement:** At least 3 routes, covering at least 1 learner route and 1 staff route.

---

## WCAG AA Contrast Validation

### Methodology

WCAG 2.1 relative luminance is computed using the standard formula:

```
L = 0.2126 * R_lin + 0.7152 * G_lin + 0.0722 * B_lin
```

Where `R_lin`, `G_lin`, `B_lin` are linearised sRGB values:

```
if C_sRGB <= 0.04045:
    C_lin = C_sRGB / 12.92
else:
    C_lin = ((C_sRGB + 0.055) / 1.055) ^ 2.4
```

Contrast ratio between foreground `L1` and background `L2` (where L1 > L2):

```
ratio = (L1 + 0.05) / (L2 + 0.05)
```

### Threshold

WCAG 2.1 Level AA for **normal text**: contrast ratio **>= 4.5:1**

### Color Pairs Tested

| Pair | Foreground | Background | Minimum |
|---|---|---|---|
| Body text (ink-900) | `#000000` | `#ffffff` | 4.5:1 |
| Secondary text (ink-700) | `#4a494a` | `#ffffff` | 4.5:1 |
| Link color (blue) on white | `#295cad` | `#ffffff` | 4.5:1 |
| White on blue (primary button) | `#ffffff` | `#295cad` | 4.5:1 |
| White on magenta | `#ffffff` | `#ab3b78` | 4.5:1 |

Colors sourced from:
- `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
- `assets/branding/tokens.css`
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss`

---

## Running the Smoke Test

### Full run (contrast + route manifest + evidence report checks)

```bash
./scripts/qa/verify-authenticated-smoke-a11y.sh
```

### Expected output

```
=== AC-FRONT-031: Authenticated Route Manifest ===
✅ Route manifest has 5 authenticated routes (minimum: 3)
✅ Required route '/dashboard' is present in manifest
✅ Required route '/account' is present in manifest
✅ Required route '/admin' is present in manifest
✅ Route manifest includes learner routes (3 learner routes)
✅ Route manifest includes staff/admin routes (2 staff routes)

=== AC-FRONT-032: Runbook-Grade Smoke Path ===
✅ Smoke path script exists at scripts/qa/verify-authenticated-smoke-a11y.sh
✅ Script is executable
✅ Runbook doc exists at docs/operations/AUTHENTICATED_SMOKE_A11Y.md
...

=== AC-FRONT-033: WCAG AA Contrast Validation ===
✅ PASS  21.00:1  Body text (ink-900 #000000) on white (#ffffff)
✅ PASS  ...
...

RESULT: PASS
```

---

## Failure Handling

### When a contrast check fails

1. Identify the failing color pair from the script output (line shows `❌ FAIL  X.XX:1`).
2. Open the corresponding source file:
   - Token colors: `assets/branding/tokens.css` or `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
   - MFE overrides: `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
3. Either darken the foreground color or lighten the background to increase contrast.
4. Use the WCAG contrast checker at https://webaim.org/resources/contrastchecker/ to validate the new values before committing.
5. Update `docs/operations/evidence/authenticated-smoke-a11y-report.md` with the new ratio.
6. Re-run `./scripts/qa/verify-authenticated-smoke-a11y.sh` to confirm PASS.

### When a required route is missing

1. Add the route to the `AUTHENTICATED_ROUTES` array in `scripts/qa/verify-authenticated-smoke-a11y.sh`.
2. Ensure the entry follows the format: `"path|auth_level|description"`.
3. Valid `auth_level` values: `learner`, `staff`.
4. Update the route table in this runbook and in `docs/operations/evidence/authenticated-smoke-a11y-report.md`.

### When the evidence report is missing

```bash
# Re-create from the report template in the evidence directory
cp docs/operations/evidence/authenticated-smoke-a11y-report.md.example \
   docs/operations/evidence/authenticated-smoke-a11y-report.md
# Or regenerate manually following the structure in the existing report.
```

---

## Rollback

This gate is verification-only. It does not modify any production configuration or deployed assets. No rollback is required.

If a CI failure is blocking a merge unrelated to frontend branding:

1. Confirm the failing AC is genuinely unrelated to the change (check CI job name: `authenticated-smoke-a11y`).
2. If the failure is a pre-existing regression, open a bead to track it.
3. The gate can be bypassed in an emergency by marking the CI job as non-blocking in `.github/workflows/ci.yml` (requires team lead approval and a follow-up bead within 24 hours).
