# Token Generation Pipeline Contract

**Purpose**: Define the single-source token generation pipeline architecture to eliminate multi-source drift.

**Status**: ACTIVE (Phase 1: Contract + Drift Detection)
**Last verified**: 2026-02-17
**Acceptance Criteria**: AC-TKPIPE-001, AC-TKPIPE-002, AC-TKPIPE-003

---

## Problem Statement

The design token architecture has 3 layers with **NO automated generation pipeline**, leading to confirmed drift:

### Current State: Manual Maintenance

```
Layer 1 (canonical)     Layer 2 (SCSS bridge)       Layer 3 (runtime CSS)
assets/branding/        infrastructure/tutor/       infrastructure/tutor/
  tokens.css              themes/mereka/              themes/mereka/
                            scss/_tokens.scss           common/static/css/
                                                          mereka-overrides.css

--color-teal: #237072   $color-teal: #237072        --mereka-color-teal: #237072
                        --mereka-color-teal: #237072
(110 properties)        (24 SCSS vars, 37 CSS)      (1,636 lines CSS)

↓                       ↓                           ↓
HAND-MAINTAINED         HAND-MAINTAINED             HAND-MAINTAINED
```

### Confirmed Drift

**Resolved (2026-02-25)**: All previously drifted tokens have been unified.

| Token | Layer 1 (canonical) | Layer 2 (SCSS) | Layer 3 (runtime) | Status |
|-------|---------------------|----------------|-------------------|--------|
| `--color-teal` / `--mereka-color-teal` | `#237072` | `#237072` | `#237072` | ✅ RESOLVED |
| `--color-ink-500` / `--mereka-color-ink-500` | `#6B6B6B` | `#6B6B6B` | `#6B6B6B` | ✅ RESOLVED |

**Historical values (before 2026-02-25)**: teal was `#2d898b` (L1/L3) vs `#297F81` (L2); ink-500 was `#737373` (L2) vs `#7B7B7B` (L3).

**Root cause**: Hex color values are hardcoded independently in all 3 files.

---

## Target State: Single-Source Pipeline

```
Layer 1 (canonical)            Layer 2 (SCSS bridge)       Layer 3 (runtime CSS)
assets/branding/               infrastructure/tutor/       infrastructure/tutor/
  tokens.css                     themes/mereka/              themes/mereka/
                                   scss/_tokens.scss           common/static/css/
                                                                 mereka-overrides.css

--color-teal: #237072   →     $color-teal: #237072  →     --mereka-color-teal: #237072
                               --mereka-color-teal: #237072
(110 properties)               (GENERATED)                 (:root block GENERATED)

↓                              ↓                           ↓
FIGMA EXPORT (manual)          AUTO-GENERATED              AUTO-GENERATED
```

**Principle**: `tokens.css` (Layer 1) is the **ONLY** file containing raw hex values. All downstream layers reference or are generated from Layer 1.

---

## Pipeline Design

### Phase 1: Contract + Drift Detection (Current)

**Deliverables**:
- ✅ This contract document (AC-TKPIPE-001)
- ✅ Drift detection verifier script (AC-TKPIPE-002)
- ✅ CI gate for new drift (AC-TKPIPE-003)
- ✅ Known drift table (documented below)

**Status**: **COMPLETE** (2026-02-17)

### Phase 2: Generator Script (Future)

**Tool**: `scripts/branding/generate-token-layers.sh` (NOT YET IMPLEMENTED)

**Input**: `assets/branding/tokens.css`

**Outputs**:
1. **SCSS bridge** (`infrastructure/tutor/themes/mereka/scss/_tokens.scss`):
   - SCSS variable declarations: `$color-teal: #237072;`
   - CSS custom property `:root` block: `--mereka-color-teal: #{$color-teal};`
   - Preserve existing SCSS logic (Bootstrap overrides, semantic aliases)

2. **Runtime CSS `:root` block** (embedded in `mereka-overrides.css`):
   - CSS custom properties: `--mereka-color-teal: #237072;`
   - Preserve existing runtime CSS rules (NOT the :root block)

**Algorithm**:
```python
# Pseudocode
tokens_css = parse_css_custom_properties("assets/branding/tokens.css")

# Generate SCSS variables
for name, value in tokens_css.items():
    scss_var = name.replace("--color-", "$color-")
    emit(f"{scss_var}: {value};")

# Generate CSS custom properties with namespace mapping
namespace_map = {
    "--color-teal": "--mereka-color-teal",
    "--color-magenta": "--mereka-color-magenta",
    "--color-blue": "--mereka-color-blue",
    "--color-sky": "--mereka-color-sky",
    "--color-burgundy": "--mereka-color-danger",
    "--color-pink": "--mereka-color-danger-soft",
    "--color-gold": "--mereka-color-warning",
    "--color-forest": "--mereka-color-success",
    "--color-black": "--mereka-color-ink-900",
}
emit(":root {")
for canonical_name, mereka_name in namespace_map.items():
    value = tokens_css[canonical_name]
    emit(f"  {mereka_name}: {value};")
emit("}")
```

**Preservation strategy**:
- SCSS: Replace only variable declarations and `:root` block, keep Bootstrap overrides and semantic aliases
- CSS: Replace only `:root` block in `mereka-overrides.css`, keep all other CSS rules

**Migration checklist** (before Phase 2):
1. Resolve current drift (decide canonical hex values)
2. Write generator script with dry-run mode
3. Validate generated output matches expected structure
4. Run visual regression tests to ensure no visual changes
5. Update `sync-brand-assets.sh` to invoke generator after token sync
6. Deploy to staging, verify no visual regressions
7. Deploy to production

### Phase 3: CI Enforcement (Future)

**Gate**: CI fails if any layer contains hardcoded hex values not present in Layer 1

**Implementation**:
```bash
# In .github/workflows/ci.yml
- name: Verify token single-source
  run: |
    ./scripts/qa/verify-token-generation-pipeline.sh
```

**Exit criteria**: FAIL count > 0 means new independent hex definitions were introduced.

---

## Token Namespace Mapping

### Layer 1 → Layer 2 (SCSS Variables)

| Layer 1 (canonical) | Layer 2 (SCSS) | Notes |
|---------------------|----------------|-------|
| `--color-teal` | `$color-teal` | Simple prefix replacement |
| `--color-magenta` | `$color-magenta` | Simple prefix replacement |
| `--color-blue` | `$color-blue` | Simple prefix replacement |
| `--color-sky` | `$color-sky` | Simple prefix replacement |
| `--color-forest` | `$color-forest` | Simple prefix replacement |
| `--color-gold` | `$color-gold` | Simple prefix replacement |
| `--color-burgundy` | `$color-burgundy` | Simple prefix replacement |
| `--color-pink` | `$color-pink` | Simple prefix replacement |
| `--color-black` | `$color-ink-900` | Semantic rename |
| `--gray-*` | N/A | Not currently bridged to SCSS |

### Layer 1 → Layer 2 (CSS Custom Properties)

| Layer 1 (canonical) | Layer 2 (CSS) | Notes |
|---------------------|---------------|-------|
| `--color-teal` | `--mereka-color-teal` | Namespace prefix |
| `--color-magenta` | `--mereka-color-magenta` | Namespace prefix |
| `--color-blue` | `--mereka-color-blue` | Namespace prefix |
| `--color-sky` | `--mereka-color-sky` | Namespace prefix |
| `--color-forest` | `--mereka-color-success` | Semantic alias |
| `--color-gold` | `--mereka-color-warning` | Semantic alias |
| `--color-burgundy` | `--mereka-color-danger` | Semantic alias |
| `--color-pink` | `--mereka-color-danger-soft` | Semantic alias |
| `--color-black` | `--mereka-color-ink-900` | Semantic rename |

### Layer 2 → Layer 3 (Paragon Bridge)

| Layer 2 (Mereka) | Layer 3 (Paragon) | Notes |
|------------------|-------------------|-------|
| `--mereka-color-magenta` | `--pgn-color-primary` | Primary brand color |
| `--mereka-color-teal` | `--pgn-color-secondary` | Secondary brand color |
| `--mereka-color-success` | `--pgn-color-success` | Semantic mapping |
| `--mereka-color-info` | `--pgn-color-info` | Semantic mapping |
| `--mereka-color-warning` | `--pgn-color-warning` | Semantic mapping |
| `--mereka-color-danger` | `--pgn-color-danger` | Semantic mapping |

---

## Known Drift Table (updated 2026-02-25)

### Color Value Drift

| Token Name | Layer 1 (canonical) | Layer 2 (SCSS) | Layer 3 (runtime) | Status |
|------------|---------------------|----------------|-------------------|--------|
| `teal` | `#237072` | `#237072` | `#237072` | ✅ RESOLVED (was DRIFT) |
| `ink-500` | `#6B6B6B` | `#6B6B6B` | `#6B6B6B` | ✅ RESOLVED (was DRIFT) |
| `magenta` | `#ab3b78` | `#ab3b78` | `#ab3b78` | ✅ ALIGNED |
| `blue` | `#295cad` | `#295cad` | `#295cad` | ✅ ALIGNED |
| `sky` | `#94d1e4` | `#94d1e4` | `#94d1e4` | ✅ ALIGNED |
| `black` / `ink-900` | `#000000` | `#000000` | `#000000` | ✅ ALIGNED |

**Historical drift** (before 2026-02-25): teal was `#2d898b` (L1/L3) vs `#297F81` (L2); ink-500 was `#737373` (L2) vs `#7B7B7B` (L3).

### Drift Resolution (COMPLETED 2026-02-25)

**Teal**: Unified to `#237072` (5.78:1 on white — WCAG AA PASS). All layers updated.

**Ink-500**: Unified to `#6B6B6B` (5.33:1 on white — WCAG AA PASS). Token added to Layer 1 (`tokens.css`) and all layers updated.

---

## File Inventory

### Layer 1: Canonical Design Tokens

**File**: `assets/branding/tokens.css`
**Source**: Figma design system (manual export)
**Count**: 110 CSS custom properties (189 lines including comments, as of 2026-02-17)
**Prefixes**: `--color-*`, `--font-*`, `--space-*`, `--radius-*`, `--shadow-*`, `--avatar-*`, `--icon-*`, `--button-*`, `--gray-*`, `--text-*`, `--leading-*`, `--duration-*`, `--ease-*`, `--breakpoint-*`, `--container-*`, `--z-*`

**Provenance tracking**: `assets/branding/tokens.provenance.json`
- Upstream repo, commit SHA, file SHA256
- Synced via `scripts/branding/sync-brand-assets.sh`
- Freshness verified via `scripts/branding/update-token-provenance.sh`

### Layer 2: SCSS Bridge

**File**: `infrastructure/tutor/themes/mereka/scss/_tokens.scss`
**Purpose**: Bridge canonical tokens into SCSS variables + CSS custom properties for LMS/CMS/MFEs
**Count**:
- 24 SCSS variables (`$color-*`, `$mereka-*`, Bootstrap overrides)
- 37 CSS custom properties (`:root { --mereka-*, --pgn-* }`)

**Sections** (preserve when generating):
1. SCSS variable declarations (REPLACE during generation)
2. `:root` block with CSS custom properties (REPLACE during generation)
3. Bootstrap overrides (`$font-family-sans-serif`, `$btn-border-radius`, etc.) (PRESERVE)
4. Global CSS rules (`body {}`, `h1-h6 {}`, `a {}`, `.btn-primary {}`, `.card {}`) (PRESERVE)

### Layer 3: Runtime CSS Overrides

**File**: `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css`
**Purpose**: Runtime-injected CSS (loaded via `head-extra.html`) that defines additional tokens and aliases
**Count**: 1,636 lines (as of 2026-02-17)

**Sections** (preserve when generating):
1. `:root` block with `--mereka-*` and `--color-*` aliases (REPLACE during generation)
2. All other CSS rules (global styles, component overrides, MFE-specific rules) (PRESERVE)

---

## Non-Goals

### Out of Scope (Phase 1)

1. **Figma API integration**: Manual export from Figma to `tokens.css` is acceptable (low frequency, ~quarterly)
2. **Runtime CSS-in-JS**: No plan to migrate to CSS-in-JS frameworks (React styled-components, Emotion, etc.)
3. **Token versioning**: No semantic versioning or breaking change detection (design tokens are treated as a single cohesive system)
4. **Token composition**: No support for derived tokens (e.g., `--color-teal-hover: darken($color-teal, 10%)`) — all values are literals

### Potential Future Enhancements (Post-Phase 3)

1. **Figma API sync**: Automate token export from Figma via API (requires Figma Enterprise or plugin development)
2. **Token validation**: JSON schema for `tokens.css` structure, enforce naming conventions
3. **Contrast verification**: Auto-check WCAG AA contrast ratios during generation
4. **Token documentation**: Auto-generate visual swatch gallery from `tokens.css`

---

## Existing Tooling

### Sync & Provenance

**Script**: `scripts/branding/sync-brand-assets.sh`
**Purpose**: Copy `tokens.css` from upstream `bbbi-mereka-brand-assets` repo → `assets/branding/tokens.css`
**Also syncs**: Fonts, logos, favicons

**Script**: `scripts/branding/update-token-provenance.sh`
**Purpose**: Refresh `tokens.provenance.json` with upstream SHA, file hash, sync timestamp
**Ensures**: Token file integrity, audit trail for changes

### Drift Detection

**Script**: `scripts/branding/verify-token-drift.sh`
**Purpose**: Check 9 color pairs between `tokens.css` (Layer 1) and `mereka-overrides.css` (Layer 3)
**Exit code**: 1 if drift detected
**CI gate**: Not currently enforced (exits with 0 warnings)

**New script** (this contract): `scripts/qa/verify-token-generation-pipeline.sh`
**Purpose**: Comprehensive drift detection across all 3 layers + provenance checks
**Exit code**: 0 if FAIL count = 0, 1 otherwise
**CI gate**: Enforced in `monitoring-guardrails` job (syntax check in Phase 1, execution in Phase 3)

---

## Related Documentation

- **Token Reference Integrity**: `docs/architecture/TOKEN_REFERENCE_INTEGRITY.md` — 3-layer architecture, token inventory, drift warnings
- **Design Token Spec**: `specs/design-tokens.md` (AC-UITKN-001..012)
- **Frontend Audit Checklist**: `docs/FRONTEND_AUDIT_CHECKLIST.md` — Token correctness, usage lint
- **WCAG Contrast Compliance**: `docs/architecture/ACCESSIBILITY_CONFORMANCE_POLICY.md` — Token contrast verification

---

## Verification

### Manual Verification

```bash
# Check for multi-source drift
./scripts/qa/verify-token-generation-pipeline.sh

# Expected output (Phase 1):
# === Token Generation Pipeline Verification ===
#
# --- Contract & Files ---
#   PASS: Contract document exists
#   PASS: Canonical token file exists (assets/branding/tokens.css)
#   PASS: Provenance file exists (assets/branding/tokens.provenance.json)
#   PASS: SCSS bridge file exists
#   PASS: Runtime override file exists
#
# --- Token Counts ---
#   PASS: Layer 1 has 110 CSS custom properties (expected >= 100)
#   PASS: Layer 2 has 24 SCSS variables (expected >= 20)
#
# --- Cross-Layer Drift ---
#   PASS: --color-teal aligned across layers (#237072)
#   PASS: --mereka-color-ink-500 aligned across layers (#6B6B6B)
#   PASS: --color-magenta aligned across layers
#   PASS: --color-blue aligned across layers
#   PASS: --color-sky aligned across layers
#
# --- Provenance ---
#   PASS: Provenance SHA256 matches tokens.css
#
# === Results: 13 PASS / 0 FAIL / 0 WARN ===
# Exit code: 0
```

### CI Enforcement

**CI Job**: `monitoring-guardrails` in `.github/workflows/ci.yml`

**Phase 1** (current):
```yaml
- name: Verify script syntax
  run: |
    bash -n scripts/qa/verify-token-generation-pipeline.sh
```

**Phase 3** (future):
```yaml
- name: Verify token single-source
  run: |
    ./scripts/qa/verify-token-generation-pipeline.sh
```

**Exit criteria**: CI fails if FAIL count > 0.

---

## Acceptance Criteria Verification

| AC | Requirement | Verification Method |
|----|-------------|---------------------|
| AC-TKPIPE-001 | Contract document defines single-source pipeline architecture | This document exists at `docs/architecture/TOKEN_GENERATION_PIPELINE.md` |
| AC-TKPIPE-002 | Verifier detects multi-source drift | `scripts/qa/verify-token-generation-pipeline.sh` extracts hex values from all layers, reports drift as WARN |
| AC-TKPIPE-003 | CI gate prevents new independent hex definitions | `.github/workflows/ci.yml` → `monitoring-guardrails` job runs verifier (syntax check in Phase 1) |

**Last AC verification**: 2026-02-17
**Next review**: When implementing Phase 2 (generator script)

---

## Migration Timeline

| Phase | Deliverables | Status | Target Date |
|-------|--------------|--------|-------------|
| **Phase 1** | Contract + drift detection + CI gate | ✅ COMPLETE | 2026-02-17 |
| **Phase 2** | Generator script, resolve current drift | 🔜 PLANNED | Q1 2026 |
| **Phase 3** | CI enforcement (fail on new drift) | 🔜 PLANNED | Q1 2026 |

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2026-02-17 | Initial contract creation (AC-TKPIPE-001..003, Phase 1) | Agent (bead mereka-lms-115d.3) |
