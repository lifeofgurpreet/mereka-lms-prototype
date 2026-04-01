# Frontend Runtime Closure Tracker (2026-04-01)

Flat backlog of every user-facing surface that needs audit, fix, or explicit deferral.
Three tenants: Mereka (default), Skill Our Future (SOF), Biji-Biji (BB).

## Surfaces

| # | Surface | URL | Status | Root Cause | Owner File(s) | Fix | Proof |
|---|---------|-----|--------|------------|----------------|-----|-------|
| 1 | `/courses` search error | `/courses` | BLOCKED | Meilisearch not deployed in dev; `SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine"` tries to connect to `http://meilisearch:7700` which does not resolve. `ELASTIC_SEARCH_CONFIG` points to `elasticsearch:9200` also absent. When the search backend raises a connection error, Open edX catches it and shows "An error occurred when searching for courses." | `production.py:150` | **Cannot fix in code.** Either deploy Meilisearch in the dev namespace, OR set `FEATURES["ENABLE_COURSE_DISCOVERY"] = False` + `SEARCH_ENGINE = ""` to disable search and fall back to the static courseware.courses list. Config change required in overlay or production.py. | Needs Meilisearch pod or config disable |
| 2 | `/courses` card images 404 | `/courses` | CSS-MITIGATED | MCT-migrated courses have asset URLs like `asset-v1:MEREKA+MCT31-EN+course+type@asset+block@images_course_image.jpg`. If the course image file was not imported into the contentstore during migration, the URL 404s. The `onerror` handler in templates falls back to `/theming/asset/images/no_course_image.png` which does not exist in the Mereka theme either. The CSS gradient background on `.course .course-image` provides a visual fallback, but no placeholder image shows. | `course.html:11`, `course_card.underscore:4`, `course_about.html:219` | **Fixed in this pass:** Added `no_course_image.png` onerror fallback to use a brand-colored SVG data URI instead of a missing PNG. This ensures broken images degrade to a clean branded placeholder rather than a broken-image icon. | Visual: gradient + SVG placeholder |
| 3 | `/dashboard` legacy page | `/dashboard` | OK | `LEARNER_HOME_MFE_REDIRECT_PERCENTAGE = 100` is set. `LEARNER_HOME_MICROFRONTEND_URL` points to `{MFE_BASE_URL}/learner-dashboard/`. The LMS Django view checks this setting and returns a 302 redirect to the MFE. This works correctly when the MFE is deployed and reachable. No code change needed. | `production.py:724,903` | None needed. Redirect works when MFE is live. | Verify 302 from `/dashboard` to MFE |
| 4 | MFE footer data | MFE pages | OK | `MEREKA_PUBLIC_FOOTER = build_mereka_public_footer()` at `production.py:967` populates the dict. `MFE_CONFIG["MEREKA_PUBLIC_FOOTER"] = MEREKA_PUBLIC_FOOTER` at line 968 injects it into the MFE config API. `FEATURES['MFE_CONFIG'] = MFE_CONFIG` at line 1974 syncs to the API view. The `footer.js` component reads `getConfig().MEREKA_PUBLIC_FOOTER` which comes from the config API response. Data chain is complete. | `mereka_footer.py`, `production.py:967-968`, `footer.js` | None needed. Footer data flows correctly from Python to MFE runtime. | Verify `getConfig().MEREKA_PUBLIC_FOOTER` is non-null in browser console |
| 5 | MFE footer CSS | MFE pages | OK | Footer CSS lives in `scss/_mfe-footer.scss` (compiled into MFE theme), and is duplicated in `mereka-overrides.css` for Django LMS pages. Both copies define the `.mereka-footer--v2` dark footer with all 4 zones. | `scss/_mfe-footer.scss`, `mereka-overrides.css:688-912` | None needed. | Visual check |
| 6 | Django LMS footer | LMS server-rendered pages | OK | `footer.html` template has hardcoded footer content that mirrors `mereka_footer.py` data. Uses tenant-variant fields from SiteConfiguration (support email, privacy URL, etc.). CSS is shared via `mereka-overrides.css`. | `templates/footer.html`, `mereka-overrides.css:688-912` | None needed. | Visual check |
| 7 | Course card broken-image icon | `/courses`, `/dashboard` | FIXED | When `img.src` is empty or 404s and the `onerror` fallback also 404s, browsers show a broken-image icon. The CSS rule `.course .course-image img[src=""]` hides the icon via `visibility: hidden`, but this does not cover 404 responses (the `src` attribute is non-empty). | `mereka-overrides.css:1152-1160` | **Fixed in this pass:** Updated the `onerror` handler in all 3 templates to replace the src with a brand-colored SVG data URI. Also added CSS for `img[data-broken]` to ensure clean fallback. | Broken images show gradient + SVG |
| 8 | `/courses` page layout without search | `/courses` | DOCUMENTED | When course search is disabled (`ENABLE_COURSE_DISCOVERY = False`), the `/courses` page drops the search bar and facets sidebar. The `.courses.no-course-discovery` selector in `_discovery.scss:41-43` spans the full grid width (`grid-column: 1 / -1`). This works correctly. | `_discovery.scss:41-43` | None needed. Layout handles both modes. | n/a |
| 9 | Language selector | LMS footer | DEFERRED | No `LANGUAGES` override in `production.py`. Open edX defaults to `LANGUAGE_CODE = "en"`. The footer template conditionally includes a language selector via `footer_language_selector_is_enabled()` which checks `DarkLangConfig`. No additional languages are configured. Enabling Malay (ms), Bahasa Indonesia (id), or others requires Transifex translation sync + `DarkLangConfig` setup. | `production.py` (absent), `footer.html:230` | **Deferred.** Requires translation import and DarkLangConfig admin setup. Not a code issue. | n/a |
| 10 | Tenant palette injection | LMS pages | OK | `head-extra.html` reads `PRIMARY_COLOR`, `SECONDARY_COLOR`, `ACCENT_COLOR` from SiteConfiguration and injects CSS custom property overrides. SOF gets purple, BB gets black, Mereka gets default magenta. | `head-extra.html:51-83` | None needed. Works via SiteConfiguration per-tenant. | Verify per-tenant in browser |
| 11 | Homepage hero | `/` | OK | `index_overlay.html` renders the Mereka hero section with CTA buttons to `/register` and `/courses`. Uses `platform_name` from SiteConfiguration. | `index_overlay.html` | None needed. | Visual check |
| 12 | Course about page | `/courses/{id}/about` | OK | `course_about.html` renders course detail with hero, quickfacts, decision support, sidebar, and Schema.org JSON-LD. Images use same `onerror` fallback (fixed in #7). | `courseware/course_about.html` | Image fallback fixed with #7. | Visual check |
| 13 | Header brand/logo | All pages | OK | `header/brand.html` loads `images/logo.png` from theme static. Logo files exist in `lms/static/images/`. Tagline "Learning experiences crafted for Southeast Asia" renders. | `header/brand.html`, `lms/static/images/logo.png` | None needed. | Visual check |

## Summary

- **OK (no action):** 9 surfaces (#3, #4, #5, #6, #8, #10, #11, #12, #13)
- **Fixed in this pass:** 2 surfaces (#2, #7) -- image fallback handler
- **Blocked (infra):** 1 surface (#1) -- Meilisearch not deployed
- **Deferred:** 1 surface (#9) -- language selector needs translation import

## Root Cause Details

### #1: Course search error

The `/courses` page in Open edX (Ulmo) uses the `edx-search` package to query a search backend when `FEATURES["ENABLE_COURSE_DISCOVERY"] = True`. The configured backend is `search.meilisearch.MeilisearchEngine` at `http://meilisearch:7700`. In the dev cluster, Meilisearch is not deployed (no pod, no service). When the page loads and the user types a search query (or on initial load if configured for auto-search), the search engine raises a connection error, which the edx-search package catches and renders as "An error occurred when searching for courses."

**Options to resolve:**
1. Deploy Meilisearch in the dev namespace (preferred -- enables search functionality)
2. Disable search in dev overlay: set `SEARCH_ENGINE = ""` and `FEATURES["ENABLE_COURSE_DISCOVERY"] = False` in a dev-specific production.py patch. This falls back to the static course list view (no search, no facets).
3. Index courses after Meilisearch deployment: `./manage.py lms reindex_course --all`

### #2 + #7: Broken course images

MCT-migrated courses reference asset URLs of the form:
```
/asset-v1:MEREKA+MCT31-EN+course+type@asset+block@images_course_image.jpg
```

These 404 when the course image binary was not imported into the Open edX contentstore during migration. The `onerror` handler in the templates fell back to `/theming/asset/images/no_course_image.png` which also did not exist in the Mereka theme.

**Fix applied:** Changed `onerror` handlers to use an inline SVG data URI that renders a brand-colored placeholder. This eliminates dependency on a physical PNG file and ensures any 404'd image degrades cleanly to a branded placeholder with the gradient background visible through the SVG.

### #9: Language selector

Open edX uses `DarkLangConfig` (a Django admin model) to control which languages appear in the language selector. By default, only English is enabled. To add Malay, Indonesian, etc.:
1. Import Transifex translations into the Open edX image (build-time)
2. Create `DarkLangConfig` entries in Django admin (runtime)
3. Set `LANGUAGES` in settings if you want to restrict the list

This is an admin/content task, not a code fix.
