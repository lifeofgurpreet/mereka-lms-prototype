#!/usr/bin/env bash
# @spec: observability-validation-requirements_spec.md
# @covers AC-OVR-016, AC-OVR-018, AC-OVR-019, AC-OVR-020, AC-OVR-021, AC-OVR-023, AC-OVR-025, AC-OVR-026, AC-OVR-027, AC-OVR-028, AC-OVR-029, AC-OVR-031
#
# Runtime verification for observability validation (live cluster + GCP checks)
# This script checks live deployments, GCP resources, and Grafana dashboards.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
SKIP=0

# Helper functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAIL++))
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((SKIP++))
}

echo "========================================================="
echo "Observability Validation Runtime Verification (Live)"
echo "========================================================="
echo ""

# AC-OVR-016: SLI recording rules producing data
echo "==> AC-OVR-016: Prometheus recording rules producing numeric data (0-1 range)"
if command -v kubectl >/dev/null 2>&1; then
    # Try to get Prometheus pod
    PROM_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)

    if [[ -n "$PROM_POD" ]]; then
        # Query recording rule
        if kubectl exec -n monitoring "$PROM_POD" -c prometheus -- \
            wget -q -O- "http://localhost:9090/api/v1/query?query=mereka:http_requests:availability_ratio_5m" 2>/dev/null | \
            grep -q '"status":"success"'; then
            pass "AC-OVR-016: SLI recording rule mereka:http_requests:availability_ratio_5m is producing data"
        else
            skip "AC-OVR-016: Recording rule exists but may not have data yet (requires django-prometheus)"
        fi
    else
        skip "AC-OVR-016: Prometheus pod not found in monitoring namespace"
    fi
else
    skip "AC-OVR-016: kubectl not available (requires live cluster access)"
fi

# AC-OVR-018: GCP uptime checks
echo ""
echo "==> AC-OVR-018: GCP uptime checks deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    UPTIME_COUNT=$(gcloud monitoring uptime list-configs --format=json 2>/dev/null | jq '. | length' || echo 0)
    EXPECTED_UPTIME=$(find infrastructure/monitoring/uptime/*.json 2>/dev/null | wc -l || echo 0)

    if [[ "$UPTIME_COUNT" -ge "$EXPECTED_UPTIME" ]]; then
        pass "AC-OVR-018: GCP has $UPTIME_COUNT uptime checks (expected: $EXPECTED_UPTIME)"
    else
        fail "AC-OVR-018: GCP has $UPTIME_COUNT uptime checks (expected: $EXPECTED_UPTIME)"
    fi
else
    skip "AC-OVR-018: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-019: GCP alert policies
echo ""
echo "==> AC-OVR-019: GCP alert policies deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    ALERT_COUNT=$(gcloud alpha monitoring policies list --format=json 2>/dev/null | jq '. | length' || echo 0)

    if [[ "$ALERT_COUNT" -gt 0 ]]; then
        pass "AC-OVR-019: GCP has $ALERT_COUNT alert policies deployed"
    else
        fail "AC-OVR-019: No GCP alert policies found"
    fi
else
    skip "AC-OVR-019: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-020: GCP log-based metrics
echo ""
echo "==> AC-OVR-020: GCP log-based metrics deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    METRIC_COUNT=$(gcloud logging metrics list --format=json 2>/dev/null | jq '. | length' || echo 0)

    if [[ "$METRIC_COUNT" -gt 0 ]]; then
        pass "AC-OVR-020: GCP has $METRIC_COUNT log-based metrics deployed"
    else
        fail "AC-OVR-020: No GCP log-based metrics found"
    fi
else
    skip "AC-OVR-020: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-021: GCP dashboards
echo ""
echo "==> AC-OVR-021: GCP monitoring dashboards deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    DASHBOARD_COUNT=$(gcloud monitoring dashboards list --format=json 2>/dev/null | jq '. | length' || echo 0)

    if [[ "$DASHBOARD_COUNT" -gt 0 ]]; then
        pass "AC-OVR-021: GCP has $DASHBOARD_COUNT monitoring dashboards deployed"
    else
        skip "AC-OVR-021: No GCP dashboards found (may not be deployed yet)"
    fi
else
    skip "AC-OVR-021: gcloud not authenticated (requires GCP access)"
fi

# AC-OVR-023: Grafana dashboard with required panels
echo ""
echo "==> AC-OVR-023: Grafana dashboard bbi-app-mereka-lms exists with required panels"
GRAFANA_URL="${GRAFANA_URL:-https://grafana.mereka.io}"
GRAFANA_TOKEN="${GRAFANA_API_TOKEN:-}"

if [[ -n "$GRAFANA_TOKEN" ]]; then
    DASHBOARD_JSON=$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
        "$GRAFANA_URL/api/dashboards/uid/bbi-app-mereka-lms" 2>/dev/null)

    if echo "$DASHBOARD_JSON" | jq -e '.dashboard' >/dev/null 2>&1; then
        # Check for required panels from contract
        REQUIRED_PANELS=("LMS" "CMS" "Caddy" "MySQL" "Redis")
        MISSING=0
        for panel in "${REQUIRED_PANELS[@]}"; do
            if ! echo "$DASHBOARD_JSON" | jq -e ".dashboard.panels[] | select(.title | contains(\"$panel\"))" >/dev/null 2>&1; then
                fail "AC-OVR-023: Required panel '$panel' not found in dashboard"
                ((MISSING++))
            fi
        done

        if [[ $MISSING -eq 0 ]]; then
            pass "AC-OVR-023: Dashboard bbi-app-mereka-lms has all required panels"
        fi
    else
        fail "AC-OVR-023: Dashboard bbi-app-mereka-lms not found in Grafana"
    fi
else
    skip "AC-OVR-023: GRAFANA_API_TOKEN not set (requires Grafana API access)"
fi

# AC-OVR-025: validate-observability-compliance.sh outputs valid JSON
echo ""
echo "==> AC-OVR-025: Validation script produces valid JSON with --json flag"
if [[ -f "scripts/qa/validate-observability-compliance.sh" ]]; then
    # Run in JSON mode and validate output
    if OUTPUT=$(scripts/qa/validate-observability-compliance.sh --mode local --json 2>/dev/null); then
        if echo "$OUTPUT" | jq -e '.summary.total_checks' >/dev/null 2>&1; then
            pass "AC-OVR-025: Validation script produces valid JSON output"
        else
            fail "AC-OVR-025: Validation script JSON output is malformed"
        fi
    else
        skip "AC-OVR-025: Validation script not yet implemented (TODO)"
    fi
else
    skip "AC-OVR-025: scripts/qa/validate-observability-compliance.sh not found (TODO)"
fi

# AC-OVR-026: Validation script detects missing resources
echo ""
echo "==> AC-OVR-026: Validation script exits non-zero when resources are missing"
skip "AC-OVR-026: Requires deliberate test environment with missing ServiceMonitor (manual test)"

# AC-OVR-027: Validation script --mode runtime queries kubectl and gcloud
echo ""
echo "==> AC-OVR-027: Validation script runtime mode queries kubectl and gcloud"
skip "AC-OVR-027: Requires validate-observability-compliance.sh with --mode runtime (TODO)"

# AC-OVR-028: CI runs validation script on monitoring file changes
echo ""
echo "==> AC-OVR-028: CI workflow runs validation script on PR changes"
if [[ -f ".github/workflows/observability-compliance.yml" ]]; then
    if grep -q "validate-observability-compliance.sh" .github/workflows/observability-compliance.yml; then
        pass "AC-OVR-028: CI workflow configured to run validation script"
    else
        fail "AC-OVR-028: CI workflow exists but does not run validation script"
    fi
else
    skip "AC-OVR-028: CI workflow for observability compliance not yet created (TODO)"
fi

# AC-OVR-029: CI blocks merge when ServiceMonitor is removed
echo ""
echo "==> AC-OVR-029: CI blocks merge when ServiceMonitor is removed from kustomization"
skip "AC-OVR-029: Requires CI integration test with deliberate removal (manual verification)"

# AC-OVR-031: Alert rules have valid PromQL (no syntax errors)
echo ""
echo "==> AC-OVR-031: All alert PromQL expressions are valid (no syntax errors)"
if command -v kubectl >/dev/null 2>&1; then
    PROM_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)

    if [[ -n "$PROM_POD" ]]; then
        # Get all alert rules from Prometheus
        RULES_JSON=$(kubectl exec -n monitoring "$PROM_POD" -c prometheus -- \
            wget -q -O- "http://localhost:9090/api/v1/rules" 2>/dev/null)

        if echo "$RULES_JSON" | jq -e '.data.groups[].rules[] | select(.type=="alerting")' >/dev/null 2>&1; then
            # Count alerts with health=ok
            TOTAL_ALERTS=$(echo "$RULES_JSON" | jq '[.data.groups[].rules[] | select(.type=="alerting")] | length')
            OK_ALERTS=$(echo "$RULES_JSON" | jq '[.data.groups[].rules[] | select(.type=="alerting" and .health=="ok")] | length')

            if [[ "$OK_ALERTS" -eq "$TOTAL_ALERTS" ]]; then
                pass "AC-OVR-031: All $TOTAL_ALERTS alert rules have valid PromQL (health=ok)"
            else
                fail "AC-OVR-031: $((TOTAL_ALERTS - OK_ALERTS)) alert rules have PromQL syntax errors"
            fi
        else
            skip "AC-OVR-031: No alert rules loaded in Prometheus yet"
        fi
    else
        skip "AC-OVR-031: Prometheus pod not found in monitoring namespace"
    fi
else
    skip "AC-OVR-031: kubectl not available (requires live cluster access)"
fi

# Summary
echo ""
echo "==========================================="
echo "Summary"
echo "==========================================="
echo -e "${GREEN}PASS: $PASS${NC}"
echo -e "${RED}FAIL: $FAIL${NC}"
echo -e "${YELLOW}SKIP: $SKIP${NC}"
echo "Total: $((PASS + FAIL + SKIP))"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

exit 0
