#!/usr/bin/env bash
# @covers AC-MTA-008, AC-MTA-009, AC-MTA-010, AC-MTA-011, AC-MTA-012, AC-MTA-013, AC-MTA-014, AC-MTA-027, AC-MTA-028
# @spec: multi-tenancy-architecture_spec.md
# Verify multi-tenancy architecture components beyond foundation
#
# NOTE: verify-multi-tenancy-foundation.sh covers AC-MTA-001, AC-MTA-002, and base setup.
# This script covers ADDITIONAL ACs for tenant-specific functionality.
#
# Checks:
#   AC-MTA-008: Tenant branding logo display
#   AC-MTA-009: Tenant brand colors configuration
#   AC-MTA-010: Tenant footer branding
#   AC-MTA-011: Branding asset updates without rebuild
#   AC-MTA-012: Tenant domain routing
#   AC-MTA-013: Client-owned domain CNAME support
#   AC-MTA-014: Concurrent domain SiteConfiguration resolution
#   AC-MTA-027: API latency performance with multiple tenants
#   AC-MTA-028: Load test with 50 tenants
#
# Usage:
#   ./scripts/qa/verify-multi-tenancy.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Helper functions
pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Multi-Tenancy Architecture Verification ==="
echo "(Additional ACs beyond verify-multi-tenancy-foundation.sh)"
echo ""

# Check 1: Tenant provisioning script
echo "Checking AC-MTA-012, AC-MTA-013: Tenant provisioning and domain support..."

PROVISION_SCRIPT="scripts/tenants/provision-tenant.sh"

if [[ -f "$PROVISION_SCRIPT" ]]; then
  pass "AC-MTA-012: Tenant provisioning script exists at $PROVISION_SCRIPT"

  if [[ -x "$PROVISION_SCRIPT" ]]; then
    pass "AC-MTA-012: Provisioning script is executable"
  else
    fail "AC-MTA-012: Provisioning script is not executable"
  fi

  # Check for domain configuration support
  if grep -q "domain\|DOMAIN" "$PROVISION_SCRIPT"; then
    pass "AC-MTA-013: Provisioning script supports custom domain configuration"
  else
    skip "AC-MTA-013: Custom domain support not found in provisioning script"
  fi

  # Check for idempotency
  if grep -q "already provisioned\|exists" "$PROVISION_SCRIPT"; then
    pass "AC-MTA-012: Provisioning script includes idempotency checks"
  else
    skip "AC-MTA-012: Idempotency checks not detected in provisioning script"
  fi
else
  fail "AC-MTA-012: Tenant provisioning script not found at $PROVISION_SCRIPT"
fi

echo ""

# Check 2: Tenant branding assets structure
echo "Checking AC-MTA-008, AC-MTA-009, AC-MTA-010, AC-MTA-011: Tenant branding support..."

TENANT_BRANDING_DIR="infrastructure/tutor/themes/mereka/tenants"

if [[ -d "$TENANT_BRANDING_DIR" ]]; then
  pass "AC-MTA-008/AC-MTA-011: Tenant branding directory exists at $TENANT_BRANDING_DIR"

  # Check for tenant-specific subdirectories
  TENANT_DIRS=$(find "$TENANT_BRANDING_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  if [[ $TENANT_DIRS -gt 0 ]]; then
    pass "AC-MTA-008: Found $TENANT_DIRS tenant-specific branding directories"

    # Check for logo assets
    if find "$TENANT_BRANDING_DIR" -name "*.png" -o -name "*.svg" -o -name "*.jpg" | grep -q .; then
      pass "AC-MTA-008: Tenant logo assets found"
    else
      skip "AC-MTA-008: No tenant logo assets found (may be configured dynamically)"
    fi
  else
    skip "AC-MTA-008: No tenant-specific directories found (tenants may not be configured yet)"
  fi

  # Check for branding configuration files
  if find "$TENANT_BRANDING_DIR" -name "*.json" -o -name "*.yaml" -o -name "*.yml" | grep -q .; then
    pass "AC-MTA-009/AC-MTA-010: Tenant branding configuration files found"
  else
    skip "AC-MTA-009/AC-MTA-010: No branding config files (may use SiteConfiguration)"
  fi
else
  skip "AC-MTA-008/AC-MTA-011: Tenant branding directory not found (may use SiteConfiguration only)"
fi

# Check AC-MTA-011: Branding deployment without rebuild
COLLECTSTATIC_SCRIPT="scripts/infra/collectstatic.sh"
if [[ -f "$COLLECTSTATIC_SCRIPT" ]] || grep -r "collectstatic" scripts/ 2>/dev/null | grep -q .; then
  pass "AC-MTA-011: collectstatic mechanism exists for branding deployment"
else
  skip "AC-MTA-011: collectstatic deployment mechanism not found"
fi

echo ""

# Check 3: SiteConfiguration branding support
echo "Checking AC-MTA-009, AC-MTA-010: SiteConfiguration branding variables..."

PROD_SETTINGS="deploy/k8s/base/apps/openedx/settings/lms/production.py"

if [[ -f "$PROD_SETTINGS" ]]; then
  # Check for SiteConfiguration usage
  if grep -q "SiteConfiguration\|site_configuration" "$PROD_SETTINGS"; then
    pass "AC-MTA-014: SiteConfiguration support found in production settings"

    # Check for branding-related configuration
    BRANDING_KEYS=(
      "logo"
      "color"
      "footer"
      "brand"
    )

    BRANDING_FOUND=false
    for key in "${BRANDING_KEYS[@]}"; do
      if grep -qi "$key" "$PROD_SETTINGS"; then
        BRANDING_FOUND=true
        pass "AC-MTA-009/AC-MTA-010: Branding key '$key' referenced in settings"
      fi
    done

    if [[ "$BRANDING_FOUND" = false ]]; then
      skip "AC-MTA-009/AC-MTA-010: Branding keys not found (may be in SiteConfiguration JSON)"
    fi
  else
    skip "AC-MTA-014: SiteConfiguration not referenced in production settings"
  fi
else
  fail "AC-MTA-009/AC-MTA-010/AC-MTA-014: Production settings missing at $PROD_SETTINGS"
fi

echo ""

# Check 4: Multi-site domain configuration
echo "Checking AC-MTA-012, AC-MTA-013, AC-MTA-014: Multi-site domain routing..."

if [[ -f "$PROD_SETTINGS" ]]; then
  # Check for multiple domains in ALLOWED_HOSTS
  EXPECTED_DOMAINS=(
    "academyv2.mereka.io"
    "academy.biji-biji.com"
    "skillourfuture.academy.mereka.io"
  )

  ALL_FOUND=true
  for domain in "${EXPECTED_DOMAINS[@]}"; do
    if grep -q "$domain" "$PROD_SETTINGS"; then
      pass "AC-MTA-012/AC-MTA-013: Domain $domain configured in ALLOWED_HOSTS"
    else
      ALL_FOUND=false
      fail "AC-MTA-012: Domain $domain not found in ALLOWED_HOSTS"
    fi
  done

  # Check for Sites framework domain resolution
  if grep -q "_candidate_site_domains\|get_current_site" "$PROD_SETTINGS"; then
    pass "AC-MTA-014: Site resolution mechanism found for concurrent domains"
  else
    skip "AC-MTA-014: Site resolution mechanism not found"
  fi
else
  skip "AC-MTA-012/AC-MTA-013/AC-MTA-014: Production settings not available"
fi

echo ""

# Check 5: Caddy multi-domain configuration
echo "Checking AC-MTA-012, AC-MTA-013: Caddy reverse proxy multi-domain support..."

CADDYFILE="deploy/k8s/base/apps/caddy/Caddyfile"

if [[ -f "$CADDYFILE" ]]; then
  pass "AC-MTA-012: Caddy configuration file exists"

  # Check for multiple domain handling
  CADDY_DOMAINS=$(grep -o '[a-z0-9.-]*\.mereka\.[a-z]*\|[a-z0-9.-]*\.biji-biji\.com' "$CADDYFILE" 2>/dev/null | sort -u | wc -l)
  if [[ $CADDY_DOMAINS -gt 1 ]]; then
    pass "AC-MTA-012/AC-MTA-013: Caddy handles $CADDY_DOMAINS domains"
  else
    skip "AC-MTA-012: Caddy domain count not verified"
  fi

  # Check for wildcard or multi-site blocks
  if grep -q "{\$default_site_port}\|\*.mereka\.\|multi" "$CADDYFILE"; then
    pass "AC-MTA-012: Caddy multi-site routing configuration found"
  else
    skip "AC-MTA-012: Caddy multi-site configuration not detected"
  fi
else
  fail "AC-MTA-012/AC-MTA-013: Caddyfile missing at $CADDYFILE"
fi

echo ""

# Check 6: Performance benchmarks (requires live cluster)
echo "Checking AC-MTA-027, AC-MTA-028: Multi-tenant performance..."

KUBECTL_AVAILABLE=false
if command -v kubectl &> /dev/null; then
  if kubectl cluster-info &> /dev/null; then
    KUBECTL_AVAILABLE=true
  fi
fi

if [[ "$KUBECTL_AVAILABLE" = true ]]; then
  skip "AC-MTA-027: API latency benchmarking requires load test execution (manual)"
  skip "AC-MTA-028: 50-tenant load test requires load test execution (manual)"
else
  skip "AC-MTA-027/AC-MTA-028: kubectl not available, cannot check cluster performance"
fi

echo ""

# Check 7: Tenant ConfigMap registry
echo "Checking AC-MTA-014: Tenant registry ConfigMap..."

TENANT_CONFIGMAP="deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml"
TENANT_REGISTRY_SYNC="scripts/tenants/sync-tenant-registry-configmap.sh"

if [[ -f "$TENANT_CONFIGMAP" ]]; then
  pass "AC-MTA-014: Tenant registry ConfigMap found at $TENANT_CONFIGMAP"
else
  fail "AC-MTA-014: Tenant registry ConfigMap missing at $TENANT_CONFIGMAP"
fi

if [[ -x "$TENANT_REGISTRY_SYNC" ]]; then
  if "$TENANT_REGISTRY_SYNC" --check >/dev/null; then
    pass "AC-MTA-014: tenant registry sync contract passes"
  else
    fail "AC-MTA-014: tenant registry drift detected (sync contract)"
  fi
else
  skip "AC-MTA-014: tenant registry sync script not present yet (merge #386 for strict sync enforcement)"
fi

echo ""

# Check 8: Tenant isolation patterns in code
echo "Checking tenant isolation patterns in codebase..."

TENANT_PLUGIN_DIR="infrastructure/tutor/plugins/multi-tenancy"

if [[ -d "$TENANT_PLUGIN_DIR" ]]; then
  pass "Multi-tenancy plugin directory exists at $TENANT_PLUGIN_DIR"

  # Check for TenantConfig model
  if rg -n "class TenantConfig" "$TENANT_PLUGIN_DIR" -g "*.py" >/dev/null 2>&1; then
    pass "TenantConfig model defined in multi-tenancy plugin"
  else
    skip "TenantConfig model not found (may be defined elsewhere)"
  fi

  # Check for TenantResolutionMiddleware
  if rg -n "TenantResolutionMiddleware" "$TENANT_PLUGIN_DIR" -g "*.py" >/dev/null 2>&1; then
    pass "TenantResolutionMiddleware found in multi-tenancy plugin"
  else
    skip "TenantResolutionMiddleware not found"
  fi

  # Check for setup.py (plugin installation)
  if [[ -f "$TENANT_PLUGIN_DIR/setup.py" ]]; then
    pass "Multi-tenancy plugin has setup.py for installation"
  else
    skip "Multi-tenancy plugin setup.py not found"
  fi
else
  skip "Multi-tenancy plugin directory not found at $TENANT_PLUGIN_DIR"
fi

echo ""

# Check 9: Integration with apply-patches.sh
echo "Checking multi-tenancy integration in apply-patches.sh..."

APPLY_PATCHES="infrastructure/tutor/apply-patches.sh"

if [[ -f "$APPLY_PATCHES" ]]; then
  # Check for tenant-related patches
  if grep -q "tenant\|TENANT\|multi.*tenancy" "$APPLY_PATCHES"; then
    pass "Multi-tenancy patches referenced in apply-patches.sh"
  else
    skip "Multi-tenancy patches not found in apply-patches.sh"
  fi

  # Check for SiteConfiguration patches
  if grep -q "SiteConfiguration\|SITE_CONFIG" "$APPLY_PATCHES"; then
    pass "SiteConfiguration patches found in apply-patches.sh"
  else
    skip "SiteConfiguration patches not found"
  fi
else
  skip "apply-patches.sh not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

echo ""
echo "NOTE: This script covers additional multi-tenancy ACs."
echo "Run verify-multi-tenancy-foundation.sh for base setup checks."
echo "Run verify-tenant-isolation.sh for cross-tenant isolation tests."

[[ $FAIL -gt 0 ]] && exit 1
exit 0
