# MFE Plugin-Slot Migration Register

> Inventory of all MFE customization points with migration paths to plugin-slot-first architecture.
>
> **Bead**: mereka-lms-8jao.9 / mereka-lms-115d.18 / mereka-lms-115d.21
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
| **Verification** | `verify-mfe-footer-slot.sh`, `verify-footer-slot-migration.sh`, `verify-footer-variant-matrix.sh`, `verify-mfe-footer-fallbacks.sh` |
| **Fallback paths** | Enterprise MFEs (admin-portal, learner-portal) use separate build pipeline without plugin-slot support — see `docs/operations/footer-slot-exceptions.md` for exception register (FTRX-EXC-001, FTRX-EXC-002). Studio CMS uses Mako templates (FTRX-EXC-003). |

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
| **Owner** | Mereka frontend team |
| **Action** | Create `MerekaHeaderLogo` React component; wire via `env.config.jsx` slot |
| **Target Date** | 2026-Q3 |
| **Files** | `mereka.scss:34-47` |
| **Migration path** | Create `MerekaHeaderLogo` component, wire via `env.config.jsx` slot |

---

### 3. Authentication Page Branding (authn MFE)

| Field | Value |
|-------|-------|
| **Current approach** | CSS overrides: `[class*="authn"]`, `[class*="login-register"]` with `[data-testid*="authn"]` primaries. `[class*="auth-page"]` **removed 2026-02-18** (bead 115d.18 — fully covered by authn + data-testid paths). |
| **Target slot** | `org.openedx.frontend.authn.login_component.v1` |
| **Status** | 🟡 CSS OVERRIDE — slot available, data-testid hardened, auth-page selector eliminated |
| **Risk** | Low-Medium (2 brittle class selectors remain as fallback; data-testid primary paths cover all hardened routes) |
| **Tenant impact** | All domains — login/register card styling |
| **Priority** | P1 |
| **Effort** | M (banner/card wrapper component) |
| **Owner** | Mereka frontend team |
| **Action** | Create login banner widget; move card gradient + button styling to `login_component.v1` slot component |
| **Target Date** | 2026-Q3 |
| **Files** | `mereka.scss:209-290` |
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
| **Owner** | Mereka frontend team |
| **Action** | Phase: (1) sidebar widget for tenant branding via `widget_sidebar.v1`, (2) empty state via `no_courses_view.v1`, (3) keep card CSS with data-testid as fallback |
| **Target Date** | 2026-Q3 |
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
| **Owner** | Mereka / Upstream community |
| **Action** | File upstream OEP/slot proposal for learning course grid layout. Until approved: keep CSS with data-testid hardening and `SELECTOR-EXCEPTION` annotations (expires 2026-Q3). |
| **Target Date** | Upstream slot: TBD (community dependent). CSS exceptions: 2026-Q3 review. |
| **Files** | `mereka.scss:406-522` |
| **Migration path** | Keep CSS with data-testid hardening. Request upstream slot for learning course grid layout. Use `ProgressCertificateStatusSlot` for certificate area only. |

---

### 6. Discussions MFE Styling (discussions MFE)

| Field | Value |
|-------|-------|
| **Current approach** | CSS overrides: `[class*="discussions"]` + `[data-testid*="discussions"]` (6 blocks). `[class*="discussion"]` singular **removed 2026-02-18** (bead 115d.18 — consolidated into plural form + data-testid primaries). |
| **Target slot** | No slot available upstream |
| **Status** | 🔴 CSS ONLY — no slot path; singular/plural consolidated |
| **Risk** | Low (data-testid hardened; plural-only fallback; P3/cosmetic) |
| **Tenant impact** | All domains — forum card styling, link colors, headings |
| **Priority** | P3 (cosmetic only, well-hardened) |
| **Effort** | N/A (keep CSS) |
| **Owner** | Mereka frontend team |
| **Action** | Keep CSS with `SELECTOR-EXCEPTION` annotations. Monitor upstream for discussions slot. |
| **Target Date** | N/A — review exceptions at 2026-Q3 |
| **Files** | `mereka.scss:610-680` |
| **Migration path** | Keep CSS. `[class*="discussion"]` singular consolidated into `[class*="discussions"]` plural (done 2026-02-18). |

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
| **Owner** | Mereka frontend team |
| **Action** | Keep CSS with `SELECTOR-EXCEPTION` annotations. Monitor upstream for account settings slot. |
| **Target Date** | N/A — review exceptions at 2026-Q3 |
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
| **Owner** | Mereka frontend team |
| **Action** | Keep CSS as-is. Long-term: contribute Mereka theme to Paragon theme system. |
| **Target Date** | N/A (stable) |
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
| **Owner** | Mereka frontend team |
| **Action** | Move nav colors to CSS custom properties in token system. Keep layout CSS. |
| **Target Date** | 2026-Q3 |
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
| **Owner** | Mereka frontend team |
| **Action** | Create Studio-specific `MerekaStudioFooter` variant; wire via `studio_footer.v1` slot in `mereka_lms.py` |
| **Target Date** | 2026-Q4 |
| **Files** | N/A → `mereka_lms.py` |
| **Migration path** | Create Studio-specific footer variant, wire via studio_footer.v1 slot |

---

---

## Selector Exception Register

> Temporary exceptions to the slot-first policy. All exceptions require an expiry date and a reviewer-approved rollback path.
>
> **Policy**: Any `[class*="..."]` selector that cannot be replaced by a slot or stable Paragon BEM class must be listed here with:
> 1. A `// SELECTOR-EXCEPTION: <reason> | expires: YYYY-QN` annotation in `mereka.scss`
> 2. An entry in this register with owner, rationale, and rollback plan

### Exception Register Table

| Selector Pattern | MFE | Reason Cannot Migrate | Expires | Owner | Rollback Plan |
|-----------------|-----|----------------------|---------|-------|---------------|
| `[class*="authn"]` | authn | No stable data-testid on all entrypoints; `authn` is the wrapper class emitted by authn MFE | 2026-Q3 | Mereka frontend | Remove if `[data-testid*="authn"]` covers all routes in next authn MFE upgrade |
| `[class*="login-register"]` | authn | authn MFE emits this class on top-level wrapper alongside `authn`; belt-and-suspenders fallback | 2026-Q3 | Mereka frontend | Remove once `login_component.v1` slot is wired |
| `[class*="account-settings"]` | account | No upstream slot; account MFE top-level wrapper class | 2026-Q3 | Mereka frontend | Remove once upstream account settings slot is available |
| `[class*="account-page"]` | account | No upstream slot; account MFE secondary wrapper class | 2026-Q3 | Mereka frontend | Remove once upstream account settings slot is available |
| `[class*="learner-dashboard"]` | learner-dashboard | No upstream slot for layout container; covers 8 blocks of cosmetic CSS | 2026-Q3 | Mereka frontend | Phase to `widget_sidebar.v1` + `no_courses_view.v1` once wired |
| `[class*="learning"]` | learning | No upstream slot for course grid layout; upstream slot proposal pending (see AC-US7-005) | 2026-Q3 | Mereka / Upstream | Remove once upstream `learning_course_grid.v1` or equivalent slot is approved |
| `[class*="discussions"]` | discussions | No upstream slot; P3/cosmetic; data-testid primary present | 2026-Q3 | Mereka frontend | Keep indefinitely unless upstream slot emerges |
| `[class*="course"]` (in dashboard/learning scope) | dashboard/learning | No stable slot for course card inner; data-testid primary present | 2026-Q3 | Mereka frontend | Remove once dashboard course card slot is upstream |
| `[class*="image-cap"]`, `[class*="imagecap"]` | learning | Paragon ImageCap component internal classes; semi-stable | 2026-Q3 | Mereka frontend | Remove if Paragon exposes stable BEM for image cap |
| `[class*="image"]`, `[class*="media"]` (in card scope) | learning | Too broad — no better alternative; scoped inside `.pgn__card` to limit blast radius | 2026-Q3 | Mereka frontend | Replace with explicit Paragon classes once Paragon card layout stabilizes |

### Removed Exceptions (bead 115d.18, 2026-02-18)

| Selector Pattern | Removed | Reason |
|-----------------|---------|--------|
| `[class*="auth-page"]` | 2026-02-18 | Fully covered by `[class*="authn"]` + `[data-testid*="authn"]` primary paths |
| `[class*="discussion"]` (singular) | 2026-02-18 | Consolidated into `[class*="discussions"]` plural + data-testid primary paths (33% of singular blocks eliminated) |

---

## Unresolved Selectors (Cannot Be Slot-Migrated Yet)

> These selectors have no viable slot migration path at this time. Each is tracked with rationale, date filed, and next review date.

### US7-TICKET-001: Learning MFE Course Grid Layout Slot

- **Selector**: `[class*="learning"]` (11 rule blocks)
- **Filed**: 2026-02-18
- **Rationale**: No upstream Open edX slot exists for the learning MFE course grid layout container. The `ProgressCertificateStatusSlot` covers only the certificate area, not the full layout. The `[class*="learning"]` selector is the broadest and most brittle in the file — it matches any element whose class contains the string "learning".
- **Attempted alternatives**: `body.learning-mfe` (not emitted by upstream MFE), `[data-testid*="learning-page"]` (data-testid not consistently applied by upstream learning MFE).
- **Next review**: 2026-Q3
- **Resolution path**: File slot proposal with Open edX community for `org.openedx.frontend.learning.course_grid.v1`. Until approved, keep CSS with `SELECTOR-EXCEPTION` annotations and data-testid primary paths.
- **Rollback**: If `[class*="learning"]` causes false positives (styling non-learning pages), narrow scope by adding `[data-page="learning"]` attribute via MFE config.

### US7-TICKET-002: Discussions MFE Styling

- **Selector**: `[class*="discussions"]` (6 rule blocks)
- **Filed**: 2026-02-18
- **Rationale**: No upstream slot available for discussions MFE styling. All rules are P3/cosmetic (card borders, link colors, heading font). `[class*="discussion"]` singular was eliminated (bead 115d.18); plural `[class*="discussions"]` remains as well-scoped fallback.
- **Next review**: 2026-Q3
- **Resolution path**: Monitor upstream discussions MFE for slot additions. Keep as CSS with data-testid primary + SELECTOR-EXCEPTION.
- **Rollback**: Styles are cosmetic only — removing the `[class*="discussions"]` fallback would fall back to global Paragon defaults, which are acceptable.

---

## Summary Matrix

| # | Override | Slot Available | Status | Priority | Effort | Risk | Owner | Target Date |
|---|---------|---------------|--------|----------|--------|------|-------|-------------|
| 1 | Footer | ✅ footer.v1 | ✅ MIGRATED | Done | Done | Low | Mereka | Done |
| 2 | Header Logo | ✅ header_logo.v1 | 🟡 CSS | P1 | M | Med | Mereka frontend | 2026-Q3 |
| 3 | Authn Branding | ✅ login_component.v1 | 🟡 CSS (auth-page removed) | P1 | M | Low-Med | Mereka frontend | 2026-Q3 |
| 4 | Dashboard Layout | ✅ sidebar + no_courses | 🟡 CSS | P1 | L | High | Mereka frontend | 2026-Q3 |
| 5 | Learning Layout | ⚠️ Partial (cert only) | 🔴 CSS | P2 | L | Critical | Mereka / Upstream | TBD (upstream) |
| 6 | Discussions | ❌ None | 🔴 CSS (singular removed) | P3 | N/A | Low | Mereka frontend | 2026-Q3 review |
| 7 | Account/Settings | ❌ None | 🟡 CSS | P3 | N/A | Med | Mereka frontend | 2026-Q3 review |
| 8 | Paragon Globals | N/A (use tokens) | ✅ STABLE | P3 | N/A | Low | Mereka frontend | N/A |
| 9 | Navbar | ⚠️ Partial (logo) | 🟡 CSS | P2 | S | Low | Mereka frontend | 2026-Q3 |
| 10 | Studio Footer | ✅ studio_footer.v1 | ⬜ NOT STARTED | P2 | M | N/A | Mereka frontend | 2026-Q4 |

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

**Status**: LOCKED (Sprint S6 / bead 115d.18, 2026-02-18)

This register is the canonical inventory of all MFE DOM/CSS overrides.
Any new override MUST:
1. Be added to this register with full classification (including Owner, Action, Target Date)
2. Include a `data-testid` fallback selector
3. Have an approved migration path documented
4. Pass `verify-migration-lock.sh` CI gate
5. If brittle `[class*=]` is unavoidable, add a `// SELECTOR-EXCEPTION: <reason> | expires: YYYY-QN` annotation in SCSS

### Rollback Policy

If a selector change breaks production styling:
1. Revert the SCSS commit: `git revert <sha> --no-edit`
2. Restore previous exception annotation (with updated expiry)
3. Update this register with the regression finding
4. File a bug ticket with browser/MFE version that triggered the break

Rollback windows per exception tier:
- **P1 selectors** (authn, dashboard): 24h hotfix window
- **P2 selectors** (learning): 72h — uses data-testid primary, class fallback only
- **P3 selectors** (discussions, account): No SLA — cosmetic only, falls back to Paragon defaults

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
- [footer-slot-exceptions.md](footer-slot-exceptions.md) — Footer fallback exception register with visual evidence pack
- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html)
