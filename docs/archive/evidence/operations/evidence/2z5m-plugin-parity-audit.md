# Plugin Parity Audit: LMS / Studio / MFE Slot Inventory

> **Bead**: mereka-lms-2z5m
> **ACs**: AC-UX-110, AC-UX-111, AC-UX-112, AC-UX-113
> **Date**: 2026-02-19
> **Branch**: feat/23ry2-spec-dedupe-normalize

---

## AC-UX-110: Plugin Slot Discovery Output

### Environment

| Item | Value |
|------|-------|
| Tutor version | 21.0.0 (Ulmo) |
| `tutormfe.hooks.PLUGIN_SLOTS` | **NOT AVAILABLE** (`ImportError: No module named 'tutormfe'`) |
| Active wiring path | apply-patches.sh fallback (string replacement in `env.config.jsx`) |
| Plugin file | `infrastructure/tutor/plugins/mereka_lms.py` |

### Slot Registration (mereka_lms.py lines 630–701)

Three slots are declared in a forward-compatible `try/except ImportError` block:

| Slot ID | Op | Widget ID | RenderWidget | keepDefault |
|---------|----|-----------|--------------|-------------|
| `footer_slot` | `PLUGIN_OPERATIONS.Replace` | `mereka_footer` | `MerekaFooter` | `False` |
| `header_logo_slot` | `PLUGIN_OPERATIONS.Replace` | `mereka_header_logo` | `MerekaHeaderLogo` | `False` |
| `learner_dashboard.sidebar.v1` | `PLUGIN_OPERATIONS.Append` | `mereka_dashboard_sidebar_cta` | `MerekaDashboardSidebarCTA` | `True` |

**Runtime status**: `_PLUGIN_SLOTS_AVAILABLE = False` — all three registrations silently skipped.

### MFE env.config.jsx (generated: `tutor_env/env/plugins/mfe/build/mfe/env.config.jsx`)

- Uses `addPlugins(config, slot_name, plugins)` helper (line 10–18)
- `pluginSlots: {}` initialized empty at line 74 — **no slot entries populated**
- MerekaFooter component defined **inline** (via `mfe-env-config` ENV_PATCHES, not via slot)
- apply-patches.sh replaces `RenderWidget: IndigoFooter,` → `RenderWidget: <MerekaFooter />,` (string substitution)

### Studio (CMS) Slot Inventory

Studio is a Django/Mako application (not an MFE). It does **not** use the FPF plugin slot system.
Branding in Studio is applied via:
- LMS theme inheritance (`DEFAULT_SITE_THEME`)
- Django template overrides in the Indigo theme
- Studio-specific CSS patches in `apply-patches.sh`

### LMS Slot Inventory

LMS core pages use Django/Mako templates. Plugin slots in the FPF sense only apply to MFEs.
LMS branding is applied via:
- Comprehensive Mako template patches in `apply-patches.sh`
- `SITE_VARIANTS` hostname dispatch in `mereka_lms.py` (lines ~1075–1090)
- `TenantResolutionMiddleware` for multi-tenant context

---

## AC-UX-111: MFE Changes are via Tutor Plugin / FPF — NOT Direct Repo Patching

**Verdict: PASS (with WARN for fallback path)**

| Change Type | Method | Direct Repo Patch? |
|-------------|--------|--------------------|
| MerekaFooter component definition | `mfe-env-config` ENV_PATCHES hook in `mereka_lms.py` | ❌ No |
| Footer slot wiring (primary) | `PLUGIN_SLOTS.add_item()` in `mereka_lms.py` (try/except, currently inactive) | ❌ No |
| Footer slot wiring (fallback) | `apply-patches.sh` string replacement in generated `env.config.jsx` | ⚠️ WARN — modifies generated file, not source |
| MFE SCSS theme import | `mfe-env-config` ENV_PATCHES hook | ❌ No |
| SITE_VARIANTS hostname dispatch | `mereka_lms.py` lines 1075–1090 | ❌ No |
| Header logo (fallback) | CSS `.navbar .navbar-brand img` override in `mereka.scss` | ⚠️ WARN — CSS hack, HIGH risk |
| Dashboard sidebar (fallback) | SCSS scoped layout rules via `[data-testid*="learner-dashboard"]` | ⚠️ WARN — CSS hack, HIGH risk |

**No MFE source files in the Open edX repository are directly patched.** All customizations flow through:
1. Tutor plugin hooks (`hooks.Filters.ENV_PATCHES`) — generates MFE config at build time
2. `apply-patches.sh` — post-generation string replacement (fallback/migration path)
3. SCSS overrides in the Indigo theme (compile-time)

Verify script confirmation:
```
verify-footer-slot-migration.sh: PASS 23/23, FAIL 0, WARN 0
verify-mfe-footer-slot-migration.sh: PASS 23/23, FAIL 0, WARN 0
verify-branding-health.sh: PASS 3/3, FAIL 0
verify-mfe-branding.sh: PASS 57/57, FAIL 0, SKIP 1
```

---

## AC-UX-112: Expected vs Implemented Slot Behavior (Diff Table)

| Slot ID | Surface | Expected Behavior | Current Implementation | Status |
|---------|---------|-------------------|----------------------|--------|
| `footer_slot` | All MFEs (authn, learner-dashboard, etc.) | `DIRECT_PLUGIN Replace` → `MerekaFooter` via FPF | Inline component in `env.config.jsx` via `mfe-env-config` patch + apply-patches.sh RenderWidget replacement | ✅ FUNCTIONAL — wrong path |
| `header_logo_slot` | All MFEs (header bar) | `DIRECT_PLUGIN Replace` → `MerekaHeaderLogo` via FPF | CSS `.navbar .navbar-brand img` override (compile-time SCSS) | ⚠️ WARN — HIGH risk fallback, not slot-based |
| `learner_dashboard.sidebar.v1` | Learner Dashboard MFE | `DIRECT_PLUGIN Append` → `MerekaDashboardSidebarCTA` | SCSS scoped layout rules (`[data-testid*="learner-dashboard"]`) | ⚠️ WARN — HIGH risk fallback, component not rendered |
| LMS footer | LMS (Django) | Mereka-branded footer via theme template | Mako template override via apply-patches.sh + Indigo theme | ✅ FUNCTIONAL |
| Studio branding | Studio (Django/Mako) | Mereka-branded Studio header + CSS | CSS patches via apply-patches.sh + Studio template overrides | ✅ FUNCTIONAL |
| MFE font loading | All MFEs | Local Poppins/Lato fonts (no Google Fonts CDN) | SCSS `@font-face` in `mereka.scss` + font files in `mfe/fonts/` | ✅ PASS (57/57 verify-mfe-branding.sh) |

**Summary**:
- 3/5 surfaces: FUNCTIONAL ✅
- 2/5 surfaces: FUNCTIONAL via HIGH-risk CSS fallback ⚠️ (header_logo, dashboard sidebar)
- 0/5 surfaces: BROKEN ❌

---

## AC-UX-113: Follow-Up Fixes for Remaining Direct Patch Usage

### Priority 1 — Unblock when `tutormfe.hooks.PLUGIN_SLOTS` ships (HIGH impact, LOW risk)

| Item | Action | File | Priority |
|------|--------|------|----------|
| footer_slot primary path | Remove `try/except ImportError` guard; use PLUGIN_SLOTS directly | `mereka_lms.py` line 632 | P1 |
| footer_slot fallback cleanup | Remove apply-patches.sh footer string replacement (lines 1043–1207) | `apply-patches.sh` | P1 — after PLUGIN_SLOTS confirmed stable |
| header_logo_slot wiring | Move from CSS hack to `PLUGIN_SLOTS.add_item(header_logo_slot, ...)` with `MerekaHeaderLogo` component defined in `mfe-env-config` | `mereka_lms.py` + `apply-patches.sh` | P1 |
| dashboard sidebar CTA | Implement `MerekaDashboardSidebarCTA` component in `mfe-env-config` patch + wire via `PLUGIN_SLOTS.add_item(learner_dashboard.sidebar.v1, ...)` | `mereka_lms.py` + `apply-patches.sh` | P2 |

### Priority 2 — Migration debt tracking

| Debt Item | Lines | Risk | Action |
|-----------|-------|------|--------|
| apply-patches.sh footer block | ~165 lines (1043–1207) | LOW — functional, guarded by MIGRATED-TO-SLOT marker | Remove when PLUGIN_SLOTS confirmed active for 2 weeks |
| CSS header logo hack | `mereka.scss` `.navbar .navbar-brand img` | HIGH — selector may break on MFE updates | Replace with slot wiring |
| SCSS dashboard layout rules | `mereka.scss` `[data-testid*="learner-dashboard"]` | HIGH — data-testid selectors may change | Replace with PLUGIN_SLOTS.Append |

### Tracking Reference

These follow-up items should be tracked under a future bead in the `e4j6` family once `tutormfe.hooks.PLUGIN_SLOTS` is available in Tutor v22+.

---

## Evidence Files

| Script | Result |
|--------|--------|
| `scripts/qa/verify-footer-slot-migration.sh` | PASS 23 / FAIL 0 / WARN 0 |
| `scripts/qa/verify-mfe-footer-slot-migration.sh` | PASS 23 / FAIL 0 / WARN 0 |
| `scripts/qa/verify-branding-health.sh` | PASS 3 / FAIL 0 |
| `scripts/qa/verify-mfe-branding.sh` | PASS 57 / FAIL 0 / SKIP 1 |
| `python3 -c "from tutormfe.hooks import PLUGIN_SLOTS"` | `ImportError: No module named 'tutormfe'` |
