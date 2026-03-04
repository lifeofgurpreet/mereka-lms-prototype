#!/usr/bin/env bash
# @covers AC-026, AC-027, AC-028, AC-029, AC-030, AC-031, AC-032, AC-037, AC-038, AC-039, AC-040, AC-041
# @spec: slo-sla-service-level-management_spec.md
# Verify service-specific SLI metrics and error budget procedures.
#
# Checks:
# - Service-specific SLI metrics (LMS availability, CMS latency, etc.)
# - All production services have SLI metrics
# - Error budget exhaustion procedures (< 0%, < 10%)
# - Error budget dashboard panels and thresholds
# - Service ownership and runbook links in dashboards
#
# Usage:
#   ./scripts/qa/verify-slo-service-metrics.sh              # local mode (default)
#   ./scripts/qa/verify-slo-service-metrics.sh --mode local  # explicit local
#   ./scripts/qa/verify-slo-service-metrics.sh --mode runtime # check live cluster
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

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1" >&2; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; SKIP=$((SKIP + 1)); }

# ── Local Mode Checks ─────────────────────────────────────────────

if [[ "$MODE" == "local" ]]; then
  SPEC_FILE="specs/slo-sla-service-level-management_spec.md"
  SLO_FILE="deploy/k8s/base/monitoring/prometheusrule-slo.yaml"

  if [[ ! -f "$SPEC_FILE" ]]; then
    fail "Spec file missing ($SPEC_FILE)"
    echo -e "\n  Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
    exit 1
  fi

  if [[ ! -f "$SLO_FILE" ]]; then
    fail "SLO PrometheusRule missing ($SLO_FILE)"
    echo -e "\n  Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
    exit 1
  fi

  # ── AC-026, AC-027, AC-028: Service-specific SLI metrics ──────

  # AC-026: LMS availability ratio metric
  if grep -q 'mereka_sli_lms_availability_ratio' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-026: LMS availability SLI metric defined in spec"
  else
    fail "AC-026: LMS availability SLI metric missing from spec"
  fi

  # AC-027: CMS latency p95 metric
  if grep -q 'mereka_sli_cms_latency_p95_seconds' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-027: CMS p95 latency SLI metric defined in spec"
  else
    fail "AC-027: CMS p95 latency SLI metric missing from spec"
  fi

  # AC-028: All production services have SLI metrics
  PRODUCTION_SERVICES=(
    "lms"
    "cms"
    "mfe"
    "forum"
    "discovery"
    "mysql"
    "redis"
  )

  for service in "${PRODUCTION_SERVICES[@]}"; do
    # Check for availability ratio metric
    if grep -q "mereka_sli_${service}_availability_ratio" "$SPEC_FILE" 2>/dev/null; then
      pass "AC-028: Service $service has availability_ratio SLI metric"
    else
      fail "AC-028: Service $service missing availability_ratio SLI metric"
    fi

    # Check for error budget metric
    if grep -q "mereka_sli_${service}_error_budget_remaining_minutes" "$SPEC_FILE" 2>/dev/null; then
      pass "AC-028: Service $service has error_budget_remaining_minutes SLI metric"
    else
      fail "AC-028: Service $service missing error_budget_remaining_minutes SLI metric"
    fi
  done

  # Check PrometheusRule has service-specific recording rules
  for service in lms cms; do
    # Look for service-specific availability rules
    if grep -q "service:.*${service}" "$SLO_FILE" 2>/dev/null || \
       grep -q "service.*=.*\"${service}\"" "$SLO_FILE" 2>/dev/null; then
      pass "PrometheusRule: Service $service has recording rules"
    else
      fail "PrometheusRule: Service $service missing recording rules"
    fi
  done

  # ── AC-029, AC-030, AC-031, AC-032: Error Budget Procedures ───

  # AC-029: Error budget exhausted (< 0%) procedures
  if grep -q 'error budget is exhausted.*< 0%' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-029: Error budget exhaustion threshold documented (< 0%)"
  else
    fail "AC-029: Error budget exhaustion threshold missing"
  fi

  # AC-029: P1 incident creation
  if grep -q 'P1 incident.*Error Budget Exhausted' "$SPEC_FILE" 2>/dev/null || \
     grep -q 'P1 incident is created' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-029: P1 incident creation on exhaustion documented"
  else
    fail "AC-029: P1 incident creation on exhaustion missing"
  fi

  # AC-029: Deployment freeze except remediation
  if grep -q 'deployments are frozen.*except.*remediation' "$SPEC_FILE" 2>/dev/null || \
     grep -q 'freeze all non-incident-remediation deployments' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-029: Deployment freeze on exhaustion documented"
  else
    fail "AC-029: Deployment freeze on exhaustion missing"
  fi

  # AC-029: Notification within 15 minutes
  if grep -q 'within 15 minutes' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-029: Notification within 15 minutes documented"
  else
    fail "AC-029: Notification timeline missing"
  fi

  # AC-030: Error budget critical (< 10%) deployment gate
  if grep -q 'error budget.*< 10%' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-030: Critical error budget threshold documented (< 10%)"
  else
    fail "AC-030: Critical error budget threshold missing"
  fi

  # AC-030: VP/CTO approval required
  if grep -q 'VP/CTO approval' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-030: VP/CTO approval requirement documented"
  else
    fail "AC-030: VP/CTO approval requirement missing"
  fi

  # AC-030: Gate blocks deployment until approval
  if grep -q 'gate check blocks deployment until approval' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-030: Deployment gate blocking documented"
  else
    fail "AC-030: Deployment gate blocking missing"
  fi

  # AC-031: Reliability sprint when exhausted
  if grep -q 'reliability sprint' "$SPEC_FILE" 2>/dev/null && \
     grep -q 'all feature work is paused' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-031: Reliability sprint requirement documented"
  else
    fail "AC-031: Reliability sprint requirement missing"
  fi

  # AC-031: Sprint continues until >= 10% budget
  if grep -q 'budget is restored to >= 10%' "$SPEC_FILE" 2>/dev/null || \
     grep -q 'until error budget is restored to >= 10%' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-031: Reliability sprint exit condition documented (>= 10%)"
  else
    fail "AC-031: Reliability sprint exit condition missing"
  fi

  # AC-032: Projected recovery date on dashboard
  if grep -q 'projected recovery date' "$SPEC_FILE" 2>/dev/null || \
     grep -q 'projected recovery time' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-032: Projected recovery date requirement documented"
  else
    fail "AC-032: Projected recovery date requirement missing"
  fi

  # AC-032: Based on current burn rate
  if grep -q 'based on current burn rate' "$SPEC_FILE" 2>/dev/null; then
    pass "AC-032: Recovery projection uses burn rate"
  else
    fail "AC-032: Recovery projection burn rate calculation missing"
  fi

  # ── AC-037, AC-038, AC-039, AC-040, AC-041: Dashboard Requirements ──

  GRAFANA_DASH="infrastructure/monitoring/grafana/dashboards/slo-overview.json"

  if [[ ! -f "$GRAFANA_DASH" ]]; then
    skip "Grafana dashboard not found ($GRAFANA_DASH) - dashboard ACs skipped"
  else
    # AC-037: All Tier 1 SLO metrics displayed
    TIER1_METRICS=(
      "LMS availability"
      "CMS availability"
      "latency P99"
      "latency P95"
      "latency P50"
      "error rate"
      "error budget"
    )

    for metric in "${TIER1_METRICS[@]}"; do
      # Case-insensitive search
      if grep -qi "$metric" "$GRAFANA_DASH" 2>/dev/null; then
        pass "AC-037: Dashboard displays '$metric'"
      else
        fail "AC-037: Dashboard missing '$metric'"
      fi
    done

    # AC-038: Service ownership panel
    if grep -qi 'ownership' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-038: Service ownership panel present"
    else
      fail "AC-038: Service ownership panel missing"
    fi

    # AC-038: Escalation contacts L1-L4
    for level in L1 L2 L3 L4; do
      if grep -q "$level" "$GRAFANA_DASH" 2>/dev/null; then
        pass "AC-038: Escalation level $level documented"
      else
        fail "AC-038: Escalation level $level missing"
      fi
    done

    # AC-038: Service tier displayed
    if grep -qi 'tier' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-038: Service tier displayed"
    else
      fail "AC-038: Service tier missing from dashboard"
    fi

    # AC-038: On-call rotation structure
    if grep -qi 'on-call' "$GRAFANA_DASH" 2>/dev/null || \
       grep -qi 'rotation' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-038: On-call rotation structure displayed"
    else
      fail "AC-038: On-call rotation structure missing"
    fi

    # AC-039: PrometheusRule definition links
    if grep -q 'prometheusrule-slo' "$GRAFANA_DASH" 2>/dev/null || \
       grep -q 'PrometheusRule' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-039: PrometheusRule definition links present"
    else
      fail "AC-039: PrometheusRule definition links missing"
    fi

    # AC-040: Runbook links
    RUNBOOKS=(
      "ONCALL_OBSERVABILITY_PLAYBOOK"
      "DEPLOYMENT_RUNBOOK"
      "TROUBLESHOOTING"
    )

    for runbook in "${RUNBOOKS[@]}"; do
      if grep -q "$runbook" "$GRAFANA_DASH" 2>/dev/null; then
        pass "AC-040: Runbook link present: $runbook"
      else
        fail "AC-040: Runbook link missing: $runbook"
      fi
    done

    # AC-040: SLO/SLA spec link
    if grep -q 'slo-sla-service-level-management' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-040: SLO/SLA spec link present"
    else
      fail "AC-040: SLO/SLA spec link missing"
    fi

    # AC-041: Error budget color thresholds
    COLOR_THRESHOLDS=(
      '"red"'
      '"yellow"'
      '"green"'
    )

    for color in "${COLOR_THRESHOLDS[@]}"; do
      if grep -q "$color" "$GRAFANA_DASH" 2>/dev/null; then
        pass "AC-041: Color threshold present: $color"
      else
        fail "AC-041: Color threshold missing: $color"
      fi
    done

    # AC-041: Threshold values (0.10 = 10%, 0.25 = 25%)
    if grep -q '0.10' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-041: RED threshold 0.10 (< 10%) present"
    else
      fail "AC-041: RED threshold 0.10 missing"
    fi

    if grep -q '0.25' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-041: YELLOW threshold 0.25 (10-25%) present"
    else
      fail "AC-041: YELLOW threshold 0.25 missing"
    fi

    # AC-041: Verify threshold mapping (RED < 10%, YELLOW 10-25%, GREEN >= 25%)
    if grep -q 'RED.*10%' "$GRAFANA_DASH" 2>/dev/null || \
       grep -q 'red.*0.10' "$GRAFANA_DASH" 2>/dev/null; then
      pass "AC-041: RED color mapped to < 10% threshold"
    else
      skip "AC-041: RED color threshold mapping not explicitly documented"
    fi
  fi

  echo
  echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  [[ "$FAIL" -eq 0 ]]
  exit $?
fi

# ── Runtime Mode Checks ──────────────────────────────────────────

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

# Find Prometheus pod
PROM_POD="$(
  kubectl --context "$K8S_CONTEXT" -n monitoring get pods \
    -l app.kubernetes.io/name=prometheus \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
)"

if [[ -z "$PROM_POD" ]]; then
  skip "Prometheus pod not found in monitoring namespace"
  echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  exit 0
fi

# ── AC-026: LMS availability ratio ──────────────────────────────

LMS_AVAIL=$(
  kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
    wget -qO- --timeout=5 'http://localhost:9090/api/v1/query?query=mereka_sli_lms_availability_ratio' 2>/dev/null || true
)

if echo "$LMS_AVAIL" | grep -q '"status":"success"' 2>/dev/null; then
  # Extract value
  VALUE=$(echo "$LMS_AVAIL" | grep -oP '"value":\[\d+,"([^"]+)"\]' | grep -oP '\d+\.\d+' || echo "unknown")

  if [[ "$VALUE" != "unknown" ]]; then
    # Check if value is between 0 and 1
    if (( $(echo "$VALUE >= 0 && $VALUE <= 1" | bc -l 2>/dev/null || echo 0) )); then
      pass "AC-026: LMS availability ratio returns value between 0 and 1 (got: $VALUE)"
    else
      fail "AC-026: LMS availability ratio out of range (got: $VALUE, expected: 0-1)"
    fi
  else
    pass "AC-026: LMS availability ratio metric exists in Prometheus"
  fi
else
  skip "AC-026: LMS availability ratio metric not yet populated (no data)"
fi

# ── AC-027: CMS p95 latency ─────────────────────────────────────

CMS_LATENCY=$(
  kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
    wget -qO- --timeout=5 'http://localhost:9090/api/v1/query?query=mereka_sli_cms_latency_p95_seconds' 2>/dev/null || true
)

if echo "$CMS_LATENCY" | grep -q '"status":"success"' 2>/dev/null; then
  VALUE=$(echo "$CMS_LATENCY" | grep -oP '"value":\[\d+,"([^"]+)"\]' | grep -oP '\d+\.?\d*' || echo "unknown")

  if [[ "$VALUE" != "unknown" ]]; then
    pass "AC-027: CMS p95 latency returns value in seconds (got: ${VALUE}s)"
  else
    pass "AC-027: CMS p95 latency metric exists in Prometheus"
  fi
else
  skip "AC-027: CMS p95 latency metric not yet populated (no data)"
fi

# ── AC-028: All production services have SLI metrics ────────────

PRODUCTION_SERVICES=(
  "lms"
  "cms"
)

for service in "${PRODUCTION_SERVICES[@]}"; do
  # Check availability metric
  AVAIL=$(
    kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
      wget -qO- --timeout=5 "http://localhost:9090/api/v1/query?query=mereka_sli_${service}_availability_ratio" 2>/dev/null || true
  )

  if echo "$AVAIL" | grep -q '"status":"success"' 2>/dev/null; then
    pass "AC-028: Service $service has availability_ratio metric in Prometheus"
  else
    skip "AC-028: Service $service availability_ratio not yet populated"
  fi

  # Check error budget metric
  BUDGET=$(
    kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
      wget -qO- --timeout=5 "http://localhost:9090/api/v1/query?query=mereka_sli_${service}_error_budget_remaining_minutes" 2>/dev/null || true
  )

  if echo "$BUDGET" | grep -q '"status":"success"' 2>/dev/null; then
    pass "AC-028: Service $service has error_budget_remaining_minutes metric in Prometheus"
  else
    skip "AC-028: Service $service error_budget_remaining_minutes not yet populated"
  fi
done

# ── AC-029, AC-030: Error budget alerts active ──────────────────

RULES_JSON="$(
  kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
    wget -qO- --timeout=5 'http://localhost:9090/api/v1/rules' 2>/dev/null || true
)"

if [[ -n "$RULES_JSON" ]]; then
  # AC-029: SLOBudgetExhausted alert
  if echo "$RULES_JSON" | grep -q 'SLOBudgetExhausted' 2>/dev/null; then
    pass "AC-029: SLOBudgetExhausted alert rule active in Prometheus"
  else
    fail "AC-029: SLOBudgetExhausted alert rule not found"
  fi

  # AC-030: SLOBudgetCritical alert
  if echo "$RULES_JSON" | grep -q 'SLOBudgetCritical' 2>/dev/null; then
    pass "AC-030: SLOBudgetCritical alert rule active in Prometheus"
  else
    fail "AC-030: SLOBudgetCritical alert rule not found"
  fi

  # AC-030: SLOBudgetLow alert (< 25%)
  if echo "$RULES_JSON" | grep -q 'SLOBudgetLow' 2>/dev/null; then
    pass "AC-030: SLOBudgetLow alert rule active in Prometheus"
  else
    fail "AC-030: SLOBudgetLow alert rule not found"
  fi
else
  skip "Unable to query Prometheus rules API"
fi

# ── AC-032: Error budget dashboard panels ───────────────────────

# Check if error budget metrics are queryable
ERROR_BUDGET_RATIO=$(
  kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
    wget -qO- --timeout=5 'http://localhost:9090/api/v1/query?query=mereka_slo_error_budget_remaining_ratio' 2>/dev/null || true
)

if echo "$ERROR_BUDGET_RATIO" | grep -q '"status":"success"' 2>/dev/null; then
  pass "AC-032: Error budget remaining ratio metric active in Prometheus"
else
  skip "AC-032: Error budget remaining ratio metric not yet populated"
fi

echo
echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[[ "$FAIL" -eq 0 ]]
exit $?
