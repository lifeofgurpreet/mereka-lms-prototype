# Token Drift Remediation Guide
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

## Overview

This document defines the canonical token source, the authoring contract for adding new design tokens, and the drift-check flow used in CI to prevent undefined CSS variable references.

**Related script**: `scripts/qa/verify-token-drift.sh`
**Related CI jobs**: `design-token-validation`, `token-drift`, `branding-token-integrity`

---

## Canonical Token Source

```
assets/branding/tokens.css
```

This file is the **single source of truth** for raw design-system values. It is synced from the upstream brand assets repository and documented in `assets/branding/tokens.provenance.json`.

### What belongs here

- Raw palette values (`--color-teal`, `--color-magenta`, `--color-blue`, ...)
- Typography scale (`--font-heading`, `--font-body`, ...)
- Spacing scale (`--space-1` through `--space-24`)
- Radius, shadow, z-index, animation, container, and breakpoint primitives
- **Does NOT** define `--mereka-*` prefixed tokens — those live in the bridge files below

### What belongs in the bridge files

The `--mereka-*` prefixed tokens are defined in the theme bridge layer:

| File | Purpose |
|------|---------|
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | SCSS variables + `:root` block compiled into MFEs via webpack |
| `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` | Runtime CSS for LMS + Studio (common to both) |
| `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css` | Runtime CSS for LMS only |
| `infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css` | Runtime CSS for Studio (CMS) only |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | MFE-specific extensions (gradient, mfe-surface, mfe-border, etc.) |
| `infrastructure/tutor/themes/mereka/scss/theme.scss` | LMS/Studio SCSS theme (radius-xl, etc.) |

---

## Defined Token Namespaces

### Ink scale (text / foreground colors)

The Mereka ink scale uses **four levels only**. ink-600 does **not** exist:

| Token | Value | Use |
|-------|-------|-----|
| `--mereka-color-ink-900` | `#000000` | Primary text, headings |
| `--mereka-color-ink-700` | `#4A494A` | Secondary text, nav links |
| `--mereka-color-ink-500` | `#6B6B6B` | Tertiary text, captions, labels |
| `--mereka-color-ink-300` | `#AFADB2` | Placeholder text, disabled state |

**If you reach for `--mereka-color-ink-600`, use `--mereka-color-ink-700` instead.**

### Palette

| Token | Value |
|-------|-------|
| `--mereka-color-teal` | `#237072` |
| `--mereka-color-magenta` | `#ab3b78` |
| `--mereka-color-blue` | `#295cad` |
| `--mereka-color-sky` | `#94d1e4` |

### Surface

| Token | Value |
|-------|-------|
| `--mereka-color-surface-primary` | `#FBFAFB` |
| `--mereka-color-surface-secondary` | `#F5F5F5` |
| `--mereka-color-border` | `#DDDDDE` |
| `--mereka-color-border-strong` | `#7B7B7C` |

### Semantic

| Token | Alias |
|-------|-------|
| `--mereka-color-info` | → `--mereka-color-blue` |
| `--mereka-color-info-soft` | → `--mereka-color-sky` |
| `--mereka-color-success` | `#2c6e49` |
| `--mereka-color-warning` | `#f4be48` |
| `--mereka-color-danger` | `#8c002f` |
| `--mereka-color-danger-soft` | `#cd89ae` |

---

## Adding a New Token

Follow these steps **in order** to avoid drift:

### 1. Add to the SCSS bridge (compiled path for MFEs)

Edit `infrastructure/tutor/themes/mereka/scss/_tokens.scss`:

```scss
// Add the SCSS variable first
$color-ink-new: #XXXXXX;

// Then add to :root
:root {
  ...
  --mereka-color-ink-new: #{$color-ink-new};
}
```

### 2. Mirror in all runtime override files

Add the same property to **all three** CSS override targets so LMS and Studio see the token at runtime (no webpack step):

```css
/* In common/static/css/mereka-overrides.css */
:root {
  ...
  --mereka-color-ink-new: #XXXXXX;
}
```

Repeat for `lms/static/css/mereka-overrides.css` and `cms/static/css/mereka-overrides.css`.

### 3. If the token is MFE-only (no LMS/Studio equivalent needed)

Add it to `infrastructure/tutor/themes/mereka/mfe/mereka.scss` `:root` block. These tokens are prefixed `--mereka-mfe-*` to signal MFE scope:

```scss
:root {
  --mereka-mfe-new-thing: value;
}
```

### 4. Verify no drift was introduced

```bash
./scripts/qa/verify-token-drift.sh
```

Expected: all checks PASS, zero FAIL.

### 5. Run the full token integrity suite

```bash
./scripts/qa/verify-branding-token-integrity.sh
```

---

## Drift-Check Flow

```
PR touches assets/branding/** or infrastructure/tutor/themes/**
       │
       ▼
CI: token-drift job
  └─ ./scripts/qa/verify-token-drift.sh
       ├─ [AC-TOKEN-003] Canonical source present + non-empty
       ├─ [AC-TOKEN-001] All var(--mereka-*) references resolve
       ├─ [AC-TOKEN-002] ink-600 gap absent (and other off-scale tokens)
       └─ [AC-TOKEN-004] CI coverage references script + provenance check

CI: design-token-validation job (broader artifact sync gate)
  ├─ Validate tokens.css syntax
  ├─ Validate tokens.provenance.json (upstream sync evidence)
  └─ Verify token values in theme files

CI: branding-token-integrity job (cross-reference + contrast)
  ├─ Token reference resolution (_tokens.scss ↔ theme files)
  ├─ ink-600 gap check
  └─ WCAG AA contrast quick-check (ink-900 on surface-primary)

CI: monitoring-guardrails job (syntax check)
  └─ bash -n scripts/qa/verify-token-drift.sh
```

The scripts are complementary. `verify-token-drift.sh` focuses on **undefined CSS variable references** and **canonical source discipline**. `verify-branding-token-integrity.sh` focuses on **cross-file consistency** and **contrast ratios**.

---

## Remediation Checklist

If `verify-token-drift.sh` FAILs in CI:

1. Read the `[FAIL]` output to identify the undefined token name and the file/line where it appears.
2. Decide: **define it** (follow "Adding a New Token" above) or **replace the reference** with the nearest defined token.
3. Common replacement map for frequent mistakes:
   - `--mereka-color-ink-600` → `--mereka-color-ink-700`
   - `--mereka-color-ink-400` → `--mereka-color-ink-500`
   - `--mereka-color-ink-200` → `--mereka-color-ink-300`
   - `--mereka-color-ink-100` → `--mereka-color-surface-primary`
4. Re-run the script locally to verify PASS before pushing.
5. Commit both the fix and any new token definitions together.

---

## Provenance and Upstream Sync

`assets/branding/tokens.css` is synced from the upstream brand assets repository. When a sync is performed, `assets/branding/tokens.provenance.json` must be updated:

```json
{
  "source_repo": "Biji-Biji-Initiative/mereka-brand-assets",
  "source_path": "tokens/tokens.css",
  "source_branch": "main",
  "source_commit": "<40-char SHA>",
  "source_sha256": "<64-char SHA256 of synced file>",
  "synced_at_utc": "2026-01-15T00:00:00Z"
}
```

CI validates this file in the `design-token-validation` job. A missing or stale provenance file is a FAIL.

---

## See Also

- `scripts/qa/verify-token-drift.sh` — drift gate (this doc's companion)
- `scripts/qa/verify-branding-token-integrity.sh` — cross-reference + contrast gate
- `assets/branding/tokens.css` — canonical token source
- `assets/branding/tokens.provenance.json` — upstream sync record
- `docs/adr/` — Architecture Decision Records
