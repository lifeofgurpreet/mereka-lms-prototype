# MFE Selector Liveness Audit (2026-02-28)

## Scope
- File audited: `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
- Objective: tranche-2 baseline after slot-expansion work
- Method: static selector extraction from active SCSS (comments removed, `@media` ignored)

## Summary
- Total selector lines: **55**
- `mereka-` slot-owned selectors: **21**
- Paragon-coupled selectors (`.pgn__*`): **17**
- Account wrapper exceptions (`.page__account-settings*`): **2**
- Navbar/Bootstrap generic selectors: **6**
- Other global selectors: **9**

## Active Exceptions
1. `.page__account-settings`
2. `.page__account-settings h1, .page__account-settings h2`

Both remain intentionally in place pending full runtime validation of `org.openedx.frontend.account.account_settings_tab.v1` coverage on all account surfaces.

## Paragon-Coupled Selector Inventory
- `.pgn__btn--primary`
- `.pgn__btn--primary:focus`
- `.pgn__btn--link`
- `.pgn__btn`
- `.pgn__btn--link:focus`
- `.pgn__card`
- `.pgn__alert`
- `.pgn__alert--info`
- `.pgn__alert--success`
- `.pgn__alert--warning`
- `.pgn__alert--danger`
- `.pgn__modal-content`
- `.pgn__dropdown-menu`
- `.pgn__dropdown-toggle`
- `.pgn__tabs .nav-link`
- `.pgn__tabs .nav-link.active`

## Next Cleanup Pass (Tranche-2)
1. Validate each `.pgn__*` selector against live DOM on authn/dashboard/learning/account.
2. Remove selectors with zero live matches, or replace with slot-owned class hooks.
3. If account slot rendering is confirmed across all tabs, remove `.page__account-settings*` exceptions.
4. Re-run:
   - `./scripts/qa/verify-selector-hardening.sh`
   - `./scripts/qa/verify-selector-to-slot-migration.sh`
   - `./scripts/qa/verify-mfe-footer-slot-migration.sh`
