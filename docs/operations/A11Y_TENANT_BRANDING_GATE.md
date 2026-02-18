# A11y Tenant Branding Gate

**Bead**: mereka-lms-3vg9.3
**Script**: `scripts/qa/verify-a11y-tenant-branding.sh`
**AC coverage**: AC-A11Y-301, AC-A11Y-302, AC-A11Y-303, AC-A11Y-304
**CI job**: `a11y-tenant-branding`
**Last updated**: 2026-02-18

---

## Purpose

This gate extends the existing a11y regression lane to cover:

1. **Keyboard/focus patterns** for four MFE routes (authn, dashboard, account, course-authoring)
2. **Landmark/ARIA requirements** for authenticated shell routes, with machine-readable JSON output
3. **Contrast assertions** for branded elements (buttons using `--mereka-primary`, headers using `--mereka-ink-*`) in enterprise tenant themes
4. **Integration** — how this script relates to the two existing a11y scripts and CI

For the upstream contrast and focus-visible gate see
[A11Y_CONTRAST_FOCUS_GATE.md](A11Y_CONTRAST_FOCUS_GATE.md). For authenticated route landmark
details see [ACCESSIBILITY_CONFORMANCE_RUNBOOK.md](ACCESSIBILITY_CONFORMANCE_RUNBOOK.md).

---

## Route Keyboard/Focus Requirements (AC-A11Y-301)

Four routes are in scope for this bead. Each must satisfy the keyboard/focus rules below.

### Route 1 — Authn (`/authn/`)

**MFE**: `frontend-app-authn`
**URL pattern**: `https://apps.<domain>/authn/login`

| Requirement | Standard | Notes |
|---|---|---|
| Tab order follows visual/DOM order | WCAG 1.3.2, 2.4.3 | Login form → SSO buttons → footer links |
| Focus trap absent on login page | WCAG 2.1.2 | No modal traps on initial load |
| Visible focus ring on all interactive elements | WCAG 2.4.7 | Inputs, buttons, social-login links |
| Focus ring meets 3:1 contrast | WCAG 1.4.11 | `--mereka-mfe-focus` token applied |

### Route 2 — Learner Dashboard (`/learner-dashboard`)

**MFE**: `frontend-app-learner-dashboard`
**URL pattern**: `https://apps.<domain>/learner-dashboard/`

| Requirement | Standard | Notes |
|---|---|---|
| Course card links keyboard-reachable | WCAG 2.1.1 | All `.course-card a` in tab order |
| Skip-to-main link present | WCAG 2.4.1 | Visible on focus, hidden at rest |
| Focus ring on course cards | WCAG 2.4.7 | `.course-card a:focus-visible` styled |
| Correct tab order across card grid | WCAG 1.3.2 | Left-to-right, row by row |

### Route 3 — Account (`/account/`)

**MFE**: `frontend-app-account`
**URL pattern**: `https://apps.<domain>/account/`

| Requirement | Standard | Notes |
|---|---|---|
| Form input focus ring on all fields | WCAG 2.4.7 | `.form-control:focus-visible` styled |
| Focus not lost after save/update | WCAG 2.4.3 | Focus returns to trigger element |
| Keyboard-accessible toggle switches | WCAG 2.1.1 | Space/Enter toggles preference |
| No focus trap in notification panel | WCAG 2.1.2 | Panel dismissable with Escape |

### Route 4 — Course Authoring (`/course-authoring/`)

**MFE**: `frontend-app-course-authoring`
**URL pattern**: `https://apps.<domain>/course-authoring/`

| Requirement | Standard | Notes |
|---|---|---|
| Course unit navigation keyboard-reachable | WCAG 2.1.1 | Sidebar units all in tab order |
| Drag-and-drop alternative available | WCAG 2.1.1 | Keyboard reorder via menu/buttons |
| Focus ring on toolbar buttons | WCAG 2.4.7 | All toolbar buttons show focus ring |
| Rich text editor keyboard-accessible | WCAG 2.1.1 | Standard editor keyboard shortcuts work |

---

## Landmark/ARIA Matrix (AC-A11Y-302)

### Required landmarks per route

All four routes must include the ARIA landmark regions listed below. The matrix covers
both the authenticated shell (header/footer from LMS shell) and the MFE body.

| Landmark | HTML / role | authn | dashboard | account | course-authoring |
|---|---|---|---|---|---|
| `banner` | `<header>` / `role="banner"` | required | required | required | required |
| `nav` | `<nav>` / `role="nav"` | conditional* | required | required | required |
| `main` | `<main>` / `role="main"` | required | required | required | required |
| `contentinfo` | `<footer>` / `role="contentinfo"` | required | required | required | required |

\* `nav` on `/authn/login` may be absent if no navigation is rendered before authentication.
   If present, it must have `aria-label="Site navigation"`.

### Uniqueness rules

- `banner`, `main`, and `contentinfo` must each appear **exactly once** per page.
- `nav` may appear more than once **only if** each instance has a unique `aria-label`.
- Duplicate `main` landmarks are a **blocking failure** per WCAG 1.3.6.

### JSON output format

All landmark audit results are written to:

```
var/a11y/{route}-landmarks.json
```

Examples:
- `var/a11y/authn-landmarks-offline.json`
- `var/a11y/dashboard-landmarks-2026-02-18T12-00-00Z.json`
- `var/a11y/account-landmarks-2026-02-18T12-00-00Z.json`
- `var/a11y/course-authoring-landmarks-2026-02-18T12-00-00Z.json`

Each JSON file follows this schema:

```json
{
  "route": "/authn/login",
  "timestamp": "2026-02-18T12:00:00Z",
  "mode": "offline | live",
  "landmarks": {
    "banner": 1,
    "nav": 0,
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

### Live verification approach (`A11Y_TENANT_LIVE=1`)

When running with a live LMS, use axe-core or Playwright + `@axe-core/playwright`:

```javascript
// Example: assert required landmarks on /learner-dashboard/
const results = await new AxeBuilder({ page }).analyze();
// Check: landmark-one-main, landmark-banner-is-top-level, landmark-contentinfo-is-top-level
// Check course-authoring specific: landmark-unique (no duplicate nav without aria-label)
```

---

## Branded Element Contrast Assertions (AC-A11Y-303)

### Primary button (`--mereka-primary` / `btn-primary`)

Mereka's primary button uses a gradient (`--mereka-mfe-gradient`):
`--mereka-color-magenta → --mereka-color-teal → --mereka-color-blue`.
The label text is `#ffffff` (white). Each gradient endpoint must meet WCAG AA 3:1
(UI component threshold per SC 1.4.11).

| Pair | Foreground | Background token | Hex | Threshold | Standard |
|---|---|---|---|---|---|
| btn-primary label on magenta | `#ffffff` | `--mereka-color-magenta` | `#ab3b78` | 3:1 | SC 1.4.11 |
| btn-primary label on teal | `#ffffff` | `--mereka-color-teal` | `#297F81` | 3:1 | SC 1.4.11 |
| btn-primary label on blue | `#ffffff` | `--mereka-color-blue` | `#295cad` | 3:1 | SC 1.4.11 |

### Page headers (`--mereka-ink-*` tokens)

Page headers use `--mereka-color-ink-900` or `--mereka-color-ink-700` on the surface
background (`--mereka-color-neutral-100` ≈ `#FBFAFB`). Headers at design-system sizes
(≥18px regular / ≥14px bold) must meet the large-text threshold of 3:1 (SC 1.4.3).
Normal-weight body headers must meet 4.5:1.

| Pair | Foreground | Background | Threshold | Standard |
|---|---|---|---|---|
| H1–H3 (large) | `$color-ink-900` (#000000) | `$color-neutral-100` (#FBFAFB) | 3:1 | SC 1.4.3 large text |
| H4–H6 / subheading | `$color-ink-700` (#4A494A) | `$color-neutral-100` (#FBFAFB) | 3:1 | SC 1.4.3 large text |
| Enterprise header on white | `$color-ink-900` (#000000) | `#ffffff` | 4.5:1 | SC 1.4.3 normal text |
| Enterprise header on white | `$color-ink-700` (#4A494A) | `#ffffff` | 4.5:1 | SC 1.4.3 normal text |

### Enterprise tenant theme overrides

Enterprise tenants may override `--mereka-primary` and `--mereka-ink-*` tokens.
Any override must:

1. Maintain 3:1 minimum on button label text (UI component threshold).
2. Maintain 4.5:1 minimum on normal body text in headers.
3. Be validated by re-running this script with `A11Y_TENANT_LIVE=1 TENANT_HOST=<domain>`.

Cross-reference with token pairs table in
[A11Y_CONTRAST_FOCUS_GATE.md](A11Y_CONTRAST_FOCUS_GATE.md#token-pairs-checked).

---

## Integration (AC-A11Y-304)

### Relationship to existing a11y scripts

This script (`verify-a11y-tenant-branding.sh`) is the **umbrella integration** for the
3vg9.3 regression lane. It builds on and cross-validates the two existing scripts:

| Script | Scope | Relationship |
|---|---|---|
| `scripts/qa/verify-a11y-contrast-focus.sh` | Token contrast + focus-visible for all theme files | Prerequisite — must exist and pass. This script cross-references its token pairs for branded element assertions. |
| `scripts/qa/verify-a11y-authenticated-routes.sh` | Landmark/focus for `/learner-dashboard`, `/account/`, `/learning/` | Prerequisite — extends coverage to `/authn/` and `/course-authoring/`. |
| `scripts/qa/verify-a11y-tenant-branding.sh` | This script — keyboard/focus (4 routes) + landmark JSON + branded contrast + CI integration | Integrates and extends the above two scripts. |

### Running standalone

```bash
# Offline (default) — validates documentation + source patterns
./scripts/qa/verify-a11y-tenant-branding.sh

# Live mode — future: requires running LMS + tenant host
A11Y_TENANT_LIVE=1 TENANT_HOST=tenant.academyv2.mereka.io ./scripts/qa/verify-a11y-tenant-branding.sh
```

### CI opt-in

The `a11y-tenant-branding` CI job triggers on PRs with titles containing any of:
`a11y`, `accessibility`, `tenant`, `branding`, `contrast`.

See `.github/workflows/ci.yml` job `a11y-tenant-branding`.

---

## WCAG References

| Success Criterion | Level | Requirement |
|---|---|---|
| SC 1.3.2 Meaningful Sequence | A | Tab order follows visual order |
| SC 1.4.3 Contrast Minimum | AA | 4.5:1 normal text, 3:1 large text |
| SC 1.4.11 Non-text Contrast | AA | 3:1 for UI components (buttons, focus rings) |
| SC 2.1.1 Keyboard | A | All functionality keyboard-accessible |
| SC 2.1.2 No Keyboard Trap | A | Focus not trapped except in modals with Escape |
| SC 2.4.1 Bypass Blocks | A | Skip-to-main link on each page |
| SC 2.4.3 Focus Order | A | Focus order preserves meaning and operation |
| SC 2.4.7 Focus Visible | AA | Keyboard focus indicator visible |
| SC 2.4.11 Focus Appearance | AA (WCAG 2.2) | Minimum focus indicator area |

---

## CI Artifacts

| Artifact | Path | Contents |
|---|---|---|
| Gate summary | `var/a11y/a11y-tenant-branding-gate.txt` | pass/warn/fail counts, run timestamp |
| Route landmark JSON | `var/a11y/{route}-landmarks-{timestamp}.json` | Landmark counts, violations, focus checks |

---

## Related Documents

- `docs/operations/A11Y_CONTRAST_FOCUS_GATE.md` — Token contrast + focus-visible gate (public routes)
- `docs/operations/ACCESSIBILITY_CONFORMANCE_RUNBOOK.md` — Landmark requirements for authenticated routes
- `docs/operations/A11Y_EXCEPTIONS.md` — Active exception log (create when first needed)
- `scripts/qa/verify-a11y-contrast-focus.sh` — Contrast + focus-visible verification
- `scripts/qa/verify-a11y-authenticated-routes.sh` — Authenticated route landmark/focus gate
- `scripts/qa/verify-a11y-tenant-branding.sh` — This gate's verification script
