# Footer Slot Migration Contract
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-04-21 • Status: active_

**Status**: Active Migration Path
**Created**: 2026-02-17
**Related**: [ADR-014: MFE Branding Strategy](../../../programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md)
**Verification**: `scripts/qa/verify-mfe-footer-slot.sh`, `scripts/qa/verify-footer-parity.sh`

---

## Purpose

This document defines the migration lifecycle for the MFE footer customization from dual-path (plugin + string surgery) to single-source plugin-config.

---

## Current State: Plugin-Owned Footer With Retired-Indigo Guards

> 2026-04-21 truth note: the active footer owner is the repo-local Tutor plugin
> surface. `MerekaFooter` lives in
> `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/footer.js`, is assembled
> by `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime.py`, and is registered
> through `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py`. External Tutor
> Indigo is retired. Any remaining Indigo logic is a stale-render guard, not a
> live dependency or second owner.

The MerekaFooter component (v2, 5-zone dark footer) is delivered through the
repo-local Tutor plugin path:

### Canonical Source

| Concern | Current owner |
|---|---|
| Footer React component | `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/footer.js` |
| Runtime assembly into `env.config.jsx` | `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime.py` |
| Footer slot registration | `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` |
| Stale Indigo residue guard | governed patch path only, with verifier coverage |

`apply-patches.sh` must not carry a duplicate `MerekaFooter` implementation or
be treated as a second footer owner. If a render still contains an external
Indigo footer import, strip it as stale upstream residue and keep the verifier
red until the render is clean.

---

## Target State: Single-Source Plugin Config

The target is already the active direction: footer component source and slot
registration live in the repo-local plugin modules. The remaining work is to
delete stale-render guards only after verifier evidence shows Tutor/upstream no
longer emits the external Indigo residue they protect against.

### Retain (Stale-Render Guards)

**File**: `apply-patches.sh`

1. **Indigo import stripping**: keep only as a guard against stale upstream or
   stale rendered artifacts reintroducing the retired external Indigo package.
2. **mereka.scss import**: keep only if the plugin-owned runtime path still
   needs the safety net for rendered `env.config.jsx` compatibility.

**Why retain**: These guards do not make Indigo live again and must not
duplicate footer component logic. If a future render proves they are obsolete,
remove them together with the verifier expectation that required them.

---

## Migration Steps

### Phase 0: Plugin-Owned Footer (DONE)

- [x] MerekaFooter v2 defined in `_mereka_lms/mfe_runtime/footer.js`
- [x] Runtime JSX assembled by `_mereka_lms/mfe_runtime.py`
- [x] Footer slot registered through `mereka_lms_mfe_slots.py`
- [x] External Indigo package retired from active build authority
- [x] FPF dependency (`@openedx/frontend-plugin-framework@^1.8.0`) in MFE builds
- [x] Verification script (`verify-mfe-footer-slot.sh`)
- [x] CI/static gates include footer and plugin slot checks

### Phase 1: Retire Stale-Render Guards

**When**: a fresh Tutor render proves the external Indigo import and
`mereka.scss` safety-net injection are no longer needed.

**Actions**:

1. Remove the obsolete guard from the governed patch path.
2. Update `verify-mfe-footer-slot.sh` or the relevant parity verifier to fail if
   external Indigo dependency wiring is reintroduced.
3. Test: `./scripts/qa/verify-mfe-footer-slot.sh` and
   `./scripts/qa/verify-footer-parity.sh`.
4. Rebuild MFE and verify live footer rendering before closing the lane.

---

## Risk Analysis

### Risks of Reintroducing Dual-Path Footer Logic

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Component drift** | Plugin and patches diverge, footer breaks | Keep component code in `_mereka_lms/mfe_runtime/footer.js` only |
| **Confusion for maintainers** | "Which one is the source of truth?" | This document and `MFE_PLUGIN_SLOT_INVENTORY.md` point to plugin modules as canonical |
| **Indigo relapse** | Retired external package becomes live again | CI must reject `indigo-frontend-component-footer` in active render/build output |

### Risks of Single-Source (Post-Migration)

| Risk | Impact | Mitigation |
|------|--------|------------|
| **PLUGIN_SLOTS filter breaks** | Footer doesn't render | Keep slot verifier and runtime browser proof current |
| **env.config.jsx generation failure** | No footer component | Monitoring: alert on 404 for footer assets |
| **Regression** | Accidentally re-introduce Footer import | CI gate: check for `import Footer from '@edly-io/indigo-frontend-component-footer'` |

---

## Verification Metrics

### Migration Debt

**Definition**: footer component implementation outside the repo-local plugin
runtime modules.

**Current target**: zero duplicate `MerekaFooter` implementations in
`apply-patches.sh` or rendered patch helpers.

### Component Parity

**Check**: The plugin source and rendered output contain the expected identifiers:

- `SITE_VARIANTS` object with 3 domains
- `mereka-footer--v2` CSS class
- 4 zones: `footer-social`, `footer-nav`, `footer-body`, `footer-legal`

**Failure mode**: If plugin source and rendered output differ in behavior, fix the
plugin/render path. Do not add a second footer implementation.

### Slot Wiring Integrity

**Check**: PLUGIN_SLOTS registration exists for `footer_slot` with:
- `keepDefault: False` (replaces upstream footer)
- `op: PLUGIN_OPERATIONS.Replace`
- `RenderWidget: "MerekaFooter"`

---

## Rollback Plan

If footer slot wiring fails in production:

1. **Immediate**: revert the source PR or roll back to the prior known-good MFE
   image through GitOps.
2. **Short-term**: investigate plugin slot registration, `env.config.jsx`
   generation, and runtime component assembly.
3. **Long-term**: repair the plugin/render path and add a regression guard.
   Reintroducing a duplicate `apply-patches.sh` footer component is an
   intentional architecture change and requires a new authority decision.

**Rollback cost**: depends on image availability and GitOps realization time;
do not use live-only `kubectl` mutation as closure.

---

## Success Criteria

### Current Lane Complete When:
- [x] Footer source lives in the plugin runtime modules.
- [x] Slot registration lives in `mereka_lms_mfe_slots.py`.
- [ ] Any remaining stale-render guards have verifier coverage and a retirement
  trigger.
- [ ] Footer renders correctly in active MFEs after the next MFE image proof.

---

## Related Files

| File | Role | Status |
|------|------|--------|
| `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime/footer.js` | Footer component source | Active |
| `infrastructure/tutor/plugins/_mereka_lms/mfe_runtime.py` | Runtime assembly into `env.config.jsx` | Active |
| `infrastructure/tutor/plugins/mereka_lms_mfe_slots.py` | Slot registration | Active |
| `infrastructure/tutor/apply-patches.sh` | Governed patch entrypoint; not footer source authority | Active |
| `scripts/qa/verify-mfe-footer-slot.sh` | Footer slot wiring check | Active |
| `scripts/qa/verify-footer-parity.sh` | Footer parity check | Active |
| `docs/programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md` | Strategic decision (plugin-first) | Reference |

---

## Acceptance Criteria Mapping

- **AC-FTSLOT-001**: This document defines the footer slot migration lifecycle toward single-source plugin config.
- **AC-FTSLOT-002**: Verification confirms MerekaFooter remains plugin-owned and rendered output stays aligned.
- **AC-FTSLOT-003**: CI gates prevent regression to string-surgery-only footer wiring or live Indigo dependency wiring.

---

**Last Updated**: 2026-04-21
**Owner**: Platform Team
**Revisit**: When the remaining stale-render guards have fresh render evidence
showing they can be removed.
