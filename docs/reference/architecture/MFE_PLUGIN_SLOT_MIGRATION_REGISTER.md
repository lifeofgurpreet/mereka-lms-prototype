# MFE Plugin-Slot Migration Register

> Inventory of all MFE customization points with migration paths to plugin-slot-first architecture.
>
> **Bead**: mereka-lms-8jao.9 / mereka-lms-115d.18 / mereka-lms-115d.21
> **Last updated**: 2026-02-28
> **Source**: MFE_SELECTOR_AUDIT.md + [MFE_PLUGIN_SLOT_MATRIX.md](../operations/MFE_PLUGIN_SLOT_MATRIX.md)

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
| **Fallback paths** | Enterprise MFEs (admin-portal, learner-portal) use separate build pipeline without plugin-slot support — see `docs/policies/architecture/footer-slot-exceptions.md` for exception register (FTRX-EXC-001, FTRX-EXC-002). Studio CMS uses Mako templates (FTRX-EXC-003). |

---

### 2. Header Logo (All MFEs)

| Field | Value |
|-------|-------|
| **Current approach** | Plugin slot in `mereka_lms.py` (`MerekaHeaderLogo`) with compatibility sizing in `.mereka-header-logo` |
| **Target slot** | `org.openedx.frontend.layout.header_logo.v1` |
| **Status** | ✅ MIGRATED — slot active with compatibility sizing |
| **Risk** | Low (slot API is stable; fallback selectors are minimal) |
| **Tenant impact** | All domains — logo size/placement |
| **Priority** | Done |
| **Effort** | Done |
| **Owner** | Mereka frontend team |
| **Action** | Keep slot component active and keep `.mereka-header-logo` styling as compatibility surface |
| **Target Date** | Done |
| **Files** | `infrastructure/tutor/plugins/mereka_lms.py`, `infrastructure/tutor/themes/mereka/mfe/mereka.scss` |
| **Verification** | `verify-selector-to-slot-migration.sh`, `verify-migration-lock.sh`, `verify-no-dom-overrides.sh` |
| **Migration path** | Slot registration already complete; scoped SCSS kept for layout consistency |

---

### 3. Authentication Page Branding (authn MFE)

| Field | Value |
|-------|-------|
| **Current approach** | Slot-backed component in `mereka_lms.py` (`MerekaAuthnLoginBranding`) with slot-owned classes in `mereka.scss` |
| **Target slot** | `org.openedx.frontend.authn.login_component.v1` |
| **Status** | ✅ MIGRATED — slot active without wildcard fallback selectors |
| **Risk** | Low (slot-owned classes only) |
| **Tenant impact** | All domains — login/register card styling |
| **Priority** | Done |
| **Effort** | Done |
| **Owner** | Mereka frontend team |
| **Action** | Keep slot component active; avoid wildcard selector fallback reintroduction |
| **Target Date** | Done |
| **Files** | `infrastructure/tutor/plugins/mereka_lms.py`, `infrastructure/tutor/themes/mereka/mfe/mereka.scss` |
| **Verification** | `verify-selector-to-slot-migration.sh`, `verify-mfe-selector-hardening.sh`, `verify-migration-lock.sh` |
| **Migration path** | Slot registration already complete; wrapper fallback selectors removed after dead-selector audit |

---

### 4. Learner Dashboard Layout (learner-dashboard MFE)

| Field | Value |
|-------|-------|
| **Current approach** | Slot components in `mereka_lms.py` (`MerekaLearnerSidebarWidget`, `MerekaNoCoursesView`) with generic tokenized card styles in `mereka.scss` |
| **Target slot** | `org.openedx.frontend.learner_dashboard.widget_sidebar.v1`, `...no_courses_view.v1` |
| **Status** | ✅ SLOT-FIRST — sidebar/empty-state slot path active; dashboard wildcard selectors removed |
| **Risk** | Medium (remaining visual parity comes from shared `.card`/`.pgn__card` tokenized rules) |
| **Tenant impact** | All domains — course cards, status pills, layout |
| **Priority** | Done |
| **Effort** | Done |
| **Owner** | Mereka frontend team |
| **Action** | Keep slot widgets active and prevent reintroduction of dead dashboard wildcard selectors |
| **Target Date** | Done |
| **Files** | `infrastructure/tutor/plugins/mereka_lms.py`, `infrastructure/tutor/themes/mereka/mfe/mereka.scss` |
| **Migration path** | Slot widgets are live; dashboard-scoped wildcard fallback was removed after dead-selector audit |

---

### 5. Learning MFE Layout (learning MFE)

| Field | Value |
|-------|-------|
| **Current approach** | Slot component for progress/certificate context (`MerekaProgressCertificateStatus`) plus generic tokenized Paragon/Bootstrap component styling |
| **Target slot** | No direct slot — `ProgressCertificateStatusSlot` covers one section |
| **Status** | ✅ DEAD WILDCARD REMOVED — no active `[class*="learning"]` selectors remain |
| **Risk** | Medium (full layout slots still not available upstream) |
| **Tenant impact** | All domains — course grid, card layout, image handling |
| **Priority** | Done (for wildcard cleanup) |
| **Effort** | Done (for wildcard cleanup) |
| **Owner** | Mereka / Upstream community |
| **Action** | Track upstream slot expansion for full learning layout; keep current slot insertion and shared tokenized rules |
| **Target Date** | Upstream slot: TBD (community dependent) |
| **Files** | `infrastructure/tutor/plugins/mereka_lms.py`, `infrastructure/tutor/themes/mereka/mfe/mereka.scss` |
| **Migration path** | Wildcard learning selectors removed; keep slot insertion and avoid selector reintroduction |

---

### 6. Discussions MFE Styling (discussions MFE)

| Field | Value |
|-------|-------|
| **Current approach** | Generic tokenized Paragon component styling only (no discussions-specific wildcard selectors) |
| **Target slot** | No slot available upstream |
| **Status** | ✅ DEAD WILDCARD REMOVED — discussions wildcard selectors removed from active CSS |
| **Risk** | Low (no discussions-specific brittle selectors remain) |
| **Tenant impact** | All domains — forum card styling, link colors, headings |
| **Priority** | Done (for wildcard cleanup) |
| **Effort** | N/A (keep CSS) |
| **Owner** | Mereka frontend team |
| **Action** | Keep discussions coverage through shared tokenized component rules; monitor upstream for dedicated slots |
| **Target Date** | Done (for wildcard cleanup) |
| **Files** | `infrastructure/tutor/themes/mereka/mfe/mereka.scss` |
| **Migration path** | Discussions wildcard selectors removed after dead-selector audit; regression blocked in `verify-mfe-selector-hardening.sh` |

---

### 7. Account/Settings Page (account MFE)

| Field | Value |
|-------|-------|
| **Current approach** | Slot-owned account surfaces (`account_settings_tab.v1` + `account_settings_field.v1`) with tokenized shared component styles |
| **Target slot** | `org.openedx.frontend.account.account_settings_tab.v1` + `org.openedx.frontend.account.account_settings_field.v1` |
| **Status** | ✅ MIGRATED — wrapper exception removed |
| **Risk** | Low (no wrapper-class dependency remains) |
| **Tenant impact** | All domains — form styling, card layout |
| **Priority** | Done |
| **Effort** | Done |
| **Owner** | Mereka frontend team |
| **Action** | Keep slot components active and block wrapper selector regressions in QA gates |
| **Target Date** | Done |
| **Files** | `infrastructure/tutor/plugins/mereka_lms.py`, `infrastructure/tutor/themes/mereka/mfe/mereka.scss` |
| **Migration path** | Wrapper selector retired; account surfaces now flow through slot components and shared tokenized styles |
| **Verification** | `verify-mfe-selector-hardening.sh`, `verify-selector-to-slot-migration.sh`, `verify-no-dom-overrides.sh` |

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
| **Current approach** | Direct Bootstrap/Paragon class overrides: `.navbar`, `.navbar .nav-link`, `.navbar .dropdown-toggle` |
| **Target slot** | `org.openedx.frontend.layout.header_logo.v1` (partial — logo only) |
| **Status** | ✅ TOKENIZED CSS — navbar colors/shadows/spacing use `var(--mereka-*)` contract |
| **Risk** | Low (Bootstrap naming convention, widely used) |
| **Tenant impact** | All domains — nav background, link colors, padding |
| **Priority** | Done |
| **Effort** | Done |
| **Owner** | Mereka frontend team |
| **Action** | Keep tokenized navbar styles and prevent hardcoded color regressions |
| **Target Date** | Done |
| **Files** | `mereka.scss:27-61` |
| **Migration path** | Migration complete; navbar uses tokenized values with shared fallback contract |

---

### 10. Studio Footer (Studio/authoring)

| Field | Value |
|-------|-------|
| **Current approach** | Plugin slot in `mereka_lms.py` (`MerekaStudioFooter`) |
| **Target slot** | `org.openedx.frontend.layout.studio_footer.v1` |
| **Status** | ✅ MIGRATED — dual-path active |
| **Risk** | Low |
| **Tenant impact** | Studio only |
| **Priority** | Done |
| **Effort** | Done |
| **Owner** | Mereka frontend team |
| **Action** | Keep slot component active |
| **Target Date** | Done |
| **Files** | `infrastructure/tutor/plugins/mereka_lms.py` |
| **Verification** | `verify-footer-variant-matrix.sh`, `verify-plugin-slot-migration-register.sh`, `verify-selector-to-slot-migration.sh` |
| **Migration path** | Slot registration complete |

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
| _None active_ | — | All prior account wrapper exceptions retired via slot migration | — | — | Re-open only if upstream slot contracts regress |

### Removed Exceptions (bead 115d.18, 2026-02-18)

| Selector Pattern | Removed | Reason |
|-----------------|---------|--------|
| `[class*="auth-page"]` | 2026-02-18 | Fully covered by `[class*="authn"]` + `[data-testid*="authn"]` primary paths |
| `[class*="discussion"]` (singular) | 2026-02-18 | Consolidated into `[class*="discussions"]` plural + data-testid primary paths (33% of singular blocks eliminated) |
| `[class*="account-page"]` | 2026-02-28 | Removed as dead selector branch from `mereka.scss`; guarded by `verify-mfe-selector-hardening.sh` regression check |
| `[class*="login-register"]` | 2026-02-28 | Removed as dead selector branch from `mereka.scss`; guarded by `verify-mfe-selector-hardening.sh` regression check |
| `[class*="discussions"]` | 2026-02-28 | Removed as dead selector branch from `mereka.scss`; guarded by `verify-mfe-selector-hardening.sh` regression check |
| `[class*="authn"]` | 2026-02-28 | Removed as dead selector branch from `mereka.scss`; guarded by `verify-mfe-selector-hardening.sh` regression check |
| `[class*="learner-dashboard"]` | 2026-02-28 | Removed as dead selector branch from `mereka.scss`; guarded by `verify-mfe-selector-hardening.sh` regression check |
| `[class*="learning"]` | 2026-02-28 | Removed as dead selector branch from `mereka.scss`; guarded by `verify-mfe-selector-hardening.sh` regression check |
| `.page__account-settings` | 2026-02-28 | Removed after slot migration to `account_settings_tab.v1` + `account_settings_field.v1`; guarded by `verify-no-dom-overrides.sh` + `verify-migration-lock.sh` |
| `[class*="course"]` (dashboard/learning scope) | 2026-02-28 | Removed with dead dashboard/learning selector branch; guarded by `verify-mfe-selector-hardening.sh` regression check |
| `[class*="image-cap"]`, `[class*="imagecap"]` | 2026-02-28 | Removed with dead learning selector branch; scoped media fallback no longer needed |
| `[class*="image"]`, `[class*="media"]` (card scope) | 2026-02-28 | Removed with dead learning selector branch; scoped media fallback no longer needed |

---

## Unresolved Selectors (Cannot Be Slot-Migrated Yet)

> These selectors have no viable slot migration path at this time. Each is tracked with rationale, date filed, and next review date.

### US7-TICKET-001: Learning MFE Course Grid Layout Slot (Closed)

- **Selector**: `[class*="learning"]` (11 rule blocks)
- **Closed**: 2026-02-28
- **Resolution**: Removed after dead-selector audit confirmed no live DOM matches in Ulmo learning surfaces.
- **Guardrail**: `scripts/qa/verify-mfe-selector-hardening.sh` now fails if `[class*="learning"]` is reintroduced.

### US7-TICKET-002: Discussions MFE Styling (Closed)

- **Selector**: `[class*="discussions"]` (6 rule blocks)
- **Closed**: 2026-02-28
- **Resolution**: Removed after dead-selector audit confirmed no live DOM matches in Ulmo discussions surfaces.
- **Guardrail**: `scripts/qa/verify-mfe-selector-hardening.sh` now fails if `[class*="discussions"]` is reintroduced.

---

## Summary Matrix

| # | Override | Slot Available | Status | Priority | Effort | Risk | Owner | Target Date |
|---|---------|---------------|--------|----------|--------|------|-------|-------------|
| 1 | Footer | ✅ footer.v1 | ✅ MIGRATED | Done | Done | Low | Mereka | Done |
| 2 | Header Logo | ✅ header_logo.v1 | ✅ MIGRATED | P1 | M | Med | Mereka frontend | Done |
| 3 | Authn Branding | ✅ login_component.v1 | ✅ MIGRATED | P1 | M | Low-Med | Mereka frontend | Done |
| 4 | Dashboard Layout | ✅ sidebar + no_courses | ✅ wildcard fallback removed | P1 | L | Medium | Mereka frontend | Done |
| 5 | Learning Layout | ✅ progress_certificate_status | ✅ wildcard fallback removed | P2 | L | Medium | Mereka / Upstream | Done |
| 6 | Discussions | ❌ None | ✅ wildcard fallback removed | P3 | N/A | Low | Mereka frontend | Done |
| 7 | Account/Settings | ❌ None | 🟡 CSS | P3 | N/A | Med | Mereka frontend | 2026-Q3 review |
| 8 | Paragon Globals | N/A (use tokens) | ✅ STABLE | P3 | N/A | Low | Mereka frontend | N/A |
| 9 | Navbar | ⚠️ Partial (logo) | 🟡 CSS | P2 | S | Low | Mereka frontend | 2026-Q3 |
| 10 | Studio Footer | ✅ studio_footer.v1 | ✅ MIGRATED | P2 | M | N/A | Mereka frontend | Done |

## Migration Roadmap

### Now (Sprint S6)
- [x] Footer → `footer.v1` (DONE)
- [x] Dead-selector cleanup + selector exception hardening (DONE, 115d.18 + Phase C follow-ups)
- [x] Header Logo → `header_logo.v1` (DONE)
- [x] Authn Branding → `login_component.v1` (DONE)
- [x] Studio Footer → `studio_footer.v1` (DONE)
- [x] Dashboard sidebar + no-courses slots wired (`widget_sidebar.v1`, `no_courses_view.v1`) (DONE)
- [x] Navbar token migration (DONE)

### Next Sprint
- [x] Learning layout upstream slot expansion proposal drafted (course-grid/surface-level slots) — tracked here after the concept-root cleanup.

### Backlog
- [ ] Optional: replace remaining structural navbar CSS with slot-owned React shell if upstream adds header layout slots

### Keep as CSS
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
- `docs/reference/architecture/MFE_PLUGIN_SLOT_MIGRATION_REGISTER.md`
- `docs/guides/branding/BRANDING_OPERATING_MODEL.md`

## Verification

Run `./scripts/qa/verify-plugin-slot-migration-register.sh` to check:
1. Register doc exists with all 10 entries
2. Summary matrix is present and complete
3. All MIGRATED items have verification scripts
4. No P0 items remain open

## References
- [MFE_SELECTOR_AUDIT.md](MFE_SELECTOR_AUDIT.md)
- [MFE_PLUGIN_SLOT_MATRIX.md](../operations/MFE_PLUGIN_SLOT_MATRIX.md)
- `LEARNING_SLOT_EXPANSION_PROPOSAL.md` retired with the concept-root cleanup; rely on this register plus the slot inventory for current migration state.
- [footer-slot-exceptions.md](../../policies/architecture/footer-slot-exceptions.md) — Footer fallback exception register with visual evidence pack
- [OEP-65: Frontend Plugin Framework](https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0065-frontend-plugin-framework.html)
