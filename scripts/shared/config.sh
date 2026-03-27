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
export K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
export K8S_CLUSTER="${K8S_CLUSTER:-mereka-lms}"

# =============================================================================
# Domain Settings
# =============================================================================
# Canonical app-owned tenant/domain source lives in
# deploy/k8s/tenancy/tenant-registry.yaml.
# This file provides derived shell defaults for scripts and must stay aligned
# with the tenant registry rather than becoming a second authority plane.
# Production
export LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
export STUDIO_DOMAIN="${STUDIO_DOMAIN:-studio.${LMS_DOMAIN}}"
export MFE_DOMAIN="${MFE_DOMAIN:-apps.${LMS_DOMAIN}}"
export AUTHENTIK_DOMAIN="${AUTHENTIK_DOMAIN:-auth0.mereka.io}"
export PREVIEW_DOMAIN="${PREVIEW_DOMAIN:-preview.${LMS_DOMAIN}}"
export DISCOVERY_DOMAIN="${DISCOVERY_DOMAIN:-discovery.${LMS_DOMAIN}}"

# Legacy Oscar ecommerce (deprecated — being replaced by purchase-gateway)
# Kept during dual-stack transition period; will be removed after AC-027/AC-028 close
export ECOMMERCE_DOMAIN="${ECOMMERCE_DOMAIN:-ecommerce.${LMS_DOMAIN}}"

export NOTES_DOMAIN="${NOTES_DOMAIN:-notes.${LMS_DOMAIN}}"
export CREDENTIALS_DOMAIN="${CREDENTIALS_DOMAIN:-credentials.${LMS_DOMAIN}}"
export FORUM_DOMAIN="${FORUM_DOMAIN:-forum.${LMS_DOMAIN}}"

# Enterprise MFE domains
export ENTERPRISE_ADMIN_DOMAIN="${ENTERPRISE_ADMIN_DOMAIN:-admin.${LMS_DOMAIN}}"
export ENTERPRISE_PORTAL_DOMAIN="${ENTERPRISE_PORTAL_DOMAIN:-learner.${LMS_DOMAIN}}"

# Alternative domains (multisite)
export BIJI_DOMAIN="${BIJI_DOMAIN:-academy.biji-biji.com}"
export SKILLOURFUTURE_DOMAIN="${SKILLOURFUTURE_DOMAIN:-skillourfuture.academy.mereka.io}"
export SKILLOURFUTURE_STUDIO_DOMAIN="${SKILLOURFUTURE_STUDIO_DOMAIN:-studio.${SKILLOURFUTURE_DOMAIN}}"
export SKILLOURFUTURE_MFE_DOMAIN="${SKILLOURFUTURE_MFE_DOMAIN:-apps.${SKILLOURFUTURE_DOMAIN}}"

# Biji-Biji dedicated subdomains (public DNS)
export BIJI_STUDIO_DOMAIN="${BIJI_STUDIO_DOMAIN:-studio.academy.biji-biji.com}"
export BIJI_MFE_DOMAIN="${BIJI_MFE_DOMAIN:-apps.academy.biji-biji.com}"

# Development
export DEV_LMS_DOMAIN="${DEV_LMS_DOMAIN:-academyv2.mereka.dev}"
export DEV_STUDIO_DOMAIN="${DEV_STUDIO_DOMAIN:-studio.${DEV_LMS_DOMAIN}}"
export DEV_MFE_DOMAIN="${DEV_MFE_DOMAIN:-apps.${DEV_LMS_DOMAIN}}"
export DEV_AUTHENTIK_DOMAIN="${DEV_AUTHENTIK_DOMAIN:-auth0.mereka.dev}"
export DEV_PREVIEW_DOMAIN="${DEV_PREVIEW_DOMAIN:-preview.${DEV_LMS_DOMAIN}}"
export DEV_DISCOVERY_DOMAIN="${DEV_DISCOVERY_DOMAIN:-discovery.${DEV_LMS_DOMAIN}}"

# Legacy Oscar ecommerce (deprecated — being replaced by purchase-gateway)
# Kept during dual-stack transition period; will be removed after AC-027/AC-028 close
export DEV_ECOMMERCE_DOMAIN="${DEV_ECOMMERCE_DOMAIN:-ecommerce.${DEV_LMS_DOMAIN}}"

export DEV_NOTES_DOMAIN="${DEV_NOTES_DOMAIN:-notes.${DEV_LMS_DOMAIN}}"
export DEV_CREDENTIALS_DOMAIN="${DEV_CREDENTIALS_DOMAIN:-credentials.${DEV_LMS_DOMAIN}}"
export DEV_FORUM_DOMAIN="${DEV_FORUM_DOMAIN:-forum.${DEV_LMS_DOMAIN}}"

# Enterprise MFE domains (dev)
export DEV_ENTERPRISE_ADMIN_DOMAIN="${DEV_ENTERPRISE_ADMIN_DOMAIN:-admin.${DEV_LMS_DOMAIN}}"
export DEV_ENTERPRISE_PORTAL_DOMAIN="${DEV_ENTERPRISE_PORTAL_DOMAIN:-learner.${DEV_LMS_DOMAIN}}"

# DEV tenant-pattern domains
export DEV_BIJI_DOMAIN="${DEV_BIJI_DOMAIN:-biji-biji.academyv2.mereka.dev}"
export DEV_BIJI_STUDIO_DOMAIN="${DEV_BIJI_STUDIO_DOMAIN:-studio.${DEV_BIJI_DOMAIN}}"
export DEV_BIJI_MFE_DOMAIN="${DEV_BIJI_MFE_DOMAIN:-apps.${DEV_BIJI_DOMAIN}}"
export DEV_SKILLOURFUTURE_DOMAIN="${DEV_SKILLOURFUTURE_DOMAIN:-skillourfuture.academyv2.mereka.dev}"
export DEV_SKILLOURFUTURE_STUDIO_DOMAIN="${DEV_SKILLOURFUTURE_STUDIO_DOMAIN:-studio.${DEV_SKILLOURFUTURE_DOMAIN}}"
export DEV_SKILLOURFUTURE_MFE_DOMAIN="${DEV_SKILLOURFUTURE_MFE_DOMAIN:-apps.${DEV_SKILLOURFUTURE_DOMAIN}}"

# Purchase Gateway is path-routed under the LMS host via /payments/*.
# There is no standalone payments.<domain> hostname in the active platform contract.

# Staging (active non-prod lane on shared rke2-nonprod today)
export STAGING_LMS_DOMAIN="${STAGING_LMS_DOMAIN:-staging.academyv2.mereka.io}"
export STAGING_STUDIO_DOMAIN="${STAGING_STUDIO_DOMAIN:-staging.studio.academyv2.mereka.io}"
export STAGING_MFE_DOMAIN="${STAGING_MFE_DOMAIN:-staging.apps.academyv2.mereka.io}"
export STAGING_AUTHENTIK_DOMAIN="${STAGING_AUTHENTIK_DOMAIN:-staging.auth0.mereka.io}"
export STAGING_PREVIEW_DOMAIN="${STAGING_PREVIEW_DOMAIN:-staging.preview.academyv2.mereka.io}"
export STAGING_DISCOVERY_DOMAIN="${STAGING_DISCOVERY_DOMAIN:-staging.discovery.academyv2.mereka.io}"
# Legacy Oscar ecommerce (deprecated — being replaced by purchase-gateway)
# Kept during dual-stack transition period; will be removed after AC-027/AC-028 close
export STAGING_ECOMMERCE_DOMAIN="${STAGING_ECOMMERCE_DOMAIN:-staging.ecommerce.academyv2.mereka.io}"
export STAGING_NOTES_DOMAIN="${STAGING_NOTES_DOMAIN:-staging.notes.academyv2.mereka.io}"
export STAGING_CREDENTIALS_DOMAIN="${STAGING_CREDENTIALS_DOMAIN:-staging.credentials.academyv2.mereka.io}"
export STAGING_FORUM_DOMAIN="${STAGING_FORUM_DOMAIN:-staging.forum.academyv2.mereka.io}"

# Enterprise MFE domains (staging)
export STAGING_ENTERPRISE_ADMIN_DOMAIN="${STAGING_ENTERPRISE_ADMIN_DOMAIN:-staging.admin.academyv2.mereka.io}"
export STAGING_ENTERPRISE_PORTAL_DOMAIN="${STAGING_ENTERPRISE_PORTAL_DOMAIN:-staging.learner.academyv2.mereka.io}"

# Purchase Gateway (staging)

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

mereka_lms_normalize_env() {
    local raw_env="${1:-prod}"
    case "$raw_env" in
        prod|production) echo "prod" ;;
        dev|development) echo "dev" ;;
        staging) echo "staging" ;;
        *)
            echo "unsupported environment: $raw_env" >&2
            return 1
            ;;
    esac
}

mereka_lms_registry_env_name() {
    local normalized_env
    normalized_env="$(mereka_lms_normalize_env "${1:-prod}")" || return 1
    case "$normalized_env" in
        prod) echo "production" ;;
        dev) echo "dev" ;;
        staging) echo "staging" ;;
    esac
}

mereka_lms_default_namespace_for_env() {
    local normalized_env
    normalized_env="$(mereka_lms_normalize_env "${1:-prod}")" || return 1
    case "$normalized_env" in
        prod) echo "${K8S_NAMESPACE_PROD:-${K8S_NAMESPACE:-mereka-lms}}" ;;
        dev) echo "${K8S_NAMESPACE_DEV:-mereka-lms-dev}" ;;
        staging) echo "${K8S_NAMESPACE_STAGING:-stg-mereka-lms}" ;;
    esac
}

mereka_lms_default_context_for_env() {
    local normalized_env
    normalized_env="$(mereka_lms_normalize_env "${1:-prod}")" || return 1
    case "$normalized_env" in
        prod) echo "${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}}" ;;
        dev|staging) echo "${K8S_CONTEXT_NONPROD:-rke2-nonprod}" ;;
    esac
}

mereka_lms_lms_base_url_for_env() {
    local normalized_env
    normalized_env="$(mereka_lms_normalize_env "${1:-prod}")" || return 1
    case "$normalized_env" in
        prod) echo "https://${LMS_DOMAIN:-academyv2.mereka.io}" ;;
        dev) echo "https://${DEV_LMS_DOMAIN:-academyv2.mereka.dev}" ;;
        staging) echo "https://${STAGING_LMS_DOMAIN:-staging.academyv2.mereka.io}" ;;
    esac
}

mereka_lms_canonical_domain_map_json() {
    local normalized_env registry_env repo_root
    normalized_env="$(mereka_lms_normalize_env "${1:-prod}")" || return 1
    registry_env="$(mereka_lms_registry_env_name "$normalized_env")" || return 1
    repo_root="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

    python3 - "$repo_root" "$registry_env" <<'PY'
import json
import sys
from pathlib import Path

import yaml

repo_root = Path(sys.argv[1])
registry_env = sys.argv[2]
registry_path = repo_root / "deploy" / "k8s" / "tenancy" / "tenant-registry.yaml"
tenant_contracts_path = repo_root / "infrastructure" / "tenants" / "tenant-contracts.yml"

registry = yaml.safe_load(registry_path.read_text(encoding="utf-8")) or {}
runtime_contracts = {}
if tenant_contracts_path.exists():
    tenant_contract_payload = yaml.safe_load(tenant_contracts_path.read_text(encoding="utf-8")) or {}
    for tenant in tenant_contract_payload.get("tenants", []):
        slug = tenant.get("slug")
        if slug:
            runtime_contracts[slug] = tenant.get("registry_slug") or slug

registry_domains = {}
for domain_entry in registry.get("domains", []):
    if (
        domain_entry.get("environment") == registry_env
        and domain_entry.get("role") == "primary"
        and domain_entry.get("status") == "active"
    ):
        tenant_slug = domain_entry.get("tenant")
        domain = domain_entry.get("domain")
        if tenant_slug and domain:
            registry_domains[tenant_slug] = domain

result = {}
for runtime_slug, registry_slug in runtime_contracts.items():
    domain = registry_domains.get(registry_slug) or registry_domains.get(runtime_slug)
    if domain:
        result[runtime_slug] = domain

if not result:
    for registry_slug, domain in registry_domains.items():
        result[registry_slug] = domain

print(json.dumps(result, sort_keys=True))
PY
}

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
