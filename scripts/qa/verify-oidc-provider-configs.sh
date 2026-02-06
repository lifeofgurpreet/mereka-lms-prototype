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

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
  -n, --namespace NAMESPACE   K8s namespace (default: $NAMESPACE)
  -c, --context CONTEXT       Kube context to target (repeatable). If omitted, uses:
                              ${DEFAULT_CONTEXTS[*]}
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
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ ${#CONTEXTS[@]} -eq 0 ]]; then
  CONTEXTS=("${DEFAULT_CONTEXTS[@]}")
fi

failures=0

for ctx in "${CONTEXTS[@]}"; do
  log "[$ctx] Verifying OIDC provider configs in LMS (namespace=$NAMESPACE)"
  kubectl --context "$ctx" exec -i -n "$NAMESPACE" deploy/lms -- bash -lc 'python - <<PY
import django
django.setup()

from django.conf import settings
from django.contrib.sites.models import Site
from common.djangoapps.third_party_auth.models import OAuth2ProviderConfig

domains = []
for name in ("MEREKA_LMS_DOMAIN", "MEREKA_BIJI_DOMAIN", "MEREKA_SKILLOURFUTURE_DOMAIN"):
    dom = getattr(settings, name, None)
    if dom:
        domains.append(dom)

domains = [d.strip() for d in domains if str(d).strip()]
domains = list(dict.fromkeys(domains))  # preserve order, de-dupe

def check(domain: str) -> tuple[bool, str]:
    site = Site.objects.filter(domain=domain).first()
    if not site:
        return False, "Site missing"
    qs = OAuth2ProviderConfig.objects.filter(site=site, backend_name="oidc", enabled=True, visible=True)
    if not qs.exists():
        total = OAuth2ProviderConfig.objects.filter(site=site, backend_name="oidc").count()
        return False, f"oidc enabled/visible missing (total oidc records={total})"
    return True, f"OK (count={qs.count()})"

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

