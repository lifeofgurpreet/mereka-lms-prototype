# Frontend Phase D: MFE Slot Branding Stabilization

**Date**: 2026-02-28
**Prerequisite**: Phase C complete (FE-010, FE-011, FE-012, FE-015 prepared)
**Specs**: `specs/mfe-plugin-slots_spec.md`, `specs/paragon-design-tokens-migration_spec.md`

---

## Objective

Finalize the remaining high-friction front-end overrides by migrating brand-critical shell areas to Open edX Plugin Framework (FPF) slots, then lock the remaining legacy BEM overrides as non-fragile `var(--mereka-*)`-driven rules.

---

## Why this phase now

Recent token-coverage review shows Paragon v22 consumes only a subset of `--pgn-*` component tokens; many BEM overrides in `mereka.scss` must remain for visual parity. The highest-ROI path is to move these durable concerns into supported plugin slots:

1. Site header branding (logo + nav scaffold)
2. Site footer branding (copyright + links + logo)
3. Authn/login identity treatment where available

This reduces CSS fragility while preserving the new token-first runtime model.

---

## Task D1: Inventory & classify overrides for slot migration

1. Open `docs/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md` and `infrastructure/tutor/themes/mereka/mfe/mereka.scss`.
2. Mark each override as:
   - **SAFE_TO_SLOT**: header/footer/authn areas that duplicate plugin-slot components.
   - **NEEDS_KEEP**: structural or deeply coupled CSS that stays in `mereka.scss` with var references.
3. Add/refresh a short note in the inventory file with a one-line rationale per migrated selector.

---

## Task D2: Implement header slot branding

1. In `infrastructure/tutor/plugins/mereka_lms.py`, confirm/extend `PLUGIN_SLOTS` usage for `org.openedx.frontend.layout.header_logo.v1` and nav/container slots.
2. Render React components that:
   - use canonical `/static/images/mereka-logo*` paths
   - keep existing brand text/ARIA labels
   - avoid hardcoded dimensions (pull from token vars where possible)
3. Remove or de-prioritize overlapping legacy BEM selectors that only handled logo/nav shell structure.
4. Add a fallback branch for unknown variants to avoid runtime render regressions.

---

## Task D3: Implement footer slot branding

1. In `infrastructure/tutor/plugins/mereka_lms.py`, confirm/extend `PLUGIN_SLOTS` for `org.openedx.frontend.layout.footer.v1`.
2. Keep links/labels sourced from the same config map used by current footer scss (branding text, support/terms, copyright).
3. Preserve legacy behavior for non-Mereka tenants where explicit mapping is absent.
4. Keep BEM footer rules only for typography and spacing not covered by plugin output.

---

## Task D4: Reduce legacy surface in `mereka.scss`

1. Keep all structural/semantically-coupled selectors untouched.
2. Ensure remaining branding-visible selectors reference `var(--mereka-*)` values for color/shadow/radius/font variables.
3. Re-run hardcoded-color sweep: target zero raw `#...` in non-comment code paths.
4. Keep comments around why each retained selector is required (future migration guardrail).

---

## Task D5: Verify

- `bash scripts/qa/verify-paragon-token-coverage.sh`
- `bash scripts/qa/verify-paragon-tokens.sh`
- `bash scripts/qa/verify-paragon-theme-urls.sh`
- Visual smoke check against `apps.academyv2.mereka.io/authn` + `.../dashboard` after image rebuild.
- Capture whether header/footer selectors in `mereka.scss` were reduced only where slot replacements are active.

---

## Completion Criteria

1. Header and footer shell branding moved to slots with no functional regression.
2. `mereka.scss` has fewer structural overrides and no hardcoded brand hex in style rules.
3. All existing token + theme verification scripts pass.
4. No runtime dependency on removed structural selectors in plugin slots.
