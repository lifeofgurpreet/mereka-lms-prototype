#!/usr/bin/env bash
# Verify OIDC provider configs exist/enabled for the current LMS sites.
#
# Why this exists:
# - If `OAuth2ProviderConfig` for backend `oidc` is missing/disabled for a site,
#   `/auth/login/oidc/` can 500 with:
#     "Can't fetch setting of a disabled backend/provider."
#
# This script is "internal" (needs kubectl access) but contains no secrets and
# is safe to run during ops / hardening.
#
# Usage:
#   ./scripts/qa/verify-oidc-provider-configs.sh
#   ./scripts/qa/verify-oidc-provider-configs.sh --verify-only-prod
#
# Env:
#   NAMESPACE=mereka-lms
#   CONTEXTS="ctx1 ctx2"
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"

DEFAULT_CONTEXTS=(
  "gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
  "kind-dev"
)

CONTEXTS=()
ENVIRONMENT="auto" # auto | prod | dev

# If true, allow an empty domain list (not recommended).
ALLOW_EMPTY_DOMAINS="${ALLOW_EMPTY_DOMAINS:-0}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -n, --namespace NAMESPACE   K8s namespace (default: $NAMESPACE)
  -c, --context CONTEXT       Kube context to target (repeatable). If omitted, uses:
                              ${DEFAULT_CONTEXTS[*]}
  --env {auto|prod|dev}       Which domain set to verify per context (default: $ENVIRONMENT)
  -h, --help                  Show help
EOF
  exit 1
}

log() {
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NAMESPACE="$2"; shift 2 ;;
    -c|--context) CONTEXTS+=("$2"); shift 2 ;;
    --env) ENVIRONMENT="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ ${#CONTEXTS[@]} -eq 0 ]]; then
  CONTEXTS=("${DEFAULT_CONTEXTS[@]}")
fi

failures=0

for ctx in "${CONTEXTS[@]}"; do
  env_for_ctx="$ENVIRONMENT"
  if [[ "$env_for_ctx" == "auto" ]]; then
    if [[ "$ctx" == kind* ]]; then
      env_for_ctx="dev"
    else
      env_for_ctx="prod"
    fi
  fi

  if [[ "$env_for_ctx" != "prod" && "$env_for_ctx" != "dev" ]]; then
    echo "Invalid --env value: $ENVIRONMENT (expected auto|prod|dev)" >&2
    exit 1
  fi

  DOMAINS=()
  if [[ "$env_for_ctx" == "prod" ]]; then
    DOMAINS=("$LMS_DOMAIN" "$BIJI_DOMAIN" "$SKILLOURFUTURE_DOMAIN")
  else
    DOMAINS=("$DEV_LMS_DOMAIN")
  fi

  # Trim empties and de-dupe while preserving order
  DOMAINS_CSV="$(printf "%s\n" "${DOMAINS[@]}" | awk 'NF{print}' | awk '!seen[$0]++' | paste -sd, -)"
  if [[ -z "${DOMAINS_CSV:-}" && "$ALLOW_EMPTY_DOMAINS" != "1" ]]; then
    echo "No domains resolved for ctx=$ctx env=$env_for_ctx (set ALLOW_EMPTY_DOMAINS=1 to bypass)" >&2
    failures=$((failures + 1))
    continue
  fi

  log "[$ctx] Verifying OIDC provider configs in LMS (namespace=$NAMESPACE)"
  kubectl --context "$ctx" exec -i -n "$NAMESPACE" deploy/lms -- env DOMAINS_CSV="$DOMAINS_CSV" bash -lc 'python - <<PY
import os
import django
django.setup()

from django.contrib.sites.models import Site
from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig

domains = [d.strip() for d in os.environ.get("DOMAINS_CSV", "").split(",") if d.strip()]
domains = list(dict.fromkeys(domains))  # preserve order, de-dupe
if not domains:
    raise SystemExit("DOMAINS_CSV is empty; refusing to verify nothing.")

def check(domain: str) -> tuple[bool, str]:
    site = Site.objects.filter(domain=domain).first()
    if not site:
        return False, "Site missing"
    qs = OAuth2ProviderConfig.objects.filter(site=site, backend_name="oidc").order_by("-change_date", "-id")
    if not qs.exists():
        return False, "oidc provider config missing"
    latest = qs.first()
    assert latest is not None
    if not (latest.enabled and latest.visible):
        return False, f"latest oidc provider config is disabled/hidden (id={latest.id} enabled={latest.enabled} visible={latest.visible})"
    return True, f"OK (latest_id={latest.id} total={qs.count()})"

for d in domains:
    ok, msg = check(d)
    print(f"{d}\\t{msg}" if ok else f"{d}\\tFAIL: {msg}")

PY' | awk -v ctx="$ctx" '
  $2 ~ /^FAIL:/ {print "[ "ctx" ] ✗ " $0; exit_code=1; next}
  {print "[ "ctx" ] ✓ " $0}
  END {exit exit_code+0}
  '
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    failures=$((failures + 1))
  fi
done

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "FAILED ($failures context(s) have missing/disabled OIDC provider configs)" >&2
  exit 1
fi

echo ""
echo "OK"
