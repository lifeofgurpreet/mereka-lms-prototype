#!/usr/bin/env bash
# Synthetic health checks for public endpoints (prod + dev)
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
  EXTRA_HOSTS=("$SKILLOURFUTURE_DOMAIN" "$BIJI_DOMAIN" "$BIJI_STUDIO_DOMAIN")
else
  BASE_DOMAIN="$DEV_LMS_DOMAIN"
  EXTRA_HOSTS=()
fi

urls=(
  "https://${BASE_DOMAIN}/"
  "https://preview.${BASE_DOMAIN}/"
  "https://studio.${BASE_DOMAIN}/"
  "https://apps.${BASE_DOMAIN}/authn/login"
  "https://apps.${BASE_DOMAIN}/account/"
  "https://apps.${BASE_DOMAIN}/learner-dashboard/"
  "https://discovery.${BASE_DOMAIN}/health/"
  "https://ecommerce.${BASE_DOMAIN}/dashboard/"
  "https://credentials.${BASE_DOMAIN}/health/"
  "https://notes.${BASE_DOMAIN}/"
  "https://forum.${BASE_DOMAIN}/heartbeat"
)

for host in "${EXTRA_HOSTS[@]}"; do
  urls+=("https://${host}/")
done

if [[ "$ENVIRONMENT" == "prod" ]]; then
  # Biji MFEs live on a dedicated hostname.
  urls+=("https://${BIJI_MFE_DOMAIN}/authn/login")
  urls+=("https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1")
fi

failures=0

is_ok() {
  local url=$1
  local code=$2

  # Notes API returns 405 on GET / but still indicates service reachability.
  if [[ "$url" == *"notes."* && "$code" == "405" ]]; then
    return 0
  fi

  if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
    return 0
  fi

  return 1
}

check_url() {
  local url=$1
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$url" || echo "000")

  if is_ok "$url" "$code"; then
    printf "✓ %s (%s)\n" "$url" "$code"
  else
    printf "✗ %s (%s)\n" "$url" "$code" >&2
    failures=$((failures + 1))
  fi
}

printf "Running %s checks for %s...\n" "${#urls[@]}" "$ENVIRONMENT"
for url in "${urls[@]}"; do
  check_url "$url"
done

if [[ $failures -gt 0 ]]; then
  echo "${failures} checks failed." >&2
  exit 1
fi

if [[ "${CHECK_CERTS:-0}" == "1" && "$ENVIRONMENT" == "prod" ]]; then
  echo "Running certificate SAN checks..."
  "$SCRIPT_DIR/../infra/check-cert-sans.sh"
fi

if [[ "${CHECK_BRANDING:-0}" == "1" ]]; then
  echo "Running branding checks..."
  "$SCRIPT_DIR/verify-public-branding.sh" "$ENVIRONMENT"
fi

echo "All checks passed."
