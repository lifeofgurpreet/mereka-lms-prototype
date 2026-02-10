#!/usr/bin/env bash
# Verify HubSpot registration service alert rules in K8s manifests
# AC-HUB-026: Alert fires when user creation success rate < 95%
#
# Static checks:
#   - PrometheusRule manifests define HubSpot-specific alerts
#   - Expected alerts: HighFailureRate, ServiceDown, SignatureSpike, DLQBacklog, EmailFailure
#   - ServiceMonitor exists for metric scraping
#
# Usage:
#   ./scripts/qa/verify-hubspot-alerts.sh
#
# Returns:
#   0 if all alert rules are defined
#   1 if alert rules are missing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

MONITORING_DIR="deploy/k8s/base/monitoring"

# Expected alert names per spec Observability section
EXPECTED_ALERTS=(
  "HubSpotRegistrationHighFailureRate"
  "HubSpotRegistrationServiceDown"
  "HubSpotSignatureVerificationSpike"
  "HubSpotDLQBacklog"
  "HubSpotEmailFailureRate"
)

failures=0

# =============================================================================
# Check 1: PrometheusRule manifests
# =============================================================================
check_prometheusrules() {
  info "Checking PrometheusRule manifests for HubSpot alerts..."

  local rule_files
  rule_files=$(find "${MONITORING_DIR}" -name 'prometheusrule*.yaml' -o -name 'prometheusrule*.yml' 2>/dev/null || true)

  if [[ -z "${rule_files}" ]]; then
    error "No PrometheusRule files found in ${MONITORING_DIR}"
    failures=$((failures + 1))
    return 1
  fi

  local found=0
  for alert_name in "${EXPECTED_ALERTS[@]}"; do
    local alert_found=0
    while IFS= read -r rule_file; do
      if [[ -z "${rule_file}" ]]; then continue; fi
      if grep -q "${alert_name}" "${rule_file}" 2>/dev/null; then
        info "  ✓ ${alert_name} found in ${rule_file}"
        alert_found=1
        found=$((found + 1))
        break
      fi
    done <<< "${rule_files}"

    if [[ "${alert_found}" -eq 0 ]]; then
      warn "  ✗ ${alert_name} NOT found in any PrometheusRule"
    fi
  done

  info "  Found ${found}/${#EXPECTED_ALERTS[@]} expected HubSpot alerts"

  if [[ "${found}" -lt "${#EXPECTED_ALERTS[@]}" ]]; then
    failures=$((failures + 1))
  fi
}

# =============================================================================
# Check 2: ServiceMonitor for metric scraping
# =============================================================================
check_servicemonitor() {
  info "Checking for HubSpot ServiceMonitor..."

  local sm_files
  sm_files=$(find deploy/k8s -name '*servicemonitor*hubspot*' -o -name '*hubspot*servicemonitor*' 2>/dev/null || true)

  if [[ -z "${sm_files}" ]]; then
    # Also check inside monitoring directory for combined ServiceMonitor
    sm_files=$(grep -rl 'hubspot-registration-service' deploy/k8s/base/monitoring/ 2>/dev/null || true)
  fi

  if [[ -n "${sm_files}" ]]; then
    info "  ✓ HubSpot ServiceMonitor found: ${sm_files}"
  else
    warn "  ✗ No ServiceMonitor for hubspot-registration-service"
    warn "    Expected: deploy/k8s/base/monitoring/servicemonitor-hubspot.yaml"
    failures=$((failures + 1))
  fi
}

# =============================================================================
# Main
# =============================================================================
main() {
  info "Verifying HubSpot registration service alert configuration..."
  info "Spec reference: AC-HUB-026 + Observability section"
  echo

  check_prometheusrules
  echo
  check_servicemonitor

  echo
  if [[ "${failures}" -eq 0 ]]; then
    info "HubSpot alert configuration verified"
    exit 0
  else
    error "${failures} alert configuration issue(s) found"
    error "  See specs/external-registration-hubspot_spec.md Observability > Alerts"
    exit 1
  fi
}

main "$@"
