# Selector Hardening Policy

**Purpose**: Guidelines for writing maintainable, stable CSS/SCSS selectors in Mereka Academy themes.
**Last updated**: 2026-02-17
**Covers**: `AC-UISEL-001`, `AC-UISEL-002`
**Related**: [MFE_PLUGIN_SLOT_INVENTORY.md](./MFE_PLUGIN_SLOT_INVENTORY.md), [MFE_FIRST_POLICY.md](./MFE_FIRST_POLICY.md)

> **2026-02-28 status note**: This document captures the pre-Phase C/T102 policy baseline and includes historical examples.
> Current production selector contracts are enforced by:
> - `scripts/qa/verify-mfe-selector-hardening.sh`
> - `scripts/qa/verify-selector-to-slot-migration.sh`
> - `scripts/qa/verify-no-dom-overrides.sh`
>
> For current truth, prefer:
> - [MFE_SELECTOR_OVERRIDE_INVENTORY.md](./MFE_SELECTOR_OVERRIDE_INVENTORY.md)
> - [FPF_PLUGIN_SLOT_REGISTRY.md](./FPF_PLUGIN_SLOT_REGISTRY.md)

---

## Problem Statement

The Open edX platform undergoes frequent DOM structure changes during upgrades. Selectors that depend on deep DOM nesting or unstable attributes break silently, causing:

- **Visual regressions** (missing branding, layout breaks)
- **Upgrade friction** (theme must be rewritten for each Tutor version)
- **Testing gaps** (data-testid is for tests, not production styling)

**Goal**: Minimize fragility by preferring stable selector patterns and migrating to plugin slots where available.

---

## Selector Complexity Rules

### Maximum Nesting Depth: 3 Levels

**Rule**: Selectors SHOULD NOT exceed 3 levels of descendant combinators.

| ❌ Fragile (4+ levels) | ✅ Preferred (≤3 levels) |
|------------------------|---------------------------|
| `.dashboard .my-courses .course-item .course-container` | `[class*="course-card"]` (attribute selector) |
| `.home.style-logout header .title` | `.mereka-hero h1` (custom class) |
| `.view-outline .outline-complex .outline-section:hover` | `.pgn__card:hover` (Paragon class) |

**Rationale**: Each nesting level couples the selector to a specific DOM structure. Open edX frequently restructures components during upgrades.

**Current state** (theme.scss):
- **100+ selectors** with 3+ levels of nesting
- Most are in LMS/Studio legacy views
- Documented as KNOWN ISSUE (see "Current Risk Inventory" below)

---

## Approved Selector Patterns

### 1. Paragon Component Classes (Preferred)

Open edX uses the Paragon design system. Paragon classes are stable across upgrades.

```scss
.pgn__card { border-radius: 24px; }
.pgn__btn--primary { background: var(--mereka-gradient-primary); }
.pgn__form-control:focus { box-shadow: 0 0 0 4px var(--mereka-mfe-focus); }
```

**Stability**: HIGH (Paragon maintains backward compatibility)

---

### 2. Attribute Substring Selectors (MFE Targeting)

For MFEs where class names are generated (React, Webpack CSS modules), use attribute selectors:

```scss
[class*="authn"] .pgn__card { /* Authn MFE surfaces */ }
[class*="learner-dashboard"] [class*="course-card"] { /* Course cards */ }
[data-testid*="discussions"] .card { /* Discussions MFE */ }
```

**Stability**: MEDIUM (depends on BEM-like naming conventions)

**⚠️ Important**: `data-testid` SHOULD only be used when no class-based alternative exists. It is intended for testing, not production styling.

---

### 3. Custom Mereka Classes (Controlled by Us)

Inject custom classes via XBlocks, Django templates, or plugin slots:

```scss
.mereka-hero { background: var(--mereka-gradient-primary); }
.mereka-badge { border-radius: 999px; }
.mereka-footer--v2 { background: #1A1623; }
```

**Stability**: HIGH (we control the markup)

**Implementation path**:
- LMS templates: `infrastructure/tutor/themes/mereka/lms/templates/`
- Plugin slots: `infrastructure/tutor/plugins/mereka_lms.py` → `PLUGIN_SLOTS`

---

## Prohibited Patterns

### 1. Element-Type Chains (Fragile)

```scss
/* ❌ Breaks if Open edX changes markup structure */
header nav ul li a { color: blue; }

/* ✅ Use classes or limit depth */
.navbar .nav-link { color: blue; }
```

---

### 2. data-testid for Styling (Anti-Pattern)

```scss
/* ❌ data-testid is for tests, not production CSS */
[data-testid="login-page"] .card { border: 1px solid red; }

/* ✅ Use class selectors */
[class*="login-register"] .pgn__card { border: 1px solid red; }
```

**Current usage**: `mereka.scss` uses `[data-testid*="login-page"]` in 5 places (ACCEPTABLE for MFE targeting until slot migration).

---

### 3. Deep DOM Coupling (>3 Levels)

```scss
/* ❌ Couples to specific DOM structure */
.dashboard .my-courses .course-item .course-container { border: none; }

/* ✅ Target the final element directly */
.dashboard [class*="course-container"] { border: none; }
```

---

## Design Token Usage

**Rule**: All color values MUST use design tokens (`var(--mereka-*)` or `$color-*`), NOT raw hex codes.

| ❌ Fragile | ✅ Token-based |
|------------|----------------|
| `color: #2d898b;` | `color: var(--mereka-color-teal);` |
| `background: #fff;` | `background: var(--mereka-mfe-surface);` |
| `border: 1px solid #1A1623;` | `border: 1px solid var(--mereka-color-ink-900);` |

**Exceptions**:
- `rgba()` with alpha values (e.g., `rgba(45, 137, 139, 0.12)` for teal with transparency)
- Inline gradients where token composition is verbose

**Token source**: `assets/branding/tokens.css` (synced from Figma via `scripts/branding/update-token-provenance.sh`)

---

## Migration Path: Plugin Slots Over SCSS

**Philosophy**: When Open edX provides a plugin slot, prefer it over CSS hacks.

### Example: Footer Migration

**Before** (SCSS override):
```scss
footer.wrapper-footer { display: none; }
.custom-footer { /* inject via JS */ }
```

**After** (Plugin slot):
```python
# infrastructure/tutor/plugins/mereka_lms.py
from tutor import hooks

hooks.Filters.ENV_TEMPLATE_VARIABLES.add_item(
    "PLUGIN_SLOTS",
    [
        {
            "slot_id": "org.openedx.frontend.layout.footer.v1",
            "op": "PLUGIN_OPERATIONS.Replace",
            "widget_id": "MerekaFooter",
        }
    ]
)
```

**Result**: Footer is replaced at runtime without SCSS hacks. Survives Open edX upgrades.

---

## Current Risk Inventory

### HIGH-RISK Selectors (>3 Levels, Frequent Open edX Changes)

| Selector | File | Risk | Migration Path |
|----------|------|------|----------------|
| `.dashboard .my-courses .course-item .course-container` | `theme.scss:314` | HIGH | Migrate to learner-dashboard MFE slot when available |
| `.home.style-logout header .title` | `theme.scss:104` | MEDIUM | Custom template injection |
| `.courseware .course-content .course-outline .course-index` | `theme.scss:395` | MEDIUM | Paragon Card classes |
| `.view-outline .outline-complex .outline-section:hover` | `theme.scss:800` | HIGH | Studio redesign in Ulmo may change structure |

**Total fragile selectors**: 100+ (as of 2026-02-17)

**Mitigation**:
- Document as KNOWN ISSUE in `verify-selector-hardening.sh`
- Track Open edX changelogs for DOM structure changes
- Prioritize migration to plugin slots (see next section)

---

## Slot-First Migration Assessment

### Current env.config.jsx Customizations

**Wired via `apply-patches.sh`** (string replacement method):

1. **SCSS import injection** (line 1326-1357)
   - Injects `import './mereka/mereka.scss'` into `env.config.jsx`
   - **Slot alternative**: N/A (SCSS loading is required, not replaceable by slots)

2. **MerekaFooter component** (line 560-610 in `mereka_lms.py`)
   - **Status**: ACTIVE (using `PLUGIN_OPERATIONS.Replace`)
   - **Slot ID**: `org.openedx.frontend.layout.footer.v1`
   - **Migration**: COMPLETE

### Slot-Wirable Customizations (Not Yet Migrated)

From [MFE_PLUGIN_SLOT_INVENTORY.md](./MFE_PLUGIN_SLOT_INVENTORY.md), 100+ slots are available but unwired. Top migration candidates:

| Customization | Current Method | Slot ID | Priority |
|---------------|----------------|---------|----------|
| Header logo | SCSS `.navbar-brand img` | `org.openedx.frontend.layout.header_logo.v1` | HIGH |
| Login/register card styling | SCSS `[data-testid*="login-page"]` | `org.openedx.frontend.authn.login.top.v1` | MEDIUM |
| Course card layout | SCSS `[class*="course-card"]` | `org.openedx.frontend.learner-dashboard.course-card.v1` | MEDIUM |
| Discussion post styling | SCSS `[class*="discussions"]` | `org.openedx.frontend.discussions.post.v1` | LOW |

**Migration trigger**: When Open edX upstream changes DOM structure, migrate affected selectors to slots instead of rewriting SCSS.

---

## Verification

**Script**: `scripts/qa/verify-selector-hardening.sh`

**Checks**:
- ✅ Selector nesting depth (WARN on >3 levels)
- ✅ data-testid usage in production SCSS (WARN)
- ✅ Raw hex colors (WARN if not using tokens)
- ✅ Fragile selector ratio (WARN if >30%)

**CI Integration**: `.github/workflows/ci.yml` → `monitoring-guardrails` job

---

## Recommendations

### For New Features
1. **Check slot inventory first** (`docs/reference/architecture/MFE_PLUGIN_SLOT_INVENTORY.md`)
2. **Use Paragon classes** when targeting standard components
3. **Inject custom classes** via Django templates or XBlocks
4. **Limit nesting** to ≤3 levels

### For Existing Code
1. **Document fragile selectors** as KNOWN ISSUE (don't break the theme)
2. **Migrate opportunistically** when Open edX changes DOM structure
3. **Prioritize high-traffic surfaces** (dashboard, authn, course player)

### For Tutor Upgrades
1. **Run `verify-selector-hardening.sh`** before and after upgrade
2. **Compare fragile selector count** (expect increase if new DOM structures)
3. **Test critical paths** (`make qa-smoke`) to catch visual regressions
4. **Review slot inventory** for new upstream slots

---

## Related Documents

- [MFE_PLUGIN_SLOT_INVENTORY.md](./MFE_PLUGIN_SLOT_INVENTORY.md) — Complete slot catalog
- [MFE_FIRST_POLICY.md](./MFE_FIRST_POLICY.md) — Slot-first implementation strategy
- [ADR-014: MFE Branding Strategy](../../adr/014-mfe-branding-strategy.md) — Historical context
- [verify-selector-hardening.sh](../../../scripts/qa/verify-selector-hardening.sh) — Automated checks

---

## Revision History

| Date | Change |
|------|--------|
| 2026-02-17 | Initial policy (bead 217q) |
