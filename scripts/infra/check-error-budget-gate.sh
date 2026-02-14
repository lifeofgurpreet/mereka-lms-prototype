#!/usr/bin/env bash
# @spec: slo-sla-service-level-management_spec.md
# @covers AC-010, AC-011, AC-012
#
# Check error budget status and gate deployments based on remaining budget.
#
# Queries mereka:slo:error_budget_remaining_ratio for all Tier 1 services
# and returns the deployment policy:
#
#   >= 0.50  -> PASS   (Normal: deploy freely)
#   0.25-0.49 -> WARN  (Cautious: engineering lead approval)
#   0.10-0.24 -> BLOCK (Restricted: engineering lead + product approval)
#   < 0.10   -> FREEZE (Frozen: VP/CTO approval only)
#
# Usage:
#   ./scripts/infra/check-error-budget-gate.sh
#   ./scripts/infra/check-error-budget-gate.sh --prometheus-url http://localhost:9090
#   ./scripts/infra/check-error-budget-gate.sh --skip-prometheus
#   ./scripts/infra/check-error-budget-gate.sh --override --approver "jane" --justification "hotfix for P1"
set -euo pipefail

PROMETHEUS_URL="${PROMETHEUS_URL:-http://prometheus.mereka.dev}"
SKIP_PROMETHEUS=false
OVERRIDE=false
APPROVER=""
JUSTIFICATION=""
SERVICE_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prometheus-url) PROMETHEUS_URL="$2"; shift 2 ;;
    --skip-prometheus) SKIP_PROMETHEUS=true; shift ;;
    --override) OVERRIDE=true; shift ;;
    --approver) APPROVER="$2"; shift 2 ;;
    --justification) JUSTIFICATION="$2"; shift 2 ;;
    --service) SERVICE_FILTER="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--prometheus-url URL] [--skip-prometheus] [--override --approver NAME --justification REASON]"
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ── Structured logging helper ────────────────────────────────────
log_decision() {
  local service="$1" budget_pct="$2" decision="$3" approver_val="${4:-}"
  printf '{"event":"deployment_gate_decision","service":"%s","budget_remaining_pct":%s,"decision":"%s","approver":"%s","timestamp":"%s"}\n' \
    "$service" "$budget_pct" "$decision" "$approver_val" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
}

# ── Skip mode (offline / no Prometheus) ──────────────────────────
if [[ "$SKIP_PROMETHEUS" == "true" ]]; then
  echo "[SKIP] Prometheus query skipped (--skip-prometheus)"
  echo "Decision: SKIP (offline mode, no budget data)"
  exit 0
fi

# ── Query Prometheus ─────────────────────────────────────────────
QUERY='mereka:slo:error_budget_remaining_ratio{tier="1"}'
if [[ -n "$SERVICE_FILTER" ]]; then
  QUERY="mereka:slo:error_budget_remaining_ratio{tier=\"1\",service=\"${SERVICE_FILTER}\"}"
fi

RESPONSE=$(curl -sf --max-time 10 \
  "${PROMETHEUS_URL}/api/v1/query" \
  --data-urlencode "query=${QUERY}" 2>/dev/null) || {
  echo "[WARN] Cannot reach Prometheus at ${PROMETHEUS_URL}" >&2
  echo "Decision: SKIP (Prometheus unreachable)"
  exit 0
}

# Parse results
RESULT_COUNT=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
print(len(results))
" 2>/dev/null || echo "0")

if [[ "$RESULT_COUNT" == "0" ]]; then
  echo "[WARN] No error budget data returned from Prometheus"
  echo "Decision: SKIP (no data — metrics may need 30d to populate)"
  exit 0
fi

# Find the minimum error budget across all Tier 1 services
MIN_BUDGET=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('data', {}).get('result', [])
min_val = 1.0
min_svc = 'unknown'
for r in results:
    val = float(r['value'][1])
    svc = r['metric'].get('service', 'unknown')
    print(f'  {svc}: {val*100:.1f}% remaining')
    if val < min_val:
        min_val = val
        min_svc = svc
print(f'MINIMUM={min_val:.4f}')
print(f'MIN_SERVICE={min_svc}')
" 2>/dev/null)

echo "Error Budget Status (Tier 1):"
echo "$MIN_BUDGET" | grep -E '^\s' || true

MIN_VALUE=$(echo "$MIN_BUDGET" | grep '^MINIMUM=' | cut -d= -f2)
MIN_SERVICE=$(echo "$MIN_BUDGET" | grep '^MIN_SERVICE=' | cut -d= -f2)

if [[ -z "$MIN_VALUE" ]]; then
  echo "[WARN] Could not parse error budget value"
  echo "Decision: SKIP (parse error)"
  exit 0
fi

# ── Determine deployment policy ──────────────────────────────────
MIN_PCT=$(python3 -c "print(f'{float(\"$MIN_VALUE\")*100:.1f}')")

# Use python for float comparison
DECISION=$(python3 -c "
v = float('$MIN_VALUE')
if v >= 0.50:
    print('PASS')
elif v >= 0.25:
    print('WARN')
elif v >= 0.10:
    print('BLOCK')
else:
    print('FREEZE')
")

echo ""
echo "Lowest budget: ${MIN_SERVICE} at ${MIN_PCT}%"

case "$DECISION" in
  PASS)
    echo "Decision: PASS (Normal - deploy freely)"
    log_decision "$MIN_SERVICE" "$MIN_PCT" "allow"
    exit 0
    ;;
  WARN)
    echo "Decision: WARN (Cautious - requires engineering lead approval)"
    if [[ "$OVERRIDE" == "true" && -n "$APPROVER" && -n "$JUSTIFICATION" ]]; then
      echo "Override: approved by ${APPROVER} — ${JUSTIFICATION}"
      log_decision "$MIN_SERVICE" "$MIN_PCT" "override" "$APPROVER"
      exit 0
    fi
    log_decision "$MIN_SERVICE" "$MIN_PCT" "warn"
    exit 1
    ;;
  BLOCK)
    echo "Decision: BLOCK (Restricted - requires engineering lead + product approval)"
    if [[ "$OVERRIDE" == "true" && -n "$APPROVER" && -n "$JUSTIFICATION" ]]; then
      echo "Override: approved by ${APPROVER} — ${JUSTIFICATION}"
      log_decision "$MIN_SERVICE" "$MIN_PCT" "override" "$APPROVER"
      exit 0
    fi
    log_decision "$MIN_SERVICE" "$MIN_PCT" "block"
    exit 2
    ;;
  FREEZE)
    echo "Decision: FREEZE (Frozen - VP/CTO approval required, incident remediation only)"
    if [[ "$OVERRIDE" == "true" && -n "$APPROVER" && -n "$JUSTIFICATION" ]]; then
      echo "Override: approved by ${APPROVER} — ${JUSTIFICATION}"
      log_decision "$MIN_SERVICE" "$MIN_PCT" "override" "$APPROVER"
      exit 0
    fi
    log_decision "$MIN_SERVICE" "$MIN_PCT" "freeze"
    exit 3
    ;;
esac
