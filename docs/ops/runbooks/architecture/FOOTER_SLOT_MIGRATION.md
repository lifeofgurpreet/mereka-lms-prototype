# Footer Slot Migration Contract
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

**Status**: Active Migration Path
**Created**: 2026-02-17
**Related**: [ADR-014: MFE Branding Strategy](../../../programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md)
**Verification**: `scripts/qa/verify-footer-slot-migration.sh`

---

## Purpose

This document defines the migration lifecycle for the MFE footer customization from dual-path (plugin + string surgery) to single-source plugin-config.

---

## Current State: Defense-in-Depth Dual-Path

The MerekaFooter component (v2, 5-zone dark footer) is currently delivered via two redundant paths:

### Path 1: Plugin (Canonical Source)

**File**: `infrastructure/tutor/plugins/mereka_lms.py` lines 568-769

**Mechanism**:
1. **Forward-compat registration** (lines 568-593): `PLUGIN_SLOTS.add_item("footer_slot", ...)` with ImportError guard
   - This path activates when `tutormfe.hooks.PLUGIN_SLOTS` becomes available in tutor-mfe
   - Currently inactive (Tutor 21 doesn't expose the filter yet)
2. **mfe-env-config patch** (lines 599-769): Injects MerekaFooter component inline in `env.config.jsx`
   - Full React component definition (171 lines)
   - Contains all footer logic: SITE_VARIANTS, socialLinks, navLinks, 4-column layout
   - mereka.scss import
   - This is the **canonical source of truth** for the footer component

### Path 2: apply-patches.sh (Fallback)

**File**: `infrastructure/tutor/apply-patches.sh` lines 1031-1207

**Mechanism**:
1. **Indigo import stripping** (line 1031): Removes `import Footer from '@edly-io/indigo-frontend-component-footer';`
2. **mereka.scss import injection** (lines 1032-1042): Safety net for CSS import
3. **MerekaFooter component duplication** (lines 1043-1206): Entire component inline
4. **RenderWidget replacement** (line 1207): `RenderWidget: <Footer />` → `RenderWidget: <MerekaFooter />`

**Why dual-path**: Defense-in-depth redundancy. If the plugin path fails (env.config.jsx generation issue, patch ordering problem), the string surgery in apply-patches.sh provides a fallback.

---

## Target State: Single-Source Plugin-Config

**When PLUGIN_SLOTS filter ships in tutor-mfe**:

### Keep (Plugin Only)

**File**: `mereka_lms.py`

1. **PLUGIN_SLOTS registration** (lines 568-593): Remove ImportError guard, make it the active path
2. **mfe-env-config patch** (lines 599-769): Keep as-is (component definition + mereka.scss import)

**Why keep mfe-env-config**: Even with PLUGIN_SLOTS, the component definition must live somewhere. The env.config.jsx patch is the right place for inline component definitions.

### Remove (apply-patches.sh)

**File**: `apply-patches.sh`

1. **Footer component duplication** (lines 1043-1206): DELETE
2. **RenderWidget replacement** (line 1207): DELETE

**Why remove**: Once PLUGIN_SLOTS is active, the string surgery is redundant. The plugin path handles both component injection and slot wiring.

### Retain (Safety Nets)

**File**: `apply-patches.sh`

1. **Indigo import stripping** (lines 1031): KEEP until we confirm Indigo is fully removed from upstream
2. **mereka.scss import** (lines 1032-1042): KEEP as safety net (ensures CSS loads even if plugin path has issues)

**Why retain**: These are low-risk safety nets that don't duplicate the component logic. They can be removed in a later cleanup phase once we have 6+ months of stable PLUGIN_SLOTS operation.

---

## Migration Steps

### Phase 0: Current State (DONE)

- [x] MerekaFooter v2 defined in `mereka_lms.py` mfe-env-config patch
- [x] PLUGIN_SLOTS forward-compat registration with ImportError guard
- [x] apply-patches.sh fallback (full duplication)
- [x] FPF dependency (`@openedx/frontend-plugin-framework@^1.8.0`) in MFE builds
- [x] Verification script (`verify-mfe-footer-slot.sh`)
- [x] CI gate (`.github/workflows/ci.yml` mfe-footer-slot job)

### Phase 1: PLUGIN_SLOTS Filter Ships (Trigger)

**When**: tutor-mfe upstream exposes `tutormfe.hooks.PLUGIN_SLOTS` filter

**Actions**:

1. Remove ImportError guard from `mereka_lms.py` lines 568-593
2. Set `_PLUGIN_SLOTS_AVAILABLE = True` as unconditional
3. Test: `tutor images build mfe && tutor k8s restart mfe`
4. Verify: `scripts/qa/verify-mfe-footer-slot.sh` (all checks PASS)
5. Verify: Live cluster footer renders identically

### Phase 2: Remove apply-patches.sh Duplication (After 2 Weeks Stable)

**When**: PLUGIN_SLOTS path has been stable in production for 2+ weeks

**Actions**:
1. **DELETE** `apply-patches.sh` lines 1043-1206 (MerekaFooter component)
2. **DELETE** `apply-patches.sh` line 1207 (RenderWidget replacement)
3. **KEEP** lines 1031-1042 (Indigo import stripping + mereka.scss safety net)
4. Update verification script to expect single-source (plugin only)
5. Test: `tutor images build mfe && tutor k8s restart mfe`
6. Verify: `scripts/qa/verify-footer-slot-migration.sh` (PASS on migration debt = 0)

### Phase 3: Remove Safety Nets (Optional, After 6 Months)

**When**: PLUGIN_SLOTS path has been stable in production for 6+ months

**Actions**:
1. **DELETE** `apply-patches.sh` lines 1031-1042 (Indigo import + mereka.scss safety net)
2. All footer logic now lives exclusively in `mereka_lms.py`
3. Update verification script accordingly

---

## Risk Analysis

### Risks of Dual-Path

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Component drift** | Plugin and patches diverge, footer breaks | Verification script checks parity (key identifiers: SITE_VARIANTS, mereka-footer--v2, 4 zones) |
| **Confusion for maintainers** | "Which one is the source of truth?" | This document + @covers annotations point to plugin as canonical |
| **Migration debt** | 177 lines of redundant code | Track as metric in verification script |

### Risks of Single-Source (Post-Migration)

| Risk | Impact | Mitigation |
|------|--------|------------|
| **PLUGIN_SLOTS filter breaks** | Footer doesn't render | Retain mfe-env-config patch (doesn't rely on filter) |
| **env.config.jsx generation failure** | No footer component | Monitoring: alert on 404 for footer assets |
| **Regression** | Accidentally re-introduce Footer import | CI gate: check for `import Footer from '@edly-io/indigo-frontend-component-footer'` |

---

## Verification Metrics

### Migration Debt

**Definition**: Lines of redundant footer code in `apply-patches.sh`

**Current**: 177 lines (1043-1206: 164 lines component + 1207: 1 line RenderWidget + 1031-1042: 12 lines safety nets)

**Target**: 12 lines (safety nets only) after Phase 2, 0 lines after Phase 3

### Component Parity

**Check**: Both sources (plugin + patches) contain identical key identifiers:

- `SITE_VARIANTS` object with 3 domains
- `mereka-footer--v2` CSS class
- 4 zones: `footer-social`, `footer-nav`, `footer-body`, `footer-legal`

**Failure mode**: If identifiers differ → drift detected → alert maintainer

### Slot Wiring Integrity

**Check**: PLUGIN_SLOTS registration exists for `footer_slot` with:
- `keepDefault: False` (replaces upstream footer)
- `op: PLUGIN_OPERATIONS.Replace`
- `RenderWidget: "MerekaFooter"`

---

## Rollback Plan

If PLUGIN_SLOTS path fails in production:

1. **Immediate**: Revert to dual-path by uncommenting apply-patches.sh footer block
2. **Short-term**: Investigate plugin issue (env.config.jsx generation, patch ordering)
3. **Long-term**: If PLUGIN_SLOTS proves unreliable, document decision to remain on dual-path

**Rollback cost**: 5 minutes (revert commit + `tutor images build mfe` + `tutor k8s restart mfe`)

---

## Success Criteria

### Phase 1 Complete When:
- [x] PLUGIN_SLOTS filter is available in tutor-mfe
- [ ] ImportError guard removed from `mereka_lms.py`
- [ ] Footer renders identically in all MFEs (authn, account, learning, profile, etc.)
- [ ] `verify-mfe-footer-slot.sh` passes (30+ PASS / 0 FAIL)

### Phase 2 Complete When:
- [ ] apply-patches.sh footer component (lines 1043-1206) deleted
- [ ] apply-patches.sh RenderWidget replacement (line 1207) deleted
- [ ] `verify-footer-slot-migration.sh` reports migration debt = 12 lines (safety nets only)
- [ ] Footer renders identically for 2+ weeks in production

### Phase 3 Complete When:
- [ ] All safety nets removed from apply-patches.sh
- [ ] Migration debt = 0 lines
- [ ] Footer stable for 6+ months

---

## Related Files

| File | Role | Status |
|------|------|--------|
| `infrastructure/tutor/plugins/mereka_lms.py` | Canonical source (plugin) | Active |
| `infrastructure/tutor/apply-patches.sh` | Fallback (string surgery) | Active, to be removed |
| `scripts/qa/verify-mfe-footer-slot.sh` | Component parity check | Active |
| `scripts/qa/verify-plugin-slot-wiring.sh` | Slot wiring integrity | Active |
| `scripts/qa/verify-footer-slot-migration.sh` | Migration progress tracking | NEW (this bead) |
| `docs/programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md` | Strategic decision (plugin-first) | Reference |

---

## Acceptance Criteria Mapping

- **AC-FTSLOT-001**: This document defines the footer slot migration lifecycle (dual-path → single-source plugin-config)
- **AC-FTSLOT-002**: Verification script confirms MerekaFooter lives in exactly one canonical source (mereka_lms.py), detects drift between plugin and patches
- **AC-FTSLOT-003**: CI gate prevents regression to string-surgery-only footer wiring

---

**Last Updated**: 2026-02-17
**Owner**: Platform Team
**Revisit**: When `tutormfe.hooks.PLUGIN_SLOTS` filter ships in tutor-mfe
