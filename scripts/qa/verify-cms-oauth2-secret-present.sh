#!/usr/bin/env bash
# @covers AC-012
# @spec: secrets-management_spec.md
# Verify Studio (CMS) edx-oauth2 client secret is present in the running pods.
#
# This catches a common failure mode where Studio login 500s on `/complete/edx-oauth2/`
# because `CMS_SOCIAL_AUTH_EDX_OAUTH2_SECRET` is empty/missing.
#
# This script never prints secret values.
#
# Usage:
#   ./scripts/qa/verify-cms-oauth2-secret-present.sh --context <kube_context>
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

KUBE_CONTEXT="${KUBE_CONTEXT:-$K8S_CONTEXT}"
NAMESPACE="${NAMESPACE:-$K8S_NAMESPACE}"

usage() {
  cat <<EOF
Usage: $0 [--context <kube_context>] [--namespace <ns>]

Env:
  KUBE_CONTEXT  Kubernetes context (default: scripts/shared/config.sh: K8S_CONTEXT)
  NAMESPACE     Namespace (default: scripts/shared/config.sh: K8S_NAMESPACE)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      KUBE_CONTEXT="${2:-}"; shift 2 ;;
    --namespace)
      NAMESPACE="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "${KUBE_CONTEXT:-}" ]]; then
  echo "Missing --context / KUBE_CONTEXT" >&2
  exit 1
fi

if [[ -z "${NAMESPACE:-}" ]]; then
  echo "Missing --namespace / NAMESPACE" >&2
  exit 1
fi

check_deploy() {
  local deploy="$1"
  kubectl --context "$KUBE_CONTEXT" -n "$NAMESPACE" exec "deploy/${deploy}" -- python3 - <<'PY'
import os
import sys
v = (os.environ.get("CMS_SOCIAL_AUTH_EDX_OAUTH2_SECRET", "") or "").strip()
print("present", bool(v))
sys.exit(0 if v else 1)
PY
}

echo "Context: $KUBE_CONTEXT"
echo "Namespace: $NAMESPACE"

echo "Checking CMS oauth secret presence (deploy/cms)..."
check_deploy "cms"

echo "Checking CMS oauth secret presence (deploy/cms-worker)..."
check_deploy "cms-worker"

echo "OK"

