#!/usr/bin/env bash
# @covers AC-009
# @spec: multi-site-domains_spec.md
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
#   OIDC_PROVIDER_DISPLAY_NAME="Sign in with Mereka"
#   VERIFY_OIDC_DISPLAY_NAME=1
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
ENVIRONMENT="auto" # auto | prod | dev | staging

# If true, allow an empty domain list (not recommended).
ALLOW_EMPTY_DOMAINS="${ALLOW_EMPTY_DOMAINS:-0}"
OIDC_PROVIDER_DISPLAY_NAME="${OIDC_PROVIDER_DISPLAY_NAME:-Sign in with Mereka}"
VERIFY_OIDC_DISPLAY_NAME="${VERIFY_OIDC_DISPLAY_NAME:-1}"

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -n, --namespace NAMESPACE   K8s namespace (default: $NAMESPACE)
  -c, --context CONTEXT       Kube context to target (repeatable). If omitted, uses:
                              ${DEFAULT_CONTEXTS[*]}
  --env {auto|prod|dev|staging}
                              Which domain set to verify per context (default: $ENVIRONMENT)
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
  # If caller explicitly scopes env, only target the matching default context(s).
  # This avoids accidentally verifying prod domains against a dev kind cluster (or vice versa).
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    CONTEXTS=("gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster")
  elif [[ "$ENVIRONMENT" == "dev" ]]; then
    CONTEXTS=("kind-dev")
  elif [[ "$ENVIRONMENT" == "staging" ]]; then
    CONTEXTS=("rke2-nonprod")
  else
    CONTEXTS=("${DEFAULT_CONTEXTS[@]}")
  fi
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

  if [[ "$env_for_ctx" != "prod" && "$env_for_ctx" != "dev" && "$env_for_ctx" != "staging" ]]; then
    echo "Invalid --env value: $ENVIRONMENT (expected auto|prod|dev|staging)" >&2
    exit 1
  fi

  DOMAINS=()
  if [[ "$env_for_ctx" == "prod" ]]; then
    DOMAINS=("$LMS_DOMAIN" "$BIJI_DOMAIN" "$SKILLOURFUTURE_DOMAIN")
  elif [[ "$env_for_ctx" == "staging" ]]; then
    DOMAINS=("$STAGING_LMS_DOMAIN")
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
  kubectl --context "$ctx" exec -i -n "$NAMESPACE" deploy/lms -- env \
    DOMAINS_CSV="$DOMAINS_CSV" \
    OIDC_PROVIDER_DISPLAY_NAME="$OIDC_PROVIDER_DISPLAY_NAME" \
    VERIFY_OIDC_DISPLAY_NAME="$VERIFY_OIDC_DISPLAY_NAME" \
    bash -lc 'python - <<PY
import os
import django
django.setup()

from django.contrib.sites.models import Site
from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig

domains = [d.strip() for d in os.environ.get("DOMAINS_CSV", "").split(",") if d.strip()]
domains = list(dict.fromkeys(domains))  # preserve order, de-dupe
if not domains:
    raise SystemExit("DOMAINS_CSV is empty; refusing to verify nothing.")
expected_display_name = os.environ.get("OIDC_PROVIDER_DISPLAY_NAME", "Sign in with Mereka")
verify_display_name = os.environ.get("VERIFY_OIDC_DISPLAY_NAME", "1") == "1"

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
    secret = ""
    try:
        secret = latest.get_setting("SECRET") or ""
    except Exception:
        secret = ""
    if not secret:
        return False, f"latest oidc provider config resolves empty secret (id={latest.id})"
    if verify_display_name and (latest.name or "") != expected_display_name:
        return False, (
            f"latest oidc provider display name mismatch (id={latest.id} "
            f"got={latest.name!r} expected={expected_display_name!r})"
        )
    return True, (
        f"OK (latest_id={latest.id} total={qs.count()} "
        f"secret_len={len(secret)} display_name={latest.name!r})"
    )

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
