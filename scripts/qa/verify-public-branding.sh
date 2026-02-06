#!/usr/bin/env bash
# Verify branding signals are visible on public endpoints (prod + dev)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

ENVIRONMENT="${1:-prod}"
if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Usage: $0 [prod|dev]" >&2
  exit 1
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  BASE_DOMAIN="$LMS_DOMAIN"
  EXTRA_HOSTS=("$BIJI_DOMAIN" "$SKILLOURFUTURE_DOMAIN")
else
  BASE_DOMAIN="$DEV_LMS_DOMAIN"
  EXTRA_HOSTS=()
fi

failures=0

check_follow_200() {
  local url=$1
  local label=$2
  local code size
  # Follow redirects and require a real 200 so we know the asset is reachable.
  code=$(curl -sS -L -o /dev/null -w "%{http_code}" "$url" || echo "000")
  size=$(curl -sS -L -o /dev/null -w "%{size_download}" "$url" || echo "0")
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
    code=$(curl -sS -L -o /dev/null -w "%{http_code}" "$url" || echo "000")
    size=$(curl -sS -L -o /dev/null -w "%{size_download}" "$url" || echo "0")
    if [[ "$code" == "200" && "$size" -gt 0 ]]; then
      printf "✓ %s (200 via %s, %s bytes)\n" "$label" "$url" "$size"
      ok=1
      break
    fi
  done
  if [[ "$ok" == "0" ]]; then
    printf "✗ %s (no working URL)\n" "$label" >&2
    for url in "$@"; do
      code=$(curl -sS -L -o /dev/null -w "%{http_code}" "$url" || echo "000")
      size=$(curl -sS -L -o /dev/null -w "%{size_download}" "$url" || echo "0")
      printf "  - %s (%s, %s bytes)\n" "$url" "$code" "$size" >&2
    done
    failures=$((failures + 1))
  fi
}

check_http() {
  local url=$1
  local label=$2
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$url" || echo "000")
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
  body=$(curl -sS -L "$url" || true)
  if echo "$body" | grep -q "$needle"; then
    printf "✓ %s\n" "$label"
  else
    printf "✗ %s (missing '%s')\n" "$label" "$needle" >&2
    failures=$((failures + 1))
  fi
}

check_css_fonts() {
  local url=$1
  local label=$2
  local css
  css="$(curl -sS -L "$url" || true)"
  # Font-face URLs are fingerprinted (e.g. Poppins-Regular.<hash>.woff2), so match
  # the base name and extension rather than an exact filename.
  if echo "$css" | grep -Eq 'font-family:[[:space:]]*"Poppins"' \
    && echo "$css" | grep -Eq 'font-family:[[:space:]]*"Lato"' \
    && echo "$css" | grep -Eq 'Poppins-Regular[^"]*\.woff2' \
    && echo "$css" | grep -Eq 'Lato-Regular[^"]*\.woff2' \
    && echo "$css" | grep -Eq '\\.mereka-footer[[:space:]]*\\{' \
    && echo "$css" | grep -Eq '\\.mereka-footer[[:space:]]+\\.footer-brand[[:space:]]+img'; then
    printf "✓ %s\n" "$label"
  else
    printf "✗ %s (missing Poppins/Lato font-face wiring or footer CSS)\n" "$label" >&2
    failures=$((failures + 1))
  fi
}

check_homepage_brand_fonts() {
  local base_domain=$1
  local label=$2
  local html css_path override_css

  html="$(curl -sS -L "https://${base_domain}/" || true)"

  # We load brand overrides via comprehensive theme hook `head-extra.html`.
  css_path="$(printf '%s' "$html" | rg -o '/static/mereka/css/mereka-overrides[^"]*\.css' | head -n 1 || true)"
  if [[ -z "$css_path" ]]; then
    printf "✗ %s (missing Mereka override CSS link in homepage HTML)\n" "$label" >&2
    failures=$((failures + 1))
    return
  fi

  override_css="https://${base_domain}${css_path}"
  check_css_fonts "$override_css" "$label (override CSS wiring)"
}

check_homepage_brand_logo() {
  local base_domain=$1
  local label=$2
  local html logo_path logo_url code size
  local theming_effective_url

  html="$(curl -sS -L "https://${base_domain}/" || true)"
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
  theming_effective_url="$(curl -sS -L -o /dev/null -w "%{url_effective}" "https://${base_domain}/theming/asset/mereka/images/logo-horizontal.png" || true)"
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

  code=$(curl -sS -L -o /dev/null -w "%{http_code}" "$logo_url" || echo "000")
  size=$(curl -sS -L -o /dev/null -w "%{size_download}" "$logo_url" || echo "0")
  if [[ "$code" == "200" && "$size" -gt 2048 ]]; then
    printf "✓ %s\n" "$label"
  else
    printf "✗ %s (logo unreachable or too small)\n" "$label" >&2
    printf "  logo_url: %s\n" "$logo_url" >&2
    printf "  http: %s size: %s\n" "$code" "$size" >&2
    failures=$((failures + 1))
  fi
}

echo "Branding verification ($ENVIRONMENT) for ${BASE_DOMAIN}..."
echo ""

# HTML branding checks
check_contains "https://${BASE_DOMAIN}/" "LMS homepage includes 'Mereka Academy'" "Mereka Academy"
check_contains "https://studio.${BASE_DOMAIN}/" "Studio page includes 'Mereka'" "Mereka"
check_http "https://apps.${BASE_DOMAIN}/authn/login" "MFE login reachable"

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

# Homepage must actually be using brand logo content (not stock Open edX).
check_homepage_brand_logo "${BASE_DOMAIN}" "Homepage logo matches brand assets"

for host in "${EXTRA_HOSTS[@]}"; do
  check_contains "https://${host}/" "Microsite ${host} includes 'Mereka'" "Mereka"
done

echo ""
if [[ $failures -gt 0 ]]; then
  echo "${failures} branding checks failed." >&2
  exit 1
fi

echo "All branding checks passed."
