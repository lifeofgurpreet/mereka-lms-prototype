#!/usr/bin/env bash
# Verify Open edX monitoring runtime contract.
set -euo pipefail

NAMESPACE="${VERIFY_MON_NS:-mereka-lms}"
MONITORING_NS="${VERIFY_MON_MONITORING_NS:-monitoring}"
TIMEOUT_SECS="${VERIFY_MON_TIMEOUT:-20}"
FAIL=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

run_kubectl() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "$TIMEOUT_SECS" kubectl "$@"
  else
    kubectl "$@"
  fi
}

echo "=== Open edX Monitoring Verification ==="
echo

echo "1. Checking ServiceMonitors..."
run_kubectl get servicemonitor -n "$NAMESPACE" >/dev/null && pass "ServiceMonitors listable in $NAMESPACE" || fail "Cannot list ServiceMonitors in $NAMESPACE"
echo

echo "2. Checking PrometheusRules..."
run_kubectl get prometheusrule -n "$NAMESPACE" >/dev/null && pass "PrometheusRules listable in $NAMESPACE" || fail "Cannot list PrometheusRules in $NAMESPACE"
echo

echo "3. Checking service endpoints..."
run_kubectl get endpoints -n "$NAMESPACE" lms cms >/dev/null && pass "LMS/CMS endpoints exist" || fail "LMS/CMS endpoints missing"
echo

echo "4. Testing LMS /metrics endpoint (expected: HTTP 200)..."
LMS_CODE="$(run_kubectl exec -n "$NAMESPACE" deploy/lms -- curl -s -o /dev/null -w "%{http_code}" localhost:8000/metrics 2>/dev/null || echo "000")"
if [[ "$LMS_CODE" == "200" ]]; then
  pass "LMS /metrics returned 200"
else
  fail "LMS /metrics returned $LMS_CODE (expected 200)"
fi
echo

echo "5. Testing CMS /metrics endpoint (expected: HTTP 200)..."
CMS_CODE="$(run_kubectl exec -n "$NAMESPACE" deploy/cms -- curl -s -o /dev/null -w "%{http_code}" localhost:8000/metrics 2>/dev/null || echo "000")"
if [[ "$CMS_CODE" == "200" ]]; then
  pass "CMS /metrics returned 200"
else
  fail "CMS /metrics returned $CMS_CODE (expected 200)"
fi
echo

echo "6. Checking if Prometheus Operator is running..."
run_kubectl get pods -n "$MONITORING_NS" -l app.kubernetes.io/name=prometheus >/dev/null \
  && pass "Prometheus pod(s) discovered in $MONITORING_NS" \
  || fail "Prometheus pod(s) not found in $MONITORING_NS"
echo

echo "=== Summary ==="
if [[ "$FAIL" -eq 0 ]]; then
  echo "PASS: monitoring runtime contract satisfied"
  exit 0
fi

echo "FAIL: monitoring runtime contract has $FAIL failing check(s)"
exit 1
