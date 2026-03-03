#!/usr/bin/env bash
# Audit cluster capacity signals that commonly block enterprise API desired replicas.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

NAMESPACE="${NAMESPACE:-${K8S_NAMESPACE:-mereka-lms}}"
NAMESPACE_PROD="${NAMESPACE_PROD:-${K8S_NAMESPACE_PROD:-$NAMESPACE}}"
NAMESPACE_DEV="${NAMESPACE_DEV:-${K8S_NAMESPACE_DEV:-$NAMESPACE}}"
CONTEXT_PROD="${CONTEXT_PROD:-${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}}"
CONTEXT_DEV="${CONTEXT_DEV:-${K8S_CONTEXT_DEV:-${K8S_CONTEXT:-kind-dev}}}"
ENV_NAME=""
KUBE_CONTEXT=""
NAMESPACE_OVERRIDE=""

usage() {
  cat <<'EOF'
Usage: audit-enterprise-capacity-pressure.sh [--env <prod|dev>] [--context <kubectl-context>]

Examples:
  ./scripts/qa/audit-enterprise-capacity-pressure.sh --env prod
  ./scripts/qa/audit-enterprise-capacity-pressure.sh --context kind-dev
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="${2:-}"
      shift 2
      ;;
    --context)
      KUBE_CONTEXT="${2:-}"
      shift 2
      ;;
    --namespace)
      NAMESPACE="${2:-}"
      NAMESPACE_OVERRIDE="$NAMESPACE"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$ENV_NAME" ]]; then
  case "$ENV_NAME" in
    prod)
      KUBE_CONTEXT="$CONTEXT_PROD"
      [[ -z "$NAMESPACE_OVERRIDE" ]] && NAMESPACE="$NAMESPACE_PROD"
      ;;
    dev)
      KUBE_CONTEXT="$CONTEXT_DEV"
      [[ -z "$NAMESPACE_OVERRIDE" ]] && NAMESPACE="$NAMESPACE_DEV"
      ;;
    *)
      echo "Invalid --env: $ENV_NAME (expected prod|dev)" >&2
      exit 1
      ;;
  esac
fi

KCTX=()
if [[ -n "$KUBE_CONTEXT" ]]; then
  KCTX=(--context "$KUBE_CONTEXT")
fi

echo "=== Enterprise Capacity Pressure Audit ==="
echo "Namespace: $NAMESPACE"
if [[ -n "$KUBE_CONTEXT" ]]; then
  echo "Context: $KUBE_CONTEXT"
fi
echo

echo "--- Enterprise deployment desired vs ready ---"
kubectl "${KCTX[@]}" -n "$NAMESPACE" get deploy \
  enterprise-catalog enterprise-catalog-worker enterprise-access enterprise-access-worker \
  enterprise-subsidy enterprise-admin-portal enterprise-learner-portal 2>/dev/null \
  -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,READY:.status.readyReplicas
echo

echo "--- Pending enterprise pods and scheduling reasons ---"
PENDING_PODS="$(kubectl "${KCTX[@]}" -n "$NAMESPACE" get pods -l app.kubernetes.io/component=enterprise \
  --field-selector=status.phase=Pending -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)"
if [[ -z "$PENDING_PODS" ]]; then
  echo "No pending enterprise pods."
else
  for pod in $PENDING_PODS; do
    echo "[$pod]"
    kubectl "${KCTX[@]}" -n "$NAMESPACE" describe pod "$pod" \
      | awk '/FailedScheduling|Insufficient|No preemption victims|Warning/{print "  " $0}'
  done
fi
echo

echo "--- Node CPU request saturation (Allocated resources) ---"
for node in $(kubectl "${KCTX[@]}" get nodes -o jsonpath='{.items[*].metadata.name}'); do
  cpu_line="$(kubectl "${KCTX[@]}" describe node "$node" 2>/dev/null | awk '
    /Allocated resources:/ {capture=1; next}
    capture && /^  cpu[[:space:]]/ {print; exit}
    capture && /^Events:/ {exit}
  ')"
  if [[ -n "$cpu_line" ]]; then
    echo "$node: $cpu_line"
  fi
done
echo

if command -v jq >/dev/null 2>&1; then
  echo "--- Namespace CPU request totals (cores, descending) ---"
  kubectl "${KCTX[@]}" get pods -A -o json \
    | jq -r '
      .items[] |
      . as $pod |
      (
        ([.spec.containers[]?.resources.requests.cpu // "0"]
          | map(if test("m$") then (sub("m$";"")|tonumber/1000) else tonumber end)
          | add // 0) +
        ([.spec.initContainers[]?.resources.requests.cpu // "0"]
          | map(if test("m$") then (sub("m$";"")|tonumber/1000) else tonumber end)
          | max // 0)
      ) as $cpu |
      [$pod.metadata.namespace, ($cpu|tonumber)] | @tsv' \
    | awk '{sum[$1]+=$2} END {for (ns in sum) printf "%s\t%.3f\n", ns, sum[ns]}' \
    | sort -k2,2nr
else
  echo "jq not found; skipping namespace CPU aggregation."
fi
echo

echo "Audit complete."
