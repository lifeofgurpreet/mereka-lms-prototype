# Frontend Phase A+B Audit — OEP-48 Compliance Review

**Date**: 2026-02-28
**Reviewer**: Opus (reviewer role)
**Scope**: Phase A (Foundation) + Phase B (Brand Foundation)
**Verdict**: CONDITIONAL PASS — 4 blocking gaps, 7 recommendations

---

## 1. Executive Summary

Phase A and B are functionally complete. The brand package works, tokens are consistent, mereka.scss uses var() references throughout, and CI verification scripts pass. However, the brand package is missing **4 mandatory OEP-48 files** that will cause build failures when MFEs attempt to import them.

**Blocking items must be resolved before Phase C starts.**

---

## 2. OEP-48 Mandatory File Checklist

| File | Required By | Status |
|------|------------|--------|
| `logo.svg` | MFE header component | PRESENT |
| `logo.png` | Fallback/email | PRESENT |
| `logo-white.svg` | Dark backgrounds | PRESENT |
| `logo-white.png` | Fallback | PRESENT |
| `favicon.ico` | Browser tab | PRESENT |
| `paragon/_variables.scss` | Paragon SCSS pipeline | PRESENT |
| `paragon/fonts.scss` | @font-face declarations | PRESENT |
| `paragon/tokens.json` | Paragon token build | PRESENT |
| `paragon/_overrides.scss` | MFE webpack (unconditional import) | **MISSING** |
| `paragon/images/card-imagecap-fallback.png` | Paragon Card.ImageCap | **MISSING** |
| `logo-trademark.svg` | Legal/trademark display | **MISSING** |
| `logo-trademark.png` | Fallback | **MISSING** |

### Impact of Missing Files

- **`_overrides.scss`**: MFE webpack config imports `@edx/brand/paragon/_overrides.scss` unconditionally. If absent, the build may fail or silently skip brand overrides depending on the webpack resolve configuration. **Create as empty file at minimum.**
- **`card-imagecap-fallback.png`**: Paragon's `Card.ImageCap` component references this as a fallback. Missing = broken image icon on cards without images.
- **`logo-trademark.svg/png`**: Used by footer and legal pages. Missing = broken image or React error boundary.

---

## 3. Package.json Review

**File**: `infrastructure/tutor/brand-mereka/package.json`

### Current State
```json
{
  "name": "@edx/brand-mereka",
  "version": "1.0.0",
  "exports": {
    "./logo.svg": "./logo.svg",
    "./logo-white.svg": "./logo-white.svg",
    "./logo.png": "./logo.png",
    "./logo-white.png": "./logo-white.png",
    "./favicon.ico": "./favicon.ico",
    "./paragon/fonts.scss": "./paragon/fonts.scss",
    "./paragon/_variables.scss": "./paragon/_variables.scss",
    "./paragon/tokens.json": "./paragon/tokens.json"
  }
}
```

### Issues

| # | Severity | Issue |
|---|----------|-------|
| 1 | BLOCKING | Missing export: `./paragon/_overrides.scss` (MFE webpack imports this) |
| 2 | BLOCKING | Missing export: `./paragon/images/card-imagecap-fallback.png` |
| 3 | BLOCKING | Missing exports: `./logo-trademark.svg`, `./logo-trademark.png` |
| 4 | LOW | No `"."` root export (reference brand-openedx has it) |
| 5 | LOW | `"main": "package.json"` is unusual — reference uses `"main": "package.json"` too, so acceptable |

---

## 4. tokens.json Format Review

**File**: `infrastructure/tutor/brand-mereka/paragon/tokens.json`

### Current Format (Custom/Flat)
```json
{
  "_comment": "placeholder tokens...",
  "colors": { "primary": "#ab3b78" },
  "typography": { "font-family-sans-serif": "..." }
}
```

### DTCG Format (What Paragon v23+ expects)
```json
{
  "color": {
    "primary": {
      "$value": "#ab3b78",
      "$type": "color",
      "$description": "Primary brand color (magenta)"
    }
  }
}
```

### Assessment

- **Not blocking for Tutor v21 / Paragon v22**: Current Paragon version consumes `_variables.scss`, not `tokens.json` for theming. The tokens.json is a placeholder.
- **Will block Paragon v23+ migration**: When Paragon switches to CSS-variable-first theming via `build-tokens` CLI, this format won't parse.
- **Recommendation**: Leave as-is for now. Phase C's paragon-design-tokens-migration spec handles the format upgrade. The `_comment` field documents this intent.

**Verdict**: NON-BLOCKING (deferred to spec)

---

## 5. _variables.scss Review

**File**: `infrastructure/tutor/brand-mereka/paragon/_variables.scss`

### Findings

| Check | Result |
|-------|--------|
| Color values match _tokens.scss | PASS — `$primary: #ab3b78`, `$secondary: #237072` match exactly |
| Font stacks match _tokens.scss | PASS — Poppins (body), Lato (headings) |
| `!default` flag on all variables | PASS — all 12 variables use `!default` |
| Pill button radius (9999px) | PASS — matches brand intent |
| Link colors consistent | PASS — `$link-color: #295cad` = `$color-info`, `$link-hover-color: #237072` = `$color-teal` |

**Verdict**: PASS — no issues

---

## 6. _tokens.scss Review

**File**: `infrastructure/tutor/themes/mereka/scss/_tokens.scss` (243 lines)

### Structure

- Lines 1–183: `// BEGIN GENERATED` block — auto-generated CSS custom properties + SCSS variables
- Line 183: `// END GENERATED`
- Lines 185–203: SCSS Bootstrap variable overrides (body, link, primary, etc.)
- Lines 205–244: **Manual CSS rules** (body, h1-h6, a, .btn-primary, .card)

### Findings

| # | Severity | Finding |
|---|----------|---------|
| 1 | MEDIUM | Lines 205–244 contain CSS rules (body, h1-h6, a, .btn-primary, .card) OUTSIDE the generated block. If `generate-tokens-from-canonical.sh` is run, it will overwrite lines 1–183 but lines 185–244 survive. However, if the script is ever changed to overwrite the entire file, these rules are lost. |
| 2 | LOW | Lines 48–50 duplicate color vars: `--mereka-teal`, `--mereka-magenta`, `--mereka-blue` duplicate `--mereka-color-teal`, etc. Legacy aliases — not harmful but add noise. |
| 3 | LOW | `--mereka-color-indigo` (line 52) is an alias for `$color-blue` — naming mismatch (indigo ≠ blue). The hex value `#295cad` is blue, not indigo. |

### Color Consistency Cross-Check

| Color | tokens.css | _tokens.scss | _variables.scss | tokens.json | Match? |
|-------|-----------|-------------|----------------|-------------|--------|
| Magenta | #ab3b78 | #ab3b78 | #ab3b78 | #ab3b78 | PASS |
| Teal | #237072 | #237072 | #237072 | #237072 | PASS |
| Blue | #295cad | #295cad | #295cad | #295cad | PASS |
| Forest | #2c6e49 | #2c6e49 | #2c6e49 | #2c6e49 | PASS |
| Gold | #f4be48 | #f4be48 | #f4be48 | #f4be48 | PASS |
| Burgundy | #8c002f | #8c002f | #8c002f | #8c002f | PASS |

### RGB Value Consistency

| Color | Hex | RGB in _tokens.scss | Calculated | Match? |
|-------|-----|---------------------|------------|--------|
| Teal | #237072 | 35 112 114 | 35 112 114 | PASS |
| Magenta | #ab3b78 | 171 59 120 | 171 59 120 | PASS |
| Blue | #295cad | 41 92 173 | 41 92 173 | PASS |
| Forest | #2c6e49 | 44 110 73 | 44 110 73 | PASS |
| Gold | #f4be48 | 244 190 72 | 244 190 72 | PASS |
| Burgundy | #8c002f | 140 0 47 | 140 0 47 | PASS |

**Verdict**: PASS — all values consistent across all 4 source files

---

## 7. mereka.scss Review

**File**: `infrastructure/tutor/themes/mereka/mfe/mereka.scss` (580 lines)

### Positive Findings

1. **Zero hardcoded hex values** — All colors use `var(--mereka-*)` or `var(--pgn-*)` tokens
2. **RISK annotations on every selector** — LOW/MEDIUM/HIGH classification
3. **SELECTOR-EXCEPTION markers** with expiration dates (2026-Q3)
4. **Removed selectors documented** — `[data-testid*=]` and `[class*="auth-page"]` removals noted
5. **Graceful degradation** — All overrides degrade visually (not functionally) on selector rename
6. **Responsive rules present** — Mobile navbar padding at 768px breakpoint

### Selector Risk Assessment

| Risk Level | Count | Examples |
|-----------|-------|---------|
| LOW | ~28 | `:root`, `body`, `.btn-primary:hover`, `.mereka-badge`, alert variants |
| MEDIUM | ~12 | `.navbar .nav-link`, `.pgn__form-control`, `.card`, `.pgn__modal-content` |
| HIGH | ~10 | `[class*="authn"]`, `[class*="learning"]`, `[class*="learner-dashboard"]` |

### Issues

| # | Severity | Finding |
|---|----------|---------|
| 1 | MEDIUM | `[class*="learning"]` (line 416) is overly broad — matches any element with "learning" anywhere in any class name. Could accidentally style `<div class="e-learning-promo">`. No practical alternative until upstream adds a slot. |
| 2 | LOW | `transform: translateY(-1px)` on button hover (line 87) not gated behind `@media (prefers-reduced-motion: no-preference)`. WCAG 2.1 SC 2.3.3 recommendation. |
| 3 | INFO | Lines 453–463 use `:is()` with `[class*="image-cap"], [class*="imagecap"], [class*="image"], [class*="media"]` — defensive multi-match. Correct approach given Paragon version variance. |

### Architecture Assessment

The file follows a clear pattern:
1. **Global resets** (body, :root) — safe, stable
2. **Bootstrap/Paragon BEM overrides** (buttons, forms, cards, alerts, modals) — semi-stable
3. **Scoped surface overrides** (authn, account, dashboard, learning, discussions) — brittle but documented with expiration dates
4. **Custom classes** (.mereka-badge, .mereka-header-logo) — fully controlled, safe

This is well-structured for Phase C's token grounding work. The SELECTOR-EXCEPTION markers give the implementor clear targets for slot migration in Phase D.

**Verdict**: PASS — well-documented, token-referenced, risk-annotated

---

## 8. brand-package.sh Review

**File**: `infrastructure/tutor/patches/brand-package.sh`

### Issue

Line 8 references `themes/mereka/mfe/theme/` as the theme source directory:
```bash
local THEME_SOURCE_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/theme"
```

This directory does not exist. The actual MFE stylesheet is at `themes/mereka/mfe/mereka.scss`.

**Impact**: The theme sync portion of the patch always skips with "source not found" message. The brand-mereka copy (lines 21–23) works correctly.

**Assessment**: NON-BLOCKING for Phase A/B. The brand package is installed via `npm install @edx/brand@file:./brand-mereka` in the MFE Dockerfile (handled by the Tutor plugin). The theme CSS is imported via `@import` in `mereka.scss`, not copied as compiled CSS. This script's theme sync is a Phase C/D concern (runtime CDN theming via PARAGON_THEME_URLS).

**Verdict**: NON-BLOCKING — deferred to Phase C/D

---

## 9. fonts.scss Review

**File**: `infrastructure/tutor/brand-mereka/paragon/fonts.scss`

| Check | Result |
|-------|--------|
| All 9 font variants declared | PASS (Poppins: Regular/SemiBold/Bold, Lato: Regular/Bold/Black + Italic variants) |
| `font-display: swap` on all | PASS |
| Relative paths (`../fonts/`) correct | PASS |
| woff2 format specified | PASS |
| Font files exist in `fonts/` directory | PASS (9 .woff2 files) |

**Verdict**: PASS

---

## 10. Action Items (Prioritized)

### BLOCKING (Must fix before Phase C)

| # | Item | Owner | Files |
|---|------|-------|-------|
| B1 | Create `paragon/_overrides.scss` (empty file with header comment) | Implementor | `brand-mereka/paragon/_overrides.scss` |
| B2 | Create `paragon/images/card-imagecap-fallback.png` | Implementor | `brand-mereka/paragon/images/card-imagecap-fallback.png` |
| B3 | Create `logo-trademark.svg` and `logo-trademark.png` (copy from logo.svg/png if no trademark variant exists) | Implementor | `brand-mereka/logo-trademark.svg`, `brand-mereka/logo-trademark.png` |
| B4 | Add missing exports to `package.json` | Implementor | `brand-mereka/package.json` |

### RECOMMENDED (Should fix during Phase C)

| # | Item | Priority | Files |
|---|------|----------|-------|
| R1 | Move CSS rules from _tokens.scss lines 205–244 into a separate `_base.scss` or into mereka.scss LMS scope | MEDIUM | `themes/mereka/scss/_tokens.scss` |
| R2 | Add `@media (prefers-reduced-motion: no-preference)` guard to `transform: translateY(-1px)` hover | LOW | `themes/mereka/mfe/mereka.scss:87` |
| R3 | Remove duplicate `--mereka-teal/magenta/blue` aliases (lines 48–50 of _tokens.scss) | LOW | `themes/mereka/scss/_tokens.scss` |
| R4 | Rename `--mereka-color-indigo` to `--mereka-color-blue` (or document why indigo) | LOW | `themes/mereka/scss/_tokens.scss` |
| R5 | Fix brand-package.sh theme source path (Phase C/D) | LOW | `infrastructure/tutor/patches/brand-package.sh` |
| R6 | Add `"."` root export to package.json | LOW | `brand-mereka/package.json` |
| R7 | Upgrade tokens.json to DTCG format (deferred to paragon-design-tokens-migration spec) | LOW | `brand-mereka/paragon/tokens.json` |

---

## 11. Verification Scripts Status

All Phase A/B verification scripts pass:

| Script | Checks | Status |
|--------|--------|--------|
| `verify-theme-consistency.sh` | 13 | PASS |
| `verify-token-reference-integrity.sh` | 15+ | PASS |
| `verify-token-generation-pipeline.sh` | 7+ | PASS |
| `verify-mfe-branding.sh` | 56 | PASS |
| `verify-mfe-route-drift.sh` | 32 | PASS |

Note: These scripts do not check for the 4 missing mandatory files (they verify what exists, not what's missing). A new check should be added to `verify-mfe-branding.sh` to assert OEP-48 mandatory file presence.

---

## 12. Conclusion

Phase A+B implementation is **solid and well-documented**. The codebase shows disciplined use of design tokens, risk annotations, and selector exception tracking. The 4 blocking gaps are straightforward to fix (create files, update exports). Once addressed, Phase C can proceed safely.

The `mereka.scss` architecture is mature — zero hardcoded hex, comprehensive risk classification, and clear Phase D slot migration targets. The token pipeline (`tokens.css → _tokens.scss → _variables.scss → tokens.json`) is consistent across all 4 files with no value drift.
