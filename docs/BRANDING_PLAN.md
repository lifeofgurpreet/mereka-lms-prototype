# Mereka.io Branding Rollout Tracker
_Audience: Design + Platform Eng • Owner: Branding Guild • Last updated: 2026-02-28_

Checklist that tracks the status of each LMS/Studio/MFE theming milestone.

> **Related specs**: [branding-system_spec.md](../specs/branding-system_spec.md), [oep48-brand-package_spec.md](../specs/oep48-brand-package_spec.md), [paragon-design-tokens-migration_spec.md](../specs/paragon-design-tokens-migration_spec.md)
> **Related docs**: [BRANDING.md](BRANDING.md), [MFE_VERSIONS.md](architecture/MFE_VERSIONS.md), [FRONTEND_TRACKER.md](FRONTEND_TRACKER.md)

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

## Phase 2 — Micro-Frontend Theming (PARTIAL)
- [x] Clone required MFEs via `tutor dev start mfe` (learning, account, auth, profile, gradebook, authoring).
- [x] Apply Paragon theme overrides + global styles.
- [x] Replace logos/favicons in each MFE's `public/` folder (`scripts/branding/setup-mfe-branding.sh` copies favicon + logo assets automatically).
- [x] MFE footer slot wired via FPF (`MerekaFooter` component in `mereka_lms.py` plugin).
- [ ] Configure environment copy (`SITE_NAME`, marketing links) — tracked in FRONTEND_TRACKER.md.
- [ ] Run `npm start` smoke checks; capture screenshots.
- [x] Rebuild Docker image with `tutor images build mfe` (production image deployed).

## Phase 3 — LMS/Studio Theme (COMPLETE)
- [x] Create Mereka theme package under `infrastructure/tutor/themes/mereka`.
- [x] Drop in SCSS overrides + images for LMS/Studio.
- [x] LMS SCSS entry points (`lms-main-v1.scss`, `lms-main-v1-rtl.scss`) created.
- [x] CMS SCSS entry points (`studio-main-v1.scss`, `studio-main-v1-rtl.scss`) created.
- [x] Update `tutor config` (`THEME_NAME`, favicon/static paths) and rebuild `openedx` images.
- [x] Verify legacy pages (login, dashboard, course outline) with new branding — deployed to production.

## Phase 4 — Extended Surfaces (NOT STARTED)
- [ ] Discovery service (React app) styling.
- [ ] Email templates (transactional + marketing headers/footers).
- [ ] PDF certificates/badges if applicable.
- ~~Ecommerce/XQueue UIs~~ — Ecommerce replaced by Purchase Gateway (FastAPI); XQueue UI minimal.

## Phase 5 — Next-Gen Branding (IN PROGRESS)
> See [FRONTEND_PHASE_C_PROMPT.md](FRONTEND_PHASE_C_PROMPT.md) and [deep audit](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md).

- [x] Create OEP-48 `@edx/brand` package (`infrastructure/tutor/brand-mereka/`) — [spec](../specs/oep48-brand-package_spec.md)
- [x] **Fix OEP-48 mandatory file gaps** (4 missing files) — see [deep audit §4](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#4-missing-oep-48-mandatory-files-confirmed-from-audit-v1)
- [x] **Split theme.scss for MFE consumption** — `mereka.scss` now imports focused MFE partials instead of full LMS/Studio theme — see [deep audit §3 CRIT-2](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#crit-2-themescss-leaks-600-lines-of-lmsstudio-css-into-every-mfe)
- [x] **Fix runtime theme CSS bloat** — `mereka-brand.min.css` now generated as brand delta (3KB class), `light.min.css` as light-variant delta — see [deep audit §3 CRIT-3](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#crit-3-runtime-theme-css-files-are-bloated-and-duplicated)
- [ ] Migrate SCSS token overrides to JSON design tokens (Paragon v23+) — [spec](../specs/paragon-design-tokens-migration_spec.md)
- [ ] Enable PARAGON_THEME_URLS for runtime CDN theming (config + assets are ready; rollout toggle remains environment-driven).
- [x] Activate all relevant FPF plugin slots (header, learning, account, profile) — [spec](../specs/mfe-plugin-slots_spec.md)
- [x] Consolidate slot variant fallback contract across header/footer components (single runtime map with unknown-host fallback branch).
- [x] Upgrade Node 18 → 24 (Ulmo default).
- [ ] Multi-tenant token switching (`tenants/` directory).

> **Architecture note (2026-02-28)**: Brand package `_variables.scss` is **dead in Ulmo** — Paragon v23+ ignores SCSS variables. Our actual theming works through `mereka.scss` → `_tokens.scss` CSS custom properties. See [deep audit §3 CRIT-1](reviews/FRONTEND_PHASE_AB_DEEP_AUDIT.md#crit-1-brand-package-scss-variables-are-dead).

> **Dead selector warning (2026-02-28)**: ~60% of scoped `[class*="..."]` CSS selectors in `mereka.scss` are **phantom CSS** — they match no actual DOM element in Ulmo MFEs. See [selector inventory §Dead Selector Audit](architecture/MFE_SELECTOR_OVERRIDE_INVENTORY.md#critical-dead-selector-audit-2026-02-28). The token naming gap analysis is at [token audit §Naming Gap](architecture/PARAGON_V22_TOKEN_AUDIT.md#token-naming-gap-analysis-2026-02-28). A registry of 98 FPF plugin slots is at [FPF registry](architecture/FPF_PLUGIN_SLOT_REGISTRY.md).

## QA & Documentation
- [ ] Cross-browser + mobile smoke tests (Chrome, Edge, Safari, Firefox, iOS, Android).
- [ ] Accessibility scan (contrast, focus order) on key pages.
- [ ] Performance spot-check (bundle size changes, Lighthouse).
- [x] Publish implementation notes/screenshots in `docs/BRANDING.md`.
- [x] Update README/AGENTS with quick branding maintenance instructions.

## Deployment Checklist
- [x] Confirm Tutor image builds succeed in CI.
- [x] Regenerate environment with fresh assets (`tutor config save` → `./infrastructure/tutor/apply-patches.sh`).
- [ ] Purge CDN/static caches after deploy.
- [ ] Notify stakeholders with before/after visuals + rollback plan.
