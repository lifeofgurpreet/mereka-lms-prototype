# Interaction State Quality Contract

**Purpose**: Define the 4-state contract (loading, empty, error, success) that all MFEs must implement for graceful UX.

**Last updated**: 2026-02-17

---

## Overview

Every user interaction with the Mereka Academy platform must provide clear feedback in all possible states. This document specifies the mandatory interaction states, their visual requirements, and how to implement them using Paragon components and design tokens.

**The 4 Required States**:
1. **Loading** — Data is being fetched or processed
2. **Empty** — No data to display (but not an error)
3. **Error** — Something went wrong
4. **Success** — Operation completed successfully

---

## State Requirements

### 1. Loading State

**When to use**: While fetching data, processing a form submission, or waiting for an async operation.

**Required implementation**:
- Use Paragon `Spinner` or `Skeleton` components
- Theme spinner via `--pgn-color-primary-base` (inherited from `--mereka-color-magenta`)
- Skeleton components use built-in Paragon styling

**Example (Spinner)**:
```jsx
import { Spinner } from '@openedx/paragon';

<div className="d-flex justify-content-center p-5">
  <Spinner animation="border" variant="primary" />
  <span className="sr-only">Loading...</span>
</div>
```

**Example (Skeleton)**:
```jsx
import { Skeleton } from '@openedx/paragon';

<Skeleton height={200} count={3} />
```

**Design token usage**:
- Spinner color: `var(--pgn-color-primary-base)` (auto-themed)
- No hardcoded colors allowed

---

### 2. Empty State

**When to use**: When a query returns no results, a list is empty, or user has no content yet.

**Required implementation**:
- Show a meaningful message explaining why the view is empty
- Include a call-to-action (CTA) button when applicable
- Use `--mereka-color-ink-700` for text
- Use `--mereka-color-ink-500` for secondary text

**Example**:
```jsx
import { Button } from '@openedx/paragon';

<div className="text-center p-5">
  <p style={{ color: 'var(--mereka-color-ink-700)' }}>
    You haven't enrolled in any courses yet.
  </p>
  <p style={{ color: 'var(--mereka-color-ink-500)' }}>
    Browse our catalog to get started.
  </p>
  <Button variant="primary" href="/courses">
    Explore Courses
  </Button>
</div>
```

**Anti-patterns**:
- ❌ Showing a blank page with no explanation
- ❌ Displaying only a generic "No data" message without context
- ❌ Missing actionable next step

---

### 3. Error State

**When to use**: API failures, validation errors, permission issues, network timeouts.

**Required implementation**:
- Use Paragon `Alert` component with `variant="danger"`
- Theme alert via `--pgn-color-danger-base` (inherited from `--mereka-color-burgundy`)
- Include retry action where applicable
- Provide clear, user-friendly error message (not raw API response)

**Example**:
```jsx
import { Alert, Button } from '@openedx/paragon';

<Alert variant="danger" dismissible>
  <Alert.Heading>Unable to load course</Alert.Heading>
  <p>
    We couldn't retrieve the course data. Please check your connection and try again.
  </p>
  <div className="mt-3">
    <Button variant="outline-danger" onClick={handleRetry}>
      Retry
    </Button>
  </div>
</Alert>
```

**Design token usage**:
- Alert background: Auto-themed via Paragon
- Alert text: Auto-themed via Paragon
- Custom styling: Use `var(--pgn-color-danger-base)` or `var(--mereka-color-danger)`

**Error severity levels**:
- **Critical**: Use `variant="danger"` (red)
- **Warning**: Use `variant="warning"` (gold)
- **Info**: Use `variant="info"` (blue)

---

### 4. Success State

**When to use**: Form submission success, data saved, action completed.

**Required implementation**:
- Use Paragon `Alert` with `variant="success"` for persistent confirmation
- Use Paragon `Toast` for transient notifications
- Theme via `--pgn-color-success-base` (inherited from `--mereka-color-forest`)

**Example (Alert)**:
```jsx
import { Alert } from '@openedx/paragon';

<Alert variant="success" dismissible>
  <Alert.Heading>Profile updated</Alert.Heading>
  <p>Your changes have been saved successfully.</p>
</Alert>
```

**Example (Toast)**:
```jsx
import { Toast } from '@openedx/paragon';

<Toast show={showToast} onClose={() => setShowToast(false)} delay={3000} autohide>
  <Toast.Header>
    <strong className="me-auto">Success</strong>
  </Toast.Header>
  <Toast.Body>Your enrollment has been confirmed.</Toast.Body>
</Toast>
```

**Design token usage**:
- Alert/Toast background: Auto-themed via Paragon
- Custom styling: Use `var(--pgn-color-success-base)` or `var(--mereka-color-success)`

---

## Design Token Requirements

All interaction states must use design tokens, not hardcoded colors.

**Token bridge in `_tokens.scss`**:
```scss
$color-success: $color-forest;      // #2c6e49
$color-warning: $color-gold;        // #f4be48
$color-danger: $color-burgundy;     // #8c002f
$color-info: $color-blue;           // #295cad

:root {
  --mereka-color-success: #{$color-success};
  --mereka-color-warning: #{$color-warning};
  --mereka-color-danger: #{$color-danger};
  --mereka-color-info: #{$color-info};
  --pgn-color-success-base: #{$color-success};
  --pgn-color-warning-base: #{$color-warning};
  --pgn-color-danger-base: #{$color-danger};
  --pgn-color-info-base: #{$color-info};
}
```

**Paragon auto-theming**:
- Paragon components automatically consume canonical `--pgn-color-*-base` tokens
- No need to manually style Alert, Spinner, Toast components

**Custom usage**:
```scss
.custom-error-message {
  color: var(--mereka-color-danger);
  border: 1px solid var(--mereka-color-danger);
}
```

---

## MFE Coverage Matrix

| MFE | Loading | Empty | Error | Success | Status |
|-----|---------|-------|-------|---------|--------|
| authn | ✓ | ✓ | ✓ | ✓ | PASS |
| account | ✓ | ✓ | ✓ | ✓ | PASS |
| learning | ✓ | ✓ | ✓ | N/A | PASS |
| profile | ✓ | ✓ | ✓ | N/A | PASS |
| discussions | ✓ | ✓ | ✓ | ✓ | PASS |
| gradebook | ✓ | ✓ | ✓ | N/A | PASS |
| learner-dashboard | ✓ | ✓ | ✓ | N/A | PASS |
| communications | ✓ | ✓ | ✓ | ✓ | PASS |
| ora-grading | ✓ | ✓ | ✓ | ✓ | PASS |
| authoring | ✓ | ✓ | ✓ | ✓ | PASS |
| course-authoring | ✓ | ✓ | ✓ | ✓ | PASS |

**Legend**:
- ✓ = State is handled gracefully
- N/A = State not applicable for this MFE
- PENDING = Implementation needed
- FAIL = State not handled (shows blank or crashes)

**Coverage status**: All 11 MFEs implement the 4-state contract via Paragon components (inherited from upstream Open edX).

---

## XBlock Feedback Gap

**Issue**: Custom XBlock feedback CSS in `custom-apps` uses hardcoded colors instead of design tokens.

**Examples**:
```css
/* Hardcoded in XBlock CSS */
.feedback.correct { background-color: #d4edda; }
.feedback.incorrect { background-color: #f8d7da; }
```

**Recommended migration**:
```css
/* Use design tokens */
.feedback.correct { background-color: var(--mereka-color-success-soft); }
.feedback.incorrect { background-color: var(--mereka-color-danger-soft); }
```

**Status**: WARN (not a blocker, but should be migrated in future work)

**Tracking**: This is a known gap documented for future cleanup. XBlock feedback is in `custom-apps`, not the theme, so it requires separate migration effort.

---

## Verification

Machine-checkable verification via:
```bash
./scripts/qa/verify-interaction-state-contract.sh
```

**Checks performed**:
- This contract document exists with all required sections
- MFE coverage matrix is present with 11 MFEs
- Paragon interaction components documented (Spinner, Skeleton, Alert, Toast)
- Design token bridge in `_tokens.scss` includes success, warning, danger, info
- No hardcoded feedback colors in MFE SCSS files
- Token definitions include all 4 semantic states

---

## Acceptance Criteria

**@covers AC-UISTATE-001**: All MFEs implement 4-state contract (loading, empty, error, success)
**@covers AC-UISTATE-002**: Design tokens used for all interaction states (no hardcoded colors)
**@covers AC-UISTATE-003**: Paragon components used for interaction feedback (Spinner, Skeleton, Alert, Toast)
**@covers AC-UISTATE-004**: MFE coverage matrix maintained with PASS/PENDING/N-A status

---

## References

- **Paragon Design System**: https://paragon-openedx.netlify.app/
- **Design Tokens**: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
- **MFE Plugin**: `infrastructure/tutor/plugins/mereka_lms.py`
- **Frontend Audit**: `../qa/reports/FRONTEND_AUDIT_CHECKLIST.md`
