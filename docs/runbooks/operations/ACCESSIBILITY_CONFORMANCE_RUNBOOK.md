# Accessibility Conformance Runbook — Authenticated MFE Routes

**Bead**: mereka-lms-3vg9.2
**Script**: `scripts/qa/verify-a11y-authenticated-routes.sh`
**AC coverage**: AC-ACCSS-201, AC-ACCSS-202, AC-ACCSS-203, AC-ACCSS-204, AC-ACCSS-205
**Last updated**: 2026-02-18

---

## Purpose

This runbook documents the accessibility conformance requirements for authenticated
MFE routes in Mereka Academy. It covers:

- Authenticated route scenarios and landmark requirements
- Focus indicator specifications
- Artifact storage for route-level evidence
- Regression guard and ticket templates for failures

For contrast and focus-visible gate details on public/branding routes, see
[A11Y_CONTRAST_FOCUS_GATE.md](../../operations/A11Y_CONTRAST_FOCUS_GATE.md).

---

## Authenticated Route Scenarios (AC-ACCSS-201)

Three authenticated routes are covered by this gate. Each route requires a logged-in
user session. In offline mode the script validates this documentation; in live mode
(`A11Y_LIVE=1`) it would drive a browser with axe-core assertions.

### Route 1 — Learner Dashboard (`/learner-dashboard`)

**URL pattern**: `https://apps.<domain>/learner-dashboard/`
**MFE**: `frontend-app-learner-dashboard`
**User state**: Authenticated, enrolled in at least one course

**Purpose**: Primary landing page after login. Exposes course cards, progress
indicators, and navigation. Landmark failures here affect the majority of learner
sessions.

### Route 2 — Account / Profile (`/account/`)

**URL pattern**: `https://apps.<domain>/account/`
**MFE**: `frontend-app-account`
**User state**: Authenticated, viewing own profile

**Purpose**: Profile editing, notification preferences, connected accounts. Contains
dense form controls; focus management is critical for screen reader users.

### Route 3 — Learning / Courseware (`/learning/`)

**URL pattern**: `https://apps.<domain>/learning/course/<course-id>/home`
**MFE**: `frontend-app-learning`
**User state**: Authenticated, enrolled in a specific course

**Purpose**: Core learning experience. Unit navigation, video player, and problem
responses. The most complex interactive surface; landmark structure must be
consistent across unit types.

---

## Landmark Requirements Matrix (AC-ACCSS-202)

WCAG 1.3.6 (Identify Purpose, AAA) and general best practice require landmark
regions so that screen reader users can navigate by region.

### Required landmarks per route

| Landmark | HTML element / role | Dashboard | Account | Learning |
|---|---|---|---|---|
| `banner` | `<header>` / `role="banner"` | required | required | required |
| `nav` | `<nav>` / `role="nav"` | required | required | required |
| `main` | `<main>` / `role="main"` | required | required | required |
| `contentinfo` | `<footer>` / `role="contentinfo"` | required | required | required |

### Uniqueness rules

- `banner`, `main`, and `contentinfo` must each appear **exactly once** per page.
- `nav` may appear more than once **only if** each instance has a unique
  `aria-label` (e.g. `aria-label="Primary"`, `aria-label="Course chapters"`).
- Duplicate `main` landmarks are a **blocking failure** per WCAG 1.3.6.

### Live verification approach (A11Y_LIVE=1)

When running with a live LMS, use axe-core or Playwright + `@axe-core/playwright`:

```javascript
// Example: assert required landmarks on /learner-dashboard/
const results = await new AxeBuilder({ page }).analyze();
const landmarks = results.passes.find(r => r.id === 'landmark-one-main');
// Also check: landmark-banner-is-top-level, landmark-contentinfo-is-top-level
```

---

## Focus Indicator Specifications (AC-ACCSS-203)

### Contrast requirement

All focus indicators must meet **3:1 minimum contrast** against adjacent colours per
WCAG 2.2 SC 1.4.11 (Non-text Contrast, Level AA). This applies to:

- The focus ring outline colour vs. the surface behind it
- The focus indicator vs. the interactive element background

A contrast ratio of 3:1 or higher is non-negotiable. Do not rely on colour alone
to communicate focus state.

### Visible outline requirement

Focus indicators must use a **visible outline** (or equivalent enclosed shape).
Colour change alone does not satisfy SC 2.4.7 (Focus Visible, Level AA) or
SC 2.4.11 (Focus Appearance, Level AA in WCAG 2.2).

Acceptable patterns:

```css
/* Recommended: teal glow ring via box-shadow */
:focus-visible {
  outline: 3px solid var(--mereka-color-teal);
  outline-offset: 2px;
}

/* Acceptable alternative: box-shadow ring */
:focus-visible {
  outline: none;
  box-shadow: 0 0 0 4px var(--mereka-mfe-focus);
}
```

Not acceptable:

```css
/* BAD: colour change only, no outline or ring */
:focus { color: var(--mereka-color-teal); }

/* BAD: removes focus ring with no replacement */
:focus { outline: none; }
```

### Primary interactive controls

The following controls on each authenticated route must have visible focus styles:

| Control type | CSS class / element | Minimum standard |
|---|---|---|
| Primary action button | `.btn-primary`, `.pgn__btn--primary` | 3:1 outline |
| Secondary button | `.btn-secondary`, `.pgn__btn--secondary` | 3:1 outline |
| Form input | `.form-control`, `input[type=text]` | 3:1 outline |
| Navigation link | `nav a`, `.nav-link` | 3:1 outline |
| Course card link | `.course-card a`, `.pgn__card a` | 3:1 outline |

### WCAG references

- **SC 1.4.11** Non-text Contrast (Level AA) — 3:1 for UI components and graphical objects
- **SC 2.4.7** Focus Visible (Level AA) — keyboard focus indicator must be visible
- **SC 2.4.11** Focus Appearance (Level AA, WCAG 2.2) — minimum focus indicator area

---

## Artifact Storage and Route-Level Evidence (AC-ACCSS-204)

### Storage path

All a11y gate artifacts are written to:

```
var/a11y/{route}-{timestamp}.json
```

Examples:
- `var/a11y/learner-dashboard-2026-02-18T12-00-00Z.json`
- `var/a11y/account-2026-02-18T12-00-00Z.json`
- `var/a11y/learning-2026-02-18T12-00-00Z.json`

The gate summary (offline mode) is written to:
```
var/a11y-authenticated-routes-gate.txt
```

### Route-level evidence fields (live mode)

Each JSON artifact contains:

```json
{
  "route": "/learner-dashboard/",
  "timestamp": "2026-02-18T12:00:00Z",
  "mode": "live",
  "landmarks": {
    "banner": 1,
    "nav": 2,
    "main": 1,
    "contentinfo": 1
  },
  "landmark_violations": [],
  "focus_checks": [
    { "selector": ".btn-primary", "has_visible_focus": true, "contrast_ratio": 4.5 }
  ],
  "axe_violations": [],
  "pass": true
}
```

### Remediation notes per route

#### `/learner-dashboard` remediation

| Finding | Remediation |
|---|---|
| Missing `<main>` landmark | Wrap course cards section in `<main>` in `frontend-app-learner-dashboard` |
| Duplicate `<nav>` without `aria-label` | Add `aria-label="Primary"` and `aria-label="Course progress"` to distinguish nav regions |
| Course card link missing focus style | Add `.course-card a:focus-visible` rule in MFE SCSS override |

#### `/account/` remediation

| Finding | Remediation |
|---|---|
| Form inputs lose focus ring on hover | Remove `box-shadow: none` from `.form-control:hover:focus` |
| `<header>` not at top level (inside `<main>`) | Move header element outside `<main>` to satisfy `landmark-banner-is-top-level` |

#### `/learning/` remediation

| Finding | Remediation |
|---|---|
| Unit navigation has unlabelled `<nav>` | Add `aria-label="Course chapters"` to secondary nav |
| Video player controls missing focus ring | Inject focus styles via MFE SCSS for `.video-controls button:focus-visible` |

---

## Regression Guard and Ticket Template (AC-ACCSS-205)

When the verification script fails, CI produces a deterministic ticket suggestion.
Each failure maps to one of the following ticket titles, which can be filed directly
in the project issue tracker.

### Failure → ticket template

```
Title: a11y(authenticated-routes): <route> <type> failure — <AC-ID>

Body:
  Route:     <route, e.g. /learner-dashboard/>
  Expected:  <expected landmark count or focus assertion>
  Actual:    <actual state found>
  WCAG SC:   <e.g. SC 1.3.6 or SC 2.4.7>
  Remediation: See docs/runbooks/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md#remediation-notes-per-route
  Severity:  Medium (landmark) / High (focus invisible)
  Labels:    a11y, regression, authenticated-routes
```

### Deterministic ticket suggestion (script output on FAIL)

When `./scripts/qa/verify-a11y-authenticated-routes.sh` exits non-zero, it prints:

```
Regression guard — suggested ticket title for each FAIL:
  a11y(authenticated-routes): <route> landmark/focus failure — <AC-ACCSS-NNN>
```

Use this title verbatim when filing the issue so that it can be cross-referenced
against the bead and AC.

### Severity classification

| Finding type | Severity | Action |
|---|---|---|
| Missing required landmark (`main`, `banner`) | High | Block merge, file ticket |
| Duplicate `main` landmark | High | Block merge, file ticket |
| Unlabelled duplicate `nav` | Medium | Block merge, file ticket |
| Focus ring contrast below 3:1 | High | Block merge, file ticket |
| Focus ring absent on interactive element | High | Block merge, file ticket |
| Missing `contentinfo` (`<footer>`) | Low | WARN only, file ticket within 2 sprints |

### Exception process

If a finding cannot be fixed immediately (e.g., upstream MFE imposes the pattern),
follow the exception process in [A11Y_CONTRAST_FOCUS_GATE.md](../../operations/A11Y_CONTRAST_FOCUS_GATE.md#exception-process)
and add an entry to the accessibility exception register in this runbook family.

---

## CI Integration

The gate runs as a dedicated job (`a11y-authenticated-routes`) in
`.github/workflows/ci.yml`.

**Triggers**: PRs with titles containing `a11y`, `accessibility`, `landmark`,
`focus`, or `authenticated`.

**Offline mode** (default): validates this runbook's documentation and structure.
Zero dependencies — runs in any CI environment.

**Live mode** (`A11Y_LIVE=1`): requires a running LMS. Intended for pre-release
or nightly runs, not standard PR gates.

**Artifacts**: `var/a11y-authenticated-routes-gate.txt` and per-route JSON in
`var/a11y/` (live mode only).

---

## Related Documents

- `docs/runbooks/operations/A11Y_CONTRAST_FOCUS_GATE.md` — Token contrast + focus-visible gate (public routes)
- Accessibility exception log (to be maintained in the active operations evidence register)
- `scripts/qa/verify-a11y-contrast-focus.sh` — Contrast + focus-visible verification script
- `scripts/qa/verify-a11y-authenticated-routes.sh` — This gate's verification script
- `scripts/qa/verify-ui-accessibility.sh` — Broader axe journey coverage gate
