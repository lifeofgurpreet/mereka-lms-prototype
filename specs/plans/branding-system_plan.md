---
spec: branding-system_spec.md
tier: 1
status: draft
estimated_effort: "3-5 days (formalization + verification hardening; most assets already exist)"
owner: engineering
last_updated: "2026-02-10"
---

# Implementation Plan: Branding System

**AC Coverage**: AC-001 through AC-020, AC-INT-001 through AC-INT-003 (from `specs/branding-system_spec.md`)

**Source Spec**: `specs/branding-system_spec.md`
**Tier**: 1 (Core Infrastructure)
**Depends On**: Tier 0 (repository-structure, secrets-management, tutor-configuration, cross-cutting-requirements), multi-site-domains
**Blocks**: multi-tenancy-architecture (tenant branding)

## Summary

The Mereka branding system is **substantially implemented**.Theme assets (logos, fonts, SCSS, templates, MFE footer), asset sync scripts, and verification gates already exist. This plan focuses on closing gaps identified by the spec: formalizing the theme structure, hardening verification gates for CI,eliminating any remaining Google Fonts leakage, and ensuringend-to-end coverage across all acceptance criteria.

The work is primarily verification and hardening, not greenfield development.

## Prerequisites

1. Tutor v21 (Ulmo) installed and `TUTOR_ROOT` configured (`infrastructure/tutor/tutor-env.sh`)
2. Docker Desktop with >= 12 GB RAM and 2-4 GB swap
3. `assets/branding/` directory populated with canonical logovariants, favicon, and font files
4. `infrastructure/tutor/apply-patches.sh` functional and passing
5. Multi-site domains spec complete (DNS for academyv2.mereka.io and academy.biji-biji.com)

## Task Breakdown

### Build

- [ ] **[S]** Audit theme directory structure against spec and fill any gaps (`infrastructure/tutor/themes/mereka/`) | AC:#1, #2 | Depends: None
  - Verify all logo variants listed in spec exist: `logo.png`, `logo-horizontal.png`, `logo-horizontal-white.png`, `logo-square.png`, `logo-horizontal.svg`, `logo-horizontal-white.svg`, `logo-square.svg`, `favicon.ico`
  - Verify `lms/`, `cms/`, `mfe/`, `common/` subtrees match spec layout
  - **Done**: `ls` of each directory matches spec tree; `verify-branding-health.sh` passes

- [ ] **[S]** Verify and document `apply-patches.sh` asset sync for all copy targets (`infrastructure/tutor/apply-patches.sh`) | AC: #1, #2, #7 | Depends: None
  - Confirm logos copied to `tutor_env/env/build/openedx/themes/mereka/lms/static/images/`
  - Confirm fonts copied to `tutor_env/env/build/openedx/themes/mereka/lms/static/fonts/`
  - Confirm templates synced to preserve Django template overrides
  - Confirm MFE SCSS synced to `tutor_env/env/plugins/mfe/build/mfe/indigo/mereka/`
  - **Done**: Running `apply-patches.sh` and verifying destination directories contain expected files

- [ ] **[M]** Harden Google Fonts stripping in SASS compilation pipeline (`infrastructure/tutor/apply-patches.sh`) | AC: #5, #6 | Depends: None
  - Verify `apply-patches.sh` strips `@import url('...fonts.googleapis.com...')` from all SCSS sources
  - Verify compiled CSS has zero `fonts.googleapis.com` references
  - Add post-compilation grep guard that fails the build if any Google Fonts references survive
  - **Done**: `grep -r "fonts.googleapis.com" tutor_env/env/build/openedx/lms/static/css/*.css` returns 0 results

- [ ] **[S]** Verify SASS compilation order and theme-first compilation (`infrastructure/tutor/apply-patches.sh`) | AC: #7| Depends: None
  - Confirm `npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka` runs before default theme
  - Confirm both LMS and Studio themes compile
  - **Done**: Build logs show "Compiled mereka theme" beforedefault

- [ ] **[S]** Verify MFE env.config.jsx patch imports mereka.scss and MerekaFooter (`infrastructure/tutor/apply-patches.sh`, `infrastructure/tutor/themes/mereka/mfe/mereka.scss`) | AC: #3, #10 | Depends: None
  - Confirm `env.config.jsx` imports `mereka.scss`
  - Confirm MerekaFooter component replaces default Indigo footer
  - Confirm MerekaFooter includes required content: Mereka Academy branding, tagline, course/dashboard/help links, contactemails, partner links, copyright, Open edX credit
  - **Done**: `grep "MerekaFooter"` in env.config.jsx returnsmatch; visual inspection of running MFE confirms footer

- [ ] **[S]** Verify MFE theme fonts copied to build context(`infrastructure/tutor/themes/mereka/mfe/fonts/`) | AC: #5 |Depends: None
  - Confirm `*.woff2` files exist in `mfe/fonts/`
  - **Done**: `ls infrastructure/tutor/themes/mereka/mfe/fonts/*.woff2` shows Poppins + Lato variants

- [ ] **[S]** Verify Django settings `DEFAULT_SITE_THEME = "mereka"` (`deploy/k8s/base/apps/openedx/settings/lms/production.py`) | AC: #1, #8 | Depends: None
  - Confirm setting present in LMS production settings
  - Confirm SiteConfiguration considered for per-domain overrides (SHOULD)
  - **Done**: `grep "DEFAULT_SITE_THEME" deploy/k8s/base/apps/openedx/settings/lms/production.py` returns `"mereka"`

- [ ] **[M]** Verify multi-domain consistency across academyv2.mereka.io and academy.biji-biji.com (`scripts/qa/verify-public-branding.sh`) | AC: #8 | Depends: Build tasks above
  - Run `verify-public-branding.sh prod` and confirm both domains pass all checks
  - If either domain shows default branding, investigate SiteConfiguration and Caddy routing
  - **Done**: `verify-public-branding.sh prod` exits 0

### Test

- [ ] **[S]** Run `verify-branding-health.sh` (source gate) and document any failures (`scripts/branding/verify-branding-health.sh`) | AC: #7 | Depends: Build tasks
  - Execute script and capture output
  - Fix any failures found
  - **Done**: Script exits 0 with all checks passing

- [ ] **[S]** Run `run-branding-gates.sh prod` (full gate suite) (`scripts/branding/run-branding-gates.sh`) | AC: #1-#10 |Depends: Build tasks
  - Execute `BRANDING_LEVEL=deep scripts/branding/run-branding-gates.sh prod`
  - Capture output showing source gate + live gate pass
  - **Done**: Script exits 0

- [ ] **[M]** Run Google Fonts absence verification on compiled CSS (`scripts/branding/verify-branding-health.sh`, manualgrep) | AC: #6 | Depends: Build tasks
  - Run `grep "fonts.googleapis.com" tutor_env/env/build/openedx/lms/static/css/*.css` and confirm 0 results
  - Run `verify-public-branding.sh prod` with deep branding level
  - **Done**: Zero Google Fonts references found

- [ ] **[S]** Run Studio branding verification (`scripts/qa/verify-studio-authoring-branding.sh`) | AC: #2, #9 | Depends:Build tasks
  - Execute `scripts/qa/verify-studio-authoring-branding.sh prod`
  - Confirm Studio homepage shows Mereka branding
  - Confirm Studio preview shows Mereka branding
  - **Done**: Script exits 0

- [ ] **[S]** Verify favicon across all endpoints (manual + script) | AC: #4 | Depends: Build tasks
  - `curl -I https://academyv2.mereka.io/theming/asset/mereka/images/favicon.ico` returns 200
  - `curl -I https://academy.biji-biji.com/theming/asset/mereka/images/favicon.ico` returns 200
  - Browser inspection confirms Mereka icon, not Open edX default
  - **Done**: HTTP 200 for both domains; browser shows correct icon

- [ ] **[S]** Verify MFE footer renders on all MFE surfaces (manual + script) | AC: #3 | Depends: Build tasks
  - Check `apps.academyv2.mereka.io/authn/login` — MerekaFooter visible
  - Check `apps.academyv2.mereka.io/account/` — MerekaFootervisible
  - Check `apps.academyv2.mereka.io/profile/` — MerekaFootervisible
  - Check `apps.academyv2.mereka.io/learning/` — MerekaFootervisible
  - **Done**: All four surfaces show MerekaFooter

- [ ] **[S]** Verify login page branding (manual + script) |AC: #10 | Depends: Build tasks
  - Navigate to `apps.academyv2.mereka.io/authn/login`
  - Confirm Mereka logo, Mereka gradient, and custom fonts
  - No Open edX default branding elements
  - **Done**: Screenshot or script output confirms Mereka branding on login

### Observability

- [ ] **[S]** Verify apply-patches.sh produces asset sync logoutput (`infrastructure/tutor/apply-patches.sh`) | Req: OBS-logs | Depends: Build tasks
  - Run `apply-patches.sh` and confirm console output shows "Copied logo.png to LMS theme" (or equivalent)
  - **Done**: Log lines present for each copied asset

- [ ] **[S]** Verify asset size budget remains under 5 MB (`scripts/branding/verify-branding-health.sh`) | Req: NFR-asset-size | Depends: Build tasks
  - Run `du -sh infrastructure/tutor/themes/mereka/` and confirm < 5 MB per copy (common, lms, cms, mfe)
  - **Done**: Total per-copy under 5 MB

- [ ] **[S]** Document branding CI dashboard expectations (`docs/guides/branding/BRANDING_OPERATING_MODEL.md`) | Req: OBS-dashboard | Depends: None
  - Verify branding health section in operating model doc references CI dashboard pass/fail
  - **Done**: Doc section exists describing CI gate integration

### Docs

- [ ] **[S]** Verify branding docs are up-to-date (`docs/guides/branding/BRANDING.md`, `docs/status/active/BRANDING_PLAN_2026-03-03.md`, `docs/guides/branding/BRANDING_VERIFICATION_CHECKLIST.md`) | Depends: None
  - Confirm docs match current asset paths and script names
  - Confirm rollout workflow documented for new team members
  - **Done**: Docs reviewed and accurate

- [ ] **[S]** Verify operating model and guardrails docs (`docs/guides/branding/BRANDING_OPERATING_MODEL.md`, `docs/guides/branding/BRANDING_GUARDRAILS.md`) | Depends: None
  - Confirm edge case recovery procedures match spec edge cases section
  - **Done**: Recovery steps for logo-not-appearing, Google-fonts-still-loading, MFE-footer-not-rendering, font-files-missing, and theme-cache-invalidation all documented

### Rollout

- [ ] **[S]** Verify feature flag / theme toggle mechanism exists (`deploy/k8s/base/apps/openedx/settings/lms/production.py`) | Depends: None
  - Confirm `DEFAULT_SITE_THEME` can be unset to roll back todefault Open edX branding
  - Document rollback procedure in spec rollout section
  - **Done**: `tutor config save --unset DEFAULT_SITE_THEME`verified to revert theme

- [ ] **[S]** Run full pre-deployment verification pipeline (`scripts/branding/run-branding-gates.sh prod`) | Depends: Allbuild + test tasks
  - Source gate passes
  - Live gate passes
  - Audit passes
  - **Done**: `run-branding-gates.sh prod` exits 0

## Milestones

| Milestone | Tasks | Target |
|-----------|-------|--------|
| M1: Source verification | All Build tasks + source gate test | Day 1 |
| M2: Live verification | All live gate tests (AC #1-#10) | Day 2 |
| M3: Hardening | Google Fonts stripping hardened, NFR checks| Day 3 |
| M4: Docs + Rollout | Docs verified, rollout procedure tested | Day 4 |
| M5: Sign-off | All gates green, spec status -> approved | Day 5 |

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Google Fonts imports re-introduced by upstream Open edX SCSS updates | Medium | Medium | Post-compilation grep guard in`apply-patches.sh`; CI enforcement |
| `tutor config save` regenerates templates, wiping patches |High (happens on every config change) | High | `apply-patches.sh` always runs after `config save`; documented in CLAUDE.md |
| MFE build cache serves stale branding | Medium | Low | `tutor images build mfe --no-cache`; documented in edge cases |
| Browser/CDN cache masks branding updates | Medium | Low | `collectstatic --clear` + cache-busting query params; documented in rollout |
| Studio preview uses different theme rendering path | Low |Medium | Separate `verify-studio-authoring-branding.sh` checkcovers this |
| Multi-domain SiteConfiguration misconfiguration | Low | Medium | `verify-public-branding.sh` checks both domains; alerton failure |
