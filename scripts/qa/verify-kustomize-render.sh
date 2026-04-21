#!/usr/bin/env bash
# @covers AC-001, AC-002
# @spec: k8s-deployment_spec.md
# Verify that Kustomize overlays render without errors and all resources
# are in the mereka-lms namespace.
#
# App repo ownership note:
#   deploy/k8s/overlays/local is app-owned. Environment overlays such as
#   production/rke2-nonprod are realized in bbi-infrastructure; if absent here,
#   default verification skips them instead of inventing an app-repo failure.
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
REQUIRE_PRODUCTION_OVERLAY="${VERIFY_KUSTOMIZE_REQUIRE_PRODUCTION_OVERLAY:-0}"
SCOPE_MODE="${VERIFY_KUSTOMIZE_RENDER_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_KUSTOMIZE_RENDER_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

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

should_skip_scope() {
    local path

    [[ "$SCOPE_MODE" == "changed" ]] || return 1
    [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        case "$path" in
            .github/workflows/ci.yml|\
            deploy/k8s/*|\
            scripts/qa/verify-kustomize-render.sh)
                return 1
                ;;
        esac
    done <<< "$CHANGED_FILES_RAW"

    return 0
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
        if [[ "${overlay}" == "production" && "${REQUIRE_PRODUCTION_OVERLAY}" != "1" ]]; then
            print_warning "Overlay directory not found: ${overlay_path} (infra-owned; skipping)"
            echo -e "\n${GREEN}PASSED${NC}: ${overlay} skipped (infra-owned overlay absent)\n"
            return 0
        fi
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
        fail_count=$((fail_count + 1))
        echo -e "\n${RED}FAILED${NC}: ${overlay} (1 checks failed)\n"
        return 1
    fi
    print_success "kubectl kustomize renders successfully"
    pass_count=$((pass_count + 1))
    local render_output; render_output=$(cat "${render_file}")

    # Check 4: No empty documents
    if echo "${render_output}" | grep -q '^---$' && ! echo "${render_output}" | grep -qv '^---$'; then
        print_error "Output contains only empty documents"
        fail_count=$((fail_count + 1))
    else
        print_success "No empty documents in output"
        pass_count=$((pass_count + 1))
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
        fail_count=$((fail_count + 1))
    else
        print_success "All namespaced resources have namespace: ${EXPECTED_NAMESPACE}"
        pass_count=$((pass_count + 1))
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
        pass_count=$((pass_count + 1))
    fi

    # Check 7: Count resources
    local resource_count
    resource_count=$(echo "${render_output}" | grep -c "^kind: " || true)
    print_success "Rendered ${resource_count} resources"

    # Summary
    echo ""
    if [[ ${fail_count} -eq 0 ]]; then
        echo -e "${GREEN}PASSED${NC}: ${overlay} (${pass_count} checks passed)"
        return 0
    else
        echo -e "${RED}FAILED${NC}: ${overlay} (${fail_count} checks failed, ${pass_count} passed)"
        return 1
    fi
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
        overlays_to_test=("local")
        if [[ -d "${OVERLAYS_DIR}/production" || "${REQUIRE_PRODUCTION_OVERLAY}" == "1" ]]; then
            overlays_to_test+=("production")
        fi
    fi

    if should_skip_scope; then
        echo "PASS verify-kustomize-render (scope skip: no kustomize-render-relevant changes)"
        exit 0
    fi

    # Check kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl not found — skipping kustomize render verification"
        exit 0
    fi

    print_header "Kustomize Render Verification"
    echo "Repository: ${REPO_ROOT}"
    echo "Testing overlays: ${overlays_to_test[*]}"
    echo ""

    # Test each overlay
    for overlay in "${overlays_to_test[@]}"; do
        verify_overlay "${overlay}"
        local result=$?
        if [[ ${result} -eq 0 ]]; then
            total_pass=$((total_pass + 1))
        else
            total_fail=$((total_fail + 1))
        fi
        echo ""
    done

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
