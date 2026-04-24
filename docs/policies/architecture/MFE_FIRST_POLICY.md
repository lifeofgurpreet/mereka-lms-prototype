# MFE-First Frontend Policy

_Audience: All Contributors • Last updated: 2026-02-17_

## Policy Statement

**All new learner-facing and operator-facing frontend changes MUST target Micro-Frontends (MFEs) or Frontend Plugin Framework (FPF) extension points (plugin slots), NOT new `edx-platform` Django templates or views.**

This policy applies to:
- New UI features
- Branding and theming changes
- Component replacements (headers, footers, sidebars)
- Interactive functionality additions

## Rationale

- ADR-014 establishes the plugin-first (FPF slot-driven) architecture
- MFEs provide React-based, independently deployable frontends
- Plugin slots allow component injection without forking MFE repositories
- Django templates are legacy and will be progressively replaced

## MFE Route Ownership

These URL paths are owned by MFEs and MUST NOT have new Django template overrides:

| Path | MFE | Plugin Slots Available |
|------|-----|-----------------------|
| `/authn/*` | frontend-app-authn | header_slot, footer_slot, login_component |
| `/account/*` | frontend-app-account | header_slot, footer_slot, additional_profile_fields |
| `/learning/*` | frontend-app-learning | header_slot, footer_slot, sequence_container_slot, course_breadcrumbs, learner_tools, progress_certificate_status |
| `/learner-dashboard/*` | frontend-app-learner-dashboard | header_slot, footer_slot, course_card_action, widget_sidebar, no_courses_view |
| `/discussions/*` | frontend-app-discussions | header_slot, footer_slot |
| `/profile/*`, `/u/*` | frontend-app-profile | header_slot, footer_slot, additional_profile_fields |
| `/course-authoring/*`, `/authoring/*` | frontend-app-course-authoring | header_slot, studio_footer, course_outline_header_actions, page_banner, course_unit_header_actions |
| `/gradebook/*` | frontend-app-gradebook | header_slot, footer_slot |
| `/communications/*` | frontend-app-communications | header_slot, footer_slot |
| `/ora-grading/*` | frontend-app-ora-grading | header_slot, footer_slot |

**Full slot catalog**: `docs/reference/architecture/MFE_PLUGIN_SLOT_INVENTORY.md` (100+ slots across 14 MFEs)

## Extension Points

When adding new UI functionality:

1. **First choice**: Use an existing FPF plugin slot (see inventory)
2. **Second choice**: Create a new plugin slot in the MFE (contribute upstream or fork)
3. **Third choice**: SCSS/CSS override via theme tokens
4. **Last resort**: Django template change (requires exception, see below)

### How to Use Plugin Slots

Plugin slots are registered in `infrastructure/tutor/plugins/mereka_lms.py` via:
```python
PLUGIN_SLOTS.add_item(("slot_name", { "keepDefault": False, "plugins": [...] }))
```

The `MerekaFooter` component is the canonical example of slot-based customization (footer_slot).

**Example**: Custom footer via plugin-slot

```python
# In infrastructure/tutor/plugins/mereka_lms.py
from tutormfe.hooks import PLUGIN_SLOTS

PLUGIN_SLOTS.add_item({
    "footer_slot": {
        "plugins": [{
            "op": "PLUGIN_OPERATIONS.Replace",
            "widget": {
                "id": "mereka_footer",
                "type": "DIRECT_PLUGIN",
                "RenderWidget": "MerekaFooter",
                "content": {
                    "src": "/openedx/app/plugins/MerekaFooter.jsx"
                }
            }
        }]
    }
})
```

See `docs/reference/architecture/FOOTER_V2_TO_LMS_MAPPING.md` for the complete footer slot wiring example.

## Exceptions (AC-UIMFE-003)

Django template or edx-platform view changes are permitted ONLY when:

### Legitimate Exception Cases

| Case | Example | Justification |
|------|---------|---------------|
| LMS root-domain pages with no MFE equivalent | `/courses/` catalog, `/about` pages | No MFE serves these routes |
| Django admin pages | `/admin/` | Admin UI is inherently Django |
| Email templates | `lms/templates/emails/` | Not rendered in browser |
| Server-rendered error pages | 404, 500 templates | Must work without JS |
| LMS/Studio core pages not yet migrated to MFE | Some Studio pages | Migration in progress |

### Current Known Exceptions

| File | Reason | Migration Plan |
|------|--------|---------------|
| `infrastructure/tutor/themes/mereka/lms/templates/footer.html` | LMS root-domain footer (non-MFE pages) | Will be superseded by MFE footer_slot |
| `infrastructure/tutor/themes/mereka/lms/templates/*.html` | Theme overrides for non-MFE LMS pages | Progressive migration |

### Exception Process

To add a Django template change when an MFE alternative could exist:

1. **Document why** in a bead comment or PR description
2. **Reference** which MFE route/slot was considered and why it was insufficient
3. **Get approval** from a reviewer who confirms the exception is warranted
4. **Track migration** — add to the "Current Known Exceptions" table with a migration plan

## Verification

```bash
# Check policy compliance
./scripts/qa/verify-mfe-first-policy.sh

# Search for policy keywords
rg -n "MFE-first|plugin slots|no new edx-platform frontend" docs/
```

## Related Documents

- **ADR-014**: `docs/programs/frontend/MFE_BRANDING_MIGRATION_DECISION.md` (plugin-first rationale)
- **Slot Inventory**: `docs/reference/architecture/MFE_PLUGIN_SLOT_INVENTORY.md` (100+ slots)
- **MFE Versions**: `docs/reference/architecture/MFE_VERSIONS.md` (active MFEs)
- **Footer Mapping**: `docs/reference/architecture/FOOTER_V2_TO_LMS_MAPPING.md` (slot example)
- **Branding Contract**: `docs/guides/branding/TENANT_BRANDING_CONTRACT.md`
