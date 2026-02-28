# Performance Budgets & Cache-Control Contract

**Purpose**: Define performance budgets, cache-control policies, and bundle size thresholds for Mereka Academy frontend to ensure fast, reliable user experiences.

**Last updated**: 2026-02-17

**Acceptance Criteria**: AC-UIPERF-001, AC-UIPERF-002, AC-UIPERF-003

---

## Performance Budget Thresholds

Performance budgets are based on **Core Web Vitals** — Google's standardized metrics for user experience quality. All measurements are for **production builds** on **representative 3G network** conditions.

| Metric | Threshold | Measurement Point | Priority |
|--------|-----------|-------------------|----------|
| **LCP** (Largest Contentful Paint) | < 2.5s | 75th percentile | P0 |
| **FID** (First Input Delay) | < 100ms | 75th percentile | P0 |
| **CLS** (Cumulative Layout Shift) | < 0.1 | 75th percentile | P0 |
| **TTFB** (Time to First Byte) | < 600ms | 75th percentile | P1 |
| **FCP** (First Contentful Paint) | < 1.8s | 75th percentile | P1 |
| **TTI** (Time to Interactive) | < 3.8s | 75th percentile | P1 |
| **Total Blocking Time** | < 200ms | 75th percentile | P1 |
| **Speed Index** | < 3.4s | 75th percentile | P2 |

**Priority definitions**:
- **P0**: Blocking — must meet thresholds before production release
- **P1**: High — should meet thresholds, requires sign-off if exceeded
- **P2**: Medium — aspirational targets, track trend over time

**Testing conditions**:
- Network: Simulated 3G (1.6 Mbps throughput, 150ms RTT)
- Device: Mid-tier mobile (4x CPU slowdown)
- Tool: Lighthouse CI (run 5 times, median used)

**Reference**: [Web Vitals](https://web.dev/vitals/), [Lighthouse scoring](https://web.dev/performance-scoring/)

---

## Cache-Control Policy (AC-UIPERF-001)

Cache-control headers maximize CDN hit rates and reduce origin server load while ensuring users always receive fresh content when needed.

### Hashed Assets (Content-Addressable)

**Pattern**: `*.js`, `*.css`, `*.woff`, `*.woff2` with hash in filename (e.g., `main.abc123.js`)

**Headers**:
```
Cache-Control: public, max-age=31536000, immutable
```

**Rationale**:
- **365-day cache**: Hashed filenames never collide, safe to cache forever
- **`immutable`**: Browser won't revalidate even on refresh
- **`public`**: CDN can cache and serve to multiple users
- **Impact**: Near-zero origin requests for repeat visitors

**Examples**:
- `main.a3f7b2c.js` → cache for 1 year
- `app.d9e4f1a.css` → cache for 1 year
- `roboto-latin.7a2b3c4.woff2` → cache for 1 year

### index.html (Entry Point)

**Pattern**: `index.html`, unhashed HTML files

**Headers**:
```
Cache-Control: no-cache, must-revalidate
```

**Rationale**:
- **`no-cache`**: Browser checks server freshness every request (via ETag/Last-Modified)
- **`must-revalidate`**: Don't serve stale content from cache
- **Impact**: Always loads latest SPA shell, which references latest hashed assets

**Critical**: `index.html` must NEVER have `max-age` > 0, as it controls which hashed assets to load.

### API Responses

**Pattern**: `/api/*`, `/login_refresh`, `/api/mfe_config/v1/*`

**Headers**:
```
Cache-Control: private, no-store
```

**Rationale**:
- **`private`**: CDN must NOT cache (user-specific data)
- **`no-store`**: Browser must NOT cache (sensitive data)
- **Impact**: Every API call hits origin, ensures fresh data

**Exceptions**:
- Static config endpoints (e.g., `/api/mfe_config/v1/site_config`) may use `Cache-Control: public, max-age=300` (5 minutes) if content is truly static and multi-user-safe

### Static Images & Fonts (Unhashed)

**Pattern**: `*.png`, `*.jpg`, `*.svg`, `*.woff`, `*.woff2` **without hash** in filename

**Headers**:
```
Cache-Control: public, max-age=86400
```

**Rationale**:
- **24-hour cache**: Balance freshness vs. performance
- **`public`**: CDN can cache
- **Impact**: Reduces requests for static brand assets

**Note**: Prefer hashed assets where possible (e.g., via webpack asset fingerprinting).

### Service Worker Scripts

**Pattern**: `service-worker.js`, `sw.js`

**Headers**:
```
Cache-Control: no-cache, must-revalidate
```

**Rationale**:
- **Critical**: Service worker must check for updates frequently
- **Risk**: Stale SW can prevent app updates for days

---

## Bundle Size Budgets (AC-UIPERF-002)

Bundle size directly impacts **LCP** and **TTI**. Budgets are enforced via **webpack-bundle-analyzer** and **Lighthouse CI**.

| Bundle Type | Budget (gzipped) | Limit (uncompressed) | Notes |
|-------------|------------------|----------------------|-------|
| **Initial MFE Load** (total) | 500 KB | 1.5 MB | Includes vendor chunks + MFE entry |
| **Individual Chunk** (max) | 250 KB | 750 KB | Prevents single oversized chunk |
| **Vendor Bundle** (max) | 300 KB | 900 KB | React, Paragon, vendor libs |
| **MFE Entry Chunk** (max) | 150 KB | 450 KB | MFE-specific code only |
| **Lazy-Loaded Route** (max) | 200 KB | 600 KB | Code-split route chunks |
| **CSS** (total initial) | 100 KB | 300 KB | All stylesheets loaded on init |
| **Fonts** (total) | 50 KB | 150 KB | WOFF2 only, subset where possible |

**Enforcement**:
```bash
# Run during CI
npx webpack-bundle-analyzer build/stats.json --mode static --report build/bundle-report.html

# Fail if total initial JS > 500 KB gzipped
npx bundlesize check
```

**Optimization strategies when budget exceeded**:
1. **Code splitting**: Split route-level chunks (`React.lazy()`)
2. **Tree shaking**: Remove unused exports (verify `sideEffects: false` in package.json)
3. **Vendor optimization**: Replace heavy deps (e.g., `lodash` → `lodash-es`, `moment` → `date-fns`)
4. **Dynamic imports**: Load heavy libs on-demand (e.g., charting libraries)
5. **Image optimization**: Use WebP, compress, lazy-load below fold

---

## Caddy Configuration Requirements (AC-UIPERF-003)

Current Caddyfile location: `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`

### Required Header Configuration

**Reference configuration pattern**:

```caddyfile
:8002 {
    log {
        output stdout
        format filter {
            wrap json
            fields {
                common_log delete
                request>headers delete
                resp_headers delete
                tls delete
            }
        }
    }

    # Cache-control header directives
    header {
        # Security headers
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Referrer-Policy strict-origin-when-cross-origin
    }

    # MFE routes with cache headers
    @mfe_authn {
        path /authn /authn/*
    }
    handle @mfe_authn {
        uri strip_prefix /authn
        root * /openedx/dist/authn

        # Cache hashed assets aggressively
        @static {
            file
            path *.js *.css *.woff *.woff2 *.png *.jpg *.svg
        }
        header @static {
            Cache-Control "public, max-age=31536000, immutable"
        }

        # Never cache index.html
        @index {
            file
            path */index.html
        }
        header @index {
            Cache-Control "no-cache, must-revalidate"
        }

        try_files /{path} /index.html
        file_server
    }

    # Repeat for all 11 MFE routes...

    # API routes - no caching
    reverse_proxy /api/mfe_config/v1* lms:8000 {
        header_up Host {http.request.host}
        header_down Cache-Control "private, no-store"
    }

    reverse_proxy /login_refresh* lms:8000 {
        header_up Host {http.request.host}
        header_down Cache-Control "private, no-store"
    }
}
```

**Key implementation notes**:
1. **Per-route static asset matching**: Use `@static` matcher within each MFE handle block
2. **Caddy index.html exception**: Explicitly override cache for `index.html` in each route
3. **Caddy reverse_proxy API headers**: Use `header_down` in `reverse_proxy` blocks to set response cache headers
4. **Content-addressable detection**: Caddy can't detect hashes automatically, so cache ALL static assets in MFE dist directories (safe because MFE build always hashes)

**Current posture**: Caddyfile includes route-level cache-control headers. Keep this contract focused on preventing drift between documented policy and runtime behavior.

---

## Current Gaps (as of 2026-02-17)

| Gap | Impact | Priority |
|-----|--------|----------|
| **No continuous runtime cache-control monitoring** | Header drift can regress cache hit rates without immediate detection | P1 |
| **No performance monitoring** | Can't detect regressions | P0 |
| **No bundle size tracking** | Bundle bloat goes unnoticed | P1 |
| **No Lighthouse CI** | Can't validate performance budgets in CI | P1 |
| **No web-vitals instrumentation** | No RUM data from production | P1 |
| **No CDN in front of Caddy** | Can't leverage edge caching yet | P2 |

**Next steps**:
1. Keep Caddy cache-control policy drift-free via static + runtime verification (AC-UIPERF-003)
2. Set up Lighthouse CI in GitHub Actions
3. Add `web-vitals` library to MFE builds for RUM
4. Configure webpack-bundle-analyzer in build pipeline
5. Set up Google Cloud CDN or Cloudflare in front of LoadBalancer

---

## Tooling

### Lighthouse CI

**Setup** (not yet implemented):

```yaml
# .github/workflows/performance-budget.yml
name: Performance Budget

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  lighthouse:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: treosh/lighthouse-ci-action@v10
        with:
          urls: |
            https://apps.academyv2.mereka.io/authn/login
            https://apps.academyv2.mereka.io/learning
            https://apps.academyv2.mereka.io/learner-dashboard
          uploadArtifacts: true
          temporaryPublicStorage: true
          budgetPath: .lighthouserc.json
```

**Budget config** (`.lighthouserc.json`):

```json
{
  "ci": {
    "collect": {
      "numberOfRuns": 5
    },
    "assert": {
      "preset": "lighthouse:recommended",
      "assertions": {
        "largest-contentful-paint": ["error", {"maxNumericValue": 2500}],
        "first-input-delay": ["error", {"maxNumericValue": 100}],
        "cumulative-layout-shift": ["error", {"maxNumericValue": 0.1}],
        "interactive": ["error", {"maxNumericValue": 3800}],
        "total-byte-weight": ["error", {"maxNumericValue": 512000}]
      }
    },
    "upload": {
      "target": "temporary-public-storage"
    }
  }
}
```

### webpack-bundle-analyzer

**Setup** (not yet implemented):

Add to `@openedx/frontend-build` config in MFE plugin:

```javascript
// infrastructure/tutor/plugins/mereka_lms.py (mfe-webpack-config patch)
module.exports = {
  plugins: [
    new BundleAnalyzerPlugin({
      analyzerMode: process.env.CI ? 'static' : 'server',
      reportFilename: 'bundle-report.html',
      openAnalyzer: !process.env.CI,
      generateStatsFile: true,
      statsFilename: 'stats.json',
    }),
  ],
};
```

### web-vitals RUM

**Setup** (not yet implemented):

Add to MFE initialization:

```javascript
// Add to each MFE's src/index.jsx
import {getCLS, getFID, getFCP, getLCP, getTTFB} from 'web-vitals';

function sendToAnalytics(metric) {
  // Send to Google Analytics, Datadog, etc.
  console.log('[Web Vitals]', metric);
}

getCLS(sendToAnalytics);
getFID(sendToAnalytics);
getFCP(sendToAnalytics);
getLCP(sendToAnalytics);
getTTFB(sendToAnalytics);
```

---

## Verification Commands

**Check cache headers** (requires live endpoint):

```bash
# Should return "Cache-Control: public, max-age=31536000, immutable"
curl -I https://apps.academyv2.mereka.io/authn/static/js/main.abc123.js | grep -i cache-control

# Should return "Cache-Control: no-cache, must-revalidate"
curl -I https://apps.academyv2.mereka.io/authn/index.html | grep -i cache-control

# Should return "Cache-Control: private, no-store"
curl -I https://apps.academyv2.mereka.io/api/mfe_config/v1/config | grep -i cache-control
```

**Verify Caddyfile compliance** (source check):

```bash
./scripts/qa/verify-performance-budget.sh
```

**Run Lighthouse audit** (requires live endpoint):

```bash
npx lighthouse https://apps.academyv2.mereka.io/authn/login \
  --output html \
  --output-path ./lighthouse-authn.html \
  --chrome-flags="--headless"
```

**Analyze bundle size** (requires build artifacts):

```bash
npx webpack-bundle-analyzer build/stats.json
```

---

## MFE-Specific Budgets

Open edX MFEs have different complexity levels. Per-MFE budgets:

| MFE | Initial JS (gzipped) | Rationale |
|-----|----------------------|-----------|
| **authn** | 400 KB | Simple forms, minimal logic |
| **account** | 450 KB | Profile editing, moderate complexity |
| **learning** | 550 KB | Course player, video, assessments (critical path) |
| **learner-dashboard** | 500 KB | Course cards, progress tracking |
| **discussions** | 500 KB | Forum threading, rich text editor |
| **gradebook** | 450 KB | Tables, charts |
| **profile** | 400 KB | Simple profile view |
| **communications** | 450 KB | Messaging UI |
| **ora-grading** | 500 KB | Rubric grading, file uploads |
| **authoring** | 600 KB | Studio course authoring, complex UI |
| **course-authoring** | 600 KB | Alias for authoring, same budget |

**Overall initial load budget**: 500 KB average across all MFEs (some can be higher if justified).

---

## Related Documentation

- **MFE Version Pinning**: `docs/architecture/MFE_VERSIONS.md`
- **Selector Hardening**: `docs/architecture/SELECTOR_HARDENING_POLICY.md`
- **Frontend Audit**: `docs/FRONTEND_AUDIT_CHECKLIST.md`
- **Caddyfile**: `deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile`
- **Troubleshooting**: `docs/operations/TROUBLESHOOTING.md`

---

## Acceptance Criteria

- **AC-UIPERF-001**: Cache-control headers defined for hashed assets, index.html, API responses
- **AC-UIPERF-002**: Performance budgets documented (LCP < 2.5s, FID < 100ms, CLS < 0.1, bundle < 500KB)
- **AC-UIPERF-003**: Caddyfile cache configuration requirements documented with examples

**Verification**: `./scripts/qa/verify-performance-budget.sh`
