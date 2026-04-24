#!/usr/bin/env bash
# @covers AC-003
# @spec: k8s-deployment_spec.md
# Post-deployment verification wrapper.
#
# Intent: provide one command that an operator can run after a rollout to sanity-check
# core runtime health without duplicating the repo's QA scripts.
#
# This script:
# - checks pod + deployment readiness
# - checks rollouts for core deployments (lms/cms/caddy)
# - runs public auth surface checks (no cluster access needed)
#
# Notes:
# - Does not print secret values.
# - Uses existing QA gates where possible.
#
# Usage:
#   ./scripts/infra/verify-deployment.sh --env prod
#   ./scripts/infra/verify-deployment.sh --env dev --context kind-dev
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_NAME="prod" # prod|dev
NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
CONTEXT="${CONTEXT:-${K8S_CONTEXT:-rke2-prod}}"

usage() {
  cat <<'USAGE' >&2
Usage: ./scripts/infra/verify-deployment.sh [--env prod|dev] [--namespace NAMESPACE] [--context CONTEXT]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_NAME="${2:-}"; shift 2 ;;
    --namespace) NAMESPACE="${2:-}"; shift 2 ;;
    --context) CONTEXT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$ENV_NAME" != "prod" && "$ENV_NAME" != "dev" ]]; then
  echo "Invalid --env: $ENV_NAME (expected prod|dev)" >&2
  exit 1
fi

echo "Verify deployment"
echo "  env: $ENV_NAME"
echo "  context: $CONTEXT"
echo "  namespace: $NAMESPACE"
echo ""

echo "==> Kubernetes readiness"
kubectl --context "$CONTEXT" -n "$NAMESPACE" get pods
kubectl --context "$CONTEXT" -n "$NAMESPACE" get deploy
echo ""

for d in lms cms caddy; do
  echo "==> rollout status deploy/$d"
  kubectl --context "$CONTEXT" -n "$NAMESPACE" rollout status "deploy/$d" --timeout=5m
done
echo ""

echo "==> Public auth surface checks"
if [[ "$ENV_NAME" == "prod" ]]; then
  ./scripts/qa/verify-auth-surfaces.sh prod
else
  ./scripts/qa/verify-auth-surfaces.sh dev
fi
echo ""

echo "OK"

