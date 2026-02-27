# Mereka.io Branding Rollout Tracker
_Audience: Design + Platform Eng • Owner: Branding Guild • Last updated: 2026-02-27_

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

## Phase 5 — Next-Gen Branding (PLANNED)
> These items are tracked in detail via specs. See [FRONTEND_TRACKER.md](FRONTEND_TRACKER.md).

- [ ] Create OEP-48 `@edx/brand` package (`infrastructure/tutor/brand-mereka/`) — [spec](../specs/oep48-brand-package_spec.md)
- [ ] Migrate SCSS token overrides to JSON design tokens (Paragon v23+) — [spec](../specs/paragon-design-tokens-migration_spec.md)
- [ ] Enable PARAGON_THEME_URLS for runtime CDN theming.
- [ ] Activate all relevant FPF plugin slots (header, learning, account, profile) — [spec](../specs/mfe-plugin-slots_spec.md)
- [ ] Upgrade Node 18 → 24 (Ulmo default).
- [ ] Multi-tenant token switching (`tenants/` directory).

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
