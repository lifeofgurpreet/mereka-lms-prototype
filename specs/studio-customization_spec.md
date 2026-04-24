---
title: "Studio Customization: Mereka Academy Course Authoring Experience"
type: "feature_spec"
status: "draft"
version: "1.0.0"
owner: "engineering"
id: "SPEC-FE-STUDIO-CUSTOMIZATION"
spec_class: "integration"
created: "2026-02-27"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "frontend"
normativity: "normative"
supersedes: []
superseded_by: null
verification_sources:
  - "tests"
  - "manual-verification"
interfaces:
  - "studio"
  - "theme-overrides"
tags:
  - "frontend.brand.tokens"
  - "frontend.composition"
summary: "Defines the customization contract for Mereka Studio branding, navigation, authoring experience, and supported extension points."
vehicle: "talent_platform"
last_updated: "2026-02-27"
depends_on:
  - "specs/branding-system_spec.md"
  - "specs/tutor-configuration_spec.md"
links:
  related_docs:
    - "docs/guides/branding/BRANDING.md"
    - "docs/guides/branding/BRANDING_OPERATING_MODEL.md"
    - "docs/ops/runbooks/BRANDING_RELEASE_RUNBOOK.md"
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/mfe-plugin-slots_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/oep48-brand-package_spec.md"
    - "specs/design-tokens-system_spec.md"
---

# Human Summary

## What is changing

The Open edX Studio (CMS) at `studio.academyv2.mereka.io` is being customized end-to-end for Mereka Academy's B2B enterprise education use case. Studio already has a comprehensive theme (`infrastructure/tutor/themes/mereka/cms/`) with SCSS entry points, logo assets, font preloading, and custom footer templates. This spec extends those foundations to cover:

1. **Studio homepage** -- custom welcome messaging and quick-start guides for Mereka educators, with language-aware content for EN, BM (Bahasa Malaysia), and ID.
2. **Branding parity** -- ensuring Studio header, footer, navigation, and chrome match the LMS branding established in `branding-system_spec.md`.
3. **Navigation and help links** -- replacing stock Open edX documentation links with Mereka-specific educator guides and support URLs.
4. **Course-authoring MFE branding** -- extending FPF slot activation to `frontend-app-course-authoring` for consistent branding inside the React-based authoring interface.
5. **Content templates** -- default course structure templates that reflect Mereka's pedagogical model for enterprise training.
6. **Studio settings defaults** -- language, enrollment, and certificate defaults appropriate for Mereka's B2B context.

## Why

Studio is the primary tool for course creators -- both Mereka's internal team and B2B enterprise partners who author their own training content. A generic Open edX Studio experience creates friction for non-technical educators unfamiliar with the platform. Mereka-specific help links, language-aware welcome content, and sensible defaults reduce onboarding time for new course authors and reinforce brand credibility with enterprise partners.

The existing Studio theme already handles visual basics (logo, fonts, footer). This spec fills the remaining gaps: homepage content, navigation customization, MFE branding for course-authoring, content templates, and configuration defaults.

## Success looks like

- A Mereka educator logging into Studio sees a branded homepage with quick-start guides in their preferred language, not a generic Open edX welcome.
- All help and documentation links in Studio point to Mereka-specific guides, not upstream Open edX documentation.
- The course-authoring MFE (`frontend-app-course-authoring`) displays Mereka branding via FPF slots.
- New courses created in Studio start from Mereka content templates with sensible defaults (language, enrollment mode, certificate settings).
- `scripts/qa/verify-studio-customization.sh` passes in CI with zero Open edX default leakage detected in Studio.

---

# Agent Contract

## Scope

### In Scope

- Studio homepage customization (welcome message, quick-start educator guides, language-aware content)
- Studio header branding (logo, site name consistency with LMS)
- Studio footer customization (matching LMS footer via theme templates -- already partially implemented)
- Studio navigation links (help URLs, support links, documentation references)
- Course-authoring MFE branding via FPF slots (`frontend-app-course-authoring`)
- Custom help/documentation links pointing to Mereka-specific guides
- Studio email templates for course team notifications (invitation, access grant)
- Default course structure templates for Mereka educators
- Studio Django settings defaults (language, enrollment, certificates)
- Verification scripts for Studio customization compliance
- Language support for EN, BM (Bahasa Malaysia), and ID

### Out of Scope

- LMS-side branding (covered by `branding-system_spec.md`)
- MFE footer slot (already activated, covered by `branding-system_spec.md`)
- MFE header/navigation slots for non-Studio MFEs (covered by `mfe-plugin-slots_spec.md`)
- Multi-tenant white-labeling of Studio per enterprise (covered by `multi-tenancy-architecture_spec.md`)
- Studio backend API changes or custom Django views
- Design token pipeline or PARAGON_THEME_URLS (covered by `design-tokens-system_spec.md`)
- Course content authoring workflows (pedagogical design, not platform concern)
- Studio performance optimization

## Non-goals

- Building a custom Studio frontend from scratch. All customizations MUST use the existing comprehensive theme system (Django templates, SCSS) and FPF plugin slots (for MFE portions).
- Forking `frontend-app-course-authoring`. All MFE customizations MUST be delivered via FPF slots and Tutor plugin configuration, matching the zero-fork constraint in `mfe-plugin-slots_spec.md`.
- Implementing a full CMS for educator documentation. Help links point to external Mereka guides (hosted separately), not an in-platform documentation system.
- Replacing the Open edX Studio workflow. Customizations are additive (branding, defaults, templates) and do not change core authoring mechanics.
- Supporting languages beyond EN, BM, and ID in this release. Additional languages are additive and follow the same pattern.

## Requirements

### Functional

- The Studio comprehensive theme MUST display Mereka branding (logo, fonts, colors) on all server-rendered pages.
- The Studio homepage MUST display a language-aware welcome section with quick-start guides for educators.
- All help and documentation links in Studio MUST point to Mereka-specific URLs, not upstream Open edX documentation.
- The `frontend-app-course-authoring` MFE MUST display Mereka branding via FPF slot configuration.
- Studio email templates for course team notifications MUST use configurable `PLATFORM_NAME` and `LMS_ROOT_URL` settings.
- New courses created in Studio SHOULD default to `invitation_only: true` enrollment mode.
- New courses created in Studio SHOULD default to English language with BM and ID available as alternatives.
- Studio MUST expose customization settings (help URLs, support URLs) via environment variables, not hardcoded values.

### Non-Functional Requirements

- Studio homepage with customizations MUST load in under 3 seconds (p95) on a 4G connection.
- Total CMS theme asset size MUST remain under 3 MB.
- All Studio customizations MUST preserve WCAG 2.1 AA accessibility compliance.

## Acceptance Criteria

### Studio Homepage Customization

- [ ] AC-STUDIO-001: Given an educator navigates to `studio.academyv2.mereka.io`, when the Studio homepage loads, then the page MUST display a Mereka-branded welcome section with the platform name "Mereka Academy" and a tagline describing its purpose for enterprise education.
- [ ] AC-STUDIO-002: Given the Studio homepage is displayed, when the educator's browser language preference is set to `ms` (Bahasa Malaysia) or `id` (Bahasa Indonesia), then the welcome message and quick-start guide headings MUST render in the corresponding language using Django i18n.
- [ ] AC-STUDIO-003: Given the Studio homepage is displayed, when the educator views the page, then a quick-start guide section MUST be visible with links to at least: (a) creating a new course, (b) importing existing content, (c) managing course settings, and (d) inviting course team members.

### Studio Branding Consistency

- [ ] AC-STUDIO-004: Given the Studio homepage loads, when the page renders, then the Mereka logo MUST appear in the Studio header and the logo file MUST be sourced from the `mereka/cms/static/images/` theme directory (not the default Open edX logo).
- [ ] AC-STUDIO-005: Given the Studio SCSS is compiled, when `studio-main-v1.scss` is processed, then the compiled CSS MUST include Mereka design token values (font families Poppins and Lato, brand colors `--mereka-color-teal`, `--mereka-color-magenta`) and MUST NOT contain Google Fonts `@import` rules.
- [ ] AC-STUDIO-006: Given any page in Studio, when the page renders, then the favicon MUST be the Mereka favicon from `mereka/cms/static/images/favicon.ico` (not the default Open edX icon).

### Studio Footer Customization

- [ ] AC-STUDIO-007: Given any page in Studio, when the footer renders, then it MUST display: (a) copyright notice with "Mereka Academy" and current year, (b) a link to the LMS at the configured `LMS_ROOT_URL`, and (c) a support email link (`support@mereka.io`).
- [ ] AC-STUDIO-008: Given the Studio footer templates `footer.html` and `widgets/footer.html`, when reviewed, then both MUST use `settings.PLATFORM_NAME` and `settings.LMS_ROOT_URL` (not hardcoded values) to support multi-tenant override.

### Studio Navigation and Help Links

- [ ] AC-STUDIO-009: Given a Studio page with a "Help" or documentation link, when the educator clicks it, then the link MUST navigate to a Mereka-specific help URL (configurable via `STUDIO_HELP_URL` Django setting) and MUST NOT point to `docs.openedx.org` or any upstream Open edX documentation site.
- [ ] AC-STUDIO-010: Given the Studio navigation bar, when the educator views available links, then a "Support" link MUST be present that navigates to the Mereka support portal (configurable via `MEREKA_STUDIO_SUPPORT_URL` environment variable).
- [ ] AC-STUDIO-011: Given the Studio "About" or help dropdown, when the educator views it, then a "Mereka Educator Guide" link MUST be present pointing to Mereka's own documentation for course authors.

### Course-Authoring MFE Branding

- [ ] AC-STUDIO-012: Given the `frontend-app-course-authoring` MFE loads within Studio, when the MFE renders, then the MFE MUST display the Mereka logo in its header area via FPF slot configuration in `mereka_lms.py`, not the default Open edX logo.
- [ ] AC-STUDIO-013: Given the `frontend-app-course-authoring` MFE, when help or documentation links are rendered, then they MUST point to Mereka-specific URLs consistent with AC-STUDIO-009, configured via MFE runtime configuration (`env.config.jsx`).
- [ ] AC-STUDIO-014: Given the `frontend-app-course-authoring` MFE, when the footer renders, then it MUST display the MerekaFooter component (already activated in `branding-system_spec.md`), ensuring visual consistency between Studio server-rendered pages and MFE-rendered pages.

### Studio Email Templates

- [ ] AC-STUDIO-015: Given a course team invitation is sent from Studio, when the invitation email is composed, then the email MUST include Mereka Academy branding (logo, platform name) and MUST NOT display default Open edX branding or generic "edX" references.
- [ ] AC-STUDIO-016: Given Studio email templates for course team notifications (invitation, access granted, access revoked), when the templates are reviewed, then they MUST use configurable `PLATFORM_NAME` and `LMS_ROOT_URL` settings (not hardcoded values).

### Content Templates and Course Defaults

- [ ] AC-STUDIO-017: Given an educator creates a new course in Studio, when the course creation wizard completes, then the default course language MUST be set to `en` (English) with `ms` (Bahasa Malaysia) and `id` (Bahasa Indonesia) available as selectable alternatives.
- [ ] AC-STUDIO-018: Given an educator creates a new course in Studio, when no explicit enrollment configuration is set, then the course MUST default to `invitation_only: true` enrollment mode (appropriate for B2B enterprise training where learners are enrolled by administrators).
- [ ] AC-STUDIO-019: Given an educator creates a new course in Studio, when the course advanced settings are viewed, then Mereka-specific defaults MUST be pre-configured for: (a) `cert_html_view_enabled: true`, (b) `certificates_display_behavior: "end"`, and (c) `course_visibility: "private"`.

### Studio Settings and Configuration

- [ ] AC-STUDIO-020: Given the Studio Django settings (CMS `production.py`), when the settings are loaded, then `STUDIO_NAME` MUST be set to "Mereka Academy Studio" and `STUDIO_SHORT_NAME` MUST be set to "Studio".
- [ ] AC-STUDIO-021: Given the Studio Django settings, when `STUDIO_HELP_URL`, `MEREKA_STUDIO_SUPPORT_URL`, and `MEREKA_EDUCATOR_GUIDE_URL` are configured, then these values MUST be sourced from environment variables (via Tutor config or ExternalSecrets) and MUST NOT be hardcoded in source code.

### Verification

- [ ] AC-STUDIO-022: Given a CI run, when `scripts/qa/verify-studio-customization.sh` executes, then it MUST verify: (a) Mereka logo exists in CMS theme images, (b) Studio SCSS compiles without error, (c) footer templates reference `settings.PLATFORM_NAME`, (d) no Google Fonts imports in compiled CSS, and (e) Studio help URL is not `docs.openedx.org`.
- [ ] AC-STUDIO-023: Given a production deployment, when `curl -s https://studio.academyv2.mereka.io/ | grep -i "mereka"` is run, then it MUST return at least one match confirming Mereka branding is present in the Studio homepage HTML.

### Non-Functional Requirements

- [ ] AC-STUDIO-024: Given the Studio homepage with all customizations applied, when loaded on a 4G connection, then the page MUST load in under 3 seconds (p95), consistent with the platform-wide NFR in `cross-cutting-requirements_spec.md`.
- [ ] AC-STUDIO-025: Given the Studio comprehensive theme, when all theme assets (images, fonts, CSS) are measured, then the total CMS theme asset size MUST remain under 3 MB.

**Cross-Cutting Inheritance**: This spec inherits requirements from `specs/cross-cutting-requirements_spec.md` including:
- Observability baseline (metrics, logs, traces, dashboards, alerts)
- Secrets management (Infisical -> GCP SM -> ExternalSecrets -> K8s)
- Common NFR thresholds (latency, availability, security)

Only domain-specific NFRs are listed above.

### Cross-Spec Integration

#### Branding System (Tier 3 -> this spec)

- [ ] AC-INT-001: Given `branding-system_spec.md` asset sync runs via the canonical Tutor prepare flow, when the sync completes, then all CMS theme assets (logos, fonts, SCSS, templates) MUST be present in `tutor_env/env/build/openedx/themes/mereka/cms/`.
- [ ] AC-INT-002: Given `branding-system_spec.md` MerekaFooter component is deployed, when the `frontend-app-course-authoring` MFE renders its footer, then the MerekaFooter MUST render identically to other MFEs (authn, account, learning).

#### MFE Plugin Slots (Tier 3 -> this spec)

- [ ] AC-INT-003: Given `mfe-plugin-slots_spec.md` Phase 1 header branding slots are activated, when the `frontend-app-course-authoring` MFE loads, then the Mereka logo MUST render in the MFE header via the same slot mechanism used for other MFEs.

## Dependencies

### Upstream

- **branding-system_spec.md** (completed): Provides the foundation theme structure, MerekaFooter component, SCSS compilation pipeline, and Google Fonts stripping. Studio customization builds on top of this.
- **tutor-configuration_spec.md**: Provides the canonical Tutor prepare flow that syncs theme assets to the build directory. Studio theme files are delivered through this pipeline.
- **mfe-plugin-slots_spec.md** (draft): Provides FPF slot activation pattern for `frontend-app-course-authoring` header branding (Phase 1). Studio MFE branding depends on this activation.

### Downstream

- **multi-tenancy-architecture_spec.md**: Per-tenant Studio branding overrides (different logos, platform names) will extend the customization patterns defined here.
- **content-libraries-v2_spec.md**: Content library templates may reuse the default course structure templates defined here.

## Verification

### Automated Verification

Add verification scripts to `scripts/qa/verify-studio-customization/` with `@covers` annotations:

```bash
#!/usr/bin/env bash
# @covers AC-STUDIO-004, AC-STUDIO-005, AC-STUDIO-006, AC-STUDIO-007, AC-STUDIO-008, AC-STUDIO-022
# @spec: studio-customization_spec

set -euo pipefail
# Verify CMS theme assets, SCSS compilation, footer templates, help URLs
```

Run coverage report:
```bash
scripts/qa/spec-tools/ac-coverage-report.py
```

### Manual Verification

1. Navigate to `studio.academyv2.mereka.io` and visually confirm Mereka branding on homepage, header, and footer.
2. Change browser language to `ms` or `id` and confirm welcome message renders in the selected language.
3. Click all help/documentation links in Studio and confirm they navigate to Mereka URLs, not `docs.openedx.org`.
4. Create a new course and confirm default settings (language, enrollment mode, certificate config).
5. Send a course team invitation and confirm the email uses Mereka branding.

### Test Plan

See `specs/plans/studio-customization_test_plan.md` for comprehensive test scenarios.

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `STUDIO_NAME` | No | `"Mereka Academy Studio"` | Display name in Studio UI |
| `STUDIO_SHORT_NAME` | No | `"Studio"` | Short name for breadcrumbs/nav |
| `STUDIO_HELP_URL` | No | `"https://help.mereka.io/studio"` | Help link target URL |
| `MEREKA_STUDIO_SUPPORT_URL` | No | `"https://help.mereka.io/support"` | Support portal URL |
| `MEREKA_EDUCATOR_GUIDE_URL` | No | `"https://help.mereka.io/educator-guide"` | Educator documentation URL |
| `STUDIO_DEFAULT_COURSE_LANGUAGE` | No | `"en"` | Default language for new courses |
| `STUDIO_DEFAULT_INVITATION_ONLY` | No | `"true"` | Default enrollment restriction |

### Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| `ENABLE_STUDIO_WELCOME_CUSTOMIZATION` | `true` | Enables custom welcome section on Studio homepage |
| `ENABLE_STUDIO_CONTENT_TEMPLATES` | `false` | Enables Mereka default course structure templates (enable after templates are authored) |

## Observability

### Metrics

- `studio_homepage_load_p95_seconds`: p95 latency for Studio homepage with custom welcome content
- `studio_help_link_clicks_total`: Counter of help link clicks (to measure educator engagement)

### Alerts

- SHOULD alert if Studio homepage load time exceeds 5 seconds for more than 5 minutes
- SHOULD alert if `verify-studio-customization.sh` fails in CI

### Dashboards

- Studio customization health: CI pass/fail status of `verify-studio-customization.sh`
- Studio usage: page load times, help link engagement

## Edge Cases

### Studio Theme Not Applied After Rebuild

**Symptom**: Default Open edX Studio branding appears after `./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast`.

**Cause**: The canonical Tutor prepare flow was not run after `tutor config save`, so CMS theme assets were not synced to the build context.

**Recovery**:
```bash
./scripts/infra/prepare-tutor-build-context.sh --target openedx
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
tutor k8s restart cms
tutor k8s exec cms ./manage.py cms collectstatic --noinput
```

### Course-Authoring MFE Shows Generic Branding

**Symptom**: `frontend-app-course-authoring` displays the default Open edX logo despite FPF slot configuration.

**Cause**: MFE image was built before slot activation was added to `mereka_lms.py`, or `env.config.jsx` patch was not applied.

**Recovery**:
```bash
./infrastructure/tutor/apply-patches.sh
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
tutor k8s restart mfe
```

### Help Links Point to docs.openedx.org

**Symptom**: Studio help links navigate to upstream Open edX documentation instead of Mereka guides.

**Cause**: `STUDIO_HELP_URL` not set in Tutor config or environment variable not propagated to CMS pods.

**Recovery**:
```bash
# Verify the setting
tutor config printvalue STUDIO_HELP_URL
# Set if missing
./scripts/infra/tutor-config-save.sh --set STUDIO_HELP_URL="https://help.mereka.io/studio"
tutor k8s restart cms
```

### Language-Specific Content Not Rendering

**Symptom**: Welcome message always displays in English regardless of browser language.

**Cause**: Django i18n translations not compiled or not loaded for `ms`/`id` locales.

**Recovery**:
```bash
# Compile translations
tutor k8s exec cms ./manage.py cms compilemessages
tutor k8s restart cms
```

### Email Templates Show Default Branding

**Symptom**: Course team invitation emails display "edX" or default Open edX branding.

**Cause**: `PLATFORM_NAME` not set in CMS Django settings, or email template cache not cleared.

**Recovery**:
```bash
# Verify PLATFORM_NAME
tutor k8s exec cms ./manage.py cms shell -c "from django.conf import settings; print(settings.PLATFORM_NAME)"
# Should print "Mereka Academy"
```

## Rollout & Rollback

### Rollout Plan

1. **Phase 1 - Branding Parity**: Verify existing CMS theme assets (logo, fonts, footer, SCSS) are complete and consistent with LMS. Covered by AC-STUDIO-004 through AC-STUDIO-008.
2. **Phase 2 - Navigation & Help**: Configure `STUDIO_HELP_URL` and related settings. Update navigation links via Tutor config. Covered by AC-STUDIO-009 through AC-STUDIO-011.
3. **Phase 3 - Homepage & MFE**: Add custom welcome section and activate course-authoring MFE FPF slots. Covered by AC-STUDIO-001 through AC-STUDIO-003 and AC-STUDIO-012 through AC-STUDIO-014.
4. **Phase 4 - Defaults & Templates**: Configure course creation defaults and enable content templates. Covered by AC-STUDIO-017 through AC-STUDIO-021.

### Feature Flags

- `ENABLE_STUDIO_WELCOME_CUSTOMIZATION` (default: `true`): Controls custom homepage welcome section. Disable to revert to stock Studio homepage.
- `ENABLE_STUDIO_CONTENT_TEMPLATES` (default: `false`): Controls Mereka course structure templates. Enable only after templates are authored and reviewed.

### Backward Compatibility

- All customizations are additive. Disabling feature flags or removing theme overrides reverts to stock Open edX Studio behavior.
- Email template changes use `PLATFORM_NAME` which is already set; no backward compatibility risk.
- Course defaults only apply to newly created courses; existing courses are not affected.

### Rollback Steps

```bash
# Revert to stock Studio (emergency)
# 1. Disable custom welcome
tutor config save --set ENABLE_STUDIO_WELCOME_CUSTOMIZATION=false

# 2. Reset help URL to upstream
tutor config save --unset STUDIO_HELP_URL

# 3. Rebuild and restart
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
tutor k8s restart cms
```

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Upstream Open edX upgrade changes Studio template structure | Medium | Medium | Pin to Tutor v21 (Ulmo), test template compatibility before upgrading |
| `frontend-app-course-authoring` FPF slots change IDs in future release | Medium | Low | Slot activation via `mereka_lms.py` is version-pinned; upgrade testing catches changes |
| Translation files for BM/ID incomplete or inaccurate | Low | Medium | Professional translation review before enabling language-specific content |
| Custom course defaults conflict with enterprise partner expectations | Low | Low | Defaults are overridable per-course; document override process in educator guide |

## Open Questions

- [ ] What is the URL for the Mereka educator help portal? Currently using placeholder `https://help.mereka.io/studio`. Need actual URL from product team.
- [ ] Should content templates include a "Mereka Enterprise Training" template with pre-defined section structure (onboarding, core modules, assessment, certification)? Need pedagogical guidance from learning design team.
- [ ] Should the Studio welcome page include video tutorials or only text-based quick-start guides? Need product decision on content format.
- [ ] Are there additional languages beyond EN, BM, and ID that should be supported in the initial release? The user context mentions "potentially more" -- need confirmed language list.
