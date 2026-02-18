# MFE Plugin-Slot Migration Register

> Inventory of all MFE customization points with migration paths to plugin-slot-first architecture.
>
> **Bead**: mereka-lms-8jao.9
> **Last updated**: 2026-02-18
> **Source**: MFE_SELECTOR_HARDENING_AUDIT.md + MFE_PLUGIN_SLOT_MATRIX.md

## Migration Register

Each entry links a current DOM/CSS override to its preferred slot/config replacement.

### Priority Legend
- **P0**: Migrate now — high breakage risk, slot available
- **P1**: Migrate next sprint — moderate risk, slot available
- **P2**: Migrate when slot available — slot not yet upstream
- **P3**: Keep as CSS — no slot path, low risk

### Effort Legend
- **S**: Small (< 1 hour) — config change only
- **M**: Medium (1-4 hours) — new React component + wiring
- **L**: Large (4+ hours) — complex component with state/API

---

### 1. Footer (All MFEs)

| Field | Value |
|-------|-------|
| **Current approach** | React component via `mereka_lms.py` RenderWidget + PLUGIN_SLOTS |
| **Target slot** | `org.openedx.frontend.layout.footer.v1` |
| **Status** | ✅ MIGRATED — dual-path wiring active |
| **Risk** | Low (already on slot) |
| **Tenant impact** | All domains |
| **Priority** | Done |
| **Effort** | Done |
| **Owner** | Mereka |
| **Files** | `mereka_lms.py:~650-900` |
| **Migration path** | Migration complete — dual-path wiring (RenderWidget + PLUGIN_SLOTS) |
| **Verification** | `verify-mfe-footer-slot.sh`, `verify-footer-slot-migration.sh`, `verify-footer-variant-matrix.sh` |

---

### 2. Header Logo (All MFEs)

| Field | Value |
|-------|-------|
| **Current approach** | CSS override in `mereka.scss` (`.navbar .navbar-brand img { height: 32px }`) |
| **Target slot** | `org.openedx.frontend.layout.header_logo.v1` |
| **Status** | 🟡 CSS OVERRIDE — slot available but not wired |
| **Risk** | Medium (class `.navbar-brand` is Bootstrap, relatively stable) |
| **Tenant impact** | All domains — logo size/placement |
| **Priority** | P1 |
| **Effort** | M (React component with tenant-aware logo URL) |
| **Owner** | Mereka |
| **Files** | `mereka.scss:34-47` |
| **Migration path** | Create `MerekaHeaderLogo` component, wire via `env.config.jsx` slot |

---

### 3. Authentication Page Branding (authn MFE)

| Field | Value |
|-------|-------|
| **Current approach** | CSS overrides: `[class*="authn"]`, `[class*="login-register"]`, `[class*="auth-page"]` with `[data-testid*="authn"]` fallbacks |
| **Target slot** | `org.openedx.frontend.authn.login_component.v1` |
| **Status** | 🟡 CSS OVERRIDE — slot available, data-testid hardened |
| **Risk** | Medium (3 brittle class selectors, but data-testid fallbacks added) |
| **Tenant impact** | All domains — login/register card styling |
| **Priority** | P1 |
| **Effort** | M (banner/card wrapper component) |
| **Owner** | Mereka |
| **Files** | `mereka.scss:209-263` |
| **Migration path** | Create login banner widget, move card gradient + button styling to slot component |

---

### 4. Learner Dashboard Layout (learner-dashboard MFE)

| Field | Value |
|-------|-------|
| **Current approach** | CSS overrides: `[class*="learner-dashboard"]` + `[data-testid*="learner-dashboard"]` (8 blocks) |
| **Target slot** | `org.openedx.frontend.learner_dashboard.widget_sidebar.v1`, `...no_courses_view.v1` |
| **Status** | 🟡 CSS OVERRIDE — partial slot path (sidebar + empty state) |
| **Risk** | High (broad class selector, 8 blocks affected) |
| **Tenant impact** | All domains — course cards, status pills, layout |
| **Priority** | P1 |
| **Effort** | L (multiple components: sidebar widget, empty state, course card styling) |
| **Owner** | Mereka |
| **Files** | `mereka.scss:289-560` |
| **Migration path** | Phase: (1) sidebar widget for tenant branding, (2) empty state for onboarding, (3) keep card CSS with data-testid |

---

### 5. Learning MFE Layout (learning MFE)

| Field | Value |
|-------|-------|
| **Current approach** | CSS overrides: `[class*="learning"]` + `[data-testid*="learning"]` (11 blocks) — HIGHEST RISK |
| **Target slot** | No direct slot — `ProgressCertificateStatusSlot` covers one section |
| **Status** | 🔴 CSS ONLY — no adequate slot path |
| **Risk** | Critical (broadest selector, 11 blocks, any class with "learning" matches) |
| **Tenant impact** | All domains — course grid, card layout, image handling |
| **Priority** | P2 (no slot available for layout) |
| **Effort** | L (would need upstream slot proposal for course grid layout) |
| **Owner** | Mereka / Upstream request |
| **Files** | `mereka.scss:406-522` |
| **Migration path** | Keep CSS with data-testid hardening. Request upstream slot for learning course grid layout. Use `ProgressCertificateStatusSlot` for certificate area only. |

---

### 6. Discussions MFE Styling (discussions MFE)

| Field | Value |
|-------|-------|
| **Current approach** | CSS overrides: `[class*="discussions"]` + `[class*="discussion"]` + `[data-testid*="discussions"]` (9 blocks) |
| **Target slot** | No slot available upstream |
| **Status** | 🔴 CSS ONLY — no slot path |
| **Risk** | Medium (data-testid hardened, dual singular/plural selectors) |
| **Tenant impact** | All domains — forum card styling, link colors, headings |
| **Priority** | P3 (cosmetic only, well-hardened) |
| **Effort** | N/A (keep CSS) |
| **Owner** | Mereka |
| **Files** | `mereka.scss:562-630` |
| **Migration path** | Keep CSS. Consolidate `[class*="discussion"]` singular into `[class*="discussions"]` plural only. |

---

### 7. Account/Settings Page (account MFE)

| Field | Value |
|-------|-------|
| **Current approach** | CSS overrides: `[class*="account-settings"]`, `[class*="account-page"]` + `[data-testid*="account"]` (6 blocks) |
| **Target slot** | No slot available upstream |
| **Status** | 🟡 CSS OVERRIDE — data-testid hardened, no slot |
| **Risk** | Medium (6 blocks, data-testid fallbacks in place) |
| **Tenant impact** | All domains — form styling, card layout |
| **Priority** | P3 (low risk, well-hardened) |
| **Effort** | N/A (keep CSS) |
| **Owner** | Mereka |
| **Files** | `mereka.scss:289-560` |
| **Migration path** | Keep CSS with data-testid. Monitor upstream for account settings slot. |

---

### 8. Global Paragon Overrides (all MFEs)

| Field | Value |
|-------|-------|
| **Current approach** | Direct Paragon class overrides: `.pgn__card`, `.pgn__alert`, `.pgn__modal-content`, `.pgn__btn--primary`, etc. |
| **Target slot** | N/A — use Paragon theme tokens instead |
| **Status** | ✅ STABLE — Paragon BEM classes are library-controlled |
| **Risk** | Low (Paragon follows semver, class names are stable) |
| **Tenant impact** | All domains — card radius, button gradient, alert colors |
| **Priority** | P3 (keep as-is, very stable) |
| **Effort** | N/A |
| **Owner** | Mereka |
| **Files** | `mereka.scss:63-194` |
| **Migration path** | Keep CSS. Long-term: contribute Mereka theme to Paragon's theme system when available. |

---

### 9. Navbar Overrides (all MFEs)

| Field | Value |
|-------|-------|
| **Current approach** | Direct Bootstrap/Paragon class overrides: `.navbar`, `.navbar .navbar-brand`, `.navbar .nav-link` |
| **Target slot** | `org.openedx.frontend.layout.header_logo.v1` (partial — logo only) |
| **Status** | 🟡 CSS OVERRIDE — stable Bootstrap classes |
| **Risk** | Low (Bootstrap naming convention, widely used) |
| **Tenant impact** | All domains — nav background, link colors, padding |
| **Priority** | P2 |
| **Effort** | S (mostly CSS custom properties, could move to token system) |
| **Owner** | Mereka |
| **Files** | `mereka.scss:27-61` |
| **Migration path** | Move colors to CSS custom properties already in token system. Keep layout CSS. |

---

### 10. Studio Footer (Studio/authoring)

| Field | Value |
|-------|-------|
| **Current approach** | Not customized (default Open edX) |
| **Target slot** | `org.openedx.frontend.layout.studio_footer.v1` |
| **Status** | ⬜ NOT STARTED — slot available |
| **Risk** | N/A (no current override) |
| **Tenant impact** | Studio only |
| **Priority** | P2 |
| **Effort** | M (extend MerekaFooter to Studio context) |
| **Owner** | Mereka |
| **Files** | N/A → `mereka_lms.py` |
| **Migration path** | Create Studio-specific footer variant, wire via studio_footer.v1 slot |

---

## Summary Matrix

| # | Override | Slot Available | Status | Priority | Effort | Risk |
|---|---------|---------------|--------|----------|--------|------|
| 1 | Footer | ✅ footer.v1 | ✅ MIGRATED | Done | Done | Low |
| 2 | Header Logo | ✅ header_logo.v1 | 🟡 CSS | P1 | M | Med |
| 3 | Authn Branding | ✅ login_component.v1 | 🟡 CSS | P1 | M | Med |
| 4 | Dashboard Layout | ✅ sidebar + no_courses | 🟡 CSS | P1 | L | High |
| 5 | Learning Layout | ⚠️ Partial (cert only) | 🔴 CSS | P2 | L | Critical |
| 6 | Discussions | ❌ None | 🔴 CSS | P3 | N/A | Med |
| 7 | Account/Settings | ❌ None | 🟡 CSS | P3 | N/A | Med |
| 8 | Paragon Globals | N/A (use tokens) | ✅ STABLE | P3 | N/A | Low |
| 9 | Navbar | ⚠️ Partial (logo) | 🟡 CSS | P2 | S | Low |
| 10 | Studio Footer | ✅ studio_footer.v1 | ⬜ NOT STARTED | P2 | M | N/A |

## Migration Roadmap

### Now (Sprint S6)
- [x] Footer → `footer.v1` (DONE)
- [x] All selectors hardened with data-testid fallbacks (DONE, 8jao.3)

### Next Sprint
- [ ] Header Logo → `header_logo.v1` (P1, M)
- [ ] Authn Branding → `login_component.v1` (P1, M)
- [ ] Dashboard sidebar → `widget_sidebar.v1` (P1, L)

### Backlog
- [ ] Studio Footer → `studio_footer.v1` (P2, M)
- [ ] Navbar tokens migration (P2, S)
- [ ] Learning layout — request upstream slot (P2, L)

### Keep as CSS
- Discussions styling (P3, well-hardened)
- Account/Settings styling (P3, well-hardened)
- Paragon global overrides (P3, very stable)

## Migration Lock

**Status**: LOCKED (Sprint S6, 2026-02-18)

This register is the canonical inventory of all MFE DOM/CSS overrides.
Any new override MUST:
1. Be added to this register with full classification
2. Include a `data-testid` fallback selector
3. Have an approved migration path documented
4. Pass `verify-migration-lock.sh` CI gate

### Lock Enforcement

CI job `migration-lock` runs `scripts/qa/verify-migration-lock.sh` on every PR touching:
- `infrastructure/tutor/themes/mereka/mfe/mereka.scss`
- `docs/operations/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`
- `docs/branding/BRANDING_OPERATING_MODEL.md`

## Verification

Run `./scripts/qa/verify-plugin-slot-migration-register.sh` to check:
1. Register doc exists with all 10 entries
2. Summary matrix is present and complete
3. All MIGRATED items have verification scripts
4. No P0 items remain open

## References
- [MFE_SELECTOR_HARDENING_AUDIT.md](MFE_SELECTOR_HARDENING_AUDIT.md)
- [MFE_PLUGIN_SLOT_MATRIX.md](MFE_PLUGIN_SLOT_MATRIX.md)
- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html)
