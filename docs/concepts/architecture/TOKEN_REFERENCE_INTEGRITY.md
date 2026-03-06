# Token Reference Integrity Contract

**Purpose**: Ensure zero undefined CSS custom property or SCSS variable references in Mereka theme files.

**Status**: ACTIVE
**Last verified**: 2026-02-17
**Acceptance Criteria**: AC-UITKN-001 through AC-UITKN-004

---

## Scope

This contract governs all files under `infrastructure/tutor/themes/mereka/`:

- SCSS files: `scss/*.scss`, `mfe/*.scss`
- CSS files: `*/static/css/*.css`
- Coverage: LMS, CMS, and all MFE theme overrides

**Out of scope**: Third-party libraries, node_modules, generated vendor CSS.

---

## Token Definition Sources

Token definitions are spread across three layers:

### Layer 1: Canonical Design Tokens (Read-Only)
**File**: `assets/branding/tokens.css`
**Source**: Figma design system (synced via automation)
**Count**: 189 properties (as of 2026-02-17)
**Prefix**: `--color-*`, `--font-*`, `--space-*`, `--radius-*`, `--shadow-*`, `--avatar-*`, `--icon-*`, `--button-*`, `--gray-*`, `--text-*`, `--leading-*`, `--duration-*`, `--ease-*`, `--breakpoint-*`, `--container-*`, `--z-*`

### Layer 2: Mereka Token Bridge (SCSS → CSS)
**File**: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
**Purpose**: Bridge canonical tokens into SCSS variables + CSS custom properties for LMS/CMS/MFEs
**Count**:
  - 24 SCSS variables (`$color-*`, `$mereka-*`)
  - 37 CSS custom properties (`:root { --mereka-*, --pgn-* }`)

### Layer 3: Runtime CSS Overrides
**Files**:
  - `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css`
  - `infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css`
  - `infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css`

**Purpose**: Runtime-injected CSS (loaded via `head-extra.html`) that defines additional tokens and canonical Paragon bridges.

---

## Reference Integrity Rules

### AC-UITKN-001: All `var(--mereka-*)` References Resolve

**Rule**: Every `var(--mereka-*)` reference in theme SCSS/CSS must resolve to a `:root` definition in one of:
  - `scss/_tokens.scss` `:root` block
  - `mereka-overrides.css` `:root` block (LMS or CMS variant)
  - Self-defined in the same file

**Example violations**:
```css
/* BAD: --mereka-unknown-token never defined */
.course-card {
  color: var(--mereka-unknown-token);
}
```

**Example compliant**:
```css
/* GOOD: --mereka-color-teal defined in _tokens.scss */
.course-card {
  color: var(--mereka-color-teal);
}
```

### AC-UITKN-002: All SCSS Variable References Resolve

**Rule**: Every SCSS variable reference (`$color-*`, `$mereka-*`) must resolve to a declaration in `_tokens.scss`.

**Example violations**:
```scss
/* BAD: $color-unknown never declared */
.btn-primary {
  background: $color-unknown;
}
```

**Example compliant**:
```scss
/* GOOD: $color-magenta declared in _tokens.scss */
.btn-primary {
  background: $color-magenta;
}
```

### AC-UITKN-003: Cross-File Token Value Consistency

**Rule**: Token names must have identical hex values across all definition files.

**Example violations**:
```scss
/* _tokens.scss */
:root {
  --mereka-color-teal: #237072;
}

/* lms/static/css/mereka-overrides.css */
:root {
  --mereka-color-teal: #FFFFFF; /* VIOLATION: value drift */
}
```

**Resolution**: Update `mereka-overrides.css` to match canonical value from `_tokens.scss` or document as intentional override with comment.

**Known intentional overrides**: None currently documented.

### AC-UITKN-004: CI Gate Blocks Undefined Token References

**Rule**: CI must fail if any undefined token references are detected.

**CI Integration**: `.github/workflows/ci.yml` → `monitoring-guardrails` job runs `scripts/qa/verify-token-reference-integrity.sh`.

**Exit code**: 0 on success, 1 if FAIL count > 0.

---

## Token Inventory

### SCSS Variables (24 total)

**Color primitives** (10):
- `$color-ink-900`, `$color-ink-700`, `$color-ink-500`, `$color-ink-300`
- `$color-neutral-100`, `$color-neutral-75`
- `$color-border`, `$color-border-strong`
- `$color-teal`, `$color-magenta`, `$color-blue`, `$color-sky`
- `$color-forest`, `$color-gold`, `$color-burgundy`, `$color-pink`

**Semantic aliases** (6):
- `$color-info`, `$color-info-soft`
- `$color-success`
- `$color-warning`
- `$color-danger`, `$color-danger-soft`

**Typography** (2):
- `$mereka-body-font`
- `$mereka-heading-font`

**Bootstrap overrides** (6):
- `$font-family-sans-serif`, `$font-family-base`
- `$headings-font-family`, `$headings-font-weight`
- `$body-color`, `$body-bg`
- `$link-color`, `$link-hover-color`
- `$primary`, `$secondary`, `$success`, `$info`, `$warning`, `$danger`
- `$border-color`
- `$btn-border-radius`, `$btn-border-radius-lg`, `$btn-border-radius-sm`

### CSS Custom Properties (37 total)

**Mereka namespace** (`--mereka-*`, 18 properties):
- `--mereka-font-body`, `--mereka-font-heading`
- `--mereka-color-ink-900`, `--mereka-color-ink-700`, `--mereka-color-ink-500`, `--mereka-color-ink-300`
- `--mereka-color-teal`, `--mereka-color-magenta`, `--mereka-color-blue`, `--mereka-color-sky`
- `--mereka-color-surface-primary`, `--mereka-color-surface-secondary`
- `--mereka-color-border`, `--mereka-color-border-strong`
- `--mereka-color-info`, `--mereka-color-info-soft`
- `--mereka-color-success`, `--mereka-color-warning`
- `--mereka-color-danger`, `--mereka-color-danger-soft`
- `--mereka-shadow-card`

**Paragon bridge** (`--pgn-*`, 13 properties):
- `--pgn-color-primary-base`, `--pgn-color-secondary-base`, `--pgn-color-success-base`, `--pgn-color-info-base`, `--pgn-color-warning-base`, `--pgn-color-danger-base`
- `--pgn-body-bg`, `--pgn-body-color`
- `--pgn-link-color`, `--pgn-link-hover-color`
- `--pgn-typography-font-family-sans-serif`, `--pgn-typography-headings-font-family`
- `--pgn-border-color`, `--pgn-border-color-translucent`
- `--pgn-btn-border-radius`

**Additional runtime tokens** (defined in `mereka-overrides.css`, 2 properties):
- `--mereka-branding-rev` (version tracking)
- `--mereka-gradient-primary` (gradient effect)

---

## Known Gaps

### Intentionally Undefined References

None currently documented. All token references must resolve.

### Future Token Additions

When adding new tokens:

1. **If canonical design token**: Add to `assets/branding/tokens.css` (synced from Figma)
2. **If Mereka-specific**: Add to `_tokens.scss` `:root` block
3. **If runtime override**: Add to `mereka-overrides.css` `:root` block with comment explaining purpose
4. **Always**: Run `scripts/qa/verify-token-reference-integrity.sh` before committing

### Token Deprecation

When removing tokens:

1. Search for all references: `grep -r "var(--token-name)" infrastructure/tutor/themes/mereka/`
2. Replace with new token or hardcoded value (if intentional one-off)
3. Remove definition from source file
4. Verify with `scripts/qa/verify-token-reference-integrity.sh`

---

## MFE Coverage

### Token Consumption by MFE

| MFE | Token Subset | File |
|-----|--------------|------|
| authn | Typography, colors (primary, secondary, info, danger), border radius | `mfe/mereka.scss` |
| account | Typography, colors (all semantic), borders | `mfe/mereka.scss` |
| learning | Typography, colors (all), shadows, gradients | `mfe/mereka.scss` |
| profile | Typography, colors (primary, secondary), borders | `mfe/mereka.scss` |
| discussions | Typography, colors (all semantic), shadows | `mfe/mereka.scss` |
| gradebook | Typography, colors (primary, info, warning, danger) | `mfe/mereka.scss` |
| learner-dashboard | Typography, colors (all), shadows, gradients | `mfe/mereka.scss` |
| communications | Typography, colors (primary, info) | `mfe/mereka.scss` |
| ora-grading | Typography, colors (all semantic) | `mfe/mereka.scss` |
| authoring | Typography, colors (primary, secondary, info, danger), borders | `mfe/mereka.scss` |
| course-authoring | Typography, colors (primary, secondary, info, danger), borders | `mfe/mereka.scss` |

**Note**: All MFEs consume Paragon bridge tokens (`--pgn-*`) via `mfe/mereka.scss`.

---

## Verification

### Manual Verification

```bash
# Run token reference integrity checker
./scripts/qa/verify-token-reference-integrity.sh

# Expected output (example):
# === Token Reference Integrity Check ===
#
# --- Token definitions ---
#   Found 37 --mereka-* definitions
#   Found 13 --pgn-* definitions
#   Found 24 SCSS variables
#
# --- Token references ---
#   PASS  All 124 var(--mereka-*) references resolve
#   PASS  All 47 var(--pgn-*) references resolve
#   PASS  All 89 SCSS variable references resolve
#
# --- Cross-file consistency ---
#   PASS  --mereka-color-teal: 1 definition, 1 unique value
#   PASS  --mereka-color-magenta: 1 definition, 1 unique value
#   ...
#
# === Results: 45 PASS / 0 FAIL / 0 WARN ===
```

### CI Enforcement

The CI job `monitoring-guardrails` in `.github/workflows/ci.yml` runs:

```bash
bash -n scripts/qa/verify-token-reference-integrity.sh  # syntax check
```

**Exit criteria**: CI fails if FAIL count > 0.

---

## Cross-File Value Consistency

### Canonical Values (as of 2026-02-25)

**Colors** (must match across _tokens.scss and mereka-overrides.css):

| Token | Hex Value | Source |
|-------|-----------|--------|
| `--mereka-color-teal` | `#237072` | _tokens.scss (canonical) — RESOLVED 2026-02-25 |
| `--mereka-color-teal` | `#237072` | mereka-overrides.css (LMS+CMS) — RESOLVED 2026-02-25 |
| `--mereka-color-ink-500` | `#6B6B6B` | _tokens.scss (canonical) — RESOLVED 2026-02-25 |
| `--mereka-color-ink-500` | `#6B6B6B` | mereka-overrides.css (LMS+CMS) — RESOLVED 2026-02-25 |
| `--mereka-color-magenta` | `#ab3b78` | _tokens.scss (canonical) |
| `--mereka-color-magenta` | `#ab3b78` | mereka-overrides.css (LMS+CMS) |
| `--mereka-color-blue` | `#295cad` | _tokens.scss (canonical) |
| `--mereka-color-blue` | `#295cad` | mereka-overrides.css (LMS+CMS) |
| `--mereka-color-sky` | `#94d1e4` | _tokens.scss (canonical) |
| `--mereka-color-sky` | `#94d1e4` | mereka-overrides.css (LMS+CMS) |
| `--mereka-color-ink-900` | `#000000` | _tokens.scss (canonical) |
| `--mereka-color-ink-900` | `#000000` | mereka-overrides.css (LMS+CMS) |
| `--mereka-color-ink-700` | `#4A494A` | _tokens.scss (canonical) |
| `--mereka-color-ink-700` | `#4A494A` | mereka-overrides.css (LMS+CMS) |

**Known drift**: None. All layers are now aligned. Historical drift (before 2026-02-25): teal was `#297F81` (SCSS) vs `#2d898b` (runtime); ink-500 was `#737373` (SCSS) vs `#7B7B7B` (runtime). Both resolved by unifying to WCAG AA-compliant values.

---

## Maintenance Workflow

### Adding New Tokens

1. **Choose layer**:
   - Canonical (Figma) → `assets/branding/tokens.css`
   - Mereka-specific → `_tokens.scss`
   - Runtime override → `mereka-overrides.css`

2. **Add definition**:
   - SCSS: `$new-token: value;` in `_tokens.scss`
   - CSS: `--mereka-new-token: value;` in `:root` block

3. **Bridge to CSS** (if SCSS):
   ```scss
   :root {
     --mereka-new-token: #{$new-token};
   }
   ```

4. **Verify**:
   ```bash
   ./scripts/qa/verify-token-reference-integrity.sh
   ```

5. **Document**: Update token inventory in this file.

### Refactoring Existing Tokens

1. **Search for references**:
   ```bash
   grep -rn "var(--old-token)" infrastructure/tutor/themes/mereka/
   grep -rn "\$old-token" infrastructure/tutor/themes/mereka/
   ```

2. **Replace references** with new token name.

3. **Remove old definition** (or alias to new token for backwards compatibility).

4. **Verify**:
   ```bash
   ./scripts/qa/verify-token-reference-integrity.sh
   ```

---

## Acceptance Criteria Verification

| AC | Requirement | Verification Method |
|----|-------------|---------------------|
| AC-UITKN-001 | All `var(--mereka-*)` references resolve | `verify-token-reference-integrity.sh` checks all SCSS/CSS files for undefined references |
| AC-UITKN-002 | All SCSS `$variable` references resolve | Script extracts all `$color-*`, `$mereka-*` references and checks against `_tokens.scss` declarations |
| AC-UITKN-003 | Cross-file token value consistency | Script extracts hex values for same token name across files, reports duplicates with different values |
| AC-UITKN-004 | CI gate blocks undefined references | `.github/workflows/ci.yml` → `monitoring-guardrails` job runs verifier, fails on FAIL > 0 |

**Last AC verification**: 2026-02-17
**Next review**: On any token addition/removal/refactor

---

## Related Documentation

- **Design Token Spec**: `specs/design-tokens.md` (AC-UITKN-001..012)
- **Frontend Audit Checklist**: `../qa/reports/FRONTEND_AUDIT_CHECKLIST.md` (Design Token Bridge section)
- **Token Bridge Implementation**: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
- **Canonical Tokens**: `assets/branding/tokens.css`
- **Provenance Tracking**: `assets/branding/tokens.provenance.json`

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-17 | Initial contract creation (AC-UITKN-001..004) | Agent-1 (bead mereka-lms-115d.1) |
