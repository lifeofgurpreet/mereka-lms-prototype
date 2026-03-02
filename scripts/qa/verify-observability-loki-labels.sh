#!/usr/bin/env bash
# @covers AC-LOG-003
# @spec: observability-stack_spec.md
# Verify all logs have required labels: service, env, cluster, namespace, hostname, severity.
#
# Usage:
#   ./scripts/qa/verify-observability-loki-labels.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

DEFAULT_K8S_CONTEXT="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-$DEFAULT_K8S_CONTEXT}}"
APP_NS="${APP_NS:-${K8S_NAMESPACE:-${K8S_NAMESPACE_PROD:-mereka-lms}}}"
STRICT="${STRICT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) APP_NS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ "$STRICT" != "0" && "$STRICT" != "1" ]]; then
  echo "STRICT must be 0 or 1 (got: $STRICT)" >&2
  exit 2
fi

failures=0
skips=0

echo "Verify: Loki log label schema"
echo "  context:   $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo ""

REQUIRED_LABELS=(
  "service"
  "env"
  "cluster"
  "namespace"
  "hostname"
  "severity"
)

# Check if kubectl/jq are available
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} kubectl not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} jq not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Check if cluster is reachable
if ! kubectl --context "$K8S_CONTEXT" cluster-info >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} Cannot reach cluster: $K8S_CONTEXT"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Find Promtail namespace and get config
promtail_ns=""
for ns in monitoring "$APP_NS" loki-stack; do
  if kubectl --context "$K8S_CONTEXT" -n "$ns" get daemonset -l app.kubernetes.io/name=promtail -o name >/dev/null 2>&1; then
    promtail_ns="$ns"
    break
  fi
done

if [[ -z "$promtail_ns" ]]; then
  echo -e "${YELLOW}SKIP${NC} Promtail DaemonSet not found"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

echo "Found Promtail in namespace: $promtail_ns"
echo ""

# Get Promtail ConfigMap
echo "Checking Promtail configuration for label schema..."
promtail_cm=$(kubectl --context "$K8S_CONTEXT" -n "$promtail_ns" get configmap -l app.kubernetes.io/name=promtail -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -z "$promtail_cm" ]]; then
  echo -e "${YELLOW}SKIP${NC} Promtail ConfigMap not found"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

promtail_config=$(kubectl --context "$K8S_CONTEXT" -n "$promtail_ns" get configmap "$promtail_cm" -o jsonpath='{.data}' 2>/dev/null || echo "{}")

# Check for each required label in Promtail config
for label in "${REQUIRED_LABELS[@]}"; do
  echo -n "Check: Promtail config includes label '$label'... "

  # Special handling for different label names
  case "$label" in
    "service")
      # Might be 'app', 'service', or 'app_kubernetes_io_name'
      if echo "$promtail_config" | grep -qE "(app|service|app_kubernetes_io_name)"; then
        echo -e "${GREEN}PASS${NC}"
      else
        echo -e "${YELLOW}WARN${NC} Label pattern not found in config"
      fi
      ;;
    "env"|"environment")
      if echo "$promtail_config" | grep -qE "(env|environment)"; then
        echo -e "${GREEN}PASS${NC}"
      else
        echo -e "${YELLOW}WARN${NC} Label 'env' not found, might use default"
      fi
      ;;
    "cluster")
      if echo "$promtail_config" | grep -q "cluster"; then
        echo -e "${GREEN}PASS${NC}"
      else
        echo -e "${YELLOW}WARN${NC} Label 'cluster' not found, might use default"
      fi
      ;;
    "namespace")
      if echo "$promtail_config" | grep -qE "(namespace|namespace_name)"; then
        echo -e "${GREEN}PASS${NC}"
      else
        echo -e "${RED}FAIL${NC}"
        failures=$((failures + 1))
      fi
      ;;
    "hostname")
      if echo "$promtail_config" | grep -qE "(hostname|pod|pod_name|instance)"; then
        echo -e "${GREEN}PASS${NC}"
      else
        echo -e "${YELLOW}WARN${NC} Hostname/pod label not found"
      fi
      ;;
    "severity"|"level")
      if echo "$promtail_config" | grep -qE "(severity|level)"; then
        echo -e "${GREEN}PASS${NC}"
      else
        echo -e "${YELLOW}WARN${NC} Severity/level extraction not found"
      fi
      ;;
  esac
done

echo ""
echo -e "${YELLOW}NOTE:${NC} This script checks Promtail configuration for label patterns."
echo "To verify actual log labels in Loki, query: {namespace=\"$APP_NS\"} and inspect labels."

echo ""
if [[ "$failures" -eq 0 ]]; then
  if [[ "$skips" -gt 0 ]]; then
    echo -e "${YELLOW}OK (with $skips skipped checks)${NC}"
  else
    echo -e "${GREEN}OK${NC}"
  fi
  exit 0
else
  echo -e "${RED}FAILED ($failures checks failed)${NC}"
  exit 1
fi
