# Mereka.io Branding Rollout Tracker

## Inputs To Confirm
- [ ] Primary/secondary hex palette (confirm final values from brand team).
- [ ] Typography sources (Google Fonts URLs or self-hosted files for Lato + Poppins).
- [ ] PNG/SVG logo variants (horizontal, square, light/white on dark background).
- [ ] Favicons/app icons (16/32/180 px) or guidance on generating them.
- [ ] Copy for footer links, support email, marketing URL.

## Phase 1 — Preparation
- [ ] Stage brand assets inside the repo (`assets/branding/`) for reproducible builds.
- [ ] Document Paragon token mapping (color → token, font stacks, spacing tweaks).
- [ ] Draft SCSS token overrides shared across MFEs.
- [ ] Define legacy LMS/Studio theming requirements (login hero, header, footer).

## Phase 2 — Micro-Frontend Theming
- [ ] Clone required MFEs via `tutor dev start mfe` (learning, account, auth, profile, gradebook, authoring).
- [ ] Apply Paragon theme overrides + global styles.
- [ ] Replace logos/favicons in each MFE’s `public/` folder.
- [ ] Configure environment copy (`SITE_NAME`, marketing links).
- [ ] Run `npm start` smoke checks; capture screenshots.
- [ ] Rebuild Docker image with `tutor images build mfe` once look is signed off.

## Phase 3 — LMS/Studio Theme
- [ ] Create Mereka theme package under `ops/themes/mereka`.
- [ ] Drop in SCSS overrides + images for LMS/Studio.
- [ ] Update `tutor config` (`THEME_NAME`, favicon/static paths) and rebuild `openedx` images.
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
- [ ] Publish implementation notes/screenshots in `docs/BRANDING.md`.
- [ ] Update README/AGENTS with quick branding maintenance instructions.

## Deployment Checklist
- [ ] Confirm Tutor image builds succeed in CI.
- [ ] Regenerate environment with fresh assets (`tutor config save` → `./ops/tutor/apply-patches.sh`).
- [ ] Purge CDN/static caches after deploy.
- [ ] Notify stakeholders with before/after visuals + rollback plan.
