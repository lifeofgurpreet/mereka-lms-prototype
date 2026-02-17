# MFE Plugin-Slot Compatibility Matrix

**Purpose**: Operational compatibility matrix view of plugin-slot wiring, mapping Mereka Academy's MFE customization strategy to FPF (Frontend Plugin Framework) extension points.

**Canonical Inventory**: [MFE_PLUGIN_SLOT_INVENTORY.md](../architecture/MFE_PLUGIN_SLOT_INVENTORY.md) — This document is a derived view focused on operational planning and migration tracking.

**Last updated**: 2026-02-17
**Covers**: Bead 1aj1 AC-UISLOT-001 through AC-UISLOT-005

---

## Active Plugin-Slot Wiring Matrix

This table lists all plugin slots currently wired by Mereka Academy or inherited from Indigo theme.

| Slot ID | Target MFE | Operation Type | Plugin Type | Owner | Rollout Priority | Status |
|---------|-----------|----------------|-------------|-------|------------------|--------|
| `org.openedx.frontend.layout.footer.v1` | All MFEs (shared) | Replace | Direct | Mereka | P0 (Live) | **ACTIVE** |
| `desktop_secondary_menu_slot` | account, discussions, learner-dashboard, profile | Insert | Direct | Indigo | N/A | INDIGO |
| `mobile_header_slot` | account, discussions, learner-dashboard, profile | Replace | Direct | Indigo | N/A | INDIGO |
| `learning_help_slot` | frontend-app-learning | Insert | Direct | Indigo | N/A | INDIGO |
| `org.openedx.frontend.layout.header_logo.v1` | Header (all MFEs) | Replace | Direct | Mereka (proposed) | P1 | AVAILABLE |
| `org.openedx.frontend.layout.studio_footer.v1` | Frontend-app-authoring | Replace | Direct | Mereka (proposed) | P1 | AVAILABLE |
| `org.openedx.frontend.authn.login_component.v1` | Frontend-app-authn | Insert | Direct | Mereka (proposed) | P1 | AVAILABLE |
| `org.openedx.frontend.learner_dashboard.widget_sidebar.v1` | Frontend-app-learner-dashboard | Insert | Direct | Mereka (proposed) | P2 | AVAILABLE |
| `org.openedx.frontend.learner_dashboard.no_courses_view.v1` | Frontend-app-learner-dashboard | Replace | Direct | Mereka (proposed) | P2 | AVAILABLE |
| `ProgressCertificateStatusSlot` | Frontend-app-learning | Insert | Direct | Mereka (proposed) | P2 | AVAILABLE |

**Legend**:
- **ACTIVE**: Mereka overrides deployed in production
- **INDIGO**: Inherited from Indigo theme, not customized
- **AVAILABLE**: Slot exists upstream, ready for wiring

---

## env.config.jsx Migration Map (AC-UISLOT-002)

This section maps current hardcoded customizations in `env.config.jsx` to their plugin-slot equivalents. All future customizations should use the plugin-slot approach instead of direct React component overrides.

### Current Hardcoded Customizations → Slot Equivalents

| Current Approach | File/Location | Slot-Based Equivalent | Migration Path |
|------------------|---------------|----------------------|----------------|
| Direct footer component override | `mereka_lms.py` RenderWidget swap | `org.openedx.frontend.layout.footer.v1` | **COMPLETE** — Dual-path wiring (RenderWidget + PLUGIN_SLOTS.add_item) |
| Dark mode toggle (Indigo) | Generated `env.config.jsx` | `desktop_secondary_menu_slot` | No action needed (inherited) |
| Mobile header override (Indigo) | Generated `env.config.jsx` | `mobile_header_slot` | No action needed (inherited) |
| Learning help button (Indigo) | Generated `env.config.jsx` | `learning_help_slot` | No action needed (inherited) |
| Custom logo (planned) | Manual CSS override | `org.openedx.frontend.layout.header_logo.v1` | Replace CSS with slot-based React component |
| Studio footer branding (planned) | N/A | `org.openedx.frontend.layout.studio_footer.v1` | Extend MerekaFooter to Studio context |
| Login banner (planned) | N/A | `org.openedx.frontend.authn.login_component.v1` | Create BannerWidget for auth flow |

### Migration Checklist

When migrating a hardcoded customization to plugin-slot wiring:

1. Identify the target slot from [MFE_PLUGIN_SLOT_INVENTORY.md](../architecture/MFE_PLUGIN_SLOT_INVENTORY.md)
2. Choose operation type: `Insert` (add before/after), `Replace` (full override), or `Hide` (remove default)
3. Implement React component in `infrastructure/tutor/plugins/mereka_lms.py` mfe-env-config patch
4. Wire slot via `config['pluginSlots'][SLOT_ID] = { op: PLUGIN_OPERATIONS.X, widget: ComponentName }`
5. Apply patches: `./infrastructure/tutor/apply-patches.sh`
6. Rebuild MFE: `tutor images build mfe`
7. Verify slot wiring: `./scripts/qa/verify-plugin-slot-wiring.sh`
8. Remove old hardcoded approach (if applicable)

---

## Direct vs iFrame Plugin Decision Rules (AC-UISLOT-003)

**Default**: Use **Direct** plugin type unless explicitly justified.

| Plugin Type | When to Use | Pros | Cons | Example Use Case |
|-------------|-------------|------|------|------------------|
| **Direct** | Default for all Mereka widgets | Full React integration, type safety, no network overhead | Requires MFE rebuild to update | Footer, header logo, dashboard widgets |
| **iFrame** | Third-party embeds, external services, security isolation | No rebuild needed, sandboxed execution | Poor UX (scrolling, loading delays), no shared state | External analytics dashboards, partner content embeds |

### Direct Plugin Type Justification Checklist

Before choosing iFrame, verify all of the following are true:

- [ ] Widget content is served from external domain (not Mereka-controlled)
- [ ] Widget requires security isolation from main MFE context
- [ ] Widget updates frequently and rebuild cycle is unacceptable
- [ ] UX degradation (loading delay, scroll issues) is acceptable for this use case

**If ANY checkbox is unchecked**, use Direct plugin type.

### Approved iFrame Use Cases

None currently approved for Mereka Academy.

---

## Plugin-Slot Discovery Methods (AC-UISLOT-004)

Plugin slots are discovered through multiple methods. This section documents the evidence-based discovery process.

### 1. Source Code Inspection (Primary Method)

Each MFE repository contains a `/src/plugin-slots` directory with slot definitions:

```bash
# Clone MFE repo
git clone https://github.com/openedx/frontend-component-footer.git
cd frontend-component-footer

# List slot definitions
ls -1 src/plugin-slots/
# Output:
# FooterSlot/
# StudioFooterSlot/
```

**Evidence Links**:
- [frontend-component-footer/src/plugin-slots](https://github.com/openedx/frontend-component-footer/tree/master/src/plugin-slots)
- [frontend-component-header/src/plugin-slots](https://github.com/openedx/frontend-component-header/tree/master/src/plugin-slots)
- [frontend-app-learning/src/plugin-slots](https://github.com/openedx/frontend-app-learning/tree/master/src/plugin-slots)

### 2. Runtime Grep (Built Images)

Search compiled MFE JavaScript bundles for `PluginSlot` references:

```bash
# In a running MFE container
docker exec tutor_local_mfe_1 grep -r "PluginSlot" /openedx/dist/*/static/js/*.js | head -10

# During local development
grep -r "PluginSlot" node_modules/@openedx/*/src/ 2>/dev/null
```

### 3. Official Documentation

- [Open edX Plugin Slots Browser](https://discuss.openedx.org/t/open-edx-plugin-slots-browser/18407) — Community-maintained slot catalog
- [How to Use Frontend Plugin Slots](https://docs.openedx.org/en/latest/site_ops/how-tos/use-frontend-plugin-slots.html) — Official operator guide
- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html) — Architecture specification

### 4. Tutor-Generated env.config.jsx

After `tutor config save`, inspect the generated config:

```bash
grep -A5 "pluginSlots" tutor_env/env/plugins/mfe/build/mfe/env.config.jsx
```

This shows all slots wired by Tutor core + Indigo theme.

### 5. Automated Verification

Run the plugin-slot wiring verification script:

```bash
./scripts/qa/verify-plugin-slot-wiring.sh
```

This cross-references:
- Plugin definitions in `mereka_lms.py`
- Patch script changes in `apply-patches.sh`
- Canonical inventory in `docs/architecture/MFE_PLUGIN_SLOT_INVENTORY.md`

---

## Slot Naming Conventions

Open edX uses two naming conventions. Always use the **namespaced ID** in `env.config.jsx`:

| Convention | Example | Where Used |
|-----------|---------|------------|
| **Namespaced** (official) | `org.openedx.frontend.layout.footer.v1` | Source code `<PluginSlot id="...">`, `env.config.jsx` |
| **Shorthand** | `footer_slot` | `tutormfe.hooks.PLUGIN_SLOTS` (Python hook), legacy Indigo configs |

**Critical**: Mismatching conventions causes silent failures (slot not found, default content rendered).

---

## References

- **Canonical Inventory**: [MFE_PLUGIN_SLOT_INVENTORY.md](../architecture/MFE_PLUGIN_SLOT_INVENTORY.md)
- **ADR-014**: [MFE Branding Strategy](../adr/014-mfe-branding-strategy.md)
- **Verification Script**: [verify-plugin-slot-wiring.sh](../../scripts/qa/verify-plugin-slot-wiring.sh)
- **OEP-65**: [Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html)
- **Footer Slot Verification**: [verify-mfe-footer-slot.sh](../../scripts/qa/verify-mfe-footer-slot.sh)
