#!/usr/bin/env bash
# Central configuration for Mereka LMS scripts
# Override any value with environment variables
#
# Usage: source scripts/shared/config.sh

set -euo pipefail

# =============================================================================
# Source shared library (if available)
# =============================================================================
_SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_SHARED_DIR}/lib.sh" ]]; then
    # shellcheck source=lib.sh
    source "${_SHARED_DIR}/lib.sh"
fi
unset _SHARED_DIR

# =============================================================================
# GCP Settings
# =============================================================================
export GCP_PROJECT="${GCP_PROJECT:-mereka-lms}"
export GCP_REGION="${GCP_REGION:-asia-southeast1}"
export GCP_ZONE="${GCP_ZONE:-asia-southeast1-b}"

# =============================================================================
# Kubernetes Settings
# =============================================================================
export K8S_NAMESPACE="${K8S_NAMESPACE:-mereka-lms}"
export K8S_CONTEXT="${K8S_CONTEXT:-gke_${GCP_PROJECT}_${GCP_ZONE}_mereka-lms}"
export K8S_CLUSTER="${K8S_CLUSTER:-mereka-lms}"

# =============================================================================
# Domain Settings
# =============================================================================
# Production
export LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
export STUDIO_DOMAIN="${STUDIO_DOMAIN:-studio.${LMS_DOMAIN}}"
export MFE_DOMAIN="${MFE_DOMAIN:-apps.${LMS_DOMAIN}}"
export PREVIEW_DOMAIN="${PREVIEW_DOMAIN:-preview.${LMS_DOMAIN}}"

# Alternative domains (multisite)
export BIJI_DOMAIN="${BIJI_DOMAIN:-academy.biji-biji.com}"
export SKILLOURFUTURE_DOMAIN="${SKILLOURFUTURE_DOMAIN:-skillourfuture.academy.mereka.io}"

# Development
export DEV_LMS_DOMAIN="${DEV_LMS_DOMAIN:-academyv2.mereka.dev}"

# =============================================================================
# Container Registry
# =============================================================================
export REGISTRY="${REGISTRY:-${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/openedx}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"

# =============================================================================
# Database Settings (hostnames only, no passwords)
# =============================================================================
export MYSQL_HOST="${MYSQL_HOST:-mysql}"
export MYSQL_PORT="${MYSQL_PORT:-3306}"
export MONGODB_HOST="${MONGODB_HOST:-mongodb}"
export MONGODB_PORT="${MONGODB_PORT:-27017}"
export REDIS_HOST="${REDIS_HOST:-redis}"
export REDIS_PORT="${REDIS_PORT:-6379}"

# =============================================================================
# Tutor Settings
# =============================================================================
export TUTOR_ROOT="${TUTOR_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tutor_env}"

# =============================================================================
# Validation
# =============================================================================
validate_config() {
    local missing=()
    [[ -z "${GCP_PROJECT:-}" ]] && missing+=("GCP_PROJECT")
    [[ -z "${GCP_REGION:-}" ]] && missing+=("GCP_REGION")
    [[ -z "${LMS_DOMAIN:-}" ]] && missing+=("LMS_DOMAIN")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "ERROR: Missing required configuration: ${missing[*]}" >&2
        return 1
    fi
    return 0
}

# =============================================================================
# Helper Functions
# =============================================================================

# Get the script directory (useful for relative paths)
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Get the repository root
get_repo_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

# Print current configuration (for debugging)
print_config() {
    echo "=== Mereka LMS Configuration ==="
    echo "GCP_PROJECT:    $GCP_PROJECT"
    echo "GCP_REGION:     $GCP_REGION"
    echo "K8S_NAMESPACE:  $K8S_NAMESPACE"
    echo "LMS_DOMAIN:     $LMS_DOMAIN"
    echo "REGISTRY:       $REGISTRY"
    echo "TUTOR_ROOT:     $TUTOR_ROOT"
    echo "================================"
}

# Auto-validate on source (can be disabled with SKIP_CONFIG_VALIDATION=1)
if [[ "${SKIP_CONFIG_VALIDATION:-}" != "1" ]]; then
    validate_config || true
fi
