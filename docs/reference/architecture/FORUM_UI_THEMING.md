# Forum UI Theming Guide

<!-- Last verified: 2026-02-13 -->

This document covers theming the forum UI to match the Mereka LMS branding, including typography, header/footer integration, and CSS variable overrides.

## Forum UI Architecture

**Service**: openedx-forum v0.3.8 (Python/Django)
**Frontend**: Embedded React components within LMS courseware
**Styling**: CSS modules + Paragon design system

## CSS Theming Extension Points

### 1. Global Forum Styles

**File**: `tutor_env/plugins/forum/static/css/forum-theme.css`

```css
:root {
  /* Mereka Colors */
  --forum-primary: #FF6B35;
  --forum-secondary: #004E89;
  --forum-accent: #F7B801;
  --forum-text: #1A1A1A;
  --forum-text-muted: #4A4A4A;
  --forum-border: #E0E0E0;
  --forum-bg: #FFFFFF;
  --forum-bg-alt: #F5F5F5;

  /* Typography */
  --forum-font-primary: 'Inter', sans-serif;
  --forum-font-heading: 'Poppins', sans-serif;

  /* Spacing */
  --forum-spacing-sm: 8px;
  --forum-spacing-md: 16px;
  --forum-spacing-lg: 24px;
}
```

### 2. Thread List Styling

```css
/* Thread cards */
.discussion-thread {
  font-family: var(--forum-font-primary);
  border: 1px solid var(--forum-border);
  border-radius: 8px;
  padding: var(--forum-spacing-md);
  margin-bottom: var(--forum-spacing-md);
}

.discussion-thread:hover {
  border-color: var(--forum-primary);
  box-shadow: 0 2px 8px rgba(255, 107, 53, 0.1);
}

/* Thread title */
.thread-title {
  font-family: var(--forum-font-heading);
  font-size: 18px;
  font-weight: 600;
  color: var(--forum-text);
}

.thread-title a {
  color: var(--forum-primary);
  text-decoration: none;
}

.thread-title a:hover {
  text-decoration: underline;
}

/* Thread metadata */
.thread-meta {
  font-size: 14px;
  color: var(--forum-text-muted);
}
```

### 3. Thread Detail View

```css
/* Post content */
.discussion-post {
  font-family: var(--forum-font-primary);
  line-height: 1.6;
  color: var(--forum-text);
}

/* Author info */
.post-author {
  font-weight: 600;
  color: var(--forum-secondary);
}

/* Post actions */
.post-actions button {
  color: var(--forum-primary);
  border: 1px solid var(--forum-primary);
  background: transparent;
  padding: 6px 12px;
  border-radius: 4px;
  font-family: var(--forum-font-primary);
}

.post-actions button:hover {
  background: var(--forum-primary);
  color: white;
}
```

### 4. Comment Thread

```css
/* Comments */
.discussion-comment {
  border-left: 3px solid var(--forum-accent);
  padding-left: var(--forum-spacing-md);
  margin-left: var(--forum-spacing-lg);
  margin-top: var(--forum-spacing-sm);
}

/* Comment form */
.comment-form textarea {
  font-family: var(--forum-font-primary);
  border: 1px solid var(--forum-border);
  border-radius: 4px;
  padding: var(--forum-spacing-sm);
  width: 100%;
}

.comment-form textarea:focus {
  border-color: var(--forum-primary);
  outline: none;
  box-shadow: 0 0 0 3px rgba(255, 107, 53, 0.1);
}

.comment-submit {
  background: var(--forum-primary);
  color: white;
  border: none;
  padding: 10px 20px;
  border-radius: 4px;
  font-family: var(--forum-font-primary);
  font-weight: 600;
  cursor: pointer;
}

.comment-submit:hover {
  background: #E55A2D;
}
```

## Typography Matching with LMS

### Font Loading

Ensure Mereka fonts are loaded in forum templates:

**File**: `tutor_env/plugins/forum/templates/base.html`

```html
<head>
  <!-- Mereka Fonts -->
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Poppins:wght@600;700&display=swap" rel="stylesheet">

  <!-- Forum theme -->
  <link rel="stylesheet" href="{% static 'css/forum-theme.css' %}">
</head>
```

### Heading Styles

Match LMS heading hierarchy:

```css
.forum-heading-1 {
  font-family: var(--forum-font-heading);
  font-size: 32px;
  font-weight: 700;
  color: var(--forum-text);
  margin-bottom: var(--forum-spacing-lg);
}

.forum-heading-2 {
  font-family: var(--forum-font-heading);
  font-size: 24px;
  font-weight: 600;
  color: var(--forum-secondary);
  margin-bottom: var(--forum-spacing-md);
}

.forum-heading-3 {
  font-family: var(--forum-font-heading);
  font-size: 18px;
  font-weight: 600;
  color: var(--forum-text);
  margin-bottom: var(--forum-spacing-sm);
}
```

## Header/Footer Integration

Forum UI is embedded within LMS courseware, so header/footer are inherited from LMS theme.

**Verification**:
```bash
# Check LMS theme includes forum CSS
grep -r "forum-theme.css" tutor_env/env/apps/openedx/templates/

# Verify CSS cascade
kubectl exec -it -n mereka-lms deploy/lms -- \
  ls -la /openedx/edx-platform/lms/static/css/ | grep forum
```

## Paragon Design Token Integration

Forum React components use Paragon design system. Override Paragon tokens to match Mereka branding:

**File**: `tutor_env/plugins/mfe/forum/custom.scss`

```scss
// Import Mereka tokens
$mereka-primary: #FF6B35;
$mereka-secondary: #004E89;
$mereka-accent: #F7B801;
$mereka-font-primary: 'Inter', sans-serif;
$mereka-font-heading: 'Poppins', sans-serif;

// Override Paragon variables
$primary: $mereka-primary;
$secondary: $mereka-secondary;
$font-family-base: $mereka-font-primary;

// Button overrides
.pgn__button-primary {
  background-color: $mereka-primary;
  border-color: $mereka-primary;

  &:hover {
    background-color: darken($mereka-primary, 10%);
  }
}

// Badge overrides (thread labels)
.pgn__badge {
  font-family: $mereka-font-primary;

  &.badge-primary {
    background-color: $mereka-primary;
  }

  &.badge-secondary {
    background-color: $mereka-secondary;
  }
}

// Form control overrides
.pgn__form-control {
  font-family: $mereka-font-primary;

  &:focus {
    border-color: $mereka-primary;
    box-shadow: 0 0 0 0.2rem rgba(255, 107, 53, 0.25);
  }
}
```

## CSS Variable Overrides for Forum-Specific Elements

### Vote Buttons

```css
.vote-button {
  color: var(--forum-secondary);
  background: transparent;
  border: 1px solid var(--forum-border);
}

.vote-button.voted {
  color: var(--forum-primary);
  border-color: var(--forum-primary);
  background: rgba(255, 107, 53, 0.1);
}
```

### Category Labels

```css
.category-label {
  background: var(--forum-accent);
  color: var(--forum-text);
  font-family: var(--forum-font-primary);
  font-size: 12px;
  font-weight: 600;
  padding: 4px 8px;
  border-radius: 4px;
}
```

### Pinned/Closed Indicators

```css
.thread-pinned {
  border-left: 4px solid var(--forum-primary);
}

.thread-closed {
  opacity: 0.6;
  background: var(--forum-bg-alt);
}

.thread-closed::before {
  content: "🔒";
  margin-right: 8px;
}
```

## Deployment

1. **Edit CSS**: Modify `tutor_env/plugins/forum/static/css/forum-theme.css`
2. **Test Locally**: `tutor local restart lms`
3. **Build Image**: `tutor images build openedx`
4. **Deploy**: Follow `docs/runbooks/operations/THEME_DEPLOYMENT.md`

## Related Documentation

- `docs/runbooks/operations/THEME_DEPLOYMENT.md` - Full deployment guide
- `docs/runbooks/operations/FORUM_AUTH_E2E.md` - Forum authentication flow
- `docs/guides/branding/BRANDING.md` - Branding system overview
