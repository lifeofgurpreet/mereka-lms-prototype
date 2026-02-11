---
title: "Branding System"
type: "feature_spec"
status: "completed"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/multi-site-domains_spec.md"
  - "specs/tutor-configuration_spec.md"
links:
  related_docs:
    - "docs/BRANDING.md"
    - "docs/BRANDING_PLAN.md"
    - "docs/BRANDING_VERIFICATION_CHECKLIST.md"
    - "docs/branding/BRANDING_OPERATING_MODEL.md"
    - "docs/branding/BRANDING_GUARDRAILS.md"
    - "docs/branding/BRANDING_ROADMAP.md"
    - "docs/branding/BRANDING_INCIDENT_TEMPLATE.md"
  related_specs:
    - "specs/tutor-configuration_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
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

## Non-goals

- Multi-tenant white-labeling (future enhancement)
- Dynamic theme switching via UI (themes applied at build time)
- Brand asset CDN optimization (assets served from static files)

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

#### Asset Sync Workflow

- The system MUST run `./infrastructure/tutor/apply-patches.sh` to sync theme assets to build directory
- The system MUST copy logo variants to `tutor_env/env/build/openedx/themes/mereka/lms/static/images/`
- The system MUST copy fonts to `tutor_env/env/build/openedx/themes/mereka/lms/static/fonts/`
- The system MUST sync templates to preserve Django template overrides
- The system MUST sync MFE SCSS to `tutor_env/env/plugins/mfe/build/mfe/indigo/mereka/`

#### SASS Compilation

- The system MUST compile custom theme SASS before default theme: `npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka`
- The system MUST strip Google Fonts imports from SCSS sources before compilation
- The system MUST strip residual Google Fonts imports from compiled CSS
- The system MUST compile both LMS and Studio themes

#### MFE Branding

- The system MUST import `mereka.scss` in MFE env.config.jsx
- The system MUST replace default Indigo footer with custom `MerekaFooter` component
- The MerekaFooter MUST include:
  - Mereka Academy branding and tagline
  - Links to courses, dashboard, help center
  - Contact emails: team@mereka.io, techadmin@biji-biji.com
  - Partner links (Biji-Biji Initiative, Mereka main site)
  - Copyright notice and Open edX credit
- The system MUST copy MFE theme fonts to build context

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
# Re-sync assets
./infrastructure/tutor/apply-patches.sh

# Rebuild image (picks up new assets)
tutor images build openedx

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
tutor images build openedx
```

### MFE Footer Not Rendering

**Symptom**: Default Indigo footer shows instead of MerekaFooter

**Cause**: env.config.jsx patch not applied or MFE build cache stale

**Recovery**:
```bash
# Re-apply patches
./infrastructure/tutor/apply-patches.sh

# Rebuild MFE image
tutor images build mfe

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
./infrastructure/tutor/apply-patches.sh
tutor k8s exec lms ./manage.py lms collectstatic --noinput
```

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

- Asset sync: Console output from `apply-patches.sh` showing "Copied logo.png to LMS theme"
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
./infrastructure/tutor/apply-patches.sh

# 3. Rebuild image
tutor images build openedx

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
tutor images build mfe

# 4. Deploy
tutor k8s restart mfe
```

### Rollback to Default Theme

```bash
# 1. Disable custom theme in Django settings
tutor config save --unset DEFAULT_SITE_THEME

# 2. Rebuild (picks up default theme)
tutor images build openedx

# 3. Restart
tutor k8s restart lms cms

# Note: This reverts to Open edX default branding
```

## Open Questions

1. Should we version theme assets (e.g., logo-v2.png) to enable cache busting?
2. How do we handle A/B testing of branding changes?
3. Should we extract footer component to separate npm package?
4. Do we need a design system spec for color palette, typography?
5. Should we implement per-domain branding overrides via SiteConfiguration?
6. How do we measure branding consistency compliance across services?
