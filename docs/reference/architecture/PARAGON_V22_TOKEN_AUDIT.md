# Paragon v22 Token Audit

## Source
- Source core theme: `infrastructure/tutor/themes/mereka/mfe/theme/core.min.css`
- Theme bridge: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
- Generated on: 2026-02-28T03:51:05Z (UTC)
- Command: `python3 scripts/qa/paragon-v22-token-audit.py --write`

## Method
- Parse `var(--pgn-*)` references from `core.min.css`.
- Remove custom property definition lines first (`--pgn-*:` declarations are excluded).
- Compare consumed set to the `:root` `--pgn-*` definitions in `_tokens.scss`.
- Classify into `consumed+defined`, `consumed+missing`, and `defined+ignored`.

## Counts
- Consumed tokens (from `core.min.css`): `1318`
- Defined in `_tokens.scss`: `80`
- Consumed & defined: `30`
- Consumed & missing: `1288`
- Defined & ignored: `50`

## Consumed & Defined
- These tokens are read by current Paragon styles and already supplied in `_tokens.scss`.

- `--pgn-alert-bg`
- `--pgn-alert-border-color`
- `--pgn-btn-color`
- `--pgn-btn-hover-color`
- `--pgn-color-accent-a`
- `--pgn-color-accent-b`
- `--pgn-color-black`
- `--pgn-color-brand-base`
- `--pgn-color-dark-200`
- `--pgn-color-gray-500`
- `--pgn-color-gray-700`
- `--pgn-color-info-200`
- `--pgn-color-info-500`
- `--pgn-color-info-base`
- `--pgn-color-light-200`
- `--pgn-color-light-500`
- `--pgn-color-primary-100`
- `--pgn-color-primary-200`
- `--pgn-color-primary-500`
- `--pgn-color-primary-700`
- `--pgn-color-primary-base`
- `--pgn-color-red`
- `--pgn-color-white`
- `--pgn-spacing-spacer-1`
- `--pgn-spacing-spacer-2`
- `--pgn-spacing-spacer-3`
- `--pgn-spacing-spacer-4`
- `--pgn-spacing-spacer-base`
- `--pgn-transition-fade`
- `--pgn-typography-font-size-xs`

## Consumed & Missing (High-Value Families)
- Full list for actionability is in:
  - `docs/concepts/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_MISSING.tsv`
- Family breakdown:
  - color
  - size
  - spacing
  - typography
  - elevation
  - elevation-box
  - button
  - transition
  - alert

| Family | Count | Sample tokens |
| --- | ---: | --- |
| color | 606 | `--pgn-color-alert-content, --pgn-color-alert-icon-danger, --pgn-color-alert-icon-info, --pgn-color-alert-icon-success, --pgn-color-alert-icon-warning`, ... |
| size | 197 | `--pgn-size-alert-border-radius, --pgn-size-alert-border-width, --pgn-size-annotation-arrow-border-width, --pgn-size-annotation-border-radius, --pgn-size-annotation-max-width`, ... |
| spacing | 177 | `--pgn-spacing-action-row-gap-x, --pgn-spacing-action-row-gap-y, --pgn-spacing-alert-actions-gap, --pgn-spacing-alert-icon-space, --pgn-spacing-alert-margin-bottom`, ... |
| typography | 120 | `--pgn-typography-alert-font-size, --pgn-typography-alert-font-weight-link, --pgn-typography-alert-line-height, --pgn-typography-annotation-font-size, --pgn-typography-annotation-line-height`, ... |
| elevation | 85 | `--pgn-elevation-annotation-box-shadow, --pgn-elevation-btn-box-shadow-active, --pgn-elevation-close-button-text-shadow, --pgn-elevation-code-kbd-box-shadow, --pgn-elevation-data-table-box-shadow`, ... |
| elevation-box | 38 | `--pgn-elevation-box-shadow-base-blur, --pgn-elevation-box-shadow-base-color, --pgn-elevation-box-shadow-base-offset-x, --pgn-elevation-box-shadow-base-offset-y, --pgn-elevation-box-shadow-centered-1`, ... |
| other | 21 | `--pgn-other-btn-disabled-opacity, --pgn-other-carousel-control-opacity-base, --pgn-other-carousel-control-opacity-hover, --pgn-other-chip-opacity-disabled, --pgn-other-content-form-control-checkbox-indicator-icon-checked-base`, ... |
| button | 14 | `--pgn-btn-active-bg, --pgn-btn-active-border-color, --pgn-btn-active-color, --pgn-btn-bg, --pgn-btn-border-color`, ... |
| transition | 11 | `--pgn-transition-badge, --pgn-transition-btn, --pgn-transition-carousel-base, --pgn-transition-carousel-control, --pgn-transition-carousel-indicator`, ... |
| badge | 5 | `--pgn-badge-bg, --pgn-badge-color, --pgn-badge-focus-bg, --pgn-badge-focus-box-shadow, --pgn-badge-focus-color` |
| content | 4 | `--pgn-content-carousel-control-bg-next-icon, --pgn-content-carousel-control-bg-prev-icon, --pgn-content-navbar-toggler-dark-icon-bg, --pgn-content-navbar-toggler-light-icon-bg` |
| border | 3 | `--pgn-border-color-nav-tabs-link-border-active, --pgn-border-color-nav-tabs-link-border-focus, --pgn-border-color-nav-tabs-link-border-hover` |

## Defined & Ignored
- These tokens are defined in `_tokens.scss` but not observed in the current
  `var()` consumption pass of `core.min.css`.
- Keep only if they are intentionally retained for fallback or future-safe migration.

- `--pgn-body-bg`
- `--pgn-body-color`
- `--pgn-border-color`
- `--pgn-border-color-translucent`
- `--pgn-border-radius`
- `--pgn-border-radius-lg`
- `--pgn-border-radius-sm`
- `--pgn-btn-border-radius`
- `--pgn-color-brand-700`
- `--pgn-color-danger`
- `--pgn-color-gray-base`
- `--pgn-color-info`
- `--pgn-color-info-300`
- `--pgn-color-info-700`
- `--pgn-color-primary`
- `--pgn-color-primary-300`
- `--pgn-color-primary-400`
- `--pgn-color-secondary`
- `--pgn-color-success`
- `--pgn-color-warning`
- `--pgn-elevation-1`
- `--pgn-elevation-2`
- `--pgn-elevation-3`
- `--pgn-elevation-4`
- `--pgn-elevation-box-shadow-level-2`
- `--pgn-font-family-sans-serif`
- `--pgn-font-size-base`
- `--pgn-font-size-lg`
- `--pgn-font-size-sm`
- `--pgn-form-control-border-color`
- `--pgn-heading-font-family`
- `--pgn-line-height-base`
- `--pgn-line-height-lg`
- `--pgn-line-height-sm`
- `--pgn-link-color`
- `--pgn-link-hover-color`
- `--pgn-spacing-1`
- `--pgn-spacing-2`
- `--pgn-spacing-3`
- `--pgn-spacing-4`
- `--pgn-spacing-5`
- `--pgn-spacing-6`
- `--pgn-spacing-spacer-0`
- `--pgn-spacing-spacer-5`
- `--pgn-spacing-spacer-6`
- `--pgn-transition-base`
- `--pgn-zindex-dropdown`
- `--pgn-zindex-modal`
- `--pgn-zindex-popover`
- `--pgn-zindex-tooltip`

## Operational Notes
- This is a **consumption audit only**. It intentionally does not infer tokens
  by scanning declaration names in `infrastructure/tutor/themes/mereka/mfe/theme/core.min.css`.
- Large full lists are stored in TSV artifacts to support diff-friendly reviews:
  - `docs/concepts/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_MISSING.tsv`
  - `docs/concepts/architecture/PARAGON_V22_TOKEN_AUDIT_DEFINED_IGNORED.tsv`
  - `docs/concepts/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_DEFINED.tsv`

## Token Naming Gap Analysis (2026-02-28)

### Short-Form vs Canonical v22 Names

Our `_tokens.scss` uses **short-form** token names. Paragon v22's `replace-variables.js`
build step rewrites SCSS variables to `var(--pgn-*)` using **canonical long-form** names.
Some of our definitions may not match what Paragon actually consumes.

| Our Token (short-form) | Canonical v22 Name | Match? |
|------------------------|--------------------|--------|
| `--pgn-color-primary` | `--pgn-color-primary-base` | **MISMATCH** — v22 uses `-base` suffix |
| `--pgn-color-secondary` | `--pgn-color-secondary-base` | **MISMATCH** |
| `--pgn-color-success` | `--pgn-color-success-base` | **MISMATCH** |
| `--pgn-color-info` | `--pgn-color-info-base` | **MISMATCH** |
| `--pgn-color-warning` | `--pgn-color-warning-base` | **MISMATCH** |
| `--pgn-color-danger` | `--pgn-color-danger-base` | **MISMATCH** |
| `--pgn-border-radius` | `--pgn-size-border-radius-base` | **MISMATCH** — uses `size-` prefix |
| `--pgn-border-radius-lg` | `--pgn-size-border-radius-lg` | **MISMATCH** |
| `--pgn-border-radius-sm` | `--pgn-size-border-radius-sm` | **MISMATCH** |
| `--pgn-font-family-sans-serif` | `--pgn-typography-font-family-sans-serif` | **MISMATCH** — uses `typography-` prefix |
| `--pgn-font-size-base` | `--pgn-typography-font-size-base` | **MISMATCH** |
| `--pgn-line-height-base` | `--pgn-typography-line-height-base` | **MISMATCH** |
| `--pgn-color-primary-base` | `--pgn-color-primary-base` | MATCH |
| `--pgn-color-primary-700` | `--pgn-color-primary-700` | MATCH |
| `--pgn-btn-color` | `--pgn-btn-color` | MATCH |
| `--pgn-btn-hover-color` | `--pgn-btn-hover-color` | MATCH |
| `--pgn-alert-bg` | `--pgn-alert-bg` | MATCH |
| `--pgn-link-color` | `--pgn-link-color` | MATCH |
| `--pgn-body-bg` | `--pgn-body-bg` | MATCH |
| `--pgn-body-color` | `--pgn-body-color` | MATCH |

### Why This Matters

The `replace-variables.js` build step in Paragon v22 rewrites SCSS `$variable` references
to `var(--pgn-*)` using the canonical token map. If we define `--pgn-color-primary` but
Paragon's compiled CSS uses `var(--pgn-color-primary-base)`, our override has **no effect**.

However, our `_tokens.scss` **also defines `--pgn-color-primary-base`** (line 41), so the
canonical name IS covered for colors. The short-form duplicates (`--pgn-color-primary`,
`--pgn-color-secondary`, etc.) in the "Defined & Ignored" section above are indeed ignored
by Paragon — they're dead weight.

### Recommendation

1. **Keep canonical `-base` suffixed tokens** — these are what Paragon reads.
2. **Remove short-form duplicates** from `_tokens.scss` (e.g., `--pgn-color-primary` when
   `--pgn-color-primary-base` is already defined with the same value).
3. **Add missing canonical names** for border-radius, typography, and spacing families
   if we want Paragon to pick up our values for those properties.
4. **Verify with core.min.css**: The "Consumed & Defined" section above is the definitive
   list of what Paragon actually reads from our `:root` block.

### Paragon v22 Token Architecture

```
SCSS authoring → $primary, $secondary, $font-family-sans-serif
    ↓
replace-variables.js (build step)
    ↓
Compiled CSS → var(--pgn-color-primary-base), var(--pgn-typography-font-family-sans-serif)
    ↓
Runtime → reads from :root { --pgn-color-primary-base: ... }
```

The `replace-variables.js` step is the key — it maps old SCSS variable names to new
CSS custom property names using a fixed lookup table. Our `:root` must define the
OUTPUT names (right column), not the INPUT names (left column).

---

## Guidance for Phase C
- Paragon v22 **does not consume** many component-level token families (card, modal, dropdown, tabs) in current core CSS.
- For those non-consumed families, visual customizations **must remain as CSS rules** (BEM overrides) until upstream token support exists.
- Prioritize replacing BEM overrides only where token replacement is known to take effect.
- For `--pgn-*` tokens in `defined+ignored`, prefer explicit `--mereka-*` overrides in our own CSS.
- Re-audit whenever `core.min.css` changes (Theme URL runtime path update).
- **CRITICAL**: ~60% of scoped `[class*="..."]` selectors are DEAD — see `MFE_SELECTOR_OVERRIDE_INVENTORY.md` §Dead Selector Audit. Do NOT invest in hardening selectors that match nothing.
