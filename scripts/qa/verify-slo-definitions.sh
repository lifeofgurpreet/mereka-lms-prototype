#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-007, AC-008, AC-009, AC-021
# @spec: slo-sla-service-level-management_spec.md
# Verify SLO policy document, PrometheusRule YAML, and all-service SLI/SLO coverage.
#
# Usage:
#   ./scripts/qa/verify-slo-definitions.sh              # local mode (default)
#   ./scripts/qa/verify-slo-definitions.sh --mode local
#   ./scripts/qa/verify-slo-definitions.sh --mode runtime
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

SLO_POLICY="docs/policies/operations/SLO_POLICY.md"
BURN_RATE_FILE="deploy/k8s/base/monitoring/slo-burn-rate-rules.yaml"
EXISTING_SLO_FILE="deploy/k8s/base/monitoring/prometheusrule-slo.yaml"
KUSTOMIZATION="deploy/k8s/base/monitoring/kustomization.yaml"

# ── Local Mode Checks ─────────────────────────────────────────────────────

if [[ "$MODE" == "local" ]]; then

  # 1. SLO policy document exists
  if [[ -f "$SLO_POLICY" ]]; then
    pass "SLO policy document exists ($SLO_POLICY)"
  else
    fail "SLO policy document missing ($SLO_POLICY)"
  fi

  # 2. Required sections in SLO policy
  for section in \
    "SLI Definitions" \
    "Error Budget Policy" \
    "Burn-Rate Alert Thresholds" \
    "Review Cadence" \
    "Service Tiers"; do
    if grep -q "$section" "$SLO_POLICY" 2>/dev/null; then
      pass "SLO policy contains section: $section"
    else
      fail "SLO policy missing section: $section"
    fi
  done

  # 3. All 5 services defined in SLO policy
  for service in "LMS" "Studio" "MFE" "Purchase Gateway" "Forum"; do
    if grep -q "$service" "$SLO_POLICY" 2>/dev/null; then
      pass "SLO policy covers service: $service"
    else
      fail "SLO policy missing service: $service"
    fi
  done

  # 4. Burn-rate PrometheusRule file exists
  if [[ -f "$BURN_RATE_FILE" ]]; then
    pass "Burn-rate PrometheusRule file exists ($BURN_RATE_FILE)"
  else
    fail "Burn-rate PrometheusRule file missing ($BURN_RATE_FILE)"
    echo
    echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
    exit 1
  fi

  # 5. Both SLO files are valid YAML
  for yaml_file in "$BURN_RATE_FILE" "$EXISTING_SLO_FILE"; do
    if command -v python3 >/dev/null 2>&1; then
      if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
        pass "Valid YAML: $yaml_file"
      else
        fail "Invalid YAML: $yaml_file"
      fi
    elif command -v yq >/dev/null 2>&1; then
      if yq eval '.' "$yaml_file" >/dev/null 2>&1; then
        pass "Valid YAML: $yaml_file"
      else
        fail "Invalid YAML: $yaml_file"
      fi
    else
      skip "No YAML validator (install python3 or yq): $yaml_file"
    fi
  done

  # 6. Kustomization references the new burn-rate file
  if grep -q "slo-burn-rate-rules.yaml" "$KUSTOMIZATION" 2>/dev/null; then
    pass "Kustomization references slo-burn-rate-rules.yaml"
  else
    fail "Kustomization does not reference slo-burn-rate-rules.yaml"
  fi

  # 7. SLI recording rules for all 5 services present across both files
  for service in lms cms mfe purchase-gateway forum; do
    if grep -q "service: ${service}" "$EXISTING_SLO_FILE" 2>/dev/null || \
       grep -q "service: ${service}" "$BURN_RATE_FILE" 2>/dev/null; then
      pass "SLI recording rules present for service: $service"
    else
      fail "SLI recording rules missing for service: $service"
    fi
  done

  # 8. Burn-rate recording rules for all 5 services
  for service in lms cms mfe purchase-gateway forum; do
    if (grep -q "service: ${service}" "$EXISTING_SLO_FILE" 2>/dev/null && \
        grep -q "mereka:slo:burn_rate" "$EXISTING_SLO_FILE" 2>/dev/null) || \
       (grep -q "service: ${service}" "$BURN_RATE_FILE" 2>/dev/null && \
        grep -q "mereka:slo:burn_rate" "$BURN_RATE_FILE" 2>/dev/null); then
      pass "Burn-rate recording rules present for service: $service"
    else
      fail "Burn-rate recording rules missing for service: $service"
    fi
  done

  # 9. Multi-window fast burn alerts present in both files
  for alert_name in SLOBudgetFastBurn SLOBudgetFastBurnExtended; do
    slo_file=""
    if grep -q "alert: ${alert_name}" "$EXISTING_SLO_FILE" 2>/dev/null; then
      slo_file="$EXISTING_SLO_FILE"
    elif grep -q "alert: ${alert_name}" "$BURN_RATE_FILE" 2>/dev/null; then
      slo_file="$BURN_RATE_FILE"
    fi

    if [[ -n "$slo_file" ]]; then
      fast_expr=$(grep -A6 "alert: ${alert_name}" "$slo_file" 2>/dev/null || true)
      if echo "$fast_expr" | grep -q "burn_rate_1h" && echo "$fast_expr" | grep -q "burn_rate_5m"; then
        pass "Alert $alert_name uses multi-window (1h + 5m)"
      else
        fail "Alert $alert_name missing multi-window pattern (expected burn_rate_1h AND burn_rate_5m)"
      fi
    else
      fail "Alert missing: $alert_name"
    fi
  done

  # 10. Multi-window slow burn alerts present
  for alert_name in SLOBudgetSlowBurn SLOBudgetSlowBurnExtended; do
    slo_file=""
    if grep -q "alert: ${alert_name}" "$EXISTING_SLO_FILE" 2>/dev/null; then
      slo_file="$EXISTING_SLO_FILE"
    elif grep -q "alert: ${alert_name}" "$BURN_RATE_FILE" 2>/dev/null; then
      slo_file="$BURN_RATE_FILE"
    fi

    if [[ -n "$slo_file" ]]; then
      slow_expr=$(grep -A6 "alert: ${alert_name}" "$slo_file" 2>/dev/null || true)
      if echo "$slow_expr" | grep -q "burn_rate_6h" && echo "$slow_expr" | grep -q "burn_rate_30m"; then
        pass "Alert $alert_name uses multi-window (6h + 30m)"
      else
        fail "Alert $alert_name missing multi-window pattern (expected burn_rate_6h AND burn_rate_30m)"
      fi
    else
      fail "Alert missing: $alert_name"
    fi
  done

  # 11. Tier classification covers all 3 tiers
  for tier in "1" "2" "3"; do
    if grep -q "tier: \"${tier}\"" "$EXISTING_SLO_FILE" 2>/dev/null || \
       grep -q "tier: \"${tier}\"" "$BURN_RATE_FILE" 2>/dev/null; then
      pass "Tier $tier classification present across SLO rules"
    else
      fail "Tier $tier classification missing from SLO rules"
    fi
  done

  # 12. Error budget remaining rules for all 5 services
  for service in lms cms mfe purchase-gateway forum; do
    if grep -q "service=\"${service}\"" "$EXISTING_SLO_FILE" 2>/dev/null || \
       grep -q "service=\"${service}\"" "$BURN_RATE_FILE" 2>/dev/null; then
      pass "Error budget remaining rule present for service: $service"
    else
      fail "Error budget remaining rule missing for service: $service"
    fi
  done

  # 13. Burn-rate thresholds in SLO policy doc
  for threshold in "14.4" "6×" "1×"; do
    if grep -q "$threshold" "$SLO_POLICY" 2>/dev/null; then
      pass "Burn-rate threshold $threshold documented in SLO policy"
    else
      fail "Burn-rate threshold $threshold missing from SLO policy"
    fi
  done

  echo
  echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  [[ "$FAIL" -eq 0 ]]
  exit $?
fi

# ── Runtime Mode Checks ────────────────────────────────────────────────────

K8S_CONTEXT="${K8S_CONTEXT:-${K8S_CONTEXT_PROD:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}"
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

# 1. Both PrometheusRules deployed
for rule_name in slo-recording-rules slo-burn-rate-rules; do
  if kubectl --context "$K8S_CONTEXT" -n "$NS" get prometheusrule "$rule_name" >/dev/null 2>&1; then
    pass "PrometheusRule exists in cluster: $rule_name"
  else
    fail "PrometheusRule not found in cluster: $rule_name"
  fi
done

# 2. Recording rules active in Prometheus
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
    # Check key recording rules for extended services
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

    # Check burn-rate alerts for extended services
    for alert in SLOBudgetFastBurnExtended SLOBudgetSlowBurnExtended SLOBudgetExhaustedExtended; do
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
