# Paragon v22 Token Audit

## Source
- Source core theme: `infrastructure/tutor/themes/mereka/mfe/theme/core.min.css`
- Theme bridge: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
- Generated on: 2026-02-27T21:15:58Z (UTC)
- Command: `python3 scripts/qa/paragon-v22-token-audit.py --write`

## Method
- Parse `var(--pgn-*)` references from `core.min.css`.
- Remove custom property definition lines first (`--pgn-*:` declarations are excluded).
- Compare consumed set to the `:root` `--pgn-*` definitions in `_tokens.scss`.
- Classify into `consumed+defined`, `consumed+missing`, and `defined+ignored`.

## Counts
- Consumed tokens (from `core.min.css`): `1318`
- Defined in `_tokens.scss`: `76`
- Consumed & defined: `26`
- Consumed & missing: `1292`
- Defined & ignored: `50`

## Consumed & Defined
- These tokens are read by current Paragon styles and already supplied in `_tokens.scss`.

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
  - `docs/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_MISSING.tsv`
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
| button | 16 | `--pgn-btn-active-bg, --pgn-btn-active-border-color, --pgn-btn-active-color, --pgn-btn-bg, --pgn-btn-border-color`, ... |
| transition | 11 | `--pgn-transition-badge, --pgn-transition-btn, --pgn-transition-carousel-base, --pgn-transition-carousel-control, --pgn-transition-carousel-indicator`, ... |
| badge | 5 | `--pgn-badge-bg, --pgn-badge-color, --pgn-badge-focus-bg, --pgn-badge-focus-box-shadow, --pgn-badge-focus-color` |
| content | 4 | `--pgn-content-carousel-control-bg-next-icon, --pgn-content-carousel-control-bg-prev-icon, --pgn-content-navbar-toggler-dark-icon-bg, --pgn-content-navbar-toggler-light-icon-bg` |
| alert | 3 | `--pgn-alert-bg, --pgn-alert-border-color, --pgn-alert-icon-color` |

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
  - `docs/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_MISSING.tsv`
  - `docs/architecture/PARAGON_V22_TOKEN_AUDIT_DEFINED_IGNORED.tsv`
  - `docs/architecture/PARAGON_V22_TOKEN_AUDIT_CONSUMED_DEFINED.tsv`

## Guidance for Phase C
- Prioritize replacing BEM overrides only where token replacement is known to take effect.
- For `--pgn-*` tokens in `defined+ignored`, prefer explicit `--mereka-*` overrides in our own CSS.
- Re-audit whenever `core.min.css` changes (Theme URL runtime path update).
