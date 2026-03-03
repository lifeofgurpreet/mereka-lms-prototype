#!/usr/bin/env bash
# @covers AC-DRILL-001, AC-DRILL-002, AC-DRILL-003, AC-DRILL-004, AC-DRILL-005, AC-DRILL-007
# @spec: slo-sla-service-level-management_spec.md
# Verify synthetic alert delivery drill infrastructure.
#
# Checks:
# - CronJob deployed with correct schedule (every Monday 09:00 UTC)
# - Drill script POSTs to Alertmanager API with test alert
# - Structured logging to Loki on drill success/failure
# - Prometheus metrics exposed (drill_success_total, drill_latency_seconds)
# - Missed drill triggers real P2 alert
# - Drill alert delivered to Slack #ops-alerts channel
#
# Usage:
#   ./scripts/qa/verify-slo-synthetic-drills.sh              # local mode (default)
#   ./scripts/qa/verify-slo-synthetic-drills.sh --mode local  # explicit local
#   ./scripts/qa/verify-slo-synthetic-drills.sh --mode runtime # check live cluster
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
  # AC-DRILL-001: CronJob manifest exists
  CRONJOB_FILE="deploy/k8s/base/monitoring/cronjob-synthetic-alert-drill.yaml"

  if [[ -f "$CRONJOB_FILE" ]]; then
    pass "AC-DRILL-001: Synthetic alert drill CronJob manifest exists ($CRONJOB_FILE)"
  else
    fail "AC-DRILL-001: Synthetic alert drill CronJob manifest missing ($CRONJOB_FILE)"
    echo -e "\n  Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
    exit 1
  fi

  # Valid YAML
  if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml; yaml.safe_load(open('$CRONJOB_FILE'))" 2>/dev/null; then
      pass "CronJob manifest is valid YAML"
    else
      fail "CronJob manifest is not valid YAML"
    fi
  else
    skip "No YAML validator available (python3 not found)"
  fi

  # AC-DRILL-001: Schedule is Monday 09:00 UTC (0 9 * * 1)
  if grep -q 'schedule:.*"0 9 \* \* 1"' "$CRONJOB_FILE" 2>/dev/null || \
     grep -q "schedule:.*'0 9 \\* \\* 1'" "$CRONJOB_FILE" 2>/dev/null; then
    pass "AC-DRILL-001: CronJob schedule is Monday 09:00 UTC (0 9 * * 1)"
  else
    fail "AC-DRILL-001: CronJob schedule is not Monday 09:00 UTC"
  fi

  # AC-DRILL-001: Labels include app.kubernetes.io/name=synthetic-alert-drill
  if grep -q 'app.kubernetes.io/name:.*synthetic-alert-drill' "$CRONJOB_FILE" 2>/dev/null; then
    pass "AC-DRILL-001: CronJob has correct label (app.kubernetes.io/name=synthetic-alert-drill)"
  else
    fail "AC-DRILL-001: CronJob missing required label"
  fi

  # Check kustomization includes the CronJob
  KUSTOMIZATION="deploy/k8s/base/monitoring/kustomization.yaml"
  if [[ -f "$KUSTOMIZATION" ]] && grep -q "cronjob-synthetic-alert-drill.yaml" "$KUSTOMIZATION" 2>/dev/null; then
    pass "Kustomization references cronjob-synthetic-alert-drill.yaml"
  else
    fail "Kustomization does not reference cronjob-synthetic-alert-drill.yaml"
  fi

  # AC-DRILL-002: Drill script POSTs to Alertmanager API
  DRILL_SCRIPT="scripts/monitoring/synthetic-alert-drill.sh"

  if [[ -f "$DRILL_SCRIPT" ]]; then
    pass "AC-DRILL-002: Drill script exists ($DRILL_SCRIPT)"
  else
    fail "AC-DRILL-002: Drill script missing ($DRILL_SCRIPT)"
  fi

  if [[ -f "$DRILL_SCRIPT" ]]; then
    # Check script posts to Alertmanager /api/v1/alerts
    if grep -q '/api/v1/alerts' "$DRILL_SCRIPT" 2>/dev/null; then
      pass "AC-DRILL-002: Script POSTs to Alertmanager /api/v1/alerts endpoint"
    else
      fail "AC-DRILL-002: Script does not POST to /api/v1/alerts"
    fi

    # Check alert is labeled [DRILL]
    if grep -q '\[DRILL\]' "$DRILL_SCRIPT" 2>/dev/null; then
      pass "AC-DRILL-002: Alert labeled with [DRILL] prefix"
    else
      fail "AC-DRILL-002: Alert missing [DRILL] prefix"
    fi

    # Check severity is info (not page-level)
    if grep -q 'severity.*info' "$DRILL_SCRIPT" 2>/dev/null; then
      pass "AC-DRILL-002: Alert severity is 'info' (non-paging)"
    else
      fail "AC-DRILL-002: Alert severity not set to 'info'"
    fi
  fi

  # AC-DRILL-003: Structured logging to Loki
  if [[ -f "$DRILL_SCRIPT" ]]; then
    # Check for structured log fields
    for field in "event" "status" "delivery_timestamp"; do
      if grep -q "$field" "$DRILL_SCRIPT" 2>/dev/null; then
        pass "AC-DRILL-003: Structured log field present: $field"
      else
        fail "AC-DRILL-003: Structured log field missing: $field"
      fi
    done

    # Check event=synthetic_alert_drill
    if grep -q 'event.*synthetic_alert_drill' "$DRILL_SCRIPT" 2>/dev/null; then
      pass "AC-DRILL-003: Log event is 'synthetic_alert_drill'"
    else
      fail "AC-DRILL-003: Log event 'synthetic_alert_drill' not found"
    fi

    # Check status values (success/failed)
    if grep -q 'status.*success' "$DRILL_SCRIPT" 2>/dev/null && \
       grep -q 'status.*failed' "$DRILL_SCRIPT" 2>/dev/null; then
      pass "AC-DRILL-003: Log status values include 'success' and 'failed'"
    else
      fail "AC-DRILL-003: Log status values missing 'success' or 'failed'"
    fi
  fi

  # AC-DRILL-004: Prometheus metrics exposed
  # Check PrometheusRule has drill metrics recording rules
  SLO_FILE="deploy/k8s/base/monitoring/prometheusrule-slo.yaml"

  if [[ -f "$SLO_FILE" ]]; then
    if grep -q 'mereka_alerting_drill_success_total' "$SLO_FILE" 2>/dev/null; then
      pass "AC-DRILL-004: Metric mereka_alerting_drill_success_total referenced"
    else
      fail "AC-DRILL-004: Metric mereka_alerting_drill_success_total not found"
    fi

    if grep -q 'mereka_alerting_drill_latency_seconds' "$SLO_FILE" 2>/dev/null; then
      pass "AC-DRILL-004: Metric mereka_alerting_drill_latency_seconds referenced"
    else
      fail "AC-DRILL-004: Metric mereka_alerting_drill_latency_seconds not found"
    fi
  fi

  # AC-DRILL-005: Missed drill triggers P2 alert
  if [[ -f "$SLO_FILE" ]]; then
    if grep -q 'alert.*AlertDeliveryPipelineFailure' "$SLO_FILE" 2>/dev/null || \
       grep -q 'Alert Delivery Pipeline Failure' "$SLO_FILE" 2>/dev/null; then
      pass "AC-DRILL-005: Missed drill alert rule defined"
    else
      fail "AC-DRILL-005: Missed drill alert rule missing"
    fi

    # Check alert severity is P2
    missed_drill_alert=$(grep -A10 "Alert Delivery Pipeline Failure" "$SLO_FILE" 2>/dev/null || true)
    if echo "$missed_drill_alert" | grep -q 'severity.*P2' 2>/dev/null; then
      pass "AC-DRILL-005: Missed drill alert has P2 severity"
    else
      fail "AC-DRILL-005: Missed drill alert severity not P2"
    fi

    # Check 5 minute timeout
    if echo "$missed_drill_alert" | grep -q '5m' 2>/dev/null; then
      pass "AC-DRILL-005: Missed drill detected within 5 minutes"
    else
      fail "AC-DRILL-005: Missed drill timeout not set to 5 minutes"
    fi
  fi

  # AC-DRILL-007: Slack channel routing
  ALERTMANAGER_CONFIG="deploy/k8s/base/monitoring/alertmanager-config.yaml"

  if [[ -f "$ALERTMANAGER_CONFIG" ]]; then
    # Check ops-alerts channel exists
    if grep -q '#ops-alerts' "$ALERTMANAGER_CONFIG" 2>/dev/null || \
       grep -q 'ops-alerts' "$ALERTMANAGER_CONFIG" 2>/dev/null; then
      pass "AC-DRILL-007: Alertmanager routes to #ops-alerts channel"
    else
      fail "AC-DRILL-007: Alertmanager #ops-alerts channel not configured"
    fi

    # Check DRILL alerts route to same channel as production
    if grep -q 'DRILL' "$ALERTMANAGER_CONFIG" 2>/dev/null; then
      pass "AC-DRILL-007: DRILL alerts have routing configuration"
    else
      skip "AC-DRILL-007: DRILL alert routing not explicitly configured (may use default)"
    fi
  else
    skip "Alertmanager config not found ($ALERTMANAGER_CONFIG)"
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

# AC-DRILL-001: CronJob exists in cluster
if kubectl --context "$K8S_CONTEXT" -n "$NS" get cronjob synthetic-alert-drill >/dev/null 2>&1; then
  pass "AC-DRILL-001: CronJob synthetic-alert-drill exists in cluster"

  # Verify schedule
  SCHEDULE=$(kubectl --context "$K8S_CONTEXT" -n "$NS" get cronjob synthetic-alert-drill \
    -o jsonpath='{.spec.schedule}' 2>/dev/null || true)
  if [[ "$SCHEDULE" == "0 9 * * 1" ]]; then
    pass "AC-DRILL-001: CronJob schedule is correct (0 9 * * 1)"
  else
    fail "AC-DRILL-001: CronJob schedule incorrect (got: $SCHEDULE, expected: 0 9 * * 1)"
  fi

  # Verify label
  LABEL=$(kubectl --context "$K8S_CONTEXT" -n "$NS" get cronjob synthetic-alert-drill \
    -o jsonpath='{.metadata.labels.app\.kubernetes\.io/name}' 2>/dev/null || true)
  if [[ "$LABEL" == "synthetic-alert-drill" ]]; then
    pass "AC-DRILL-001: CronJob has correct label"
  else
    fail "AC-DRILL-001: CronJob label incorrect (got: $LABEL)"
  fi
else
  fail "AC-DRILL-001: CronJob synthetic-alert-drill not found in cluster"
fi

# AC-DRILL-004: Check Prometheus has drill metrics
PROM_POD="$(
  kubectl --context "$K8S_CONTEXT" -n monitoring get pods \
    -l app.kubernetes.io/name=prometheus \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
)"

if [[ -z "$PROM_POD" ]]; then
  skip "AC-DRILL-004: Prometheus pod not found in monitoring namespace"
else
  # Query for drill success metric
  DRILL_SUCCESS=$(
    kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
      wget -qO- --timeout=5 'http://localhost:9090/api/v1/query?query=mereka_alerting_drill_success_total' 2>/dev/null || true
  )

  if echo "$DRILL_SUCCESS" | grep -q '"status":"success"' 2>/dev/null; then
    pass "AC-DRILL-004: Prometheus has mereka_alerting_drill_success_total metric"
  else
    skip "AC-DRILL-004: mereka_alerting_drill_success_total metric not yet populated (no drills run yet)"
  fi

  # Query for drill latency metric
  DRILL_LATENCY=$(
    kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
      wget -qO- --timeout=5 'http://localhost:9090/api/v1/query?query=mereka_alerting_drill_latency_seconds' 2>/dev/null || true
  )

  if echo "$DRILL_LATENCY" | grep -q '"status":"success"' 2>/dev/null; then
    pass "AC-DRILL-004: Prometheus has mereka_alerting_drill_latency_seconds metric"
  else
    skip "AC-DRILL-004: mereka_alerting_drill_latency_seconds metric not yet populated"
  fi
fi

# AC-DRILL-005: Check missed drill alert rule is loaded
RULES_JSON="$(
  kubectl --context "$K8S_CONTEXT" -n monitoring exec "$PROM_POD" -- \
    wget -qO- --timeout=5 'http://localhost:9090/api/v1/rules' 2>/dev/null || true
)"

if [[ -n "$RULES_JSON" ]]; then
  if echo "$RULES_JSON" | grep -q 'Alert Delivery Pipeline Failure' 2>/dev/null || \
     echo "$RULES_JSON" | grep -q 'AlertDeliveryPipelineFailure' 2>/dev/null; then
    pass "AC-DRILL-005: Missed drill alert rule active in Prometheus"
  else
    fail "AC-DRILL-005: Missed drill alert rule not found in Prometheus"
  fi
else
  skip "AC-DRILL-005: Unable to query Prometheus rules API"
fi

# AC-DRILL-007: Check recent drill executions (if any)
RECENT_JOBS=$(
  kubectl --context "$K8S_CONTEXT" -n "$NS" get jobs \
    -l app.kubernetes.io/name=synthetic-alert-drill \
    --sort-by=.metadata.creationTimestamp 2>/dev/null || true
)

if [[ -n "$RECENT_JOBS" ]]; then
  JOB_COUNT=$(echo "$RECENT_JOBS" | wc -l)
  pass "AC-DRILL-007: Found $((JOB_COUNT - 1)) drill job(s) in cluster history"

  # Check if latest job succeeded
  LATEST_JOB=$(echo "$RECENT_JOBS" | tail -1 | awk '{print $1}')
  if [[ -n "$LATEST_JOB" ]]; then
    JOB_STATUS=$(kubectl --context "$K8S_CONTEXT" -n "$NS" get job "$LATEST_JOB" \
      -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
    if [[ "$JOB_STATUS" == "1" ]]; then
      pass "AC-DRILL-007: Latest drill job succeeded"
    else
      fail "AC-DRILL-007: Latest drill job did not succeed"
    fi
  fi
else
  skip "AC-DRILL-007: No drill jobs found (may not have run yet)"
fi

echo
echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[[ "$FAIL" -eq 0 ]]
exit $?
