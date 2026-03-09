---
title: "MFE Plugin Slots: FPF Slot Activation Roadmap"
type: "feature_spec"
status: "draft"
version: "1.0.0"
owner: "engineering"
id: "SPEC-FE-PLUGIN-SLOTS"
spec_class: "integration"
created: "2026-02-27"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "frontend"
normativity: "normative"
supersedes: []
superseded_by: null
verification_sources:
  - "tests"
  - "manual-verification"
interfaces:
  - "frontend-plugin-framework"
  - "openedx-mfe-runtime"
tags:
  - "frontend.composition"
  - "frontend.brand.tokens"
summary: "Defines which Open edX MFE plugin slots Mereka activates, how they are phased, and the supported extension model."
vehicle: "talent_platform"
last_updated: "2026-02-27"
depends_on:
  - "specs/branding-system_spec.md"
links:
  related_docs:
    - "docs/guides/branding/BRANDING.md"
    - "docs/guides/branding/BRANDING_OPERATING_MODEL.md"
    - "docs/ops/runbooks/MFE_PLUGIN_SLOTS_RUNBOOK.md"
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/oep48-brand-package_spec.md"
---

# Human Summary

## What is changing

Mereka Academy currently activates exactly one FPF (Frontend Plugin Framework) slot: the footer (`org.openedx.frontend.layout.footer.v1`), which replaces the default Indigo footer with a custom MerekaFooter component across all MFEs. Open edX provides approximately 130+ plugin slots across its micro-frontends, and this spec defines which additional slots to activate, in what order, and why.

The activation pattern is already proven: `infrastructure/tutor/plugins/mereka_lms.py` uses `tutormfe.hooks.PLUGIN_SLOTS.add_items()` to register slot overrides, and `mfe-env-config-runtime-definitions` patches inject component definitions into `env.config.jsx`. No MFE forks are required. No custom React component library is needed. Every new slot activation follows this exact same pattern.

This spec covers three rollout phases:
1. **Phase 1 (Header Branding)**: Replace stock Open edX logos in desktop and mobile headers, add Mereka-specific navigation items.
2. **Phase 2 (Learning Experience)**: Brand the course player and outline sidebar in the Learning MFE.
3. **Phase 3 (Account & Profile)**: Add enterprise profile fields and Mereka-branded profile sections.

## Why

Brand consistency is a trust signal for learners and partners. Today the footer is fully branded, but the header still shows the generic Open edX logo on desktop and mobile. The course player and account pages also lack Mereka branding. Every unbranded touchpoint signals an unfinished product.

Using FPF slots instead of MFE forks is the strategic decision (ADR-014): it keeps the upgrade path clean, avoids maintaining fork divergence, and lets us adopt upstream improvements automatically. The footer slot migration proved this pattern works reliably.

## Success looks like

- Every page across all MFEs displays the Mereka logo in the header (desktop and mobile) with zero Open edX default logo leakage.
- Navigation includes Mereka-specific links (dashboard, catalog, support) rather than stock items.
- Course player pages show Mereka branding in outline sidebar.
- Account profile pages include enterprise-specific fields where configured.
- All slot activations are implemented entirely via `mereka_lms.py` plugin configuration with zero MFE forks.
- Visual regression tests catch any slot rendering regressions before production.

---

# Agent Contract

## Scope

### In Scope

- Activation of header branding slots: `desktop_logo_slot`, `mobile_logo_slot` (or equivalent canonical slot IDs)
- Activation of header navigation slots: `desktop_main_menu_slot` (or equivalent)
- Activation of Learning MFE slots: sequence navigation, course outline sidebar
- Activation of Account MFE slots: additional profile fields
- Component definitions added via `mfe-env-config-runtime-definitions` patch in `mereka_lms.py`
- Slot registrations via `PLUGIN_SLOTS.add_items()` in `mereka_lms.py`
- Visual regression test strategy for each activated slot
- Phased rollout plan (Phase 1, 2, 3)
- Verification scripts for slot activation

### Out of Scope

- Custom MFE forks or custom React component library (zero-fork constraint)
- Module Federation (OEP-65) — future architecture, not available in Tutor v21
- iFrame-based plugins (deprecated approach)
- Backend API changes to support slot content
- MFE build pipeline changes (Dockerfile, webpack config) — covered by branding-system_spec
- Footer slot (already activated and covered by branding-system_spec)
- Slot activation for MFEs not currently deployed (e.g., ora-grading, communications)

## Non-goals

- Building a custom React component library. All components MUST be inline JSX defined in `mfe-env-config-runtime-definitions` patches, matching the proven MerekaFooter pattern.
- Adopting Module Federation (OEP-65). This spec uses the FPF `PLUGIN_SLOTS` API exclusively.
- Forking any MFE repository. All customization MUST be achievable via Tutor plugin hooks and `env.config.jsx` configuration.
- Building a generic slot management UI. Slot activations are code-reviewed configuration in `mereka_lms.py`.
- Supporting dynamic per-tenant slot content in this phase. Tenant-aware slot content (e.g., different logos per site) is handled by runtime hostname detection in the component, matching the existing MerekaFooter `SITE_VARIANTS` pattern.

## Acceptance Criteria

### Phase 1: Header Branding

- [ ] AC-SLOT-001: Given the Mereka LMS plugin is active, when any MFE page loads on desktop, then the header displays the Mereka logo (from `/static/images/logo-horizontal.svg` or equivalent brand asset) instead of the default Open edX logo.
- [ ] AC-SLOT-002: Given the Mereka LMS plugin is active, when any MFE page loads on a mobile viewport, then the mobile header displays the Mereka square logo (from `/static/images/logo-square.png` or equivalent) instead of the default Open edX mobile logo.
- [ ] AC-SLOT-003: Given the header logo slot is activated, when a user clicks the logo on desktop or mobile, then the user is navigated to the LMS dashboard (`/dashboard`), not the Open edX default homepage.
- [ ] AC-SLOT-004: Given the header logo slot is activated for multi-site, when a user visits `academy.biji-biji.com`, then the header displays the Biji-Biji branded logo variant (matching `SITE_VARIANTS` hostname lookup pattern from MerekaFooter).
- [ ] AC-SLOT-005: Given the desktop main menu slot is activated, when a user views the header navigation on desktop, then the menu includes Mereka-specific items: "Dashboard", "Discover Courses", and "Support" (linking to `helpUrl` from `SITE_VARIANTS`).
- [ ] AC-SLOT-006: Given the desktop main menu slot is activated, when a user views the header on a mobile viewport, then the navigation items are accessible via the mobile menu/hamburger and match the desktop items.
- [ ] AC-SLOT-007: Given all Phase 1 slots are activated, when the MFE image is built, then the build completes without errors and the `env.config.jsx` contains slot registrations for `desktop_logo_slot`, `mobile_logo_slot`, and `desktop_main_menu_slot` (or their canonical FPF IDs).

### Phase 2: Learning MFE

- [ ] AC-SLOT-008: Given the Learning MFE is loaded, when a learner views a course unit, then the course outline sidebar displays Mereka branding (brand color accents, Mereka logo in sidebar header) via the course outline sidebar slot.
- [ ] AC-SLOT-009: Given the Learning MFE is loaded, when a learner navigates between course units, then the sequence navigation area renders with Mereka-branded styling (progress indicators use brand primary color) via a sequence navigation slot or CSS override injected through the slot.
- [ ] AC-SLOT-010: Given a course has no custom course image, when the learner views the course outline sidebar, then the default placeholder uses Mereka brand colors rather than the Open edX default gray.
- [ ] AC-SLOT-011: Given all Phase 2 slots are activated, when the Learning MFE image is built, then the build completes without errors and the slot registrations are present in `env.config.jsx`.

### Phase 3: Account & Profile

- [ ] AC-SLOT-012: Given the Account MFE is loaded, when a user views their profile settings, then additional enterprise profile fields (organization, job title, department) are rendered via the `additional_profile_fields_slot` (or canonical FPF ID).
- [ ] AC-SLOT-013: Given the Profile MFE is loaded, when any user views a public profile, then the profile page header section shows Mereka branding (brand colors, logo) via the appropriate profile header slot.
- [ ] AC-SLOT-014: Given enterprise profile fields are activated, when a user saves their profile with the additional fields populated, then the values persist and are retrievable via the user profile API (`/api/user/v1/accounts`).
- [ ] AC-SLOT-015: Given all Phase 3 slots are activated, when the Account and Profile MFE images are built, then the builds complete without errors and slot registrations are present in `env.config.jsx`.

### Slot Activation Pattern

- [ ] AC-SLOT-016: Given any new slot activation, when the slot is registered in `mereka_lms.py`, then the registration MUST follow the established pattern: `PLUGIN_SLOTS.add_items()` with a tuple of `(mfe_name, slot_id, operations_string)` where the operations string uses `PLUGIN_OPERATIONS.Hide` (for default content removal) and/or `PLUGIN_OPERATIONS.Insert` (for custom widget injection).
- [ ] AC-SLOT-017: Given any new slot activation requiring a custom component, when the component is defined, then it MUST be defined in a `mfe-env-config-runtime-definitions` ENV_PATCH (inline JSX), not in an external file or forked MFE.
- [ ] AC-SLOT-018: Given a slot activation targets a multi-site deployment, when the component renders on different hostnames (`academyv2.mereka.io`, `academy.biji-biji.com`, `skillourfuture.academy.mereka.io`), then the component MUST use the `SITE_VARIANTS` hostname-lookup pattern to select tenant-appropriate content.
- [ ] AC-SLOT-019: Given the `"all"` MFE target is used for a slot registration, when the slot exists in multiple MFEs, then the slot override applies to every MFE that defines that slot ID.
- [ ] AC-SLOT-020: Given an MFE does not define a particular slot ID, when the plugin registers an override for that slot, then the MFE MUST build and render without errors (graceful no-op).

### Testing Strategy

- [ ] AC-SLOT-021: Given a slot activation is deployed, when the visual regression test suite runs, then screenshots of pages containing the activated slot are captured and compared against approved baselines.
- [ ] AC-SLOT-022: Given a new slot activation PR is submitted, when CI runs, then a verification script (`scripts/qa/verify-mfe-plugin-slots.sh`) confirms that the expected slot IDs are registered in the generated `env.config.jsx`.
- [ ] AC-SLOT-023: Given all Phase 1 slots are activated, when a smoke test hits the LMS homepage, authn login page, and learner dashboard, then no page renders the default Open edX logo in the header.
- [ ] AC-SLOT-024: Given a slot activation causes a build failure, when the MFE build is attempted, then the build error message identifies the failing slot ID and component name to enable rapid debugging.

### Non-Functional Requirements

- [ ] AC-SLOT-025: Given any slot component is rendered, when the page loads, then the slot component MUST render within 100ms of the parent slot container mounting (no perceptible delay vs. the default widget).
- [ ] AC-SLOT-026: Given all activated slots across all MFEs, when the total bundle size is measured, then the incremental JavaScript added by slot components MUST NOT exceed 15KB gzipped (inline JSX components are small by design).
- [ ] AC-SLOT-027: Given any slot component, when rendered on screen sizes from 320px to 1920px wide, then the component MUST be responsive and not cause layout overflow or horizontal scrolling.

**Cross-Cutting Inheritance**: This spec inherits requirements from `specs/cross-cutting-requirements_spec.md` including:
- Observability baseline (metrics, logs, traces, dashboards, alerts)
- Tenant isolation (multi-site hostname detection)
- Common NFR thresholds (latency, availability)

Only domain-specific NFRs are listed above.

### Cross-Spec Integration

#### Branding System (specs/branding-system_spec.md)

- [ ] AC-SLOT-028: Given the branding system provides logo assets at the paths specified in branding-system_spec (logo.png, logo-horizontal.svg, logo-square.png, logo-horizontal-white.png), when header slots reference these assets, then the logos render correctly without 404 errors.
- [ ] AC-SLOT-029: Given the branding system's Google Fonts stripping is active, when header and learning slot components render, then no Google Fonts requests are generated by slot components.

## Dependencies

### Upstream

- **specs/branding-system_spec.md**: Logo assets, font files, SCSS variables, and the `SITE_VARIANTS` data contract. MUST be completed (status: completed) before Phase 1 begins.
- **Tutor v21+ (Ulmo)**: The `tutormfe.hooks.PLUGIN_SLOTS` API. Already deployed.
- **frontend-plugin-framework >= 1.8.0**: Installed in MFE Dockerfile. Already deployed.

### Downstream

- **Future OEP-48 brand package**: When adopted, slot components will source assets from the brand package rather than `/static/images/` paths. This spec's `SITE_VARIANTS` pattern remains valid.
- **Multi-tenancy white-labeling**: Will extend the `SITE_VARIANTS` pattern to dynamically configure slot content per tenant. This spec establishes the foundation.

## Requirements

### Functional

- The system MUST activate header branding slots to replace the default Open edX logo with Mereka brand assets on all MFE pages.
- The system MUST activate header navigation slots to provide Mereka-specific navigation links.
- The system SHOULD activate Learning MFE slots to brand the course player experience.
- The system SHOULD activate Account and Profile MFE slots to support enterprise profile fields.
- The system MUST use the `PLUGIN_SLOTS.add_items()` API exclusively — no MFE forks, no manual `env.config.jsx` string surgery.
- The system MUST support multi-site branding via the `SITE_VARIANTS` hostname-lookup pattern in every slot component.
- The system MUST define all custom components as inline JSX in `mfe-env-config-runtime-definitions` patches.
- The system SHOULD use `PLUGIN_OPERATIONS.Hide` to remove default content before inserting custom content, preventing dual-render.

### Non-Functional Requirements

- Slot components MUST render within 100ms of container mount.
- Total incremental bundle size from slot components MUST NOT exceed 15KB gzipped.
- All slot components MUST be WCAG 2.1 AA accessible (keyboard navigable, screen-reader compatible, sufficient color contrast).
- Slot component failures MUST NOT crash the host MFE — components SHOULD use React error boundaries or equivalent defensive patterns.

## Edge Cases

- **Slot ID rename in upstream Open edX**: If a future Open edX release renames a slot ID (e.g., `header_logo_slot` becomes `org.openedx.frontend.header.logo.v2`), the old registration becomes a no-op (AC-SLOT-020). Detection depends on visual regression tests (AC-SLOT-021) and the verification script (AC-SLOT-022).
- **Component render failure**: If an inline JSX component throws during render, the slot SHOULD fall back to the default widget rather than showing a blank area. The FPF framework handles this natively for `DIRECT_PLUGIN` type widgets.
- **Missing brand assets (404)**: If a logo URL returns 404 (e.g., CDN issue, misconfigured static files), the component SHOULD display a text-only brand name fallback (matching `siteName` from config).
- **Build failure from slot registration**: If a slot operation string contains a syntax error, the MFE build fails entirely. The verification script (AC-SLOT-022) catches this in CI before merge.
- **Concurrent slot registrations from multiple plugins**: If another Tutor plugin registers operations on the same slot ID, `PLUGIN_SLOTS.add_items()` appends operations in plugin load order. The Mereka plugin SHOULD use explicit `priority` values to ensure deterministic ordering.
- **Large SITE_VARIANTS object**: As tenants grow, the `SITE_VARIANTS` object increases bundle size. At current scale (3 tenants), this is negligible. Beyond 20 tenants, consider loading tenant config from an API endpoint.

## Observability

### Metrics

- `mereka_mfe_slot_render_count{slot_id, mfe, hostname}`: Counter of slot component renders (emitted via `window.performance.mark` if slot components instrument this).
- No backend metrics required — slot activation is purely frontend.

### Alerts

- **Visual regression failure**: CI alert when visual regression screenshots differ beyond threshold. Severity=medium.
- **MFE build failure**: Existing CI alert covers this. No additional alert needed.

### Dashboards

- No new Grafana dashboard required. MFE build status is tracked in existing CI dashboard.
- Visual regression results are tracked in CI artifacts.

## Verification

### Automated Verification

Add verification scripts to `scripts/qa/` with `@covers` annotations:

```bash
#!/usr/bin/env bash
# @covers AC-SLOT-007, AC-SLOT-011, AC-SLOT-015, AC-SLOT-022
# @spec: mfe-plugin-slots_spec

set -euo pipefail
# Verify slot registrations exist in generated env.config.jsx
# Verify PLUGIN_SLOTS.add_items() calls in mereka_lms.py
```

Run coverage report:
```bash
scripts/qa/spec-tools/ac-coverage-report.py
```

### Manual Verification

1. Load each MFE page (authn, dashboard, learning, account, profile) and visually confirm Mereka branding in header, navigation, and phase-specific areas.
2. Load each page on mobile viewport (375px width) and confirm responsive rendering.
3. Load on `academy.biji-biji.com` domain and confirm tenant-specific branding displays.

### Test Plan

See `specs/plans/mfe-plugin-slots_test_plan.md` for comprehensive test scenarios (to be created when implementation begins).

## Configuration

### Environment Variables

No new environment variables required. Slot activation is configured entirely in `mereka_lms.py` plugin code.

### Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| N/A | N/A | Slot activations are controlled by code presence in `mereka_lms.py`. To disable a slot, remove or comment out the `PLUGIN_SLOTS.add_items()` call. No runtime feature flag mechanism exists in FPF. |

## Rollout & Rollback

### Rollout Plan

| Phase | Slots | Timeline | Gate |
|-------|-------|----------|------|
| **Phase 1** | Desktop logo, mobile logo, desktop main menu | First | Visual regression baseline + smoke test pass |
| **Phase 2** | Course outline sidebar, sequence navigation styling | After Phase 1 stable for 1 week | Learning MFE visual regression pass |
| **Phase 3** | Additional profile fields, profile header | After Phase 2 stable for 1 week | Account/Profile MFE visual regression pass |

### Rollback Steps

1. **Per-slot rollback**: Comment out or remove the specific `PLUGIN_SLOTS.add_items()` block in `mereka_lms.py` for the failing slot.
2. **Full rollback**: Revert the `mereka_lms.py` file to the previous commit and rebuild MFE images.
3. **Emergency (no rebuild)**: Slot content is baked into the MFE image at build time. To rollback without rebuilding, redeploy the previous MFE image tag from the container registry.
4. **Backward compatibility**: Removing a slot registration restores the default FPF widget. No data migration or state cleanup is needed.

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Upstream slot ID rename breaks registration | Medium (slot silently becomes no-op, default content shows) | Low | Visual regression tests detect missing branding; verification script checks slot IDs against known upstream list |
| Inline JSX component grows too complex for `mfe-env-config-runtime-definitions` | Medium (maintenance burden, hard to debug) | Medium | Enforce max 80 lines per component. If exceeded, evaluate OEP-48 brand package or external component approach |
| FPF version incompatibility after Tutor upgrade | High (all slot activations break) | Low | Pin `frontend-plugin-framework >= 1.8.0` in MFE Dockerfile; test slot rendering after every Tutor version bump |
| Multiple plugins competing for same slot | Low (unpredictable render order) | Low | Use explicit `priority` values; document slot ownership in plugin comments |
| `SITE_VARIANTS` duplication across footer and header components | Medium (inconsistency risk) | High | Extract `SITE_VARIANTS` into a shared runtime definition injected once, referenced by all components |

## Open Questions

- [ ] What are the exact canonical FPF slot IDs for header logo in the current Open edX Ulmo release? The codebase references `header_logo_slot` but upstream may use a fully-qualified form like `org.openedx.frontend.header.desktop_logo.v1`. Needs verification against `frontend-component-header` source.
- [ ] Does the Learning MFE `CourseOutlineSidebarSlot` support `PLUGIN_OPERATIONS.Insert` alongside existing content, or only `Replace`? Determines whether we can add branding without removing the outline.
- [ ] Should `SITE_VARIANTS` be extracted into a shared module injected once via `mfe-env-config-runtime-definitions`, or duplicated per component? The footer already has its own copy. Shared module reduces duplication but adds coupling.
- [ ] Are the enterprise profile fields (organization, job title, department) already supported by the Open edX user profile API, or do they require backend `UserProfile` model extensions?
- [ ] What visual regression tool should be used? Options: Playwright screenshot comparison (already in CI), Percy, Chromatic. Need to decide before Phase 1 implementation.
