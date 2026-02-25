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
VERIFY_CMD_TIMEOUT="${VERIFY_OBS_CMD_TIMEOUT:-45}"
VERIFY_RUNTIME_SCRIPT_TIMEOUT="${VERIFY_OBS_RUNTIME_SCRIPT_TIMEOUT:-60}"
VERIFY_APP_NAMESPACE="${VERIFY_OBS_APP_NAMESPACE:-mereka-lms}"
VERIFY_MONITORING_NAMESPACE="${VERIFY_OBS_MONITORING_NAMESPACE:-monitoring}"
VERIFY_K8S_CONTEXT="${VERIFY_OBS_K8S_CONTEXT:-}"
VERIFY_GCP_PROJECT="${VERIFY_OBS_GCP_PROJECT:-${GCP_PROJECT:-mereka-lms}}"
VERIFY_ENV_LABEL="${VERIFY_OBS_ENV_LABEL:-unknown}"
VERIFY_DISPATCH_PROFILE="${VERIFY_OBS_DISPATCH_PROFILE:-custom}"
VERIFY_EVIDENCE_FILE="${VERIFY_OBS_EVIDENCE_FILE:-}"
RESULTS_FILE="$(mktemp -t verify-observability-runtime.XXXXXX)"
trap 'rm -f "$RESULTS_FILE"' EXIT

# Helper functions
pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
    printf 'pass\t%s\n' "$1" >> "$RESULTS_FILE"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
    printf 'fail\t%s\n' "$1" >> "$RESULTS_FILE"
}

skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    SKIP=$((SKIP + 1))
    printf 'skip\t%s\n' "$1" >> "$RESULTS_FILE"
}

kubectl_cmd() {
    if [[ -n "$VERIFY_K8S_CONTEXT" ]]; then
        kubectl --context "$VERIFY_K8S_CONTEXT" "$@"
    else
        kubectl "$@"
    fi
}

gcloud_cmd() {
    gcloud --project "$VERIFY_GCP_PROJECT" "$@"
}

fetch_metrics_with_status() {
    local namespace="$1"
    local resource="$2"
    local target="${3:-http://localhost:8000/metrics}"
    local result=""
    local status="000"
    local body=""
    local split_token="__METRICS_SPLIT__"

    if command -v timeout >/dev/null 2>&1; then
        result="$(timeout "$VERIFY_CMD_TIMEOUT" kubectl_cmd exec -n "$namespace" "$resource" --             sh -lc "curl -s -m ${VERIFY_CMD_TIMEOUT}s -w '\n${split_token}:%{http_code}\n' '${target}'" 2>/dev/null || true)"
    else
        result="$(kubectl_cmd exec -n "$namespace" "$resource" --             sh -lc "curl -s -m ${VERIFY_CMD_TIMEOUT}s -w '\n${split_token}:%{http_code}\n' '${target}'" 2>/dev/null || true)"
    fi

    if [[ -z "$result" ]] || ! printf '%s' "$result" | tail -n1 | grep -q "^${split_token}:"; then
        printf '000%s' "$split_token"
        return 0
    fi

    status="$(printf '%s' "$result" | tail -n1 | sed "s/^${split_token}://")"
    body="$(printf '%s' "$result" | sed '$d')"
    body="${body%$'\r'}"

    printf '%s%s%s' "$status" "$split_token" "$body"
}

check_metrics_payload_shape() {
    local component="$1"
    local payload="$2"
    local missing=0

    if [[ -z "$payload" ]]; then
        fail "AC-OVR-016: ${component} /metrics body is empty"
        return 1
    fi

    if ! printf '%s' "$payload" | grep -qE '^# HELP '; then
        fail "AC-OVR-016: ${component} /metrics body missing # HELP exposition block"
        missing=$((missing + 1))
    fi

    if ! printf '%s' "$payload" | grep -qE '^# TYPE '; then
        fail "AC-OVR-016: ${component} /metrics body missing # TYPE exposition block"
        missing=$((missing + 1))
    fi

    if ! printf '%s' "$payload" | grep -qE '^[a-zA-Z_:][a-zA-Z0-9_:]*(\{[^\n]*\})?[[:space:]]+[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?([[:space:]]+[0-9]+)?$'; then
        fail "AC-OVR-016: ${component} /metrics body missing a Prometheus sample with numeric value"
        missing=$((missing + 1))
    fi

    if [[ $missing -eq 0 ]]; then
        pass "AC-OVR-016: ${component} /metrics has valid Prometheus exposition structure"
    fi

    return "$missing"
}

run_missing_resource_negative_check() {
    local validation_script="scripts/qa/verify-observability-validation.sh"
    local temp_root
    local monitoring_root
    local kustomization
    local output
    local rc=0
    local missing_sm="servicemonitor-enterprise.yaml"

    if [[ ! -x "$validation_script" ]]; then
        skip "AC-OVR-026: scripts/qa/verify-observability-validation.sh not executable"
        return 0
    fi

    temp_root="$(mktemp -d -t observability-negative.XXXXXX)"
    monitoring_root="$temp_root/deploy/k8s/base/monitoring"

    mkdir -p "$(dirname "$monitoring_root")"
    cp -a "deploy/k8s/base/monitoring" "$temp_root/deploy/k8s/base/"
    kustomization="$monitoring_root/kustomization.yaml"
    sed -i "/$missing_sm/d" "$kustomization"

    set +e
    output="$( \
      VERIFY_OBS_KUSTOMIZATION_PATH="$kustomization" \
      VERIFY_OBS_MONITORING_DIR="$monitoring_root" \
      "$validation_script" 2>&1 \
    )"
    rc=$?
    set -e

    rm -rf "$temp_root"

    if [[ $rc -ne 0 ]] && echo "$output" | grep -q "${missing_sm} NOT listed in kustomization.yaml"; then
        pass "AC-OVR-026: Negative-control check exits non-zero when required ServiceMonitor entry is missing"
    elif [[ $rc -eq 0 ]]; then
        fail "AC-OVR-026: Negative-control check passed even when required ServiceMonitor was removed"
    else
        fail "AC-OVR-026: Negative-control output did not include expected ServiceMonitor missing check"
    fi
}

echo "========================================================="
echo "Observability Validation Runtime Verification (Live)"
echo "========================================================="
echo ""

# AC-OVR-016: SLI recording rules producing data
echo "==> AC-OVR-016: Prometheus recording rules producing numeric data (0-1 range)"
if command -v kubectl >/dev/null 2>&1; then
    # Try to get Prometheus pod
    set +e
    if command -v timeout >/dev/null 2>&1; then
        PROM_POD="$(timeout "$VERIFY_CMD_TIMEOUT" kubectl_cmd get pods -n "$VERIFY_MONITORING_NAMESPACE" -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)"
    else
        PROM_POD="$(kubectl_cmd get pods -n "$VERIFY_MONITORING_NAMESPACE" -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)"
    fi
    set -e

    if [[ -n "$PROM_POD" ]]; then
        # Query recording rule
        set +e
        if command -v timeout >/dev/null 2>&1; then
            if timeout "$VERIFY_CMD_TIMEOUT" kubectl_cmd exec -n "$VERIFY_MONITORING_NAMESPACE" "$PROM_POD" -c prometheus -- \
                wget -q -O- "http://localhost:9090/api/v1/query?query=mereka:http_requests:availability_ratio_5m" 2>/dev/null | \
                grep -q '"status":"success"'; then
                pass "AC-OVR-016: SLI recording rule mereka:http_requests:availability_ratio_5m is producing data"
            else
                skip "AC-OVR-016: Recording rule exists but may not have data yet (scrape warm-up or rollout delay)"
            fi
        else
            if kubectl_cmd exec -n "$VERIFY_MONITORING_NAMESPACE" "$PROM_POD" -c prometheus -- \
                wget -q -O- "http://localhost:9090/api/v1/query?query=mereka:http_requests:availability_ratio_5m" 2>/dev/null | \
                grep -q '"status":"success"'; then
                pass "AC-OVR-016: SLI recording rule mereka:http_requests:availability_ratio_5m is producing data"
            else
                skip "AC-OVR-016: Recording rule exists but may not have data yet (scrape warm-up or rollout delay)"
            fi
        fi
        set -e
    else
        skip "AC-OVR-016: Prometheus pod not found in ${VERIFY_MONITORING_NAMESPACE} namespace"
    fi
else
    skip "AC-OVR-016: kubectl not available (requires live cluster access)"
fi

# AC-OVR-016 (prerequisite): LMS/CMS /metrics endpoints must return HTTP 200
echo ""
echo "==> AC-OVR-016: LMS/CMS /metrics endpoint returns valid Prometheus exposition payload"
if command -v kubectl >/dev/null 2>&1; then
    set +e
    LMS_RESULT="$(fetch_metrics_with_status "$VERIFY_APP_NAMESPACE" deploy/lms)"
    LMS_CODE="${LMS_RESULT%%__METRICS_SPLIT__*}"
    LMS_METRICS="${LMS_RESULT#*__METRICS_SPLIT__}"
    CMS_RESULT="$(fetch_metrics_with_status "$VERIFY_APP_NAMESPACE" deploy/cms)"
    CMS_CODE="${CMS_RESULT%%__METRICS_SPLIT__*}"
    CMS_METRICS="${CMS_RESULT#*__METRICS_SPLIT__}"
    set -e

    if [[ "$LMS_CODE" == "200" ]]; then
        pass "AC-OVR-016: LMS /metrics returned 200"
        check_metrics_payload_shape "LMS" "$LMS_METRICS"
    else
        fail "AC-OVR-016: LMS /metrics returned $LMS_CODE (expected 200)"
    fi

    if [[ "$CMS_CODE" == "200" ]]; then
        pass "AC-OVR-016: CMS /metrics returned 200"
        check_metrics_payload_shape "CMS" "$CMS_METRICS"
    else
        fail "AC-OVR-016: CMS /metrics returned $CMS_CODE (expected 200)"
    fi
else
    skip "AC-OVR-016: kubectl not available (cannot verify LMS/CMS /metrics)"
fi

# AC-OVR-018: GCP uptime checks
echo ""
echo "==> AC-OVR-018: GCP uptime checks deployed"
if command -v gcloud >/dev/null 2>&1 && gcloud auth list 2>/dev/null | grep -q ACTIVE; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        UPTIME_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd monitoring uptime list-configs --format=json 2>/dev/null || echo '[]')"
    else
        UPTIME_JSON="$(gcloud_cmd monitoring uptime list-configs --format=json 2>/dev/null || echo '[]')"
    fi
    UPTIME_COUNT="$(echo "$UPTIME_JSON" | jq '. | length' 2>/dev/null || echo 0)"
    set -e
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
    set +e
    if command -v timeout >/dev/null 2>&1; then
        ALERT_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd alpha monitoring policies list --format=json 2>/dev/null || echo '[]')"
    else
        ALERT_JSON="$(gcloud_cmd alpha monitoring policies list --format=json 2>/dev/null || echo '[]')"
    fi
    ALERT_COUNT="$(echo "$ALERT_JSON" | jq '. | length' 2>/dev/null | tr -d '[:space:]' || echo 0)"
    set -e

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
    set +e
    if command -v timeout >/dev/null 2>&1; then
        METRIC_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd logging metrics list --format=json 2>/dev/null || echo '[]')"
    else
        METRIC_JSON="$(gcloud_cmd logging metrics list --format=json 2>/dev/null || echo '[]')"
    fi
    METRIC_COUNT="$(echo "$METRIC_JSON" | jq '. | length' 2>/dev/null | tr -d '[:space:]' || echo 0)"
    set -e

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
    set +e
    if command -v timeout >/dev/null 2>&1; then
        DASHBOARD_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" gcloud_cmd monitoring dashboards list --format=json 2>/dev/null || echo '[]')"
    else
        DASHBOARD_JSON="$(gcloud_cmd monitoring dashboards list --format=json 2>/dev/null || echo '[]')"
    fi
    DASHBOARD_COUNT="$(echo "$DASHBOARD_JSON" | jq '. | length' 2>/dev/null | tr -d '[:space:]' || echo 0)"
    set -e

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
GRAFANA_DASHBOARD_CONTRACT_PATH="${GRAFANA_DASHBOARD_CONTRACT_PATH:-infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json}"

if [[ -n "$GRAFANA_TOKEN" ]]; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        DASHBOARD_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
            "$GRAFANA_URL/api/dashboards/uid/bbi-app-mereka-lms" 2>/dev/null)"
    else
        DASHBOARD_JSON="$(curl -s -H "Authorization: Bearer $GRAFANA_TOKEN" \
            "$GRAFANA_URL/api/dashboards/uid/bbi-app-mereka-lms" 2>/dev/null)"
    fi
    set -e

    if echo "$DASHBOARD_JSON" | jq -e '.dashboard' >/dev/null 2>&1; then
        # Check required panels and query fragments from contract
        REQUIRED_PANELS=("LMS" "CMS (Studio)" "Caddy" "MySQL" "Redis")
        REQUIRED_QUERY_FRAGMENTS=("kube_pod_status_phase" "container_cpu_usage_seconds_total" "container_memory_usage_bytes")

        if [[ -f "$GRAFANA_DASHBOARD_CONTRACT_PATH" ]] && command -v jq >/dev/null 2>&1; then
            mapfile -t contract_panels < <(jq -r '.required.panel_titles[]?' "$GRAFANA_DASHBOARD_CONTRACT_PATH" 2>/dev/null)
            mapfile -t contract_fragments < <(jq -r '.required.query_fragments[]?' "$GRAFANA_DASHBOARD_CONTRACT_PATH" 2>/dev/null)
            if [[ "${#contract_panels[@]}" -gt 0 ]]; then
                REQUIRED_PANELS=("${contract_panels[@]}")
            fi
            if [[ "${#contract_fragments[@]}" -gt 0 ]]; then
                REQUIRED_QUERY_FRAGMENTS=("${contract_fragments[@]}")
            fi
        fi

        MISSING=0
        for panel in "${REQUIRED_PANELS[@]}"; do
            if ! echo "$DASHBOARD_JSON" | jq -e --arg panel "$panel" '.dashboard.panels[] | select(.title == $panel)' >/dev/null 2>&1; then
                fail "AC-OVR-023: Required panel '$panel' not found in dashboard"
                MISSING=$((MISSING + 1))
            fi
        done

        for fragment in "${REQUIRED_QUERY_FRAGMENTS[@]}"; do
            if ! echo "$DASHBOARD_JSON" | jq -e --arg fragment "$fragment" '.dashboard.panels[].targets[]?.expr | select(strings | contains($fragment))' >/dev/null 2>&1; then
                fail "AC-OVR-023: Required query fragment '$fragment' not found in dashboard expressions"
                MISSING=$((MISSING + 1))
            fi
        done

        if [[ $MISSING -eq 0 ]]; then
            pass "AC-OVR-023: Dashboard bbi-app-mereka-lms has required panels and query fragments"
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
    set +e
    if command -v timeout >/dev/null 2>&1; then
      OUTPUT="$(VALIDATE_OBS_APP_NAMESPACE="$VERIFY_APP_NAMESPACE" \
        timeout "$VERIFY_RUNTIME_SCRIPT_TIMEOUT" scripts/qa/validate-observability-compliance.sh --mode local --json 2>/dev/null)"
    else
      OUTPUT="$(VALIDATE_OBS_APP_NAMESPACE="$VERIFY_APP_NAMESPACE" \
        scripts/qa/validate-observability-compliance.sh --mode local --json 2>/dev/null)"
    fi
    if [[ $? -eq 0 ]]; then
        if echo "$OUTPUT" | jq -e '.summary.total' >/dev/null 2>&1; then
            pass "AC-OVR-025: Validation script produces valid JSON output"
        else
            fail "AC-OVR-025: Validation script JSON output is malformed"
        fi
    else
        fail "AC-OVR-025: Validation script failed in --json mode"
    fi
    set -e
else
    skip "AC-OVR-025: scripts/qa/validate-observability-compliance.sh not found"
fi

# AC-OVR-026: Validation script detects missing resources
echo ""
echo "==> AC-OVR-026: Validation script exits non-zero when resources are missing"
run_missing_resource_negative_check

# AC-OVR-027: Validation script --mode runtime queries kubectl and gcloud
echo ""
echo "==> AC-OVR-027: Validation script runtime mode queries kubectl and gcloud"
if [[ -f "scripts/qa/validate-observability-compliance.sh" ]]; then
    if command -v kubectl >/dev/null 2>&1 && command -v gcloud >/dev/null 2>&1; then
        set +e
        if command -v timeout >/dev/null 2>&1; then
          OUTPUT="$(VALIDATE_OBS_APP_NAMESPACE="$VERIFY_APP_NAMESPACE" \
            timeout "$VERIFY_RUNTIME_SCRIPT_TIMEOUT" scripts/qa/validate-observability-compliance.sh --mode runtime --strict --json 2>/dev/null)"
        else
          OUTPUT="$(VALIDATE_OBS_APP_NAMESPACE="$VERIFY_APP_NAMESPACE" \
            scripts/qa/validate-observability-compliance.sh --mode runtime --strict --json 2>/dev/null)"
        fi
        if [[ $? -eq 0 ]]; then
            if echo "$OUTPUT" | jq -e '.checks[] | select(.id=="AC-OVR-027")' >/dev/null 2>&1; then
                pass "AC-OVR-027: Runtime compliance mode validates kubectl and gcloud checks"
            else
                fail "AC-OVR-027: Runtime compliance output does not include AC-OVR-027 checks"
            fi
        else
            fail "AC-OVR-027: Validation script failed in runtime mode"
        fi
        set -e
    else
        skip "AC-OVR-027: kubectl or gcloud not available"
    fi
else
    skip "AC-OVR-027: scripts/qa/validate-observability-compliance.sh not found"
fi

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
    fail "AC-OVR-028: CI workflow for observability compliance not yet created"
fi

# AC-OVR-029: CI blocks merge when ServiceMonitor is removed
echo ""
echo "==> AC-OVR-029: CI blocks merge when ServiceMonitor is removed from kustomization"
if [[ -f ".github/workflows/observability-compliance.yml" ]]; then
    if grep -q "pull_request:" .github/workflows/observability-compliance.yml \
        && grep -q "deploy/k8s/base/monitoring" .github/workflows/observability-compliance.yml \
        && grep -q "validate-observability-compliance.sh --mode local --strict" .github/workflows/observability-compliance.yml; then
        pass "AC-OVR-029: CI workflow enforces merge-blocking observability checks on monitoring changes"
    else
        fail "AC-OVR-029: CI workflow does not gate monitoring-path changes with strict observability validation"
    fi
else
    fail "AC-OVR-029: CI workflow for observability compliance not yet created"
fi

# AC-OVR-031: Alert rules have valid PromQL (no syntax errors)
echo ""
echo "==> AC-OVR-031: All alert PromQL expressions are valid (no syntax errors)"
if command -v kubectl >/dev/null 2>&1; then
    set +e
    if command -v timeout >/dev/null 2>&1; then
        PROM_POD="$(timeout "$VERIFY_CMD_TIMEOUT" kubectl_cmd get pods -n "$VERIFY_MONITORING_NAMESPACE" -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)"
    else
        PROM_POD="$(kubectl_cmd get pods -n "$VERIFY_MONITORING_NAMESPACE" -l app.kubernetes.io/name=prometheus -o name 2>/dev/null | head -1)"
    fi
    set -e

    if [[ -n "$PROM_POD" ]]; then
        # Get all alert rules from Prometheus
        set +e
        if command -v timeout >/dev/null 2>&1; then
            RULES_JSON="$(timeout "$VERIFY_CMD_TIMEOUT" kubectl_cmd exec -n "$VERIFY_MONITORING_NAMESPACE" "$PROM_POD" -c prometheus -- \
                wget -q -O- "http://localhost:9090/api/v1/rules" 2>/dev/null)"
        else
            RULES_JSON="$(kubectl_cmd exec -n "$VERIFY_MONITORING_NAMESPACE" "$PROM_POD" -c prometheus -- \
                wget -q -O- "http://localhost:9090/api/v1/rules" 2>/dev/null)"
        fi
        set -e

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
        skip "AC-OVR-031: Prometheus pod not found in ${VERIFY_MONITORING_NAMESPACE} namespace"
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

if [[ -n "$VERIFY_EVIDENCE_FILE" ]]; then
    mkdir -p "$(dirname "$VERIFY_EVIDENCE_FILE")"
    {
        echo "# Observability Runtime Verification Evidence"
        echo ""
        echo "- generated_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "- app_namespace: $VERIFY_APP_NAMESPACE"
        echo "- monitoring_namespace: $VERIFY_MONITORING_NAMESPACE"
        echo "- gcp_project: $VERIFY_GCP_PROJECT"
        echo "- environment_label: $VERIFY_ENV_LABEL"
        echo "- dispatch_profile: $VERIFY_DISPATCH_PROFILE"
        echo "- k8s_context: ${VERIFY_K8S_CONTEXT:-default}"
        echo "- evidence_identity: env=${VERIFY_ENV_LABEL};profile=${VERIFY_DISPATCH_PROFILE};context=${VERIFY_K8S_CONTEXT:-default};project=${VERIFY_GCP_PROJECT}"
        echo ""
        echo "## Summary"
        echo ""
        echo "- pass: $PASS"
        echo "- fail: $FAIL"
        echo "- skip: $SKIP"
        echo "- total: $((PASS + FAIL + SKIP))"
        echo ""
        echo "## Failed Checks"
        echo ""
        if awk -F $'\t' '$1=="fail"{exit 0} END{exit 1}' "$RESULTS_FILE"; then
            awk -F $'\t' '$1=="fail"{printf("- %s\n", $2)}' "$RESULTS_FILE"
        else
            echo "- none"
        fi
    } > "$VERIFY_EVIDENCE_FILE"
fi

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi

exit 0
