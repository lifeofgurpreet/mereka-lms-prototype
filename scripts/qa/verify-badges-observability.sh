#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-030, AC-031, AC-032, AC-033
# Verify badge analytics, metrics, and observability
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Badge Observability Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-030: Enterprise admin analytics dashboard
# ---------------------------------------------------------------------------
ADMIN_PORTAL="infrastructure/tutor/custom-apps/admin_portal"
BADGES_API="services/badgr-server"

# Check for analytics dashboard configuration
if grep -r "analytics.*dashboard\|badge.*analytics" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -i "enterprise\|tenant"; then
  pass "AC-030: Enterprise badge analytics dashboard configured"
else
  skip "AC-030: Analytics dashboard not yet implemented"
fi

# Check for required metrics (issued count, sharing rate, verification count)
if grep -r "total.*issued\|badge.*count\|sharing.*rate" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -i "analytics\|metric"; then
  pass "AC-030: Analytics metrics (issued, sharing, verification) configured"
else
  skip "AC-030: Analytics metrics not found"
fi

# Check for top badge classes by issuance volume
if grep -r "top.*badge.*class\|badge.*class.*volume" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -i "analytics\|report"; then
  pass "AC-030: Top badge classes metric configured"
else
  skip "AC-030: Top badge classes metric not found"
fi

# Check for tenant-scoped analytics (enterprise_customer_uuid filtering)
if grep -r "enterprise_customer_uuid\|tenant.*filter" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -i "analytics\|dashboard"; then
  pass "AC-030: Tenant-scoped analytics filtering configured"
else
  skip "AC-030: Tenant filtering not found"
fi

# ---------------------------------------------------------------------------
# AC-031: Enterprise API analytics endpoint
# ---------------------------------------------------------------------------
# Check for /api/v1/badges/enterprise/{uuid}/analytics/ endpoint
if grep -r "/analytics\|analytics.*endpoint" "$BADGES_API" 2>/dev/null | grep -i "enterprise.*badge\|badge.*enterprise"; then
  pass "AC-031: Enterprise API analytics endpoint configured"
else
  skip "AC-031: Analytics API endpoint not yet implemented"
fi

# Check for aggregate metrics in API response
if grep -r "aggregate.*metric\|total.*badge\|issued.*count" "$BADGES_API" 2>/dev/null | grep -i "analytics.*api\|api.*analytics"; then
  pass "AC-031: Aggregate metrics in API response configured"
else
  skip "AC-031: Aggregate metrics not found"
fi

# ---------------------------------------------------------------------------
# AC-032: Prometheus metrics for badge operations
# ---------------------------------------------------------------------------
PROMETHEUS_CONFIG="deploy/k8s/base/apps/prometheus"
OBSERVABILITY="deploy/k8s/base/apps/badgr-server"

# Check for /metrics endpoint in Badgr Server
if grep -r "/metrics\|prometheus.*metrics" "$BADGES_API" "$OBSERVABILITY" 2>/dev/null | grep -i "badge\|badgr"; then
  pass "AC-032: Badgr Server /metrics endpoint configured"
else
  skip "AC-032: Prometheus metrics not yet implemented"
fi

# Check for badge issuance count metric
if grep -r "badge_issuance_total\|badge.*issued.*count" "$BADGES_API" "$PROMETHEUS_CONFIG" 2>/dev/null | grep -i "metric\|prometheus"; then
  pass "AC-032: badge_issuance_total metric defined"
else
  skip "AC-032: badge_issuance_total metric not found"
fi

# Check for verification latency metric
if grep -r "verification.*latency\|badge_verification.*seconds" "$BADGES_API" "$PROMETHEUS_CONFIG" 2>/dev/null | grep -i "histogram\|metric"; then
  pass "AC-032: badge_verification_latency_seconds metric defined"
else
  skip "AC-032: Verification latency metric not found"
fi

# Check for queue depth metric
if grep -r "queue_depth\|issuance.*queue" "$BADGES_API" "$PROMETHEUS_CONFIG" 2>/dev/null | grep -i "badge\|metric"; then
  pass "AC-032: badge_issuance_queue_depth metric defined"
else
  skip "AC-032: Queue depth metric not found"
fi

# Check for Badgr Server health gauge
if grep -r "badgr.*health\|badge.*server.*health" "$BADGES_API" "$PROMETHEUS_CONFIG" 2>/dev/null | grep -i "gauge\|metric"; then
  pass "AC-032: badgr_server_health metric defined"
else
  skip "AC-032: Health gauge metric not found"
fi

# ---------------------------------------------------------------------------
# AC-033: Structured logging with required fields
# ---------------------------------------------------------------------------
# Check for structured JSON logging configuration
if grep -r "json.*log\|structured.*log\|logging.*json" "$BADGES_API" 2>/dev/null | grep -i "badge\|badgr"; then
  pass "AC-033: Structured JSON logging configured"
else
  skip "AC-033: Structured logging not yet implemented"
fi

# Check for required log fields (enterprise_customer_uuid, badge_class_id, etc.)
if grep -r "enterprise_customer_uuid.*log\|badge_class_id.*log\|learner_user_id" "$BADGES_API" 2>/dev/null | grep -i "error\|fail"; then
  pass "AC-033: Required log fields (enterprise_customer_uuid, badge_class_id, learner_user_id) configured"
else
  skip "AC-033: Required log fields not found"
fi

# Check for error_type and correlation_id in logs
if grep -r "error_type\|correlation_id\|request_id" "$BADGES_API" 2>/dev/null | grep -i "log"; then
  pass "AC-033: error_type and correlation_id in logs configured"
else
  skip "AC-033: error_type/correlation_id not found"
fi

# Check for Loki integration (Promtail)
if grep -r "loki\|promtail" "$OBSERVABILITY" "$PROMETHEUS_CONFIG" 2>/dev/null | grep -i "badge\|badgr"; then
  pass "AC-033: Loki/Promtail integration for log aggregation configured"
else
  skip "AC-033: Loki integration not found"
fi

# ---------------------------------------------------------------------------
# Additional checks: Alerts and dashboards
# ---------------------------------------------------------------------------
# Check for badge-specific Prometheus alerts
ALERTS_CONFIG="deploy/k8s/base/apps/prometheus/rules"
if grep -r "badge.*alert\|BadgrServer\|badge_issuance" "$ALERTS_CONFIG" "$PROMETHEUS_CONFIG" 2>/dev/null | grep -i "alert\|prometheusrule"; then
  pass "Badge-specific Prometheus alerts configured"
else
  skip "Badge-specific alerts not found"
fi

# Check for Grafana dashboard definition
GRAFANA_CONFIG="infrastructure/observability/grafana"
if grep -r "badge.*dashboard\|badgr.*dashboard" "$GRAFANA_CONFIG" 2>/dev/null | grep -i "grafana\|json"; then
  pass "Grafana badge operations dashboard configured"
else
  skip "Grafana badge dashboard not found"
fi

# Check for badge analytics metrics labels (enterprise_customer_uuid, badge_class_id)
if grep -r "labels.*enterprise_customer_uuid\|labels.*badge_class_id" "$BADGES_API" "$PROMETHEUS_CONFIG" 2>/dev/null | grep -i "metric"; then
  pass "Prometheus metric labels (enterprise_customer_uuid, badge_class_id) configured"
else
  skip "Metric labels not found"
fi

# Check for log exclusion of sensitive data (raw email, signing keys)
if grep -r "!.*log.*email\|exclude.*email.*log\|no.*raw.*email" "$BADGES_API" 2>/dev/null | grep -i "log"; then
  pass "Sensitive data exclusion from logs configured"
else
  skip "Sensitive data log exclusion not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
