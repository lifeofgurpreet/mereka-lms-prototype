---
title: "Frontend Accessibility: WCAG 2.1 AA Compliance for Mereka Branding Overlays"
type: "feature_spec"
status: "draft"
version: "1.0.0"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-27"
depends_on:
  - "specs/branding-system_spec.md"
  - "specs/cross-cutting-requirements_spec.md"
links:
  related_docs:
    - "docs/BRANDING.md"
    - "docs/branding/BRANDING_GUARDRAILS.md"
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/mfe-plugin-slots_spec.md"
    - "specs/design-tokens-system_spec.md"
    - "specs/paragon-design-tokens-migration_spec.md"
---

# Human Summary

## What is changing

This spec defines WCAG 2.1 AA accessibility requirements for all custom Mereka branding overlays applied on top of the Open edX platform. The scope covers:

- **Custom SCSS overrides** in `infrastructure/tutor/themes/mereka/mfe/mereka.scss` (614 lines) and `infrastructure/tutor/themes/mereka/scss/theme.scss` (860 lines) that modify color, focus states, and typography for 12 React MFEs
- **Custom Django templates** (`footer.html`, `header/brand.html`, `head-extra.html`, `index_overlay.html`) that add Mereka-specific HTML to the LMS and Studio
- **MerekaFooter component** injected into all MFEs via Tutor plugin
- **Color palette** defined in `infrastructure/tutor/themes/mereka/scss/_tokens.scss` (teal #237072, magenta #ab3b78, blue #295cad, burgundy #8c002f, etc.)
- **CI pipeline** (`accessibility-audit.yml`) currently running axe-core in advisory mode (`continue-on-error: true`)

This spec does NOT cover upstream Paragon component library accessibility -- that is the responsibility of the Open edX community. We cover only the delta introduced by Mereka's customizations.

## Why

Mereka Academy serves learners across Southeast Asia, including users with visual impairments, motor disabilities, and those using assistive technology. Malaysia's Persons with Disabilities Act 2008 and the broader ASEAN Enabling Masterplan emphasize digital accessibility. Additionally:

- The custom SCSS overrides modify focus indicators, color contrast, and interactive element styling -- any regression breaks assistive technology compatibility
- The gradient backgrounds on primary buttons (`var(--mereka-mfe-gradient)`) risk insufficient contrast for button text
- The dark footer (`#1A1623` background) uses `rgba(255,255,255,0.6)` and `rgba(255,255,255,0.8)` text -- contrast ratios must be verified
- The current axe-core CI workflow is advisory-only, providing no enforcement

## Success looks like

- Zero critical or serious axe-core violations attributed to Mereka customizations on all 5 audited routes (/, /login, /register, /dashboard, /courses)
- Lighthouse accessibility score >= 90 on LMS homepage and login page
- All custom interactive elements (MerekaFooter links, header logo, hero buttons) are keyboard-navigable with visible focus indicators
- Screen reader users can navigate the custom footer, header, and course cards without encountering unlabeled elements or missing landmarks
- CI pipeline blocks merges when Mereka-introduced accessibility violations are detected

---

# Agent Contract

## Scope

### In Scope

- Color contrast verification for all Mereka brand colors against their actual usage backgrounds
- Focus indicator visibility on all custom-styled interactive elements (buttons, links, form controls, nav items)
- Keyboard navigation for MerekaFooter, header brand area, hero section, and custom course cards
- Screen reader compatibility for custom Django templates (`footer.html`, `brand.html`, `index_overlay.html`)
- ARIA attributes and semantic HTML in MerekaFooter (MFE) and LMS footer template
- RTL support verification for custom SCSS (existing `lms-main-v1-rtl.scss` entry point)
- Reduced motion support (`@prefers-reduced-motion`) for custom animations and transitions
- Font sizing audit (rem vs px) in custom SCSS
- axe-core CI gate configuration (promote from advisory to blocking)
- Lighthouse accessibility score threshold in CI
- Manual testing checklist for screen readers (NVDA, VoiceOver) and keyboard-only navigation

### Out of Scope

- Upstream Paragon component library accessibility (maintained by Open edX community)
- Upstream Open edX platform template accessibility (e.g., courseware XBlock rendering)
- Third-party MFE accessibility beyond Mereka's CSS overrides
- Mobile native app accessibility (separate spec if needed)
- AAA-level WCAG compliance (targeting AA only)
- Content-level accessibility (alt text on course images uploaded by instructors)

## Non-goals

- We are NOT auditing or fixing upstream Open edX accessibility issues
- We are NOT implementing a custom accessibility widget or overlay tool
- We are NOT targeting WCAG 2.2 AAA compliance
- We are NOT building automated visual regression testing for accessibility (tracked in CI/CD pipeline spec)

## Requirements

### Functional

#### Color Contrast (WCAG SC 1.4.3, SC 1.4.11)

- All Mereka brand color combinations used for text MUST meet WCAG 2.1 AA contrast ratios: >= 4.5:1 for normal text, >= 3:1 for large text (>= 18pt or >= 14pt bold)
- All Mereka brand color combinations used for UI components and graphical objects (focus indicators, borders conveying meaning) MUST meet >= 3:1 contrast against adjacent colors
- Gradient backgrounds used under text MUST be evaluated at their lightest gradient stop (worst-case contrast)

#### Focus Indicators (WCAG SC 2.4.7)

- All custom-styled interactive elements MUST display a visible focus indicator on keyboard focus
- Custom focus indicators MUST NOT be suppressed via `outline: none` unless an equivalent visible replacement (box-shadow, border) is provided
- Focus indicators MUST NOT be obscured by parent elements with `overflow: hidden`

#### Keyboard Navigation (WCAG SC 2.1.1, SC 2.1.2)

- All custom interactive elements MUST be operable via keyboard alone
- Tab order through Mereka customizations MUST follow logical reading order
- The system MUST NOT introduce keyboard traps in any custom component

#### Screen Reader Compatibility (WCAG SC 1.1.1, SC 1.3.1, SC 4.1.2)

- All custom images MUST have meaningful `alt` text
- Custom footer and header landmarks MUST use semantic HTML (`<footer>`, `<nav>`, `<header>`) or equivalent ARIA roles
- Icon-only links MUST have accessible names via `aria-label`, visible text, or SVG `<title>`

#### RTL and Internationalization (WCAG SC 1.3.4)

- Custom SCSS SHOULD use CSS logical properties (`margin-inline-end` instead of `margin-right`) for directional spacing
- RTL SCSS entry point (`lms-main-v1-rtl.scss`) MUST compile without errors

#### Motion and Adaptability (WCAG SC 2.3.3)

- All custom CSS transitions and transforms MUST be wrapped in `@media (prefers-reduced-motion: no-preference)` or suppressed under `@media (prefers-reduced-motion: reduce)`
- The system MUST NOT rely on animation as the sole means of conveying information

#### Font Sizing (WCAG SC 1.4.4)

- Font sizes in custom SCSS MUST use relative units (`rem`, `em`) for body and interactive text
- Fixed `px` values are permitted only for decorative elements (borders, shadows, icon dimensions, touch-target minimum heights)

#### CI Enforcement

- The `accessibility-audit.yml` workflow MUST fail (not advisory) when critical or serious axe-core violations are detected on Mereka-customized routes
- A Lighthouse accessibility score threshold SHOULD be enforced in CI

### Non-Functional Requirements

- axe-core CI audit MUST complete within 5 minutes for all 5 routes combined
- Accessibility fixes MUST NOT increase total theme static asset size beyond the 5 MB budget (per branding-system_spec.md)

## Acceptance Criteria

### Color Contrast

- [ ] AC-A11Y-001: Given the Mereka teal (#237072) is used as text color on white (#FFFFFF) background, when measured, then the contrast ratio MUST be >= 4.5:1 for normal text and >= 3:1 for large text (>= 18pt or >= 14pt bold).
- [ ] AC-A11Y-002: Given the Mereka magenta (#ab3b78) is used as `--pgn-color-primary` for primary button text on white background, when measured, then the contrast ratio MUST be >= 4.5:1.
- [ ] AC-A11Y-003: Given the Mereka blue (#295cad) is used as link color (`$color-info`) on the surface-primary (#FBFAFB) background, when measured, then the contrast ratio MUST be >= 4.5:1.
- [ ] AC-A11Y-004: Given the dark footer uses white text (`rgba(255,255,255,0.8)`) on #1A1623 background, when measured, then the contrast ratio MUST be >= 4.5:1 for body text and >= 3:1 for large text.
- [ ] AC-A11Y-005: Given the dark footer uses muted text (`rgba(255,255,255,0.6)`) for copyright and legal links, when measured, then the contrast ratio MUST be >= 4.5:1 for normal text or the text MUST be classified as large text (>= 18pt).
- [ ] AC-A11Y-006: Given the gradient primary buttons use white (#fff) text on a background blending teal (#237072) and blue (#295cad), when measured at the lightest point of the gradient, then the contrast ratio MUST be >= 4.5:1.
- [ ] AC-A11Y-007: Given the ink-500 color (#6B6B6B) is used for secondary text (taglines, course organization, footer descriptions) on white or surface-primary background, when measured, then the contrast ratio MUST be >= 4.5:1 or the text MUST be >= 18pt.

### Focus Indicators

- [ ] AC-A11Y-008: Given any custom-styled button (.btn-primary, .pgn__btn--primary, .learn-more, .enter-course, .footer-cta-btn, .footer-whatsapp-btn), when it receives keyboard focus, then a visible focus indicator MUST appear that has a contrast ratio of >= 3:1 against adjacent colors and is not obscured by `overflow: hidden`.
- [ ] AC-A11Y-009: Given the Mereka form controls (.pgn__form-control:focus, .form-control:focus) define a custom focus ring (`box-shadow: 0 0 0 4px var(--mereka-mfe-focus)`), when any form input receives keyboard focus, then the focus ring MUST be visible and MUST NOT be suppressed by `outline: none` without an equivalent replacement.
- [ ] AC-A11Y-010: Given the header logo link (`.mereka-navbar-brand a`), when it receives keyboard focus, then a visible focus indicator MUST appear that meets WCAG 2.1 SC 2.4.7 (Focus Visible).
- [ ] AC-A11Y-011: Given any link in the MerekaFooter (MFE) or LMS footer template, when it receives keyboard focus, then a visible focus indicator MUST appear that is distinguishable from the hover state.

### Keyboard Navigation

- [ ] AC-A11Y-012: Given a keyboard-only user on the LMS homepage, when they press Tab repeatedly, then focus MUST move through all interactive elements (header logo, nav links, hero buttons, course cards, footer links) in a logical reading order without keyboard traps.
- [ ] AC-A11Y-013: Given the MerekaFooter contains navigation links organized in columns (Explore, Support, Partners), when a keyboard user tabs through the footer, then links MUST be reachable in column order and no link MUST be skipped.
- [ ] AC-A11Y-014: Given the custom authn card on /login and /register, when a keyboard user navigates the form, then all form fields, buttons, and hyperlinks within the card MUST be reachable via Tab/Shift+Tab.

### Screen Reader Compatibility

- [ ] AC-A11Y-015: Given the LMS footer template (`footer.html`), when rendered, then the `<footer>` element MUST have `role="contentinfo"` (already present) and all footer column headings (`<h6>`) MUST be semantically associated with their link lists via heading hierarchy or `aria-labelledby`.
- [ ] AC-A11Y-016: Given the header brand template (`brand.html`), when the logo image is rendered, then it MUST have an alt attribute containing the platform name (verified: `alt="${_('{platform_name} home').format(platform_name=static.get_platform_name())}"`), and the tagline span MUST NOT be the only means of conveying the brand identity.
- [ ] AC-A11Y-017: Given the MerekaFooter React component injected into MFEs, when a screen reader navigates it, then the footer MUST be wrapped in a `<footer>` landmark with an accessible name (e.g., `aria-label="Mereka Academy footer"`).
- [ ] AC-A11Y-018: Given the footer social media icon links (`.footer-social-link`), when rendered, then each link MUST have either visible text, an `aria-label`, or an `<svg>` with `role="img"` and a `<title>` element describing the social platform.

### RTL Support

- [ ] AC-A11Y-019: Given the LMS is loaded in an RTL language (e.g., Arabic), when custom Mereka SCSS is applied, then all layout directions (flexbox `gap`, `margin-right` on `.mereka-course-chip`, grid `grid-template-columns`) MUST mirror correctly, with no overlapping elements or clipped text. The `lms-main-v1-rtl.scss` entry point MUST compile without errors.

### Reduced Motion and Font Sizing

- [ ] AC-A11Y-020: Given a user has enabled `prefers-reduced-motion: reduce` in their OS settings, when viewing any Mereka-styled page, then all CSS transitions (`.course:hover transform`, `.learn-more:hover transform`, `.btn-primary:hover transform`, `.footer-social-link:hover transform`) MUST be suppressed or reduced to opacity-only changes.
- [ ] AC-A11Y-021: Given the custom SCSS in `mereka.scss` and `theme.scss`, when audited, then font sizes MUST use `rem` or `em` units (not `px`) for all body and interactive text so that browser zoom and user font-size preferences are respected. Fixed `px` values are permitted only for decorative elements (borders, shadows, icon sizing).

### CI Integration

- [ ] AC-A11Y-022: Given the `accessibility-audit.yml` GitHub Actions workflow, when a push to `main` modifies files under `infrastructure/tutor/themes/**` or `infrastructure/tutor/plugins/**`, then axe-core MUST run against all 5 routes (/, /login, /register, /dashboard, /courses) and the job MUST fail (not `continue-on-error`) if any critical or serious violations are found.
- [ ] AC-A11Y-023: Given a Lighthouse CI check is configured, when run against the LMS homepage and /login page, then the accessibility category score MUST be >= 90 and the job MUST report the score in the GitHub Actions summary.

### Non-Functional Requirements

- [ ] AC-A11Y-024: Given the axe-core audit runs in CI, when executed, then it MUST complete within 5 minutes for all 5 routes combined.
- [ ] AC-A11Y-025: Given any accessibility fix is applied to custom SCSS or templates, when the fix is deployed, then it MUST NOT increase total theme static asset size beyond the 5 MB budget defined in branding-system_spec.md.

**Cross-Cutting Inheritance**: This spec inherits requirements from `specs/cross-cutting-requirements_spec.md` including:
- Common NFR thresholds (page load p95 < 3 seconds)
- Observability baseline (CI reporting)

Only accessibility-specific NFRs are listed above.

### Cross-Spec Integration

#### Branding System (branding-system_spec.md)

- [ ] AC-INT-001: Given `branding-system_spec.md` AC-BRD-NFR-002 states "Branding elements SHOULD meet WCAG 2.1 AA contrast ratios", when this spec is approved, then the SHOULD in branding-system is upgraded to MUST for all Mereka color combinations verified by AC-A11Y-001 through AC-A11Y-007.

## Dependencies

### Upstream

- **branding-system_spec.md**: Color palette, theme structure, and MerekaFooter component definition
- **Paragon component library**: Provides baseline WCAG 2.1 AA compliance for standard components; Mereka overrides must not degrade it

### Downstream

- **design-tokens-system_spec.md**: Color validation rules should incorporate contrast ratio checks defined here
- **mfe-plugin-slots_spec.md**: FPF slot components must meet the focus indicator and keyboard navigation requirements defined here

## Edge Cases

### 1. Gradient Button Contrast at Midpoint

**Scenario**: The `var(--mereka-mfe-gradient)` blends from magenta (#ab3b78 at 0%) through teal (#237072 at 60%) to blue (#295cad at 100%). At certain gradient midpoints, the interpolated color may be lighter than either endpoint, potentially failing contrast against white text.

**Mitigation**: Measure contrast at 10% intervals across the gradient. If any midpoint fails 4.5:1 against white, darken that gradient stop or add a semi-transparent dark overlay.

### 2. Focus Ring Clipped by overflow: hidden

**Scenario**: Custom card styles (`.pgn__card`, `.course`) set `overflow: hidden` for image cropping. If a focusable element is near the card edge, the box-shadow focus ring gets clipped.

**Mitigation**: Use `outline` (not `box-shadow`) for focus on elements inside `overflow: hidden` containers, or add `overflow: visible` specifically on `:focus-within` of the parent.

### 3. Dark Footer on High-Contrast Mode

**Scenario**: Windows High Contrast mode overrides all custom colors. The dark footer (`#1A1623`) and its custom link colors are replaced by system colors, potentially making the footer unreadable if layout depends on color differences.

**Mitigation**: Use `@media (forced-colors: active)` to ensure footer links and text remain visible by relying on system `LinkText` and `CanvasText` colors.

### 4. prefers-reduced-motion Breaks Hover Feedback

**Scenario**: Suppressing all `transform: translateY(-1px)` and `box-shadow` transitions under `prefers-reduced-motion: reduce` removes all hover feedback, making it unclear that an element is interactive.

**Mitigation**: Keep opacity or color transitions (which do not trigger vestibular responses) as the reduced-motion alternative. Only suppress transform and positional animations.

### 5. RTL margin-right on .mereka-course-chip

**Scenario**: `.mereka-course-chip { margin-right: 0.75rem }` creates correct spacing in LTR but pushes the chip in the wrong direction in RTL.

**Mitigation**: Replace with `margin-inline-end: 0.75rem`. Audit all directional properties (`margin-left`, `margin-right`, `padding-left`, `padding-right`, `text-align: left/right`, `float: left/right`) in custom SCSS and convert to logical equivalents.

### 6. Font Size in px for Touch Targets

**Scenario**: The authn button has `min-height: 44px` (AC-A11Y-014 context). This is a valid px value for touch target compliance (WCAG SC 2.5.8), but could be flagged by the px audit script.

**Mitigation**: The font-size audit script (AC-A11Y-021) MUST allowlist `min-height`, `min-width`, `max-height`, `max-width` properties that use px for touch-target or icon-sizing purposes.

## Observability

### Metrics

- `axe_violations_total` (gauge, per route, per severity): Total axe-core violations from weekly audit, published to GitHub Actions summary and optionally to Prometheus via push gateway
- `lighthouse_a11y_score` (gauge, per route): Lighthouse accessibility score from CI

### Alerts

- SHOULD alert in `#ops-warnings` Slack channel if weekly axe audit detects new critical violations on production

### Dashboards

- GitHub Actions workflow summary provides per-route violation table (already implemented in `accessibility-audit.yml`)

## Rollout & Rollback

### Rollout Plan

1. **Phase 1 -- Audit** (Week 1): Run contrast ratio verification script and font-size audit against current SCSS. Document all violations.
2. **Phase 2 -- Remediate** (Week 2-3): Fix identified violations (contrast adjustments, missing focus indicators, missing ARIA labels, prefers-reduced-motion media queries). Each fix is a targeted CSS/template change -- low risk.
3. **Phase 3 -- CI enforcement** (Week 3): Set `A11Y_AUDIT_BLOCKING=true` in `accessibility-audit.yml` (remove `continue-on-error: true`). Add Lighthouse a11y threshold.
4. **Phase 4 -- Manual testing** (Week 4): Execute manual verification checklist (NVDA, VoiceOver, keyboard-only, RTL, zoom).

### Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| `A11Y_AUDIT_BLOCKING` | false | When true, `accessibility-audit.yml` fails on critical/serious violations instead of advisory mode. Set to true once existing violations are remediated. |

### Backward Compatibility

- All changes are additive CSS (adding focus indicators, reduced-motion queries, ARIA attributes). No existing functionality is removed.
- Color adjustments that shift brand colors by more than a few hue degrees require design review approval.

### Rollback Steps

1. If a contrast fix changes brand colors unacceptably: revert the specific SCSS token in `_tokens.scss` and rebuild images.
2. If CI gate blocks legitimate changes: set `A11Y_AUDIT_BLOCKING=false` (emergency) and file a tracking issue.
3. If reduced-motion media query breaks animations for sighted users: revert the `@media (prefers-reduced-motion)` block and investigate.

## Verification

### Automated Verification

Add verification scripts to `scripts/qa/verify-frontend-accessibility/` with `@covers` annotations:

```bash
#!/usr/bin/env bash
# @covers AC-A11Y-001, AC-A11Y-002, AC-A11Y-003, AC-A11Y-004, AC-A11Y-005, AC-A11Y-006, AC-A11Y-007
# @spec: frontend-accessibility_spec
set -euo pipefail
# Verify contrast ratios for all Mereka brand color combinations
# Uses wcag-contrast-ratio calculations (Python colorsys or node contrast-ratio)
```

```bash
#!/usr/bin/env bash
# @covers AC-A11Y-020
# @spec: frontend-accessibility_spec
set -euo pipefail
# Grep SCSS files for transition/transform/animation properties
# Verify each has a @media (prefers-reduced-motion: reduce) counterpart
```

```bash
#!/usr/bin/env bash
# @covers AC-A11Y-021
# @spec: frontend-accessibility_spec
set -euo pipefail
# Grep SCSS files for px-based font-size declarations
# Exclude borders, shadows, icon-sizing, and min-height (44px touch targets)
# Fail if any body/interactive text uses px
```

```bash
#!/usr/bin/env bash
# @covers AC-A11Y-022, AC-A11Y-023, AC-A11Y-024
# @spec: frontend-accessibility_spec
set -euo pipefail
# Verify accessibility-audit.yml has continue-on-error: false
# Verify Lighthouse CI is configured with accessibilityThreshold >= 90
```

Run coverage report:
```bash
scripts/qa/spec-tools/ac-coverage-report.py
```

### Manual Verification

The following require human verification with assistive technology. Add to `specs/plans/manual_verifications.yaml`:

1. **NVDA + Chrome (Windows)**: Navigate LMS homepage, /login, /dashboard using NVDA screen reader. Verify all custom Mereka elements (footer, header logo, hero section, course cards) are announced correctly with meaningful labels.
2. **VoiceOver + Safari (macOS)**: Navigate the same pages using VoiceOver. Verify rotor landmarks include the custom footer, and all links have descriptive text.
3. **Keyboard-only (any browser)**: Tab through all 5 audited routes. Verify focus is always visible, never trapped, and follows logical reading order through Mereka customizations.
4. **RTL verification (Arabic locale)**: Load LMS with `?lang=ar` or Arabic language preference. Verify Mereka-custom layouts mirror correctly.
5. **Reduced motion (OS setting)**: Enable reduced motion in OS. Verify all Mereka hover/transition animations are suppressed.
6. **200% browser zoom**: Zoom to 200% on LMS homepage. Verify no Mereka-styled content is clipped, overlapped, or unreachable.

### Test Plan

See `specs/plans/frontend-accessibility_test_plan.md` for comprehensive test scenarios (to be generated).

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Upstream Paragon update changes focus indicator implementation | Medium | Medium | Pin Paragon version; review Paragon changelogs for a11y regressions before MFE image rebuilds |
| axe-core false positives block CI | Low | Medium | Use `A11Y_AUDIT_BLOCKING` flag to gate enforcement; maintain an allowlist for known false positives with justifications |
| Dark footer contrast fails for muted text rgba(255,255,255,0.6) | Medium | High | Pre-computed: rgba(255,255,255,0.6) on #1A1623 is approximately 8.5:1 -- passes. But verify at build time. |
| Custom gradient buttons have variable contrast along gradient stops | Medium | Medium | Measure at the lightest gradient point (the worst case). If it fails, add a semi-transparent overlay or adjust gradient stops. |
| RTL mirroring breaks with `margin-right` on `.mereka-course-chip` | Low | Medium | Replace directional properties with logical properties (`margin-inline-end`) |
| px-based font sizes in existing SCSS | Medium | High | Audit reveals most values already use rem. Remaining px values in the theme are for borders/shadows (acceptable). |

## Open Questions

- [ ] Should we add axe-core testing for MFE routes (apps.academyv2.mereka.io/authn/login, /learning, /account) in addition to the current LMS routes? The MFE routes receive Mereka SCSS overrides via `mereka.scss` but are not currently scanned.
- [ ] What is the minimum Lighthouse accessibility score we will enforce? Proposed: 90. Need confirmation from product.
- [ ] Should we adopt `eslint-plugin-jsx-a11y` for the MerekaFooter React component and any future FPF slot components?
