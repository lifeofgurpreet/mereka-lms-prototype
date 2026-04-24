#!/usr/bin/env bash
# @covers AC-008, AC-037, AC-038, AC-039, AC-040, AC-041, AC-DRILL-006
# @spec: slo-sla-service-level-management_spec.md
# Verify SLO dashboard JSON files exist and contain required panels.
#
# Checks:
# - Grafana SLO overview dashboard exists with required panels
# - GCP Cloud Monitoring SLO dashboard exists with required widgets
# - Error budget panels use correct color thresholds
# - Service ownership panel present
# - Runbook links present
# - PrometheusRule definition links present
# - Alert Delivery Drills panel present
#
# Usage:
#   ./scripts/qa/verify-slo-dashboards.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PASS=0
FAIL=0
SKIP=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }
skip() { echo "[SKIP] $1"; SKIP=$((SKIP + 1)); }

# ── Grafana Dashboard ────────────────────────────────────────────
GRAFANA_DASH="infrastructure/monitoring/grafana/dashboards/slo-overview.json"

if [[ -f "$GRAFANA_DASH" ]]; then
  pass "Grafana SLO overview dashboard exists ($GRAFANA_DASH)"
else
  fail "Grafana SLO overview dashboard missing ($GRAFANA_DASH)"
  echo "  Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  exit 1
fi

# Valid JSON
if python3 -c "import json; json.load(open('$GRAFANA_DASH'))" 2>/dev/null; then
  pass "Grafana dashboard is valid JSON"
else
  fail "Grafana dashboard is not valid JSON"
fi

# UID matches spec
if grep -q '"uid": "mereka-slo-overview"' "$GRAFANA_DASH" 2>/dev/null; then
  pass "Dashboard UID is mereka-slo-overview"
else
  fail "Dashboard UID is not mereka-slo-overview"
fi

# AC-008: Required panels - availability ratio per service
if grep -q 'availability_ratio' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-008: Availability ratio panel present"
else
  fail "AC-008: Availability ratio panel missing"
fi

# AC-008: Error budget remaining
if grep -q 'error_budget_remaining' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-008: Error budget remaining panel present"
else
  fail "AC-008: Error budget remaining panel missing"
fi

# AC-008: Burn rate trend
if grep -q 'burn_rate' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-008: Burn rate trend panel present"
else
  fail "AC-008: Burn rate trend panel missing"
fi

# AC-008: Latency percentiles (p50, p95, p99)
for pct in p50 p95 p99; do
  if grep -q "http_request_duration:${pct}_5m" "$GRAFANA_DASH" 2>/dev/null; then
    pass "AC-008: Latency ${pct} panel present"
  else
    fail "AC-008: Latency ${pct} panel missing"
  fi
done

# AC-037: All Tier 1 SLO metrics shown
for svc in lms cms; do
  if grep -q "service=.*${svc}" "$GRAFANA_DASH" 2>/dev/null; then
    pass "AC-037: Service ${svc} represented in dashboard"
  else
    fail "AC-037: Service ${svc} missing from dashboard"
  fi
done

# AC-038: Service ownership panel with escalation contacts
if grep -qi 'ownership' "$GRAFANA_DASH" 2>/dev/null && grep -qi 'escalation' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-038: Service ownership and escalation panel present"
else
  fail "AC-038: Service ownership/escalation panel missing"
fi

# Check escalation levels L1-L4
for level in L1 L2 L3 L4; do
  if grep -q "$level" "$GRAFANA_DASH" 2>/dev/null; then
    pass "AC-038: Escalation level $level documented"
  else
    fail "AC-038: Escalation level $level missing"
  fi
done

# AC-039: Links to PrometheusRule definitions
if grep -q 'prometheusrule-slo' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-039: Link to PrometheusRule definitions present"
else
  fail "AC-039: Link to PrometheusRule definitions missing"
fi

# AC-040: Links to runbooks
for runbook in "ONCALL_OBSERVABILITY_PLAYBOOK" "DEPLOYMENT_RUNBOOK" "TROUBLESHOOTING"; do
  if grep -q "$runbook" "$GRAFANA_DASH" 2>/dev/null; then
    pass "AC-040: Runbook link present: $runbook"
  else
    fail "AC-040: Runbook link missing: $runbook"
  fi
done

# AC-040: Link to SLO/SLA spec
if grep -q 'slo-sla-service-level-management' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-040: SLO/SLA spec link present"
else
  fail "AC-040: SLO/SLA spec link missing"
fi

# AC-041: Error budget panels use color thresholds (RED < 10%, YELLOW 10-25%, GREEN >= 25%)
if grep -q '"red"' "$GRAFANA_DASH" 2>/dev/null && grep -q '"yellow"' "$GRAFANA_DASH" 2>/dev/null && grep -q '"green"' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-041: Error budget color thresholds present (red/yellow/green)"
else
  fail "AC-041: Error budget color thresholds missing"
fi

# Verify threshold values map to spec (0.10 and 0.25 boundaries)
if grep -q '0.10' "$GRAFANA_DASH" 2>/dev/null && grep -q '0.25' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-041: Threshold values 0.10 and 0.25 present"
else
  fail "AC-041: Threshold values 0.10 and/or 0.25 missing"
fi

# AC-DRILL-006: Alert Delivery Drills panel
if grep -q 'Alert Delivery Drills' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-DRILL-006: Alert Delivery Drills panel present"
else
  fail "AC-DRILL-006: Alert Delivery Drills panel missing"
fi

if grep -q 'mereka_alerting_drill_success_total' "$GRAFANA_DASH" 2>/dev/null; then
  pass "AC-DRILL-006: Drill success metric referenced"
else
  fail "AC-DRILL-006: Drill success metric not referenced"
fi

# ── GCP Cloud Monitoring Dashboard ───────────────────────────────
GCP_DASH="infrastructure/monitoring/dashboards/openedx-slo-dashboard.json"

if [[ -f "$GCP_DASH" ]]; then
  pass "GCP SLO dashboard exists ($GCP_DASH)"
else
  skip "GCP SLO dashboard not found ($GCP_DASH) — may use Grafana only"
fi

if [[ -f "$GCP_DASH" ]]; then
  # AC-037: Availability widgets
  if grep -q 'mereka_slo_availability_ratio' "$GCP_DASH" 2>/dev/null; then
    pass "GCP dashboard: availability ratio widget present"
  else
    fail "GCP dashboard: availability ratio widget missing"
  fi

  # Error budget widgets
  if grep -q 'mereka_slo_error_budget_remaining' "$GCP_DASH" 2>/dev/null; then
    pass "GCP dashboard: error budget widget present"
  else
    fail "GCP dashboard: error budget widget missing"
  fi

  # Ownership panel
  if grep -q 'Service Ownership' "$GCP_DASH" 2>/dev/null; then
    pass "GCP dashboard: ownership panel present"
  else
    fail "GCP dashboard: ownership panel missing"
  fi
fi

echo
echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[[ "$FAIL" -eq 0 ]]
exit $?
