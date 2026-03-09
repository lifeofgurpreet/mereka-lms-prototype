---
id: "SPEC-FRONTEND-PERFORMANCE-BUDGETS"
title: "Frontend Performance Budgets: Core Web Vitals, Bundle Sizes, and Caching for SEA Users"
type: "feature_spec"
status: "draft"
spec_class: "domain"
version: "1.0.0"
owner: "platform"
created: "2026-02-27"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "frontend"
normativity: "normative"
supersedes: []
superseded_by: null
verification_sources:
  - "infrastructure/monitoring/lighthouse-budgets.json"
  - ".github/workflows/lighthouse-ci.yml"
interfaces:
  - "apps.academyv2.mereka.io"
  - "infrastructure/monitoring/lighthouse-budgets.json"
tags:
  - "frontend.composition"
  - "frontend.brand.tokens"
  - "runtime.cache"
summary: "Defines enforceable frontend performance budgets, Lighthouse thresholds, and cache expectations for the Mereka Academy web surfaces."
vehicle: "talent_platform"
last_updated: "2026-02-27"
depends_on:
  - "specs/branding-system_spec.md"
  - "specs/k8s-deployment_spec.md"
depends_on_optional:
  - "specs/oep48-brand-package_spec.md"
  - "specs/plans/paragon-design-tokens-migration_spec.md"
links:
  related_docs:
    - "docs/policies/architecture/PERFORMANCE_BUDGETS.md"
    - "docs/policies/architecture/LIGHTHOUSE_BUDGETS.md"
    - "docs/guides/branding/BRANDING.md"
  related_specs:
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/oep48-brand-package_spec.md"
    - "specs/plans/paragon-design-tokens-migration_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/ci-cd-pipeline_spec.md"
---

# Human Summary

## What is changing

This spec codifies measurable, CI-enforceable performance budgets for the Mereka Academy frontend. It covers twelve React-based MFEs served via Caddy on GKE, the LMS/Studio Django pages, custom Mereka branding assets (9 WOFF2 font files, SVG/PNG logos, 641 lines of SCSS overrides), and the Lighthouse CI pipeline that gates deployments. The budgets are calibrated for users in Southeast Asia (Malaysia, Indonesia, Philippines, Vietnam) where 4G is common but connection quality varies and 3G is still encountered in rural areas.

Key components:
- Core Web Vitals targets (LCP, INP, CLS) aligned with Google's "good" thresholds
- Per-MFE bundle size ceilings (JS and CSS, gzipped) enforced in CI
- Font loading strategy (preload critical weights, `font-display: swap`, subsetting)
- Image optimization (SVG logos, WebP fallbacks, lazy loading below the fold)
- CSS branding overhead budget (<5 KB gzipped over stock Paragon)
- Lighthouse CI minimum scores for Performance and Accessibility
- Caddy cache-control headers for hashed assets, entry points, and API responses
- Build time budgets for MFE and openedx image builds
- Real User Metrics (RUM) via the browser Performance API or Sentry

## Why

Mereka Academy's target users are in Southeast Asia where network conditions range from fast urban 4G to intermittent rural 3G. Without enforceable budgets, bundle sizes creep (Open edX MFEs already ship large vendor bundles), custom branding adds unchecked CSS/font weight, and cache headers remain misconfigured (the Caddyfile currently sets `Cache-Control: no-store` on all responses, including static assets). The existing `docs/architecture/PERFORMANCE_BUDGETS.md` document defines aspirational targets but lacks spec-grade acceptance criteria, CI enforcement, and RUM feedback loops. Meanwhile, the Lighthouse CI workflow (`lighthouse-ci.yml`) and budget file (`infrastructure/monitoring/lighthouse-budgets.json`) are already in place but have no formal contract linking them to release gates.

## Success looks like

- Every PR that increases an MFE's initial JS bundle by more than 10 KB is flagged in CI before merge.
- Lighthouse CI runs against production URLs weekly and blocks release if Performance score drops below 50 or LCP exceeds 2500ms.
- Repeat visitors to `apps.academyv2.mereka.io` load MFEs in under 1 second thanks to aggressive cache-control headers on hashed assets.
- The custom Mereka SCSS adds no more than 5 KB gzipped over stock Paragon CSS.
- RUM data from production confirms p75 LCP is under 2.5 seconds for SEA users on 4G.
- MFE Docker image builds complete in under 10 minutes; openedx image builds in under 45 minutes.

---

# Agent Contract

## Scope

### In Scope

- Core Web Vitals budget targets (LCP, INP, CLS, TTFB, FCP, TBT)
- Per-MFE JavaScript and CSS bundle size ceilings
- Font loading strategy for Poppins (3 weights) and Lato (6 weights)
- Image optimization requirements for branding assets
- CSS branding overhead budget (Mereka SCSS vs stock Paragon)
- Lighthouse CI integration and minimum score gates
- Network performance targets for 4G (primary) and 3G (graceful degradation)
- Caddy cache-control header configuration
- Build time budgets (MFE and openedx images)
- Real User Metrics (RUM) collection and alerting
- Verification scripts for CI enforcement
- The `infrastructure/monitoring/lighthouse-budgets.json` budget file contract

### Out of Scope

- CDN deployment in front of Caddy/LoadBalancer (future infrastructure work)
- Service worker implementation (deferred -- documented as consideration only)
- Backend API response time optimization (covered by cross-cutting NFRs)
- PARAGON_THEME_URLS runtime theming (covered by `paragon-design-tokens-migration_spec.md`)
- MFE code splitting implementation details (this spec defines the budget, not the technique)
- Mobile native app performance (covered by `proposals/proposals/mobile-apps-enterprise_spec.md`)

## Non-goals

- Achieving sub-second LCP on 3G connections (3G targets are graceful degradation, not parity with 4G)
- Mandating specific bundler configuration (webpack vs esbuild) -- budgets are tool-agnostic
- Replacing the existing `docs/architecture/PERFORMANCE_BUDGETS.md` doc (that doc remains as the human-readable guide; this spec adds enforceable contracts)
- Optimizing third-party scripts (analytics, error tracking) -- only counting them toward budgets

## Requirements

### Functional

#### Core Web Vitals Budgets

- The system MUST enforce a Largest Contentful Paint (LCP) budget of 2500ms or less at p75, measured under simulated 4G conditions (9 Mbps throughput, 40ms RTT).
- The system MUST enforce an Interaction to Next Paint (INP) budget of 200ms or less at p75. FID MUST NOT appear in any budget configuration (retired March 2024).
- The system MUST enforce a Cumulative Layout Shift (CLS) budget of 0.10 or less at p75.
- The system SHOULD enforce a Time to First Byte (TTFB) budget of 600ms or less at p75 for MFE HTML entry points.
- The system SHOULD enforce a First Contentful Paint (FCP) budget of 1800ms or less at p75.
- The system SHOULD enforce a Total Blocking Time (TBT) budget of 200ms or less (median of 5 Lighthouse runs).
- The system MUST define 3G graceful degradation targets: LCP under 4000ms, INP under 300ms, CLS under 0.15.

#### Bundle Size Budgets

- The system MUST enforce per-MFE initial JavaScript bundle ceilings (gzipped):
  - authn: 400 KB
  - account: 450 KB
  - learning: 550 KB
  - dashboard: 500 KB
  - discussions: 500 KB
  - gradebook: 450 KB
  - profile: 400 KB
  - course-authoring: 600 KB
  - ora-grading: 500 KB
- The system MUST enforce per-MFE initial CSS bundle ceilings (gzipped): 100 KB per MFE.
- The system MUST define an absolute JS ceiling of 2048 KB (uncompressed) and an absolute CSS ceiling of 500 KB (uncompressed) per MFE page, enforced in `infrastructure/monitoring/lighthouse-budgets.json`.
- The system SHOULD flag any PR that increases an MFE's total initial JS by more than 10 KB gzipped.

#### Font Loading Strategy

- The system MUST serve all custom fonts (Poppins and Lato) in WOFF2 format exclusively. No WOFF1, TTF, or OTF files MUST be shipped to production.
- The system MUST apply `font-display: swap` to all `@font-face` declarations to prevent invisible text during font loading.
- The system MUST preload the two most critical font files (`Poppins-Regular.woff2` and `Poppins-SemiBold.woff2`) via `<link rel="preload">` in MFE HTML entry points.
- The system SHOULD subset Lato to Latin + Latin Extended only (dropping Cyrillic, Greek glyphs) to reduce total font payload.
- The total font payload for all 9 WOFF2 files MUST NOT exceed 150 KB uncompressed (approximately 50 KB gzipped).

#### Image Optimization

- The system MUST serve logo assets in SVG format as the primary format. PNG fallbacks MAY be provided for email templates and legacy contexts only.
- The system MUST lazy-load all images below the initial viewport fold using `loading="lazy"` or equivalent.
- The system SHOULD serve raster images (course thumbnails, banners) in WebP format with JPEG/PNG fallback via `<picture>` element or Caddy content negotiation.
- Favicon files MUST NOT exceed 32 KB total across all sizes.

#### CSS Branding Overhead

- The custom Mereka SCSS (`mereka.scss` and associated partials) MUST NOT add more than 5 KB gzipped CSS over the stock Paragon theme baseline.
- The system MUST include a CI check that compares compiled Mereka CSS size against stock Paragon CSS size and fails if the delta exceeds 5 KB gzipped.

#### Lighthouse CI Integration

- The `infrastructure/monitoring/lighthouse-budgets.json` file MUST cover at minimum these MFE paths: `/authn/login`, `/dashboard`, `/learning/course`, `/profile`, `/account`, `/discussions`.
- The Lighthouse CI workflow MUST validate budget file structure and thresholds as a CI gate (currently `scripts/qa/verify-lighthouse-budgets.sh`).
- Lighthouse CI MUST enforce minimum scores: Performance >= 50, Accessibility >= 90.
- The system SHOULD run Lighthouse CI against production URLs on a weekly schedule (cron) in addition to the budget file validation that runs on PR.

#### Caching Strategy

- Caddy MUST serve hashed static assets (JS, CSS, WOFF2 with content hash in filename) with `Cache-Control: public, max-age=31536000, immutable`.
- Caddy MUST serve `index.html` entry points with `Cache-Control: no-cache, must-revalidate`.
- Caddy MUST serve API proxy responses with `Cache-Control: private, no-store`.
- Caddy MUST serve unhashed static images and fonts with `Cache-Control: public, max-age=86400`.
- The system SHOULD add `ETag` and `Last-Modified` headers on all static assets for conditional request support.

#### Build Time Budgets

- MFE Docker image builds MUST complete in under 10 minutes on CI runners with 4 CPU cores and 12 GB RAM.
- The openedx Docker image build (LMS/CMS/workers) MUST complete in under 45 minutes on CI runners with 4 CPU cores and 12 GB RAM.
- The webpack `NODE_OPTIONS` memory limit MUST remain at 6144 MB or higher to prevent OOM during MFE compilation.

#### Runtime Monitoring (RUM)

- The system MUST collect Real User Metrics (LCP, INP, CLS, FCP, TTFB) from production browsers using the `web-vitals` library or Sentry Performance Monitoring.
- RUM data MUST be segmented by MFE name and user country (at minimum: MY, ID, PH, VN).
- The system MUST alert when p75 LCP exceeds 3000ms (1.2x budget) sustained for 24 hours in any country segment.

### Non-Functional Requirements

- [ ] AC-PERF-NFR-001: Given the full set of 9 WOFF2 font files, when all are downloaded on first visit, then the total transfer size MUST be under 150 KB uncompressed.
- [ ] AC-PERF-NFR-002: Given a user on simulated 4G (9 Mbps, 40ms RTT), when loading any MFE page, then LCP MUST be under 2500ms at p75 across 5 Lighthouse runs.
- [ ] AC-PERF-NFR-003: Given production RUM data over a 7-day window, when filtered to SEA countries (MY, ID, PH, VN), then p75 LCP SHOULD be under 2500ms.

**Cross-Cutting Inheritance**: This spec inherits requirements from `specs/cross-cutting-requirements_spec.md` including:
- Observability baseline (RUM data flows into Prometheus/Grafana)
- Common NFR thresholds (p95 API latency < 500ms applies to backend; this spec tightens frontend targets)
- Secrets management (any analytics/RUM API keys follow the Infisical pipeline)

## Acceptance Criteria

### Core Web Vitals

- [ ] AC-PERF-001: Given the Lighthouse budget file at `infrastructure/monitoring/lighthouse-budgets.json`, when parsed, then every entry MUST include `largest-contentful-paint` with budget <= 2500ms.
- [ ] AC-PERF-002: Given the Lighthouse budget file, when parsed, then every entry MUST include `experimental-interaction-to-next-paint` with budget <= 200ms and MUST NOT include `first-input-delay`.
- [ ] AC-PERF-003: Given the Lighthouse budget file, when parsed, then every entry MUST include `cumulative-layout-shift` with budget <= 100 (Lighthouse units, equivalent to 0.10).
- [ ] AC-PERF-004: Given the Lighthouse budget file, when parsed, then it MUST contain entries for at minimum these paths: `/authn/login`, `/dashboard`, `/learning/course`, `/profile`, `/account`, `/discussions`.

### Bundle Sizes

- [ ] AC-PERF-005: Given the Lighthouse budget file, when parsed, then every entry's `resourceSizes` for `script` MUST be <= 2048 KB.
- [ ] AC-PERF-006: Given the Lighthouse budget file, when parsed, then every entry's `resourceSizes` for `stylesheet` MUST be <= 500 KB.
- [ ] AC-PERF-007: Given per-MFE JS ceilings defined in this spec, when a CI build produces an MFE bundle exceeding its ceiling, then the CI pipeline MUST report a warning. The absolute ceiling (2048 KB) MUST cause a failure.
- [ ] AC-PERF-008: Given any MFE build, when the initial CSS bundle is measured, then it MUST be <= 100 KB gzipped.

### Font Loading

- [ ] AC-PERF-009: Given the MFE Caddy-served HTML, when the source is inspected, then `Poppins-Regular.woff2` and `Poppins-SemiBold.woff2` MUST be referenced via `<link rel="preload" as="font" type="font/woff2" crossorigin>`.
- [ ] AC-PERF-010: Given all `@font-face` declarations in compiled CSS, when inspected, then every declaration MUST include `font-display: swap`.
- [ ] AC-PERF-011: Given the font directory (`infrastructure/tutor/themes/mereka/lms/static/fonts/`), when listing files, then only `.woff2` files MUST be present (no `.woff`, `.ttf`, `.otf`).

### Image Optimization

- [ ] AC-PERF-012: Given the branding image directory, when listing logo files, then SVG variants MUST exist for `logo-horizontal`, `logo-horizontal-white`, and `logo-square`. PNG variants MAY exist alongside.
- [ ] AC-PERF-013: Given any MFE page, when inspecting images below the initial viewport, then they MUST have `loading="lazy"` or be loaded via Intersection Observer.

### CSS Branding Overhead

- [ ] AC-PERF-014: Given the compiled Mereka MFE CSS and the stock Paragon CSS, when the gzipped sizes are compared, then the delta MUST be <= 5 KB.

### Lighthouse CI

- [ ] AC-PERF-015: Given the `scripts/qa/verify-lighthouse-budgets.sh` script, when run in CI, then it MUST exit 0 only if all budget thresholds in the JSON file are within the limits defined in this spec.
- [ ] AC-PERF-016: Given a Lighthouse CI run against production MFE URLs, when scores are collected, then the Performance score MUST be >= 50 and the Accessibility score MUST be >= 90.
- [ ] AC-PERF-017: Given the `.github/workflows/lighthouse-ci.yml` workflow, when triggered, then it MUST validate the budget file structure and all threshold ranges.

### Caching Strategy

- [ ] AC-PERF-018: Given a request for a hashed static asset (e.g., `main.abc123.js`) from Caddy, when the response headers are inspected, then `Cache-Control` MUST be `public, max-age=31536000, immutable`.
- [ ] AC-PERF-019: Given a request for `index.html` from Caddy, when the response headers are inspected, then `Cache-Control` MUST be `no-cache, must-revalidate`.
- [ ] AC-PERF-020: Given a request for an API endpoint via Caddy reverse proxy, when the response headers are inspected, then `Cache-Control` MUST include `no-store`.

### Build Time

- [ ] AC-PERF-021: Given a CI runner with 4 CPU cores and 12 GB RAM, when building any single MFE Docker image, then the build MUST complete in under 10 minutes.
- [ ] AC-PERF-022: Given a CI runner with 4 CPU cores and 12 GB RAM, when building the openedx Docker image, then the build MUST complete in under 45 minutes.
- [ ] AC-PERF-023: Given the MFE webpack configuration, when inspected, then `NODE_OPTIONS` MUST include `--max-old-space-size=6144` or higher.

### Runtime Monitoring

- [ ] AC-PERF-024: Given the MFE JavaScript bundle in production, when loaded in a browser, then it MUST collect and report LCP, INP, CLS, FCP, and TTFB metrics via the `web-vitals` library or Sentry Performance SDK.
- [ ] AC-PERF-025: Given RUM data collected over 24 hours, when p75 LCP exceeds 3000ms for any SEA country segment (MY, ID, PH, VN), then an alert MUST fire to `#ops-warnings`.

### Cross-Spec Integration

#### Branding System (branding-system_spec.md)

- [ ] AC-PERF-INT-001: Given the font files managed by the branding system, when deployed, then they MUST conform to PERF-009, PERF-010, and PERF-011 requirements (preload, font-display, WOFF2-only).
- [ ] AC-PERF-INT-002: Given the Mereka SCSS maintained per branding-system_spec.md, when compiled, then it MUST conform to PERF-014 requirement (CSS delta <= 5 KB gzipped over stock Paragon).

## Dependencies

### Upstream

- **branding-system_spec.md**: Font files, SCSS overrides, and logo assets are managed by the branding system. Changes to font weights or SCSS size directly affect performance budgets.
- **k8s-deployment_spec.md**: Caddy configuration and deployment manifests control cache headers and serving behavior.
- **ci-cd-pipeline_spec.md**: Lighthouse CI workflow and verification scripts run as part of the CI pipeline.

### Downstream

- **paragon-design-tokens-migration_spec.md**: When PARAGON_THEME_URLS is enabled, CSS delivery changes from build-time to runtime. Performance budgets may need adjustment (MFE CSS shrinks, but runtime CSS fetch adds latency).
- **oep48-brand-package_spec.md**: The brand package consolidation may change how fonts and logos are referenced, affecting preload hints and cache behavior.

## Verification

### Automated Verification

Add verification scripts to `scripts/qa/` with `@covers` annotations:

```bash
#!/usr/bin/env bash
# @covers PERF-001, PERF-002, PERF-003, PERF-004, PERF-005, PERF-006
# @spec: frontend-performance-budgets_spec

set -euo pipefail
# Validate lighthouse-budgets.json structure and thresholds
```

The existing `scripts/qa/verify-lighthouse-budgets.sh` already covers PERF-001 through PERF-006 and PERF-015. Update `@covers` annotations to reference this spec.

Additional scripts needed:
- `scripts/qa/verify-font-loading.sh` -- PERF-009, PERF-010, PERF-011
- `scripts/qa/verify-css-branding-overhead.sh` -- PERF-014
- `scripts/qa/verify-caddy-cache-headers.sh` -- PERF-018, PERF-019, PERF-020

Run coverage report:
```bash
scripts/qa/spec-tools/ac-coverage-report.py
```

### Manual Verification

1. Run Lighthouse against `https://apps.academyv2.mereka.io/authn/login` and confirm Performance >= 50, Accessibility >= 90 (PERF-016).
2. Verify cache headers on production by running `curl -I https://apps.academyv2.mereka.io/authn/static/js/main.*.js | grep -i cache-control` (PERF-018).
3. After RUM is deployed, monitor Grafana dashboard for 7 days to confirm p75 LCP stays under 2500ms for SEA users (AC-PERF-NFR-003).
4. Time an MFE Docker image build on CI runners and confirm it completes under 10 minutes (PERF-021).

### Test Plan

See `specs/plans/frontend-performance-budgets_test_plan.md` for comprehensive test scenarios (to be created).

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| NODE_OPTIONS | Yes | `--max-old-space-size=6144` | Webpack memory limit for MFE builds |
| LIGHTHOUSE_BUDGET_PATH | No | `infrastructure/monitoring/lighthouse-budgets.json` | Path to Lighthouse budget file |
| RUM_ENABLED | No | `false` | Enable Real User Metrics collection in MFE |
| RUM_SAMPLE_RATE | No | `0.1` | Fraction of page loads to sample for RUM (0.0-1.0) |
| SENTRY_TRACES_SAMPLE_RATE | No | `0.1` | Sentry Performance Monitoring sample rate |

### Feature Flags

| Flag | Default | Description |
|------|---------|-------------|
| ENABLE_RUM_COLLECTION | false | Enable browser-side performance metric collection |
| ENABLE_LIGHTHOUSE_CI_GATE | true | Block releases if Lighthouse scores are below minimum |
| ENABLE_BUNDLE_SIZE_WARNINGS | false | Warn in PR comments when bundle size increases > 10 KB |

## Observability

### Metrics

- `frontend_lcp_seconds` histogram: Largest Contentful Paint per MFE, segmented by country
- `frontend_inp_milliseconds` histogram: Interaction to Next Paint per MFE, segmented by country
- `frontend_cls_score` histogram: Cumulative Layout Shift per MFE
- `frontend_bundle_size_bytes` gauge: Initial JS bundle size per MFE (from CI builds)
- `frontend_css_delta_bytes` gauge: Mereka CSS overhead vs stock Paragon (from CI builds)
- `mfe_build_duration_seconds` histogram: MFE Docker image build time
- `openedx_build_duration_seconds` histogram: openedx Docker image build time

### Alerts

- **LCP Regression**: Fires when p75 LCP exceeds 3000ms for any SEA country segment for 24 hours, severity=warning
- **Bundle Size Breach**: Fires when any MFE JS bundle exceeds its ceiling in a merged PR, severity=warning
- **Lighthouse Score Drop**: Fires when weekly Lighthouse Performance score drops below 50, severity=error
- **Build Time Exceeded**: Fires when MFE build exceeds 10 minutes or openedx build exceeds 45 minutes, severity=warning

### Dashboards

- `frontend-performance`: Grafana dashboard showing LCP/INP/CLS per MFE, country segmentation, and historical trends
- `build-performance`: Grafana dashboard showing build times per image type, with trend lines

## Edge Cases

1. **Font preload race condition**: If `<link rel="preload">` fires before Caddy's gzip encoding negotiation, the browser may double-download fonts. Mitigation: ensure preload hints include `type="font/woff2"` and `crossorigin` attributes to match the actual resource fetch.

2. **Lighthouse score variance**: Lighthouse scores can vary +/- 5 points between runs on the same page. Mitigation: run 5 times and use the median. Do not fail CI on a single low score.

3. **Cache poisoning after deployment**: A deployment that changes hashed asset filenames means old `index.html` cached by any intermediate proxy points to non-existent assets. Mitigation: `index.html` MUST have `no-cache` so browsers always fetch the latest version.

4. **3G users hitting absolute ceilings**: Users on poor 3G connections may time out before 2048 KB of JS loads. Mitigation: 3G degradation targets are advisory (4000ms LCP), and code splitting ensures critical path JS is loaded first.

5. **RUM data skew from bots**: Search engine crawlers and monitoring bots inflate or deflate RUM metrics. Mitigation: filter RUM data by user-agent, excluding known bot patterns before aggregation.

6. **PARAGON_THEME_URLS transition**: When runtime theming is enabled, MFE CSS bundles shrink but an additional network request is needed for the theme CSS from CDN. Mitigation: update CSS budgets when the migration spec is implemented; preload the theme CSS URL.

7. **Font subsetting breaks non-Latin learner names**: If Lato is subset to Latin-only, learner names containing Vietnamese diacritics may render in fallback fonts. Mitigation: Latin Extended subset covers Vietnamese; verify character coverage before subsetting.

8. **Build OOM on CI runners**: The 6144 MB webpack memory limit may be insufficient for the course-authoring MFE (largest bundle). Mitigation: monitor build memory usage; increase to 8192 MB if OOM occurs. The heavy runner pool (4CPU/12GB) provides headroom.

## Rollout & Rollback

### Rollout Plan

1. **Phase 1 -- Budget File and CI Validation** (current state, operational):
   - `infrastructure/monitoring/lighthouse-budgets.json` exists with thresholds.
   - `scripts/qa/verify-lighthouse-budgets.sh` runs in CI.
   - `lighthouse-ci.yml` workflow validates budget file structure.

2. **Phase 2 -- Cache Headers** (next):
   - Update Caddy configuration to add per-asset-type `Cache-Control` headers.
   - Deploy to nonprod, verify headers with curl, then roll to production.
   - Rollback: revert Caddy config (current `no-store` is the fallback).

3. **Phase 3 -- Font Optimization**:
   - Add preload hints to MFE HTML templates.
   - Verify `font-display: swap` in all `@font-face` declarations.
   - Subset Lato fonts (if character coverage is confirmed safe).

4. **Phase 4 -- RUM Collection**:
   - Enable `web-vitals` or Sentry Performance SDK in MFE initialization.
   - Start with 10% sampling rate (`RUM_SAMPLE_RATE=0.1`).
   - Build Grafana dashboard for frontend metrics.

5. **Phase 5 -- Bundle Size CI Gate**:
   - Add webpack-bundle-analyzer to MFE builds.
   - Enable PR comments for bundle size regressions.
   - Enforce per-MFE ceilings as hard CI gates.

### Feature Flags

| Flag | Phase | Default | Rollback |
|------|-------|---------|----------|
| ENABLE_RUM_COLLECTION | 4 | false | Set to false, redeploy MFEs |
| ENABLE_LIGHTHOUSE_CI_GATE | 1 | true | Set to false in workflow to unblock CI |
| ENABLE_BUNDLE_SIZE_WARNINGS | 5 | false | Set to false to silence warnings |

### Backward Compatibility

- Cache header changes are purely additive; removing them reverts to existing behavior.
- Font preload hints are progressive enhancement; older browsers ignore them.
- RUM collection is client-side sampling; disabling it has zero server-side impact.
- Bundle size gates only run in CI; they do not affect runtime behavior.

### Rollback Steps

1. **Cache headers**: Revert Caddy configuration to remove `header` directives. Redeploy Caddy pod.
2. **Font preload**: Remove `<link rel="preload">` from HTML templates. Rebuild MFE images.
3. **RUM**: Set `ENABLE_RUM_COLLECTION=false` and redeploy MFEs. No data loss (metrics already shipped).
4. **Lighthouse CI gate**: Set `ENABLE_LIGHTHOUSE_CI_GATE=false` in the workflow file to unblock merges.
5. **Bundle size gate**: Remove size check step from CI workflow.

## Risks and Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Lighthouse scores too volatile for hard CI gate | Medium | Medium | Use median of 5 runs; set Performance minimum at 50 (generous) |
| Font subsetting removes needed glyphs | Medium | Low | Verify Latin Extended covers all SEA languages; keep full files as fallback |
| Cache headers cause stale content after deploy | High | Low | `index.html` always `no-cache`; hashed assets are immutable |
| RUM sampling overhead affects user experience | Low | Low | 10% sample rate; `web-vitals` library is <1.5 KB |
| Bundle size gate blocks legitimate feature work | Medium | Medium | Per-MFE ceilings have 10-20% headroom over current sizes; waiver process for justified increases |

## Open Questions

- [ ] Should the weekly Lighthouse CI run target staging (`apps.academyv2.mereka.dev`) or production (`apps.academyv2.mereka.io`), or both?
- [ ] Which RUM backend should we use: `web-vitals` library reporting to Prometheus pushgateway, or Sentry Performance Monitoring (already partially configured)?
- [ ] Should bundle size warnings be posted as GitHub PR comments, or only logged in CI output?
- [ ] What is the actual current size of each MFE bundle? (Needed to validate that proposed ceilings have adequate headroom. Measure before enforcing.)
