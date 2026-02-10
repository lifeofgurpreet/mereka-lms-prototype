#!/usr/bin/env bash
# Verify that Kustomize overlays render without errors and all resources
# are in the mereka-lms namespace.
#
# Usage:
#   scripts/qa/verify-kustomize-render.sh [--overlay local|production]
#
# Examples:
#   scripts/qa/verify-kustomize-render.sh              # Test both overlays
#   scripts/qa/verify-kustomize-render.sh --overlay local
#   scripts/qa/verify-kustomize-render.sh --overlay production

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OVERLAYS_DIR="${REPO_ROOT}/deploy/k8s/overlays"
EXPECTED_NAMESPACE="mereka-lms"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Expected resource types (at minimum)
EXPECTED_RESOURCE_TYPES=(
    "Namespace"
    "Deployment"
    "Service"
    "PersistentVolumeClaim"
    "ConfigMap"
)

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [--overlay OVERLAY]

Verify that Kustomize overlays render without errors and all resources
are in the mereka-lms namespace.

Options:
  --overlay OVERLAY    Test specific overlay (local|production)
                      If not specified, tests both overlays

Examples:
  $(basename "$0")                    # Test both overlays
  $(basename "$0") --overlay local    # Test local only
  $(basename "$0") --overlay production
EOF
}

# =============================================================================
# Verification Functions
# =============================================================================

verify_overlay() {
    local overlay="$1"
    local overlay_path="${OVERLAYS_DIR}/${overlay}"
    local pass_count=0
    local fail_count=0

    print_header "Verifying overlay: ${overlay}"

    # Check 1: Overlay directory exists
    if [[ ! -d "${overlay_path}" ]]; then
        print_error "Overlay directory not found: ${overlay_path}"
        return 1
    fi
    print_success "Overlay directory exists"

    # Check 2: kustomization.yaml exists
    if [[ ! -f "${overlay_path}/kustomization.yaml" ]]; then
        print_error "kustomization.yaml not found in ${overlay_path}"
        return 1
    fi
    print_success "kustomization.yaml exists"

    # Check 3: Render with kubectl kustomize
    local render_file
    render_file=$(mktemp "/tmp/kustomize-${overlay}.XXXXXX.yaml")

    if ! kubectl kustomize "${overlay_path}" > "${render_file}" 2>&1; then
        print_error "Failed to render overlay: ${overlay}"
        cat "${render_file}" | sed 's/^/  /' >&2
        rm -f "${render_file}"
        ((fail_count++))
        echo -e "\n${RED}FAILED${NC}: ${overlay} (1 checks failed)\n"
        return 1
    fi
    print_success "kubectl kustomize renders successfully"
    ((pass_count++))

    # Check 4: No empty documents
    if echo "${render_output}" | grep -q '^---$' && ! echo "${render_output}" | grep -qv '^---$'; then
        print_error "Output contains only empty documents"
        ((fail_count++))
    else
        print_success "No empty documents in output"
        ((pass_count++))
    fi

    # Check 5: All resources have namespace: mereka-lms (except cluster-scoped resources)
    # Use a simple grep-based check without temp files or complex parsing
    local cluster_scoped_pattern="ClusterRole|ClusterRoleBinding|ClusterIssuer|ClusterSecretStore|CustomResourceDefinition|Namespace"
    local total_namespaced
    total_namespaced=$(echo "${render_output}" | grep "^kind: " | grep -Ev "^kind: (${cluster_scoped_pattern})$" | wc -l || true)

    # Count occurrences of "namespace: mereka-lms"
    local namespace_count
    namespace_count=$(echo "${render_output}" | grep -c "^  namespace: ${EXPECTED_NAMESPACE}$" || true)

    if [[ ${namespace_count} -lt ${total_namespaced} ]]; then
        local missing=$((total_namespaced - namespace_count))
        print_error "Found ${missing} resources without namespace: ${EXPECTED_NAMESPACE}"
        ((fail_count++))
    else
        print_success "All namespaced resources have namespace: ${EXPECTED_NAMESPACE}"
        ((pass_count++))
    fi

    # Check 6: Expected resource types present
    local missing_types=()
    for expected_type in "${EXPECTED_RESOURCE_TYPES[@]}"; do
        if ! echo "${render_output}" | grep -E "^kind:[[:space:]]+${expected_type}$" > /dev/null; then
            missing_types+=("${expected_type}")
        fi
    done

    if [[ ${#missing_types[@]} -gt 0 ]]; then
        print_warning "Missing expected resource types: ${missing_types[*]}"
        # This is a warning, not a failure
    else
        print_success "All expected resource types present"
        ((pass_count++))
    fi

    # Check 7: Count resources
    local resource_count
    resource_count=$(echo "${render_output}" | grep -c "^kind: " || true)
    print_success "Rendered ${resource_count} resources"

    # Summary
    echo ""
    if [[ ${fail_count} -eq 0 ]]; then
        echo -e "${GREEN}PASSED${NC}: ${overlay} (${pass_count} checks passed)"
        echo "DEBUG: About to return 0 from verify_overlay" >&2
        return 0
    else
        echo -e "${RED}FAILED${NC}: ${overlay} (${fail_count} checks failed, ${pass_count} passed)"
        echo "DEBUG: About to return 1 from verify_overlay" >&2
        return 1
    fi
    echo "DEBUG: Should never reach here" >&2
}

# =============================================================================
# Main
# =============================================================================

main() {
    local overlays_to_test=()
    local total_pass=0
    local total_fail=0

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --overlay)
                shift
                if [[ -z "${1:-}" ]]; then
                    echo "ERROR: --overlay requires an argument" >&2
                    usage
                    exit 1
                fi
                overlays_to_test+=("$1")
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "ERROR: Unknown argument: $1" >&2
                usage
                exit 1
                ;;
        esac
    done

    # If no overlay specified, test both
    if [[ ${#overlays_to_test[@]} -eq 0 ]]; then
        overlays_to_test=("local" "production")
    fi

    # Check kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    print_header "Kustomize Render Verification"
    echo "Repository: ${REPO_ROOT}"
    echo "Testing overlays: ${overlays_to_test[*]}"
    echo ""

    # Test each overlay
    for overlay in "${overlays_to_test[@]}"; do
        echo "DEBUG: Starting verification for overlay: ${overlay}" >&2
        verify_overlay "${overlay}"
        local result=$?
        echo "DEBUG: verify_overlay returned: ${result}" >&2
        if [[ ${result} -eq 0 ]]; then
            ((total_pass++))
            echo "DEBUG: ${overlay} PASSED, total_pass=${total_pass}" >&2
        else
            ((total_fail++))
            echo "DEBUG: ${overlay} FAILED, total_fail=${total_fail}" >&2
        fi
        echo ""
        echo "DEBUG: Completed ${overlay}, moving to next" >&2
    done
    echo "DEBUG: Loop completed, total_pass=${total_pass} total_fail=${total_fail}" >&2

    # Final summary
    print_header "Summary"
    echo "Overlays tested: ${#overlays_to_test[@]}"
    echo -e "${GREEN}Passed:${NC} ${total_pass}"
    echo -e "${RED}Failed:${NC} ${total_fail}"
    echo ""

    if [[ ${total_fail} -eq 0 ]]; then
        echo -e "${GREEN}All overlays verified successfully!${NC}"
        exit 0
    else
        echo -e "${RED}Some overlays failed verification.${NC}"
        exit 1
    fi
}

main "$@"
