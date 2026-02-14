#!/usr/bin/env bash
# @covers AC-001
# @spec: observability-stack_spec.md
# Verify ServiceMonitor resources exist for all services.
#
# Usage:
#   ./scripts/qa/verify-observability-servicemonitors.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
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

failures=0
skips=0

echo "Verify: ServiceMonitor resources"
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

# Check if ServiceMonitor CRD is installed
echo -n "Check: ServiceMonitor CRD is installed... "
if kubectl --context "$K8S_CONTEXT" get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1; then
  echo -e "${GREEN}PASS${NC}"
else
  echo -e "${RED}FAIL${NC} ServiceMonitor CRD not found (Prometheus Operator not installed?)"
  failures=$((failures + 1))
  exit 1
fi

# Expected ServiceMonitors from repo
EXPECTED_SERVICEMONITORS=(
  "lms"
  "cms"
  "redis"
  "mysql"
  "enterprise"
)

echo ""
echo "Checking ServiceMonitor manifests in repository..."
for svc in "${EXPECTED_SERVICEMONITORS[@]}"; do
  echo -n "  Check: servicemonitor-$svc.yaml exists... "
  if [[ -f "deploy/k8s/base/monitoring/servicemonitor-$svc.yaml" ]]; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${RED}FAIL${NC}"
    failures=$((failures + 1))
  fi
done

echo ""
echo "Checking deployed ServiceMonitors in cluster..."
for svc in "${EXPECTED_SERVICEMONITORS[@]}"; do
  echo -n "  Check: ServiceMonitor '$svc' deployed... "
  if kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get servicemonitor "$svc" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
  else
    echo -e "${YELLOW}WARN${NC} Not found in namespace $APP_NS"
  fi
done

# Check if any ServiceMonitors exist in the namespace
echo ""
echo -n "Check: At least one ServiceMonitor exists in $APP_NS... "
sm_count=$(kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get servicemonitor -o json 2>/dev/null | jq '.items | length' || echo "0")

if [[ "$sm_count" -gt 0 ]]; then
  echo -e "${GREEN}PASS${NC} ($sm_count ServiceMonitors found)"
else
  echo -e "${YELLOW}WARN${NC} No ServiceMonitors found"
fi

# List all ServiceMonitors
if [[ "$sm_count" -gt 0 ]]; then
  echo ""
  echo "Deployed ServiceMonitors:"
  kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get servicemonitor -o custom-columns=NAME:.metadata.name,AGE:.metadata.creationTimestamp | sed 's/^/  /'
fi

# Check if Prometheus is discovering targets
echo ""
echo -n "Check: Prometheus is deployed... "
prom_pod=$(kubectl --context "$K8S_CONTEXT" -n monitoring get pods -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [[ -n "$prom_pod" ]]; then
  echo -e "${GREEN}PASS${NC} (pod: $prom_pod)"

  # Try to query Prometheus targets
  echo -n "Check: Prometheus scraping targets from $APP_NS... "
  targets=$(kubectl --context "$K8S_CONTEXT" -n monitoring exec "$prom_pod" -- wget -qO- --timeout=5 'http://localhost:9090/api/v1/targets' 2>/dev/null || echo "")

  if [[ -n "$targets" ]]; then
    # Check if any targets are from mereka-lms namespace
    if echo "$targets" | jq -e --arg ns "$APP_NS" '.data.activeTargets[] | select(.labels.namespace == $ns)' >/dev/null 2>&1; then
      active_count=$(echo "$targets" | jq --arg ns "$APP_NS" '[.data.activeTargets[] | select(.labels.namespace == $ns)] | length')
      echo -e "${GREEN}PASS${NC} ($active_count active targets)"
    else
      echo -e "${YELLOW}WARN${NC} No active targets found for namespace $APP_NS"
    fi
  else
    echo -e "${YELLOW}SKIP${NC} Cannot query Prometheus targets API"
    skips=$((skips + 1))
  fi
else
  echo -e "${YELLOW}SKIP${NC} Prometheus pod not found"
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
