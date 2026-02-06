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

echo "Branding verification ($ENVIRONMENT) for ${BASE_DOMAIN}..."
echo ""

# HTML branding checks
check_contains "https://${BASE_DOMAIN}/" "LMS homepage includes 'Mereka Academy'" "Mereka Academy"
check_contains "https://studio.${BASE_DOMAIN}/" "Studio page includes 'Mereka'" "Mereka"
check_http "https://apps.${BASE_DOMAIN}/authn/login" "MFE login reachable"

# Asset checks (theme assets)
check_any_follow_200 "Logo asset (logo.png)" \
  "https://${BASE_DOMAIN}/theming/asset/images/logo.png" \
  "https://${BASE_DOMAIN}/static/mereka/images/logo.png"
check_any_follow_200 "Logo asset (logo-horizontal.png)" \
  "https://${BASE_DOMAIN}/theming/asset/images/logo-horizontal.png" \
  "https://${BASE_DOMAIN}/static/mereka/images/logo-horizontal.png"
check_any_follow_200 "Favicon asset (favicon.ico)" \
  "https://${BASE_DOMAIN}/theming/asset/images/favicon.ico" \
  "https://${BASE_DOMAIN}/static/mereka/images/favicon.ico"

# Font checks (critical for brand typography)
check_any_follow_200 "Font asset (Poppins-Regular.woff2)" \
  "https://${BASE_DOMAIN}/theming/asset/fonts/Poppins-Regular.woff2" \
  "https://${BASE_DOMAIN}/static/mereka/fonts/Poppins-Regular.woff2"
check_any_follow_200 "Font asset (Lato-Regular.woff2)" \
  "https://${BASE_DOMAIN}/theming/asset/fonts/Lato-Regular.woff2" \
  "https://${BASE_DOMAIN}/static/mereka/fonts/Lato-Regular.woff2"

for host in "${EXTRA_HOSTS[@]}"; do
  check_contains "https://${host}/" "Microsite ${host} includes 'Mereka'" "Mereka"
done

echo ""
if [[ $failures -gt 0 ]]; then
  echo "${failures} branding checks failed." >&2
  exit 1
fi

echo "All branding checks passed."
