# Mereka.io Branding Rollout Tracker
_Audience: Design + Platform Eng • Owner: Branding Guild • Last verified: 2025-11-08_

Checklist that tracks the status of each LMS/Studio/MFE theming milestone.

## Inputs To Confirm
- [x] Primary/secondary hex palette (captured in `docs/BRANDING.md#palette`).
- [x] Typography sources (Poppins + Lato WOFF2 vendored under `assets/branding/fonts/`).
- [x] PNG/SVG logo variants (horizontal, square, light/white on dark background).
- [x] Favicons/app icons (16/32/180 px) or guidance on generating them.
- [x] Copy for footer links, support email, marketing URL.

## Phase 1 — Preparation
- [x] Stage brand assets inside the repo (`assets/branding/`) for reproducible builds.
- [x] Document Paragon token mapping (color → token, font stacks, spacing tweaks).
- [x] Draft SCSS token overrides shared across MFEs.
- [x] Define legacy LMS/Studio theming requirements (login hero, header, footer).

## Phase 2 — Micro-Frontend Theming
- [x] Clone required MFEs via `tutor dev start mfe` (learning, account, auth, profile, gradebook, authoring).
- [x] Apply Paragon theme overrides + global styles.
- [x] Replace logos/favicons in each MFE's `public/` folder (`scripts/branding/setup-mfe-branding.sh` now copies favicon + logo assets automatically).
- [ ] Configure environment copy (`SITE_NAME`, marketing links).
- [ ] Run `npm start` smoke checks; capture screenshots.
- [ ] Rebuild Docker image with `tutor images build mfe` once look is signed off.

## Phase 3 — LMS/Studio Theme
- [x] Create Mereka theme package under `infrastructure/tutor/themes/mereka`.
- [x] Drop in SCSS overrides + images for LMS/Studio.
- [x] Update `tutor config` (`THEME_NAME`, favicon/static paths) and rebuild `openedx` images.
- [ ] Verify legacy pages (login, dashboard, course outline) with new branding.

## Phase 4 — Extended Surfaces
- [ ] Discovery service (React app) styling.
- [ ] Ecommerce/XQueue UIs (once plugins are live).
- [ ] Email templates (transactional + marketing headers/footers).
- [ ] PDF certificates/badges if applicable.

## QA & Documentation
- [ ] Cross-browser + mobile smoke tests (Chrome, Edge, Safari, Firefox, iOS, Android).
- [ ] Accessibility scan (contrast, focus order) on key pages.
- [ ] Performance spot-check (bundle size changes, Lighthouse).
- [x] Publish implementation notes/screenshots in `docs/BRANDING.md`.
- [x] Update README/AGENTS with quick branding maintenance instructions.

## Deployment Checklist
- [ ] Confirm Tutor image builds succeed in CI.
- [x] Regenerate environment with fresh assets (`tutor config save` → `make tutor-apply` or `./infrastructure/tutor/apply-patches.sh`); Tutor 18.2.2 now serves http://localhost + http://studio.localhost without 500s.
- [ ] Purge CDN/static caches after deploy.
- [ ] Notify stakeholders with before/after visuals + rollback plan.
