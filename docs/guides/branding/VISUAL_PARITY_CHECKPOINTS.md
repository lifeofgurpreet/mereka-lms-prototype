# Visual Parity Checkpoints

**Bead**: mereka-lms-115d.23
**Covers**: AC-UI-101, AC-UI-102, AC-UI-103, AC-UI-104, AC-UI-105, AC-UI-106
**Last updated**: 2026-02-18
**Audience**: Platform Engineering / QA

## Purpose

This document defines the visual parity and route-content checkpoint contract
for Mereka Academy's MFE authn/enterprise surfaces. It extends the foundational
screenshot baseline (see `VISUAL_SMOKE_BASELINE.md`) with:

- A 15-point checkpoint matrix (5 routes × 3 enterprise domains)
- Route content markers that prevent false-positive HTTP 200 passes
- Screenshot baseline naming and RMSE diff thresholds
- Branded footer assertions (MerekaFooter, no default Open edX shell)
- Asset integrity checks (fonts, CSS, JS references)
- Release lane instructions for pre-deploy execution

---

## 15-Point Visual Checkpoint Matrix (AC-UI-101)

5 authn surfaces × 3 enterprise domains = 15 deterministic checkpoints.

| Route | MFE App | academyv2.mereka.io | academy.biji-biji.com | biji-biji.com |
|---|---|---|---|---|
| `/learner-dashboard/` | frontend-app-learner-dashboard | ✓ | ✓ | ✓ |
| `/learning/` | frontend-app-learning | ✓ | ✓ | ✓ |
| `/account/` | frontend-app-account | ✓ | ✓ | ✓ |
| `/gradebook/` | frontend-app-gradebook | ✓ | ✓ | ✓ |
| `/profile/` | frontend-app-profile | ✓ | ✓ | ✓ |

**Viewport pairs**: Desktop 1280×800 and mobile 375×812 for each cell.

**Total baselines per release**: 15 cells × 2 viewports = 30 screenshot comparisons minimum.

---

## Route Content Markers (AC-UI-102)

HTTP 200 alone is insufficient to confirm a route rendered correctly. Each
route must contain an expected content marker in the response body. A 200
without the expected marker indicates an authn redirect, shell error, or
blank SPA stub — all false positives.

| Route | Expected Content Marker (case-insensitive regex) |
|---|---|
| `/learner-dashboard/` | `My Courses\|course.*dashboard\|learner.dashboard` |
| `/learning/` | `Course\|lesson\|learning.*content\|unit.*viewer` |
| `/account/` | `Account Settings\|account.*setting\|Change Password` |
| `/gradebook/` | `Gradebook\|grades?\|score\|student.*grade` |
| `/profile/` | `Profile\|Full Name\|Country\|profile.*edit` |

### False-Positive 200 Guard

A plain HTTP 200 response from `apps.*` routes can still mean:

- The user is not authenticated (SPA renders a blank state or silent redirect)
- The route is defined but the MFE chunk failed to load (JS bundle 404)
- The shell rendered but the inner app returned an error

**Rule**: Always grep the response body for the content marker before marking a
route as PASS. Never accept HTTP 200 as the only signal.

---

## Screenshot Baseline Flow (AC-UI-103)

### Naming Convention

Baseline screenshots must follow this deterministic pattern:

```
var/screenshots/baseline/{domain}/{route-slug}/{viewport}.png
```

Examples:

```
var/screenshots/baseline/academyv2.mereka.io/learner-dashboard/desktop.png
var/screenshots/baseline/academyv2.mereka.io/learner-dashboard/mobile.png
var/screenshots/baseline/biji-biji.com/account/desktop.png
```

Where:
- `domain` is the bare hostname (no `https://`, no port)
- `route-slug` is the path segment without leading slash (e.g. `learner-dashboard`)
- `viewport` is one of `desktop` (1280×800) or `mobile` (375×812)

### Capture Command

```bash
# Capture baselines for all 15 checkpoints (requires Playwright + auth):
RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=0 \
  VISUAL_SMOKE_DOMAIN=academyv2.mereka.io \
  SSO_USERNAME="smoke-test@mereka.io" \
  SSO_PASSWORD="<from-infisical>" \
  ./scripts/branding/run-branding-gates.sh prod
```

See `docs/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md` for credential
management and rotation schedule.

### RMSE Diff Threshold Policy

Visual comparisons use ImageMagick `compare -metric RMSE`. Two thresholds:

| Threshold | RMSE Value | When Used |
|---|---|---|
| **Tolerant** | ≤ 5.0 | Feature development; allows minor layout shifts |
| **Strict** | ≤ 2.0 | Pre-release gate; zero tolerance for unintended visual changes |

The pre-deploy release lane (below) uses the **strict** threshold (RMSE ≤ 2.0).

**Triage**: If a diff exceeds threshold:

1. Inspect the diff image at `var/screenshots/diff/{domain}/{route}/{viewport}.png`
2. If intentional (design update), re-capture baseline with `RUN_SCREENSHOTS=1`
3. If unintentional, revert the offending change before deploy

Cross-reference: `docs/operations/VISUAL_SMOKE_BASELINE.md` for the full RMSE
policy including the 5.0 / 2.0 gate lifecycle. See also
`docs/ops/runbooks/VISUAL_REGRESSION_RUNBOOK.md` for ImageMagick command syntax.

### 10 Critical Baseline Routes

The minimum set of 10 checkpoints that must have baselines before any release:

1. `academyv2.mereka.io` / `learner-dashboard` / desktop
2. `academyv2.mereka.io` / `learner-dashboard` / mobile
3. `academyv2.mereka.io` / `learning` / desktop
4. `academyv2.mereka.io` / `account` / desktop
5. `academyv2.mereka.io` / `gradebook` / desktop
6. `academyv2.mereka.io` / `profile` / desktop
7. `academy.biji-biji.com` / `learner-dashboard` / desktop
8. `academy.biji-biji.com` / `account` / desktop
9. `biji-biji.com` / `learner-dashboard` / desktop
10. `biji-biji.com` / `profile` / desktop

---

## Branded Footer Assertions (AC-UI-104)

### Rule

Every `apps.*` MFE shell page **must** render the `MerekaFooter` component.
The default Open edX footer marker (`Powered by Open edX`) **must not** appear
in any MFE shell page.

### How MerekaFooter Is Wired

`MerekaFooter` is injected by `infrastructure/tutor/apply-patches.sh` into
the MFE `env.config.jsx` build artefact:

```jsx
// Expected in tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx
const MerekaFooter = () => { /* ... branded footer JSX ... */ };
// ...
{ id: "mereka_footer", RenderWidget: MerekaFooter }
```

The patch replaces the upstream `RenderWidget: <Footer />` with
`RenderWidget: <MerekaFooter />`. Verify with:

```bash
grep -F 'const MerekaFooter' tutor_env/env/plugins/mfe/build/mfe/indigo/env.config.jsx
```

### Footer Assertion Checks

| Check | Pass Condition | Fail Condition |
|---|---|---|
| MerekaFooter component present | `const MerekaFooter` in env.config.jsx | String absent |
| Default footer suppressed | `Powered by Open edX` absent from MFE pages | String present in response body |
| CSS class present | `.mereka-footer` or `.mereka-footer--v2` in mereka-overrides.css | Class absent |
| apps.* shell pages render footer | Footer DOM node visible in screenshot | Footer absent or invisible |

---

## Asset Integrity Checks (AC-UI-105)

Broken asset references (missing fonts, unresolvable CSS, 404 JS chunks) cause
silent rendering failures that visual regression alone cannot catch. These
checks guard the production image build.

### Source-Level Checks (CI / Offline)

| Asset | Location | Check |
|---|---|---|
| `mereka-overrides.css` | `infrastructure/tutor/themes/mereka/common/static/css/` | File exists, non-empty (> 10 lines) |
| `mereka-design-tokens.css` | `infrastructure/tutor/themes/mereka/common/static/css/` | File exists |
| `mfe/mereka.scss` | `infrastructure/tutor/themes/mereka/mfe/` | File exists, non-empty |
| `assets/branding/tokens.css` | `assets/branding/` | File exists, has ≥ 80 token definitions |
| `common/static/fonts/` | `infrastructure/tutor/themes/mereka/common/static/fonts/` | Directory present |
| `mfe/fonts/` | `infrastructure/tutor/themes/mereka/mfe/fonts/` | Directory present |

### Relative URL Reference Guard

CSS files must not contain relative `url()` references that resolve outside the
theme tree. The verification script checks for broken `../` font paths:

```bash
# Detect relative font references that don't resolve on disk:
grep -oE "url\(['\"]?[^)'\"]+\.(woff2?|ttf|eot|otf)['\"]?\)" \
  infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css
```

Any relative reference that does not resolve within the theme directory is
flagged as a broken asset reference.

### Production Build Guard

After `tutor images build openedx`, run:

```bash
# Verify static asset collection succeeded (no SuspiciousFileOperation):
tutor local run lms python manage.py lms collectstatic --noinput --dry-run 2>&1 \
  | grep -i "error\|warning" | grep -v "^System check" || true
```

A clean output (zero errors) confirms no broken `../../` references slipped
through the CSS.

---

## Release Lane Instructions (AC-UI-106)

### Run Before Any Deploy

This verification script **must** pass before any production or staging deploy
from a release branch:

```bash
# Step 1: Offline checks (always safe to run, no cluster required)
./scripts/qa/verify-visual-parity-checkpoints.sh

# Step 2: Live cluster checks (requires access to production cluster)
VISUAL_PARITY_LIVE=1 \
  VISUAL_PARITY_DOMAIN=academyv2.mereka.io \
  ./scripts/qa/verify-visual-parity-checkpoints.sh

# Step 3: Capture fresh baselines if theme or footer changed
RUN_SCREENSHOTS=1 ./scripts/branding/run-branding-gates.sh prod

# Step 4: Full branding gate (source + live)
RUN_LIVE_GATE=1 BRANDING_LEVEL=deep ./scripts/branding/run-branding-gates.sh prod
```

### Release Branch Checklist

Before tagging a release and deploying:

- [ ] `verify-visual-parity-checkpoints.sh` exits 0 FAIL (offline)
- [ ] `VISUAL_PARITY_LIVE=1 verify-visual-parity-checkpoints.sh` exits 0 FAIL
- [ ] All 10 critical route baselines exist at `var/screenshots/baseline/`
- [ ] RMSE diff ≤ 2.0 for all 10 baseline comparisons (strict gate)
- [ ] `Powered by Open edX` absent from all MFE shell page HTML
- [ ] `MerekaFooter` confirmed present in `env.config.jsx`
- [ ] No broken font/CSS asset references detected
- [ ] `apply-patches.sh` run after last `tutor config save`

### CI Integration

The script is wired into `.github/workflows/ci.yml` under the
`visual-parity-checkpoints` job (PR gate) and the `monitoring-guardrails` job
(syntax check).

Trigger the PR gate by including one of these keywords in the PR title:
`visual`, `parity`, `branding`, `mfe`, `checkpoint`.

---

## References

- `docs/operations/VISUAL_SMOKE_BASELINE.md` — RMSE policy, auth cookie flow, 5-route baseline
- `docs/ops/runbooks/VISUAL_REGRESSION_RUNBOOK.md` — ImageMagick commands, diff triage
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md` — Branding governance and release ops
- `docs/guides/branding/BRANDING_GUARDRAILS.md` — CSS/SCSS guardrails
- `infrastructure/tutor/apply-patches.sh` — MerekaFooter injection source
- `scripts/qa/verify-visual-parity-checkpoints.sh` — Verification script for this spec
- `scripts/qa/verify-visual-smoke-baseline.sh` — Prior baseline verification (AC-VIS-001..004)
- `scripts/branding/run-branding-gates.sh` — Full branding gate runner
