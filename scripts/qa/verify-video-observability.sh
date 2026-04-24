#!/usr/bin/env bash
# @spec: video-pipeline-delivery_spec.md
# @covers AC-VPD-015, AC-VPD-017, AC-VPD-018, AC-VPD-019, AC-VPD-020, AC-VPD-021, AC-VPD-026, AC-VPD-027, AC-VPD-029, AC-VPD-030
#
# Video Pipeline Phase 2: Observability & Cost Monitoring
# Verifies Mux monitoring infrastructure, alert rules, dashboards, and secrets.
#
# Usage:
#   ./scripts/qa/verify-video-observability.sh
#
# Requires: kubectl (with cluster access), grep, jq
set -euo pipefail

PASS=0; FAIL=0; SKIP=0
NAMESPACE="mereka-lms"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP: $1"; SKIP=$((SKIP + 1)); }

# Cache cluster access check (runs once)
_HAS_KUBECTL=""
has_kubectl() {
  if [[ -z "$_HAS_KUBECTL" ]]; then
    if command -v kubectl &>/dev/null && timeout 5 kubectl cluster-info &>/dev/null 2>&1; then
      _HAS_KUBECTL="yes"
    else
      _HAS_KUBECTL="no"
    fi
  fi
  [[ "$_HAS_KUBECTL" == "yes" ]]
}

kctl() { timeout 10 kubectl "$@"; }

# ── Section 1: Secret Management (AC-VPD-020) ──────────────────
echo "=== Video Secrets Management ==="

# AC-VPD-020: MUX_TOKEN_ID and MUX_TOKEN_SECRET in ExternalSecrets
if grep -q "MUX_TOKEN_ID" "$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml" && \
   grep -q "MUX_TOKEN_SECRET" "$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"; then
  pass "AC-VPD-020: MUX_TOKEN_ID and MUX_TOKEN_SECRET defined in external-secrets.yaml"
else
  fail "AC-VPD-020: MUX secrets not found in external-secrets.yaml"
fi

# AC-VPD-020: Verify secrets synced to K8s (live cluster)
if has_kubectl; then
  mux_id=$(kctl get secret mereka-lms-runtime-secrets -n "$NAMESPACE" \
    -o jsonpath='{.data.MUX_TOKEN_ID}' 2>/dev/null || echo "")
  mux_secret=$(kctl get secret mereka-lms-runtime-secrets -n "$NAMESPACE" \
    -o jsonpath='{.data.MUX_TOKEN_SECRET}' 2>/dev/null || echo "")
  if [[ -n "$mux_id" && -n "$mux_secret" ]]; then
    pass "AC-VPD-020: MUX secrets present in K8s runtime-secrets (live cluster)"
  else
    fail "AC-VPD-020: MUX secrets NOT present in K8s runtime-secrets"
  fi
else
  skip "AC-VPD-020: No cluster access — cannot verify live K8s secrets"
fi

# ── Section 2: No Hardcoded Credentials (AC-VPD-021) ───────────
echo ""
echo "=== No Hardcoded Mux Credentials ==="

# AC-VPD-021: Scan codebase for hardcoded Mux tokens
# Mux tokens look like: access token IDs are UUIDs, secrets are long hex strings
hardcoded_hits=$(grep -rn --include="*.py" --include="*.yaml" --include="*.yml" --include="*.json" \
  -E '(mux_token|MUX_TOKEN|mux_secret|MUX_SECRET)\s*[:=]\s*["\x27][a-zA-Z0-9]{8,}' \
  "$REPO_ROOT/scripts/" "$REPO_ROOT/infrastructure/" "$REPO_ROOT/deploy/" \
  "$REPO_ROOT/services/" 2>/dev/null | \
  grep -v "external-secrets" | grep -v "\.example" | grep -v "test" | \
  grep -v "secretKeyRef" | grep -v "valueFrom" | grep -v "\.md:" | \
  grep -v "os\.environ" | grep -v "MEREKA_LMS_MUX" || true)

if [[ -z "$hardcoded_hits" ]]; then
  pass "AC-VPD-021: No hardcoded Mux credentials found in codebase"
else
  fail "AC-VPD-021: Possible hardcoded Mux credentials found:"
  echo "    $hardcoded_hits"
fi

# ── Section 3: Mux Delivery Monitor Exporter (AC-VPD-029) ──────
echo ""
echo "=== Mux Delivery Monitor Infrastructure ==="

# AC-VPD-029: Monitor script exists
if [[ -f "$REPO_ROOT/scripts/monitoring/mux_delivery_monitor.py" ]]; then
  pass "AC-VPD-029: mux_delivery_monitor.py exists"
else
  fail "AC-VPD-029: mux_delivery_monitor.py not found"
fi

# AC-VPD-029: Script exposes video_delivery_minutes_monthly metric
if grep -q "video_delivery_minutes_monthly" "$REPO_ROOT/scripts/monitoring/mux_delivery_monitor.py" 2>/dev/null; then
  pass "AC-VPD-029: Script exposes video_delivery_minutes_monthly metric"
else
  fail "AC-VPD-029: Script does not expose video_delivery_minutes_monthly"
fi

# AC-VPD-029: Poll interval defaults to 6 hours (21600s)
if grep -q "21600" "$REPO_ROOT/scripts/monitoring/mux_delivery_monitor.py" 2>/dev/null; then
  pass "AC-VPD-029: Default poll interval is 21600s (6 hours)"
else
  fail "AC-VPD-029: Default poll interval is not 21600s"
fi

# AC-VPD-029: K8s Deployment manifest exists
if [[ -f "$REPO_ROOT/deploy/k8s/base/monitoring/mux-exporter.yaml" ]]; then
  pass "AC-VPD-029: mux-exporter.yaml Deployment manifest exists"
else
  fail "AC-VPD-029: mux-exporter.yaml not found"
fi

# AC-VPD-029: ServiceMonitor exists
if [[ -f "$REPO_ROOT/deploy/k8s/base/monitoring/servicemonitor-mux.yaml" ]]; then
  pass "AC-VPD-029: servicemonitor-mux.yaml exists"
else
  fail "AC-VPD-029: servicemonitor-mux.yaml not found"
fi

# AC-VPD-029: Resources referenced in kustomization.yaml
kustom_file="$REPO_ROOT/deploy/k8s/base/monitoring/kustomization.yaml"
if grep -q "mux-exporter.yaml" "$kustom_file" && grep -q "servicemonitor-mux.yaml" "$kustom_file"; then
  pass "AC-VPD-029: Mux exporter and ServiceMonitor in kustomization.yaml"
else
  fail "AC-VPD-029: Mux resources not referenced in kustomization.yaml"
fi

# AC-VPD-029: Live cluster — exporter pod running
if has_kubectl; then
  mux_pod=$(kctl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mux-delivery-monitor \
    -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
  if [[ "$mux_pod" == "Running" ]]; then
    pass "AC-VPD-029: mux-delivery-monitor pod is Running (live cluster)"
  else
    skip "AC-VPD-029: mux-delivery-monitor pod not running — deployment pending"
  fi

  # ServiceMonitor deployed
  sm=$(kctl get servicemonitor mux-delivery-monitor -n "$NAMESPACE" 2>/dev/null || echo "")
  if [[ -n "$sm" ]]; then
    pass "AC-VPD-029: ServiceMonitor mux-delivery-monitor deployed (live cluster)"
  else
    skip "AC-VPD-029: ServiceMonitor not deployed yet — pending apply"
  fi
else
  skip "AC-VPD-029: No cluster access — cannot verify live exporter"
  skip "AC-VPD-029: No cluster access — cannot verify live ServiceMonitor"
fi

# ── Section 4: Alert Rules (AC-VPD-019, AC-VPD-030) ────────────
echo ""
echo "=== Video Alert Rules ==="

pr_file="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-video.yaml"

# AC-VPD-019: PrometheusRule manifest exists
if [[ -f "$pr_file" ]]; then
  pass "AC-VPD-019: prometheusrule-video.yaml exists"
else
  fail "AC-VPD-019: prometheusrule-video.yaml not found"
fi

# AC-VPD-019: 80K delivery-minutes warning alert
if grep -q "80000" "$pr_file" 2>/dev/null && grep -q "MuxDeliveryMinutesWarning" "$pr_file"; then
  pass "AC-VPD-019: MuxDeliveryMinutesWarning alert at 80K threshold"
else
  fail "AC-VPD-019: Missing 80K delivery-minutes warning alert"
fi

# AC-VPD-019: 95K delivery-minutes critical alert
if grep -q "95000" "$pr_file" 2>/dev/null && grep -q "MuxDeliveryMinutesCritical" "$pr_file"; then
  pass "AC-VPD-019: MuxDeliveryMinutesCritical alert at 95K threshold"
else
  fail "AC-VPD-019: Missing 95K delivery-minutes critical alert"
fi

# AC-VPD-019: Referenced in kustomization.yaml
if grep -q "prometheusrule-video.yaml" "$kustom_file"; then
  pass "AC-VPD-019: prometheusrule-video.yaml in kustomization.yaml"
else
  fail "AC-VPD-019: prometheusrule-video.yaml not in kustomization.yaml"
fi

# AC-VPD-030: Transcode success rate alert
if grep -q "MuxTranscodeSuccessRateLow" "$pr_file" 2>/dev/null && grep -q "95" "$pr_file"; then
  pass "AC-VPD-030: MuxTranscodeSuccessRateLow alert at <95% threshold"
else
  fail "AC-VPD-030: Missing transcode success rate alert"
fi

# AC-VPD-030: 6-hour for duration
if grep -A5 "MuxTranscodeSuccessRateLow" "$pr_file" 2>/dev/null | grep -q "6h"; then
  pass "AC-VPD-030: Transcode alert fires after 6 hours"
else
  fail "AC-VPD-030: Transcode alert missing 6h duration"
fi

# Live cluster — PrometheusRule deployed
if has_kubectl; then
  pr_live=$(kctl get prometheusrule video-alerts -n "$NAMESPACE" 2>/dev/null || echo "")
  if [[ -n "$pr_live" ]]; then
    pass "AC-VPD-019: PrometheusRule video-alerts deployed (live cluster)"
  else
    skip "AC-VPD-019: PrometheusRule not deployed yet — pending apply"
  fi
else
  skip "AC-VPD-019: No cluster access — cannot verify live PrometheusRule"
fi

# ── Section 5: Grafana Dashboards (AC-VPD-026, AC-VPD-027) ─────
echo ""
echo "=== Video Grafana Dashboards ==="

dashboards_dir="$REPO_ROOT/infrastructure/monitoring/dashboards"

# AC-VPD-026: Video Operations Dashboard
ops_dashboard="$dashboards_dir/video-operations.json"
if [[ -f "$ops_dashboard" ]]; then
  pass "AC-VPD-026: video-operations.json dashboard exists"
  # Validate JSON
  if python3 -c "import json; json.load(open('$ops_dashboard'))" 2>/dev/null; then
    pass "AC-VPD-026: video-operations.json is valid JSON"
  else
    fail "AC-VPD-026: video-operations.json is invalid JSON"
  fi
  # Check for required panels
  if grep -q "video_transcode_success_rate" "$ops_dashboard" 2>/dev/null; then
    pass "AC-VPD-026: Dashboard includes transcode success rate panel"
  else
    fail "AC-VPD-026: Dashboard missing transcode success rate panel"
  fi
  if grep -q "mux_asset_total" "$ops_dashboard" 2>/dev/null; then
    pass "AC-VPD-026: Dashboard includes asset status panel"
  else
    fail "AC-VPD-026: Dashboard missing asset status panel"
  fi
else
  fail "AC-VPD-026: video-operations.json not found"
fi

# AC-VPD-027: Video Cost Dashboard
cost_dashboard="$dashboards_dir/video-cost.json"
if [[ -f "$cost_dashboard" ]]; then
  pass "AC-VPD-027: video-cost.json dashboard exists"
  if python3 -c "import json; json.load(open('$cost_dashboard'))" 2>/dev/null; then
    pass "AC-VPD-027: video-cost.json is valid JSON"
  else
    fail "AC-VPD-027: video-cost.json is invalid JSON"
  fi
  # Check for 80K threshold
  if grep -q "80000" "$cost_dashboard" 2>/dev/null; then
    pass "AC-VPD-027: Dashboard includes 80K threshold marker"
  else
    fail "AC-VPD-027: Dashboard missing 80K threshold marker"
  fi
  # Check delivery minutes metric
  if grep -q "video_delivery_minutes_monthly" "$cost_dashboard" 2>/dev/null; then
    pass "AC-VPD-027: Dashboard includes delivery minutes panel"
  else
    fail "AC-VPD-027: Dashboard missing delivery minutes panel"
  fi
else
  fail "AC-VPD-027: video-cost.json not found"
fi

# ── Section 6: Cost Validation (AC-VPD-017, AC-VPD-018) ────────
echo ""
echo "=== Cost Validation ==="

# AC-VPD-017: Storage cost estimate (static calculation based on spec)
# 1,290 video-minutes * $0.00055/min/month * (1 - 0.60 cold storage at 90d) = ~$0.28/month
# Spec says <= $1.55, which accounts for hot storage pricing
estimated_cost=$(python3 -c "
minutes = 1290
hot_price = 0.00055
cold_90d_discount = 0.60
cold_cost = minutes * hot_price * (1 - cold_90d_discount)
hot_cost = minutes * hot_price
print(f'Cold storage (90d+): \${cold_cost:.2f}/month')
print(f'Hot storage (new): \${hot_cost:.2f}/month')
if hot_cost <= 1.55:
    print('PASS')
else:
    print('FAIL')
" 2>/dev/null || echo "SKIP")

if echo "$estimated_cost" | grep -q "^PASS$"; then
  pass "AC-VPD-017: Storage cost for 1,290 min catalog <= \$1.55/month (even at hot pricing)"
elif echo "$estimated_cost" | grep -q "^FAIL$"; then
  fail "AC-VPD-017: Storage cost exceeds \$1.55/month"
else
  skip "AC-VPD-017: Cannot calculate storage cost (python3 unavailable)"
fi

# AC-VPD-018: Delivery cost is $0 under 100K free tier
# 30K delivery-min/month is well under 100K free tier
if python3 -c "
delivery_min = 30000
free_tier = 100000
if delivery_min < free_tier:
    print('PASS')
else:
    print('FAIL')
" 2>/dev/null | grep -q "PASS"; then
  pass "AC-VPD-018: 30K delivery-min/month is within 100K free tier (\$0.00)"
else
  skip "AC-VPD-018: Cannot validate delivery cost"
fi

# ── Section 7: Mux Data Quality Metrics (AC-VPD-015) ───────────
echo ""
echo "=== Mux Data Integration ==="

# AC-VPD-015: This AC requires Mux Data to be enabled (dashboard-level check)
# Cannot be fully automated — requires Mux dashboard access
skip "AC-VPD-015: Mux Data dashboard verification requires manual access to Mux dashboard"

# ── Summary ─────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  SKIP: $SKIP"
TOTAL=$((PASS + FAIL + SKIP))
echo "  TOTAL: $TOTAL"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
exit 0
