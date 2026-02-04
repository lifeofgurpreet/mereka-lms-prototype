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
check_http "https://${BASE_DOMAIN}/theming/asset/images/logo.png" "Logo asset (logo.png)"
check_http "https://${BASE_DOMAIN}/theming/asset/images/logo-horizontal.png" "Logo asset (logo-horizontal.png)"
check_http "https://${BASE_DOMAIN}/theming/asset/images/favicon.ico" "Favicon asset (favicon.ico)"

for host in "${EXTRA_HOSTS[@]}"; do
  check_contains "https://${host}/" "Microsite ${host} includes 'Mereka'" "Mereka"
done

echo ""
if [[ $failures -gt 0 ]]; then
  echo "${failures} branding checks failed." >&2
  exit 1
fi

echo "All branding checks passed."
