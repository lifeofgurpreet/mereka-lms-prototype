# Frontend Phase B: Brand Foundation — Implementor Prompt

**Date**: 2026-02-27
**Prerequisite**: Phase A complete (FE-003, FE-004, FE-013, FE-014, FE-016 all DONE)
**Specs**: `specs/oep48-brand-package_spec.md`, `specs/paragon-design-tokens-migration_spec.md`

**Status**: Phase B is PARTIALLY COMPLETE. An implementor agent has already created:
- `infrastructure/tutor/brand-mereka/` — the OEP-48 brand package (Task B1 DONE)
- `infrastructure/tutor/patches/brand-package.sh` — the build-context sync script (Task B2 partially done)

**Remaining work**: Tasks B3 (hardcoded color elimination) and B4 (Paragon token bridging) are NOT YET DONE.

**Phase B Review Findings (CRITICAL — already fixed)**:
- RGB values in `_tokens.scss` were wrong: `--mereka-color-teal-rgb` was `45 137 139` (corrected to `35 112 114`), `--mereka-color-indigo-rgb` was `39 110 241` (corrected to `41 92 173`)
- Duplicate `--pgn-spacing-spacer-*` tokens (7 lines) and duplicate `--pgn-color-primary-400/500` declarations were removed
- MFE Caddy `/theme/*` handler had double path nesting bug (root was `/openedx/dist/theme`, corrected to `/openedx/dist`)
- Outer Caddy had blanket `Cache-Control: no-store` killing static asset caching (replaced with tiered policy)

---

## Objective

Create the OEP-48-compliant `@edx/brand` npm package so that ALL React MFEs (authn, learning, profile, etc.) render Mereka fonts, colors, and logos instead of stock Open edX branding. Then clean up hardcoded colors in the existing theme.

---

## Task B1: Create `@edx/brand-mereka` Package (FE-001)

### What to create

Create the brand package at `infrastructure/tutor/brand-mereka/` with this exact structure:

```
infrastructure/tutor/brand-mereka/
├── package.json
├── logo.svg                    # Copy from assets/branding/mereka-logo.svg (or theme equivalent)
├── logo-white.svg              # White variant (create if missing — white fill version)
├── logo.png                    # Raster fallback ≥200px wide
├── logo-white.png              # Raster white variant
├── favicon.ico                 # Copy from existing theme favicon
├── paragon/
│   ├── fonts.scss              # 9 @font-face declarations (see below)
│   ├── _variables.scss         # Bootstrap SCSS variable overrides (see below)
│   └── tokens.json             # Placeholder JSON tokens (see below)
└── fonts/
    ├── Poppins-Regular.woff2   # Copy from infrastructure/tutor/themes/mereka/lms/static/fonts/
    ├── Poppins-SemiBold.woff2
    ├── Poppins-Bold.woff2
    ├── Lato-Regular.woff2
    ├── Lato-Bold.woff2
    ├── Lato-Italic.woff2
    ├── Lato-BoldItalic.woff2
    ├── Lato-Black.woff2
    └── Lato-BlackItalic.woff2
```

### package.json

```json
{
  "name": "@edx/brand-mereka",
  "version": "1.0.0",
  "description": "Mereka Academy OEP-48 brand package for Open edX MFEs",
  "main": "package.json",
  "exports": {
    "./logo.svg": "./logo.svg",
    "./logo-white.svg": "./logo-white.svg",
    "./logo.png": "./logo.png",
    "./logo-white.png": "./logo-white.png",
    "./favicon.ico": "./favicon.ico",
    "./paragon/fonts.scss": "./paragon/fonts.scss",
    "./paragon/_variables.scss": "./paragon/_variables.scss",
    "./paragon/tokens.json": "./paragon/tokens.json"
  },
  "peerDependencies": {
    "@openedx/paragon": ">=21.0.0"
  },
  "license": "AGPL-3.0"
}
```

**Rules**: No `dependencies`. No runtime JavaScript. Asset-only package.

### paragon/fonts.scss

Create 9 `@font-face` declarations. Use `font-display: swap` and relative paths:

```scss
// Poppins family (3 weights)
@font-face {
  font-family: 'Poppins';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url('../fonts/Poppins-Regular.woff2') format('woff2');
}

@font-face {
  font-family: 'Poppins';
  font-style: normal;
  font-weight: 600;
  font-display: swap;
  src: url('../fonts/Poppins-SemiBold.woff2') format('woff2');
}

@font-face {
  font-family: 'Poppins';
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url('../fonts/Poppins-Bold.woff2') format('woff2');
}

// Lato family (6 variants)
@font-face {
  font-family: 'Lato';
  font-style: normal;
  font-weight: 400;
  font-display: swap;
  src: url('../fonts/Lato-Regular.woff2') format('woff2');
}

@font-face {
  font-family: 'Lato';
  font-style: normal;
  font-weight: 700;
  font-display: swap;
  src: url('../fonts/Lato-Bold.woff2') format('woff2');
}

@font-face {
  font-family: 'Lato';
  font-style: italic;
  font-weight: 400;
  font-display: swap;
  src: url('../fonts/Lato-Italic.woff2') format('woff2');
}

@font-face {
  font-family: 'Lato';
  font-style: italic;
  font-weight: 700;
  font-display: swap;
  src: url('../fonts/Lato-BoldItalic.woff2') format('woff2');
}

@font-face {
  font-family: 'Lato';
  font-style: normal;
  font-weight: 900;
  font-display: swap;
  src: url('../fonts/Lato-Black.woff2') format('woff2');
}

@font-face {
  font-family: 'Lato';
  font-style: italic;
  font-weight: 900;
  font-display: swap;
  src: url('../fonts/Lato-BlackItalic.woff2') format('woff2');
}
```

### paragon/_variables.scss

Extract values from `infrastructure/tutor/themes/mereka/scss/_tokens.scss` (lines 132-150):

```scss
// Mereka Academy brand overrides for Paragon/Bootstrap
// Source of truth: assets/branding/tokens.css
//
// DEPRECATED: These SCSS variables are deprecated in Paragon v23+.
// Use paragon/tokens.json for new implementations.

$font-family-sans-serif: 'Poppins', 'Lato', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !default;
$headings-font-family: 'Lato', 'Poppins', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !default;

$primary: #ab3b78 !default;
$secondary: #237072 !default;
$success: #2c6e49 !default;
$info: #295cad !default;
$warning: #f4be48 !default;
$danger: #8c002f !default;

$link-color: #295cad !default;
$link-hover-color: #237072 !default;

$btn-border-radius: 9999px !default;
$btn-border-radius-sm: 9999px !default;
$btn-border-radius-lg: 9999px !default;
```

### paragon/tokens.json

Placeholder — full token pipeline is a future phase:

```json
{
  "colors": {
    "primary": "#ab3b78",
    "secondary": "#237072",
    "success": "#2c6e49",
    "info": "#295cad",
    "warning": "#f4be48",
    "danger": "#8c002f"
  },
  "typography": {
    "font-family-sans-serif": "'Poppins', 'Lato', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    "font-family-heading": "'Lato', 'Poppins', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
  }
}
```

### Logo files

Search for existing logos in these locations and copy:
- `assets/branding/` — check for SVG/PNG logo files
- `infrastructure/tutor/themes/mereka/lms/static/images/` — LMS logos
- `infrastructure/tutor/themes/mereka/common/static/images/` — common logos

If no SVG logo exists, note it as a gap that needs design work. Do NOT create placeholder logos.

### Font files

Copy from `infrastructure/tutor/themes/mereka/lms/static/fonts/` — all 9 woff2 files already exist there.

---

## Task B2: Wire Brand Package into Tutor Plugin (FE-001 cont.)

### Modify `infrastructure/tutor/plugins/mereka_lms.py`

Add a hook to copy the brand package into MFE build context and install it as `@edx/brand`:

The plugin needs to use the `mfe-dockerfile-pre-npm-install` hook (or equivalent Tutor v21 hook) to:

1. **COPY** the `brand-mereka/` directory into the MFE Docker build context
2. **RUN** `npm install @edx/brand@file:./brand-mereka --legacy-peer-deps`

Research the exact Tutor v21 MFE build hook name. Check:
- `infrastructure/tutor/plugins/mereka_lms.py` for existing MFE hooks
- `infrastructure/tutor/patches/mfe-node.sh` for how the MFE Dockerfile is currently patched

The key is that MFEs resolve `@edx/brand` via npm — the npm alias must point to our local package.

### Modify `infrastructure/tutor/apply-patches.sh`

In the `build-optimizations.sh` patch (or create a new `brand-package.sh` patch module), ensure:
1. The brand-mereka directory is synced into the Tutor MFE build context
2. The MFE Dockerfile gets the COPY + npm install lines

---

## Task B3: Eliminate Hardcoded Colors (FE-011)

### What to fix

In `infrastructure/tutor/themes/mereka/mfe/mereka.scss`, replace all hardcoded hex/rgba values with CSS custom property references.

**Hardcoded values to replace** (search the file):

| Hardcoded | Replace with |
|-----------|-------------|
| `#237072` | `var(--mereka-color-teal)` |
| `#1a5c5e` | `var(--mereka-color-teal-dark)` |
| `#0a4042` | `var(--mereka-color-teal-darker)` |
| `#ab3b78` | `var(--mereka-color-magenta)` |
| `#8a2f60` | `var(--mereka-color-magenta-dark)` |
| `#295cad` | `var(--mereka-color-blue)` |
| `#f7f7f7` | `var(--mereka-bg-surface)` |
| `rgba(...)` values | Use `var(--mereka-shadow-*)` or define new tokens |

**Rules**:
- Every color MUST reference a `--mereka-*` or `--pgn-*` custom property
- If a token doesn't exist in `_tokens.scss`, add it to the `:root` block
- Also add any new tokens to `assets/branding/tokens.css` (canonical source)
- Run `scripts/branding/generate-tokens-from-canonical.sh` after adding new tokens

### What NOT to fix (yet)

- Don't touch the BEM selector overrides (`.pgn__card`, etc.) — that's FE-010, Phase C
- Don't restructure the file — just replace literal color values with token references

---

## Task B4: Bridge Remaining Paragon Token Slots (FE-012)

### Current state

`_tokens.scss` bridges ~11 of ~60+ Paragon token slots. The missing ones:

| Category | Missing Tokens |
|----------|---------------|
| **Spacing** | `--pgn-spacing-1` through `--pgn-spacing-6` (none defined) |
| **Border radius** | `--pgn-border-radius-sm`, `--pgn-border-radius`, `--pgn-border-radius-lg` |
| **Elevation** | `--pgn-elevation-1` through `--pgn-elevation-4` (shadow scale) |
| **Color tints** | `--pgn-color-primary-100` through `--pgn-color-primary-500` (tint scale) |
| **Typography** | `--pgn-font-size-sm`, `--pgn-font-size-base`, `--pgn-font-size-lg`, `--pgn-line-height-*` |
| **Z-index** | `--pgn-zindex-dropdown`, `--pgn-zindex-modal`, etc. |
| **Transition** | `--pgn-transition-base`, `--pgn-transition-fade` |

### What to do

1. Research which `--pgn-*` custom properties Paragon v22 (Ulmo) actually reads
2. Add the missing ones to `assets/branding/tokens.css` with Mereka-appropriate values
3. Run `scripts/branding/generate-tokens-from-canonical.sh` to propagate
4. Verify with: check that `_tokens.scss` `:root` block now includes the new properties

**Do NOT guess values** — check Paragon's source code or documentation for the expected property names and default values, then substitute Mereka's design values where appropriate.

---

## Verification

After all tasks:

1. **Brand package structure**: `ls -la infrastructure/tutor/brand-mereka/` — all files present
2. **Package.json valid**: `cd infrastructure/tutor/brand-mereka && npm pack --dry-run` — no errors
3. **Font file integrity**: All 9 woff2 files match originals (`sha256sum`)
4. **No hardcoded colors**: `grep -nE '#[0-9a-fA-F]{6}' infrastructure/tutor/themes/mereka/mfe/mereka.scss` — should return 0 matches (or only in comments)
5. **Token count**: `grep -c 'var(--' infrastructure/tutor/themes/mereka/scss/_tokens.scss` — should be significantly higher than before
6. **CI passes**: Run `scripts/branding/generate-tokens-from-canonical.sh` and verify output matches committed files

---

## Files to Modify

| File | Action |
|------|--------|
| `infrastructure/tutor/brand-mereka/` (entire directory) | CREATE |
| `infrastructure/tutor/plugins/mereka_lms.py` | MODIFY (add MFE brand hook) |
| `infrastructure/tutor/apply-patches.sh` or `patches/brand-package.sh` | MODIFY (add brand sync) |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | MODIFY (replace hardcoded colors) |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | MODIFY (add missing Paragon slots) |
| `assets/branding/tokens.css` | MODIFY (add new token definitions) |

## Files to READ First

| File | Why |
|------|-----|
| `specs/oep48-brand-package_spec.md` | Full spec with acceptance criteria |
| `specs/paragon-design-tokens-migration_spec.md` | Token format and migration phases |
| `infrastructure/tutor/plugins/mereka_lms.py` | Understand existing plugin hooks |
| `infrastructure/tutor/patches/mfe-node.sh` | See how the MFE Dockerfile is patched |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | Current token state |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | Current MFE styling |
| `assets/branding/tokens.css` | Canonical token source |
| `scripts/branding/generate-tokens-from-canonical.sh` | Token generation pipeline |

---

## Commit Strategy

Make 4 separate commits:
1. `feat: create @edx/brand-mereka OEP-48 brand package (FE-001)`
2. `feat: wire brand package into Tutor MFE build pipeline (FE-001)`
3. `refactor: replace hardcoded colors with design token references (FE-011)`
4. `feat: bridge remaining Paragon token slots (FE-012)`
