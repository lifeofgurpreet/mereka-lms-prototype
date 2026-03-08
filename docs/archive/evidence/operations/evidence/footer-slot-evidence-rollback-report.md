# Footer Slot Evidence and Rollback Report

**Bead**: 2dcy.8
**ACs**: AC-FRONT-081, AC-FRONT-082, AC-FRONT-083, AC-FRONT-084
**Date**: 2026-02-18
**Status**: Complete

---

## Summary

This report codifies the evidence from the footer plugin-slot migration and documents
the rollback guard for slot-based overrides. The actual migration work was performed
in beads 2dcy.2 (selector-to-slot) and 1rns (legacy footer removal).

---

## AC Pass/Fail Summary

| AC | Description | Result |
|----|-------------|--------|
| AC-FRONT-081 | MFE surface touchpoint inventory exists and covers required surfaces | PASS |
| AC-FRONT-082 | Slot wiring in mereka_lms.py; exceptions documented | PASS |
| AC-FRONT-083 | MerekaFooter component present; footer_slot `keepDefault: False`; host variants covered | PASS |
| AC-FRONT-084 | Rollback playbook exists with `git revert`; `try/except ImportError` guard in plugin | PASS |

All 4 ACs pass. Verification script: `scripts/qa/verify-footer-slot-evidence-rollback.sh`

---

## AC-FRONT-081: Surface Inventory

**File**: `docs/archive/evidence/operations/evidence/mfe-surface-inventory.md`

The inventory covers:
- footer (slot-based, `footer_slot`)
- header logo (slot-based, `header_logo_slot`)
- dashboard sidebar (slot-based, `learner_dashboard.sidebar.v1`)
- authn shell (CSS-only exception, EX-05)
- navbar (CSS-only exception, EX-03/EX-04)
- course card, badges, admin, Studio (documented as not customized or CSS-only)

Mechanism column distinguishes slot-based vs CSS-only for every surface.

---

## AC-FRONT-082: Slot Wiring and Exceptions

**Slot registrations** in `infrastructure/tutor/plugins/mereka_lms.py`:

```python
# footer_slot — keepDefault: False — replaces Indigo default footer
PLUGIN_SLOTS.add_item(("footer_slot", { "keepDefault": False, ... }))

# header_logo_slot — keepDefault: False — replaces default header logo
PLUGIN_SLOTS.add_item(("header_logo_slot", { "keepDefault": False, ... }))

# learner_dashboard.sidebar.v1 — keepDefault: True — appends sidebar CTA
PLUGIN_SLOTS.add_item(("learner_dashboard.sidebar.v1", { "keepDefault": True, ... }))
```

**CSS exceptions**: `docs/policies/architecture/MFE_SELECTOR_EXCEPTIONS.md`
- 10 documented exceptions (EX-01 through EX-10)
- Exception count explicitly documented in the exceptions file Risk Summary Matrix

---

## AC-FRONT-083: Footer and Auth Shell Rendering Verification

**MerekaFooter component**:
- Defined inline in the `mfe-env-config` patch within `mereka_lms.py`
- `const MerekaFooter = () => { ... }` visible at line ~716

**`footer_slot` registration**:
- `keepDefault: False` — verified in mereka_lms.py at the PLUGIN_SLOTS block
- Operation: `PLUGIN_OPERATIONS.Replace`

**Host variants handled** (SITE_VARIANTS map in component):
- `academyv2.mereka.io` — Mereka Academy (enterprise host)
- `academy.biji-biji.com` — Biji-Biji Academy (learner host)
- `skillourfuture.academy.mereka.io` — Skill Our Future Academy

**env.config.jsx coverage** (`mfe-env-config` Tutor patch):
- MerekaFooter component definition injected into all MFE builds
- ALLOWED_HOSTS / extra domains include both enterprise and learner hosts

---

## AC-FRONT-084: Rollback Guard

### Rollback Playbook Location

`docs/runbooks/architecture/LEGACY_FOOTER_REMOVAL.md` → "Rollback Procedure" section

### Rollback Steps (from LEGACY_FOOTER_REMOVAL.md)

1. Find the `1rns` commit: `git log --oneline --grep="1rns" | head -1`
2. Revert: `git revert <commit-sha>`
3. Re-run patches: `./infrastructure/tutor/apply-patches.sh`
4. Restart: `tutor local restart`
5. Verify: `grep "MerekaFooter" tutor_env/env/plugins/mfe/build/mfe/env.config.jsx`

### Rollback Guard in Plugin

The `try/except ImportError` pattern in `mereka_lms.py` ensures the plugin loads
safely regardless of whether `tutormfe.hooks.PLUGIN_SLOTS` is available:

```python
try:
    from tutormfe.hooks import PLUGIN_SLOTS
    PLUGIN_SLOTS.add_item(("footer_slot", { ... }))
    _PLUGIN_SLOTS_AVAILABLE = True
except ImportError:
    _PLUGIN_SLOTS_AVAILABLE = False
```

The `_PLUGIN_SLOTS_AVAILABLE` flag is set in both branches, making the guard state
observable for debugging and verification.

---

## Related Evidence Files

- `docs/archive/evidence/operations/evidence/mfe-surface-inventory.md` — Surface inventory (AC-FRONT-081)
- `docs/archive/evidence/operations/evidence/footer-migration-diff.md` — Before/after diff from bead 1rns
- `docs/archive/evidence/operations/evidence/selector-to-slot-migration-diff.md` — Slot migration diff from bead 2dcy.2
- `docs/policies/architecture/MFE_SELECTOR_EXCEPTIONS.md` — CSS exception documentation (AC-FRONT-082)
- `docs/runbooks/architecture/LEGACY_FOOTER_REMOVAL.md` — Rollback playbook (AC-FRONT-084)
