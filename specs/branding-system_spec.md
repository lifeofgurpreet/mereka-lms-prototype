---
id: "SPEC-BRANDING-SYSTEM"
title: "Branding System"
type: "feature_spec"
status: "approved"
spec_class: "domain"
owner: "platform"
created: "2026-02-27"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "frontend"
normativity: "normative"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/branding/verify-branding-health.sh"
  - "scripts/branding/run-branding-gates.sh"
interfaces:
  - "infrastructure/tutor/themes/mereka/"
  - "assets/branding/"
tags:
  - "frontend.brand.tokens"
  - "frontend.composition"
  - "docs.policy"
summary: "Defines the canonical branding system for Mereka Academy across LMS, Studio, and MFEs, including assets, theme structure, and verification gates."
vehicle: "talent_platform"
last_updated: "2026-02-27"
version: "1.1.0"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/multi-site-domains_spec.md"
  - "specs/tutor-configuration_spec.md"
links:
  related_docs:
    - "docs/guides/branding/BRANDING.md"
    - "docs/guides/branding/BRANDING_OPERATING_MODEL.md"
    - "docs/guides/branding/BRANDING_GUARDRAILS.md"
    - "docs/guides/branding/BRANDING_INCIDENT_TEMPLATE.md"
  related_specs:
    - "specs/tutor-configuration_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/oep48-brand-package_spec.md"
    - "specs/plans/paragon-design-tokens-migration_spec.md"
    - "specs/mfe-plugin-slots_spec.md"
---

# Human Summary

## What we're building
A custom branding system for Mereka Academy that replaces the default Open edX visual identity across all touchpoints: the LMS learner interface, Studio course authoring, and all React-based micro-frontends. The system manages logo variants, fonts, color themes, a custom footer component, and SASS compilation, with automated verification gates to guarantee branding consistency after every build and deployment.

## Why it matters
Brand consistency directly affects learner trust and partner credibility. Mereka Academy serves both the academyv2.mereka.io and academy.biji-biji.com domains, and any default Open edX branding leaking through signals an unfinished product. The branding system also strips Google Fonts dependencies, ensuring privacy compliance and faster page loads. Without automated verification, branding regressions silently ship with every Tutor config regeneration.

## Success looks like
- Every page across LMS, Studio, and all MFEs displays Mereka branding with zero Open edX default leakage.
- `scripts/branding/verify-branding-health.sh` passes in CI on every build.
- Google Fonts requests are absent from production network traffic.
- A new team member can update branding assets by following the rollout workflow without needing tribal knowledge.

# Agent Contract

## Scope

This spec covers the custom branding system for Mereka Academy, including theme assets, MFE branding, and verification gates to ensure consistent branding across LMS, Studio, and micro-frontends.

**Architecture Note**: The branding system uses a plugin-first approach as documented in ADR-014:
- **Plugin** (`infrastructure/tutor/plugins/mereka_lms.py`): Configuration patches (Django settings, MFE footer component, Google Fonts stripping, build config)
- **Low-level patch helper** (`infrastructure/tutor/apply-patches.sh`): File-system operations (asset sync, theme directories, font distribution) exercised through the canonical Tutor prepare path

Both are required and complementary.

## Non-goals

- Multi-tenant white-labeling (future enhancement)
- Dynamic theme switching via UI (themes applied at build time)
- Brand asset CDN optimization (assets served from static files)
- Migration to OEP-48 brand package in current release (deferred per ADR-014) — **NOW PLANNED**: see `specs/oep48-brand-package_spec.md`
- Full FPF slot migration in this release cycle (opportunistic per ADR-014, plugin-first section) — **NOW PLANNED**: see `specs/mfe-plugin-slots_spec.md`
- JSON design token pipeline and PARAGON_THEME_URLS runtime theming — see `specs/plans/paragon-design-tokens-migration_spec.md`

## Requirements

### Functional

#### Theme Structure

The system MUST maintain the following theme structure:

```
infrastructure/tutor/themes/mereka/
├── lms/
│   ├── static/
│   │   ├── images/
│   │   │   ├── logo.png
│   │   │   ├── logo-horizontal.png
│   │   │   ├── logo-horizontal-white.png
│   │   │   ├── logo-square.png
│   │   │   ├── logo-horizontal.svg
│   │   │   ├── logo-horizontal-white.svg
│   │   │   ├── logo-square.svg
│   │   │   └── favicon.ico
│   │   ├── fonts/
│   │   │   └── *.woff2
│   │   ├── css/
│   │   │   └── custom-styles.css
│   │   └── sass/
│   │       └── partials/
│   └── templates/
│       └── (Django template overrides)
├── cms/
│   └── (similar structure for Studio)
├── mfe/
│   ├── fonts/
│   ├── mereka.scss
│   └── env.config.jsx (injected via patch)
└── common/
    └── templates/
```

#### Asset Sync Workflow (Script-Delivered)

- The system MUST run the canonical Tutor prepare path to realize theme assets into rendered build directories before image builds
- The system MUST mirror source theme image directories into `tutor_env/env/build/openedx/themes/mereka/**/static/images/`
- The system MUST mirror source font directories into `tutor_env/env/build/openedx/themes/mereka/**/static/fonts/`
- The system MUST sync templates to preserve Django template overrides
- The system MUST sync MFE theme source to `tutor_env/env/plugins/mfe/build/mfe/mereka/theme-source/`

**Note**: Asset sync is handled by the low-level patch helper behind `./scripts/infra/prepare-tutor-build-context.sh --target all` (file-system operations). Configuration patches are handled by the Tutor plugin (automatic via hooks).

#### SASS Compilation (Plugin-Delivered)

- The system MUST compile custom theme SASS before default theme: `npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka`
- The Tutor plugin MUST strip Google Fonts imports from SCSS sources before compilation (via `openedx-dockerfile-pre-assets` hook)
- The Tutor plugin MUST strip residual Google Fonts imports from compiled CSS
- The system MUST compile both LMS and Studio themes

**Note**: Google Fonts stripping is delivered automatically via Tutor plugin hooks.

#### MFE Branding

**Plugin-Delivered (Configuration)**:
- The Tutor plugin MUST inject custom `MerekaFooter` component via `mfe-dockerfile-post-npm-install` hook
- The MerekaFooter MUST include:
  - Mereka Academy branding and tagline
  - Links to courses, dashboard, help center
  - Contact emails: team@mereka.io, techadmin@biji-biji.com
  - Partner links (Biji-Biji Initiative, Mereka main site)
  - Copyright notice and Open edX credit
- The plugin MUST import `mereka.scss` in MFE env.config.jsx

**Script-Delivered (Assets)**:
- The system MUST sync MFE theme fonts to build context via the canonical Tutor prepare path
- The system MUST sync SCSS files to MFE build directory

**Note**: MFE footer is implemented via dual-path wiring: the Tutor plugin (`mereka_lms.py`) defines MerekaFooter and registers a forward-compatible `PLUGIN_SLOTS` entry for `footer_slot` (Direct plugin, not iFrame). Until `tutormfe.hooks.PLUGIN_SLOTS` ships, `apply-patches.sh` provides a fallback RenderWidget replacement. Verified by `scripts/qa/verify-mfe-footer-slot.sh` (CI gated). See ADR-014 "Plugin-First Migration" section for the operator workflow: discover slot → inject config via Tutor plugin → rebuild MFE image.

#### Branding Verification Gates

The system MUST pass the following verification checks:

##### Pre-Patch Gate
- `scripts/branding/verify-branding-health.sh` MUST run before applying patches
- MUST verify all required logo variants exist in theme source
- MUST verify font files exist
- MUST verify SCSS files have no syntax errors

##### Post-Build Gate
- MUST verify Mereka logo present in LMS/CMS static images
- MUST verify compiled CSS contains Mereka theme rules
- MUST verify Google Fonts imports absent from compiled CSS
- MUST verify MFE footer component includes "Mereka Academy" text

#### Django Settings

- The system MUST set `DEFAULT_SITE_THEME = "mereka"` in LMS production.py
- The system SHOULD configure SiteConfiguration to override theme per domain if needed

### Cross-Spec Integration Criteria

### Multi-Site Domains Integration (Tier 2 → Tier 3)
- [ ] AC-INT-001: Given `multi-site-domains_spec.md` configures three production domains (academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io), when branding assets are deployed, then Mereka logo and custom footer render correctly on all three domains with zero Open edX default branding leakage.
- [ ] AC-INT-002: Given multi-site domains are configured, when `scripts/branding/verify-branding-health.sh` runs in production, then it passes for all configured domains without domain-specific branding regressions.

### Tutor Configuration Integration (Tier 1 → Tier 3)
- [ ] AC-INT-003: Given `tutor-configuration_spec.md` canonical prepare flow realizes theme assets, when `./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast` completes, then Mereka logo variants exist in compiled static files and `grep -r "fonts.googleapis.com" tutor_env/env/build/openedx/` returns zero results.

### Non-Functional Requirements

- Page load time: LMS homepage with branding assets MUST load in under 3 seconds (p95) on a 4G connection
- Total theme static asset size MUST remain under 5 MB
- SASS compilation time SHOULD complete within 90 seconds
- The system MUST NOT make any external font requests (Google Fonts or other third-party font CDNs) to preserve learner privacy
- Accessibility: Branding elements SHOULD meet WCAG 2.1 AA contrast ratios (minimum 4.5:1 for normal text, 3:1 for large text)
- Logo images MUST include meaningful alt text for screen readers
- The branding system MUST NOT break existing accessibility features of the Open edX platform

## Acceptance Criteria

- [ ] AC-001: Mereka logo visible on LMS homepage
- [ ] AC-002: Mereka logo visible on Studio homepage
- [ ] AC-003: Custom Mereka footer renders on all MFEs (authn, account, profile, learning)
- [ ] AC-004: Favicon loads correctly (mereka icon, not Open edX default)
- [ ] AC-005: Custom fonts load without Google Fonts fallback
- [ ] AC-006: `grep "fonts.googleapis.com" tutor_env/env/build/openedx/lms/static/css/*.css` returns 0 results
- [ ] AC-007: `scripts/branding/verify-branding-health.sh` exits 0
- [ ] AC-008: Theme applies consistently across all domains (academyv2.mereka.io, academy.biji-biji.com)
- [ ] AC-009: Studio preview shows Mereka branding
- [ ] AC-010: Login page shows Mereka branding (not default Open edX)

## Edge Cases

### Logo Not Appearing

**Symptom**: Default Open edX logo shows instead of Mereka logo

**Cause**: Assets not synced to build directory or collectstatic not run

**Recovery**:
```bash
# Re-sync assets through the canonical prepare path
./scripts/infra/prepare-tutor-build-context.sh --target all

# Rebuild image (picks up new assets)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# Restart and collect static
tutor k8s restart lms
tutor k8s exec lms ./manage.py lms collectstatic --noinput
```

### Google Fonts Still Loading

**Symptom**: Network tab shows requests to fonts.googleapis.com

**Cause**: SCSS stripping failed or new SCSS files added with @import rules

**Recovery**:
```bash
# Check for Google Fonts imports
grep -r "fonts.googleapis.com" infrastructure/tutor/themes/mereka/

# If found, remove manually or update strip_google_fonts logic in apply-patches.sh
# Rebuild and verify
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
```

### MFE Footer Not Rendering

**Symptom**: Default Open edX footer shows instead of MerekaFooter

**Cause**: env.config.jsx patch not applied or MFE build cache stale

**Recovery**:
```bash
# Re-run the canonical prepare path
./scripts/infra/prepare-tutor-build-context.sh --target mfe

# Rebuild MFE image
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast

# Restart MFE pods
tutor k8s restart mfe
```

### Font Files Missing

**Symptom**: Browser console shows 404 for .woff2 files

**Cause**: Fonts not copied to build context or collectstatic failed

**Recovery**:
```bash
# Verify fonts exist in source
ls infrastructure/tutor/themes/mereka/lms/static/fonts/*.woff2

# Re-sync and collect static
./scripts/infra/prepare-tutor-build-context.sh --target openedx
tutor k8s exec lms ./manage.py lms collectstatic --noinput
```

### WCAG Contrast Ratio Violation

**Symptom**: Enterprise tenant's brand colors fail WCAG 2.1 AA contrast ratio (4.5:1 for normal text, 3:1 for large text)

**Cause**: Tenant uploads brand colors that look good on their marketing site but fail accessibility standards against Open edX UI backgrounds. No automated check prevents this.

**Mitigation**:
- Validate contrast ratios at brand upload time using design-tokens-system_spec.md color validation
- Reject color combinations that fail WCAG 2.1 AA with a human-readable error: "Your primary color #FF6600 on white background has contrast ratio 3.2:1 (minimum: 4.5:1)"
- Provide a suggested accessible alternative using the nearest compliant color
- CI visual regression tests MUST include Axe accessibility checks on branded pages

### Theme Cache Invalidation

**Symptom**: Updated branding not visible after rebuild

**Cause**: Browser cache or CDN cache serving old assets

**Recovery**:
```bash
# Force collectstatic with --clear flag
tutor k8s exec lms ./manage.py lms collectstatic --noinput --clear

# Hard refresh browser: Ctrl+Shift+R
```

## Observability

### Logs

- Asset sync: Console output from the canonical prepare path showing rendered theme asset mirroring
- SASS compilation: Build logs showing "Compiled mereka theme"
- Collectstatic: `tutor k8s exec lms ./manage.py lms collectstatic --noinput --verbosity=2`

### Metrics

- Asset size: Track total size of theme static files (baseline: <5MB)
- SASS compilation time: Duration of `npm run compile-sass` (baseline: 30-60s)
- Page load time: Measure LMS homepage with branding assets

### Alerts

- SHOULD alert if `verify-branding-health.sh` fails in CI
- SHOULD alert if Google Fonts requests detected in production

### Dashboards

- Branding health: CI dashboard showing pass/fail of `verify-branding-health.sh` across builds
- Asset budget: Track theme static asset size over time to detect bloat

## Rollout & Rollback

### Adding New Branding Assets

```bash
# 1. Add assets to theme source
cp new-logo.png infrastructure/tutor/themes/mereka/lms/static/images/

# 2. Sync to build context
./scripts/infra/prepare-tutor-build-context.sh --target openedx

# 3. Rebuild image
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# 4. Deploy
tutor k8s restart lms

# 5. Verify
curl -I https://academyv2.mereka.io/static/images/new-logo.png
```

### Updating MFE Footer

```bash
# 1. Edit footer component in apply-patches.sh
# Search for "const MerekaFooter" and modify

# 2. Apply patches
./infrastructure/tutor/apply-patches.sh

# 3. Rebuild MFE
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast

# 4. Deploy
tutor k8s restart mfe
```

### Rollback to Default Theme

```bash
# 1. Disable custom theme in Django settings
tutor config save --unset DEFAULT_SITE_THEME

# 2. Rebuild (picks up default theme)
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast

# 3. Restart
tutor k8s restart lms cms

# Note: This reverts to Open edX default branding
```

## Open Questions

1. ~~Should we version theme assets (e.g., logo-v2.png) to enable cache busting?~~ **RESOLVED**: Yes. Use content-hash filenames in webpack builds (e.g., `logo.a1b2c3.png`). MFE builds already produce hashed filenames. Comprehensive theme assets use git SHA as version suffix for CDN cache invalidation.
2. ~~How do we handle A/B testing of branding changes?~~ **RESOLVED**: No A/B testing for branding in v1. Per-tenant branding via SiteConfiguration covers the multi-brand use case. A/B testing adds complexity not justified for current scale.
3. ~~Should we extract footer component to separate npm package?~~ **RESOLVED**: No. Footer component is defined in branding-system_spec.md and implemented as a Tutor patch. Separate npm package adds maintenance burden without benefit since it only serves Mereka MFEs.
4. ~~Do we need a design system spec for color palette, typography?~~ **RESOLVED**: Yes, tracked in design-tokens-system_spec.md (Tier 4). Design tokens define the canonical color palette, typography, and spacing used by the branding system.
5. ~~Should we implement per-domain branding overrides via SiteConfiguration?~~ **RESOLVED**: Yes. SiteConfiguration already supports per-domain overrides in Open edX. Use `PLATFORM_NAME`, `LOGO_URL`, `FAVICON_URL` per Site. Required for multi-tenant branding per multi-tenancy-architecture_spec.md.
6. ~~How do we measure branding consistency compliance across services?~~ **RESOLVED**: Visual regression testing via Playwright screenshots in CI. Compare MFE renders against golden screenshots stored in `scripts/qa/golden/`. Alert on >5% pixel diff. Implementation tracked in CI/CD pipeline spec.
