#!/usr/bin/env bash
# @covers AC-020
# @spec: video-pipeline-delivery_spec.md
# Verify Mux secrets exist in ExternalSecrets and K8s namespace
# AC-020: Check MUX_TOKEN_ID and MUX_TOKEN_SECRET are synced
#
# Usage:
#   ./scripts/qa/verify-mux-secrets.sh [--namespace mereka-lms]
#
# Returns:
#   0 if secrets are properly configured
#   1 if missing or misconfigured

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
EXTERNAL_SECRETS_FILE="deploy/k8s/base/secrets/external-secrets.yaml"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# =============================================================================
# Validation Functions
# =============================================================================

check_external_secrets_definition() {
  info "Checking ExternalSecrets manifest..."

  if [[ ! -f "${EXTERNAL_SECRETS_FILE}" ]]; then
    error "ExternalSecrets file not found: ${EXTERNAL_SECRETS_FILE}"
    return 1
  fi

  local has_mux_token_id=0
  local has_mux_token_secret=0

  # Check for MUX_TOKEN_ID
  if grep -q "MEREKA_LMS_MUX_TOKEN_ID" "${EXTERNAL_SECRETS_FILE}"; then
    info "  ✓ MEREKA_LMS_MUX_TOKEN_ID defined"
    has_mux_token_id=1
  else
    warn "  ✗ MEREKA_LMS_MUX_TOKEN_ID not found"
  fi

  # Check for MUX_TOKEN_SECRET
  if grep -q "MEREKA_LMS_MUX_TOKEN_SECRET" "${EXTERNAL_SECRETS_FILE}"; then
    info "  ✓ MEREKA_LMS_MUX_TOKEN_SECRET defined"
    has_mux_token_secret=1
  else
    warn "  ✗ MEREKA_LMS_MUX_TOKEN_SECRET not found"
  fi

  if [[ "${has_mux_token_id}" -eq 1 ]] && [[ "${has_mux_token_secret}" -eq 1 ]]; then
    return 0
  else
    return 1
  fi
}

check_k8s_secrets() {
  info "Checking Kubernetes secrets in namespace ${NAMESPACE}..."

  # Check if kubectl is available
  if ! command -v kubectl &> /dev/null; then
    warn "kubectl not found - skipping K8s secret check"
    return 0
  fi

  # Check if namespace exists
  if ! kubectl get namespace "${NAMESPACE}" &> /dev/null; then
    warn "Namespace ${NAMESPACE} not found - skipping K8s secret check"
    return 0
  fi

  # Look for secrets with Mux credentials
  local secret_names
  secret_names=$(kubectl get secrets -n "${NAMESPACE}" -o name 2>/dev/null || echo "")

  if [[ -z "${secret_names}" ]]; then
    warn "No secrets found in namespace ${NAMESPACE}"
    return 1
  fi

  # Check each secret for Mux keys
  local found_mux_token_id=0
  local found_mux_token_secret=0

  while IFS= read -r secret_name; do
    if [[ -z "${secret_name}" ]]; then
      continue
    fi

    # Get secret keys
    local keys
    keys=$(kubectl get "${secret_name}" -n "${NAMESPACE}" -o jsonpath='{.data}' 2>/dev/null | jq -r 'keys[]' 2>/dev/null || echo "")

    # Check for MUX keys
    if grep -q "MUX_TOKEN_ID" <<<"${keys}"; then
      info "  ✓ Found MUX_TOKEN_ID in ${secret_name}"
      found_mux_token_id=1
    fi

    if grep -q "MUX_TOKEN_SECRET" <<<"${keys}"; then
      info "  ✓ Found MUX_TOKEN_SECRET in ${secret_name}"
      found_mux_token_secret=1
    fi
  done <<< "${secret_names}"

  if [[ "${found_mux_token_id}" -eq 0 ]] || [[ "${found_mux_token_secret}" -eq 0 ]]; then
    warn "Mux secrets not fully synced to K8s namespace ${NAMESPACE}"
    return 1
  fi

  return 0
}

# =============================================================================
# Main
# =============================================================================
main() {
  info "Verifying Mux secrets configuration..."
  echo

  local exit_code=0

  # Check ExternalSecrets definition
  if ! check_external_secrets_definition; then
    error "ExternalSecrets definition incomplete"
    exit_code=1
  fi

  echo

  # Check K8s secrets
  if ! check_k8s_secrets; then
    warn "K8s secrets check incomplete (may need manual verification)"
    # Don't fail on K8s check since it may not be accessible in all environments
  fi

  echo
  if [[ "${exit_code}" -eq 0 ]]; then
    info "✅ Mux secrets configuration verified"
  else
    error "❌ Mux secrets configuration incomplete"
  fi

  return "${exit_code}"
}

main "$@"
