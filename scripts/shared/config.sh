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
export K8S_CONTEXT="${K8S_CONTEXT:-rke2-prod}"
export K8S_CLUSTER="${K8S_CLUSTER:-mereka-lms}"

# =============================================================================
# Domain Settings — generated from tenant-registry.yaml
# Regenerate: python scripts/domains/generate_config_domains.py
# =============================================================================
_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
_GENERATED_DOMAINS="${_REPO_ROOT}/generated/domains/config-domains.sh"
if [[ -f "$_GENERATED_DOMAINS" ]]; then
    # shellcheck source=../../generated/domains/config-domains.sh
    source "$_GENERATED_DOMAINS"
else
    echo "WARN: generated domain config not found at $_GENERATED_DOMAINS" >&2
    echo "WARN: run: python scripts/domains/generate_config_domains.py" >&2
fi
unset _REPO_ROOT _GENERATED_DOMAINS

# Purchase Gateway is path-routed under the LMS host via /payments/*.
# There is no standalone payments.<domain> hostname in the active platform contract.

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
        prod) echo "${K8S_CONTEXT_PROD:-${K8S_CONTEXT:-rke2-prod}}" ;;
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
