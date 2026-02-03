#!/usr/bin/env bash
# Shared bash library for mereka-lms scripts
# Source this file: source "$(dirname "$0")/../shared/lib.sh"

set -euo pipefail

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_success() {
    echo "[OK] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# ============================================================================
# Kubernetes Helpers
# ============================================================================

k8s_namespace() {
    echo "${K8S_NAMESPACE:-mereka-lms}"
}

k8s_context() {
    echo "${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
}

k8s_wait_for_rollout() {
    local deployment="$1"
    local timeout="${2:-120s}"
    kubectl rollout status "deployment/$deployment" -n "$(k8s_namespace)" --timeout="$timeout"
}

k8s_get_pods() {
    local label="${1:-}"
    if [[ -n "$label" ]]; then
        kubectl get pods -n "$(k8s_namespace)" -l "$label" -o wide
    else
        kubectl get pods -n "$(k8s_namespace)" -o wide
    fi
}

k8s_logs() {
    local deployment="$1"
    local tail="${2:-100}"
    kubectl logs -n "$(k8s_namespace)" "deployment/$deployment" --tail="$tail"
}

# ============================================================================
# GCP Helpers
# ============================================================================

gcp_project() {
    echo "${GCP_PROJECT:-bbi-k8}"
}

gcp_region() {
    echo "${GCP_REGION:-asia-southeast1}"
}

# ============================================================================
# Validation Helpers
# ============================================================================

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        exit 1
    fi
}

require_env() {
    local var="$1"
    if [[ -z "${!var:-}" ]]; then
        log_error "Required environment variable not set: $var"
        exit 1
    fi
}

# ============================================================================
# Confirmation
# ============================================================================

confirm() {
    local prompt="${1:-Are you sure?}"
    read -r -p "$prompt [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}
