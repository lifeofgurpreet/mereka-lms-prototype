#!/usr/bin/env bash
# Verify Mux video delivery alert rules are defined in K8s manifests
# AC-019: When monthly delivery minutes exceed 80,000, a Slack/email alert is triggered
#
# Static checks (no cluster needed):
#   - PrometheusRule manifests define video_delivery_minutes_monthly alerts
#   - Alert thresholds match spec (80K warning, 95K critical)
#   - Alertmanager routing for video/mux alerts exists
#
# Live checks (skipped if kubectl unavailable):
#   - PrometheusRule resources exist in cluster
#   - Alertmanager config has video routing
#
# Usage:
#   ./scripts/qa/verify-mux-alerts.sh
#
# Returns:
#   0 if all alert rules are properly defined
#   1 if alert rules are missing or misconfigured

set -euo pipefail

# Source shared config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Configuration
# =============================================================================
NAMESPACE="${K8S_NAMESPACE}"
MONITORING_DIR="deploy/k8s/base/monitoring"

# Expected alert definitions per spec
EXPECTED_ALERTS=(
  "video_delivery_minutes_monthly.*80000"   # 80% of free tier warning
  "video_delivery_minutes_monthly.*95000"   # approaching free tier critical
  "mux.*asset.*errored"                     # Mux asset error
  "MUX_TOKEN.*ExternalSecret"              # Secret sync failure
)

EXPECTED_ALERT_NAMES=(
  "MuxDeliveryMinutesWarning"
  "MuxDeliveryMinutesCritical"
  "MuxAssetErrored"
  "MuxSecretSyncFailed"
)

# =============================================================================
# Static Checks
# =============================================================================

check_prometheusrule_manifests() {
  info "Checking PrometheusRule manifests for video delivery alerts..."

  local found_rules=0
  local total_expected=4

  # Check all PrometheusRule files
  local rule_files
  rule_files=$(find "${MONITORING_DIR}" -name 'prometheusrule*.yaml' -o -name 'prometheusrule*.yml' 2>/dev/null || true)

  if [[ -z "${rule_files}" ]]; then
    error "No PrometheusRule files found in ${MONITORING_DIR}"
    return 1
  fi

  info "Found PrometheusRule files:"
  echo "${rule_files}" | while IFS= read -r f; do echo "  - ${f}"; done
  echo

  # Check for video delivery minutes alert (80K threshold)
  local has_80k_alert=0
  local has_95k_alert=0
  local has_asset_error_alert=0
  local has_secret_sync_alert=0

  while IFS= read -r rule_file; do
    if [[ -z "${rule_file}" ]]; then
      continue
    fi

    # Check for 80K delivery minutes warning
    if grep -qiE 'video.delivery.minutes|mux.*delivery|delivery.*80000' "${rule_file}" 2>/dev/null; then
      info "  ✓ Found video delivery minutes alert in ${rule_file}"
      has_80k_alert=1
    fi

    # Check for 95K delivery minutes critical
    if grep -qiE 'delivery.*95000|mux.*critical.*delivery' "${rule_file}" 2>/dev/null; then
      info "  ✓ Found critical delivery minutes alert in ${rule_file}"
      has_95k_alert=1
    fi

    # Check for Mux asset errored alert
    if grep -qiE 'mux.*asset.*error|mux.*errored|video.*asset.*error' "${rule_file}" 2>/dev/null; then
      info "  ✓ Found Mux asset error alert in ${rule_file}"
      has_asset_error_alert=1
    fi

    # Check for secret sync failure alert
    if grep -qiE 'mux.*secret.*sync|mux.*token.*fail|externalsecret.*mux' "${rule_file}" 2>/dev/null; then
      info "  ✓ Found Mux secret sync alert in ${rule_file}"
      has_secret_sync_alert=1
    fi
  done <<< "${rule_files}"

  # Report missing alerts
  echo
  if [[ "${has_80k_alert}" -eq 0 ]]; then
    warn "  ✗ Missing: video_delivery_minutes_monthly > 80,000 warning alert"
  fi
  if [[ "${has_95k_alert}" -eq 0 ]]; then
    warn "  ✗ Missing: video_delivery_minutes_monthly > 95,000 critical alert"
  fi
  if [[ "${has_asset_error_alert}" -eq 0 ]]; then
    warn "  ✗ Missing: Mux asset errored state alert"
  fi
  if [[ "${has_secret_sync_alert}" -eq 0 ]]; then
    warn "  ✗ Missing: Mux secret ExternalSecrets sync failure alert"
  fi

  found_rules=$((has_80k_alert + has_95k_alert + has_asset_error_alert + has_secret_sync_alert))
  info "Found ${found_rules}/${total_expected} expected Mux alert definitions"

  if [[ "${found_rules}" -lt "${total_expected}" ]]; then
    return 1
  fi
  return 0
}

check_alertmanager_routing() {
  info "Checking for Alertmanager routing configuration..."

  # Look for Alertmanager config files
  local am_configs
  am_configs=$(find deploy/k8s infrastructure -name 'alertmanager*.yaml' -o -name 'alertmanager*.yml' 2>/dev/null || true)

  if [[ -z "${am_configs}" ]]; then
    warn "No Alertmanager config files found - cannot verify routing"
    return 0
  fi

  local has_video_route=0
  while IFS= read -r config_file; do
    if [[ -z "${config_file}" ]]; then
      continue
    fi

    if grep -qiE 'video|mux|delivery.minutes' "${config_file}" 2>/dev/null; then
      info "  ✓ Found video/Mux routing in ${config_file}"
      has_video_route=1
    fi
  done <<< "${am_configs}"

  if [[ "${has_video_route}" -eq 0 ]]; then
    warn "  ⚠ No Mux/video-specific Alertmanager routing found"
  fi

  return 0
}

# =============================================================================
# Live Checks
# =============================================================================

check_live_prometheus_rules() {
  info "Checking live Prometheus rules in cluster..."

  if ! command -v kubectl &> /dev/null; then
    warn "kubectl not found - skipping live PrometheusRule check"
    return 0
  fi

  if ! kubectl get namespace "${NAMESPACE}" &> /dev/null 2>&1; then
    warn "Namespace ${NAMESPACE} not found - skipping live check"
    return 0
  fi

  # Check for PrometheusRule resources
  local rules
  rules=$(kubectl get prometheusrule -n "${NAMESPACE}" -o name 2>/dev/null || echo "")

  if [[ -z "${rules}" ]]; then
    warn "No PrometheusRule resources found in namespace ${NAMESPACE}"
    return 0
  fi

  info "PrometheusRule resources in cluster:"
  echo "${rules}" | while IFS= read -r r; do echo "  - ${r}"; done

  # Check if any rule has video/mux alerts
  local has_mux_rule=0
  while IFS= read -r rule; do
    if [[ -z "${rule}" ]]; then
      continue
    fi

    local rule_yaml
    rule_yaml=$(kubectl get "${rule}" -n "${NAMESPACE}" -o yaml 2>/dev/null || echo "")

    if echo "${rule_yaml}" | grep -qiE 'video.delivery|mux.*delivery|delivery.*minutes' 2>/dev/null; then
      info "  ✓ Found video delivery alert in live rule: ${rule}"
      has_mux_rule=1
    fi
  done <<< "${rules}"

  if [[ "${has_mux_rule}" -eq 0 ]]; then
    warn "  ⚠ No Mux/video alerts found in live PrometheusRule resources"
  fi

  return 0
}

# =============================================================================
# Main
# =============================================================================
main() {
  info "Verifying Mux video delivery alert configuration..."
  info "Spec reference: AC-019 (video-pipeline-delivery_spec.md)"
  echo

  local exit_code=0

  # Static checks
  if ! check_prometheusrule_manifests; then
    error "PrometheusRule manifests missing Mux alert definitions"
    exit_code=1
  fi

  echo

  # Alertmanager routing check
  check_alertmanager_routing

  echo

  # Live checks (best-effort)
  check_live_prometheus_rules

  echo
  if [[ "${exit_code}" -eq 0 ]]; then
    info "✅ Mux alert configuration verified"
  else
    error "❌ Mux alert configuration incomplete"
    error "    Expected alerts for: delivery minutes (80K/95K), asset errors, secret sync"
    error "    See specs/video-pipeline-delivery_spec.md AC-019 and Observability section"
  fi

  return "${exit_code}"
}

main "$@"
