#!/usr/bin/env bash
# Verify branding signals are visible on public endpoints (prod + dev)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

COMMON_OVERRIDE_CSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
MFE_THEME_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
EXPECTED_BRANDING_REV="$(sed -nE 's/.*--mereka-branding-rev:[[:space:]]*"([^"]+)".*/\1/p' "$COMMON_OVERRIDE_CSS" | head -n 1)"
EXPECTED_MFE_BRANDING_REV="$(sed -nE 's/.*--mereka-mfe-branding-rev:[[:space:]]*"([^"]+)".*/\1/p' "$MFE_THEME_SCSS" | head -n 1)"

ENVIRONMENT="${1:-prod}"
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Usage: $0 [prod|dev]" >&2
  exit 1
fi

BRANDING_LEVEL="${BRANDING_LEVEL:-core}" # core|deep
if [[ "$BRANDING_LEVEL" != "core" && "$BRANDING_LEVEL" != "deep" ]]; then
  echo "Invalid BRANDING_LEVEL: ${BRANDING_LEVEL} (expected core|deep)" >&2
  exit 1
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  BASE_DOMAIN="$LMS_DOMAIN"
  STUDIO_HOST="$STUDIO_DOMAIN"
  MFE_HOST="$MFE_DOMAIN"
  FORUM_HOST="$FORUM_DOMAIN"
  EXTRA_HOSTS=("$BIJI_DOMAIN" "$SKILLOURFUTURE_DOMAIN")
else
  BASE_DOMAIN="$DEV_LMS_DOMAIN"
  STUDIO_HOST="$DEV_STUDIO_DOMAIN"
  MFE_HOST="$DEV_MFE_DOMAIN"
  FORUM_HOST="$DEV_FORUM_DOMAIN"
  EXTRA_HOSTS=()
fi

CURL_TIMEOUT_SECONDS="${CURL_TIMEOUT_SECONDS:-20}"
failures=0

check_follow_200() {
  local url=$1
  local label=$2
  local code size
  # Follow redirects and require a real 200 so we know the asset is reachable.
  code=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  size=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{size_download}" "$url" 2>/dev/null || echo "0")
  if [[ "$code" == "200" && "$size" -gt 0 ]]; then
    printf "✓ %s (200, %s bytes)\n" "$label" "$size"
  else
    printf "✗ %s (%s, %s bytes)\n" "$label" "$code" "$size" >&2
    failures=$((failures + 1))
  fi
}

check_any_follow_200() {
  local label=$1
  shift
  local url code size ok=0
  for url in "$@"; do
    code=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    size=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{size_download}" "$url" 2>/dev/null || echo "0")
    if [[ "$code" == "200" && "$size" -gt 0 ]]; then
      printf "✓ %s (200 via %s, %s bytes)\n" "$label" "$url" "$size"
      ok=1
      break
    fi
  done
  if [[ "$ok" == "0" ]]; then
    printf "✗ %s (no working URL)\n" "$label" >&2
    for url in "$@"; do
      code=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
      size=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{size_download}" "$url" 2>/dev/null || echo "0")
      printf "  - %s (%s, %s bytes)\n" "$url" "$code" "$size" >&2
    done
    failures=$((failures + 1))
  fi
}

check_http() {
  local url=$1
  local label=$2
  local code
  code=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
    printf "✓ %s (%s)\n" "$label" "$code"
  else
    printf "✗ %s (%s)\n" "$label" "$code" >&2
    failures=$((failures + 1))
  fi
}

check_contains() {
  local url=$1
  local label=$2
  local needle=$3
  local body
  body=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "$url" 2>/dev/null || true)
  if printf '%s' "$body" | rg -F -q "$needle"; then
    printf "✓ %s\n" "$label"
  else
    printf "✗ %s (missing '%s')\n" "$label" "$needle" >&2
    failures=$((failures + 1))
  fi
}

check_contains_any() {
  local url=$1
  local label=$2
  shift 2
  local body needle
  body=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "$url" 2>/dev/null || true)
  for needle in "$@"; do
    if printf '%s' "$body" | rg -F -q "$needle"; then
      printf "✓ %s\n" "$label"
      return
    fi
  done
  printf "✗ %s (none of expected strings found)\n" "$label" >&2
  failures=$((failures + 1))
}

check_mfe_authn_surface() {
  local mfe_host=$1
  local authn_url="https://${mfe_host}/authn/login"
  local config_url="https://${mfe_host}/api/mfe_config/v1"
  local html config authn_css_path authn_css

  check_http "$authn_url" "MFE login reachable"

  html="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "$authn_url" 2>/dev/null || true)"
  if printf '%s' "$html" | rg -F -q '<div id="root"></div>' \
    && printf '%s' "$html" | rg -q '/authn/app\.[^"]+\.js' \
    && printf '%s' "$html" | rg -q '/authn/app\.[^"]+\.css'; then
    printf "✓ MFE auth page serves authn bundle shell\n"
  else
    printf "✗ MFE auth page missing expected authn bundle shell\n" >&2
    failures=$((failures + 1))
  fi

  authn_css_path="$(printf '%s' "$html" | rg -o '/authn/app\.[^"]+\.css' | head -n 1 || true)"
  if [[ -z "$authn_css_path" ]]; then
    printf "✗ MFE auth page missing app CSS link\n" >&2
    failures=$((failures + 1))
  else
    authn_css="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "https://${mfe_host}${authn_css_path}" 2>/dev/null || true)"
    if printf '%s' "$authn_css" | grep -Eq -- '--mereka-mfe-gradient'; then
      if [[ -n "$EXPECTED_MFE_BRANDING_REV" ]] && ! printf '%s' "$authn_css" | grep -F -q "$EXPECTED_MFE_BRANDING_REV"; then
        printf "✗ MFE auth CSS missing expected branding revision (%s)\n" "$EXPECTED_MFE_BRANDING_REV" >&2
        failures=$((failures + 1))
      else
        printf "✓ MFE auth CSS includes Mereka branding markers\n"
      fi
    else
      printf "✗ MFE auth CSS missing Mereka gradient marker\n" >&2
      failures=$((failures + 1))
    fi
  fi

  config="$(curl -sS --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "$config_url" 2>/dev/null || true)"
  if printf '%s' "$config" | rg -F -q '"SITE_NAME": "Mereka Academy"' \
    && printf '%s' "$config" | rg -F -q '/theming/asset/mereka/images/logo-horizontal.png'; then
    printf "✓ MFE config exposes Mereka site + logo branding\n"
  else
    printf "✗ MFE config missing expected Mereka branding fields\n" >&2
    failures=$((failures + 1))
  fi
}

check_css_fonts() {
  local url=$1
  local label=$2
  local css
  local rev_ok=1
  css="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "$url" 2>/dev/null || true)"
  if [[ -n "$EXPECTED_BRANDING_REV" ]] && ! printf '%s' "$css" | grep -F -q "$EXPECTED_BRANDING_REV"; then
    rev_ok=0
  fi
  # Font-face URLs are fingerprinted (e.g. Poppins-Regular.<hash>.woff2), so match
  # the base name and extension rather than an exact filename.
  if printf '%s' "$css" | grep -Eq 'font-family:[[:space:]]*"Poppins"' \
    && printf '%s' "$css" | grep -Eq 'font-family:[[:space:]]*"Lato"' \
    && printf '%s' "$css" | grep -Eq 'Poppins-Regular[^"]*\.woff2' \
    && printf '%s' "$css" | grep -Eq 'Lato-Regular[^"]*\.woff2' \
    && printf '%s' "$css" | grep -Eq '\.mereka-footer' \
    && printf '%s' "$css" | grep -Eq '\.mereka-footer[[:space:]]+\.footer-brand[[:space:]]+img' \
    && [[ "$rev_ok" == "1" ]]; then
    if [[ "${BRANDING_LEVEL}" == "deep" ]]; then
      # Deep checks verify that key branded surfaces are actually present in the compiled override CSS
      # (course cards, courseware chrome). This avoids "homepage looks branded but the app is default".
      if printf '%s' "$css" | grep -Eq '\.courses-listing' \
        && printf '%s' "$css" | grep -Eq '\.courseware' \
        && printf '%s' "$css" | grep -Eq '\.sequence-nav' \
        && printf '%s' "$css" | grep -Eq '\.xblock'; then
        printf "✓ %s\n" "$label"
      else
        printf "✗ %s (deep checks: missing course cards/courseware selectors)\n" "$label" >&2
        echo "  hint: This usually means the cluster is running an older openedx image." >&2
        echo "  hint: Rebuild + deploy openedx, then rerun:" >&2
        echo "        BRANDING_LEVEL=deep ./scripts/qa/verify-public-branding.sh prod" >&2
        echo "  hint: Source gate for the repo (should already pass):" >&2
        echo "        BRANDING_LEVEL=deep ./scripts/branding/verify-branding-health.sh" >&2
        failures=$((failures + 1))
      fi
    else
      printf "✓ %s\n" "$label"
    fi
  else
    printf "✗ %s (missing Poppins/Lato/footer wiring or branding revision marker)\n" "$label" >&2
    printf "  debug: url=%s\n" "$url" >&2
    printf "  debug: css_bytes=%s\n" "${#css}" >&2
    local ok_poppins ok_lato ok_poppins_file ok_lato_file ok_footer ok_footer_img
    if printf '%s' "$css" | grep -Eq 'font-family:[[:space:]]*"Poppins"'; then ok_poppins=1; else ok_poppins=0; fi
    if printf '%s' "$css" | grep -Eq 'font-family:[[:space:]]*"Lato"'; then ok_lato=1; else ok_lato=0; fi
    if printf '%s' "$css" | grep -Eq 'Poppins-Regular[^"]*\.woff2'; then ok_poppins_file=1; else ok_poppins_file=0; fi
    if printf '%s' "$css" | grep -Eq 'Lato-Regular[^"]*\.woff2'; then ok_lato_file=1; else ok_lato_file=0; fi
    if printf '%s' "$css" | grep -Eq '\.mereka-footer'; then ok_footer=1; else ok_footer=0; fi
    if printf '%s' "$css" | grep -Eq '\.mereka-footer[[:space:]]+\.footer-brand[[:space:]]+img'; then ok_footer_img=1; else ok_footer_img=0; fi
    printf "  debug: checks poppins=%s lato=%s poppins_woff2=%s lato_woff2=%s footer=%s footer_img=%s\n" \
      "$ok_poppins" "$ok_lato" "$ok_poppins_file" "$ok_lato_file" "$ok_footer" "$ok_footer_img" >&2
    if [[ "$rev_ok" == "0" ]]; then
      printf "  debug: expected_branding_rev=%s not found in live CSS\n" "$EXPECTED_BRANDING_REV" >&2
      echo "  hint: Production is likely running an older openedx image." >&2
    fi
    failures=$((failures + 1))
  fi
}

check_homepage_brand_fonts() {
  local base_domain=$1
  local label=$2
  local html css_path override_css
  local ts

  # Avoid false negatives when an edge cache briefly serves an old HTML page that
  # references an older fingerprinted CSS asset which may no longer exist.
  ts="$(date +%s)"
  html="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "https://${base_domain}/?nocache=${ts}" 2>/dev/null || true)"

  # We load brand overrides via comprehensive theme hook `head-extra.html`.
  css_path="$(printf '%s' "$html" | rg -o '/static/mereka/css/mereka-overrides[^"]*\.css' | head -n 1 || true)"
  if [[ -z "$css_path" ]]; then
    printf "✗ %s (missing Mereka override CSS link in homepage HTML)\n" "$label" >&2
    failures=$((failures + 1))
    return
  fi

  override_css="https://${base_domain}${css_path}?nocache=${ts}"
  check_css_fonts "$override_css" "$label (override CSS wiring)"
}

check_homepage_brand_logo() {
  local base_domain=$1
  local label=$2
  local html logo_path logo_url code size
  local theming_effective_url
  local ts

  ts="$(date +%s)"
  html="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "https://${base_domain}/?nocache=${ts}" 2>/dev/null || true)"
  # Prefer the main header logo. Fall back to any logo.png reference.
  logo_path="$(echo "$html" | sed -nE 's/.*<img[^>]*class="logo"[^>]*src="([^"]+)".*/\1/p' | head -n 1)"
  if [[ -z "$logo_path" ]]; then
    logo_path="$(echo "$html" | sed -nE 's/.*src="([^"]*logo[^"]*\\.png)".*/\1/p' | head -n 1)"
  fi

  if [[ -z "$logo_path" ]]; then
    printf "✗ %s (could not find logo src in homepage HTML)\n" "$label" >&2
    failures=$((failures + 1))
    return
  fi

  if [[ "$logo_path" =~ ^https?:// ]]; then
    logo_url="$logo_path"
  else
    logo_url="https://${base_domain}${logo_path}"
  fi

  # Brand sanity check: the homepage logo should ultimately match the theming logo redirect target.
  # On Open edX Indigo this often ends up under /static/images/logo.<hash>.png.
  theming_effective_url="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{url_effective}" "https://${base_domain}/theming/asset/mereka/images/logo-horizontal.png" 2>/dev/null || true)"
  if [[ -z "$theming_effective_url" ]]; then
    printf "✗ %s (could not resolve theming logo)\n" "$label" >&2
    failures=$((failures + 1))
    return
  fi

  # Accept either:
  # 1) A direct themed static logo path (common with comprehensive theming), OR
  # 2) The same URL as the theming redirect target.
  if ! echo "$logo_url" | grep -q "/static/mereka/images/logo" && [[ "$logo_url" != "$theming_effective_url" ]]; then
    printf "✗ %s (homepage logo is not themed)\n" "$label" >&2
    printf "  homepage_logo_url: %s\n" "$logo_url" >&2
    printf "  expected_prefix: %s\n" "https://${base_domain}/static/mereka/images/logo" >&2
    printf "  theming_logo_url: %s\n" "$theming_effective_url" >&2
    failures=$((failures + 1))
    return
  fi

  code=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{http_code}" "$logo_url" 2>/dev/null || echo "000")
  size=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" -o /dev/null -w "%{size_download}" "$logo_url" 2>/dev/null || echo "0")
  if [[ "$code" == "200" && "$size" -gt 2048 ]]; then
    printf "✓ %s\n" "$label"
  else
    printf "✗ %s (logo unreachable or too small)\n" "$label" >&2
    printf "  logo_url: %s\n" "$logo_url" >&2
    printf "  http: %s size: %s\n" "$code" "$size" >&2
    failures=$((failures + 1))
  fi
}

check_studio_brand_css() {
  local studio_host=$1
  local label=$2
  local ts html css_path css

  ts="$(date +%s)"
  html="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "https://${studio_host}/?nocache=${ts}" 2>/dev/null || true)"
  if [[ -z "${html:-}" ]]; then
    printf "✗ %s (studio host unreachable)\n" "$label" >&2
    failures=$((failures + 1))
    return
  fi

  css_path="$(printf '%s' "$html" | rg -o '/static/studio/mereka/css/studio-main-v1\.[a-z0-9]+\.css' | head -n 1 || true)"
  if [[ -z "${css_path:-}" ]]; then
    printf "✗ %s (missing studio-main-v1 themed CSS link)\n" "$label" >&2
    failures=$((failures + 1))
    return
  fi

  css="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "https://${studio_host}${css_path}?nocache=${ts}" 2>/dev/null || true)"
  if [[ -z "${css:-}" ]]; then
    printf "✗ %s (could not fetch studio CSS)\n" "$label" >&2
    failures=$((failures + 1))
    return
  fi

  if printf '%s' "$css" | grep -Eq -- '--mereka-color-teal' \
    && printf '%s' "$css" | grep -Eq 'Poppins-Regular[^"]*\.woff2' \
    && printf '%s' "$css" | grep -Eq 'Lato-Regular[^"]*\.woff2' \
    && ! printf '%s' "$css" | grep -Eq 'fonts\.googleapis\.com'; then
    if [[ "${BRANDING_LEVEL}" == "deep" ]]; then
      if printf '%s' "$css" | grep -Eq 'action-create-course' \
        && printf '%s' "$css" | grep -Eq 'action-create-library' \
        && printf '%s' "$css" | grep -Eq 'outline-complex' \
        && printf '%s' "$css" | grep -Eq 'outline-item-title' \
        && printf '%s' "$css" | grep -Eq 'add-xblock-component'; then
        printf "✓ %s\n" "$label"
      else
        printf "✗ %s (deep checks: missing Studio create-flow/outline selectors)\n" "$label" >&2
        failures=$((failures + 1))
      fi
    else
      printf "✓ %s\n" "$label"
    fi
  else
    printf "✗ %s (missing token/font wiring or still importing Google fonts)\n" "$label" >&2
    failures=$((failures + 1))
  fi
}

check_forum_heartbeat() {
  local forum_host=$1
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "https://${forum_host}/heartbeat" 2>/dev/null || echo "000")"
  if [[ "$code" == "200" ]]; then
    printf "✓ Forum heartbeat (%s)\n" "$code"
  else
    printf "✗ Forum heartbeat (%s)\n" "$code" >&2
    failures=$((failures + 1))
  fi
}

check_credentials_health() {
  local credentials_host=$1
  local root_url="https://${credentials_host}/"
  local health_url="https://${credentials_host}/health/"
  local admin_url="https://${credentials_host}/admin/login/"
  local body root

  root="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "$root_url" 2>/dev/null || true)"
  if printf '%s' "$root" | rg -F -q "Mereka Credentials Service"; then
    printf "✓ Credentials root landing is branded\n"
  else
    printf "✗ Credentials root landing missing branded content\n" >&2
    failures=$((failures + 1))
  fi

  check_http "$admin_url" "Credentials admin login reachable"
  body="$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT_SECONDS" "$health_url" 2>/dev/null || true)"
  if printf '%s' "$body" | rg -F -q '"overall_status"' \
    && printf '%s' "$body" | rg -F -q '"database_status"'; then
    printf "✓ Credentials health payload includes status fields\n"
  else
    printf "✗ Credentials health payload missing expected status fields\n" >&2
    failures=$((failures + 1))
  fi
}

echo "Branding verification ($ENVIRONMENT) for ${BASE_DOMAIN}..."
echo "Branding level: ${BRANDING_LEVEL}"
echo ""

# HTML branding checks
check_contains "https://${BASE_DOMAIN}/" "LMS homepage includes 'Mereka Academy'" "Mereka Academy"
check_contains "https://${STUDIO_HOST}/" "Studio page includes 'Mereka'" "Mereka"
check_mfe_authn_surface "${MFE_HOST}"

# Asset checks (theme assets)
check_any_follow_200 "Logo asset (logo.png)" \
  "https://${BASE_DOMAIN}/theming/asset/mereka/images/logo.png" \
  "https://${BASE_DOMAIN}/static/mereka/images/logo.png"
check_any_follow_200 "Logo asset (logo-horizontal.png)" \
  "https://${BASE_DOMAIN}/theming/asset/mereka/images/logo-horizontal.png" \
  "https://${BASE_DOMAIN}/static/mereka/images/logo-horizontal.png"
check_any_follow_200 "Favicon asset (favicon.ico)" \
  "https://${BASE_DOMAIN}/theming/asset/mereka/images/favicon.ico" \
  "https://${BASE_DOMAIN}/static/mereka/images/favicon.ico"

# Font checks (critical for brand typography)
# The homepage must stop using stock Indigo Google fonts and include brand fonts.
check_homepage_brand_fonts "${BASE_DOMAIN}" "Homepage uses local brand fonts (no Google fonts)"
check_studio_brand_css "${STUDIO_HOST}" "Studio uses themed CSS tokens/fonts (no Google fonts)"

# Homepage must actually be using brand logo content (not stock Open edX).
check_homepage_brand_logo "${BASE_DOMAIN}" "Homepage logo matches brand assets"
check_forum_heartbeat "${FORUM_HOST}"
check_credentials_health "credentials.${BASE_DOMAIN}"

for host in "${EXTRA_HOSTS[@]}"; do
  check_http "https://${host}/" "Microsite ${host} reachable"
  check_homepage_brand_fonts "${host}" "Microsite ${host} uses local brand fonts (no Google fonts)"
  check_homepage_brand_logo "${host}" "Microsite ${host} logo matches brand assets"
done

echo ""
if [[ $failures -gt 0 ]]; then
  echo "${failures} branding checks failed." >&2
  exit 1
fi

echo "All branding checks passed."
