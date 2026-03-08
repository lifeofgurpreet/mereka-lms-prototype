# Accessibility Conformance Policy

**Purpose**: Define the accessibility conformance scope, gates, and known gaps for Mereka Academy frontend.

**Status**: Active
**Last updated**: 2026-02-17
**Acceptance Criteria**: AC-UIA11Y-001 through AC-UIA11Y-006

---

## 1. Conformance Scope

Mereka Academy targets **WCAG 2.1 Level AA** conformance for all user-facing surfaces.

### What We Test

| Area | Verification Method | Coverage |
|------|---------------------|----------|
| **Color contrast** | Automated token verification | All text/background pairs (27 checks) |
| **WCAG 2.1 AA violations** | Axe-core via Playwright | 4 core journeys (login, dashboard, courseware, discussions) |
| **Focus ring patterns** | Static analysis of SCSS/CSS | All interactive elements in MFE SCSS |
| **Bare outline removal** | Static analysis | All `outline: none` must have replacement |
| **Focus token availability** | Token definition check | `--mereka-mfe-focus` token |

**Acceptance Criteria**:
- **AC-UIA11Y-001**: WCAG AA contrast gate (verify-contrast-compliance.sh: 27 PASS / 0 FAIL)
- **AC-UIA11Y-002**: Axe-core WCAG 2.1 AA gate (verify-ui-accessibility.sh: 4 journeys, 0 critical/serious violations)
- **AC-UIA11Y-003**: Token contrast wrapper (verify-token-contrast.sh exists, delegates to AC-UIA11Y-001)

### What We Defer to Paragon/Upstream

| Component | Rationale |
|-----------|-----------|
| Paragon components (Button, Form, Modal, Alert, etc.) | Upstream maintains WCAG 2.1 AA compliance |
| Open edX core LMS/Studio widgets | Core platform accessibility responsibility |
| Third-party libraries (React, Paragon, etc.) | Vendor responsibility, monitor for regressions |

**Exception process**: If Paragon/upstream fails accessibility requirements, file upstream issue and track in known gaps table.

---

## 2. Focus Management Policy

### Current State: `:focus` Only

All focus rings currently use `:focus` pseudo-class:

```scss
// infrastructure/tutor/themes/mereka/scss/_tokens.scss
a {
  &:hover,
  &:focus {
    color: $color-teal;
  }
}
```

### Planned Migration: `:focus-visible`

**Rationale**: `:focus-visible` suppresses focus rings for mouse clicks while preserving them for keyboard navigation (WCAG 2.1 SC 2.4.7).

**Migration plan**:
1. Add `:focus-visible` polyfill for older browsers (optional, modern browsers support natively)
2. Convert `:focus` to `:focus-visible` for all interactive elements
3. Keep `:focus` for form inputs where visible focus is always required
4. Test keyboard navigation flows post-migration

**Target**: Q2 2026 (non-blocking, enhancement)

**Acceptance Criteria**: AC-UIA11Y-004 (planned, not blocking)

### Focus Ring Token Bridge

**Current state**: Focus color defined as MFE-specific token:

```scss
// infrastructure/tutor/themes/mereka/mfe/mereka.scss
:root {
  --mereka-mfe-focus: rgba(45, 137, 139, 0.18);
}
```

**Gap**: No Paragon token bridge (`--pgn-focus-ring-*`).

**Planned**:
```scss
// infrastructure/tutor/themes/mereka/scss/_tokens.scss
:root {
  --pgn-focus-ring-color: #{$color-teal};
  --pgn-focus-ring-opacity: 0.18;
  --pgn-focus-ring-width: 4px;
}
```

**Rationale**: Paragon components should use standardized focus ring tokens for consistency.

**Target**: Q2 2026 (non-blocking, enhancement)

### Bare Outline Removal Policy

**Rule**: All `outline: none` declarations MUST be paired with a box-shadow replacement.

**Enforcement**: `verify-a11y-contrast-focus.sh` checks for bare `outline: none` without `box-shadow` in the same rule block.

**Current compliance**:
- 2 instances of `outline: none` in `mereka-overrides.css`
- Both paired with `box-shadow: 0 0 0 4px rgba(45, 137, 139, 0.15)` (WCAG-compliant)

**Example**:
```css
/* CORRECT: outline removed with box-shadow replacement */
.discovery-input:focus {
  outline: none;
  border-color: rgba(45, 137, 139, 0.65);
  box-shadow: 0 0 0 4px rgba(45, 137, 139, 0.15);
}

/* INCORRECT: bare outline removal */
.discovery-input:focus {
  outline: none;  /* ❌ No replacement — FAILS gate */
}
```

---

## 3. Skip Navigation Requirements

**WCAG 2.1 SC 2.4.1 (Level A)**: "A mechanism is available to bypass blocks of content that are repeated on multiple Web pages."

### Current State: Missing

**Gap**: No skip navigation link in MFEs or LMS/Studio.

### Required Implementation

**Location**: Add to all MFE layouts (via frontend-plugin-framework slot or direct injection).

**Pattern**:
```jsx
// Skip link component (visually hidden until focused)
<a href="#main-content" className="skip-to-main">
  Skip to main content
</a>

// CSS
.skip-to-main {
  position: absolute;
  top: -40px;
  left: 0;
  background: var(--pgn-color-primary-base);
  color: white;
  padding: 8px;
  z-index: 100;
}

.skip-to-main:focus {
  top: 0;
}
```

**Target elements**:
- `<main id="main-content">` wrapping primary content area
- Skip link visible on keyboard focus, hidden otherwise

**Target**: Q2 2026 (Level A gap, high priority)

**Acceptance Criteria**: AC-UIA11Y-005 (planned)

---

## 4. ARIA Landmark Requirements

**WCAG 2.1 SC 1.3.1 (Level A)**: "Information, structure, and relationships conveyed through presentation can be programmatically determined."

### Current State: Incomplete

| Landmark | Required | Current Status | Target |
|----------|----------|----------------|--------|
| `<header role="banner">` | Yes | Missing | Main site header |
| `<main role="main">` | Yes | Missing | Primary content area |
| `<nav role="navigation" aria-label="...">` | Yes | Partial (no aria-label) | Main navigation |
| `<footer role="contentinfo">` | Yes | Present (mereka-footer) | Site footer |
| `<aside role="complementary">` | Contextual | Not checked | Sidebars, related content |

### Required Implementation

**Example**:
```jsx
// Layout structure
<header role="banner">
  <nav role="navigation" aria-label="Main navigation">
    {/* Navigation links */}
  </nav>
</header>

<main id="main-content" role="main">
  {/* Primary content */}
</main>

<footer role="contentinfo">
  {/* Footer content */}
</footer>
```

**Target**: Q2 2026 (Level A gap, high priority)

**Acceptance Criteria**: AC-UIA11Y-006 (planned)

---

## 5. Keyboard Navigation Requirements

**WCAG 2.1 SC 2.1.1 (Level A)**: "All functionality of the content is operable through a keyboard interface."

### Current Coverage

- **Focus rings**: Present for all interactive elements (`:focus` rules in mereka.scss)
- **Tab order**: Native HTML semantics (no custom tabindex manipulation)
- **Custom interactions**: None (all use native HTML or Paragon components)

### Gaps

- **Keyboard navigation verification script**: Missing (planned for Q2 2026)
- **Focus trap verification**: Not systematically tested (modals, dropdowns)
- **Custom widget keyboard patterns**: Not applicable (no custom widgets)

### Verification Plan

**Script**: `scripts/qa/verify-a11y-regression-lane.sh`

**Checks**:
- All interactive elements focusable via Tab
- Focus order logical (matches visual layout)
- No keyboard traps (can escape all focus containers)
- Custom interactions have keyboard equivalents

**Target**: Q2 2026

---

## 6. Dynamic Content Announcement Requirements

**WCAG 2.1 SC 4.1.3 (Level AA)**: "Status messages can be programmatically determined through role or properties such that they can be presented to the user by assistive technologies without receiving focus."

### Current State: Missing

**Gap**: No `aria-live` regions for dynamic content announcements.

### Required Patterns

| Use Case | ARIA Pattern | Politeness |
|----------|--------------|------------|
| Toast notifications | `<div role="status" aria-live="polite">` | polite |
| Form errors | `<div role="alert" aria-live="assertive">` | assertive |
| Search results | `<div role="status" aria-live="polite">` | polite |
| Loading states | `<div role="status" aria-live="polite">` | polite |

**Example**:
```jsx
// Toast notification
<Toast>
  <div role="status" aria-live="polite" aria-atomic="true">
    Course saved successfully
  </div>
</Toast>

// Form error
<Alert variant="danger">
  <div role="alert" aria-live="assertive" aria-atomic="true">
    Invalid email address
  </div>
</Alert>
```

**Target**: Q2 2026

---

## 7. Axe-Core Expansion Plan

**Current coverage**: 4 journeys (login, dashboard, courseware, discussions)

**Gap**: MFE routes not covered:
- `/account/` (account settings)
- `/u/:username` (profile)
- `/gradebook/` (course gradebook)
- `/communications/` (course communications)
- `/ora-grading/` (open response assessment grading)
- `/authoring/` (course authoring — Studio)
- `/course-authoring/` (course authoring — legacy path)

**Expansion plan**:
1. Add 7 routes to `JOURNEYS` array in `verify-ui-accessibility.sh`
2. Target: 11 journeys total (4 existing + 7 new)
3. Gate: 0 critical/serious violations across all 11 journeys
4. Timeline: Q2 2026

**Rationale**: Comprehensive axe-core coverage ensures no WCAG regressions in under-tested MFEs.

---

## 8. Known Gaps Table

| Gap | Severity | WCAG Level | Timeline | AC ID |
|-----|----------|------------|----------|-------|
| No `:focus-visible` usage | Minor | Enhancement | Q2 2026 | AC-UIA11Y-004 |
| No skip navigation link | **High** | **Level A** | Q2 2026 | AC-UIA11Y-005 |
| Incomplete ARIA landmarks | **High** | **Level A** | Q2 2026 | AC-UIA11Y-006 |
| No keyboard navigation verification | Medium | Level A | Q2 2026 | (planned) |
| No Paragon focus token bridge | Minor | Enhancement | Q2 2026 | (planned) |
| Axe-core covers only 4/11 MFE routes | Medium | Level AA | Q2 2026 | (planned) |
| No aria-live for dynamic content | Medium | Level AA | Q2 2026 | (planned) |

**Blocking vs Non-Blocking**:
- **Blocking** (Level A gaps): Skip navigation, ARIA landmarks
- **Non-blocking** (enhancements/partial coverage): `:focus-visible`, Paragon token bridge, axe-core expansion

**Gate behavior**:
- `verify-a11y-contrast-focus.sh` will **WARN** (not FAIL) for documented gaps
- This ensures gates don't regress while we address known issues
- Once implemented, WARNs convert to PASS

---

## 9. Upstream Dependency Assumptions

### Paragon WCAG Compliance

**Assumption**: Paragon Design System (v22+) maintains WCAG 2.1 AA compliance for all components.

**Verification**: Monitor [Paragon release notes](https://github.com/openedx/paragon/releases) for accessibility regressions.

**Escalation**: If Paragon fails WCAG requirements, file issue at https://github.com/openedx/paragon/issues with label `accessibility`.

### Open edX Core Accessibility

**Assumption**: Open edX core LMS/Studio maintains baseline accessibility (keyboard navigation, semantic HTML).

**Verification**: Axe-core checks include LMS-rendered pages (courseware, discussions).

**Escalation**: If core LMS fails WCAG requirements, file issue at https://github.com/openedx/edx-platform/issues with label `accessibility`.

---

## 10. Verification Commands

```bash
# Full accessibility conformance gate (all AC-UIA11Y-* criteria)
./scripts/qa/verify-accessibility.sh

# WCAG AA contrast gate (AC-UIA11Y-001)
./scripts/qa/verify-contrast-compliance.sh

# Axe-core WCAG 2.1 AA gate (AC-UIA11Y-002)
./scripts/qa/verify-ui-accessibility.sh

# Token contrast wrapper (AC-UIA11Y-003)
./scripts/qa/verify-token-contrast.sh
```

---

## 11. Continuous Improvement

### Q2 2026 Roadmap

1. **Add skip navigation** (Level A gap, high priority) — AC-UIA11Y-005
2. **Complete ARIA landmarks** (Level A gap, high priority) — AC-UIA11Y-006
3. **Expand axe-core coverage** (4 → 11 journeys)
4. **Add aria-live regions** (dynamic content announcements)
5. **Migrate to `:focus-visible`** (enhancement) — AC-UIA11Y-004
6. **Add Paragon focus token bridge** (enhancement)
7. **Add keyboard navigation verification script**

### Post-Q2 2026

- Screen reader testing (manual, not automated)
- Performance testing for assistive technologies
- User testing with assistive technology users
- Form accessibility deep-dive (labels, error announcements, validation)

---

## 12. References

- **WCAG 2.1 Guidelines**: https://www.w3.org/WAI/WCAG21/quickref/
- **Paragon Accessibility**: https://paragon-openedx.netlify.app/foundations/accessibility/
- **Axe-core Documentation**: https://github.com/dequelabs/axe-core
- **MDN :focus-visible**: https://developer.mozilla.org/en-US/docs/Web/CSS/:focus-visible
- **ARIA Authoring Practices**: https://www.w3.org/WAI/ARIA/apg/

---

**End of Policy**
