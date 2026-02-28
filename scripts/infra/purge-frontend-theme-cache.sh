#!/usr/bin/env bash
# Purge Cloudflare cache entries for frontend branding/theme rollout paths.
# Default mode is dry-run (prints target URLs). Use --apply to execute.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/shared/config.sh
source "$REPO_ROOT/scripts/shared/config.sh"

API_BASE="https://api.cloudflare.com/client/v4"
ENVIRONMENT="prod"
APPLY=0
PURGE_EVERYTHING=0

usage() {
  cat <<'EOF'
Usage: purge-frontend-theme-cache.sh [options]

Options:
  --env <prod|dev>      Target environment domains (default: prod)
  --apply               Execute Cloudflare cache purge (default: dry-run)
  --purge-everything    Purge entire zone cache (high impact)
  -h, --help            Show this help

Required for --apply:
  CLOUDFLARE_ZONE_ID and either:
  - CLOUDFLARE_API_TOKEN
  - CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENVIRONMENT="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    --purge-everything)
      PURGE_EVERYTHING=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$ENVIRONMENT" in
  prod|dev) ;;
  *)
    echo "ERROR: --env must be prod or dev (got: $ENVIRONMENT)" >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  lms_domain="$LMS_DOMAIN"
  mfe_domain="$MFE_DOMAIN"
  discovery_domain="$DISCOVERY_DOMAIN"
else
  lms_domain="$DEV_LMS_DOMAIN"
  mfe_domain="$DEV_MFE_DOMAIN"
  discovery_domain="$DEV_DISCOVERY_DOMAIN"
fi

declare -a purge_urls=(
  "https://${mfe_domain}/authn/login"
  "https://${mfe_domain}/learner-dashboard/"
  "https://${mfe_domain}/account/settings"
  "https://${mfe_domain}/profile/u/"
  "https://${mfe_domain}/learning"
  "https://${mfe_domain}/api/mfe_config/v1"
  "https://${mfe_domain}/theme/core.min.css"
  "https://${mfe_domain}/theme/light.min.css"
  "https://${mfe_domain}/theme/mereka-brand.min.css"
  "https://${mfe_domain}/theme/mereka-brand-light.min.css"
  "https://${lms_domain}/"
  "https://${discovery_domain}/"
)

echo "=== Frontend Theme Cache Purge ==="
echo "Environment: $ENVIRONMENT"
echo "Mode: $([[ "$APPLY" -eq 1 ]] && echo "apply" || echo "dry-run")"
echo "Target URLs (${#purge_urls[@]}):"
for url in "${purge_urls[@]}"; do
  echo "  - $url"
done

if [[ "$APPLY" -ne 1 ]]; then
  echo ""
  echo "Dry-run complete. Re-run with --apply to execute Cloudflare purge."
  exit 0
fi

ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
if [[ -z "$ZONE_ID" ]]; then
  echo "ERROR: CLOUDFLARE_ZONE_ID is required for --apply" >&2
  exit 2
fi

declare -a auth_headers
if [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  auth_headers=("-H" "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}")
elif [[ -n "${CLOUDFLARE_EMAIL:-}" && -n "${CLOUDFLARE_API_KEY:-}" ]]; then
  auth_headers=("-H" "X-Auth-Email: ${CLOUDFLARE_EMAIL}" "-H" "X-Auth-Key: ${CLOUDFLARE_API_KEY}")
else
  echo "ERROR: Provide CLOUDFLARE_API_TOKEN or CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY" >&2
  exit 2
fi

if [[ "$PURGE_EVERYTHING" -eq 1 ]]; then
  payload='{"purge_everything":true}'
  echo ""
  echo "Applying full zone purge (purge_everything=true)..."
else
  files_json="$(printf '%s\n' "${purge_urls[@]}" | jq -R . | jq -s .)"
  payload="$(jq -cn --argjson files "$files_json" '{files:$files}')"
  echo ""
  echo "Applying URL-targeted purge..."
fi

response="$(
  curl -sS -X POST \
    "$API_BASE/zones/$ZONE_ID/purge_cache" \
    -H "Content-Type: application/json" \
    "${auth_headers[@]}" \
    --data "$payload"
)"

if [[ "$(echo "$response" | jq -r '.success // false')" != "true" ]]; then
  echo "ERROR: Cloudflare purge failed" >&2
  echo "$response" | jq . >&2 || echo "$response" >&2
  exit 1
fi

echo "Cloudflare purge succeeded."
echo "$response" | jq .
