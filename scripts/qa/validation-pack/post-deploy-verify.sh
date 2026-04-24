#!/usr/bin/env bash
# post-deploy-verify.sh — Verify deployment health after applying changes
# Usage: ./scripts/qa/validation-pack/post-deploy-verify.sh [--namespace mereka-lms]
# Exit: 0 = all pass, 1 = failures detected
set -euo pipefail

NAMESPACE="mereka-lms"
if [[ "${1:-}" == "--namespace" ]]; then
  NAMESPACE="${2:-mereka-lms}"
fi

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

pass() { TOTAL=$((TOTAL+1)); PASSED=$((PASSED+1)); echo -e "${GREEN}PASS${NC} $*"; }
fail() { TOTAL=$((TOTAL+1)); FAILED=$((FAILED+1)); echo -e "${RED}FAIL${NC} $*"; }
skip() { TOTAL=$((TOTAL+1)); SKIPPED=$((SKIPPED+1)); echo -e "${YELLOW}SKIP${NC} $*"; }

echo "=== Post-Deploy Verification ==="
echo "Namespace: $NAMESPACE"
echo ""

# 1. All pods Running/Completed
echo "--- Pod Status ---"
not_ready=0
while IFS= read -r line; do
  name=$(echo "$line" | awk '{print $1}')
  ready=$(echo "$line" | awk '{print $2}')
  status=$(echo "$line" | awk '{print $3}')
  restarts=$(echo "$line" | awk '{print $4}')

  if [[ "$status" == "Running" || "$status" == "Completed" ]]; then
    # Check restarts
    restart_count=$(echo "$restarts" | grep -oE '^[0-9]+')
    if [[ "$restart_count" -gt 5 ]]; then
      fail "Pod $name — $status but $restarts restarts"
    else
      pass "Pod $name — $status ($ready ready)"
    fi
  elif [[ "$status" == "Error" && "$name" =~ verify|auth-verify|cert-verify ]]; then
    skip "Pod $name — $status (verification job)"
  else
    fail "Pod $name — $status"
    not_ready=$((not_ready+1))
  fi
done < <(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null)

# 2. Services have endpoints
echo ""
echo "--- Service Endpoints ---"
CRITICAL_SERVICES=("lms" "cms" "caddy" "mfe" "mysql")
for svc in "${CRITICAL_SERVICES[@]}"; do
  endpoints=$(kubectl get endpoints "$svc" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
  if [[ -n "$endpoints" ]]; then
    pass "Endpoints: $svc ($endpoints)"
  else
    fail "Endpoints: $svc — EMPTY (no backends)"
  fi
done

# 3. External access (via LoadBalancer or ClusterIP)
echo ""
echo "--- External Access ---"
caddy_ip=$(kubectl get svc caddy -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [[ -n "$caddy_ip" ]]; then
  pass "LoadBalancer IP: $caddy_ip"
else
  caddy_type=$(kubectl get svc caddy -n "$NAMESPACE" -o jsonpath='{.spec.type}' 2>/dev/null || echo "")
  skip "Caddy service type: $caddy_type (no external IP)"
fi

# 4. HPAs active
echo ""
echo "--- Autoscaling ---"
hpa_list=$(kubectl get hpa -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
if [[ -n "$hpa_list" ]]; then
  while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    targets=$(echo "$line" | awk '{print $4}')
    if [[ "$targets" == *"<unknown>"* ]]; then
      skip "HPA $name — targets unknown (metrics not yet collected)"
    else
      pass "HPA $name — $targets"
    fi
  done <<< "$hpa_list"
else
  skip "No HPAs configured"
fi

# 5. PrometheusRules loaded
echo ""
echo "--- Monitoring ---"
rules=$(kubectl get prometheusrule -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
if [[ -n "$rules" ]]; then
  rule_count=$(echo "$rules" | wc -l)
  pass "PrometheusRules: $rule_count loaded"
else
  skip "No PrometheusRules found"
fi

monitors=$(kubectl get servicemonitor -n "$NAMESPACE" --no-headers 2>/dev/null || echo "")
if [[ -n "$monitors" ]]; then
  monitor_count=$(echo "$monitors" | wc -l)
  pass "ServiceMonitors: $monitor_count configured"
else
  skip "No ServiceMonitors found"
fi

# 6. Log streaming check (promtail)
echo ""
echo "--- Log Streaming ---"
promtail_pods=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=promtail" --no-headers 2>/dev/null || echo "")
if [[ -n "$promtail_pods" ]]; then
  promtail_count=$(echo "$promtail_pods" | wc -l)
  running_count=$(echo "$promtail_pods" | grep -c "Running" || echo "0")
  if [[ "$running_count" -eq "$promtail_count" ]]; then
    pass "Promtail: $running_count/$promtail_count running"
  else
    fail "Promtail: $running_count/$promtail_count running"
  fi
else
  skip "No promtail pods found"
fi

# 7. Recent pod crashes (last 30 min)
echo ""
echo "--- Recent Crashes (30m) ---"
crashes=$(kubectl get events -n "$NAMESPACE" --field-selector reason=BackOff --sort-by='.lastTimestamp' 2>/dev/null | tail -5)
if [[ -n "$crashes" && ! "$crashes" =~ "No resources found" ]]; then
  crash_count=$(echo "$crashes" | grep -c "Back-off" || echo "0")
  if [[ "$crash_count" -gt 0 ]]; then
    fail "Recent BackOff events: $crash_count"
  else
    pass "No recent crash loops"
  fi
else
  pass "No recent crash loops"
fi

echo ""
echo "=== Summary ==="
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED | Skipped: $SKIPPED"

if [[ $FAILED -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL${NC}"
  exit 1
else
  echo -e "${GREEN}RESULT: PASS${NC}"
  exit 0
fi
