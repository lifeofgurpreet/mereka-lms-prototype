#!/usr/bin/env bash
# @covers AC-012
# @spec: secrets-management_spec.md
# Verify that MEREKA_PLATFORM_ADMIN_EMAILS is set correctly on core deployments.
#
# This does not mutate anything. It checks the runtime backstop allowlist that
# prevents admin permissions from drifting between enforcement runs.
#
# Usage:
#   ./scripts/qa/verify-platform-admin-env.sh
#   ./scripts/qa/verify-platform-admin-env.sh --env prod
#   ./scripts/qa/verify-platform-admin-env.sh --env dev
#   ./scripts/qa/verify-platform-admin-env.sh --env staging
#   REQUIRED_ADMINS_CSV="a@x.com,b@y.com" ./scripts/qa/verify-platform-admin-env.sh --env all
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
REQUIRED_ADMINS_CSV="${REQUIRED_ADMINS_CSV:-gurpreet@biji-biji.com,malasari@mereka.my}"

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/verify-platform-admin-env.sh [--env prod|dev|staging|both|all] [--namespace NAMESPACE]
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

required=()
IFS=',' read -r -a required <<<"$REQUIRED_ADMINS_CSV"
required_norm=()
for e in "${required[@]}"; do
  e="$(echo "${e}" | awk '{gsub(/^[ \t]+|[ \t]+$/, "", $0); print tolower($0)}')"
  [[ -n "$e" ]] && required_norm+=("$e")
done

if [[ ${#required_norm[@]} -eq 0 ]]; then
  echo "REQUIRED_ADMINS_CSV resolved to empty; refusing to run." >&2
  exit 1
fi

check_context() {
  local ctx="$1"
  local ns="$2"
  local failures=0
  local deployments=(lms cms discovery credentials ecommerce)

  echo "Context: $ctx"
  echo "Namespace: $ns"
  echo "Required: $(printf "%s," "${required_norm[@]}" | sed 's/,$//')"

  for d in "${deployments[@]}"; do
    local value
    value="$(kubectl --context "$ctx" -n "$ns" get deploy "$d" \
      -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="MEREKA_PLATFORM_ADMIN_EMAILS")].value}' 2>/dev/null || true)"
    value="${value:-}"
    local current_norm
    current_norm="$(echo "$value" | tr ',' '\n' | awk '{gsub(/^[ \t]+|[ \t]+$/, "", $0); print tolower($0)}' | awk 'NF' | sort -u | paste -sd, -)"
    echo "  - $d: ${current_norm:-<missing>}"

    if [[ -z "$current_norm" ]]; then
      failures=$((failures + 1))
      continue
    fi

    for req in "${required_norm[@]}"; do
      if ! echo ",$current_norm," | grep -qi ",${req},"; then
        echo "    ! missing required admin: $req" >&2
        failures=$((failures + 1))
      fi
    done
  done

  if [[ "$failures" -gt 0 ]]; then
    echo "FAILED ($failures mismatches)" >&2
    return 1
  fi

  echo "OK"
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
