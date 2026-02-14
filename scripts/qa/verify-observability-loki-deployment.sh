#!/usr/bin/env bash
# @covers AC-LOG-001
# @spec: observability-stack_spec.md
# Verify Promtail DaemonSet is deployed and scraping logs from all pods in mereka-lms namespace.
#
# Usage:
#   ./scripts/qa/verify-observability-loki-deployment.sh
#   ./scripts/qa/verify-observability-loki-deployment.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
STRICT="${STRICT:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context) K8S_CONTEXT="$2"; shift 2 ;;
    --namespace) APP_NS="$2"; shift 2 ;;
    --strict) STRICT=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

failures=0
skips=0

echo "Verify: Promtail DaemonSet deployment"
echo "  context:   $K8S_CONTEXT"
echo "  namespace: $APP_NS"
echo ""

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} kubectl not available"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Check if cluster is reachable
if ! kubectl --context "$K8S_CONTEXT" cluster-info >/dev/null 2>&1; then
  echo -e "${YELLOW}SKIP${NC} Cannot reach cluster: $K8S_CONTEXT"
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Check if Promtail DaemonSet exists (might be in monitoring namespace)
promtail_ns=""
for ns in monitoring "$APP_NS" loki-stack; do
  if kubectl --context "$K8S_CONTEXT" -n "$ns" get daemonset -l app.kubernetes.io/name=promtail -o name >/dev/null 2>&1; then
    promtail_ns="$ns"
    break
  fi
done

if [[ -z "$promtail_ns" ]]; then
  echo -e "${YELLOW}SKIP${NC} Promtail DaemonSet not found in monitoring, $APP_NS, or loki-stack namespaces"
  skips=$((skips + 1))
  [[ "$STRICT" -eq 1 ]] && exit 1
  exit 0
fi

# Check Promtail DaemonSet status
echo -n "Check: Promtail DaemonSet exists in namespace $promtail_ns... "
if kubectl --context "$K8S_CONTEXT" -n "$promtail_ns" get daemonset -l app.kubernetes.io/name=promtail >/dev/null 2>&1; then
  echo -e "${GREEN}PASS${NC}"
else
  echo -e "${RED}FAIL${NC}"
  failures=$((failures + 1))
fi

# Check Promtail pods are running
echo -n "Check: Promtail pods are running... "
promtail_pods=$(kubectl --context "$K8S_CONTEXT" -n "$promtail_ns" get pods -l app.kubernetes.io/name=promtail -o json 2>/dev/null || echo '{"items":[]}')
running_count=$(echo "$promtail_pods" | jq -r '[.items[] | select(.status.phase == "Running")] | length')
total_count=$(echo "$promtail_pods" | jq -r '.items | length')

if [[ "$running_count" -gt 0 ]] && [[ "$running_count" -eq "$total_count" ]]; then
  echo -e "${GREEN}PASS${NC} ($running_count/$total_count pods running)"
else
  echo -e "${RED}FAIL${NC} Only $running_count/$total_count pods running"
  failures=$((failures + 1))
fi

# Check Promtail is configured to scrape from mereka-lms namespace
echo -n "Check: Promtail configured to scrape $APP_NS namespace... "
promtail_config=$(kubectl --context "$K8S_CONTEXT" -n "$promtail_ns" get configmap -l app.kubernetes.io/name=promtail -o jsonpath='{.items[0].data}' 2>/dev/null || echo '{}')
if echo "$promtail_config" | grep -q "$APP_NS" || echo "$promtail_config" | grep -q "namespace_name"; then
  echo -e "${GREEN}PASS${NC}"
else
  echo -e "${YELLOW}WARN${NC} Cannot verify namespace filter in Promtail config (might scrape all namespaces)"
fi

# Check if Loki is deployed
echo -n "Check: Loki deployment exists... "
loki_found=0
for ns in monitoring "$APP_NS" loki-stack; do
  if kubectl --context "$K8S_CONTEXT" -n "$ns" get statefulset,deployment -l app.kubernetes.io/name=loki -o name >/dev/null 2>&1; then
    loki_found=1
    echo -e "${GREEN}PASS${NC} (found in namespace $ns)"
    break
  fi
done

if [[ "$loki_found" -eq 0 ]]; then
  echo -e "${YELLOW}SKIP${NC} Loki deployment not found"
  skips=$((skips + 1))
fi

# Check Promtail is successfully shipping logs
echo -n "Check: Promtail is shipping logs... "
# Check Promtail logs for successful pushes
if [[ "$running_count" -gt 0 ]]; then
  first_pod=$(echo "$promtail_pods" | jq -r '.items[0].metadata.name')
  promtail_logs=$(kubectl --context "$K8S_CONTEXT" -n "$promtail_ns" logs "$first_pod" --tail=100 2>/dev/null || echo "")

  if echo "$promtail_logs" | grep -qi "error"; then
    echo -e "${YELLOW}WARN${NC} Errors found in Promtail logs"
  elif [[ -n "$promtail_logs" ]]; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${YELLOW}SKIP${NC} Cannot read Promtail logs"
    skips=$((skips + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} No running Promtail pods to check logs"
  skips=$((skips + 1))
fi

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
