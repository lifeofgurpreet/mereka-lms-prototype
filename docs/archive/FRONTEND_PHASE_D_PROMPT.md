# Frontend Phase D: MFE Slot Branding Stabilization

**Date**: 2026-02-28
**Prerequisite**: Phase C complete (FE-010, FE-011, FE-012, FE-015 prepared)
**Specs**: `specs/mfe-plugin-slots_spec.md`, `specs/plans/paragon-design-tokens-migration_spec.md`

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

## CRITICAL: Dead Selector Reality (2026-02-28)

**Read `docs/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md` §Dead Selector Audit FIRST.**

A DOM audit reveals that ~60% of the scoped `[class*="..."]` selectors in `mereka.scss`
(lines 250-570) are **PHANTOM** — they compile and ship but match **no actual DOM element**:

| Selector | Status |
|----------|--------|
| `[class*="authn"]` | **DEAD** |
| `[class*="login-register"]` | **DEAD** |
| `[class*="account-page"]` | **DEAD** |
| `[class*="learner-dashboard"]` | **DEAD** |
| `[class*="learning"]` | **DEAD** |
| `[class*="my-courses"]` | **DEAD** |
| `[class*="discover"]` | **DEAD** |
| `[class*="discussions"]` | **DEAD** |
| `.page__account-settings` | **LIVE** (explicit class in Account MFE wrapper) |

This fundamentally changes Phase D's approach: instead of migrating CSS overrides to slots,
we must first **find the actual DOM class names** and rewrite selectors, OR bypass CSS
entirely via plugin slot injection.

### Available FPF Slots (98 total)

See `docs/architecture/FPF_PLUGIN_SLOT_REGISTRY.md` for the complete inventory.

Key slots for Phase D branding:
- **Learner Dashboard**: `course_card.v1`, `dashboard_header.v1`, `sidebar.v1` (6 slots)
- **Authn**: Only `login_component.v1` (1 slot — limited)
- **Learning**: `course_header.v1`, `course_outline.v1`, `course_tabs.v1` (26 slots)
- **Header/Footer**: Already implemented (18 + 6 slots)

---

## Task D1: Inventory & classify overrides for slot migration

1. Open `docs/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md` and `infrastructure/tutor/themes/mereka/mfe/mereka.scss`.
2. **First**: Inspect each MFE's actual DOM to find real wrapper class names.
3. Mark each override as:
   - **DEAD_SELECTOR**: The `[class*="..."]` doesn't match any DOM element. Needs rewrite or slot migration.
   - **SAFE_TO_SLOT**: Can be fully replaced by a plugin slot component.
   - **NEEDS_REWRITE**: Selector is dead but no slot covers this surface — find actual class name.
   - **NEEDS_KEEP**: Selector is LIVE and structural — stays in `mereka.scss` with var references.
4. Add/refresh a short note in the inventory file with a one-line rationale per item.

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

## Files to READ First

| File | Why |
|------|-----|
| `docs/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md` | Dead selector audit — which selectors are phantom CSS |
| `docs/architecture/FPF_PLUGIN_SLOT_REGISTRY.md` | All 98 available FPF slots in Ulmo |
| `docs/archive/reports/reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md` | Architecture issues from Phase A/B |
| `infrastructure/tutor/themes/mereka/mfe/mereka.scss` | All current BEM overrides |
| `infrastructure/tutor/plugins/mereka_lms.py` | Current slot registrations |

---

## Completion Criteria

1. Header and footer shell branding moved to slots with no functional regression.
2. All DEAD `[class*="..."]` selectors either rewritten with actual DOM class names OR replaced by plugin slot injection.
3. `mereka.scss` has fewer structural overrides and no hardcoded brand hex in style rules.
4. All existing token + theme verification scripts pass.
5. No runtime dependency on removed structural selectors in plugin slots.
6. `docs/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md` updated with new selector status (DEAD → LIVE or REMOVED).
