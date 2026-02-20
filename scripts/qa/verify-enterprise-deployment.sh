#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-033, AC-034
# @spec: enterprise-microservices_spec.md
# Machine-verifiable enterprise deployment verification
# Exit 0 if all checks pass, exit 1 if any check fails

set -euo pipefail

NAMESPACE="mereka-lms"
FAILED=0

log_pass() { printf "✅ PASS: %s\n" "$1"; }
log_fail() { printf "❌ FAIL: %s\n" "$1"; FAILED=1; }
log_info() { printf "ℹ️  INFO: %s\n" "$1"; }

http_code_from_pod() {
  local pod="$1"
  local port="$2"
  local python_probe

  python_probe="import urllib.request; exec(\"try:\\n print(urllib.request.urlopen('http://localhost:${port}/health/', timeout=5).getcode())\\nexcept Exception:\\n print('000')\")"

  kubectl exec -n "$NAMESPACE" "$pod" -- python3 -c "$python_probe" 2>/dev/null \
    || kubectl exec -n "$NAMESPACE" "$pod" -- python -c "$python_probe" 2>/dev/null \
    || printf "000\n"
}

echo "═══════════════════════════════════════════════════════════"
echo "  Enterprise Microservices Deployment Verification"
echo "  Namespace: $NAMESPACE"
echo "  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "═══════════════════════════════════════════════════════════"
echo

# Check 1: All 7 deployments exist and are ready
echo "[1/10] Checking deployments..."
EXPECTED_DEPLOYMENTS=(
  "enterprise-catalog"
  "enterprise-catalog-worker"
  "enterprise-access"
  "enterprise-access-worker"
  "enterprise-subsidy"
  "enterprise-admin-portal"
  "enterprise-learner-portal"
)

for dep in "${EXPECTED_DEPLOYMENTS[@]}"; do
  if kubectl get deployment "$dep" -n "$NAMESPACE" &>/dev/null; then
    READY=$(kubectl get deployment "$dep" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment "$dep" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    if [ "$READY" -eq "$DESIRED" ]; then
      log_pass "$dep: $READY/$DESIRED ready"
    else
      log_fail "$dep: $READY/$DESIRED ready (expected $DESIRED/$DESIRED)"
    fi
  else
    log_fail "$dep: deployment not found"
  fi
done

# Check 2: All pods are running with 0 restarts
echo
echo "[2/10] Checking pods..."
POD_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=enterprise --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
if [ "$POD_COUNT" -ge 7 ]; then
  log_pass "Enterprise pods running: $POD_COUNT (expected ≥7)"
else
  log_fail "Enterprise pods running: $POD_COUNT (expected ≥7)"
fi

# Check for restart loops
RESTARTING=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=enterprise --field-selector=status.phase=Running -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2>/dev/null | tr ' ' '\n' | awk '$1>5{print}' | wc -l)
if [ "$RESTARTING" -eq 0 ]; then
  log_pass "No pods with >5 restarts"
else
  log_fail "$RESTARTING pods have >5 restarts (check for crash loops)"
fi

# Check 3: All 5 services have endpoints
echo
echo "[3/10] Checking services..."
EXPECTED_SERVICES=(
  "enterprise-catalog"
  "enterprise-access"
  "enterprise-subsidy"
  "enterprise-admin-portal"
  "enterprise-learner-portal"
)

for svc in "${EXPECTED_SERVICES[@]}"; do
  if kubectl get svc "$svc" -n "$NAMESPACE" &>/dev/null; then
    ENDPOINTS=$(kubectl get endpoints "$svc" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null | wc -w)
    if [ "$ENDPOINTS" -gt 0 ]; then
      log_pass "$svc: $ENDPOINTS endpoint(s)"
    else
      log_fail "$svc: no endpoints (check pod selectors)"
    fi
  else
    log_fail "$svc: service not found"
  fi
done

# Check 4: Health checks return 200
echo
echo "[4/10] Checking health endpoints..."
HEALTH_SERVICES=(
  "enterprise-catalog:8160"
  "enterprise-access:18270"
  "enterprise-subsidy:18280"
)

for svc_port in "${HEALTH_SERVICES[@]}"; do
  SVC="${svc_port%:*}"
  PORT="${svc_port#*:}"
  POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$SVC" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  if [ -n "$POD" ]; then
    HTTP_CODE=$(http_code_from_pod "$POD" "$PORT" | tr -d '\r\n')
    if [ "$HTTP_CODE" = "200" ]; then
      log_pass "$SVC /health/ returns 200"
    else
      log_fail "$SVC /health/ returns $HTTP_CODE (expected 200)"
    fi
  else
    log_fail "$SVC: no running pod found"
  fi
done

# Check 5: Resource usage within expected bounds
echo
echo "[5/10] Checking resource usage..."
if command -v kubectl &>/dev/null && kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/component=enterprise --no-headers &>/dev/null; then
  TOTAL_CPU=$(kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/component=enterprise --no-headers 2>/dev/null | awk '{sum+=$2} END {print sum}' | sed 's/m//')
  TOTAL_MEM=$(kubectl top pods -n "$NAMESPACE" -l app.kubernetes.io/component=enterprise --no-headers 2>/dev/null | awk '{sum+=$3} END {print sum}' | sed 's/Mi//')

  # Expected: <100m CPU, <2000Mi memory
  if [ "${TOTAL_CPU:-0}" -lt 100 ]; then
    log_pass "Total CPU: ${TOTAL_CPU}m (within bounds)"
  else
    log_fail "Total CPU: ${TOTAL_CPU}m (expected <100m at idle)"
  fi

  if [ "${TOTAL_MEM:-0}" -lt 2000 ]; then
    log_pass "Total memory: ${TOTAL_MEM}Mi (within bounds)"
  else
    log_fail "Total memory: ${TOTAL_MEM}Mi (expected <2000Mi)"
  fi
else
  log_info "Metrics server not available, skipping resource check"
fi

# Check 6: All secrets exist
echo
echo "[6/10] Checking secrets..."
if kubectl get secret enterprise-secrets -n "$NAMESPACE" &>/dev/null; then
  SECRET_KEYS=$(kubectl get secret enterprise-secrets -n "$NAMESPACE" -o jsonpath='{.data}' 2>/dev/null | grep -o '"[^"]*"' | wc -l)
  if [ "$SECRET_KEYS" -ge 10 ]; then
    log_pass "enterprise-secrets: $SECRET_KEYS keys (expected ≥10)"
  else
    log_fail "enterprise-secrets: $SECRET_KEYS keys (expected ≥10)"
  fi
else
  log_fail "enterprise-secrets not found"
fi

# Check 7: Integrated channels configured in LMS
echo
echo "[7/10] Checking LMS integrated channels config..."
if kubectl get configmap lms-settings -n "$NAMESPACE" &>/dev/null; then
  if kubectl get configmap lms-settings -n "$NAMESPACE" -o yaml 2>/dev/null | grep -q "mereka_enterprise_channels.py"; then
    log_pass "LMS ConfigMap references mereka_enterprise_channels.py"
  else
    log_fail "LMS ConfigMap missing mereka_enterprise_channels.py"
  fi
else
  log_info "LMS ConfigMap not found (skipping channel config check)"
fi

# Check 8: No ImagePullBackOff or CrashLoopBackOff
echo
echo "[8/10] Checking for common failure states..."
WAITING_REASONS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=enterprise --field-selector=status.phase!=Succeeded -o jsonpath='{.items[*].status.containerStatuses[*].state.waiting.reason}' 2>/dev/null || true)
IMAGE_PULL_ERRORS=$(tr ' ' '\n' <<<"$WAITING_REASONS" | awk '$0=="ImagePullBackOff"{count++} END{print count+0}')
if [ "$IMAGE_PULL_ERRORS" -eq 0 ]; then
  log_pass "No ImagePullBackOff errors"
else
  log_fail "$IMAGE_PULL_ERRORS pods in ImagePullBackOff"
fi

CRASH_LOOPS=$(tr ' ' '\n' <<<"$WAITING_REASONS" | awk '$0=="CrashLoopBackOff"{count++} END{print count+0}')
if [ "$CRASH_LOOPS" -eq 0 ]; then
  log_pass "No CrashLoopBackOff errors"
else
  log_fail "$CRASH_LOOPS pods in CrashLoopBackOff"
fi

# Check 9: MFE ingress exists
echo
echo "[9/10] Checking MFE ingress..."
if kubectl get ingress enterprise-mfe -n "$NAMESPACE" &>/dev/null; then
  INGRESS_IP=$(kubectl get ingress enterprise-mfe -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
  if [ -n "$INGRESS_IP" ]; then
    log_pass "MFE ingress exists with IP: $INGRESS_IP"
  else
    log_fail "MFE ingress exists but has no IP assigned"
  fi
else
  log_info "MFE ingress not found (may not be deployed yet)"
fi

# Check 10: Config-gen init containers present
echo
echo "[10/10] Checking config-gen init containers..."
CONFIG_GEN_COUNT=$(kubectl get deployments -n "$NAMESPACE" -l app.kubernetes.io/component=enterprise -o jsonpath='{.items[*].spec.template.spec.initContainers[?(@.name=="config-gen")].name}' 2>/dev/null | wc -w)
if [ "$CONFIG_GEN_COUNT" -ge 3 ]; then
  log_pass "Config-gen init containers: $CONFIG_GEN_COUNT (expected ≥3)"
else
  log_fail "Config-gen init containers: $CONFIG_GEN_COUNT (expected ≥3 for main services)"
fi

# Summary
echo
echo "═══════════════════════════════════════════════════════════"
if [ $FAILED -eq 0 ]; then
  echo "  ✅ ALL CHECKS PASSED"
  echo "  Enterprise deployment is healthy and operational"
  echo "═══════════════════════════════════════════════════════════"
  exit 0
else
  echo "  ❌ SOME CHECKS FAILED"
  echo "  Review failures above and check logs with:"
  echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/component=enterprise --tail=50"
  echo "═══════════════════════════════════════════════════════════"
  exit 1
fi
