#!/usr/bin/env bash
# Enforce baseline Cloudflare security settings (TLS min version, HTTPS rewrites, HSTS).
# Requires: CLOUDFLARE_ZONE_ID and either CLOUDFLARE_API_TOKEN or
#           CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_BASE="https://api.cloudflare.com/client/v4"
ZONE_ID=${CLOUDFLARE_ZONE_ID:?"Set CLOUDFLARE_ZONE_ID"}

DRY_RUN=${DRY_RUN:-false}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  AUTH_HEADERS=("-H" "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
elif [[ -n "${CLOUDFLARE_EMAIL:-}" && -n "${CLOUDFLARE_API_KEY:-}" ]]; then
  AUTH_HEADERS=("-H" "X-Auth-Email: ${CLOUDFLARE_EMAIL}" "-H" "X-Auth-Key: ${CLOUDFLARE_API_KEY}")
else
  echo "Provide CLOUDFLARE_API_TOKEN or CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY" >&2
  exit 1
fi

patch_setting() {
  local setting=$1
  local payload=$2

  echo "[PATCH] $setting"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  payload: $payload"
    return 0
  fi

  response=$(curl -fsSL -X PATCH "$API_BASE/zones/$ZONE_ID/settings/$setting" \
    -H "Content-Type: application/json" \
    "${AUTH_HEADERS[@]}" \
    --data "$payload") || {
      echo "  ! Request failed" >&2
      echo "$response" >&2
      return 1
    }

  if [[ $(echo "$response" | jq -r '.success') != "true" ]]; then
    echo "  ! API error: $response" >&2
    return 1
  fi
}

patch_setting "ssl" '{"value":"strict"}'
patch_setting "min_tls_version" '{"value":"1.2"}'
patch_setting "always_use_https" '{"value":"on"}'
patch_setting "automatic_https_rewrites" '{"value":"on"}'
patch_setting "security_header" '{"value":{"strict_transport_security":{"enabled":true,"max_age":31536000,"include_subdomains":true,"preload":false,"nosniff":true}}}'

echo "Cloudflare zone hardening complete."
