#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-007, AC-008, AC-009
# @spec: slo-sla-service-level-management_spec.md
# Verify the SLI/SLO PrometheusRule contracts exist and are well-formed.
#
# Usage:
#   ./scripts/qa/verify-slo-contracts.sh              # local mode (default)
#   ./scripts/qa/verify-slo-contracts.sh --mode local  # explicit local
#   ./scripts/qa/verify-slo-contracts.sh --mode runtime # check live cluster
set -euo pipefail

MODE="${MODE:-local}"
if [[ "${1:-}" == "--mode" ]]; then
  MODE="${2:-}"; shift 2
fi

if [[ "$MODE" != "local" && "$MODE" != "runtime" ]]; then
  echo "Invalid mode: $MODE (expected local|runtime)" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PASS=0
FAIL=0
SKIP=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }
skip() { echo "[SKIP] $1"; SKIP=$((SKIP + 1)); }

SLO_FILE="deploy/k8s/base/monitoring/prometheusrule-slo.yaml"
KUSTOMIZATION="deploy/k8s/base/monitoring/kustomization.yaml"

# ── Local Mode Checks ─────────────────────────────────────────────

if [[ "$MODE" == "local" ]]; then
  # 1. PrometheusRule file exists
  if [[ -f "$SLO_FILE" ]]; then
    pass "SLO PrometheusRule file exists ($SLO_FILE)"
  else
    fail "SLO PrometheusRule file missing ($SLO_FILE)"
    echo "  Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
    exit 1
  fi

  # 2. Valid YAML (requires yq or python3)
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml; yaml.safe_load(open('$SLO_FILE'))" 2>/dev/null; then
      pass "SLO PrometheusRule is valid YAML"
    else
      fail "SLO PrometheusRule is not valid YAML"
    fi
  elif command -v yq >/dev/null 2>&1; then
    if yq eval '.' "$SLO_FILE" >/dev/null 2>&1; then
      pass "SLO PrometheusRule is valid YAML"
    else
      fail "SLO PrometheusRule is not valid YAML"
    fi
  else
    skip "No YAML validator available (install python3 or yq)"
  fi

  # 3. Kustomization includes the SLO file
  if grep -q "prometheusrule-slo.yaml" "$KUSTOMIZATION" 2>/dev/null; then
    pass "Kustomization references prometheusrule-slo.yaml"
  else
    fail "Kustomization does not reference prometheusrule-slo.yaml"
  fi

  # 4. Recording rules for LMS availability (AC-004, AC-005)
  for rule in \
    "mereka:http_requests:availability_ratio_5m" \
    "mereka:http_requests:availability_ratio_30m" \
    "mereka:http_requests:availability_ratio_1h" \
    "mereka:http_requests:availability_ratio_6h"; do
    if grep -q "record: ${rule}" "$SLO_FILE" 2>/dev/null; then
      pass "Recording rule defined: $rule"
    else
      fail "Recording rule missing: $rule"
    fi
  done

  # 5. Recording rules for latency percentiles (AC-003)
  for rule in \
    "mereka:http_request_duration:p50_5m" \
    "mereka:http_request_duration:p95_5m" \
    "mereka:http_request_duration:p99_5m"; do
    if grep -q "record: ${rule}" "$SLO_FILE" 2>/dev/null; then
      pass "Latency recording rule defined: $rule"
    else
      fail "Latency recording rule missing: $rule"
    fi
  done

  # 6. Burn rate recording rules (AC-007)
  for rule in \
    "mereka:slo:burn_rate_5m" \
    "mereka:slo:burn_rate_30m" \
    "mereka:slo:burn_rate_1h" \
    "mereka:slo:burn_rate_6h"; do
    if grep -q "record: ${rule}" "$SLO_FILE" 2>/dev/null; then
      pass "Burn rate rule defined: $rule"
    else
      fail "Burn rate rule missing: $rule"
    fi
  done

  # 7. Error budget remaining recording rules (AC-007)
  for rule in \
    "mereka:slo:error_budget_remaining_ratio" \
    "mereka:slo:error_budget_remaining_minutes"; do
    if grep -q "record: ${rule}" "$SLO_FILE" 2>/dev/null; then
      pass "Error budget rule defined: $rule"
    else
      fail "Error budget rule missing: $rule"
    fi
  done

  # 8. Both LMS and CMS services covered (AC-001)
  for svc in lms cms; do
    if grep -q "service: ${svc}" "$SLO_FILE" 2>/dev/null; then
      pass "Service covered in SLO rules: $svc"
    else
      fail "Service missing from SLO rules: $svc"
    fi
  done

  # 9. Tier 1 classification present (AC-002)
  if grep -q 'tier: "1"' "$SLO_FILE" 2>/dev/null; then
    pass "Tier 1 classification present in SLO rules"
  else
    fail "Tier 1 classification missing from SLO rules"
  fi

  # 10. Burn rate alert rules (AC-009)
  for alert in \
    SLOBudgetFastBurn \
    SLOBudgetSlowBurn \
    SLOBudgetWarning \
    SLOBudgetExhausted \
    SLOBudgetLow \
    SLIMeasurementDown; do
    if grep -q "alert: ${alert}" "$SLO_FILE" 2>/dev/null; then
      pass "Alert rule defined: $alert"
    else
      fail "Alert rule missing: $alert"
    fi
  done

  # 11. Fast burn uses multi-window (1h AND 5m)
  fast_burn_expr=$(grep -A5 "alert: SLOBudgetFastBurn" "$SLO_FILE" 2>/dev/null || true)
  if echo "$fast_burn_expr" | grep -q "burn_rate_1h" && echo "$fast_burn_expr" | grep -q "burn_rate_5m"; then
    pass "SLOBudgetFastBurn uses multi-window (1h + 5m)"
  else
    fail "SLOBudgetFastBurn missing multi-window pattern"
  fi

  # 12. Slow burn uses multi-window (6h AND 30m)
  slow_burn_expr=$(grep -A5 "alert: SLOBudgetSlowBurn" "$SLO_FILE" 2>/dev/null || true)
  if echo "$slow_burn_expr" | grep -q "burn_rate_6h" && echo "$slow_burn_expr" | grep -q "burn_rate_30m"; then
    pass "SLOBudgetSlowBurn uses multi-window (6h + 30m)"
  else
    fail "SLOBudgetSlowBurn missing multi-window pattern"
  fi

  echo
  echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  [[ "$FAIL" -eq 0 ]]
  exit $?
fi

# ── Runtime Mode Checks ──────────────────────────────────────────

K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
NS="${APP_NS:-mereka-lms}"

if ! command -v kubectl >/dev/null 2>&1; then
  skip "kubectl not available"
  echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  exit 0
fi

if ! kubectl --context "$K8S_CONTEXT" get namespace "$NS" >/dev/null 2>&1; then
  skip "Cannot reach cluster ($K8S_CONTEXT / $NS)"
  echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  exit 0
fi

# 1. PrometheusRule exists in cluster
if kubectl --context "$K8S_CONTEXT" -n "$NS" get prometheusrule slo-recording-rules >/dev/null 2>&1; then
  pass "PrometheusRule slo-recording-rules exists in cluster"
else
  fail "PrometheusRule slo-recording-rules not found in cluster"
fi

# 2. Check recording rules are loaded in Prometheus
PROM_POD="$(
  kubectl --context "$K8S_CONTEXT" -n monitoring get pods \
    -l app.kubernetes.io/name=prometheus \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
)"

if [[ -z "$PROM_POD" ]]; then
  skip "Prometheus pod not found in monitoring namespace"
else
  RULES_JSON="$(
    kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
      wget -qO- --timeout=5 'http://localhost:9090/api/v1/rules' 2>/dev/null || true
  )"

  if [[ -z "$RULES_JSON" ]]; then
    skip "Unable to query Prometheus /api/v1/rules"
  else
    # Check for SLI recording rules
    for rule in \
      "mereka:http_requests:availability_ratio_5m" \
      "mereka:slo:burn_rate_1h" \
      "mereka:slo:error_budget_remaining_ratio"; do
      if echo "$RULES_JSON" | grep -q "$rule"; then
        pass "Recording rule active in Prometheus: $rule"
      else
        fail "Recording rule not found in Prometheus: $rule"
      fi
    done

    # Check for alert rules
    for alert in SLOBudgetFastBurn SLOBudgetSlowBurn SLIMeasurementDown; do
      if echo "$RULES_JSON" | grep -q "$alert"; then
        pass "Alert rule active in Prometheus: $alert"
      else
        fail "Alert rule not found in Prometheus: $alert"
      fi
    done
  fi
fi

echo
echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[[ "$FAIL" -eq 0 ]]
exit $?
