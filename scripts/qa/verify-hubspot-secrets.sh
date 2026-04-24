#!/usr/bin/env bash
# @covers AC-HUB-005
# @spec: proposals/external-registration-hubspot_spec.md
# Verify HubSpot service secrets in ExternalSecrets and K8s
# AC-HUB-005: HubSpot OAuth credentials in Infisical/ExternalSecrets
#
# Static checks:
#   - ExternalSecrets YAML defines HUBSPOT_CLIENT_ID, HUBSPOT_CLIENT_SECRET, etc.
#   - SENDGRID_API_KEY defined
#   - OPENEDX_SERVICE_ACCOUNT credentials defined
#
# Live checks (skipped if kubectl unavailable):
#   - Secrets exist in K8s namespace
#
# Usage:
#   ./scripts/qa/verify-hubspot-secrets.sh
#
# Returns:
#   0 if all required secrets are defined
#   1 if secrets are missing

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

NAMESPACE="${K8S_NAMESPACE}"
EXTERNAL_SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"

# Required secrets per spec
REQUIRED_SECRETS=(
  "MEREKA_LMS_HUBSPOT_CLIENT_ID"
  "MEREKA_LMS_HUBSPOT_CLIENT_SECRET"
  "MEREKA_LMS_HUBSPOT_REFRESH_TOKEN"
  "MEREKA_LMS_SENDGRID_API_KEY"
  "MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_USERNAME"
  "MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_PASSWORD"
)

# =============================================================================
# Static Check: ExternalSecrets manifest
# =============================================================================
check_external_secrets() {
  info "Checking ExternalSecrets manifest for HubSpot secrets..."

  if [[ ! -f "${EXTERNAL_SECRETS_FILE}" ]]; then
    error "ExternalSecrets file not found: ${EXTERNAL_SECRETS_FILE}"
    return 1
  fi

  local missing=0
  for secret in "${REQUIRED_SECRETS[@]}"; do
    if grep -q "${secret}" "${EXTERNAL_SECRETS_FILE}"; then
      info "  ✓ ${secret} defined"
    else
      warn "  ✗ ${secret} NOT found in ExternalSecrets"
      missing=$((missing + 1))
    fi
  done

  if [[ "${missing}" -gt 0 ]]; then
    error "  ${missing} required HubSpot secrets missing from ExternalSecrets"
    return 1
  fi

  info "  All ${#REQUIRED_SECRETS[@]} required secrets defined"
  return 0
}

# =============================================================================
# Static Check: Dedicated HubSpot ExternalSecret resource
# =============================================================================
check_dedicated_external_secret() {
  info "Checking for dedicated HubSpot ExternalSecret resource..."

  local hubspot_es
  hubspot_es=$(find deploy/k8s -name '*hubspot*' -name '*.yaml' -o -name '*hubspot*' -name '*.yml' 2>/dev/null || true)

  if [[ -n "${hubspot_es}" ]]; then
    info "  ✓ Found dedicated HubSpot ExternalSecret: ${hubspot_es}"
    return 0
  else
    warn "  ✗ No dedicated HubSpot ExternalSecret resource found"
    warn "    Expected: deploy/k8s/base/secrets/hubspot-registration-secrets.yaml"
    return 1
  fi
}

# =============================================================================
# Live Check: K8s secrets
# =============================================================================
check_k8s_secrets() {
  info "Checking K8s secrets in namespace ${NAMESPACE}..."

  if ! command -v kubectl &>/dev/null; then
    warn "kubectl not found - skipping live K8s check"
    return 0
  fi

  if ! kubectl get namespace "${NAMESPACE}" &>/dev/null 2>&1; then
    warn "Namespace ${NAMESPACE} not found - skipping live K8s check"
    return 0
  fi

  # Check for hubspot-registration-secrets
  if kubectl get secret hubspot-registration-secrets -n "${NAMESPACE}" &>/dev/null 2>&1; then
    info "  ✓ hubspot-registration-secrets exists in K8s"
    local keys
    keys=$(kubectl get secret hubspot-registration-secrets -n "${NAMESPACE}" \
      -o jsonpath='{.data}' 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "")
    if [[ -n "${keys}" ]]; then
      info "  Secret keys: ${keys}"
    fi
  else
    warn "  ✗ hubspot-registration-secrets not found in K8s namespace"
  fi

  return 0
}

# =============================================================================
# Main
# =============================================================================
main() {
  info "Verifying HubSpot registration service secrets..."
  echo

  local exit_code=0

  if ! check_external_secrets; then
    exit_code=1
  fi

  echo

  if ! check_dedicated_external_secret; then
    exit_code=1
  fi

  echo

  check_k8s_secrets

  echo
  if [[ "${exit_code}" -eq 0 ]]; then
    info "HubSpot secrets configuration verified"
  else
    error "HubSpot secrets configuration incomplete"
    error "  See specs/proposals/external-registration-hubspot_spec.md for required secrets"
  fi

  return "${exit_code}"
}

main "$@"
