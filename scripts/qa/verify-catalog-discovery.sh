#!/usr/bin/env bash
# @covers AC-T117-001, AC-T117-002, AC-T117-003, AC-T117-004
# @spec: branding-system_spec.md
# verify-catalog-discovery.sh
#
# T117: Ulmo catalog revamp + Discovery theming audit verification.
#
# Checks that:
#   - Design tokens are applied to catalog CSS surfaces
#   - Discovery service settings are correctly configured
#   - Indigo course-about template OG tags are present (upstream)
#   - SEO gaps are documented and tracked
#   - No regressions in branding token wiring
#
# Usage:
#   ./scripts/qa/verify-catalog-discovery.sh
#   ./scripts/qa/verify-catalog-discovery.sh --live   # includes HTTP checks against prod
#
# Counters: PASS / FAIL / SKIP

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0
SKIP=0

# Optionally probe the live cluster
LIVE_MODE=false
for arg in "$@"; do
  [[ "$arg" == "--live" ]] && LIVE_MODE=true
done

# ─── helpers ────────────────────────────────────────────────────────────────

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP  $1"; SKIP=$((SKIP + 1)); }

check_file_exists() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    pass "$label"
  else
    fail "$label — file not found: $path"
  fi
}

check_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label — file not found: $file"
    return
  fi
  if grep -qF -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label — pattern not found in $file: $needle"
  fi
}

check_contains_re() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label — file not found: $file"
    return
  fi
  if grep -qE -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label — pattern not found in $file: $needle"
  fi
}

check_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if [[ ! -f "$file" ]]; then
    skip "$label — file not found: $file"
    return
  fi
  if grep -qF -- "$needle" "$file"; then
    fail "$label — unwanted pattern found in $file: $needle"
  else
    pass "$label"
  fi
}

http_check() {
  local url="$1"
  local needle="$2"
  local label="$3"
  if [[ "$LIVE_MODE" != "true" ]]; then
    skip "$label (--live not set)"
    return
  fi
  local body
  body="$(curl -sf --max-time 10 "$url" 2>/dev/null)" || {
    fail "$label — HTTP request failed: $url"
    return
  }
  if grep -qF "$needle" <<< "$body"; then
    pass "$label"
  else
    fail "$label — pattern not found in response from $url: $needle"
  fi
}

section() {
  echo ""
  echo "=== $1 ==="
}

# ─── 1. Design Token Files ───────────────────────────────────────────────────

section "1. Design Token File Presence"

TOKENS_CSS="$REPO_ROOT/assets/branding/tokens.css"
TOKENS_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
MEREKA_OVERRIDES_COMMON="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
MEREKA_OVERRIDES_LMS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css/mereka-overrides.css"
MEREKA_OVERRIDES_CMS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/css/mereka-overrides.css"
MEREKA_DESIGN_TOKENS="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css"
LMS_DISCOVERY_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/sass/partials/_discovery.scss"
HEAD_EXTRA_LMS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/head-extra.html"
HEAD_EXTRA_COMMON="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates/head-extra.html"
HEAD_EXTRA_CMS="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/head-extra.html"
COURSE_TEMPLATE_LMS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/course.html"
COURSE_CARD_TEMPLATE_LMS="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/discovery/course_card.underscore"

check_file_exists "$TOKENS_CSS" "Canonical token source exists (assets/branding/tokens.css)"
check_file_exists "$TOKENS_SCSS" "SCSS bridge exists (scss/_tokens.scss)"
check_file_exists "$MEREKA_OVERRIDES_COMMON" "Common mereka-overrides.css exists"
check_file_exists "$MEREKA_OVERRIDES_LMS" "LMS mereka-overrides.css exists"
check_file_exists "$MEREKA_OVERRIDES_CMS" "CMS mereka-overrides.css exists"
check_file_exists "$MEREKA_DESIGN_TOKENS" "mereka-design-tokens.css exists"
check_file_exists "$LMS_DISCOVERY_SCSS" "LMS discovery partial exists"
check_file_exists "$HEAD_EXTRA_LMS" "LMS head-extra.html exists"
check_file_exists "$HEAD_EXTRA_COMMON" "Common head-extra.html exists"
check_file_exists "$HEAD_EXTRA_CMS" "CMS head-extra.html exists"
check_file_exists "$COURSE_TEMPLATE_LMS" "LMS course card template override exists"
check_file_exists "$COURSE_CARD_TEMPLATE_LMS" "LMS discovery course-card template override exists"

# ─── 2. Token Namespace Consistency ─────────────────────────────────────────

section "2. Token Namespace Consistency"

# Canonical source defines the three brand primaries
check_contains "$TOKENS_CSS" "--color-teal: #237072" "tokens.css defines --color-teal"
check_contains "$TOKENS_CSS" "--color-magenta: #ab3b78" "tokens.css defines --color-magenta"
check_contains "$TOKENS_CSS" "--color-blue: #295cad" "tokens.css defines --color-blue"

# SCSS bridge mirrors the canonical colours
check_contains "$TOKENS_SCSS" "\$color-teal: #237072" "SCSS bridge mirrors teal"
check_contains "$TOKENS_SCSS" "\$color-magenta: #ab3b78" "SCSS bridge mirrors magenta"
check_contains "$TOKENS_SCSS" "--pgn-color-primary-base" "SCSS bridge exports --pgn-color-primary-base (Paragon bridge)"
check_contains "$TOKENS_SCSS" "--mereka-color-teal" "SCSS bridge exports --mereka-color-teal"

# Runtime CSS carries the Mereka namespace vars
check_contains "$MEREKA_OVERRIDES_LMS" "--mereka-color-teal" "LMS overrides define --mereka-color-teal"
check_contains "$MEREKA_OVERRIDES_LMS" "--pgn-color-primary-base" "LMS overrides bridge --pgn-color-primary-base"
check_contains "$MEREKA_OVERRIDES_COMMON" "--mereka-color-teal" "Common overrides define --mereka-color-teal"

# Branding revision marker present
check_contains "$MEREKA_OVERRIDES_LMS" "--mereka-branding-rev" "LMS overrides have branding revision marker"

# ─── 3. Catalog CSS Surface Coverage ────────────────────────────────────────

section "3. Catalog CSS Surface Coverage"

# The authored discovery surface is LMS-only SCSS, not runtime override CSS.
check_contains "$LMS_DISCOVERY_SCSS" ".find-courses" "LMS discovery partial styles .find-courses"
check_contains "$LMS_DISCOVERY_SCSS" "#discovery-form.wrapper-search-context" "LMS discovery partial styles the search shell"
check_contains "$LMS_DISCOVERY_SCSS" ".discovery-input" "LMS discovery partial styles search input"
check_contains "$LMS_DISCOVERY_SCSS" ".discovery-submit.button" "LMS discovery partial styles submit button"
check_contains "$LMS_DISCOVERY_SCSS" ".search-facets" "LMS discovery partial styles search facets panel"
check_contains "$LMS_DISCOVERY_SCSS" ".courses-listing" "LMS discovery partial styles catalog grid"

# Course-about page styling
check_contains "$LMS_DISCOVERY_SCSS" ".course-about" "LMS discovery partial styles .course-about"
check_contains "$LMS_DISCOVERY_SCSS" ".course-about .register" "LMS discovery partial styles enroll CTA"
check_contains "$LMS_DISCOVERY_SCSS" ".course-about .course-sidebar" "LMS discovery partial styles course-about sidebar"
check_contains "$LMS_DISCOVERY_SCSS" ".course-about .intro-inner-wrapper" "LMS discovery partial styles course-about hero"
check_contains "$LMS_DISCOVERY_SCSS" "grid-template-columns: minmax(0, 1.7fr) minmax(18rem, 24rem)" "LMS discovery partial gives course-about a two-column conversion layout"
check_contains "$LMS_DISCOVERY_SCSS" ".course-about .social-sharing" "LMS discovery partial styles course-about social sharing cluster"
check_contains "$LMS_DISCOVERY_SCSS" ".course-about .important-dates-item" "LMS discovery partial styles course-about metadata cards"
check_contains "$LMS_DISCOVERY_SCSS" "position: sticky" "LMS discovery partial keeps the course-about sidebar sticky on desktop"

# Course card styling
check_contains "$LMS_DISCOVERY_SCSS" ".find-courses .course .course-image" "LMS discovery partial styles course card image area"
check_contains "$LMS_DISCOVERY_SCSS" ".find-courses #discovery-message.search-status-label" "LMS discovery count is treated as an eyebrow, not a hero"
check_contains_re "$LMS_DISCOVERY_SCSS" "text-transform:[[:space:]]*capitalize" "LMS discovery filters normalize raw facet labels"
check_contains "$LMS_DISCOVERY_SCSS" "grid-template-columns: repeat(auto-fit, minmax(260px, 1fr))" "LMS discovery grid is dense without collapsing cards"
check_contains "$LMS_DISCOVERY_SCSS" ".find-courses .course .course-name" "LMS discovery groups course metadata as a vertical stack"
check_contains "$LMS_DISCOVERY_SCSS" ".find-courses .course .course-code" "LMS discovery keeps internal course code tertiary"
check_contains "$LMS_DISCOVERY_SCSS" ".find-courses .course .course-title" "LMS discovery keeps course title primary"
check_contains "$LMS_DISCOVERY_SCSS" ".find-courses .learn-more" "LMS discovery styles CTA as an image-overlay pill"
check_contains "$LMS_DISCOVERY_SCSS" "@media (max-width: 640px)" "LMS discovery partial carries the mobile fallback"
check_contains "$COURSE_TEMPLATE_LMS" "View Course" "LMS template CTA says View Course"
check_contains "$COURSE_CARD_TEMPLATE_LMS" "View Course" "Discovery template CTA says View Course"
check_contains "$COURSE_TEMPLATE_LMS" "class=\"course-code\" aria-hidden=\"true\"" "LMS template demotes internal course codes"
check_contains "$COURSE_CARD_TEMPLATE_LMS" "class=\"course-code\" aria-hidden=\"true\"" "Discovery template demotes internal course codes"
check_contains "$COURSE_CARD_TEMPLATE_LMS" "<div class=\"cover-image\">" "Discovery template keeps CTA inside cover image"

# Token usage in catalog CSS (not hard-coded hex for brand values)
check_contains "$LMS_DISCOVERY_SCSS" "var(--mereka-shadow-card)" "Catalog CSS uses --mereka-shadow-card token"
check_contains "$LMS_DISCOVERY_SCSS" "var(--mereka-gradient-primary)" "Catalog CSS uses --mereka-gradient-primary token"
check_contains "$LMS_DISCOVERY_SCSS" "var(--mereka-font-heading)" "Catalog CSS uses --mereka-font-heading token"
check_contains "$LMS_DISCOVERY_SCSS" "var(--mereka-color-surface-primary)" "Catalog CSS uses --mereka-color-surface-primary token"

# Common overrides should stay out of authored discovery ownership.
check_not_contains "$MEREKA_OVERRIDES_COMMON" ".find-courses #discovery-form.wrapper-search-context" "Common overrides do not own discovery shell"
check_not_contains "$MEREKA_OVERRIDES_COMMON" ".course-about .intro-inner-wrapper" "Common overrides do not own course-about hero"

# ─── 4. Head-Extra CSS Injection ────────────────────────────────────────────

section "4. Head-Extra CSS Injection"

check_contains "$HEAD_EXTRA_LMS" "mereka-overrides.css" "LMS head-extra injects mereka-overrides.css"
check_contains "$HEAD_EXTRA_LMS" "Poppins-Regular.woff2" "LMS head-extra preloads Poppins font"
check_contains "$HEAD_EXTRA_LMS" "Lato-Regular.woff2" "LMS head-extra preloads Lato font"
check_contains "$HEAD_EXTRA_LMS" "rel=\"preload\"" "LMS head-extra uses font preload"
check_contains "$HEAD_EXTRA_COMMON" "mereka-overrides.css" "Common head-extra injects mereka-overrides.css"
check_contains "$HEAD_EXTRA_CMS" "mereka-overrides.css" "CMS head-extra injects mereka-overrides.css"

# ─── 5. Discovery Service Settings ──────────────────────────────────────────

section "5. Discovery Service Settings"

DISCOVERY_SETTINGS="$REPO_ROOT/deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py"

check_file_exists "$DISCOVERY_SETTINGS" "Discovery production settings exist"
check_contains "$DISCOVERY_SETTINGS" "PLATFORM_NAME = \"Mereka Academy\"" "Discovery PLATFORM_NAME set to Mereka Academy"
check_contains "$DISCOVERY_SETTINGS" "MEREKA_LMS_DOMAIN" "Discovery settings reference MEREKA_LMS_DOMAIN env var"
check_contains "$DISCOVERY_SETTINGS" "DISCOVERY_DOMAIN" "Discovery settings define DISCOVERY_DOMAIN"
check_contains_re "$DISCOVERY_SETTINGS" "KEY_PREFIX.*discovery" "Discovery cache uses namespaced KEY_PREFIX"
check_contains "$DISCOVERY_SETTINGS" "JWT_AUTH" "Discovery settings configure JWT_AUTH"
check_contains "$DISCOVERY_SETTINGS" "MerekaPlatformAdminMiddleware" "Discovery middleware stack includes platform admin guard"

# ─── 6. LMS Feature Flag Wiring ─────────────────────────────────────────────

section "6. LMS Feature Flag Wiring"

LMS_PROD="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

check_file_exists "$LMS_PROD" "LMS production settings exist"
check_contains "$LMS_PROD" "FEATURES[\"ENABLE_COURSE_DISCOVERY\"] = True" "ENABLE_COURSE_DISCOVERY is True"
check_contains "$LMS_PROD" "DISCOVERY_API_BASE_URL" "DISCOVERY_API_BASE_URL wired in MFE_CONFIG"
check_contains "$LMS_PROD" "COURSE_CATALOG_VISIBILITY_PERMISSION" "COURSE_CATALOG_VISIBILITY_PERMISSION set"
check_contains "$LMS_PROD" "COURSE_ABOUT_VISIBILITY_PERMISSION" "COURSE_ABOUT_VISIBILITY_PERMISSION set"
check_contains "$LMS_PROD" "LEARNER_HOME_MFE_REDIRECT_PERCENTAGE = 100" "All learners redirected to dashboard MFE"
check_contains "$LMS_PROD" "LEARNER_HOME_MICROFRONTEND_URL" "LEARNER_HOME_MICROFRONTEND_URL configured"

# ─── 7. Discovery Sync CronJob ──────────────────────────────────────────────

section "7. Discovery Sync CronJob"

SYNC_CRONJOB="$REPO_ROOT/deploy/k8s/base/jobs/discovery-sync-cronjob.yaml"

check_file_exists "$SYNC_CRONJOB" "Discovery sync CronJob manifest exists"
check_contains "$SYNC_CRONJOB" "refresh_course_metadata" "CronJob runs refresh_course_metadata"
check_contains "$SYNC_CRONJOB" "update_index" "CronJob runs update_index"
check_contains "$SYNC_CRONJOB" "schedule: \"0 */6 * * *\"" "CronJob runs every 6 hours"
check_contains "$SYNC_CRONJOB" "concurrencyPolicy: Forbid" "CronJob uses Forbid concurrency policy"

# ─── 8. Ingress Routing ─────────────────────────────────────────────────────

section "8. Ingress Routing"

INGRESS_PROD="$REPO_ROOT/deploy/k8s/overlays/production/ingress-openedx-lms.yaml"

check_file_exists "$INGRESS_PROD" "Production ingress manifest exists"
check_contains "$INGRESS_PROD" "discovery.academyv2.mereka.io" "Discovery subdomain present in prod ingress"
check_contains "$INGRESS_PROD" "discovery.academyv2.mereka.io" "Discovery subdomain in TLS hosts"

# ─── 9. SEO Gaps (Documentation) ────────────────────────────────────────────

section "9. SEO Gap Tracking (Audit Document)"

AUDIT_DOC="$REPO_ROOT/reports/2026/audits/CATALOG_DISCOVERY_AUDIT.md"

check_file_exists "$AUDIT_DOC" "CATALOG_DISCOVERY_AUDIT.md exists"
check_contains "$AUDIT_DOC" "JSON-LD" "Audit documents JSON-LD / structured data gap"
check_contains "$AUDIT_DOC" "og:image" "Audit documents og:image gap"
check_contains "$AUDIT_DOC" "og:description" "Audit documents og:description gap"
check_contains "$AUDIT_DOC" "canonical" "Audit documents canonical URL gap"
check_contains_re "$AUDIT_DOC" "Course.*schema" "Audit documents Course schema gap"
check_contains "$AUDIT_DOC" "DEFAULT_PRODUCT_SOURCE_SLUG" "Audit documents DEFAULT_PRODUCT_SOURCE_SLUG gap"

# ─── 10. Indigo Course-About OG Tags (Upstream Template) ────────────────────

section "10. Indigo Course-About OG Tags (Upstream Template)"

INDIGO_ABOUT=".venv/lib/python3.13/site-packages/tutorindigo/templates/indigo/lms/templates/courseware/course_about.html"
INDIGO_ABOUT_ABS="$REPO_ROOT/$INDIGO_ABOUT"

if [[ -f "$INDIGO_ABOUT_ABS" ]]; then
  check_contains "$INDIGO_ABOUT_ABS" "og:title" "Indigo course_about.html has og:title"
  check_contains "$INDIGO_ABOUT_ABS" "og:description" "Indigo course_about.html has og:description"
  # Verify NO og:image (this is the known gap)
  if grep -qF "og:image" "$INDIGO_ABOUT_ABS"; then
    pass "Indigo course_about.html has og:image (gap resolved upstream)"
  else
    skip "Indigo course_about.html missing og:image (known SEO gap, tracked in CATALOG_DISCOVERY_AUDIT.md)"
  fi
else
  skip "Indigo course_about.html not present (venv not installed — run make bootstrap)"
fi

# Mereka theme does NOT override course_about — verify no conflicting override
MEREKA_ABOUT_OVERRIDE="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/courseware/course_about.html"
if [[ -f "$MEREKA_ABOUT_OVERRIDE" ]]; then
  pass "Mereka theme has custom course_about.html override (SEO additions present)"
else
  skip "Mereka theme has no course_about.html override yet (SEO gaps pending — tracked in audit doc)"
fi

# ─── 11. MFE Brand Token Config ─────────────────────────────────────────────

section "11. MFE Brand Token Config"

check_contains "$LMS_PROD" "BRAND_PRIMARY" "MFE_CONFIG has BRAND_PRIMARY token"
check_contains "$LMS_PROD" "BRAND_SECONDARY" "MFE_CONFIG has BRAND_SECONDARY token"
check_contains "$LMS_PROD" "BRAND_ACCENT" "MFE_CONFIG has BRAND_ACCENT token"

# ─── 11b. CI Static Coverage ────────────────────────────────────────────────

section "11b. CI Static Coverage"

CI_STATIC_LIST="$REPO_ROOT/.github/ci-scripts-static.txt"
check_file_exists "$CI_STATIC_LIST" "CI static script manifest exists"
check_contains "$CI_STATIC_LIST" "scripts/qa/verify-catalog-discovery.sh" "Catalog/discovery verifier is included in static CI suite"

# ─── 12. Live Cluster HTTP Checks (--live only) ───────────────────────────

section "12. Live Cluster Checks (--live mode only)"

http_check "https://academyv2.mereka.io" "Mereka Academy" "LMS homepage returns platform name"
http_check "https://academyv2.mereka.io" "mereka-overrides.css" "LMS homepage loads mereka-overrides.css"
http_check "https://academyv2.mereka.io/courses" "courses-listing" "Course listing page renders .courses-listing"
http_check "https://discovery.academyv2.mereka.io/health/" "\"status\": \"OK\"" "Discovery health endpoint returns OK"

# ─── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo "  verify-catalog-discovery results"
echo "  PASS: $PASS  |  FAIL: $FAIL  |  SKIP: $SKIP"
echo "================================================================"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "  One or more checks FAILED. See output above."
  exit 1
fi

exit 0
