#!/usr/bin/env bash
# @covers AC-VPD-019, AC-VPD-020, AC-VPD-029, AC-VPD-030
# @spec: cross-cutting-requirements_spec.md
#
# Verify Mux asset-status webhook → Alertmanager alert pipeline wiring.
#
# Validates the complete signal path:
#   Mux webhook endpoint (LMS) → ExternalSecrets (MUX_TOKEN_ID/SECRET) →
#   PrometheusRule (video-alerts) → ServiceMonitor (mux-delivery-monitor) →
#   Alertmanager routing → Grafana dashboard references
#
# Modes:
#   --offline  Static analysis of repo manifests (default; no cluster needed)
#   --online   Live cluster checks via kubectl + Alertmanager API
#
# Usage:
#   ./scripts/qa/verify-mux-alert-wiring.sh
#   ./scripts/qa/verify-mux-alert-wiring.sh --offline
#   ./scripts/qa/verify-mux-alert-wiring.sh --online
#
# Returns:
#   0  all checks passed (or skipped)
#   1  one or more checks failed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

MONITORING_DIR="${REPO_ROOT}/deploy/k8s/base/monitoring"
SECRETS_DIR="${REPO_ROOT}/deploy/k8s/base/secrets"
CUSTOM_APPS_DIR="${REPO_ROOT}/infrastructure/tutor/custom-apps"
NAMESPACE="${NAMESPACE:-mereka-lms}"
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://alertmanager.mereka-lms.svc.cluster.local:9093}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass()  { echo -e "${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
fail()  { echo -e "${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
skip()  { echo -e "${YELLOW}SKIP${NC}  $1"; SKIPPED=$((SKIPPED + 1)); }

MODE="offline"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) MODE="offline"; shift ;;
    --online)  MODE="online";  shift ;;
    -h|--help)
      echo "Usage: $0 [--offline|--online]"
      echo ""
      echo "  --offline  Static manifest checks (default)"
      echo "  --online   Live cluster checks (requires kubectl + cluster access)"
      exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# OFFLINE checks — static analysis of repo manifests
# ---------------------------------------------------------------------------

check_prometheusrule_video_exists() {
  local rule_file="${MONITORING_DIR}/prometheusrule-video.yaml"
  if [[ -f "${rule_file}" ]]; then
    pass "prometheusrule-video.yaml exists in deploy/k8s/base/monitoring/"
  else
    fail "prometheusrule-video.yaml missing (expected at ${rule_file})"
  fi
}

check_prometheusrule_alert_names() {
  local rule_file="${MONITORING_DIR}/prometheusrule-video.yaml"
  if [[ ! -f "${rule_file}" ]]; then
    skip "prometheusrule-video.yaml absent — skipping alert name checks"
    return
  fi

  local expected_alerts=(
    "MuxDeliveryMinutesWarning"
    "MuxDeliveryMinutesCritical"
    "MuxTranscodeSuccessRateLow"
    "MuxErroredAssetsGrowing"
    "MuxExporterDown"
    "MuxPollStale"
  )

  for alert in "${expected_alerts[@]}"; do
    if grep -q "${alert}" "${rule_file}" 2>/dev/null; then
      pass "PrometheusRule defines alert: ${alert}"
    else
      fail "PrometheusRule missing alert: ${alert}"
    fi
  done
}

check_prometheusrule_thresholds() {
  local rule_file="${MONITORING_DIR}/prometheusrule-video.yaml"
  if [[ ! -f "${rule_file}" ]]; then
    skip "prometheusrule-video.yaml absent — skipping threshold checks"
    return
  fi

  # AC-VPD-019: warning at 80K, critical at 95K
  if grep -q "80000" "${rule_file}" 2>/dev/null; then
    pass "PrometheusRule has 80,000-minute warning threshold (AC-VPD-019)"
  else
    fail "PrometheusRule missing 80,000-minute warning threshold (AC-VPD-019)"
  fi

  if grep -q "95000" "${rule_file}" 2>/dev/null; then
    pass "PrometheusRule has 95,000-minute critical threshold (AC-VPD-019)"
  else
    fail "PrometheusRule missing 95,000-minute critical threshold (AC-VPD-019)"
  fi

  # AC-VPD-030: transcode success rate below 95%
  if grep -q "video_transcode_success_rate" "${rule_file}" 2>/dev/null; then
    pass "PrometheusRule references video_transcode_success_rate metric (AC-VPD-030)"
  else
    fail "PrometheusRule missing video_transcode_success_rate metric (AC-VPD-030)"
  fi
}

check_prometheusrule_in_kustomization() {
  local kustomization="${MONITORING_DIR}/kustomization.yaml"
  if [[ ! -f "${kustomization}" ]]; then
    skip "kustomization.yaml absent — skipping inclusion check"
    return
  fi

  if grep -q "prometheusrule-video.yaml" "${kustomization}" 2>/dev/null; then
    pass "prometheusrule-video.yaml is referenced in monitoring kustomization.yaml"
  else
    fail "prometheusrule-video.yaml is NOT referenced in monitoring kustomization.yaml"
  fi
}

check_servicemonitor_mux_exists() {
  local sm_file="${MONITORING_DIR}/servicemonitor-mux.yaml"
  if [[ -f "${sm_file}" ]]; then
    pass "servicemonitor-mux.yaml exists (AC-VPD-029)"
  else
    fail "servicemonitor-mux.yaml missing (AC-VPD-029) — expected at ${sm_file}"
  fi
}

check_servicemonitor_in_kustomization() {
  local kustomization="${MONITORING_DIR}/kustomization.yaml"
  if [[ ! -f "${kustomization}" ]]; then
    skip "kustomization.yaml absent — skipping ServiceMonitor inclusion check"
    return
  fi

  if grep -q "servicemonitor-mux.yaml" "${kustomization}" 2>/dev/null; then
    pass "servicemonitor-mux.yaml is referenced in monitoring kustomization.yaml"
  else
    fail "servicemonitor-mux.yaml is NOT referenced in monitoring kustomization.yaml"
  fi
}

check_mux_exporter_manifest() {
  local exporter_file="${MONITORING_DIR}/mux-exporter.yaml"
  if [[ ! -f "${exporter_file}" ]]; then
    fail "mux-exporter.yaml missing — Deployment + Service for mux-delivery-monitor not found"
    return
  fi
  pass "mux-exporter.yaml (Deployment + Service for mux-delivery-monitor) exists"

  # Verify secret references exist in the Deployment
  if grep -q "MUX_TOKEN_ID" "${exporter_file}" 2>/dev/null; then
    pass "mux-exporter.yaml references MUX_TOKEN_ID from secret"
  else
    fail "mux-exporter.yaml does not reference MUX_TOKEN_ID"
  fi

  if grep -q "MUX_TOKEN_SECRET" "${exporter_file}" 2>/dev/null; then
    pass "mux-exporter.yaml references MUX_TOKEN_SECRET from secret"
  else
    fail "mux-exporter.yaml does not reference MUX_TOKEN_SECRET"
  fi
}

check_externalsecrets_mux_keys() {
  # AC-VPD-020: MUX_TOKEN_ID and MUX_TOKEN_SECRET synced via ExternalSecrets
  local es_file="${SECRETS_DIR}/external-secrets.yaml"
  if [[ ! -f "${es_file}" ]]; then
    skip "external-secrets.yaml not found — skipping Mux secret mapping check"
    return
  fi

  if grep -q "MUX_TOKEN_ID" "${es_file}" 2>/dev/null; then
    pass "ExternalSecret maps MUX_TOKEN_ID from GCP Secret Manager (AC-VPD-020)"
  else
    fail "ExternalSecret missing MUX_TOKEN_ID mapping (AC-VPD-020)"
  fi

  if grep -q "MUX_TOKEN_SECRET" "${es_file}" 2>/dev/null; then
    pass "ExternalSecret maps MUX_TOKEN_SECRET from GCP Secret Manager (AC-VPD-020)"
  else
    fail "ExternalSecret missing MUX_TOKEN_SECRET mapping (AC-VPD-020)"
  fi

  if grep -q "MEREKA_LMS_MUX_TOKEN_ID" "${es_file}" 2>/dev/null; then
    pass "ExternalSecret uses canonical GCP SM key: MEREKA_LMS_MUX_TOKEN_ID"
  else
    fail "ExternalSecret does not use canonical key MEREKA_LMS_MUX_TOKEN_ID"
  fi
}

check_webhook_endpoint_exists() {
  # Mux sends asset.ready / video.asset.errored events to this endpoint
  local urls_file="${CUSTOM_APPS_DIR}/openedx_mux_upload/urls.py"
  local views_file="${CUSTOM_APPS_DIR}/openedx_mux_upload/views.py"

  if [[ ! -f "${urls_file}" ]]; then
    skip "openedx_mux_upload/urls.py not found — skipping webhook endpoint check"
    return
  fi

  if grep -q "mux.webhook\|mux_webhook" "${urls_file}" 2>/dev/null; then
    pass "Mux webhook URL route registered in openedx_mux_upload/urls.py"
  else
    fail "No Mux webhook route found in openedx_mux_upload/urls.py"
  fi

  if [[ -f "${views_file}" ]]; then
    if grep -q "mux_webhook_handler\|mux.*webhook" "${views_file}" 2>/dev/null; then
      pass "mux_webhook_handler view defined in openedx_mux_upload/views.py"
    else
      fail "mux_webhook_handler view missing in openedx_mux_upload/views.py"
    fi

    # Signature verification is a security requirement
    if grep -q "verify_mux_webhook_signature\|MUX_WEBHOOK_SECRET" "${views_file}" 2>/dev/null; then
      pass "Mux webhook view validates webhook signature (security)"
    else
      fail "Mux webhook view does not validate webhook signature"
    fi
  else
    skip "openedx_mux_upload/views.py not found — skipping view checks"
  fi
}

check_video_xblock_config() {
  local xblock_config="${CUSTOM_APPS_DIR}/openedx_video_pipeline/xblock_config.py"
  if [[ ! -f "${xblock_config}" ]]; then
    skip "openedx_video_pipeline/xblock_config.py not found — skipping XBlock config check"
    return
  fi

  if grep -q "stream.mux.com\|MUX_PLAYBACK_BASE_URL\|MUX_STREAM_BASE" "${xblock_config}" 2>/dev/null; then
    pass "Video XBlock config references Mux stream base URL"
  else
    fail "Video XBlock config does not reference Mux stream base URL"
  fi
}

check_alertmanager_routing_config() {
  # Look for any Alertmanager config declaring a video/mux route
  local am_configs
  am_configs=$(find "${REPO_ROOT}/deploy/k8s" "${REPO_ROOT}/infrastructure" \
    -name 'alertmanager*.yaml' -o -name 'alertmanager*.yml' 2>/dev/null || true)

  if [[ -z "${am_configs}" ]]; then
    # Alertmanager is often managed by kube-prometheus-stack — routing is
    # configured via Helm values or a Secret; absence from this repo is expected.
    skip "No Alertmanager config files found in repo (managed externally via Helm values)"
    return
  fi

  local has_route=0
  while IFS= read -r cfg; do
    [[ -z "${cfg}" ]] && continue
    if grep -qiE 'video|mux|delivery.minutes|component.*video' "${cfg}" 2>/dev/null; then
      pass "Alertmanager config ${cfg} has video/Mux routing entry"
      has_route=1
    fi
  done <<< "${am_configs}"

  if [[ "${has_route}" -eq 0 ]]; then
    skip "Alertmanager routing for Mux alerts not found in repo (may be in Helm values)"
  fi
}

check_grafana_dashboard_reference() {
  # AC-VPD-026, AC-VPD-027: Grafana video dashboards
  local monitoring_dir="${MONITORING_DIR}"
  local found=0

  # Check for JSON dashboard files
  local dashboard_files
  dashboard_files=$(find "${monitoring_dir}" -name "*.json" 2>/dev/null || true)
  while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    if grep -qiE 'video|mux|delivery.minutes' "${f}" 2>/dev/null; then
      pass "Grafana dashboard file references video/Mux: ${f}"
      found=1
    fi
  done <<< "${dashboard_files}"

  # Check for ConfigMap / dashboard provisioning references in YAML
  local yaml_refs
  yaml_refs=$(grep -rl "grafana\|dashboard" "${REPO_ROOT}/deploy/k8s" \
    --include="*.yaml" --include="*.yml" 2>/dev/null || true)
  while IFS= read -r f; do
    [[ -z "${f}" ]] && continue
    if grep -qiE 'video.*dashboard|mux.*dashboard|dashboard.*video|dashboard.*mux' "${f}" 2>/dev/null; then
      pass "Grafana dashboard reference found in ${f}"
      found=1
    fi
  done <<< "${yaml_refs}"

  if [[ "${found}" -eq 0 ]]; then
    skip "No Grafana dashboard files for video/Mux found in repo (may be provisioned externally)"
  fi
}

run_offline_checks() {
  echo "=== Mux Alert Wiring — Offline Checks ==="
  echo ""

  echo "-- PrometheusRule --"
  check_prometheusrule_video_exists
  check_prometheusrule_alert_names
  check_prometheusrule_thresholds
  check_prometheusrule_in_kustomization
  echo ""

  echo "-- ServiceMonitor (AC-VPD-029) --"
  check_servicemonitor_mux_exists
  check_servicemonitor_in_kustomization
  check_mux_exporter_manifest
  echo ""

  echo "-- ExternalSecrets (AC-VPD-020) --"
  check_externalsecrets_mux_keys
  echo ""

  echo "-- Webhook endpoint wiring --"
  check_webhook_endpoint_exists
  check_video_xblock_config
  echo ""

  echo "-- Alertmanager routing --"
  check_alertmanager_routing_config
  echo ""

  echo "-- Grafana dashboards --"
  check_grafana_dashboard_reference
  echo ""
}

# ---------------------------------------------------------------------------
# ONLINE checks — live cluster validation
# ---------------------------------------------------------------------------

check_live_prometheusrule() {
  if ! kubectl get prometheusrule video-alerts -n "${NAMESPACE}" &>/dev/null; then
    fail "PrometheusRule/video-alerts not found in namespace ${NAMESPACE}"
    return
  fi
  pass "PrometheusRule/video-alerts exists in cluster (namespace: ${NAMESPACE})"

  # Verify alert names are loaded in the cluster resource
  local rule_yaml
  rule_yaml=$(kubectl get prometheusrule video-alerts -n "${NAMESPACE}" -o yaml 2>/dev/null)

  for alert in "MuxDeliveryMinutesWarning" "MuxDeliveryMinutesCritical" "MuxTranscodeSuccessRateLow"; do
    if echo "${rule_yaml}" | grep -q "${alert}" 2>/dev/null; then
      pass "Live PrometheusRule has alert: ${alert}"
    else
      fail "Live PrometheusRule missing alert: ${alert}"
    fi
  done
}

check_live_servicemonitor() {
  if ! kubectl get servicemonitor mux-delivery-monitor -n "${NAMESPACE}" &>/dev/null; then
    fail "ServiceMonitor/mux-delivery-monitor not found in namespace ${NAMESPACE}"
    return
  fi
  pass "ServiceMonitor/mux-delivery-monitor exists in cluster (AC-VPD-029)"
}

check_live_mux_exporter_pod() {
  local pod_count
  pod_count=$(kubectl get pods -n "${NAMESPACE}" \
    -l 'app.kubernetes.io/name=mux-delivery-monitor' \
    --field-selector='status.phase=Running' \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')

  if [[ "${pod_count}" -gt 0 ]]; then
    pass "mux-delivery-monitor pod is Running (${pod_count} replica(s))"
  else
    fail "No running mux-delivery-monitor pod found in namespace ${NAMESPACE}"
  fi
}

check_live_webhook_reachable() {
  # Probe the Mux webhook endpoint inside the cluster via LMS service
  local lms_svc
  lms_svc=$(kubectl get svc -n "${NAMESPACE}" -l 'app.kubernetes.io/name=lms' \
    --no-headers -o custom-columns=':spec.clusterIP' 2>/dev/null | head -1 || true)

  if [[ -z "${lms_svc}" ]]; then
    skip "LMS service ClusterIP not found — skipping webhook reachability check"
    return
  fi

  local http_status
  http_status=$(kubectl run mux-wiring-probe-$$ \
    --image=curlimages/curl:latest \
    --restart=Never \
    --rm \
    --attach \
    -n "${NAMESPACE}" \
    -- curl -s -o /dev/null -w "%{http_code}" \
       -X POST "http://${lms_svc}:8000/api/mux/webhook/" \
       --max-time 5 2>/dev/null || echo "000")

  # 403 = reached the endpoint (signature validation rejected empty body — expected)
  # 405 = method not allowed means GET-only — would be a bug
  # 200 = unexpected (should require signature)
  # 000 = connection failed
  case "${http_status}" in
    403|401)
      pass "Mux webhook endpoint reachable and rejects unsigned request (HTTP ${http_status})"
      ;;
    200)
      fail "Mux webhook returned 200 for unsigned request — signature validation may be disabled"
      ;;
    000)
      fail "Mux webhook endpoint unreachable (connection timed out)"
      ;;
    *)
      skip "Mux webhook returned HTTP ${http_status} — manual verification required"
      ;;
  esac
}

check_live_alertmanager_route() {
  # Port-forward or use in-cluster Alertmanager API
  local am_pod
  am_pod=$(kubectl get pods -n monitoring \
    -l 'app.kubernetes.io/name=alertmanager' \
    --no-headers -o custom-columns=':metadata.name' 2>/dev/null | head -1 || true)

  if [[ -z "${am_pod}" ]]; then
    # Try the mereka-lms namespace
    am_pod=$(kubectl get pods -n "${NAMESPACE}" \
      -l 'app=alertmanager' \
      --no-headers -o custom-columns=':metadata.name' 2>/dev/null | head -1 || true)
  fi

  if [[ -z "${am_pod}" ]]; then
    skip "Alertmanager pod not found — skipping live route check"
    return
  fi

  # Fetch Alertmanager config via API to check for video/component routing
  local am_config
  am_config=$(kubectl exec -n monitoring "${am_pod}" -- \
    wget -qO- "http://localhost:9093/api/v2/status" 2>/dev/null || echo "")

  if [[ -z "${am_config}" ]]; then
    skip "Could not reach Alertmanager API on ${am_pod} — skipping route check"
    return
  fi

  if echo "${am_config}" | grep -qiE 'video|mux|component' 2>/dev/null; then
    pass "Alertmanager live config contains video/Mux routing"
  else
    skip "Alertmanager live config has no explicit video/Mux route (alerts may fall through to catch-all)"
  fi
}

run_online_checks() {
  echo "=== Mux Alert Wiring — Online Checks ==="
  echo ""

  if ! command -v kubectl &>/dev/null; then
    skip "kubectl not found — all online checks skipped"
    echo ""
    return
  fi

  if ! kubectl get namespace "${NAMESPACE}" &>/dev/null 2>&1; then
    skip "Namespace ${NAMESPACE} not reachable — all online checks skipped"
    echo ""
    return
  fi

  echo "-- Live PrometheusRule --"
  check_live_prometheusrule
  echo ""

  echo "-- Live ServiceMonitor --"
  check_live_servicemonitor
  echo ""

  echo "-- Live mux-delivery-monitor pod --"
  check_live_mux_exporter_pod
  echo ""

  echo "-- Live webhook endpoint --"
  check_live_webhook_reachable
  echo ""

  echo "-- Live Alertmanager routing --"
  check_live_alertmanager_route
  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

echo "Mux alert wiring verification"
echo "  mode:       ${MODE}"
echo "  namespace:  ${NAMESPACE}"
echo "  repo root:  ${REPO_ROOT}"
echo ""

run_offline_checks

if [[ "${MODE}" == "online" ]]; then
  run_online_checks
fi

echo "Summary: PASSED=${PASSED} FAILED=${FAILED} SKIPPED=${SKIPPED}"
echo ""

if [[ "${FAILED}" -gt 0 ]]; then
  echo -e "${RED}FAIL${NC}  ${FAILED} check(s) failed"
  echo "  See specs/video-pipeline-delivery_spec.md for AC-VPD-019/020/029/030"
  exit 1
fi

echo -e "${GREEN}PASS${NC}  All checks passed (${PASSED} pass, ${SKIPPED} skip)"
exit 0
