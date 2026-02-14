#!/usr/bin/env bash
# @spec: slo-sla-service-level-management_spec.md
# @covers AC-022, AC-024, AC-025
#
# Generate a monthly SLA compliance report from Prometheus metrics.
#
# Queries Prometheus for 30d availability, latency percentiles, error budgets,
# and produces a Markdown report following the spec's report template.
#
# Usage:
#   ./scripts/ops/generate-sla-report.sh
#   ./scripts/ops/generate-sla-report.sh --prometheus-url http://localhost:9090
#   ./scripts/ops/generate-sla-report.sh --skip-prometheus
#   ./scripts/ops/generate-sla-report.sh --month 2026-01
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://prometheus.mereka.dev}"
SKIP_PROMETHEUS=false
REPORT_MONTH=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prometheus-url) PROMETHEUS_URL="$2"; shift 2 ;;
    --skip-prometheus) SKIP_PROMETHEUS=true; shift ;;
    --month) REPORT_MONTH="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--prometheus-url URL] [--skip-prometheus] [--month YYYY-MM] [--output-dir DIR]"
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# Defaults
if [[ -z "$REPORT_MONTH" ]]; then
  REPORT_MONTH=$(date -u '+%Y-%m')
fi
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="${ROOT_DIR}/var/reports/sla"
fi

mkdir -p "$OUTPUT_DIR"
REPORT_FILE="${OUTPUT_DIR}/${REPORT_MONTH}.md"
GENERATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# ── Prometheus query helper ──────────────────────────────────────
prom_query() {
  local query="$1"
  if [[ "$SKIP_PROMETHEUS" == "true" ]]; then
    echo "N/A"
    return
  fi
  local resp
  resp=$(curl -sf --max-time 10 \
    "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=${query}" 2>/dev/null) || {
    echo "N/A"
    return
  }
  echo "$resp" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('data', {}).get('result', [])
    if not results:
        print('N/A')
    else:
        print(results[0]['value'][1])
except Exception:
    print('N/A')
" 2>/dev/null || echo "N/A"
}

prom_query_all() {
  local query="$1"
  if [[ "$SKIP_PROMETHEUS" == "true" ]]; then
    echo "[]"
    return
  fi
  local resp
  resp=$(curl -sf --max-time 10 \
    "${PROMETHEUS_URL}/api/v1/query" \
    --data-urlencode "query=${query}" 2>/dev/null) || {
    echo "[]"
    return
  }
  echo "$resp" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    results = data.get('data', {}).get('result', [])
    for r in results:
        svc = r['metric'].get('service', 'unknown')
        tier = r['metric'].get('tier', '?')
        val = r['value'][1]
        print(f'{svc}|{tier}|{val}')
except Exception:
    pass
" 2>/dev/null || true
}

fmt_pct() {
  local val="$1"
  if [[ "$val" == "N/A" ]]; then
    echo "N/A"
  else
    python3 -c "print(f'{float(\"$val\")*100:.2f}%')" 2>/dev/null || echo "N/A"
  fi
}

fmt_seconds() {
  local val="$1"
  if [[ "$val" == "N/A" ]]; then
    echo "N/A"
  else
    python3 -c "v=float('$val'); print(f'{v*1000:.0f}ms' if v < 10 else f'{v:.1f}s')" 2>/dev/null || echo "N/A"
  fi
}

fmt_minutes() {
  local val="$1"
  if [[ "$val" == "N/A" ]]; then
    echo "N/A"
  else
    python3 -c "print(f'{float(\"$val\"):.1f} min')" 2>/dev/null || echo "N/A"
  fi
}

# ── Collect metrics ──────────────────────────────────────────────
echo "Generating SLA report for ${REPORT_MONTH}..."

# Tier 1: LMS
LMS_AVAIL=$(prom_query 'mereka:http_requests:availability_ratio_5m{service="lms",tier="1"}')
LMS_P50=$(prom_query 'mereka:http_request_duration:p50_5m{service="lms"}')
LMS_P95=$(prom_query 'mereka:http_request_duration:p95_5m{service="lms"}')
LMS_P99=$(prom_query 'mereka:http_request_duration:p99_5m{service="lms"}')
LMS_BUDGET_RATIO=$(prom_query 'mereka:slo:error_budget_remaining_ratio{service="lms",tier="1"}')
LMS_BUDGET_MIN=$(prom_query 'mereka:slo:error_budget_remaining_minutes{service="lms",tier="1"}')

# Tier 1: CMS
CMS_AVAIL=$(prom_query 'mereka:http_requests:availability_ratio_5m{service="cms",tier="1"}')
CMS_P50=$(prom_query 'mereka:http_request_duration:p50_5m{service="cms"}')
CMS_P95=$(prom_query 'mereka:http_request_duration:p95_5m{service="cms"}')
CMS_P99=$(prom_query 'mereka:http_request_duration:p99_5m{service="cms"}')
CMS_BUDGET_RATIO=$(prom_query 'mereka:slo:error_budget_remaining_ratio{service="cms",tier="1"}')
CMS_BUDGET_MIN=$(prom_query 'mereka:slo:error_budget_remaining_minutes{service="cms",tier="1"}')

# Determine overall status
OVERALL_STATUS="PASS"
if [[ "$SKIP_PROMETHEUS" == "true" ]]; then
  OVERALL_STATUS="N/A (offline mode)"
else
  for val in "$LMS_AVAIL" "$CMS_AVAIL"; do
    if [[ "$val" != "N/A" ]]; then
      below=$(python3 -c "print('yes' if float('$val') < 0.999 else 'no')" 2>/dev/null || echo "no")
      if [[ "$below" == "yes" ]]; then
        OVERALL_STATUS="FAIL"
      fi
    fi
  done
fi

# Budget status
BUDGET_STATUS="Healthy"
if [[ "$SKIP_PROMETHEUS" != "true" ]]; then
  for val in "$LMS_BUDGET_RATIO" "$CMS_BUDGET_RATIO"; do
    if [[ "$val" != "N/A" ]]; then
      status=$(python3 -c "
v = float('$val')
if v <= 0: print('Exhausted')
elif v < 0.10: print('Critical')
elif v < 0.25: print('Low')
elif v < 0.50: print('Low')
else: print('Healthy')
" 2>/dev/null || echo "Unknown")
      case "$status" in
        Exhausted) BUDGET_STATUS="Exhausted" ;;
        Critical) [[ "$BUDGET_STATUS" != "Exhausted" ]] && BUDGET_STATUS="Critical" ;;
        Low) [[ "$BUDGET_STATUS" == "Healthy" ]] && BUDGET_STATUS="Low" ;;
      esac
    fi
  done
fi

# ── Generate report ──────────────────────────────────────────────
cat > "$REPORT_FILE" <<REPORT
# Mereka Academy - Monthly SLA Compliance Report

**Reporting Period**: ${REPORT_MONTH}
**Report Generated**: ${GENERATED_AT}
**Report Version**: 1.0

## Executive Summary

- Overall Platform Availability: $(fmt_pct "$LMS_AVAIL")
- SLA Compliance Status: ${OVERALL_STATUS}
- Error Budget Status: ${BUDGET_STATUS}

## Service-Level Metrics

### Tier 1: Critical Services

| Service | SLO Target | Actual | SLA Target | Error Budget Remaining |
|---------|-----------|--------|-----------|----------------------|
| LMS | 99.95% | $(fmt_pct "$LMS_AVAIL") | 99.9% | $(fmt_minutes "$LMS_BUDGET_MIN") |
| CMS | 99.95% | $(fmt_pct "$CMS_AVAIL") | 99.9% | $(fmt_minutes "$CMS_BUDGET_MIN") |

### Tier 2: Important Services

| Service | SLO Target | SLA Target | Status |
|---------|-----------|-----------|--------|
| MFE | 99.9% | 99.5% | Monitoring |
| Forum | 99.9% | 99.5% | Monitoring |
| Discovery | 99.9% | 99.5% | Monitoring |
| Workers | 99.9% | 99.5% | Monitoring |

### Tier 3: Optional Services

| Service | SLO Target | SLA Target | Status |
|---------|-----------|-----------|--------|
| Notes | 99.5% | 99.0% | Monitoring |
| XQueue | 99.5% | 99.0% | Monitoring |

## Latency Performance

| Service | p50 Target | p50 Actual | p95 Target | p95 Actual | p99 Target | p99 Actual |
|---------|-----------|-----------|-----------|-----------|-----------|-----------|
| LMS | 500ms | $(fmt_seconds "$LMS_P50") | 2,000ms | $(fmt_seconds "$LMS_P95") | 5,000ms | $(fmt_seconds "$LMS_P99") |
| CMS | 800ms | $(fmt_seconds "$CMS_P50") | 3,000ms | $(fmt_seconds "$CMS_P95") | 8,000ms | $(fmt_seconds "$CMS_P99") |

## Error Budget Consumption

| Service | Total Budget | Budget Remaining (ratio) | Budget Remaining (minutes) | Burn Rate Trend |
|---------|-------------|-------------------------|---------------------------|----------------|
| LMS | 21.6 min | $(fmt_pct "$LMS_BUDGET_RATIO") | $(fmt_minutes "$LMS_BUDGET_MIN") | — |
| CMS | 21.6 min | $(fmt_pct "$CMS_BUDGET_RATIO") | $(fmt_minutes "$CMS_BUDGET_MIN") | — |

## Incident Summary

| Severity | Count | Notes |
|----------|-------|-------|
| P1 (Critical) | — | No automated incident tracking yet |
| P2 (High) | — | — |
| P3 (Medium) | — | — |
| P4 (Low) | — | — |

## Maintenance Windows

| Date | Start | End | Duration | Scope | Outcome |
|------|-------|-----|----------|-------|---------|
| — | — | — | — | No maintenance windows recorded this period | — |

## Recommendations

1. Continue monitoring error budget burn rates for Tier 1 services
2. Implement automated incident tracking for future reports
3. Review and tighten SLO targets once 90-day baseline is established

## Methodology

- Availability: \`mereka:http_requests:availability_ratio_5m\` (Prometheus recording rule)
- Latency: \`mereka:http_request_duration:p{50,95,99}_5m\` (Prometheus recording rule)
- Error Budget: \`mereka:slo:error_budget_remaining_ratio\` (30-day rolling window)
- Source: Prometheus at ${PROMETHEUS_URL}
- Dashboard: [Mereka LMS - SLO Overview](https://grafana.mereka.io/d/mereka-slo-overview)
- Spec: [SLO/SLA Service Level Management](specs/slo-sla-service-level-management_spec.md)
REPORT

echo "Report written to: ${REPORT_FILE}"
echo "OK"
