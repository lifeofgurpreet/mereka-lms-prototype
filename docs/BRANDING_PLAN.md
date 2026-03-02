# Mereka.io Branding Rollout Tracker
_Audience: Design + Platform Eng • Owner: Branding Guild • Last updated: 2026-03-02_

Checklist that tracks the status of each LMS/Studio/MFE theming milestone.

> **Related specs**: [branding-system_spec.md](../specs/branding-system_spec.md), [oep48-brand-package_spec.md](../specs/oep48-brand-package_spec.md), [paragon-design-tokens-migration_spec.md](../specs/paragon-design-tokens-migration_spec.md)
> **Related docs**: [BRANDING.md](BRANDING.md), [MFE_VERSIONS.md](architecture/MFE_VERSIONS.md), [FRONTEND_TRACKER.md](FRONTEND_TRACKER.md)

## Progress Summary

| Phase | Status | Remaining |
|-------|--------|-----------|
| Phase 1 — Preparation | **COMPLETE** | — |
| Phase 2 — MFE Theming | **COMPLETE** | — |
| Phase 3 — LMS/Studio Theme | **COMPLETE** | — |
| Phase 4 — Extended Surfaces | **MOSTLY COMPLETE** | PDF certificates only |
| Phase 5 — Next-Gen Branding | **COMPLETE** | — |
| Phase 6 — Slot Branding Expansion | **FROZEN (Issue #111 decision)** | Freeze new slot expansion until dev runtime stability is restored |
| Phase 7 — BEM Reduction | **IN PROGRESS** | Remaining selector pruning decisions after latest green live audit rerun |
| QA & Documentation | **MOSTLY COMPLETE** | Before/after visuals + stakeholder handoff bundle |
| Deployment | **MOSTLY COMPLETE** | Dev runtime re-verify after CSP rollout, stakeholder notification |

---

## 2026-03-02 Stabilization Snapshot (Issues #105, #107, #108, #106, #111)

- Runtime evidence (`#105`):
  - `./scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only` passed and wrote artifacts under `var/screenshots/dev/20260302T010124Z/` (one non-blocking render-timeout warning on `mfe-authn-login`).
  - `./scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers` passed (`PASS=17 WARN=0 FAIL=0`).
  - `./scripts/qa/verify-studio-authoring-branding.sh dev` passed (`failures=0`) on latest rerun.
- BEM + a11y (`#107`, `#108`):
  - `./scripts/qa/verify-mfe-selector-hardening.sh` passed.
  - `./scripts/qa/verify-a11y-contrast-focus.sh` passed with documented non-blocking warnings.
  - `./scripts/qa/verify-wcag-contrast-v2.sh` passed.
  - `./scripts/qa/verify-mfe-live-dom-audit.sh --env dev --audit-profile phase7_full --project chromium` passed (`1 passed`), log: `var/qa/mfe-live-dom-audit-dev-20260302T010325Z.log`.
- Root-cause hardening applied in repo:
  - Updated `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile` CSP to allow required CDN/Google font domains for MFE runtime script/style/font loads.
  - Added bounded recovery + low-signal hydration handling in `tests/e2e/tests/selector-dom-audit.spec.ts` to reduce headless false negatives.
  - Detailed stabilization log: `docs/operations/FRONTEND_RUNTIME_STABILITY_STATUS_2026-03-02.md`.
  - Issue closure matrix: `docs/operations/FRONTEND_CLOSURE_STATUS_MATRIX_2026-03-02.md`.
- Certificate closure (`#106`):
  - `./scripts/qa/verify-certificate-branding.sh` passed (`PASS=25 WARN=0 FAIL=0`).
- Phase 6 decision (`#111`):
  - Slot-expansion lane remains intentionally frozen as a scope decision; runtime checks above are now green on latest rerun.

---

## Inputs To Confirm
- [x] Primary/secondary hex palette (captured in `docs/BRANDING.md#palette`).
- [x] Typography sources (Poppins + Lato WOFF2 vendored under `assets/branding/fonts/`).
- [x] PNG/SVG logo variants (horizontal, square, light/white on dark background).
- [x] Favicons/app icons (16/32/256 px) generated and deployed.
- [x] Copy for footer links, support email, marketing URL.

## Phase 1 — Preparation (COMPLETE)
- [x] Stage brand assets inside the repo (`assets/branding/`) for reproducible builds.
- [x] Document Paragon token mapping (color → token, font stacks, spacing tweaks).
- [x] Draft SCSS token overrides shared across MFEs.
- [x] Define legacy LMS/Studio theming requirements (login hero, header, footer).

## Phase 2 — Micro-Frontend Theming (COMPLETE)
- [x] Clone required MFEs via `tutor dev start mfe` (learning, account, auth, profile, gradebook, authoring).
- [x] Apply Paragon theme overrides + global styles.
- [x] Replace logos/favicons in each MFE's `public/` folder (`scripts/branding/setup-mfe-branding.sh` copies favicon + logo assets automatically).
- [x] MFE footer slot wired via FPF (`MerekaFooter` component in `mereka_lms.py` plugin).
- [x] Configure environment copy (`SITE_NAME`, marketing/support/legal links) via runtime variant map (`MEREKA_SITE_VARIANTS`) and verify with `verify-footer-variant-matrix.sh`.
- [x] Rebuild Docker image with `tutor images build mfe` (production image deployed).
- [ ] Capture MFE screenshots (authn, dashboard, learning, account) showing brand tokens applied via runtime CSS.

## Phase 3 — LMS/Studio Theme (COMPLETE)
- [x] Create Mereka theme package under `infrastructure/tutor/themes/mereka`.
- [x] Drop in SCSS overrides + images for LMS/Studio.
- [x] LMS SCSS entry points (`lms-main-v1.scss`, `lms-main-v1-rtl.scss`) created.
- [x] CMS SCSS entry points (`studio-main-v1.scss`, `studio-main-v1-rtl.scss`) created.
- [x] Update `tutor config` (`THEME_NAME`, favicon/static paths) and rebuild `openedx` images.
- [x] Verify legacy pages (login, dashboard, course outline) with new branding — deployed to production.

## Phase 4 — Extended Surfaces (MOSTLY COMPLETE)
- [x] Discovery service styling baseline + token wiring (`verify-catalog-discovery.sh` source gate).
- [x] Email templates (16 types × 3 languages) — branded gradient header, tenant-aware org name, localized CTAs. Verified by `verify-certificate-branding.sh`.
- [ ] PDF certificates/badges if applicable.
- ~~Ecommerce/XQueue UIs~~ — Ecommerce replaced by Purchase Gateway (FastAPI); XQueue UI minimal.

## Phase 5 — Next-Gen Branding (COMPLETE)

> See [FRONTEND_PHASE_C_PROMPT.md](FRONTEND_PHASE_C_PROMPT.md) and [deep audit](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md).

### Phase A/B — Audit + Architecture Fixes (COMPLETE)
- [x] Create OEP-48 `@edx/brand` package (`infrastructure/tutor/brand-mereka/`) — [spec](../specs/oep48-brand-package_spec.md)
- [x] **Fix OEP-48 mandatory file gaps** (4 missing files) — see [deep audit §4](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#4-missing-oep-48-mandatory-files-confirmed-from-audit-v1)
- [x] **Close OEP-48 interface gaps** — `logo.js` exports + canonical aliases (`logo_white.*`, `favicon.png`) now enforced by brand-package/OEP-48 verifiers.
- [x] **Split theme.scss for MFE consumption** — `mereka.scss` now imports focused MFE partials instead of full LMS/Studio theme — see [deep audit §3 CRIT-2](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#crit-2-themescss-leaks-600-lines-of-lmsstudio-css-into-every-mfe)
- [x] **Fix runtime theme CSS bloat** — `mereka-brand.min.css` now generated as brand delta (1.9KB), `light.min.css` as light-variant delta — see [deep audit §3 CRIT-3](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#crit-3-runtime-theme-css-files-are-bloated-and-duplicated)
- [x] **OEP-48 asset-only contract enforced** — `package.json` has explicit exports map, no scripts/peerDependencies/dependencies, verified by `verify-mfe-css-architecture.sh` Check 5.

### Phase C — Token Grounding + BEM Hardening (COMPLETE)
- [x] **Paragon v22 token audit** — 1,318 consumed tokens mapped; 30 consumed+defined, 1,288 consumed+missing, 50 defined+ignored. See [PARAGON_V22_TOKEN_AUDIT.md](architecture/PARAGON_V22_TOKEN_AUDIT.md).
- [x] **Canonical token naming enforced** — All 12 short-form→canonical mismatches resolved (`--pgn-color-primary` → `--pgn-color-primary-base`, etc.). Regression blocklist active in `verify-design-tokens-migration.sh` (55/55 PASS).
- [x] **Legacy alias removal** — Zero `--mereka-teal`, `--mereka-magenta`, `--mereka-color-indigo-rgb` aliases remain.
- [x] **BEM override hardening** — All 80 color/shadow/radius values in `mereka.scss` now use `var()` references. Zero hardcoded hex values outside comments.
- [x] **PARAGON_THEME_URLS enabled by default** — `MEREKA_PARAGON_THEME_ENABLED: true` in plugin. Runtime CSS served from `/theme/` (core.min.css 523KB, mereka-brand.min.css 1.9KB). Operator rollback via `MEREKA_PARAGON_THEME_ENABLED=false`.
- [x] **CSS architecture guardrails in CI** — `verify-mfe-css-architecture.sh` (no monolithic theme import, tokens-only _tokens.scss, no LMS/Studio selector leakage, asset-only brand package), `verify-mfe-reduced-motion.sh` (transform guards).
- [x] **Paragon token coverage verification** — `verify-paragon-token-coverage.sh` (49/49 PASS).

### Phase D — Dead Selector Cleanup + Slot Migration (COMPLETE)
- [x] **Dead selector audit** — ~60% of `[class*="..."]` selectors confirmed phantom CSS. See [selector inventory](architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md#critical-dead-selector-audit-2026-02-28).
- [x] **All dead selectors removed** — `[class*="authn"]`, `[class*="learner-dashboard"]`, `[class*="learning"]`, `[class*="discussions"]`, `[class*="account-page"]` all removed with tombstone comments.
- [x] **Account wildcard replaced** — `[class*="account-settings"]` → explicit `.page__account-settings` class scope.
- [x] **Header/footer/authn slots implemented** — `MerekaHeaderLogo`, `MerekaFooter`, `MerekaAuthnLoginBranding` components in `mereka_lms.py`.
- [x] Upgrade Node 18 → 24 (Ulmo default).
- [x] Multi-tenant token switching (`tenants/` directory) via generated tenant `css/tokens.css` from `branding.json` (`scripts/tenants/sync-tenant-branding.sh` + `verify-tenant-token-switching.sh`).
- [x] Enforce post-rollout runtime branding verification in `scripts/infra/release-openedx-gitops.sh` (strict `verify-public-branding` + surface audit, with explicit emergency skip flags).
- [x] Consolidate slot variant fallback contract across header/footer components (single runtime map with unknown-host fallback branch).

> **Architecture note (2026-02-28)**: Brand package `_variables.scss` is **dead in Ulmo** — Paragon v23+ ignores SCSS variables. Our actual theming works through `mereka.scss` → `_tokens.scss` CSS custom properties. See [deep audit §3 CRIT-1](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#crit-1-brand-package-scss-variables-are-dead).

---

## Phase 6 — Slot Branding Expansion (IN PROGRESS)

> **98 FPF slots available, 47 currently wired.** See [FPF_PLUGIN_SLOT_REGISTRY.md](architecture/FPF_PLUGIN_SLOT_REGISTRY.md).

### Currently Wired Slots (47)

**Layout (6)**:
`header_logo.v1`, `header_desktop_main_menu.v1`, `header_mobile_main_menu.v1`, `header_learning.v1`, `footer.v1`, `studio_footer.v1`

**Authn (1)**: `login_component.v1`

**Learner Dashboard (5)**:
`course_card.v1`, `course_card_action.v1`, `dashboard_header.v1`, `widget_sidebar.v1`, `no_courses_view.v1`

**Learning (22)**:
`course_outline_sidebar.v1`, `course_outline_sidebar_trigger.v1`, `course_outline_mobile_sidebar_trigger.v1`, `course_outline_tab_notifications.v1`, `course_home_section_outline.v1`, `course_breadcrumbs.v1`, `course_tab_links.v1`, `course_exit_view_courses.v1`, `course_exit_dashboard_footnote_link.v1`, `course_recommendations.v1`, `content_iframe_loader.v1`, `content_iframe_error.v1`, `gated_unit_content_message.v1`, `learner_tools.v1`, `next_unit_top_nav_trigger.v1`, `notification_tray.v1`, `notification_widget.v1`, `notifications_discussions_sidebar.v1`, `notifications_discussions_sidebar_trigger.v1`, `progress_certificate_status.v1`, `progress_tab_certificate_status_main_body.v1`, `progress_tab_certificate_status_side_panel.v1`

**Learning (continued, 4)**: `progress_tab_course_grade.v1`, `progress_tab_grade_breakdown.v1`, `progress_tab_related_links.v1`, `sequence_container.v1`, `sequence_navigation.v1`, `unit_title.v1`

**Account (2)**: `additional_profile_fields.v1`, `id_verification_page.v1`

**Profile (1)**: `additional_profile_fields.v1`

**Catalog (3)**: `catalog_header.v1`, `catalog_card.v1`, `catalog_filters.v1`

**Authoring (1)**: `course_unit_sidebar.v1`

### Next Slots to Wire (priority order)

- [ ] **`authoring.course_outline_header.v1`** — Studio course outline branding. Studio has footer + unit sidebar only, no outline header.
- [ ] **`authoring.grading.v1`** — Studio grading page branding.
- [ ] **Remaining catalog slots** — 22 catalog slots available, only 3 wired so far.

---

## Phase 7 — BEM Reduction + Selector Hardening (IN PROGRESS)

> **69 BEM selectors remain in `mereka.scss`. 0 SELECTOR-EXCEPTIONs. 0 hardcoded hex.**

### Current State
- [x] All `[class*="..."]` wildcards removed (was 10 dead selectors).
- [x] All color/shadow/radius values use `var()` references (80 var() refs, 0 hardcoded hex).
- [x] Canonical token naming enforced (no legacy aliases, no short-form names).
- [ ] **Audit remaining 69 BEM selectors against live Ulmo DOM** — verify each still matches a real component. Remove any that don't.
- [x] **SELECTOR-EXCEPTIONs resolved** — reduced from 2 to 0. `.page__account-settings` now handled via slot.
- [ ] **style-dictionary JSON pipeline** — Replace SCSS-to-CSS extraction in `build-tokens.sh` with a proper JSON → CSS pipeline using `style-dictionary`. Enables multi-format output (CSS, SCSS, JSON, iOS, Android).
- [ ] **Dark mode variant** — Add `variants.dark` to PARAGON_THEME_URLS config. Currently light-only (`mereka-brand-light.min.css` is identical to `mereka-brand.min.css`).

---

## QA & Documentation
- [x] Cross-browser + mobile smoke tests — `verify-cross-browser-branding-smoke.sh` (Chromium, Firefox, WebKit with graceful fallback). Playwright-based.
- [x] npm-start MFE smoke tests — `verify-npm-start-mfe-smoke.sh` (authn, learning, account, profile with screenshot capture).
- [x] Accessibility scan (contrast, focus order) on key pages. Current gates pass (`verify-a11y-contrast-focus.sh`, `verify-wcag-contrast-v2.sh`) with non-blocking documented warnings.
- [x] Performance spot-check — runtime theme preflight checks built into both smoke scripts (PARAGON_THEME_URLS verification, theme-mode detection).
- [ ] Capture before/after screenshots for all branded surfaces. Latest deterministic MFE capture set: `var/screenshots/dev/20260302T010124Z/`.
- [x] Publish implementation notes/screenshots in `docs/BRANDING.md`.
- [x] Update README/AGENTS with quick branding maintenance instructions.
- [x] Dead selector audit documented in [MFE_SELECTOR_OVERRIDE_INVENTORY.md](architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md).
- [x] Token audit documented in [PARAGON_V22_TOKEN_AUDIT.md](architecture/PARAGON_V22_TOKEN_AUDIT.md).
- [x] FPF slot registry documented in [FPF_PLUGIN_SLOT_REGISTRY.md](architecture/FPF_PLUGIN_SLOT_REGISTRY.md).
- [x] Certificate branding verified — `verify-certificate-branding.sh` (CSS overrides, slot wiring, email templates, localized wrappers).

## Deployment Checklist
- [x] Confirm Tutor image builds succeed in CI.
- [x] Regenerate environment with fresh assets (`tutor config save` → `./infrastructure/tutor/apply-patches.sh`).
- [x] Runtime branding verification enforced in release script (`release-openedx-gitops.sh`).
- [x] PARAGON_THEME_URLS enabled by default (`MEREKA_PARAGON_THEME_ENABLED: true` in plugin). MFE image rebuild needed to pick up.
- [x] Cache purge script ready — `scripts/infra/purge-frontend-theme-cache.sh` (dry-run by default, `--apply` to execute Cloudflare purge).
- [ ] Notify stakeholders with before/after visuals + rollback plan.

---

## Next Work — Implementor Brief (Priority Order)

### Tranche 1: Remaining Slot Expansion (Phase 6 — lower priority now)

47 of 98 slots are wired. The highest-impact slots (dashboard, learning, catalog, authn) are done. Remaining work is incremental.

| Priority | Slot | What to Build | Why |
|----------|------|---------------|-----|
| **P1** | `authoring.course_outline_header.v1` | Studio outline header branding | Studio has footer + unit sidebar, no outline header |
| **P1** | `authoring.grading.v1` | Studio grading page | Currently unstyled |
| **P2** | Remaining catalog slots (19) | Various catalog surfaces | 3 of 22 catalog slots wired |

**Files**: `infrastructure/tutor/plugins/mereka_lms.py`, `docs/architecture/FPF_PLUGIN_SLOT_REGISTRY.md`
**Pattern**: Follow existing `MerekaHeaderLogo`/`MerekaFooter` pattern — React component inline in plugin, `PLUGIN_OPERATIONS.Insert`/`Replace`.

### Tranche 2: BEM Selector Audit + Reduction (Phase 7)

| Task | What | Files |
|------|------|-------|
| **Audit 69 BEM selectors** | Check each against live Ulmo DOM. Remove any that don't match real components. | `mereka.scss` |
| **Reduce BEM count** | As slots replace BEM overrides, delete the corresponding CSS selectors. Target: <40 selectors. | `mereka.scss` |

### Tranche 3: PDF Certificates (Phase 4 closure)

| Task | What | Files |
|------|------|-------|
| **PDF certificates** | If certificates are enabled, brand the template with Mereka logo + colors. | Theme certificate templates |

> Email templates are DONE (16 types × 3 languages, branded gradient header, verified by `verify-certificate-branding.sh`).

### Tranche 4: Accessibility + Screenshots

| Task | What |
|------|------|
| **Accessibility scan** | Lighthouse a11y on login + dashboard. Check magenta button contrast, focus indicators, heading order. Known: `#f4be48` gold on white fails AA. |
| **Before/after screenshots** | Capture all branded surfaces for stakeholder notification. |

> Cross-browser smoke, performance spot-check, and cache purge are DONE (scripts exist and pass).

### Tranche 5: Future (lower priority, no deadline)

| Task | What |
|------|------|
| **style-dictionary pipeline** | Replace SCSS→CSS extraction with JSON→CSS via style-dictionary. Multi-format output. |
| **Dark mode** | Add `variants.dark` to PARAGON_THEME_URLS. Currently light-only. |
| **Performance budgets in CI** | Lighthouse CI with LCP < 2.5s, bundle < 300KB gzip, theme CSS < 50KB. |
| **CI Phase 5 — ARC migration** | Migrate heavy builds to `mereka-k8s-heavy-builders`. See `CI_OPTIMIZATION_TRACKER.md`. Requires ARC deployed to rke2-nonprod. |
| **Plugin file splitting** | Extract 47 React component strings from `mereka_lms.py` into separate file(s). Status: staged/in-progress (`#109` phase 1 + phase 2 + phase 3 + phase 4 + phase 5 + phase 6 + phase 7 complete; verifier compatibility layer expanded, QA coupling reduced 98→36). See `docs/operations/PLUGIN_SPLIT_STATUS_2026-03-02.md`. |
| **Hardcoded brand name** | Replace "Mereka Academy" literals in enterprise profile fields with `{variant.brand}`. |

---

## Verification Scripts

| Script | Checks | Status |
|--------|-------:|--------|
| `verify-design-tokens-migration.sh` | 55 | All PASS |
| `verify-paragon-token-coverage.sh` | 49 | All PASS |
| `verify-mfe-css-architecture.sh` | 7 | All PASS |
| `verify-mfe-reduced-motion.sh` | 2 | All PASS |
| `verify-oep48-brand-package.sh` | — | PASS |
| `verify-brand-package-runtime.sh` | — | PASS |
| `verify-branding-asset-sync.sh` | — | PASS |
| `verify-paragon-runtime.sh` | — | PASS |
| `verify-tenant-token-switching.sh` | 15 | All PASS |
| `verify-visual-parity-checkpoints.sh` | 42 | All PASS |
| `verify-enterprise-readiness-integrity.sh` | — | All PASS |
