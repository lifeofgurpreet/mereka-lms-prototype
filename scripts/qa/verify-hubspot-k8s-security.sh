#!/usr/bin/env bash
# Verify HubSpot registration service K8s security hardening
# AC-HUB-023: Container read-only FS, non-root UID 1000
#
# Static checks:
#   - K8s Deployment manifest exists for hubspot-registration-service
#   - securityContext.runAsNonRoot = true
#   - securityContext.runAsUser = 1000
#   - securityContext.readOnlyRootFilesystem = true
#   - Dockerfile uses non-root USER
#
# Usage:
#   ./scripts/qa/verify-hubspot-k8s-security.sh
#
# Returns:
#   0 if security hardening is properly configured
#   1 if security issues found

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
failures=0

# =============================================================================
# Check 1: K8s Deployment manifest exists
# =============================================================================
check_deployment_manifest() {
  info "Checking for HubSpot registration service K8s manifests..."

  local manifests
  manifests=$(find deploy/k8s -name '*hubspot*' \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null || true)

  if [[ -z "${manifests}" ]]; then
    warn "  No K8s manifests found for hubspot-registration-service"
    warn "  Expected in: deploy/k8s/base/apps/hubspot-registration/"
    failures=$((failures + 1))
    return 1
  fi

  info "  Found manifests:"
  echo "${manifests}" | while IFS= read -r f; do echo "    - ${f}"; done
  return 0
}

# =============================================================================
# Check 2: SecurityContext in manifests
# =============================================================================
check_security_context() {
  info "Checking securityContext in K8s manifests..."

  local manifests
  manifests=$(find deploy/k8s -name '*hubspot*' \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null || true)

  if [[ -z "${manifests}" ]]; then
    warn "  Skipping: no manifests found"
    return 1
  fi

  local has_non_root=0
  local has_uid_1000=0
  local has_read_only=0

  while IFS= read -r manifest; do
    if [[ -z "${manifest}" ]]; then continue; fi

    if grep -q 'runAsNonRoot: true' "${manifest}" 2>/dev/null; then
      info "  ✓ runAsNonRoot: true in ${manifest}"
      has_non_root=1
    fi

    if grep -q 'runAsUser: 1000' "${manifest}" 2>/dev/null; then
      info "  ✓ runAsUser: 1000 in ${manifest}"
      has_uid_1000=1
    fi

    if grep -q 'readOnlyRootFilesystem: true' "${manifest}" 2>/dev/null; then
      info "  ✓ readOnlyRootFilesystem: true in ${manifest}"
      has_read_only=1
    fi
  done <<< "${manifests}"

  if [[ "${has_non_root}" -eq 0 ]]; then
    warn "  ✗ Missing: runAsNonRoot: true"
    failures=$((failures + 1))
  fi
  if [[ "${has_uid_1000}" -eq 0 ]]; then
    warn "  ✗ Missing: runAsUser: 1000"
    failures=$((failures + 1))
  fi
  if [[ "${has_read_only}" -eq 0 ]]; then
    warn "  ✗ Missing: readOnlyRootFilesystem: true"
    failures=$((failures + 1))
  fi
}

# =============================================================================
# Check 3: Dockerfile security
# =============================================================================
check_dockerfile() {
  info "Checking Dockerfile for non-root user..."

  local dockerfiles
  dockerfiles=$(find services/hubspot-webhook -name 'Dockerfile*' 2>/dev/null || true)

  if [[ -z "${dockerfiles}" ]]; then
    warn "  No Dockerfile found for hubspot-registration-service"
    warn "  Expected at: services/hubspot-webhook/Dockerfile"
    failures=$((failures + 1))
    return 1
  fi

  while IFS= read -r dockerfile; do
    if [[ -z "${dockerfile}" ]]; then continue; fi

    if grep -q 'USER 1000\|USER node\|USER appuser' "${dockerfile}" 2>/dev/null; then
      info "  ✓ Non-root USER directive in ${dockerfile}"
    else
      warn "  ✗ No non-root USER directive in ${dockerfile}"
      failures=$((failures + 1))
    fi
  done <<< "${dockerfiles}"
}

# =============================================================================
# Check 4: Live cluster security verification
# =============================================================================
check_live_security() {
  info "Checking live pod security context..."

  if ! command -v kubectl &>/dev/null; then
    warn "kubectl not found - skipping live check"
    return 0
  fi

  if ! kubectl get namespace "${NAMESPACE}" &>/dev/null 2>&1; then
    warn "Namespace ${NAMESPACE} not found - skipping live check"
    return 0
  fi

  local pods
  pods=$(kubectl get pods -n "${NAMESPACE}" -l app=hubspot-registration-service \
    -o name 2>/dev/null || true)

  if [[ -z "${pods}" ]]; then
    warn "  No hubspot-registration-service pods found in ${NAMESPACE}"
    return 0
  fi

  # Check pod security context
  local pod_name
  pod_name=$(echo "${pods}" | head -1)

  local uid
  uid=$(kubectl exec -n "${NAMESPACE}" "${pod_name}" -- id -u 2>/dev/null || echo "unknown")

  if [[ "${uid}" == "1000" ]]; then
    info "  ✓ Pod running as UID 1000"
  elif [[ "${uid}" != "unknown" ]]; then
    error "  ✗ Pod running as UID ${uid} (expected 1000)"
    failures=$((failures + 1))
  fi
}

# =============================================================================
# Main
# =============================================================================
main() {
  info "Verifying HubSpot registration service security hardening..."
  info "Spec reference: AC-HUB-023"
  echo

  check_deployment_manifest
  echo
  check_security_context
  echo
  check_dockerfile
  echo
  check_live_security

  echo
  if [[ "${failures}" -eq 0 ]]; then
    info "HubSpot service security hardening verified"
    exit 0
  else
    error "${failures} security hardening issue(s) found"
    error "  See specs/external-registration-hubspot_spec.md AC-HUB-023"
    exit 1
  fi
}

main "$@"
