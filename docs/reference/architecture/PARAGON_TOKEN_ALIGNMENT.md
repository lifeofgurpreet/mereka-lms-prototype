# Paragon Token Alignment

_Audience: Frontend Engineering • Last updated: 2026-02-17_

## Purpose

Maps Mereka brand tokens to Open edX Paragon component library CSS custom properties.
Ensures MFEs using Paragon components render with Mereka branding.

## Token Bridge Architecture

```
Figma → tokens.css (canonical) → _tokens.scss (SCSS bridge) → --mereka-* + --pgn-* CSS vars
                                                             ↓
                                                   mereka-overrides.css (runtime)
```

## Current Paragon Bridges

All Paragon token bridges are defined in `infrastructure/tutor/themes/mereka/scss/_tokens.scss` (lines 70-85) and `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` (lines 56-70).

| Paragon Token | Mereka Source | Value | Notes |
|--------------|--------------|-------|-------|
| `--pgn-color-primary-base` | `$color-magenta` | #ab3b78 | Primary action color (buttons, active states) |
| `--pgn-color-secondary-base` | `$color-teal` | #237072 | Secondary actions, links |
| `--pgn-color-success-base` | `$color-success` / `$color-forest` | #2c6e49 | Success states, positive feedback |
| `--pgn-color-info-base` | `$color-info` / `$color-blue` | #295cad | Informational states, default links |
| `--pgn-color-warning-base` | `$color-warning` / `$color-gold` | #996b00 | Warning states, caution indicators |
| `--pgn-color-danger-base` | `$color-danger` / `$color-burgundy` | #8c002f | Error states, destructive actions |
| `--pgn-body-bg` | `$color-neutral-100` | #FBFAFB | Page background |
| `--pgn-body-color` | `$color-ink-900` | #000000 | Body text color |
| `--pgn-link-color` | `$color-info` / `$color-blue` | #295cad | Default link color |
| `--pgn-link-hover-color` | `$color-teal` | #297F81 | Link hover state |
| `--pgn-typography-font-family-sans-serif` | `$mereka-body-font` | "Poppins", "Lato", -apple-system, ... | Body font stack |
| `--pgn-typography-headings-font-family` | `$mereka-heading-font` | "Lato", "Poppins", -apple-system, ... | Heading font stack |
| `--pgn-border-color` | `$color-border` | #DDDDDE | Default border color |
| `--pgn-border-color-translucent` | N/A | rgba(26, 22, 35, 0.12) | Translucent border for overlays |
| `--pgn-btn-border-radius` | N/A | 999px | Button border radius (pill shape) |

## Paragon Tokens NOT Yet Bridged (Gaps)

These Paragon tokens exist in the Paragon library but are not currently overridden in the Mereka theme. Paragon's defaults will apply.

| Paragon Token | Default Value | Should Bridge? | Priority | Notes |
|--------------|--------------|----------------|----------|-------|
| `--pgn-color-accent-a` | Paragon default | Consider | Low | Used for accent highlights; may not be needed |
| `--pgn-color-accent-b` | Paragon default | Consider | Low | Secondary accent color |
| `--pgn-color-light-*` | Paragon default | Consider | Medium | Light theme variants; consider for multi-theme support |
| `--pgn-color-dark-*` | Paragon default | Consider | Medium | Dark theme variants; consider for multi-theme support |
| `--pgn-spacing-*` | Paragon default | No | N/A | Standard spacing scale; using Paragon defaults is fine |
| `--pgn-font-size-*` | Paragon default | No | N/A | Typography scale; using Paragon defaults is fine |
| `--pgn-shadow-*` | Paragon default | Consider | Low | Custom shadows defined in Mereka tokens but not bridged to Paragon |
| `--pgn-color-gray-*` | Paragon default | Consider | Medium | Grayscale palette; Mereka has ink-* equivalents |

**Recommendation**: For Phase 2, consider bridging Mereka shadow tokens (`--mereka-shadow-card`) and grayscale tokens (`--mereka-color-ink-*`) to Paragon equivalents for deeper consistency.

## Design System Mappings

### Color Mappings

Mereka's canonical color tokens (from `tokens.css`) are exposed through `--mereka-color-*` names and bridged to canonical Paragon tokens:

| Canonical Token (tokens.css) | Mereka Alias (mereka-overrides.css) | Paragon Bridge | Usage |
|------------------------------|-------------------------------------|----------------|-------|
| `--color-teal` | `--mereka-color-teal` | `--pgn-color-secondary-base` | Secondary actions, link hover |
| `--color-magenta` | `--mereka-color-magenta` | `--pgn-color-primary-base` | Primary actions, CTA buttons |
| `--color-blue` | `--mereka-color-blue` | `--pgn-color-info-base` | Informational states, default links |
| `--color-burgundy` | `--mereka-color-danger` | `--pgn-color-danger-base` | Error states, destructive actions |
| `--color-pink` | `--mereka-color-danger-soft` | N/A | Soft error backgrounds |
| `--color-sky` | `--mereka-color-sky` | N/A | Info-soft backgrounds |
| `--color-gold` | `--mereka-color-warning` | `--pgn-color-warning-base` | Warning states |
| `--color-forest` | `--mereka-color-success` | `--pgn-color-success-base` | Success states |

### Typography Mappings

| Canonical Token (tokens.css) | Mereka Alias (mereka-overrides.css) | Paragon Bridge | Usage |
|------------------------------|-------------------------------------|----------------|-------|
| `--font-heading` | `--mereka-font-heading` | `--pgn-typography-headings-font-family` | Headings (h1-h6) |
| `--font-body` | `--mereka-font-body` | `--pgn-typography-font-family-sans-serif` | Body text, UI components |
| `--font-video` | N/A | N/A | Video player UI (not bridged) |

## Migration Policy (AC-UITOKEN-004)

### Source of Truth
- **Figma** exports to `assets/branding/tokens.css` (canonical)
- `tokens.provenance.json` tracks SHA256 hash for drift detection
- Changes to tokens MUST flow: Figma → tokens.css → _tokens.scss → overrides

### Drift Detection
- `scripts/branding/verify-token-drift.sh` — verifies 9 required token pairs match
- `scripts/qa/verify-token-definitions.sh` — ensures all `var(--mereka-*)` references resolve
- `scripts/qa/verify-design-tokens.sh` — full 12-AC gate
- `scripts/qa/verify-design-token-usage.sh` — lint for hardcoded colors (NEW)

### Update Procedure
1. Export updated tokens from Figma to `assets/branding/tokens.css`
2. Run `scripts/branding/update-token-provenance.sh` to refresh SHA256
3. Update `_tokens.scss` SCSS variables to match new values
4. Update `mereka-overrides.css` runtime values
5. Run full verification: `./scripts/qa/verify-design-tokens.sh`
6. Run drift check: `./scripts/branding/verify-token-drift.sh`
7. Run usage lint: `./scripts/qa/verify-design-token-usage.sh`
8. Visual regression check: `./scripts/qa/visual-regression-test.sh`

### Approval Path
- **Token value changes** require: PR with before/after screenshots
- **New token additions**: PR with Figma link + usage context
- **Paragon bridge changes**: PR with Paragon version compatibility note
- **Hardcoded color removal**: PR with token reference migration

## Token Usage Linting

The `verify-design-token-usage.sh` script scans theme SCSS/CSS files for hardcoded hex colors that should be token references. Allowed structural colors (white, black, footer bg) are excluded.

**Example violations**:
- `color: #ab3b78;` → should use `var(--mereka-color-magenta)`
- `background: #295cad;` → should use `var(--mereka-color-blue)`

**Allowed structural values**:
- `#fff`, `#ffffff`, `#000`, `#000000` (semantic white/black)
- `#1A1623` (footer v2 background, structural element)

## Related Files

### Token Definitions
- `assets/branding/tokens.css` — Canonical token source (Figma export)
- `assets/branding/tokens.provenance.json` — SHA256 provenance tracking
- `infrastructure/tutor/themes/mereka/scss/_tokens.scss` — SCSS bridge (defines both `$vars` and `--mereka-*` + `--pgn-*` CSS vars)
- `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` — Runtime CSS (runtime token definitions + aliases)

### Theme Files (Consumption)
- `infrastructure/tutor/themes/mereka/scss/theme.scss` — LMS/Studio theme (uses `$vars` from `_tokens.scss`)
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` — MFE theme (uses `var(--mereka-*)` references)
- `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css` — LMS-specific overrides
- `infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css` — Studio-specific overrides

### Verification Scripts
- `scripts/branding/verify-token-drift.sh` — Drift guard (9 required pairs)
- `scripts/qa/verify-token-definitions.sh` — Definition correctness checker
- `scripts/qa/verify-design-tokens.sh` — Full 12-AC gate
- `scripts/qa/verify-design-token-usage.sh` — Hardcoded color lint (NEW)
- `scripts/qa/verify-contrast-compliance.sh` — WCAG AA contrast checker

## Paragon Version Compatibility

Current Paragon version: **1.8.x** (via `@openedx/frontend-plugin-framework@^1.8.0`)

Token bridges tested against: Paragon 1.8.0 component library defaults.

**Upgrade Notes**: When upgrading Paragon, verify new tokens introduced in Paragon changelog and consider bridging if relevant to Mereka brand.
