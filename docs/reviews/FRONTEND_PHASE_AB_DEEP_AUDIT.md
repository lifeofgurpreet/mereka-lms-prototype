# Frontend Phase A+B Deep Audit — Architecture & OEP-48 Compliance

**Date**: 2026-02-28
**Reviewer**: Opus (reviewer role)
**Scope**: Phase A (Foundation) + Phase B (Brand Foundation) — deep architectural review
**Verdict**: FAIL — 3 critical architecture issues, 4 blocking OEP-48 gaps, 5 high-severity items

**Supersedes**: `FRONTEND_PHASE_AB_AUDIT.md` (shallow file-level review)

---

## 1. Executive Summary

The first audit found 4 missing OEP-48 files. This deep audit examines the **architecture** — how the brand package, theme SCSS, and runtime CSS actually flow through the build pipeline. It reveals 3 critical issues that the first audit missed:

1. **The brand package's SCSS variables are dead** — Paragon v23+ (Ulmo) ignores SCSS variables entirely. Our colors work through a different path (mereka.scss → _tokens.scss CSS custom properties), not through the brand package.

2. **Every MFE carries ~600 lines of dead LMS/Studio CSS** — `mereka.scss` imports `theme.scss` which contains dashboard, courseware, and Studio designer rules. These DOM elements don't exist in MFEs.

3. **The runtime theme CSS files are bloated and duplicated** — `core.min.css` = `light.min.css` (identical 522KB full Paragon bundles), `mereka-brand.min.css` = `mereka-brand-light.min.css` (identical 64KB full token dumps instead of ~2KB brand deltas).

These don't cause visible breakage today because the build-time mereka.scss path compensates, but they represent significant tech debt, wasted bytes, and architectural confusion that will compound in Phase C/D.

---

## 2. How MFE Theming Actually Works (Ulmo / Paragon v23+)

### The Three Theming Paths

| Path | Mechanism | Status in Our Setup | Actually Works? |
|------|-----------|-------------------|-----------------|
| **A. Brand SCSS** | `@edx/brand/paragon/_variables.scss` imported in MFE index.scss | Installed via npm alias | **NO** — Ulmo MFEs don't `@import` from `@edx/brand` for SCSS |
| **B. Build-time CSS vars** | `mereka.scss` → `_tokens.scss` `:root { --pgn-* }` compiled by webpack | Active via `import './mereka/mereka.scss'` in env.config.jsx | **YES** — this is how our colors work |
| **C. Runtime theme** | `PARAGON_THEME_URLS` loads CSS at page load | `MEREKA_PARAGON_THEME_ENABLED=False` (disabled) | **NO** — disabled by default |

### What This Means

The brand package (`brand-mereka/`) only serves ONE purpose: **providing logo and image assets** that MFE components import at build time (e.g., `import logo from '@edx/brand/logo.svg'`). Its SCSS files (`_variables.scss`, `fonts.scss`, `_overrides.scss`) are never imported by any Ulmo-era MFE.

Our actual color/font theming comes from:
```
env.config.jsx
  → import './mereka/mereka.scss'
    → @import "./scss/theme"
      → @import "fonts"  (_fonts.scss — 9 @font-face declarations)
      → @import "tokens"  (_tokens.scss — :root { --pgn-color-primary: ...; })
    → 580 lines of BEM overrides (mereka.scss)
```

This is a **non-standard but working approach**. It bypasses the OEP-48 SCSS pipeline entirely and injects CSS custom properties directly via webpack. The result is correct — MFEs render with Mereka colors and fonts. But the brand package's SCSS is dead weight.

---

## 3. Critical Issues

### CRIT-1: Brand Package SCSS Variables Are Dead

**Impact**: The entire `_variables.scss` file has zero effect on MFE rendering.

**Why**: In Paragon v22 (Palm), MFEs had `@import "@edx/brand/paragon/variables"` in their `index.scss`, which set Bootstrap SCSS variables like `$primary` before Paragon's core SCSS compiled. In Paragon v23+ (Ulmo/Teak), MFEs replaced this with `@use "@openedx/paragon/styles/css/core/custom-media-breakpoints"`. No `@import` from `@edx/brand` for SCSS.

Paragon v23+ components reference `var(--pgn-color-primary)` (CSS custom properties), not `$primary` (SCSS variables). Setting `$primary: #ab3b78 !default` in `_variables.scss` compiles correctly but produces no visible change because no component reads Bootstrap SCSS variables anymore.

**Evidence**: Search any Ulmo-era MFE `src/index.scss` — it contains only:
```scss
@use "@openedx/paragon/styles/css/core/custom-media-breakpoints" as paragonCustomMediaBreakpoints;
```
No `@import "@edx/brand/paragon/fonts"`, no `@import "@edx/brand/paragon/variables"`, no `@import "@edx/brand/paragon/overrides"`.

**Current compensation**: Our colors work because `mereka.scss` → `_tokens.scss` sets `--pgn-color-primary`, `--pgn-color-secondary`, etc. as CSS custom properties in a `:root` block. This block is compiled into every MFE's webpack bundle and cascades correctly.

**Action**: Document this reality. Stop treating `_variables.scss` as the color source of truth. The brand package is an asset container (logos/images), not a theming mechanism in Ulmo.

---

### CRIT-2: theme.scss Leaks ~600 Lines of LMS/Studio CSS Into Every MFE

**Impact**: Every MFE ships ~20KB of dead CSS that targets elements that don't exist in React apps.

**Why**: `mereka.scss` (line 2) does `@import "./scss/theme"`. The `theme.scss` file contains:

| Lines | Content | MFE-relevant? |
|-------|---------|---------------|
| 1-2 | `@import "fonts"` + `@import "tokens"` | **YES** — needed |
| 4-17 | `:root` CSS vars (duplicates from _tokens.scss) | Harmless but wasteful |
| 19-59 | Utility classes (`.bg-mereka-gradient`, `.badge-mereka`, `.mereka-badge`) | **MAYBE** — only if used in JSX |
| 61-117 | LMS header (`.global-header`, `.wrapper-header`, `.mereka-navbar-brand`) | **NO** — LMS Django templates |
| 118-310 | LMS course cards (`.course`, `.course-image`, `.learn-more`) | **NO** — LMS Django templates |
| 312-398 | LMS dashboard (`.dashboard .listing-courses`, `.my-courses`) | **NO** — LMS Django templates |
| 400-443 | LMS courseware (`.courseware .course-content`, `.xblock`) | **NO** — LMS Django templates |
| 446-666 | Footer v2 (`.mereka-footer--v2`) | **PARTIAL** — used by MerekaFooter JSX component |
| 668-787 | Legacy footer + responsive | **PARTIAL** |
| 788-871 | Studio designer (`.wrapper-view`, `.view-outline`, `.btn-default`) | **NO** — Studio Django templates |

**~500 lines** of CSS in `theme.scss` target LMS/Studio Django-rendered pages and have zero effect in MFEs.

**Action**: Split `theme.scss` into:
- `_shared.scss` — fonts + tokens (imported by both LMS theme and MFE)
- `_lms-studio.scss` — LMS/Studio Django page styles (imported by comprehensive theme only)
- `_mfe-footer.scss` — footer v2 styles (imported by mereka.scss only)
- Or simpler: have mereka.scss import `_fonts` and `_tokens` directly, not `theme`

---

### CRIT-3: Runtime Theme CSS Files Are Bloated and Duplicated

**Impact**: If `PARAGON_THEME_URLS` is ever enabled, browser loads ~1.2MB of CSS (4 files), most of it redundant.

| File | Size | Content | Problem |
|------|------|---------|---------|
| `core.min.css` | 522KB | Full Paragon compiled CSS | Should be served from CDN, not self-hosted |
| `light.min.css` | 522KB | **Identical** to core.min.css | Should contain ONLY light-variant variable overrides |
| `mereka-brand.min.css` | 64KB / 847 lines | Full Paragon token dictionary + our overrides | Should contain ONLY ~20 brand-specific variable overrides (~2KB) |
| `mereka-brand-light.min.css` | 64KB / 847 lines | **Identical** to mereka-brand.min.css | Expected (light-only deployment), but still bloated |

**How `brandOverride` should work**: The `PARAGON_THEME_URLS` mechanism loads `default` CSS first (full Paragon), then `brandOverride` second. The `brandOverride` only needs to declare the CSS variables that differ from defaults. Our `mereka-brand.min.css` declares ALL ~800 Paragon tokens, of which only ~20 are different from the default.

**Action**: When building theme CSS, emit only the delta (brand-specific overrides). For `core.min.css`, point to the CDN URL (`https://cdn.jsdelivr.net/npm/@openedx/paragon@$paragonVersion/dist/core.min.css`) or keep self-hosted but ensure it's the actual Paragon distribution file. Generate a proper `light.min.css` that only contains light-variant variables, or remove the light variant entry entirely since we're light-mode-only.

---

## 4. Missing OEP-48 Mandatory Files (Confirmed from Audit v1)

| File | Status | Why It's Needed |
|------|--------|----------------|
| `paragon/_overrides.scss` | **MISSING** | Some MFEs still `@import` this unconditionally. Must exist (can be empty). |
| `paragon/images/card-imagecap-fallback.png` | **MISSING** | Paragon `Card.ImageCap` component fallback |
| `logo-trademark.svg` | **MISSING** | Footer/legal pages import `@edx/brand/logo-trademark.svg` |
| `logo-trademark.png` | **MISSING** | Fallback for logo-trademark |

**Note**: These are only needed for MFE components that import assets from `@edx/brand/...` by path. Since Ulmo MFEs don't import SCSS from the brand package, the SCSS files are cosmetic compliance. But the **image assets are still imported** by `frontend-component-header` and `frontend-component-footer`.

---

## 5. High-Severity Issues

### HIGH-1: `package.json` `exports` Field May Block Imports

The reference `@openedx/brand-openedx` has **NO `exports` field**. Our package has explicit `exports`:

```json
{
  "exports": {
    "./logo.svg": "./logo.svg",
    "./logo-white.svg": "./logo-white.svg",
    ...
  }
}
```

Node.js treats `exports` as a **package boundary** — any path NOT listed throws `ERR_PACKAGE_PATH_NOT_EXPORTED`. If any MFE or Paragon component tries to import an unlisted path (e.g., `@edx/brand/paragon/core.scss`, `@edx/brand/logo-trademark.svg`), it silently fails or errors.

**Action**: Either remove the `exports` field entirely (match the reference), or ensure EVERY importable path is listed including the 4 missing files once created.

### HIGH-2: Duplicate `:root` CSS Variable Blocks

Both `_tokens.scss` and `theme.scss` declare `:root` blocks with overlapping variables:

| Variable | In `_tokens.scss`? | In `theme.scss`? | Same value? |
|----------|-------------------|------------------|-------------|
| `--mereka-color-ink-deep-rgb` | Line 74 | Line 7 | Yes |
| `--mereka-color-indigo-rgb` | Line 65 | Line 8 | Yes |
| `--mereka-color-teal-rgb` | Line 66 | Line 9 | Yes |
| `--mereka-color-magenta-rgb` | Line 67 | Line 10 | Yes |
| `--mereka-color-blue-rgb` | Line 68 | Line 11 | Yes |
| `--mereka-color-sky-rgb` | Line 69 | Line 12 | Yes |
| `--mereka-color-forest-rgb` | Line 70 | Line 13 | Yes |
| `--mereka-color-gold-rgb` | Line 71 | Line 14 | Yes |
| `--mereka-color-burgundy-rgb` | Line 72 | Line 15 | Yes |
| `--mereka-color-white-rgb` | Line 73 | Line 16 | Yes |
| `--mereka-radius-xl` | Line 96 | Line 6 | Yes |

All 11 RGB variables + `--mereka-radius-xl` are declared identically in both files. Since `theme.scss` imports `_tokens.scss`, these are emitted twice in compiled CSS.

**Action**: Remove the `:root` block from `theme.scss` (lines 4-17) — `_tokens.scss` already declares all these.

### HIGH-3: `.mereka-badge` Defined Twice with Different Implementations

**`theme.scss` (lines 47-59)**:
```scss
.mereka-badge {
  gap: 0.35rem;
  font-size: 0.75rem;
  font-weight: 600;
  // hardcoded values
}
```

**`mereka.scss` (lines 224-235)**:
```scss
.mereka-badge {
  gap: var(--mereka-mfe-badge-gap, 0.35rem);
  font-size: var(--pgn-font-size-sm);
  // token references
}
```

The `mereka.scss` version (tokenized) overrides `theme.scss` (hardcoded) via cascade order. But both are compiled, wasting bytes and creating confusion about which is canonical.

**Action**: Remove `.mereka-badge` from `theme.scss`. The tokenized version in `mereka.scss` is correct.

### HIGH-4: Brand Package `fonts.scss` Uses Different Font Loading Than Build Path

Two completely separate font loading mechanisms exist:

| Mechanism | File | Font path | Used by |
|-----------|------|-----------|---------|
| Brand package | `brand-mereka/paragon/fonts.scss` | `../fonts/Poppins-Regular.woff2` (relative) | **Nothing** in Ulmo — MFEs don't import brand SCSS |
| Theme SCSS | `themes/mereka/scss/_fonts.scss` | `#{$mereka-font-path}/Poppins-Regular.woff2` (variable) | **Active** — loaded via mereka.scss → theme.scss |

The brand package `fonts.scss` is dead code in Ulmo. The actual fonts are loaded via `_fonts.scss` (theme SCSS path), with `$mereka-font-path` set to `"../fonts"` in `mereka.scss` line 1.

**Action**: Keep both for compatibility (the brand package is the OEP-48 interface), but document that fonts.scss in the brand package is not consumed at build time.

### HIGH-5: `_tokens.scss` CSS Rules Outside Generated Block

Lines 205-244 of `_tokens.scss` contain CSS rules (`body`, `h1-h6`, `a`, `.btn-primary`, `.card`) AFTER the `// END GENERATED` marker. These survive regeneration of the generated block (lines 1-183) but are fragile:

- If the generation script is changed to overwrite the entire file, they're lost.
- They duplicate some styling that `mereka.scss` also declares (body, headings, buttons).
- They mix concerns — `_tokens.scss` should define tokens, not apply styles.

**Action**: Move lines 205-244 to a new `_base.scss` partial or into the appropriate LMS/MFE stylesheet.

---

## 6. Medium-Severity Issues

### MED-1: `fonts.scss` Should Be `_fonts.scss`

The reference brand-openedx uses `_fonts.scss` (underscore = SCSS partial convention). Our brand package uses `fonts.scss` (no underscore). Both work with SCSS's `@import` resolution, but the naming is non-standard.

### MED-2: Missing `paragon/core.scss` Entry Point

The reference brand-openedx has `paragon/core.scss` as the entry point for the `build-scss` CLI command. Our package doesn't have it. Needed if we ever want to run `paragon build-scss`.

### MED-3: `tokens.json` Format Wrong for `build-tokens` CLI

Our format: `{ "colors": { "primary": "#ab3b78" } }`
DTCG format: `{ "color": { "primary": { "$value": "#ab3b78", "$type": "color" } } }`

The `paragon build-tokens` CLI (v23+) expects the DTCG format. Deferred to `paragon-design-tokens-migration_spec.md`.

### MED-4: No Build Scripts in `package.json`

Reference has `build-tokens`, `build-scss`, `build` scripts. Our package has none.

### MED-5: `peerDependencies` Range Too Broad

`"@openedx/paragon": ">=21.0.0"` — should be `">=22.0.0 <24.0.0"` or more specific. The SCSS variables only work with v22, CSS variables work with v23+.

### MED-6: `prefers-reduced-motion` Missing on Hover Transforms

Multiple `transform: translateY(-1px)` rules in `mereka.scss` (lines 87, 298, 851) lack `@media (prefers-reduced-motion: no-preference)` guards. WCAG 2.1 SC 2.3.3 recommendation.

---

## 7. Low-Severity Issues

| # | Issue | File | Line(s) |
|---|-------|------|---------|
| LOW-1 | Duplicate `--mereka-teal/magenta/blue` aliases (legacy) | `_tokens.scss` | 48-50 |
| LOW-2 | `--mereka-color-indigo` is actually blue (#295cad) | `_tokens.scss` | 52 |
| LOW-3 | `brand-package.sh` theme sync path references non-existent dir | `brand-package.sh` | 8 |
| LOW-4 | `[class*="learning"]` selector overly broad | `mereka.scss` | 416 |

---

## 8. Correct Architecture (Target State)

### Current (Broken)
```
brand-mereka/                  ← SCSS dead, only logos used
  paragon/_variables.scss      ← DEAD (Ulmo ignores)
  paragon/fonts.scss           ← DEAD (Ulmo doesn't import)
  paragon/tokens.json          ← DEAD (wrong format)
  logo.svg, logo-white.svg     ← ACTIVE (MFE components import)

themes/mereka/
  scss/theme.scss              ← Imports tokens+fonts, PLUS 600 lines of LMS/Studio CSS
  scss/_tokens.scss            ← ACTIVE (CSS custom properties, this is the real theming)
  scss/_fonts.scss             ← ACTIVE (this is the real font loading)
  mfe/mereka.scss              ← ACTIVE (MFE BEM overrides, imports theme.scss + all LMS baggage)
  mfe/theme/*.css              ← DORMANT (PARAGON_THEME_URLS disabled)

Plugin injects:
  import './mereka/mereka.scss'  → compiles entire theme.scss + mereka.scss into every MFE
```

### Target (Clean)
```
brand-mereka/                  ← Asset container only
  paragon/_variables.scss      ← Keep for OEP-48 compliance, document as unused
  paragon/_fonts.scss           ← Rename from fonts.scss
  paragon/_overrides.scss      ← Create (empty file)
  paragon/images/card-imagecap-fallback.png  ← Create
  paragon/tokens.json          ← Keep placeholder, upgrade format in Phase C
  logo.svg, logo-trademark.svg ← Both present
  logo-white.svg               ← Present

themes/mereka/
  scss/_shared.scss            ← @import "fonts"; @import "tokens";  (shared by LMS + MFE)
  scss/_tokens.scss            ← CSS custom properties only (no style rules)
  scss/_fonts.scss             ← @font-face declarations
  scss/_base.scss              ← body, h1-h6, a, btn rules (moved from _tokens.scss 205-244)
  scss/_lms-studio.scss        ← LMS dashboard, courseware, Studio rules (NOT imported by MFE)
  scss/_mfe-footer.scss        ← Footer v2 CSS (imported by mereka.scss)
  scss/theme.scss              ← LMS entry: @import shared, base, lms-studio, mfe-footer
  mfe/mereka.scss              ← MFE entry: @import shared, base, mfe-footer, BEM overrides
  mfe/theme/
    mereka-brand.min.css       ← ONLY brand delta (~2KB), not full token dump
    core.min.css               ← CDN URL or properly sourced Paragon dist
    light.min.css              ← Light-variant deltas only, or remove if light-only
```

---

## 9. Prioritized Action Items

### Tier 1: CRITICAL (Fix before Phase C)

| # | Action | Files | Est. Effort |
|---|--------|-------|-------------|
| C1 | Create 4 missing OEP-48 files + update package.json exports | brand-mereka/ | 30 min |
| C2 | Split theme.scss — stop importing LMS/Studio CSS into MFEs | scss/theme.scss, mfe/mereka.scss | 2 hr |
| C3 | Move _tokens.scss lines 205-244 to separate partial | scss/_tokens.scss, scss/_base.scss | 30 min |

### Tier 2: HIGH (Fix during Phase C)

| # | Action | Files | Est. Effort |
|---|--------|-------|-------------|
| H1 | Remove duplicate `:root` block from theme.scss | scss/theme.scss | 15 min |
| H2 | Remove duplicate `.mereka-badge` from theme.scss | scss/theme.scss | 15 min |
| H3 | Remove or fix `exports` field in package.json | brand-mereka/package.json | 15 min |
| H4 | Regenerate mereka-brand.min.css as delta-only (~20 vars, not 847 lines) | mfe/theme/mereka-brand.min.css | 1 hr |
| H5 | Fix light.min.css — should not be identical to core.min.css | mfe/theme/light.min.css | 1 hr |

### Tier 3: MEDIUM (Fix during Phase C/D)

| # | Action | Files | Est. Effort |
|---|--------|-------|-------------|
| M1 | Rename fonts.scss → _fonts.scss in brand package | brand-mereka/paragon/ | 15 min |
| M2 | Create paragon/core.scss stub | brand-mereka/paragon/ | 15 min |
| M3 | Add build scripts to package.json | brand-mereka/package.json | 15 min |
| M4 | Add prefers-reduced-motion guards | mereka.scss | 30 min |
| M5 | Tighten peerDependencies version range | brand-mereka/package.json | 5 min |

### Tier 4: LOW (Cleanup)

| # | Action | Files |
|---|--------|-------|
| L1 | Remove `--mereka-teal/magenta/blue` aliases | _tokens.scss |
| L2 | Rename `--mereka-color-indigo` to `--mereka-color-blue` | _tokens.scss |
| L3 | Fix brand-package.sh theme source path | brand-package.sh |
| L4 | Document `[class*="learning"]` selector risk | mereka.scss |

---

## 10. Build Pipeline Verification Checklist

After all fixes, verify:

- [ ] `mereka.scss` does NOT import theme.scss (imports _shared.scss or _fonts + _tokens directly)
- [ ] `_tokens.scss` contains ONLY variable/property definitions (no style rules)
- [ ] `brand-mereka/` contains all 4 missing OEP-48 files
- [ ] `mereka-brand.min.css` < 5KB (delta only)
- [ ] `light.min.css` ≠ `core.min.css` (or light variant removed from PARAGON_THEME_URLS)
- [ ] No LMS/Studio selectors (`.dashboard`, `.courseware`, `.wrapper-view`) in MFE compiled CSS
- [ ] All CI verification scripts pass
- [ ] MFE image builds successfully with brand package installed

---

## 11. Follow-Up Research (2026-02-28 Phase C/D)

The following research was completed as a follow-up to this audit:

### Dead Selector Audit

**~60% of scoped `[class*="..."]` selectors in `mereka.scss` are phantom CSS.**

A DOM inspection of Ulmo MFEs revealed that most class-based wildcard selectors (lines 250-570)
match no actual DOM element. The remaining LIVE account scope was migrated to explicit
`.page__account-settings` (wildcard removed).

Full table: `docs/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md` §Dead Selector Audit.

### Paragon v22 Token Naming Gaps

Our `_tokens.scss` uses short-form names (e.g., `--pgn-color-primary`) while Paragon v22's
canonical names use longer forms (e.g., `--pgn-color-primary-base`). We define both forms
for colors, but border-radius and typography tokens are missing their canonical equivalents.

Full analysis: `docs/architecture/PARAGON_V22_TOKEN_AUDIT.md` §Token Naming Gap Analysis.

### FPF Plugin Slot Registry

98 plugin slots are available across all Ulmo MFEs. We currently use 4 (header logo, footer,
authn login, various brand surfaces). Key finding: the Learner Dashboard has 6 slots
including `course_card.v1` which could replace all dead dashboard card selectors.

Full inventory: `docs/architecture/FPF_PLUGIN_SLOT_REGISTRY.md`.

---

## 12. Sources

- [OEP-48: Brand Customization](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0048-brand-customization.html)
- [openedx/brand-openedx](https://github.com/openedx/brand-openedx) — reference implementation
- [Brand package changes not reflecting in Tutor Ulmo](https://discuss.openedx.org/t/brand-openedx-package-changes-not-reflecting-in-local-tutor-ulmo-setup/18484) — community confirmation that SCSS path is dead
- [Design tokens, Ulmo and tutor-indigo](https://discuss.openedx.org/t/design-tokens-ulmo-and-tutor-indigo/17724) — canonical discussion
- [Paragon v22→v23 design token migration](https://openedx.atlassian.net/wiki/spaces/BPL/pages/3770744958/Migrating+MFEs+to+Paragon+design+tokens+and+CSS+variables)
- [tutor-indigo plugin.py](https://github.com/overhangio/tutor-indigo/blob/release/tutorindigo/plugin.py) — reference PARAGON_THEME_URLS wiring
- [frontend-build webpack config](https://github.com/openedx/frontend-build/blob/master/config/webpack.prod.config.js)
- [Paragon example SCSS import order](https://github.com/openedx/paragon/blob/release-22.x/example/src/index.scss)
