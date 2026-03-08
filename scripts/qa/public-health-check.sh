#!/usr/bin/env bash
# @covers AC-020
# @spec: disaster-recovery-business-continuity_spec.md
# Synthetic health checks for public endpoints (prod + dev)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

ENVIRONMENT="${1:-prod}"
CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-kind-dev}}}"
NAMESPACE_PROD="${NAMESPACE_PROD:-${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}}"
NAMESPACE_DEV="${NAMESPACE_DEV:-${K8S_NAMESPACE_DEV:-${K8S_NAMESPACE:-mereka-lms}}}"

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
  "https://apps.${BASE_DOMAIN}/account/settings"
  "https://apps.${BASE_DOMAIN}/learner-dashboard/"
  "https://discovery.${BASE_DOMAIN}/health/"
  "https://ecommerce.${BASE_DOMAIN}/dashboard/"
  # Webhook endpoint is POST-only; 405 on GET still indicates routing is correct.
  "https://ecommerce.${BASE_DOMAIN}/api/v2/webhooks/stripe/"
  "https://credentials.${BASE_DOMAIN}/health/"
  "https://notes.${BASE_DOMAIN}/"
  # Open edX forum (cs_comments_service) uses /heartbeat for health.
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
DEV_FORUM_HINT_PRINTED=0

is_ok() {
  local url=$1
  local code=$2

  # Notes API returns 405 on GET / but still indicates service reachability.
  if [[ "$url" == *"notes."* && "$code" == "405" ]]; then
    return 0
  fi

  # Ecommerce Stripe webhook endpoint is POST-only. A 405 indicates correct routing.
  if [[ "$url" == *"/api/v2/webhooks/stripe/" && "$code" == "405" ]]; then
    return 0
  fi

  if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
    return 0
  fi

  return 1
}

dev_forum_diagnostics() {
  # Only run once per script invocation.
  if [[ "$DEV_FORUM_HINT_PRINTED" == "1" ]]; then
    return
  fi
  DEV_FORUM_HINT_PRINTED=1

  echo "" >&2
  echo "Dev forum health check failed. Common cause: MongoDB Atlas allowlist drift (dev VPS egress IP not allowed)." >&2
  echo "Docs:" >&2
  echo "  - docs/MONGODB_ATLAS.md" >&2
  echo "  - docs/runbooks/operations/TROUBLESHOOTING.md (forum/Atlas sections)" >&2

  if ! command -v kubectl >/dev/null 2>&1; then
    return
  fi

  local ctx="$CONTEXT_DEV"
  local ns="$NAMESPACE_DEV"

  if ! kubectl --context "$ctx" get deploy/forum -n "$ns" >/dev/null 2>&1; then
    echo "Tip: set CONTEXT_DEV/K8S_CONTEXT_DEV to inspect forum logs for your dev cluster." >&2
    return
  fi

  # Heuristic log scan (no secrets printed). We don't dump logs to stdout/stderr
  # to keep CI output minimal; we only surface a directional hint.
  local tail
  tail="$(kubectl --context "$ctx" logs -n "$ns" deploy/forum --tail=200 2>/dev/null || true)"
  if command -v rg >/dev/null 2>&1; then
    if [[ -n "$tail" ]] && echo "$tail" | rg -qi "(atlas|mongo|mongodb|srv|getaddrinfo|ENOTFOUND|ECONN|EHOST|timed out|connection refused|not authorized|Authentication failed)"; then
      echo "Forum logs indicate Mongo/Atlas connectivity/auth errors. Check Atlas allowlist + DB user permissions." >&2
    fi
  fi
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

    # Dev forum failures are almost always Atlas allowlist drift; print an actionable hint.
    if [[ "$ENVIRONMENT" == "dev" && "$url" == *"forum."*"/heartbeat" ]]; then
      dev_forum_diagnostics
    fi
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
