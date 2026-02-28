#!/usr/bin/env bash
# @spec: multi-tenancy-architecture_spec.md
# @covers Tenancy Phase 0 — Foundation (Model + Cache + Feature Flags)
#
# Verification of multi-tenant foundation spec compliance.
# Static checks run against Django app structure, LMS settings, and config files.
# Runtime ACs (cache isolation, xAPI tagging, branding injection) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-tenant-foundation.sh [--skip-cluster] [--help]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

SKIP_CLUSTER=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify Tenancy Phase 0: Foundation spec compliance.

OPTIONS:
    --skip-cluster    Skip checks requiring live kubectl access
    --help            Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Counters
PASS=0
FAIL=0
SKIP=0

pass_() { PASS=$((PASS + 1)); printf "PASS: %s\n" "$1"; }
fail_() { FAIL=$((FAIL + 1)); printf "FAIL: %s\n" "$1"; }
skip_() { SKIP=$((SKIP + 1)); printf "SKIP: %s\n" "$1"; }

# Key paths
APP_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_tenant_cache"
LMS_PRODUCTION_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
TENANT_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/tenants"

echo "========================================================"
echo "  Tenancy Phase 0: Foundation"
echo "  Spec: multi-tenancy-architecture_spec.md"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo "Cluster checks: $(if $SKIP_CLUSTER; then echo SKIPPED; else echo ENABLED; fi)"
echo

###########################################################################
# SECTION 1: Django App Structure
###########################################################################
echo "--- Django App Structure ---"

required_files=(
  "__init__.py"
  "apps.py"
  "models.py"
  "views.py"
  "urls.py"
  "serializers.py"
  "admin.py"
  "cache.py"
  "xapi.py"
  "middleware.py"
  "metrics.py"
  "branding.py"
  "signals.py"
  "setup.py"
  "migrations/__init__.py"
)

missing_files=()
for f in "${required_files[@]}"; do
  if [ ! -f "$APP_DIR/$f" ]; then
    missing_files+=("$f")
  fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
  pass_ "All ${#required_files[@]} required app files present in openedx_tenant_cache/"
else
  fail_ "Missing app files: ${missing_files[*]}"
fi

###########################################################################
# SECTION 2: TenantSiteMapping Model (EnterpriseCustomer ↔ Site)
###########################################################################
echo "--- TenantSiteMapping Model ---"

if [ -f "$APP_DIR/models.py" ]; then
  if grep -q "class TenantSiteMapping" "$APP_DIR/models.py"; then
    pass_ "TenantSiteMapping model class defined"
  else
    fail_ "TenantSiteMapping model class missing"
  fi

  mapping_fields=("enterprise_customer_uuid" "site" "slug" "name" "is_active" "branding_config")
  missing_fields=()
  for field in "${mapping_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_fields+=("$field")
    fi
  done

  if [ ${#missing_fields[@]} -eq 0 ]; then
    pass_ "All TenantSiteMapping fields present (${#mapping_fields[@]} fields)"
  else
    fail_ "Missing TenantSiteMapping fields: ${missing_fields[*]}"
  fi

  # Check site_id FK
  if grep -q "OneToOneField" "$APP_DIR/models.py" && grep -q "Site" "$APP_DIR/models.py"; then
    pass_ "EnterpriseCustomer ↔ Django Site FK mapping via site OneToOneField"
  else
    fail_ "Site FK mapping missing"
  fi

  # Check lookup methods
  if grep -q "def get_by_uuid" "$APP_DIR/models.py"; then
    pass_ "get_by_uuid() lookup method"
  else
    fail_ "get_by_uuid() missing"
  fi

  if grep -q "def get_by_site" "$APP_DIR/models.py"; then
    pass_ "get_by_site() lookup method"
  else
    fail_ "get_by_site() missing"
  fi

  if grep -q "def get_by_slug" "$APP_DIR/models.py"; then
    pass_ "get_by_slug() lookup method"
  else
    fail_ "get_by_slug() missing"
  fi
fi

###########################################################################
# SECTION 3: TenantSiteConfiguration (JSON overlays)
###########################################################################
echo "--- TenantSiteConfiguration ---"

if [ -f "$APP_DIR/models.py" ]; then
  if grep -q "class TenantSiteConfiguration" "$APP_DIR/models.py"; then
    pass_ "TenantSiteConfiguration model class defined"
  else
    fail_ "TenantSiteConfiguration model class missing"
  fi

  config_fields=("values" "mfe_config" "is_active")
  missing_cfg=()
  for field in "${config_fields[@]}"; do
    if ! grep -q "$field" "$APP_DIR/models.py"; then
      missing_cfg+=("$field")
    fi
  done

  if [ ${#missing_cfg[@]} -eq 0 ]; then
    pass_ "SiteConfiguration JSON overlay fields present (values, mfe_config)"
  else
    fail_ "Missing SiteConfiguration fields: ${missing_cfg[*]}"
  fi

  if grep -q "def get_merged_config" "$APP_DIR/models.py"; then
    pass_ "get_merged_config() for priority-based branding merge"
  else
    fail_ "get_merged_config() missing"
  fi

  # Check branding variables in model
  branding_keys=("logo_url" "favicon_url" "primary_color" "secondary_color" "footer_text" "sender_alias")
  missing_bk=()
  for bk in "${branding_keys[@]}"; do
    if ! grep -q "$bk" "$APP_DIR/models.py"; then
      missing_bk+=("$bk")
    fi
  done

  if [ ${#missing_bk[@]} -eq 0 ]; then
    pass_ "Per-tenant branding keys present (logos, colors, footer)"
  else
    fail_ "Missing branding keys: ${missing_bk[*]}"
  fi
fi

###########################################################################
# SECTION 4: Redis Cache Namespacing
###########################################################################
echo "--- Redis Cache Namespacing ---"

if [ -f "$APP_DIR/cache.py" ]; then
  if grep -q "enterprise:{uuid}:{key_type}:{key_id}" "$APP_DIR/cache.py"; then
    pass_ "Cache namespace format: enterprise:{uuid}:{key_type}:{key_id}"
  else
    fail_ "Required cache namespace format missing"
  fi

  if grep -q "def tenant_cache_key" "$APP_DIR/cache.py"; then
    pass_ "tenant_cache_key() builder function"
  else
    fail_ "tenant_cache_key() missing"
  fi

  if grep -q "def tenant_cache_get" "$APP_DIR/cache.py" && grep -q "def tenant_cache_set" "$APP_DIR/cache.py"; then
    pass_ "tenant_cache_get/set operations"
  else
    fail_ "tenant_cache_get/set missing"
  fi

  if grep -q "def tenant_cache_delete" "$APP_DIR/cache.py"; then
    pass_ "tenant_cache_delete operation"
  else
    fail_ "tenant_cache_delete missing"
  fi

  if grep -q "class TenantCacheNamespace" "$APP_DIR/cache.py"; then
    pass_ "TenantCacheNamespace context manager"
  else
    fail_ "TenantCacheNamespace context manager missing"
  fi

  if grep -q "def tenant_cache_clear_all" "$APP_DIR/cache.py"; then
    pass_ "tenant_cache_clear_all() for full tenant cache flush"
  else
    fail_ "tenant_cache_clear_all() missing"
  fi
fi

###########################################################################
# SECTION 5: ClickHouse xAPI Tagging
###########################################################################
echo "--- ClickHouse xAPI Tagging ---"

if [ -f "$APP_DIR/xapi.py" ]; then
  if grep -q "enterprise_customer_uuid" "$APP_DIR/xapi.py"; then
    pass_ "xAPI event tagging with enterprise_customer_uuid"
  else
    fail_ "enterprise_customer_uuid tagging missing"
  fi

  if grep -q "def tag_xapi_event" "$APP_DIR/xapi.py"; then
    pass_ "tag_xapi_event() function for event tagging"
  else
    fail_ "tag_xapi_event() missing"
  fi

  if grep -q "def get_enterprise_uuid_for_user" "$APP_DIR/xapi.py"; then
    pass_ "get_enterprise_uuid_for_user() resolver"
  else
    fail_ "get_enterprise_uuid_for_user() missing"
  fi

  if grep -q "Nullable" "$APP_DIR/xapi.py"; then
    pass_ "ClickHouse column is nullable (existing events have no UUID)"
  else
    fail_ "ClickHouse column nullable specification missing"
  fi

  if grep -q "def get_clickhouse_schema_extension" "$APP_DIR/xapi.py"; then
    pass_ "ClickHouse schema extension SQL provided"
  else
    fail_ "ClickHouse schema extension missing"
  fi

  if grep -q "EnterpriseCustomerUser" "$APP_DIR/xapi.py"; then
    pass_ "EnterpriseCustomerUser lookup for UUID resolution"
  else
    fail_ "EnterpriseCustomerUser lookup missing"
  fi
fi

###########################################################################
# SECTION 6: Tenant Middleware
###########################################################################
echo "--- Tenant Middleware ---"

if [ -f "$APP_DIR/middleware.py" ]; then
  if grep -q "class TenantCacheMiddleware" "$APP_DIR/middleware.py"; then
    pass_ "TenantCacheMiddleware defined"
  else
    fail_ "TenantCacheMiddleware missing"
  fi

  if grep -q "_tenant_uuid" "$APP_DIR/middleware.py"; then
    pass_ "Middleware attaches tenant UUID to request"
  else
    fail_ "Tenant UUID attachment missing"
  fi

  if grep -q "tenant_uuid" "$APP_DIR/middleware.py"; then
    pass_ "Middleware exposes tenant_uuid public alias"
  else
    fail_ "tenant_uuid public alias missing"
  fi

  if grep -q "record_tenant_request" "$APP_DIR/middleware.py"; then
    pass_ "Middleware records per-tenant request metrics"
  else
    fail_ "Per-tenant request metrics missing"
  fi
fi

if [ -f "$APP_DIR/apps.py" ]; then
  if grep -q "plugin_app" "$APP_DIR/apps.py"; then
    pass_ "openedx_tenant_cache plugin_app URL mapping defined"
  else
    fail_ "openedx_tenant_cache plugin_app URL mapping missing"
  fi
  if grep -q "api/tenant/v1" "$APP_DIR/apps.py"; then
    pass_ "openedx_tenant_cache plugin regex includes /api/tenant/v1/"
  else
    fail_ "openedx_tenant_cache plugin regex /api/tenant/v1/ missing"
  fi
fi

###########################################################################
# SECTION 7: Prometheus Metrics
###########################################################################
echo "--- Prometheus Metrics ---"

if [ -f "$APP_DIR/metrics.py" ]; then
  if grep -q "tenant_request_total" "$APP_DIR/metrics.py"; then
    pass_ "Prometheus metric: tenant_request_total"
  else
    fail_ "tenant_request_total metric missing"
  fi

  if grep -q "tenant_cache_hits_total\|tenant_cache_hit" "$APP_DIR/metrics.py"; then
    pass_ "Prometheus metric: tenant_cache_hits_total (for cache hit ratio)"
  else
    fail_ "tenant_cache_hits metric missing"
  fi

  if grep -q "tenant_cache_misses_total\|tenant_cache_miss" "$APP_DIR/metrics.py"; then
    pass_ "Prometheus metric: tenant_cache_misses_total"
  else
    fail_ "tenant_cache_misses metric missing"
  fi

  if grep -q "tenant_request_duration" "$APP_DIR/metrics.py"; then
    pass_ "Prometheus metric: tenant_request_duration_seconds"
  else
    fail_ "tenant_request_duration metric missing"
  fi

  if grep -q "def record_tenant_request" "$APP_DIR/metrics.py"; then
    pass_ "record_tenant_request() helper"
  else
    fail_ "record_tenant_request() missing"
  fi

  if grep -q "def record_cache_hit" "$APP_DIR/metrics.py"; then
    pass_ "record_cache_hit() helper"
  else
    fail_ "record_cache_hit() missing"
  fi
fi

###########################################################################
# SECTION 8: MFE Branding Injection
###########################################################################
echo "--- MFE Branding Injection ---"

if [ -f "$APP_DIR/branding.py" ]; then
  if grep -q "def get_tenant_branding" "$APP_DIR/branding.py"; then
    pass_ "get_tenant_branding() function"
  else
    fail_ "get_tenant_branding() missing"
  fi

  if grep -q "def inject_mfe_branding" "$APP_DIR/branding.py"; then
    pass_ "inject_mfe_branding() for MFE config API overlay"
  else
    fail_ "inject_mfe_branding() missing"
  fi

  mfe_keys=("LOGO_URL" "FAVICON_URL" "SITE_NAME" "PRIMARY_COLOR")
  missing_mfe=()
  for mk in "${mfe_keys[@]}"; do
    if ! grep -q "$mk" "$APP_DIR/branding.py"; then
      missing_mfe+=("$mk")
    fi
  done

  if [ ${#missing_mfe[@]} -eq 0 ]; then
    pass_ "MFE branding keys present (LOGO_URL, FAVICON_URL, SITE_NAME, PRIMARY_COLOR)"
  else
    fail_ "Missing MFE branding keys: ${missing_mfe[*]}"
  fi

  if grep -q "ENABLE_MULTI_TENANT_BRANDING" "$APP_DIR/branding.py"; then
    pass_ "MFE branding respects ENABLE_MULTI_TENANT_BRANDING flag"
  else
    fail_ "MFE branding does not check feature flag"
  fi

  if grep -q "SiteConfiguration\|TenantSiteConfiguration" "$APP_DIR/branding.py"; then
    pass_ "MFE reads SiteConfiguration at runtime"
  else
    fail_ "MFE SiteConfiguration runtime read missing"
  fi
fi

###########################################################################
# SECTION 9: Tenant Branding Directory
###########################################################################
echo "--- Tenant Branding Directory ---"

if [ -d "$TENANT_DIR" ]; then
  pass_ "Tenant branding directory exists: infrastructure/tutor/themes/mereka/tenants/"
else
  fail_ "Tenant branding directory missing"
fi

if [ -f "$TENANT_DIR/README.md" ]; then
  pass_ "Tenant branding README with directory structure guide"
else
  fail_ "Tenant branding README missing"
fi

###########################################################################
# SECTION 10: LMS Settings Configuration
###########################################################################
echo "--- LMS Settings ---"

if [ -f "$LMS_PRODUCTION_PY" ]; then
  if grep -q "ENABLE_MULTI_TENANT_BRANDING" "$LMS_PRODUCTION_PY"; then
    pass_ "ENABLE_MULTI_TENANT_BRANDING feature flag"
  else
    fail_ "ENABLE_MULTI_TENANT_BRANDING missing"
  fi

  if grep -q "ENABLE_TENANT_ANALYTICS_SCOPING" "$LMS_PRODUCTION_PY"; then
    pass_ "ENABLE_TENANT_ANALYTICS_SCOPING feature flag"
  else
    fail_ "ENABLE_TENANT_ANALYTICS_SCOPING missing"
  fi

  if grep -q "TENANT_CACHE_NAMESPACE_FORMAT" "$LMS_PRODUCTION_PY"; then
    pass_ "TENANT_CACHE_NAMESPACE_FORMAT configured"
  else
    fail_ "TENANT_CACHE_NAMESPACE_FORMAT missing"
  fi

  if grep -q "ENTERPRISE_SITE_MAPPING_ENABLED" "$LMS_PRODUCTION_PY"; then
    pass_ "ENTERPRISE_SITE_MAPPING_ENABLED flag"
  else
    fail_ "ENTERPRISE_SITE_MAPPING_ENABLED missing"
  fi

  if grep -q "XAPI_ENTERPRISE_UUID_ENABLED" "$LMS_PRODUCTION_PY"; then
    pass_ "XAPI_ENTERPRISE_UUID_ENABLED flag"
  else
    fail_ "XAPI_ENTERPRISE_UUID_ENABLED missing"
  fi

  if grep -q "SITE_CONFIGURATION_TENANT_OVERLAYS" "$LMS_PRODUCTION_PY"; then
    pass_ "SITE_CONFIGURATION_TENANT_OVERLAYS enabled"
  else
    fail_ "SITE_CONFIGURATION_TENANT_OVERLAYS missing"
  fi

  if grep -q "MFE_BRANDING_FROM_SITE_CONFIG" "$LMS_PRODUCTION_PY"; then
    pass_ "MFE_BRANDING_FROM_SITE_CONFIG flag"
  else
    fail_ "MFE_BRANDING_FROM_SITE_CONFIG missing"
  fi

  if grep -q "TENANT_BRANDING_DIR" "$LMS_PRODUCTION_PY"; then
    pass_ "TENANT_BRANDING_DIR path configured"
  else
    fail_ "TENANT_BRANDING_DIR missing"
  fi

  if grep -q "openedx_tenant_cache" "$LMS_PRODUCTION_PY"; then
    pass_ "openedx_tenant_cache in INSTALLED_APPS"
  else
    fail_ "openedx_tenant_cache missing from INSTALLED_APPS"
  fi

  # Check env var patterns (settings may span multiple lines)
  if grep -A1 'os\.environ\.get' "$LMS_PRODUCTION_PY" | grep -q 'MULTI_TENANT\|TENANT_ANALYTICS\|SITE_MAPPING'; then
    pass_ "Settings use env var pattern (os.environ.get)"
  else
    fail_ "Settings missing env var pattern"
  fi
else
  fail_ "LMS production.py not found at $LMS_PRODUCTION_PY"
fi

# Runtime tests
skip_ "Given EnterpriseCustomer with site_id FK, When request resolves to Site, Then correct SiteConfiguration loads (requires runtime test)"
skip_ "Given Redis cache with namespaced keys, When tenant A writes, Then tenant B reads empty (requires runtime test)"
skip_ "Given xAPI event from tenant learner, When stored in ClickHouse, Then enterprise_customer_uuid populated (requires runtime test)"
skip_ "Given ENABLE_MULTI_TENANT_BRANDING=False, When tenant domain visited, Then default Mereka branding renders (requires runtime test)"

###########################################################################
# Summary
###########################################################################
echo
echo "========================================================"
echo "  Summary"
echo "========================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"
echo "TOTAL: $((PASS + FAIL + SKIP))"
echo

if [ "$FAIL" -gt 0 ]; then
  echo "--- Verification FAILED with $FAIL failed check(s)"
  exit 1
else
  echo "--- Verification PASSED (static checks complete; $SKIP runtime checks skipped)"
  exit 0
fi
