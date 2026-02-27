# Frontend Phase C: Runtime Theming — Implementor Prompt

**Date**: 2026-02-27
**Prerequisite**: Phase B complete (FE-001, FE-011, FE-012 all DONE)
**Specs**: `specs/paragon-design-tokens-migration_spec.md` (Phases 2 and 3)

---

## Objective

Enable runtime CDN theming via `PARAGON_THEME_URLS` so that brand color/typography changes propagate to all MFEs without rebuilding Docker images. Then systematically replace the BEM selector overrides in `mereka.scss` with Paragon design token equivalents so that component appearance is controlled at the token level rather than by targeting fragile class names.

The dependency chain is: **FE-015** (set PARAGON_THEME_URLS) then **FE-010** (replace BEM overrides with tokens).

---

## Background: What is PARAGON_THEME_URLS?

Open edX MFEs built on `@edx/frontend-platform` support an environment variable called `PARAGON_THEME_URLS`. When set, the MFE runtime fetches compiled CSS from the specified URLs at page load and injects them into the document head. This CSS contains `--pgn-*` custom properties that override Paragon's default theme tokens.

The structure is:

```json
{
  "core": {
    "urls": {
      "default": "https://apps.academyv2.mereka.io/theme/core.min.css",
      "brandOverride": "https://apps.academyv2.mereka.io/theme/mereka-brand.min.css"
    }
  },
  "variants": {
    "light": {
      "urls": {
        "default": "https://apps.academyv2.mereka.io/theme/light.min.css",
        "brandOverride": "https://apps.academyv2.mereka.io/theme/mereka-brand-light.min.css"
      }
    }
  }
}
```

- `core.urls.default` — the base Paragon theme CSS (can be the stock Paragon output).
- `core.urls.brandOverride` — Mereka-specific token overrides that layer on top. This is the file we compile from our JSON token pipeline.
- `variants.light` — light mode variant (we use light mode only; dark mode is out of scope).

**Why this matters**: Currently, brand CSS (`mereka.scss`) is compiled into every MFE image at Webpack build time. Changing a brand color requires rebuilding all MFE images (15-20 min) and redeploying. With `PARAGON_THEME_URLS`, the brand CSS is fetched at page load from a CDN URL. Updating the brand requires only rebuilding the token CSS file (seconds) and invalidating CDN cache.

---

## Background: What is "Token-Based" Theming?

Currently, `mereka.scss` targets Paragon BEM class names directly (e.g., `.pgn__btn--primary`, `.pgn__card`, `.pgn__alert--info`) to apply brand styling. This is fragile because Paragon can rename or restructure these classes.

**Token-based theming** means controlling component appearance through CSS custom properties (`--pgn-*`) that Paragon components read internally. Instead of:

```scss
/* BEM override — fragile, breaks if Paragon renames the class */
.pgn__btn--primary {
  background-image: linear-gradient(120deg, #ab3b78, #237072, #295cad);
  border: none;
  box-shadow: 0 12px 30px rgba(41, 92, 173, 0.3);
}
```

You define component tokens in JSON:

```json
{
  "button": {
    "primary": {
      "background": { "value": "linear-gradient(120deg, {global.color.magenta} 0%, {global.color.teal} 60%, {global.color.blue} 100%)" },
      "border": { "value": "none" },
      "box-shadow": { "value": "0 12px 30px rgba({global.color.blue-rgb}, 0.3)" }
    },
    "border-radius": { "value": "{global.radius.full}" }
  }
}
```

The style-dictionary pipeline compiles these into `--pgn-*` CSS custom properties in a `:root` block. Paragon components consume the custom properties natively. No BEM class targeting needed.

**Limitation**: Not all visual properties in `mereka.scss` can be expressed as tokens. Properties like `display`, `flex`, `gap`, `padding`, `margin`, `aspect-ratio`, `object-fit`, `min-width`, `max-width`, `min-height` are structural layout overrides. These MUST remain as CSS rules (retained overrides). The goal is to eliminate token-expressible overrides (colors, border-radius, box-shadow, font-family, font-weight) and retain only structural ones.

---

## Task C1: Configure PARAGON_THEME_URLS in Tutor Plugin (FE-015)

### What to do

Modify `infrastructure/tutor/plugins/mereka_lms.py` to inject `PARAGON_THEME_URLS` into the MFE runtime configuration. The MFEs read this from the `mfe_config` API response at page load.

### Step 1: Add config defaults

In the `CONFIG_DEFAULTS` section (around line 37), add:

```python
("MEREKA_PARAGON_THEME_ENABLED", False),
("MEREKA_PARAGON_THEME_CDN_BASE", "/theme"),
```

### Step 2: Add MFE runtime config injection

Add a new `openedx-lms-production-settings` patch (or extend the existing one) that injects `PARAGON_THEME_URLS` into the MFE config API response. The LMS serves MFE config via `MFE_CONFIG` dict in Django settings:

```python
# In the openedx-lms-production-settings patch:
if {{ MEREKA_PARAGON_THEME_ENABLED }}:
    _theme_base = "{{ MEREKA_PARAGON_THEME_CDN_BASE }}"
    MFE_CONFIG["PARAGON_THEME_URLS"] = {
        "core": {
            "urls": {
                "default": f"{_theme_base}/core.min.css",
                "brandOverride": f"{_theme_base}/mereka-brand.min.css",
            }
        },
        "variants": {
            "light": {
                "urls": {
                    "default": f"{_theme_base}/light.min.css",
                    "brandOverride": f"{_theme_base}/mereka-brand-light.min.css",
                }
            }
        },
    }
```

**Key detail**: The CDN base should be a relative path (`/theme`) for local development. For production, it resolves against the MFE origin (`https://apps.academyv2.mereka.io/theme/...`). The Caddyfile already serves static assets from the MFE container, so we need a Caddy route to serve theme CSS files.

### Step 3: Add Caddy route for theme CSS

The Caddyfile at `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` already has a `@mfe_theme_css` handler (lines 48-55) that serves theme CSS from `/openedx/dist/`. Verify this handler correctly serves the compiled theme CSS files. If the theme CSS files are placed at a different path (e.g., `/openedx/dist/theme/`), add a new handler:

```
@theme_css {
    path /theme/*
}
handle @theme_css {
    root * /openedx/dist
    file_server
}
```

### Step 4: Include compiled theme CSS in MFE image

Add a Dockerfile hook (`mfe-dockerfile-post-npm-install` or a new hook) that copies the compiled token CSS into the MFE static asset directory:

```dockerfile
# Copy compiled Paragon theme CSS into MFE dist
COPY indigo/theme/ /openedx/dist/theme/
```

This requires the `build-tokens.sh` script (from Phase B4 / the token pipeline spec) to output files to `infrastructure/tutor/themes/mereka/mfe/theme/` which then gets synced into the Tutor build context by `apply-patches.sh`.

### Step 5: Build the compiled theme CSS files

Create or update `scripts/branding/build-tokens.sh` to produce four CSS files:

| File | Contents |
|------|----------|
| `core.min.css` | Paragon's default core theme CSS (copy from Paragon npm package) |
| `mereka-brand.min.css` | Mereka token overrides: all `--pgn-*` custom properties in `:root` |
| `light.min.css` | Light variant core (copy from Paragon) |
| `mereka-brand-light.min.css` | Mereka light variant overrides (same as brand for now; dark mode is out of scope) |

The `mereka-brand.min.css` file should contain the `:root` block from `_tokens.scss` lines 59-134 (all `--pgn-*` properties) compiled into a standalone CSS file. This is the file that replaces build-time SCSS compilation for brand tokens.

**Build script approach**:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Extract --pgn-* custom properties from _tokens.scss into standalone CSS
# (Later phases will use style-dictionary JSON pipeline instead)
OUTPUT_DIR="infrastructure/tutor/themes/mereka/mfe/theme"
mkdir -p "$OUTPUT_DIR"

# Generate mereka-brand.min.css from existing --pgn-* tokens
cat > "$OUTPUT_DIR/mereka-brand.min.css" << 'CSSEOF'
:root {
  /* Auto-generated from _tokens.scss --pgn-* properties */
  --pgn-color-primary: #ab3b78;
  --pgn-color-secondary: #237072;
  /* ... all --pgn-* properties from _tokens.scss ... */
}
CSSEOF

# Copy Paragon core CSS from node_modules (during MFE build)
# or create minimal placeholder for now
```

**Important**: This is a transitional approach. The full style-dictionary JSON pipeline (spec Phase 1) will replace this manual extraction. For now, the goal is to get `PARAGON_THEME_URLS` working with CSS extracted from our existing `_tokens.scss`.

---

## Task C2: Replace BEM Selector Overrides with Token Equivalents (FE-010)

### What to do

Systematically evaluate every BEM selector override in `mereka.scss` and either:
1. **Replace** it with a component token in `_tokens.scss` (add a `--pgn-*` custom property), OR
2. **Retain** it with justification (structural override not expressible as a token)

### Complete Inventory of BEM Selector Overrides

Below is every `.pgn__*` selector (and its paired Bootstrap selector where applicable) in `mereka.scss`, with the recommended disposition.

#### Global Component Overrides (no MFE scoping)

| # | Line | Selector | Properties | Disposition |
|---|------|----------|-----------|-------------|
| 1 | 25-28 | `.pgn__page-container, .page-container` | `background: transparent` | **REPLACE** with token `--pgn-body-bg` or retain as a simple 1-line structural override |
| 2 | 79-83 | `.pgn__btn--primary` | `background-image` (gradient), `border: none`, `box-shadow` | **PARTIAL** — gradient is not a standard token; add `--pgn-btn-primary-bg`, `--pgn-btn-primary-border`, `--pgn-btn-primary-box-shadow` tokens. Gradient value may need to stay as CSS. |
| 3 | 88-92 | `.pgn__btn--primary:hover, :focus` | `transform`, `box-shadow` | **RETAIN** — `transform: translateY(-1px)` is structural (not tokenizable). Shadow color can be tokenized. |
| 4 | 109-112 | `.pgn__btn--secondary, .pgn__btn--link` | `color` | **REPLACE** with `--pgn-btn-secondary-color` / `--pgn-btn-link-color` tokens |
| 5 | 115-120 | `.pgn__btn--secondary:hover/:focus, .pgn__btn--link:hover/:focus` | `color` | **REPLACE** with hover/focus token variants |
| 6 | 123-128 | `.pgn__form-control, .form-control` | `border-radius: 16px`, `border-color`, `box-shadow: none` | **REPLACE** with `--pgn-form-control-border-radius`, `--pgn-form-control-border-color` tokens |
| 7 | 131-135 | `.pgn__form-control:focus, .form-control:focus` | `border-color`, `box-shadow` (focus ring) | **REPLACE** with `--pgn-form-control-focus-border-color`, `--pgn-form-control-focus-box-shadow` tokens |
| 8 | 138-142 | `.pgn__form-label, label` | `font-weight: 600`, `color` | **REPLACE** with `--pgn-form-label-font-weight`, `--pgn-form-label-color` tokens |
| 9 | 147-151 | `.pgn__card` (+ `.card`, `.shadow-lg`) | `border-radius: 24px`, `border`, `box-shadow` | **REPLACE** with `--pgn-card-border-radius`, `--pgn-card-border-color`, `--pgn-card-box-shadow` tokens |
| 10 | 154-158 | `.pgn__card-header, .card-header` | `background`, `border-bottom` | **REPLACE** with `--pgn-card-header-bg`, `--pgn-card-header-border-color` tokens |
| 11 | 161-165 | `.pgn__card-footer, .card-footer` | `background`, `border-top` | **REPLACE** with `--pgn-card-footer-bg`, `--pgn-card-footer-border-color` tokens |
| 12 | 168-171 | `.pgn__alert` | `border-radius: 16px`, `border` | **REPLACE** with `--pgn-alert-border-radius`, `--pgn-alert-border-color` tokens |
| 13 | 174-177 | `.pgn__alert--info` | `background`, `border-color` | **REPLACE** with `--pgn-alert-info-bg`, `--pgn-alert-info-border-color` tokens |
| 14 | 180-183 | `.pgn__alert--success` | `background`, `border-color` | **REPLACE** with `--pgn-alert-success-bg`, `--pgn-alert-success-border-color` tokens |
| 15 | 186-189 | `.pgn__alert--warning` | `background`, `border-color` | **REPLACE** with `--pgn-alert-warning-bg`, `--pgn-alert-warning-border-color` tokens |
| 16 | 192-195 | `.pgn__alert--danger` | `background`, `border-color` | **REPLACE** with `--pgn-alert-danger-bg`, `--pgn-alert-danger-border-color` tokens |
| 17 | 198-202 | `.pgn__modal-content` | `border-radius: 24px`, `border`, `box-shadow` | **REPLACE** with `--pgn-modal-border-radius`, `--pgn-modal-border-color`, `--pgn-modal-box-shadow` tokens |
| 18 | 206-209 | `.pgn__dropdown-menu` (+ `.dropdown-menu`) | `border-radius: 16px`, `border`, `box-shadow` | **REPLACE** with `--pgn-dropdown-border-radius`, `--pgn-dropdown-border-color`, `--pgn-dropdown-box-shadow` tokens |
| 19 | 214-216 | `.pgn__tabs .nav-link` | `border-radius: 999px` | **REPLACE** with `--pgn-tab-border-radius` token |
| 20 | 220-224 | `.pgn__tabs .nav-link.active` | `background-image` (gradient), `color`, `border-color` | **PARTIAL** — gradient may need to stay as CSS; `color` and `border-color` are tokenizable |

#### Authn MFE Scoped Overrides

| # | Line | Selector | Properties | Disposition |
|---|------|----------|-----------|-------------|
| 21 | 256-261 | `[class*="authn"] .pgn__card` | `border-radius: 28px`, `border`, `box-shadow` | **RETAIN** — surface-scoped structural override; token covers global `.pgn__card` but authn needs a larger radius |
| 22 | 266-274 | `[class*="authn"] .pgn__card-header` | `background-image` (gradient) | **RETAIN** — surface-specific gradient, not a global token |
| 23 | 279-284 | `[class*="authn"] .pgn__btn--primary` | `min-height: 44px`, `font-weight`, `letter-spacing` | **RETAIN** — `min-height` is structural; font-weight could be tokenized but the scoping makes it authn-specific |
| 24 | 289-294 | `[class*="authn"] .pgn__hyperlink` | `color`, `text-decoration`, `font-weight` | **RETAIN** — scoped override for authn surface only |
| 25 | 299-305 | `[class*="authn"] .pgn__hyperlink:hover/:focus` | `color`, `text-decoration` | **RETAIN** — scoped override for authn surface only |

#### Account/Dashboard MFE Scoped Overrides

| # | Line | Selector | Properties | Disposition |
|---|------|----------|-----------|-------------|
| 26 | 324-333 | `[class*="account-*"] .pgn__card` | `border-radius`, `border`, `box-shadow` | **REPLACE** (once global `.pgn__card` token works, these redundant scoped overrides can be removed) |
| 27 | 339-343 | `[class*="account-*"] .pgn__form-control` | `background` | **REPLACE** with `--pgn-form-control-bg` token |
| 28 | 349-353 | `[class*="account-*"] .pgn__btn` | `border-radius: 999px` | **REPLACE** (already covered by global `--pgn-btn-border-radius: 999px` token) |
| 29 | 359-363 | `[class*="account-*"] .pgn__alert` | `border-radius: 16px` | **REPLACE** (already covered by global `--pgn-alert-border-radius` token) |
| 30 | 369-374 | `[class*="account-*"] .pgn__dropdown-toggle` | `border-radius: 999px`, `border-color` | **REPLACE** (covered by global dropdown token) |

#### Learning MFE Scoped Overrides

| # | Line | Selector | Properties | Disposition |
|---|------|----------|-----------|-------------|
| 31 | 445-453 | `[class*="learning"] :is(.pgn__card, .card)` | `border-radius`, `border`, `box-shadow`, `background`, `overflow`, `margin-bottom` | **PARTIAL** — radius/border/shadow tokenizable; `overflow: hidden` and `margin-bottom` are structural, RETAIN those |
| 32 | 456-466 | `[class*="learning"] :is(.pgn__card, .card) :is(.pgn__card-image-cap, ...)` | `max-width`, `width`, `min-width` | **RETAIN** — entirely structural (sizing) |
| 33 | 478-481 | `[class*="learning"] :is(.pgn__card, .card)` (media query) | `min-width: 0` | **RETAIN** — structural responsive fix |

#### Discussions MFE Scoped Overrides

| # | Line | Selector | Properties | Disposition |
|---|------|----------|-----------|-------------|
| 34 | 541-546 | `[class*="discussions"] .pgn__card` | `border-radius: 22px`, `border`, `box-shadow` | **REPLACE** (once global `.pgn__card` token works) |
| 35 | 563-567 | `[class*="discussions"] .pgn__btn--primary` | `background-image` (gradient), `border: none` | **REPLACE** (once global `.pgn__btn--primary` token works) |

### Summary Count

| Disposition | Count | Description |
|------------|-------|-------------|
| **REPLACE** (fully tokenizable) | ~20 | Can be eliminated by adding `--pgn-*` component tokens |
| **PARTIAL** (some props tokenizable) | ~4 | Some properties become tokens, structural props remain |
| **RETAIN** (structural or surface-scoped) | ~11 | Cannot be expressed as tokens; remain as CSS overrides |

### How to implement the replacements

For each "REPLACE" override:

1. **Add the `--pgn-*` token** to `_tokens.scss` `:root` block (and later to the JSON token pipeline). Example for card:
   ```scss
   :root {
     /* existing tokens ... */
     --pgn-card-border-radius: 24px;
     --pgn-card-box-shadow: 0 25px 60px rgb(var(--mereka-color-ink-deep-rgb) / 0.08);
     --pgn-card-border-color: rgb(var(--mereka-color-ink-deep-rgb) / 0.08);
   }
   ```

2. **Verify Paragon reads the token**. Check whether Paragon's Card component actually reads `--pgn-card-border-radius` (or `var(--pgn-card-border-radius)`) in its SCSS. If Paragon does NOT read this specific token name, you have two options:
   - a) The token override still works if it matches the CSS custom property Paragon generates (inspect the MFE in browser DevTools to find the actual property name).
   - b) If no Paragon token exists for that property, the BEM override must be RETAINED until Paragon adds token support.

3. **Remove the BEM rule** from `mereka.scss` once the token is confirmed working.

4. **Test visually** in each affected MFE to confirm no regression.

### Token names to research

Before adding tokens, inspect the Paragon source or the compiled MFE CSS in browser DevTools to find the actual CSS custom property names Paragon uses. Common patterns:

```
--pgn-btn-primary-bg
--pgn-btn-primary-border-color
--pgn-btn-primary-color
--pgn-btn-border-radius
--pgn-card-border-radius
--pgn-card-border-color
--pgn-card-box-shadow-*
--pgn-alert-border-radius
--pgn-alert-{variant}-bg
--pgn-alert-{variant}-border-color
--pgn-modal-border-radius
--pgn-dropdown-border-radius
--pgn-form-control-border-radius
--pgn-form-control-border-color
--pgn-form-control-focus-border-color
--pgn-form-control-focus-box-shadow
--pgn-form-label-color
--pgn-form-label-font-weight
--pgn-tab-border-radius
```

**CRITICAL**: Do NOT guess token names. Check the actual Paragon v22 source code or inspect running MFEs. Paragon may use different naming conventions (e.g., `--pgn-color-primary` vs `--pgn-btn-primary-bg`). Wrong token names silently fail — the CSS property is set but Paragon never reads it.

---

## Task C3: Update build-tokens.sh for New Tokens (FE-015 cont.)

After adding component tokens in Task C2, update `scripts/branding/build-tokens.sh` to include all new `--pgn-*` tokens in `mereka-brand.min.css`. The compiled CSS file served via `PARAGON_THEME_URLS` must contain every `--pgn-*` custom property from `_tokens.scss`.

---

## Task C4: Add Verification Script

Create `scripts/qa/verify-paragon-theme-urls.sh`:

```bash
#!/usr/bin/env bash
# @covers AC-TKN-016, AC-TKN-017, AC-TKN-020, AC-TKN-021
# @spec: paragon-design-tokens-migration_spec
set -euo pipefail

# 1. Verify mereka_lms.py contains PARAGON_THEME_URLS config
# 2. Verify theme CSS files exist in expected location
# 3. Verify theme CSS contains --pgn-color-primary
# 4. Verify theme CSS contains at least 100 --pgn-* properties
# 5. Verify Caddyfile has route for /theme/* (or mfe_theme_css handler)
```

Add the script to `.github/ci-scripts-static.txt`.

---

## Verification

After all tasks:

1. **PARAGON_THEME_URLS in plugin**: `grep -c 'PARAGON_THEME_URLS' infrastructure/tutor/plugins/mereka_lms.py` returns >= 1
2. **Theme CSS exists**: `ls infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand.min.css`
3. **Theme CSS has tokens**: `grep -c '\-\-pgn-' infrastructure/tutor/themes/mereka/mfe/theme/mereka-brand.min.css` returns >= 100
4. **mereka.scss reduced**: `wc -l infrastructure/tutor/themes/mereka/mfe/mereka.scss` is less than the current 583 lines (target: < 200 lines after removing tokenizable overrides)
5. **No removed scoped overrides break**: Manually check authn, dashboard, learning, discussions MFEs for visual regressions
6. **BEM override count**: `grep -c '\.pgn__' infrastructure/tutor/themes/mereka/mfe/mereka.scss` should be significantly reduced from the current ~35 unique `.pgn__*` selectors
7. **CI passes**: Run `scripts/qa/verify-paragon-theme-urls.sh` and all existing branding scripts

---

## Files to Modify

| File | Action |
|------|--------|
| `infrastructure/tutor/plugins/mereka_lms.py` | MODIFY (add PARAGON_THEME_URLS config + LMS settings patch) |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | MODIFY (add component-level `--pgn-*` tokens to `:root` block) |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | MODIFY (remove BEM overrides replaced by tokens) |
| `scripts/branding/build-tokens.sh` | MODIFY (output mereka-brand.min.css with all `--pgn-*` tokens) |
| `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | MODIFY (verify/add `/theme/*` route if needed) |
| `scripts/qa/verify-paragon-theme-urls.sh` | CREATE |
| `.github/ci-scripts-static.txt` | MODIFY (add new verification script) |
| `infrastructure/tutor/themes/mereka/mfe/theme/` | CREATE (directory for compiled theme CSS) |

## Files to READ First

| File | Why |
|------|-----|
| `specs/paragon-design-tokens-migration_spec.md` | Full spec with acceptance criteria for Phases 2-3 |
| `infrastructure/tutor/plugins/mereka_lms.py` | Understand existing MFE config injection (lines 660-860) |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | All 583 lines — the BEM overrides to evaluate |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | Current `--pgn-*` token bridge (lines 59-134) |
| `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` | Existing theme CSS handler (lines 48-55) |
| `docs/architecture/MFE_RUNTIME_CONFIG.md` | How MFE runtime config works (mfe_config API) |
| `scripts/branding/build-tokens.sh` | Current token build script (if exists from Phase B) |

---

## Commit Strategy

Make 4 separate commits:

1. `feat: configure PARAGON_THEME_URLS in Tutor plugin for runtime CDN theming (FE-015)`
2. `feat: add compiled theme CSS and Caddy serving route (FE-015)`
3. `refactor: replace BEM selector overrides with Paragon component tokens (FE-010)`
4. `test: add PARAGON_THEME_URLS verification script (FE-015)`

---

## Rollback Plan

If runtime theming causes visual regressions:

1. Set `MEREKA_PARAGON_THEME_ENABLED: false` in Tutor config
2. Run `tutor config save && ./infrastructure/tutor/apply-patches.sh && tutor local restart`
3. MFEs fall back to the SCSS-compiled branding (which remains intact during Phase C)
4. No image rebuild required — MFEs check for `PARAGON_THEME_URLS` at runtime and skip if absent

If BEM override removal causes regressions:

1. `git checkout HEAD~1 -- infrastructure/tutor/themes/mereka/mfe/mereka.scss`
2. Rebuild MFE image to restore the original BEM overrides
3. The token definitions in `_tokens.scss` are harmless (unused custom properties) and do not need to be reverted
