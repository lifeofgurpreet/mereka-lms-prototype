# MFE Selector Exceptions

**Bead**: 2dcy.2 (AC-FRONT-023)  
**Last updated**: 2026-02-28  
**Status**: Active — slot-first policy, wrapper exceptions retired

This document tracks the CSS selectors in `infrastructure/tutor/themes/mereka/mfe/mereka.scss` that are intentionally kept as exceptions after Phase C hardening.

## Policy

- Slot-first is mandatory for structure-level customizations when an FPF slot exists.
- Wildcard selectors (`[class*="..."]`) are considered brittle and are not allowed in active CSS.
- Exceptions are allowed only when there is no upstream slot and the selector is either:
  - CSS-only infrastructure (`:root`, `body`), or
  - an explicit, audited class contract with expiry metadata.

## Current Exception Inventory

### EX-01 — `:root` custom properties (RISK: LOW)

```scss
:root {
  --mereka-mfe-branding-rev: "...";
  --mereka-...: ...;
}
```

**Cannot be migrated**: plugin slots inject React components, not CSS variable declarations.  
**Rationale**: CSS-only design-token infrastructure.  
**Expiry**: None.

### EX-02 — `body` background shell styling (RISK: LOW)

```scss
body {
  min-height: 100vh;
  background-color: var(--mereka-color-surface-primary);
}
```

**Cannot be migrated**: no slot can target the document root.  
**Rationale**: CSS-only global shell styling, safe degradation.  
**Expiry**: None.

### EX-03 — Paragon/Bootstrap cosmetic component overrides (RISK: LOW-MEDIUM)

```scss
.pgn__btn--primary { ... }
.pgn__card { ... }
.navbar { ... }
```

**Cannot be migrated**: plugin slots do not replace arbitrary library component CSS themes.  
**Rationale**: primarily cosmetic tokenized styling; functionality remains intact on degradation.  
**Expiry**: review on Paragon/Bootstrap major upgrades.

## Removed Exceptions (Dead Selector Cleanup)

The following wildcard branches were intentionally removed from active CSS and are now guarded by QA gates:

- `[class*="authn"]`
- `[class*="login-register"]`
- `[class*="learner-dashboard"]`
- `[class*="learning"]`
- `[class*="discussions"]`
- `[class*="account-page"]`
- `.page__account-settings`

Regression gates:

- `scripts/qa/verify-mfe-selector-hardening.sh`
- `scripts/qa/verify-no-dom-overrides.sh`
- `scripts/qa/verify-migration-lock.sh`

## Slot Coverage That Replaced Prior CSS Branches

- `org.openedx.frontend.layout.footer.v1`
- `org.openedx.frontend.layout.header_logo.v1`
- `org.openedx.frontend.authn.login_component.v1`
- `org.openedx.frontend.learner_dashboard.widget_sidebar.v1`
- `org.openedx.frontend.learner_dashboard.no_courses_view.v1`
- `org.openedx.frontend.account.account_settings_tab.v1`
- `org.openedx.frontend.account.account_settings_field.v1`

See `infrastructure/tutor/plugins/mereka_lms.py` for canonical registrations.

## Risk Summary

| Exception | Pattern | Risk | Blocker | Expiry |
|---|---|---|---|---|
| EX-01 | `:root` token vars | LOW | No slot for CSS vars | Never |
| EX-02 | `body` shell styling | LOW | No slot for document root | Never |
| EX-03 | `.pgn__*` / `.navbar` cosmetic rules | LOW-MEDIUM | CSS-only theming concern | Paragon/Bootstrap major |

## Related Documents

- `docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`
- `docs/operations/MFE_SELECTOR_HARDENING_AUDIT.md`
- `docs/concepts/architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md`
- `docs/archive/evidence/operations/selector-to-slot-migration-diff.md`
