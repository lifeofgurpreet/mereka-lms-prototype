# MFE Surface Touchpoint Inventory

**Bead**: 2dcy.8
**AC**: AC-FRONT-081
**Last updated**: 2026-02-18
**Status**: Active

---

## Purpose

This document inventories all active MFE surface touchpoints for Mereka Academy,
covering LMS authn/apps/footer and tenant branding surfaces. Each row records
whether the surface is customized via plugin slot, CSS-only, or not customized.

---

## Surface Inventory

| Surface | Mechanism | File | Status |
|---------|-----------|------|--------|
| MFE Footer (all MFEs) | **slot-based** | `mereka_lms.py` → `footer_slot` | Active — `keepDefault: False`, replaces Indigo default |
| Header Logo | **slot-based** | `mereka_lms.py` → `header_logo_slot` | Active — `keepDefault: False`, replaces default logo |
| Learner Dashboard Sidebar CTA | **slot-based** | `mereka_lms.py` → `learner_dashboard.sidebar.v1` | Active — `keepDefault: True`, appended |
| Authn Shell (login/register background) | **CSS-only** | `mereka.scss` (EX-05) | Exception — no upstream authn surface slot; structural CSS only |
| Navbar styling | **CSS-only** | `mereka.scss` (EX-03, EX-04) | Exception — no full-navbar slot; Bootstrap 5 dependent |
| Course card layout (dashboard) | **CSS-only** | `mereka.scss` (EX-06) | Exception — no `course_card.v1` slot upstream yet |
| Badges / credential display | **not customized** | n/a | No Mereka override; uses Open edX defaults |
| Django Admin (`/admin/`) | **not customized** | n/a | Admin uses built-in Django footer; not an MFE surface |
| Studio CMS | **not customized** | n/a | Studio uses Paragon; no `env.config.jsx` footer slot |
| Body background | **CSS-only** | `mereka.scss` (EX-02) | Exception — `body` element; no slot equivalent |
| CSS custom properties (`:root`) | **CSS-only** | `mereka.scss` (EX-01) | Exception — design-token infrastructure; no slot equivalent |

---

## Slot-Based Surfaces Detail

### `footer_slot` (MFE Footer)

- **Registered in**: `infrastructure/tutor/plugins/mereka_lms.py`
- **`keepDefault`**: `False` (replaces Indigo/OpenedX default footer)
- **Operation**: `PLUGIN_OPERATIONS.Replace`
- **Widget ID**: `mereka_footer`
- **Component**: `MerekaFooter` (defined inline in `mfe-env-config` patch)
- **Host variants handled**:
  - `academyv2.mereka.io` → Mereka Academy brand
  - `academy.biji-biji.com` → Biji-Biji Academy brand
  - `skillourfuture.academy.mereka.io` → Skill Our Future Academy brand
- **MFE coverage**: authn, learner-dashboard, learning, course-authoring, profile

### `header_logo_slot` (Header Logo)

- **Registered in**: `infrastructure/tutor/plugins/mereka_lms.py`
- **`keepDefault`**: `False` (replaces default MFE header logo)
- **Operation**: `PLUGIN_OPERATIONS.Replace`
- **Widget ID**: `mereka_header_logo`
- **Component**: `MerekaHeaderLogo`
- **CSS fallback**: `.navbar .navbar-brand` (EX-04 — RISK: HIGH, expiry 2026-Q3)

### `learner_dashboard.sidebar.v1` (Dashboard Sidebar CTA)

- **Registered in**: `infrastructure/tutor/plugins/mereka_lms.py`
- **`keepDefault`**: `True` (appends, does not replace)
- **Operation**: `PLUGIN_OPERATIONS.Append`
- **Widget ID**: `mereka_dashboard_sidebar_cta`
- **Component**: `MerekaDashboardSidebarCTA`

---

## CSS-Only Exception Count

**Total exception entries**: 10 (EX-01 through EX-10)

See `docs/policies/architecture/MFE_SELECTOR_EXCEPTIONS.md` for the full exception inventory
with risk levels, rationale, and expiry dates.

| Risk level | Count |
|------------|-------|
| LOW | 3 (EX-01, EX-02, EX-10 group) |
| HIGH | 7 (EX-03 through EX-09) |

---

## Related Documents

- `docs/policies/architecture/MFE_SELECTOR_EXCEPTIONS.md` — CSS exception inventory
- `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md` — Full migration register
- `infrastructure/tutor/plugins/mereka_lms.py` — Canonical slot registrations
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss` — CSS overrides source
- `docs/archive/evidence/operations/evidence/selector-to-slot-migration-diff.md` — Before/after diff
