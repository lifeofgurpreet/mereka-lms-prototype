#!/usr/bin/env bash
# @covers AC-013
# @spec: k8s-deployment_spec.md
# Verify that core Services have non-empty Endpoints (i.e., traffic can route).
#
# Empty endpoints are one of the most common causes of "site down" incidents.
#
# Usage:
#   ./scripts/qa/verify-service-endpoints.sh
#   ./scripts/qa/verify-service-endpoints.sh --env prod
#   ./scripts/qa/verify-service-endpoints.sh --env dev
#   ./scripts/qa/verify-service-endpoints.sh --env staging
#   STRICT=1 ./scripts/qa/verify-service-endpoints.sh --env all
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="both" # prod|dev|staging|both|all
NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
NAMESPACE_PROD="${NAMESPACE_PROD:-${K8S_NAMESPACE_PROD:-$NAMESPACE}}"
NAMESPACE_DEV="${NAMESPACE_DEV:-${K8S_NAMESPACE_DEV:-$NAMESPACE}}"
NAMESPACE_STAGING="${NAMESPACE_STAGING:-${K8S_NAMESPACE_STAGING:-stg-mereka-lms}}"
CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-kind-dev}}}"
CONTEXT_STAGING="${CONTEXT_STAGING:-${K8S_CONTEXT_STAGING:-rke2-nonprod}}"
STRICT="${STRICT:-0}"

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/verify-service-endpoints.sh [--env prod|dev|staging|both|all] [--namespace NAMESPACE]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_SCOPE="${2:-}"; shift 2 ;;
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "staging" && "$ENV_SCOPE" != "both" && "$ENV_SCOPE" != "all" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

check_context() {
  local ctx="$1"
  local ns="$2"
  local failures=0

  # Only check services that exist in the namespace.
  local services=(
    caddy lms cms mfe
    discovery credentials ecommerce
    forum notes xqueue
    mysql mongodb redis smtp
    elasticsearch
  )

  echo "Context: $ctx"
  echo "Namespace: $ns"
  echo "Strict: $STRICT"

  for svc in "${services[@]}"; do
    if ! kubectl --context "$ctx" -n "$ns" get svc "$svc" >/dev/null 2>&1; then
      echo "  - $svc: <service missing> (skipped)"
      continue
    fi

    # endpoints can be "not found" transiently; treat as failure if strict.
    local subsets
    subsets="$(kubectl --context "$ctx" -n "$ns" get endpoints "$svc" -o jsonpath='{.subsets}' 2>/dev/null || true)"
    if [[ -z "$subsets" || "$subsets" == "[]" ]]; then
      echo "  - $svc: EMPTY" >&2
      failures=$((failures + 1))
    else
      # Print a small hint: port list.
      local ports
      ports="$(kubectl --context "$ctx" -n "$ns" get endpoints "$svc" -o jsonpath='{range .subsets[*].ports[*]}{.port}{" "}{end}' 2>/dev/null || true)"
      ports="$(echo "$ports" | awk '{$1=$1;print}')"
      echo "  - $svc: OK (ports=${ports:-?})"
    fi
  done

  if [[ "$failures" -gt 0 ]]; then
    if [[ "$STRICT" == "1" ]]; then
      echo "FAILED ($failures services have empty endpoints)" >&2
      return 1
    fi
    echo "WARN ($failures services have empty endpoints)" >&2
  else
    echo "OK"
  fi

  return 0
}

rc=0
if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  check_context "$CONTEXT_PROD" "$NAMESPACE_PROD" || rc=1
fi
if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  check_context "$CONTEXT_DEV" "$NAMESPACE_DEV" || rc=1
fi
if [[ "$ENV_SCOPE" == "staging" || "$ENV_SCOPE" == "all" ]]; then
  check_context "$CONTEXT_STAGING" "$NAMESPACE_STAGING" || rc=1
fi

exit "$rc"
