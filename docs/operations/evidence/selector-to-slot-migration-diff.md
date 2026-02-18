# Selector-to-Slot Migration Evidence

**Bead**: 2dcy.2
**ACs**: AC-FRONT-021, AC-FRONT-022, AC-FRONT-023, AC-FRONT-024, AC-FRONT-025
**Date**: 2026-02-18
**Author**: bead 2dcy.2 implementation

This document provides the before/after evidence for the selector-to-slot migration work
completed across the mereka-lms MFE branding stack.

---

## Summary

Three structural MFE customizations that previously relied on CSS selectors (or string surgery)
were migrated to explicit `frontend-plugin-framework` plugin slot registrations. The remaining
high-risk selectors have been documented in `docs/operations/MFE_SELECTOR_EXCEPTIONS.md` with
risk rationale and expiry dates.

---

## Migration 1: MFE Footer (footer_slot)

### Before (string surgery via apply-patches.sh — REMOVED in bead 1rns)

`infrastructure/tutor/apply-patches.sh` previously used Python string replacement:

```python
# REMOVED — bead 1rns
updated = updated.replace(
    "RenderWidget: <Footer />",
    "RenderWidget: <MerekaFooter />"
)
```

This was brittle: it depended on the exact string `RenderWidget: <Footer />` appearing in the
Tutor-generated `env.config.jsx`. Any whitespace or formatting change from upstream would
silently break the footer replacement.

### After (plugin slot registration in mereka_lms.py)

```python
# infrastructure/tutor/plugins/mereka_lms.py (active)
PLUGIN_SLOTS.add_item(
    (
        "footer_slot",
        {
            "keepDefault": False,
            "plugins": [
                {
                    "op": "PLUGIN_OPERATIONS.Replace",
                    "widget": {
                        "id": "mereka_footer",
                        "type": "DIRECT_PLUGIN",
                        "RenderWidget": "MerekaFooter",
                    },
                }
            ],
        },
    )
)
```

**Risk reduction**: From brittle string surgery (breaks on any upstream format change) to
declarative slot registration (survives upstream template reformatting).

---

## Migration 2: Header Logo (header_logo_slot)

### Before (CSS-only, mereka.scss)

The header logo branding relied exclusively on:

```scss
/* RISK: HIGH — .navbar .navbar-brand */
.navbar .navbar-brand {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-family: var(--mereka-font-heading);
  font-weight: 600;
  font-size: 1rem;
  color: var(--mereka-color-ink-900);
}

/* RISK: MEDIUM — img inside navbar-brand */
.navbar .navbar-brand img {
  height: 32px;
  width: auto;
}
```

This had no component-level override — only visual styling of Bootstrap's existing logo markup.

### After (plugin slot registration in mereka_lms.py)

```python
# infrastructure/tutor/plugins/mereka_lms.py (active)
PLUGIN_SLOTS.add_item(
    (
        "header_logo_slot",
        {
            "keepDefault": False,
            "plugins": [
                {
                    "op": "PLUGIN_OPERATIONS.Replace",
                    "widget": {
                        "id": "mereka_header_logo",
                        "type": "DIRECT_PLUGIN",
                        "RenderWidget": "MerekaHeaderLogo",
                    },
                }
            ],
        },
    )
)
```

The `.navbar .navbar-brand` CSS rule is retained as a **fallback** for builds where
`tutormfe.hooks.PLUGIN_SLOTS` is not yet available. Tagged `/* RISK: HIGH */` with a 2026-Q3
expiry in `MFE_SELECTOR_EXCEPTIONS.md`.

**Risk reduction**: Component-level slot registration is the primary path. CSS fallback degrades
gracefully (unstyled logo) rather than breaking layout.

---

## Migration 3: Learner Dashboard Sidebar (learner_dashboard.sidebar.v1)

### Before

No dedicated component injection — the sidebar CTA was attempted via scoped CSS:

```scss
/* RISK: HIGH — structural learner-dashboard layout scoping */
[data-testid*="learner-dashboard"],
[class*="learner-dashboard"] {
  background: transparent;
}
```

There was no mechanism to inject a Mereka-branded CTA panel into the dashboard sidebar.

### After (plugin slot registration in mereka_lms.py)

```python
# infrastructure/tutor/plugins/mereka_lms.py (active)
PLUGIN_SLOTS.add_item(
    (
        "learner_dashboard.sidebar.v1",
        {
            "keepDefault": True,
            "plugins": [
                {
                    "op": "PLUGIN_OPERATIONS.Append",
                    "widget": {
                        "id": "mereka_dashboard_sidebar_cta",
                        "type": "DIRECT_PLUGIN",
                        "RenderWidget": "MerekaDashboardSidebarCTA",
                    },
                }
            ],
        },
    )
)
```

The scoped background CSS remains as it is cosmetic only and does not create a structural
dependency. It is tagged RISK: HIGH in `mereka.scss` and documented in `MFE_SELECTOR_EXCEPTIONS.md`.

---

## AC-FRONT-024: String Surgery Removal Evidence

The `apply-patches.sh` file was audited for any remaining `updated.replace("RenderWidget`
patterns (the brittle string surgery approach). Result: **zero occurrences found**.

The removal was completed in bead 1rns. The current `apply-patches.sh` defines the
`MerekaFooter` component symbol in the mfe-env-config patch (so the component is available
in env.config.jsx), but the slot wiring is now done declaratively via `PLUGIN_SLOTS.add_item`,
not by string replacement.

Verification command:
```bash
grep 'updated\.replace.*RenderWidget' infrastructure/tutor/apply-patches.sh
# Expected output: (empty)
```

---

## Remaining Selector Exceptions

The following RISK: HIGH selectors could not be migrated (no upstream slot available):

| Selector | Risk | Reason | Expiry |
|----------|------|--------|--------|
| `.navbar` full styling | HIGH | No full-navbar slot in frontend-component-header | Bootstrap 6 |
| `.navbar .navbar-brand` (fallback) | HIGH | CSS fallback until PLUGIN_SLOTS confirmed live | 2026-Q3 |
| Authn surface scoping (`[class*="authn"]` etc.) | HIGH | No authn surface slot upstream | 2026-Q3 |
| Dashboard course card layout | HIGH | No `course_card.v1` slot upstream | 2026-Q3 |
| Learning image-cap flex sizing | HIGH | No Paragon Card.ImageCap slot | Paragon v22 |
| Learning media column guard | HIGH | No inner card media slot | 2026-Q3 |
| List vertical rhythm | HIGH | CSS spacing; no slot equivalent | 2026-Q3 |

Full rationale for each exception: `docs/operations/MFE_SELECTOR_EXCEPTIONS.md`.

---

## Runbook Note for Reviewers

**How to verify this is working at runtime:**

1. Deploy the MFE build with `tutormfe.hooks.PLUGIN_SLOTS` available.
2. Open the learner-facing MFE (e.g. learner dashboard).
3. Confirm:
   - Footer shows `MerekaFooter` (Mereka branding, 4-column layout, social icons).
   - Header logo area shows `MerekaHeaderLogo` (not Bootstrap default).
   - Dashboard sidebar has `MerekaDashboardSidebarCTA` appended below default content.
4. If `PLUGIN_SLOTS` is not available, the `_PLUGIN_SLOTS_AVAILABLE` flag will be `False`
   and the apply-patches.sh fallback path will engage (CSS + MerekaFooter in env.config.jsx).

**How to check which path is active:**
```bash
python3 -c "
import sys
sys.path.insert(0, 'infrastructure/tutor/plugins')
# If PLUGIN_SLOTS available: prints True
try:
    from tutormfe.hooks import PLUGIN_SLOTS
    print('PLUGIN_SLOTS available: True')
except ImportError:
    print('PLUGIN_SLOTS available: False (fallback path active)')
"
```

**Slot registration verification script:**
```bash
./scripts/qa/verify-selector-to-slot-migration.sh
```

---

## Files Changed in This Bead

| File | Change |
|------|--------|
| `infrastructure/tutor/plugins/mereka_lms.py` | Added 3 `PLUGIN_SLOTS.add_item` registrations (prior bead) |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | 17+ RISK: HIGH selectors tagged (prior bead) |
| `docs/operations/MFE_SELECTOR_EXCEPTIONS.md` | **NEW** — exception documentation (this bead) |
| `docs/operations/evidence/selector-to-slot-migration-diff.md` | **NEW** — this file (this bead) |
| `scripts/qa/verify-selector-to-slot-migration.sh` | **NEW** — verification script (this bead) |
| `.github/workflows/ci.yml` | **NEW** — `selector-to-slot-migration` CI job (this bead) |
