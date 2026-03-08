# Accessibility Regression Lane

**Bead:** 2dcy.3.1
**ACs:** AC-FRONT-071, AC-FRONT-072, AC-FRONT-073, AC-FRONT-074, AC-FRONT-075
**Script:** `scripts/qa/verify-a11y-regression-lane.sh`
**Parent bead:** 2dcy.3 (`scripts/qa/verify-authenticated-smoke-a11y.sh`)

---

## What This Covers

This runbook documents the accessibility regression lane for the Mereka LMS frontend. It extends the parent gate (bead 2dcy.3) with source-level checks for three categories of WCAG 2.1 conformance that cannot be verified with live browser automation in CI:

1. **Focus visibility** — keyboard focus rings are styled and not suppressed to `none` or `transparent`.
2. **Labels** — form controls and interactive elements use Paragon focus token patterns.
3. **Landmarks** — injected HTML (footer, nav) uses ARIA landmark roles (`role="contentinfo"`, `<nav>`).

Because CI runs without a browser, all checks are **source-level**: we grep SCSS, plugin source, and runbook files to confirm the a11y-relevant patterns are present and correctly wired.

---

## Route Manifest for A11y

The following three routes are the target set for this a11y regression lane:

| Route | Auth Level | What Is Checked |
|---|---|---|
| `/authn/login` | public | Landmark roles in injected footer (`role="contentinfo"`, `<nav>`); no focus suppression |
| `/dashboard` | learner | Focus ring via `box-shadow`, `--mereka-mfe-focus` token defined, `:focus` rules present |
| `/account/settings` | learner | Paragon form control focus styling, `--mereka-mfe-focus` not set to `transparent` |

---

## Source-Level A11y Checks

### Login page — landmarks

| Check | Source file | Pattern |
|---|---|---|
| `role="contentinfo"` on footer | `infrastructure/tutor/plugins/mereka_lms.py` | `role="contentinfo"` |
| `<nav>` landmark | `infrastructure/tutor/plugins/mereka_lms.py` | `<nav ` |

The login MFE (`/authn/login`) uses the Mereka footer component injected via `mereka_lms.py`. The footer wraps its content in `<footer role="contentinfo">` (ARIA `contentinfo` landmark) and includes a `<nav>` element for footer navigation links.

### Dashboard — focus-visible styling

| Check | Source file | Pattern |
|---|---|---|
| `:focus` rules exist | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | `:focus` |
| Focus ring uses `box-shadow` | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | `box-shadow` |
| Focus token defined | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | `--mereka-mfe-focus` |
| Focus ring not suppressed | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | No `:focus { outline: none }` or `:focus { box-shadow: none }` |

The `--mereka-mfe-focus` CSS custom property holds the focus ring color (`rgba(45, 137, 139, 0.18)` — teal at 18% opacity). This is applied via `box-shadow` on interactive elements including `.pgn__form-control:focus` and `.form-control:focus`.

### Profile — Paragon focus tokens

| Check | Source file | Pattern |
|---|---|---|
| Paragon form control has focus style | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | `pgn__form-control:focus` |
| Focus token not transparent | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | `--mereka-mfe-focus` value is not `transparent` |

The profile / account-settings route (`/account/settings`) renders Paragon form inputs. The `mereka.scss` overrides the default Paragon focus ring color with the Mereka teal token.

---

## Running the Check

```bash
# Full a11y regression lane run
./scripts/qa/verify-a11y-regression-lane.sh
```

### Expected output (all PASS)

```
=== AC-FRONT-071: Parent Script Route Coverage ===
✅ AC-FRONT-071: Parent script exists at scripts/qa/verify-authenticated-smoke-a11y.sh
✅ AC-FRONT-071: Parent script defines N route entries (>= 3 required)
...

=== AC-FRONT-073: Source-Level A11y Checks (Focus / Labels / Landmarks) ===
✅ AC-FRONT-073: mereka_lms.py injects role="contentinfo" landmark in footer
✅ AC-FRONT-073: mereka_lms.py injects <nav> landmark element
✅ AC-FRONT-073: mereka.scss defines :focus styling rules for dashboard route
✅ AC-FRONT-073: mereka.scss uses box-shadow for focus ring (Paragon pattern)
✅ AC-FRONT-073: mereka.scss defines --mereka-mfe-focus token for focus ring color
✅ AC-FRONT-073: No :focus rules suppress focus ring to none/transparent
...

RESULT: PASS
```

---

## Failure Handling

### When a landmark check fails

1. Open `infrastructure/tutor/plugins/mereka_lms.py` and locate the `MerekaFooter` component.
2. Ensure the outer `<footer>` element has `role="contentinfo"`.
3. Ensure footer navigation links are wrapped in a `<nav>` element.
4. Re-run `./scripts/qa/verify-a11y-regression-lane.sh` to confirm PASS.

### When a focus ring check fails

1. Open `infrastructure/tutor/themes/mereka/mfe/mereka.scss`.
2. Search for `:focus` rules.
3. Confirm that at least one rule sets `box-shadow` using `var(--mereka-mfe-focus)`.
4. Confirm that the `--mereka-mfe-focus` token is defined at the top of the file with a non-transparent value.
5. Confirm no rule sets `outline: none` or `box-shadow: none` on a `:focus` selector without providing an alternative.
6. Re-run the check.

### When the evidence report is missing

```bash
# Re-create from scratch using the structure in:
# docs/archive/evidence/operations/a11y-regression-lane-report.md
```

The evidence report must:
- Reference parent bead 2dcy.3
- Include a pass/fail summary table
- Include a follow-up blockers section

---

## Relationship to Parent Bead (2dcy.3)

| Bead | Script | What It Covers |
|---|---|---|
| 2dcy.3 | `verify-authenticated-smoke-a11y.sh` | Route manifest (AC-FRONT-031), runbook (AC-FRONT-032), WCAG contrast (AC-FRONT-033), evidence report (AC-FRONT-034) |
| 2dcy.3.1 | `verify-a11y-regression-lane.sh` | Confirms 2dcy.3 coverage (AC-FRONT-071, -072), adds focus/label/landmark source checks (AC-FRONT-073), branding evidence artifact (AC-FRONT-074), parent update (AC-FRONT-075) |

This script does **not** re-run the parent script. It verifies the parent script's existence and structural properties, then adds new source-level a11y checks that the parent does not cover.

---

## Rollback

This gate is verification-only. It does not modify any deployed configuration or assets.

If a CI failure blocks an unrelated merge:

1. Confirm the failing AC is genuinely unrelated to the change.
2. If the failure is a pre-existing regression, open a bead to track it.
3. The gate can be made non-blocking in `.github/workflows/ci.yml` in an emergency (requires team lead approval and a follow-up bead within 24 hours).
