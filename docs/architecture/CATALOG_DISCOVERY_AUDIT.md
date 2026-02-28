# Catalog & Discovery Audit — T117

**Status**: Audit complete, implementation gaps identified
**Date**: 2026-02-25
**Scope**: Ulmo catalog revamp, Design Token application, SEO/structured data gaps, legacy surface deprecation

---

## 1. Surfaces in Scope

Open edX Ulmo (Tutor v21, `open-release/ulmo.1`) exposes three distinct catalog surfaces:

| Surface | URL Pattern | Renderer | Status |
|---------|-------------|----------|--------|
| **Legacy LMS course listing** | `/courses` | Django/Mako (server-rendered) | Active, Mereka-themed |
| **Legacy course-about page** | `/courses/<key>/about` | Django/Mako (server-rendered), Indigo template | Active, Mereka-themed |
| **Learner Dashboard MFE** | `apps.academyv2.mereka.io/learner-dashboard/` | React (Paragon/Indigo) | Active, partially token-bridged |

There is **no separate catalog MFE** in this deployment. Open edX's `frontend-app-learner-catalog` and `frontend-app-course-about` are not built or served. The Discovery service (`discovery.academyv2.mereka.io`) is a backend API only — it has no frontend UI.

---

## 2. Design Token Application — Current State

### 2.1 Token Pipeline (from T107, DONE)

```
Layer 1 (canonical)                        Layer 2 (SCSS bridge)          Layer 3 (runtime CSS)
assets/branding/tokens.css                 scss/_tokens.scss               */static/css/mereka-overrides.css
(110+ CSS custom properties)               (24 SCSS vars + :root block)    (loaded via head-extra.html)
```

All three layers are in sync as of 2026-02-25 (`--mereka-branding-rev: "2026-02-25-wcag-aa"`).

### 2.2 What Is Tokenised on Catalog Surfaces

| Catalog Component | Token Coverage | Specific Tokens Used |
|-------------------|---------------|----------------------|
| `.find-courses` page background | Full | `--mereka-color-surface-primary` |
| Discovery search box (`.find-courses #discovery-form`) | Full | `--mereka-shadow-card`, `--mereka-gradient-primary` |
| Discovery search input (`.find-courses #discovery-input`) | Full | `--mereka-color-surface-primary` |
| Search submit button | Full | `--mereka-gradient-primary` |
| Search facets sidebar | Partial | `--mereka-shadow-card`, `--mereka-font-heading` |
| Course listing grid (`.courses-listing`) | Full | CSS Grid layout |
| Course cards (`.course`) | Full | `--mereka-shadow-card`, border tokens |
| Course card image placeholder | Full | `--mereka-color-teal`, `--mereka-color-blue` (gradient) |
| Course-about page hero header | Full | `--mereka-shadow-card`, `--mereka-font-heading` |
| Course-about radial background | Full | `--mereka-color-teal`, `--mereka-color-magenta`, `--mereka-color-blue` |
| Course-about sidebar | Full | `--mereka-shadow-card` |
| Course-about enroll button | Full | `--mereka-gradient-primary` |
| Course-about summary/description | Full | `--mereka-shadow-card`, `--mereka-font-heading` |
| Learner Dashboard MFE cards | Partial | `--pgn-color-primary-base`, `--pgn-*` via Paragon bridge |

### 2.3 What Is NOT Tokenised (Gaps)

| Component | Gap | Notes |
|-----------|-----|-------|
| Search facet toggle borders | Hard-coded `rgba(26,22,35,0.14)` | Should use `--mereka-color-border` |
| Course-about `<h1>` font-weight | Hard-coded `font-weight: 900` | No token for display weight |
| Course card hover shadow | Hard-coded `rgba(26,22,35,0.12)` | Variant of `--mereka-shadow-lg` not yet defined |
| MFE catalog recommendations | MFE runtime only, no token injection | `BRAND_PRIMARY/SECONDARY/ACCENT` keys exist in `MFE_CONFIG` but are not CSS-var bridged in MFEs |
| Discovery service admin UI | Upstream Django Admin — no Mereka theme | Out of scope (internal tool) |

---

## 3. Discovery Service Configuration

### 3.1 What Discovery Does

`course-discovery` is a separate Django service that indexes course metadata from the LMS and exposes a REST API for catalog queries. It does **not** serve any learner-facing HTML pages.

### 3.2 Current Configuration

**Settings**: `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py`

| Setting | Value | Notes |
|---------|-------|-------|
| `PLATFORM_NAME` | `"Mereka Academy"` | Correct |
| `ALLOWED_HOSTS` | `["discovery", "discovery.localhost", "discovery.academyv2.mereka.io"]` | Correct |
| `DATABASES["default"]` | MySQL `discovery` DB | Correct |
| `CACHES["default"]` | Redis DB 1 with `KEY_PREFIX=discovery` | Correct |
| `DEFAULT_PRODUCT_SOURCE_SLUG` | `"edx"` | **Gap: should be `"mereka"` or a Mereka-specific slug for catalog branding** |
| `ELASTICSEARCH_DSL` | `http://elasticsearch:9200/` | Local Elasticsearch — not tuned for production search quality |

**LMS wiring** (`deploy/k8s/base/apps/openedx/settings/lms/production.py`):

| Setting | Value |
|---------|-------|
| `FEATURES["ENABLE_COURSE_DISCOVERY"]` | `True` |
| `DISCOVERY_API_BASE_URL` (MFE_CONFIG) | `https://discovery.academyv2.mereka.io` |
| `COURSE_CATALOG_VISIBILITY_PERMISSION` | `"see_in_catalog"` |
| `COURSE_ABOUT_VISIBILITY_PERMISSION` | `"see_about_page"` |
| `SEARCH_SKIP_SHOW_IN_CATALOG_FILTERING` | `False` |

**Sync CronJob**: `deploy/k8s/base/jobs/discovery-sync-cronjob.yaml`
- Runs every 6 hours (`0 */6 * * *`)
- Executes `refresh_course_metadata` then `update_index --disable-change-limit`
- **Gap: uses wrong image** — references the `openedx` LMS image, not the `course-discovery` image

**Ingress**: `discovery.academyv2.mereka.io` routes to `caddy` service on port 80. TLS included in `openedx-lms-tls` secret.

**Monitoring**: `ServiceMonitor` (`servicemonitor-discovery.yaml`) scrapes `/metrics` every 30s.

### 3.3 Known Blockers

From `docs/status/DISCOVERY_SERVICE_STATUS.md` (2026-02-03):

- MongoDB Atlas user `cs_comments_user` lacks write permissions on `openedx.modulestore.structures`
- This blocks `refresh_course_metadata` from importing courses programmatically
- Workaround: create courses via Studio UI and trigger manual sync

---

## 4. What Ulmo Changed for Catalog

Ulmo (Open edX release corresponding to Tutor v21) introduced several catalog-relevant changes:

### 4.1 Course-About Page (Legacy Surface)

- The Indigo theme (`tutorindigo`) ships a revised `courseware/course_about.html` with:
  - Improved sidebar layout with SVG icons
  - Fallback course image via `onerror` handler
  - OG meta tags (`og:title`, `og:description`) in the `headextra` block
  - "Course Summary" section header
- The Mereka theme **inherits from Indigo** — no `courseware/course_about.html` override exists in `infrastructure/tutor/themes/mereka/`. This means the Mereka theme uses the Indigo course-about template.
- Mereka CSS overrides in `lms/static/css/mereka-overrides.css` apply ~114 selectors to `.course-about`, `.course-info`, and `.courses-listing` to apply brand styling on top of Indigo's template.

### 4.2 Learner Dashboard MFE

- `LEARNER_HOME_MFE_REDIRECT_PERCENTAGE = 100` — all learners land on the MFE dashboard, not the legacy Django dashboard
- `LEARNER_HOME_MICROFRONTEND_URL` is set to `apps.academyv2.mereka.io/learner-dashboard/`
- The Mereka footer plugin slot (`org.openedx.frontend.layout.footer.v1`) replaces the default Indigo footer in all MFEs including learner-dashboard

### 4.3 Legacy Catalog Deprecation Signal

Ulmo officially deprecates the legacy server-rendered course listing (`/courses` with `#discovery-form`) in favour of a future catalog MFE. As of Ulmo this deprecation is a signal only — the legacy view still ships and is the only learner-facing catalog surface available without a separate catalog MFE build.

---

## 5. SEO / Structured Data — Gap Analysis

### 5.1 Current State

| Page | `<title>` | Meta description | OG tags | Structured data (JSON-LD) | `robots.txt` | Sitemap |
|------|-----------|-----------------|---------|--------------------------|--------------|---------|
| LMS homepage (`/`) | `Mereka Academy` (from platform name) | None | None | None | Default edX | None |
| Course listing (`/courses`) | `Courses` (upstream default) | None | None | None | Default edX | None |
| Course-about (`/courses/<key>/about`) | `{course.display_name}` | None | `og:title`, `og:description` (Indigo) | None | Default edX | None |
| Learner Dashboard MFE | `Mereka Academy` (from SITE_NAME) | None | None | None | n/a (MFE) | n/a |

**OG tags on course-about**: Provided by the Indigo `course_about.html` template (`<%block name="headextra">`). This block outputs `og:title` from `course.display_name_with_default` and `og:description` from `get_course_about_section(request, course, 'short_description')`. These are correct but minimal.

**Gaps**:

1. **No JSON-LD / Schema.org structured data** on any page. Course-about pages lack `Course` schema markup (name, description, provider, startDate, image, url). This is a significant SEO gap — Google's rich results for courses require `Course` + `CourseInstance` schema.

2. **No `og:image`** on course-about pages. The Indigo template provides `og:title` and `og:description` but not `og:image`. Sharing a course link on social media will show no preview image.

3. **No `og:url`** or `og:type` on any page.

4. **No meta description** on homepage or course listing.

5. **No structured sitemap** (`/sitemap.xml`). Open edX ships a basic sitemap at `/sitemap.xml` via `django.contrib.sitemaps`, but it is not configured or verified for this deployment.

6. **No canonical URL tags** (`<link rel="canonical">`) on course-about pages, creating duplicate content risk (e.g. `/courses/<key>/about` accessed with and without trailing slash, or via preview domain).

7. **Course description truncation**: `get_course_about_section(request, course, 'short_description')` returns raw HTML from the Studio rich-text editor. This is injected into `og:description` without stripping tags, which can produce garbage in social share previews.

### 5.2 Priority Ranking

| Gap | SEO Impact | Implementation Complexity | Priority |
|-----|-----------|--------------------------|----------|
| JSON-LD `Course` schema on course-about | High (Google rich results) | Medium (Mako template patch) | P1 |
| `og:image` on course-about | High (social sharing) | Low (add `course_image_url` to headextra block) | P1 |
| Meta description on homepage/listing | Medium | Low | P2 |
| Canonical URL tags | Medium | Low | P2 |
| HTML-stripped `og:description` | Medium | Low | P2 |
| Sitemap verification | Low | Low | P3 |

---

## 6. Legacy Surface Deprecation Plan

### 6.1 Surfaces to Deprecate (per T117)

The T117 tracker task says "Legacy catalog surface deprecated." In Ulmo context this means:

| Surface | Deprecation Action | When |
|---------|-------------------|------|
| Legacy course listing (`/courses` with Elasticsearch-backed `#discovery-form`) | Redirect to learner-dashboard MFE or future catalog MFE | When catalog MFE is available |
| Legacy course-about page (`/courses/<key>/about`) | Replace with Ulmo's new course-about MFE (`frontend-app-course-about`) or keep Indigo template | Decision needed — see Section 6.2 |

### 6.2 Architecture Decision Required

**Option A — Keep Indigo template, apply Mereka overrides (current state)**
- No new MFE to build or deploy
- Tokens already applied via CSS
- SEO gaps remain (no JSON-LD, no og:image)
- Responsive to Ulmo upstream course-about improvements

**Option B — Build and serve `frontend-app-course-about` MFE**
- Full Paragon/token control
- Structured data can be injected via React Helmet
- Requires MFE build, Caddy routing, env config wiring
- Not yet in `MFE_CONFIG_API_URLS` or `deploy/k8s/base/apps/mfe/`

**Recommendation**: Option A in the short term (add JSON-LD and og:image to the Indigo template via a Mereka theme override of `courseware/course_about.html`). Defer Option B to a dedicated MFE track.

---

## 7. Token Application Roadmap for Catalog

To fully apply Design Tokens to catalog surfaces, the following work is needed:

### 7.1 Immediate (hard-coded values to tokenise)

| File | Selector | Current Value | Target Token |
|------|----------|---------------|-------------|
| `lms/static/css/mereka-overrides.css` | `.find-courses #discovery-input:focus` border | `rgba(45,137,139,0.65)` | `var(--mereka-color-teal)` at 65% opacity |
| `lms/static/css/mereka-overrides.css` | `.course:hover` shadow | `rgba(26,22,35,0.12)` | Define `--mereka-shadow-hover` token |
| `tokens.css` | n/a | Missing hover shadow variant | Add `--shadow-hover: 0 26px 70px rgba(0,0,0,0.12)` |

### 7.2 Medium Term (SEO on catalog pages)

1. Create `infrastructure/tutor/themes/mereka/lms/templates/courseware/course_about.html`
2. Override the `headextra` block to add:
   - `og:image` from `course_image_url`
   - `og:url` (canonical)
   - `og:type = "website"`
   - `<link rel="canonical">` tag
   - JSON-LD `Course` schema block
3. Strip HTML from `og:description` (use `re.sub(r'<[^>]+>', '', ...)` or Django's `strip_tags`)

### 7.3 Long Term

- Migrate to catalog MFE when upstream provides a stable Ulmo-compatible release
- Wire `DISCOVERY_API_BASE_URL` into catalog MFE env config
- Token bridge via `BRAND_PRIMARY/SECONDARY/ACCENT` keys in `MFE_CONFIG`

---

## 8. File Index

| File | Role |
|------|------|
| `assets/branding/tokens.css` | Canonical token source (Layer 1) |
| `infrastructure/tutor/themes/mereka/scss/_tokens.scss` | SCSS bridge (Layer 2) |
| `infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css` | Runtime CSS entrypoint (Layer 3, LMS) |
| `infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css` | Runtime CSS entrypoint (Layer 3, common) |
| `infrastructure/tutor/themes/mereka/lms/templates/head-extra.html` | CSS injection hook |
| `.venv/lib/.../tutorindigo/.../courseware/course_about.html` | Upstream Indigo course-about template (read-only) |
| `deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py` | Discovery service Django settings |
| `deploy/k8s/base/jobs/discovery-sync-cronjob.yaml` | Discovery course metadata sync job |
| `deploy/k8s/base/monitoring/servicemonitor-discovery.yaml` | Prometheus scrape config |
| `deploy/k8s/overlays/production/ingress-openedx-lms.yaml` | Ingress routing for `discovery.academyv2.mereka.io` |
| `deploy/k8s/base/apps/openedx/settings/lms/production.py` | LMS feature flags and MFE_CONFIG |
