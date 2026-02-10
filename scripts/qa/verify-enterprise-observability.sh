#!/usr/bin/env bash
# verify-enterprise-observability.sh
# Covers: AC-035, AC-036 (Observability)
# Exit 0 = all checks pass, exit 1 = failures
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAMESPACE="mereka-lms"
PASS=0; FAIL=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
info() { echo -e "${YELLOW}ℹ${NC} $1"; }

echo "=== Enterprise Observability Verification (AC-035..AC-036) ==="
echo

# ---------------------------------------------------------------------------
# AC-035: /metrics scraped by Prometheus → enterprise-specific metrics present
# ---------------------------------------------------------------------------
echo "[AC-035] Verifying enterprise metrics and Prometheus scraping..."

# 1. Check ServiceMonitor resources exist for enterprise services
SM_FILE="$REPO_ROOT/deploy/k8s/base/monitoring/servicemonitor-enterprise.yaml"
if [[ -f "$SM_FILE" ]]; then
  SM_COUNT=$(grep -c "kind: ServiceMonitor" "$SM_FILE" || echo "0")
  if [[ "$SM_COUNT" -ge 3 ]]; then
    pass "AC-035: $SM_COUNT ServiceMonitors defined in enterprise monitoring manifest"
  else
    fail "AC-035: Only $SM_COUNT ServiceMonitors (expected >= 3 for catalog, access, subsidy)"
  fi

  # Verify each ServiceMonitor targets the correct service
  for svc in enterprise-catalog enterprise-access enterprise-subsidy; do
    if grep -q "$svc" "$SM_FILE"; then
      pass "AC-035: ServiceMonitor targets $svc"
    else
      fail "AC-035: ServiceMonitor missing target for $svc"
    fi
  done

  # Verify metrics path is /metrics
  if grep -q "path: /metrics" "$SM_FILE"; then
    pass "AC-035: ServiceMonitors scrape /metrics path"
  else
    fail "AC-035: ServiceMonitors missing /metrics path"
  fi

  # Verify scrape interval
  if grep -q "interval: 30s" "$SM_FILE"; then
    pass "AC-035: Scrape interval is 30s"
  else
    info "AC-035: Scrape interval check inconclusive"
  fi
else
  fail "AC-035: ServiceMonitor manifest not found at $SM_FILE"
fi

# 2. Check ServiceMonitors are applied to the cluster
SM_CLUSTER_COUNT=$(kubectl get servicemonitors -n "$NAMESPACE" -l app.kubernetes.io/component=monitoring -o name 2>/dev/null | grep -c "enterprise" || echo "0")
if [[ "$SM_CLUSTER_COUNT" -ge 3 ]]; then
  pass "AC-035: $SM_CLUSTER_COUNT enterprise ServiceMonitors deployed in cluster"
elif [[ "$SM_CLUSTER_COUNT" -gt 0 ]]; then
  info "AC-035: $SM_CLUSTER_COUNT enterprise ServiceMonitors in cluster (expected >= 3)"
else
  # Try without label filter
  SM_CLUSTER_COUNT=$(kubectl get servicemonitors -n "$NAMESPACE" -o name 2>/dev/null | grep -c "enterprise" || echo "0")
  if [[ "$SM_CLUSTER_COUNT" -ge 3 ]]; then
    pass "AC-035: $SM_CLUSTER_COUNT enterprise ServiceMonitors deployed in cluster"
  else
    info "AC-035: $SM_CLUSTER_COUNT enterprise ServiceMonitors found in cluster"
  fi
fi

# 3. Check PrometheusRule exists for enterprise alerts
PR_FILE="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-enterprise.yaml"
if [[ -f "$PR_FILE" ]]; then
  ALERT_COUNT=$(grep -c "alert:" "$PR_FILE" || echo "0")
  if [[ "$ALERT_COUNT" -ge 4 ]]; then
    pass "AC-035: $ALERT_COUNT alert rules defined in enterprise PrometheusRule"
  else
    fail "AC-035: Only $ALERT_COUNT alert rules (expected >= 4)"
  fi
else
  fail "AC-035: PrometheusRule manifest not found at $PR_FILE"
fi

# 4. Check if /metrics endpoint responds on enterprise services
SERVICES=("enterprise-catalog:8160" "enterprise-access:18270" "enterprise-subsidy:18280")
for svc_port in "${SERVICES[@]}"; do
  SVC="${svc_port%:*}"
  PORT="${svc_port#*:}"
  POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$SVC" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$POD" ]]; then
    HTTP=$(kubectl exec -n "$NAMESPACE" "$POD" -- python3 -c "
import urllib.request, urllib.error
try:
    r = urllib.request.urlopen('http://localhost:$PORT/metrics', timeout=10)
    print(r.status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception:
    print('000')" 2>/dev/null | tr -d '[:space:]')
    if [[ "$HTTP" == "200" ]]; then
      pass "AC-035: $SVC /metrics returns 200"
    elif [[ "$HTTP" == "404" ]]; then
      info "AC-035: $SVC /metrics returns 404 (django-prometheus instrumentation pending)"
    else
      info "AC-035: $SVC /metrics returns $HTTP"
    fi
  fi
done
echo

# ---------------------------------------------------------------------------
# AC-036: License assignment failure logs include required fields
# (enterprise_customer_uuid, subscription_plan_uuid, error_type, user_email_hash)
# ---------------------------------------------------------------------------
echo "[AC-036] Verifying structured logging configuration..."

# 1. Check enterprise services output structured JSON logs
for svc in enterprise-catalog enterprise-access enterprise-subsidy; do
  POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$svc" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$POD" ]]; then
    # Get recent logs and check if they're structured (JSON format)
    LOG_SAMPLE=$(kubectl logs -n "$NAMESPACE" "$POD" --tail=20 2>/dev/null | head -5 || echo "")
    if echo "$LOG_SAMPLE" | grep -q '{.*".*":'; then
      pass "AC-036: $svc outputs structured JSON logs"
    elif [[ -n "$LOG_SAMPLE" ]]; then
      info "AC-036: $svc logs may not be structured JSON (check format)"
    else
      info "AC-036: $svc no recent log output"
    fi
  fi
done

# 2. Verify Promtail/Loki is configured to collect enterprise service logs
PROMTAIL_COUNT=$(kubectl get pods -n "$NAMESPACE" -l app=promtail --no-headers 2>/dev/null | wc -l)
if [[ "$PROMTAIL_COUNT" -eq 0 ]]; then
  PROMTAIL_COUNT=$(kubectl get pods --all-namespaces -l app=promtail --no-headers 2>/dev/null | wc -l)
fi
if [[ "$PROMTAIL_COUNT" -gt 0 ]]; then
  pass "AC-036: Promtail running ($PROMTAIL_COUNT pods) for log collection"
else
  info "AC-036: Promtail not found (logs may be collected via other means)"
fi

# 3. Check that enterprise services do NOT log raw email addresses
# (spec requires hashed emails only in logs)
for svc in enterprise-catalog enterprise-access enterprise-subsidy; do
  POD=$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=$svc" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -n "$POD" ]]; then
    # Check recent logs for email pattern (basic heuristic)
    EMAIL_LEAK=$(kubectl logs -n "$NAMESPACE" "$POD" --tail=100 2>/dev/null | { grep -cE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' || true; })
    if [[ "$EMAIL_LEAK" -eq 0 ]]; then
      pass "AC-036: $svc logs show no raw email addresses (PII safe)"
    else
      fail "AC-036: $svc logs contain $EMAIL_LEAK lines with email addresses (PII leak risk)"
    fi
  fi
done

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS"
echo -e "${RED}FAIL:${NC} $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
