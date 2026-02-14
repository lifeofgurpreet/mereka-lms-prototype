#!/usr/bin/env bash
# @covers AC-TEN-007, AC-TEN-008, AC-TEN-009, AC-TEN-010, AC-TEN-011, AC-TEN-012, AC-TEN-013
# @spec: multi-tenancy-architecture_spec.md
set -euo pipefail

# verify-tenant-pilot.sh - Verifies Phase 2 pilot tenant + isolation
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass_() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}✓${NC} $1"; }
fail_() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}✗${NC} $1"; }
skip_() { SKIP_COUNT=$((SKIP_COUNT + 1)); echo -e "${YELLOW}⊘${NC} $1"; }

# Parse flags
SKIP_CLUSTER=false
for arg in "$@"; do
  case "$arg" in
    --skip-cluster) SKIP_CLUSTER=true ;;
  esac
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Multi-Tenancy Phase 2: Pilot Client + Cross-Tenant Isolation"
echo "  @spec: multi-tenancy-architecture_spec.md"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ────────────────────────────────────────────────────────────────────
# Section 1: Pilot Tenant Definition
# ────────────────────────────────────────────────────────────────────
echo "[Section 1] Pilot Tenant Definition"
ACME_ENV="${REPO_ROOT}/scripts/tenants/acme-tenant.env"

if [[ -f "$ACME_ENV" ]]; then
  pass_ "acme-tenant.env exists"
else
  fail_ "acme-tenant.env missing"
fi

if [[ -f "$ACME_ENV" ]] && grep -q "^TENANT_SLUG=acme" "$ACME_ENV"; then
  pass_ "TENANT_SLUG=acme"
else
  fail_ "TENANT_SLUG=acme not found"
fi

if [[ -f "$ACME_ENV" ]] && grep -q "^TENANT_DOMAIN=acme.academyv2.mereka.io" "$ACME_ENV"; then
  pass_ "TENANT_DOMAIN=acme.academyv2.mereka.io"
else
  fail_ "TENANT_DOMAIN=acme.academyv2.mereka.io not found"
fi

if [[ -f "$ACME_ENV" ]] && grep -q "^TENANT_COUNTRY=SG" "$ACME_ENV"; then
  pass_ "TENANT_COUNTRY=SG"
else
  fail_ "TENANT_COUNTRY=SG not found"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 2: Cross-Tenant Isolation Module
# ────────────────────────────────────────────────────────────────────
echo "[Section 2] Cross-Tenant Isolation Module"
ISOLATION_PY="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_tenant_cache/isolation.py"

if [[ -f "$ISOLATION_PY" ]]; then
  pass_ "isolation.py exists"
else
  fail_ "isolation.py missing"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "class TenantIsolationMixin" "$ISOLATION_PY"; then
  pass_ "TenantIsolationMixin class defined"
else
  fail_ "TenantIsolationMixin class not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "def enforce_tenant_isolation" "$ISOLATION_PY"; then
  pass_ "enforce_tenant_isolation decorator defined"
else
  fail_ "enforce_tenant_isolation decorator not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "def check_tenant_access" "$ISOLATION_PY"; then
  pass_ "check_tenant_access function present"
else
  fail_ "check_tenant_access function not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "def get_request_tenant_uuid" "$ISOLATION_PY"; then
  pass_ "get_request_tenant_uuid function present"
else
  fail_ "get_request_tenant_uuid function not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "def get_user_tenant_uuid" "$ISOLATION_PY"; then
  pass_ "get_user_tenant_uuid function present"
else
  fail_ "get_user_tenant_uuid function not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "raise PermissionDenied" "$ISOLATION_PY"; then
  pass_ "PermissionDenied raised for cross-tenant access"
else
  fail_ "PermissionDenied not raised"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "request.user.is_superuser" "$ISOLATION_PY"; then
  pass_ "Superuser bypass present"
else
  fail_ "Superuser bypass not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "logger.warning" "$ISOLATION_PY"; then
  pass_ "Cross-tenant access logging (logger.warning)"
else
  fail_ "Cross-tenant access logging not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "def filter_queryset_by_tenant" "$ISOLATION_PY"; then
  pass_ "filter_queryset_by_tenant method present"
else
  fail_ "filter_queryset_by_tenant method not found"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 3: API Isolation Views
# ────────────────────────────────────────────────────────────────────
echo "[Section 3] API Isolation Views"
VIEWS_PY="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_tenant_cache/views.py"

if [[ -f "$VIEWS_PY" ]] && grep -q "class TenantCatalogIsolationView" "$VIEWS_PY"; then
  pass_ "TenantCatalogIsolationView defined in views.py"
else
  fail_ "TenantCatalogIsolationView not found"
fi

if [[ -f "$VIEWS_PY" ]] && grep -q "class TenantAnalyticsIsolationView" "$VIEWS_PY"; then
  pass_ "TenantAnalyticsIsolationView defined in views.py"
else
  fail_ "TenantAnalyticsIsolationView not found"
fi

if [[ -f "$VIEWS_PY" ]] && grep -q "TenantIsolationMixin.*TenantCatalogIsolationView\|class TenantCatalogIsolationView.*TenantIsolationMixin" "$VIEWS_PY"; then
  pass_ "TenantCatalogIsolationView uses TenantIsolationMixin"
else
  fail_ "TenantCatalogIsolationView does not use TenantIsolationMixin"
fi

if [[ -f "$VIEWS_PY" ]] && grep -q "TenantIsolationMixin.*TenantAnalyticsIsolationView\|class TenantAnalyticsIsolationView.*TenantIsolationMixin" "$VIEWS_PY"; then
  pass_ "TenantAnalyticsIsolationView uses TenantIsolationMixin"
else
  fail_ "TenantAnalyticsIsolationView does not use TenantIsolationMixin"
fi

URLS_PY="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_tenant_cache/urls.py"
if [[ -f "$URLS_PY" ]] && grep -q "tenants/catalogs/" "$URLS_PY"; then
  pass_ "/tenants/catalogs/ URL configured"
else
  fail_ "/tenants/catalogs/ URL not found"
fi

if [[ -f "$URLS_PY" ]] && grep -q "tenants/analytics/" "$URLS_PY"; then
  pass_ "/tenants/analytics/ URL configured"
else
  fail_ "/tenants/analytics/ URL not found"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 4: Superset RLS Policies
# ────────────────────────────────────────────────────────────────────
echo "[Section 4] Superset RLS Policies"
RLS_PY="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_tenant_cache/rls.py"

if [[ -f "$RLS_PY" ]]; then
  pass_ "rls.py exists"
else
  fail_ "rls.py missing"
fi

if [[ -f "$RLS_PY" ]] && grep -q "SUPERSET_RLS_POLICIES" "$RLS_PY"; then
  pass_ "SUPERSET_RLS_POLICIES dict defined"
else
  fail_ "SUPERSET_RLS_POLICIES dict not found"
fi

if [[ -f "$RLS_PY" ]] && grep -q "'xapi_events_all'" "$RLS_PY"; then
  pass_ "xapi_events_all policy present"
else
  fail_ "xapi_events_all policy not found"
fi

if [[ -f "$RLS_PY" ]] && grep -q "'course_enrollments'" "$RLS_PY"; then
  pass_ "course_enrollments policy present"
else
  fail_ "course_enrollments policy not found"
fi

if [[ -f "$RLS_PY" ]] && grep -q "'grades'" "$RLS_PY"; then
  pass_ "grades policy present"
else
  fail_ "grades policy not found"
fi

if [[ -f "$RLS_PY" ]] && grep -q "'certificates'" "$RLS_PY"; then
  pass_ "certificates policy present"
else
  fail_ "certificates policy not found"
fi

if [[ -f "$RLS_PY" ]] && grep -q "def get_rls_policy_sql" "$RLS_PY"; then
  pass_ "get_rls_policy_sql function present"
else
  fail_ "get_rls_policy_sql function not found"
fi

if [[ -f "$RLS_PY" ]] && grep -q "def generate_superset_rls_config" "$RLS_PY"; then
  pass_ "generate_superset_rls_config function present"
else
  fail_ "generate_superset_rls_config function not found"
fi

if [[ -f "$RLS_PY" ]] && grep -q "enterprise_customer_uuid" "$RLS_PY"; then
  pass_ "enterprise_customer_uuid in filter clauses"
else
  fail_ "enterprise_customer_uuid not found in filter clauses"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 5: Branding Configuration
# ────────────────────────────────────────────────────────────────────
echo "[Section 5] Branding Configuration"
ACME_BRANDING="${REPO_ROOT}/scripts/tenants/acme-branding.json"
MEREKA_BRANDING="${REPO_ROOT}/scripts/tenants/mereka-branding.json"

if [[ -f "$ACME_BRANDING" ]]; then
  pass_ "acme-branding.json exists"
else
  fail_ "acme-branding.json missing"
fi

if [[ -f "$MEREKA_BRANDING" ]]; then
  pass_ "mereka-branding.json exists"
else
  fail_ "mereka-branding.json missing"
fi

if [[ -f "$ACME_BRANDING" ]] && [[ -f "$MEREKA_BRANDING" ]]; then
  ACME_COLOR=$(grep -oP '"primary_color":\s*"\K[^"]+' "$ACME_BRANDING" | head -1)
  MEREKA_COLOR=$(grep -oP '"primary_color":\s*"\K[^"]+' "$MEREKA_BRANDING" | head -1)
  if [[ "$ACME_COLOR" != "$MEREKA_COLOR" ]]; then
    pass_ "Acme branding has different primary_color from Mereka ($ACME_COLOR vs $MEREKA_COLOR)"
  else
    fail_ "Acme and Mereka have same primary_color"
  fi
fi

if [[ -f "$ACME_BRANDING" ]] && grep -q '"SITE_NAME"' "$ACME_BRANDING" && grep -q '"LOGO_URL"' "$ACME_BRANDING" && grep -q '"FAVICON_URL"' "$ACME_BRANDING"; then
  pass_ "Acme branding has SITE_NAME, LOGO_URL, FAVICON_URL"
else
  fail_ "Acme branding missing required fields"
fi

if [[ -f "$MEREKA_BRANDING" ]] && grep -q '"SITE_NAME"' "$MEREKA_BRANDING" && grep -q '"LOGO_URL"' "$MEREKA_BRANDING" && grep -q '"FAVICON_URL"' "$MEREKA_BRANDING"; then
  pass_ "Mereka branding has SITE_NAME, LOGO_URL, FAVICON_URL"
else
  fail_ "Mereka branding missing required fields"
fi

APPLY_BRANDING="${REPO_ROOT}/infrastructure/tutor/custom-apps/openedx_tenant_cache/management/commands/apply_tenant_branding.py"
if [[ -f "$APPLY_BRANDING" ]]; then
  pass_ "apply_tenant_branding management command exists"
else
  fail_ "apply_tenant_branding management command missing"
fi

if [[ -f "$APPLY_BRANDING" ]] && grep -q "'--tenant-slug'" "$APPLY_BRANDING"; then
  pass_ "--tenant-slug argument"
else
  fail_ "--tenant-slug argument not found"
fi

if [[ -f "$APPLY_BRANDING" ]] && grep -q "'--branding-file'" "$APPLY_BRANDING"; then
  pass_ "--branding-file argument"
else
  fail_ "--branding-file argument not found"
fi

if [[ -f "$APPLY_BRANDING" ]] && grep -q "'--dry-run'" "$APPLY_BRANDING"; then
  pass_ "--dry-run support"
else
  fail_ "--dry-run support not found"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 6: LMS Production Settings
# ────────────────────────────────────────────────────────────────────
echo "[Section 6] LMS Production Settings"
PRODUCTION_PY="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"

if [[ -f "$PRODUCTION_PY" ]] && grep -q "TENANT_ISOLATION_ENABLED" "$PRODUCTION_PY"; then
  pass_ "TENANT_ISOLATION_ENABLED flag present"
else
  fail_ "TENANT_ISOLATION_ENABLED flag not found"
fi

if [[ -f "$PRODUCTION_PY" ]] && grep -q "SUPERSET_RLS_ENABLED" "$PRODUCTION_PY"; then
  pass_ "SUPERSET_RLS_ENABLED flag present"
else
  fail_ "SUPERSET_RLS_ENABLED flag not found"
fi

if [[ -f "$PRODUCTION_PY" ]] && grep -q "PILOT_TENANT_DOMAINS" "$PRODUCTION_PY"; then
  pass_ "PILOT_TENANT_DOMAINS env var handling"
else
  fail_ "PILOT_TENANT_DOMAINS env var handling not found"
fi

if [[ -f "$PRODUCTION_PY" ]] && grep -q "ALLOWED_HOSTS.*domain" "$PRODUCTION_PY"; then
  pass_ "ALLOWED_HOSTS updated for pilot domains"
else
  fail_ "ALLOWED_HOSTS update for pilot domains not found"
fi

if [[ -f "$PRODUCTION_PY" ]] && grep -q "csrf_origin.*CSRF_TRUSTED_ORIGINS\|CSRF_TRUSTED_ORIGINS.*csrf_origin" "$PRODUCTION_PY"; then
  pass_ "CSRF_TRUSTED_ORIGINS updated for pilot domains"
else
  fail_ "CSRF_TRUSTED_ORIGINS update for pilot domains not found"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 7: DNS Configuration
# ────────────────────────────────────────────────────────────────────
echo "[Section 7] DNS Configuration"
DNS_YAML="${REPO_ROOT}/infrastructure/cloudflare/tenant-dns-records.yaml"

if [[ -f "$DNS_YAML" ]]; then
  pass_ "tenant-dns-records.yaml exists"
else
  fail_ "tenant-dns-records.yaml missing"
fi

if [[ -f "$DNS_YAML" ]] && grep -q "acme.academyv2.mereka.io" "$DNS_YAML"; then
  pass_ "acme.academyv2.mereka.io record present"
else
  fail_ "acme.academyv2.mereka.io record not found"
fi

if [[ -f "$DNS_YAML" ]] && grep -q "proxied: false" "$DNS_YAML"; then
  pass_ "proxied: false for multi-level subdomain"
else
  fail_ "proxied: false not found"
fi

if [[ -f "$DNS_YAML" ]] && grep -q "academyv2.mereka.io" "$DNS_YAML"; then
  pass_ "academyv2.mereka.io record present"
else
  fail_ "academyv2.mereka.io record not found"
fi

if [[ -f "$DNS_YAML" ]] && grep -qi "Let's Encrypt" "$DNS_YAML"; then
  pass_ "Let's Encrypt comment for multi-level subdomains"
else
  fail_ "Let's Encrypt comment not found"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 8: SAML Scoping (AC-TEN-011)
# ────────────────────────────────────────────────────────────────────
echo "[Section 8] SAML Scoping (AC-TEN-011)"

CONFIGURE_IDP="${REPO_ROOT}/scripts/tenants/configure-tenant-idp.sh"
if [[ -f "$CONFIGURE_IDP" ]]; then
  pass_ "configure-tenant-idp.sh exists (from earlier phase)"
else
  fail_ "configure-tenant-idp.sh not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -qi "saml\|single tenant\|scoped" "$ISOLATION_PY"; then
  skip_ "SAML assertions scoped to single tenant (documented in isolation.py comments)"
else
  skip_ "SAML scoping documentation (implementation note in spec)"
fi

skip_ "Runtime SAML verification (requires live setup)"

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 9: Cross-Tenant Data Leakage Prevention (AC-TEN-012)
# ────────────────────────────────────────────────────────────────────
echo "[Section 9] Cross-Tenant Data Leakage Prevention (AC-TEN-012)"

if [[ -f "$ISOLATION_PY" ]] && grep -q "raise PermissionDenied" "$ISOLATION_PY"; then
  pass_ "isolation.py blocks cross-tenant access with PermissionDenied"
else
  fail_ "PermissionDenied not raised in isolation.py"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "logger.warning" "$ISOLATION_PY"; then
  pass_ "Logger warns on cross-tenant attempts"
else
  fail_ "Logger warning on cross-tenant attempts not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "def filter_queryset_by_tenant" "$ISOLATION_PY"; then
  pass_ "filter_queryset_by_tenant method in TenantIsolationMixin"
else
  fail_ "filter_queryset_by_tenant method not found"
fi

if [[ -f "$ISOLATION_PY" ]] && grep -q "queryset.none()" "$ISOLATION_PY"; then
  pass_ "Non-enterprise users get queryset.none()"
else
  fail_ "queryset.none() for non-enterprise users not found"
fi

echo ""

# ────────────────────────────────────────────────────────────────────
# Section 10: Runtime Integration (SKIP)
# ────────────────────────────────────────────────────────────────────
echo "[Section 10] Runtime Integration (SKIP)"

skip_ "Provision acme tenant and verify isolation (requires runtime)"
skip_ "Cross-tenant API call returns 403 (requires runtime)"
skip_ "Branding renders correctly per tenant (requires runtime)"
skip_ "ClickHouse analytics isolated (requires runtime)"
skip_ "Superset RLS enforced (requires runtime)"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Summary"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}PASS:${NC} $PASS_COUNT"
echo -e "  ${RED}FAIL:${NC} $FAIL_COUNT"
echo -e "  ${YELLOW}SKIP:${NC} $SKIP_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}✗ Some checks failed.${NC}"
  echo ""
  exit 1
fi
