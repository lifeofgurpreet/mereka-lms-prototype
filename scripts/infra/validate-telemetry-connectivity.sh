#!/usr/bin/env bash
# Validate Grafana → Prometheus telemetry connectivity for Mereka LMS
# Tests both GKE (in-cluster) and VPS (external) Prometheus datasources
#
# Usage: ./scripts/infra/validate-telemetry-connectivity.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

echo "=========================================="
echo "Mereka LMS Telemetry Connectivity Validator"
echo "=========================================="
echo ""

# Function to print test results
print_result() {
  local test_name="$1"
  local status="$2"
  local message="${3:-}"

  if [[ "$status" == "PASS" ]]; then
    echo -e "${GREEN}✓ PASS${NC}: $test_name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗ FAIL${NC}: $test_name"
    if [[ -n "$message" ]]; then
      echo -e "  ${YELLOW}↳ $message${NC}"
    fi
    FAILED=$((FAILED + 1))
  fi
}

# Test 1: VPS Prometheus accessibility
echo "[1/8] Testing VPS Prometheus (prometheus.mereka.dev)..."
if curl -sS --max-time 10 'https://prometheus.mereka.dev/api/v1/query?query=up' | grep -q '"status":"success"'; then
  print_result "VPS Prometheus HTTPS endpoint" "PASS"
else
  print_result "VPS Prometheus HTTPS endpoint" "FAIL" "Cannot reach https://prometheus.mereka.dev"
fi

# Test 2: VPS Prometheus external-urls job
echo "[2/8] Testing VPS Prometheus external URL monitoring..."
if curl -sS --max-time 10 'https://prometheus.mereka.dev/api/v1/query?query=up' | grep -q 'external-urls'; then
  print_result "VPS Prometheus external-urls job" "PASS"
else
  print_result "VPS Prometheus external-urls job" "FAIL" "External URL probes not returning data"
fi

# Test 3: GKE Prometheus service exists
echo "[3/8] Testing GKE Prometheus service..."
if kubectl get svc -n monitoring monitoring-kube-prometheus-prometheus &>/dev/null; then
  print_result "GKE Prometheus service exists" "PASS"
else
  print_result "GKE Prometheus service exists" "FAIL" "Service not found in monitoring namespace"
fi

# Test 4: GKE Prometheus pod is running
echo "[4/8] Testing GKE Prometheus pod status..."
if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus | grep -q "Running"; then
  print_result "GKE Prometheus pod running" "PASS"
else
  print_result "GKE Prometheus pod running" "FAIL" "Prometheus pod not in Running state"
fi

# Test 5: GKE Prometheus in-cluster query
echo "[5/8] Testing GKE Prometheus in-cluster query..."
GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o name 2>/dev/null | head -1)
if [[ -n "$GRAFANA_POD" ]]; then
  if kubectl exec -n monitoring "$GRAFANA_POD" -- \
    wget -qO- --timeout=5 'http://monitoring-kube-prometheus-prometheus.monitoring:9090/api/v1/query?query=up' 2>/dev/null | grep -q '"status":"success"'; then
    print_result "GKE Prometheus query from Grafana" "PASS"
  else
    print_result "GKE Prometheus query from Grafana" "FAIL" "Query failed or timed out"
  fi
else
  print_result "GKE Prometheus query from Grafana" "FAIL" "Grafana pod not found"
fi

# Test 6: Mereka LMS namespace metrics
echo "[6/8] Testing Mereka LMS namespace metrics availability..."
if [[ -n "$GRAFANA_POD" ]]; then
  if kubectl exec -n monitoring "$GRAFANA_POD" -- \
    wget -qO- --timeout=5 'http://monitoring-kube-prometheus-prometheus.monitoring:9090/api/v1/query?query=kube_pod_status_phase{namespace="mereka-lms"}' 2>/dev/null | grep -q '"namespace":"mereka-lms"'; then
    print_result "Mereka LMS pod metrics" "PASS"
  else
    print_result "Mereka LMS pod metrics" "FAIL" "No metrics found for mereka-lms namespace"
  fi
else
  print_result "Mereka LMS pod metrics" "FAIL" "Skipped - Grafana pod not available"
fi

# Test 7: Grafana datasource ConfigMaps
echo "[7/8] Testing Grafana datasource configuration..."
DATASOURCES=$(kubectl get configmap -n monitoring -l grafana_datasource=1 -o name 2>/dev/null | wc -l)
if [[ "$DATASOURCES" -ge 2 ]]; then
  print_result "Grafana datasource ConfigMaps" "PASS"
else
  print_result "Grafana datasource ConfigMaps" "FAIL" "Expected at least 2 datasources, found $DATASOURCES"
fi

# Test 8: Specific datasource configs exist
echo "[8/8] Testing specific datasource configs..."
PASS_COUNT=0
if kubectl get configmap -n monitoring monitoring-kube-prometheus-grafana-datasource &>/dev/null; then
  PASS_COUNT=$((PASS_COUNT + 1))
fi
if kubectl get configmap -n monitoring grafana-datasource-vps-prometheus &>/dev/null; then
  PASS_COUNT=$((PASS_COUNT + 1))
fi

if [[ "$PASS_COUNT" -eq 2 ]]; then
  print_result "Required datasource ConfigMaps" "PASS"
else
  print_result "Required datasource ConfigMaps" "FAIL" "Missing required datasource configs ($PASS_COUNT/2 found)"
fi

# Summary
echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}✓ All telemetry connectivity tests passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "  - Open Grafana: https://grafana.mereka.dev"
  echo "  - View dashboard: https://grafana.mereka.dev/d/bbi-app-mereka-lms"
  echo "  - Test datasources: Configuration → Data Sources → Test"
  exit 0
else
  echo -e "${RED}✗ Some tests failed. Check the output above for details.${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  - See: docs/operations/SLO_DASHBOARDS_SETUP.md"
  echo "  - Section: Troubleshooting Datasource Connectivity"
  exit 1
fi
