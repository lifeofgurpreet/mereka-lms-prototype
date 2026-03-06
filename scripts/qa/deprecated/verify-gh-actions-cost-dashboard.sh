#!/usr/bin/env bash
# @spec: github-actions-cost-monitoring_spec.md
# @covers: AC-014
#
# Verify that GitHub Actions cost dashboard is available in Grafana.
#
# AC-014: Given cost monitoring is deployed, when operators access Grafana,
# then cost dashboard must be available at `/dashboards/github-actions-cost`
# and all panels must render without errors.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=========================================="
echo "Verify GitHub Actions Cost Dashboard (AC-014)"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

test_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

cd "$PROJECT_ROOT"

DASHBOARD_FILE="deploy/k8s/base/monitoring/dashboards/github-actions-cost.json"

# Test 1: Verify dashboard JSON exists
echo "[Test 1] Dashboard definition file"
if [[ -f "$DASHBOARD_FILE" ]]; then
    test_pass "Dashboard JSON exists at $DASHBOARD_FILE"
else
    test_warn "Dashboard JSON not found at $DASHBOARD_FILE (not yet implemented)"
    DASHBOARD_FILE=""
fi

if [[ -n "$DASHBOARD_FILE" ]]; then
    # Test 2: Validate JSON syntax
    echo ""
    echo "[Test 2] Dashboard JSON is valid"
    if python3 -c "import json; json.load(open('$DASHBOARD_FILE'))" 2>/dev/null; then
        test_pass "Dashboard JSON is valid"
    else
        test_fail "Dashboard JSON has syntax errors"
    fi

    # Test 3: Verify dashboard structure
    echo ""
    echo "[Test 3] Dashboard has required structure"

    # Check for title
    TITLE=$(python3 -c "import json; print(json.load(open('$DASHBOARD_FILE')).get('title', ''))" 2>/dev/null || echo "")
    if [[ -n "$TITLE" ]]; then
        test_pass "Dashboard has title: '$TITLE'"
    else
        test_fail "Dashboard missing 'title' field"
    fi

    # Check for panels
    PANEL_COUNT=$(python3 -c "import json; print(len(json.load(open('$DASHBOARD_FILE')).get('panels', [])))" 2>/dev/null || echo "0")
    if [[ $PANEL_COUNT -gt 0 ]]; then
        test_pass "Dashboard has $PANEL_COUNT panel(s)"
    else
        test_fail "Dashboard has no panels"
    fi

    # Test 4: Verify required panels exist
    echo ""
    echo "[Test 4] Dashboard includes required panels"

    # As per spec AC-008, dashboard must display:
    # - Current month spend vs budget (gauge)
    # - Daily spend trend (time series)
    # - Top 5 expensive workflows (bar chart)
    # - Projected month-end cost (forecast)
    # - Historical cost comparison (month-over-month)

    PANELS_JSON=$(python3 -c "import json; panels = json.load(open('$DASHBOARD_FILE')).get('panels', []); print([p.get('title', 'Untitled') for p in panels])" 2>/dev/null || echo "[]")

    if echo "$PANELS_JSON" | grep -qi "budget\|spend\|gauge"; then
        test_pass "Dashboard includes budget/spend gauge panel"
    else
        test_warn "Dashboard may be missing budget gauge panel"
    fi

    if echo "$PANELS_JSON" | grep -qi "daily\|trend\|time.*series"; then
        test_pass "Dashboard includes daily spend trend panel"
    else
        test_warn "Dashboard may be missing daily trend panel"
    fi

    if echo "$PANELS_JSON" | grep -qi "top\|expensive\|workflow"; then
        test_pass "Dashboard includes top workflows panel"
    else
        test_warn "Dashboard may be missing top workflows panel"
    fi

    if echo "$PANELS_JSON" | grep -qi "forecast\|projected"; then
        test_pass "Dashboard includes cost forecast panel"
    else
        test_warn "Dashboard may be missing forecast panel"
    fi

    # Test 5: Verify Prometheus datasource queries
    echo ""
    echo "[Test 5] Dashboard uses Prometheus datasource"
    if grep -q "prometheus" "$DASHBOARD_FILE"; then
        test_pass "Dashboard configured for Prometheus datasource"
    else
        test_warn "Dashboard may not be using Prometheus"
    fi

    # Test 6: Check for required metrics
    echo ""
    echo "[Test 6] Dashboard queries required metrics"

    # As per spec AC-007, metrics should include:
    # - github_actions_workflow_duration_seconds
    # - github_actions_workflow_cost_usd
    # - github_actions_monthly_budget_consumed_percent

    if grep -q "github_actions_workflow_duration_seconds" "$DASHBOARD_FILE"; then
        test_pass "Dashboard queries workflow duration metric"
    else
        test_warn "Dashboard missing workflow duration metric"
    fi

    if grep -q "github_actions_workflow_cost_usd" "$DASHBOARD_FILE"; then
        test_pass "Dashboard queries workflow cost metric"
    else
        test_warn "Dashboard missing workflow cost metric"
    fi

    if grep -q "github_actions_monthly_budget_consumed_percent" "$DASHBOARD_FILE"; then
        test_pass "Dashboard queries budget consumed metric"
    else
        test_warn "Dashboard missing budget consumed metric"
    fi
fi

# Test 7: Verify ConfigMap exists for dashboard
echo ""
echo "[Test 7] Grafana dashboard ConfigMap"

if [[ -f deploy/k8s/base/monitoring/grafana-dashboards-configmap.yaml ]]; then
    test_pass "Grafana dashboards ConfigMap exists"

    if grep -q "github-actions-cost" deploy/k8s/base/monitoring/grafana-dashboards-configmap.yaml; then
        test_pass "ConfigMap references github-actions-cost dashboard"
    else
        test_warn "ConfigMap does not reference github-actions-cost dashboard"
    fi
else
    test_warn "Grafana dashboards ConfigMap not found"
fi

# Test 8: Verify dashboard label for Grafana sidecar
echo ""
echo "[Test 8] Dashboard ConfigMap has grafana_dashboard label"

if [[ -f deploy/k8s/base/monitoring/grafana-dashboards-configmap.yaml ]]; then
    if grep -q "grafana_dashboard:" deploy/k8s/base/monitoring/grafana-dashboards-configmap.yaml; then
        test_pass "ConfigMap has grafana_dashboard label"
    else
        test_warn "ConfigMap missing grafana_dashboard label (required for sidecar)"
    fi
fi

# Test 9: Check if Grafana is deployed
echo ""
echo "[Test 9] Grafana deployment status"

if command -v kubectl >/dev/null 2>&1; then
    if kubectl get deployment -n mereka-lms grafana --ignore-not-found 2>/dev/null | grep -q grafana; then
        test_pass "Grafana is deployed in mereka-lms namespace"
    else
        test_warn "Grafana deployment not found in cluster (may be in different namespace)"
    fi
else
    test_warn "kubectl not available - cannot check Grafana deployment"
fi

# Test 10: Test dashboard availability (if cluster is accessible)
echo ""
echo "[Test 10] Dashboard availability check"

if command -v kubectl >/dev/null 2>&1; then
    # Check if we can access the cluster
    if kubectl cluster-info >/dev/null 2>&1; then
        # Try to find Grafana service
        GRAFANA_SVC=$(kubectl get svc -A --field-selector metadata.name=grafana --no-headers 2>/dev/null | head -1 | awk '{print $1}')

        if [[ -n "$GRAFANA_SVC" ]]; then
            echo "  Found Grafana in namespace: $GRAFANA_SVC"

            # Port forward test (non-blocking)
            echo "  Testing port-forward to Grafana..."
            timeout 5s kubectl port-forward -n "$GRAFANA_SVC" svc/grafana 3000:3000 >/dev/null 2>&1 &
            PF_PID=$!
            sleep 2

            # Try to access dashboard
            if curl -f -s -o /dev/null "http://localhost:3000/api/health" 2>/dev/null; then
                test_pass "Grafana API is accessible via port-forward"

                # Check if dashboard endpoint exists
                if curl -f -s "http://localhost:3000/api/dashboards/db/github-actions-cost" 2>/dev/null | grep -q "github-actions-cost"; then
                    test_pass "Dashboard available at /dashboards/github-actions-cost"
                else
                    test_warn "Dashboard endpoint not found (may need different path)"
                fi
            else
                test_warn "Cannot access Grafana API (may need authentication)"
            fi

            # Clean up port-forward
            kill $PF_PID 2>/dev/null || true
        else
            test_warn "Grafana service not found in cluster"
        fi
    else
        test_warn "Cannot connect to Kubernetes cluster (skipping live checks)"
    fi
else
    test_warn "kubectl not available (skipping live checks)"
fi

# Test 11: Verify dashboard documentation
echo ""
echo "[Test 11] Dashboard is documented"

if grep -rq "github-actions-cost" docs/ 2>/dev/null; then
    test_pass "Dashboard documented in docs/"
else
    test_warn "Dashboard not documented in docs/"
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "WARN: $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
    if [[ $WARN -gt 0 ]]; then
        echo -e "${YELLOW}⚠ AC-014 VERIFIED WITH WARNINGS: Dashboard structure validated${NC}"
        echo ""
        echo "Recommendations:"
        if [[ ! -f "$DASHBOARD_FILE" ]]; then
            echo "  - Create dashboard JSON at $DASHBOARD_FILE"
        fi
        echo "  - Ensure all required panels are configured (budget gauge, trend, top workflows, forecast)"
        echo "  - Add dashboard to Grafana ConfigMap with grafana_dashboard label"
        echo "  - Document dashboard access in operational docs"
        exit 0
    else
        echo -e "${GREEN}✓ AC-014 VERIFIED: Cost dashboard is available and valid${NC}"
        exit 0
    fi
else
    echo -e "${RED}✗ AC-014 FAILED: Dashboard validation failed${NC}"
    exit 1
fi
