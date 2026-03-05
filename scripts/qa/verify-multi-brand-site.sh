#!/usr/bin/env bash
# @covers AC-001, AC-005, AC-008
# @spec: multi-site-domains_spec.md
# Verify multi-brand multi-site configuration — static/config checks only.
# Does NOT require a running cluster or LMS pod.
#
# Checks:
# - multisite-sites.yml structure and required fields
# - All declared sites are present in the Caddyfile
# - All declared site domains are in ALLOWED_HOSTS (mereka_lms.py)
# - Design token pipeline: canonical → generated files are in sync
# - Per-tenant brand assets directory structure
# - Tutor plugin multi-site defaults (extra hosts, CSRF origins)
# - mereka_tenancy Django app files exist (middleware, models, migration)
# - env.config.jsx exists and references mereka SCSS
#
# Usage:
#   ./scripts/qa/verify-multi-brand-site.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""
PLUGIN_BUNDLE_FILE="$PLUGIN_MAIN"

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
  PLUGIN_BUNDLE_FILE="$PLUGIN_BUNDLE"
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)) || true; }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; ((SKIP++)) || true; }
section() { echo ""; echo -e "${BLUE}### $1${NC}"; }

echo -e "${BLUE}=== Multi-Brand Multi-Site Verification ===${NC}"
echo ""

# ---------------------------------------------------------------------------
# 1. multisite-sites.yml structure
# ---------------------------------------------------------------------------
section "1. multisite-sites.yml"

SITES_YML="infrastructure/tutor/multisite-sites.yml"

if [[ ! -f "$SITES_YML" ]]; then
  fail "multisite-sites.yml not found at $SITES_YML"
else
  pass "multisite-sites.yml exists"

  # Check YAML is valid (requires python3 with yaml)
  if python3 -c "import yaml, sys; yaml.safe_load(open('$SITES_YML'))" 2>/dev/null; then
    pass "multisite-sites.yml is valid YAML"
  else
    fail "multisite-sites.yml is not valid YAML"
  fi

  # Expected canonical sites
  EXPECTED_SITE_DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")

  for domain in "${EXPECTED_SITE_DOMAINS[@]}"; do
    if grep -qF "$domain" "$SITES_YML"; then
      pass "Site declared in multisite-sites.yml: $domain"
    else
      fail "Site missing from multisite-sites.yml: $domain"
    fi
  done

  # Check required site_values keys for each site
  REQUIRED_VALUES=("LMS_ROOT_URL" "CMS_ROOT_URL" "MFE_BASE_URL" "THEME_NAME" "course_org_filter")
  for key in "${REQUIRED_VALUES[@]}"; do
    if grep -qF "$key" "$SITES_YML"; then
      pass "Required site_values key present in multisite-sites.yml: $key"
    else
      fail "Required site_values key missing from multisite-sites.yml: $key"
    fi
  done

  # THEME_NAME must be "mereka" for all sites
  THEME_ENTRIES=$(grep "THEME_NAME:" "$SITES_YML" | awk '{print $2}' | sort -u)
  if [[ "$THEME_ENTRIES" == "mereka" ]]; then
    pass "All sites use THEME_NAME: mereka"
  else
    fail "Not all sites use THEME_NAME: mereka (found: $THEME_ENTRIES)"
  fi

  # Each site has a unique org in course_org_filter
  ORGS=($(grep -A2 "course_org_filter:" "$SITES_YML" | grep -E "^\s+- " | awk '{print $2}'))
  UNIQUE_ORGS=($(echo "${ORGS[@]}" | tr ' ' '\n' | sort -u))
  if [[ ${#ORGS[@]} -eq ${#UNIQUE_ORGS[@]} ]]; then
    pass "All sites have unique org filters (${ORGS[*]})"
  else
    fail "Duplicate org filters found in multisite-sites.yml"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Caddyfile domain coverage
# ---------------------------------------------------------------------------
section "2. Caddyfile domain coverage"

CADDYFILE="deploy/k8s/base/apps/caddy/Caddyfile"

if [[ ! -f "$CADDYFILE" ]]; then
  fail "Caddyfile not found at $CADDYFILE"
else
  pass "Caddyfile exists"

  CADDY_LMS_DOMAINS=("academyv2.mereka.io" "academy.biji-biji.com" "skillourfuture.academy.mereka.io")
  for domain in "${CADDY_LMS_DOMAINS[@]}"; do
    if grep -qF "$domain" "$CADDYFILE"; then
      pass "Domain in Caddyfile: $domain"
    else
      fail "Domain missing from Caddyfile: $domain"
    fi
  done

  # Studio domains
  CADDY_STUDIO_DOMAINS=("studio.academyv2.mereka.io" "studio.academy.biji-biji.com")
  for domain in "${CADDY_STUDIO_DOMAINS[@]}"; do
    if grep -qF "$domain" "$CADDYFILE"; then
      pass "Studio domain in Caddyfile: $domain"
    else
      fail "Studio domain missing from Caddyfile: $domain"
    fi
  done

  # MFE domains
  CADDY_MFE_DOMAINS=("apps.academyv2.mereka.io" "apps.academy.biji-biji.com")
  for domain in "${CADDY_MFE_DOMAINS[@]}"; do
    if grep -qF "$domain" "$CADDYFILE"; then
      pass "MFE domain in Caddyfile: $domain"
    else
      fail "MFE domain missing from Caddyfile: $domain"
    fi
  done

  # mfe_config proxy: enterprise portals must forward Host header to LMS
  ENTERPRISE_PORTALS=("admin.academyv2.mereka.io" "enterprise.academyv2.mereka.io")
  for portal in "${ENTERPRISE_PORTALS[@]}"; do
    if grep -A5 "$portal" "$CADDYFILE" | grep -qF "header_up Host"; then
      pass "Enterprise portal $portal proxies mfe_config with Host header"
    else
      fail "Enterprise portal $portal missing 'header_up Host' for mfe_config proxy"
    fi
  done

  # LMS vhost block forwards to lms:8000
  if grep -qF 'proxy "lms:8000"' "$CADDYFILE"; then
    pass "Caddyfile LMS proxy target is lms:8000"
  else
    fail "Caddyfile LMS proxy target 'lms:8000' not found"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Tutor plugin multi-site config
# ---------------------------------------------------------------------------
section "3. Tutor plugin multi-site config"

PLUGIN="$PLUGIN_BUNDLE_FILE"

if [[ ! -f "$PLUGIN" ]]; then
  fail "mereka_lms.py plugin not found at $PLUGIN"
else
  pass "mereka_lms.py plugin exists"

  PLUGIN_EXPECTED_HOSTS=("academy.biji-biji.com" "skillourfuture.academy.mereka.io" "enterprise.academyv2.mereka.io")
  for host in "${PLUGIN_EXPECTED_HOSTS[@]}"; do
    if grep -qF "$host" "$PLUGIN"; then
      pass "Extra host in mereka_lms.py: $host"
    else
      fail "Extra host missing from mereka_lms.py: $host"
    fi
  done

  # CSRF origins
  if grep -qF "MEREKA_LMS_EXTRA_CSRF_ORIGINS" "$PLUGIN"; then
    pass "CSRF origins config key declared in mereka_lms.py"
  else
    fail "CSRF origins config key missing from mereka_lms.py"
  fi

  # DEFAULT_SITE_THEME
  if grep -qF 'DEFAULT_SITE_THEME = "mereka"' "$PLUGIN"; then
    pass "DEFAULT_SITE_THEME set to mereka in mereka_lms.py"
  else
    fail "DEFAULT_SITE_THEME not set in mereka_lms.py"
  fi

  # Session cookie domain config key
  if grep -qF "MEREKA_SESSION_COOKIE_DOMAIN" "$PLUGIN"; then
    pass "Session cookie domain config key present in mereka_lms.py"
  else
    fail "Session cookie domain config key missing from mereka_lms.py"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Design token pipeline
# ---------------------------------------------------------------------------
section "4. Design token pipeline"

CANONICAL="assets/branding/tokens.css"
GENERATED_CSS="infrastructure/tutor/themes/mereka/common/static/css/mereka-design-tokens.css"
OVERRIDES_CSS="infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
TOKENS_SCSS="infrastructure/tutor/themes/mereka/scss/_tokens.scss"

if [[ ! -f "$CANONICAL" ]]; then
  fail "Canonical tokens file not found: $CANONICAL"
else
  pass "Canonical tokens file exists: $CANONICAL"
fi

if [[ ! -f "$GENERATED_CSS" ]]; then
  fail "Generated design tokens CSS not found: $GENERATED_CSS"
else
  pass "Generated design tokens CSS exists: $GENERATED_CSS"

  # Check the DO NOT EDIT header is present
  if grep -q "DO NOT EDIT" "$GENERATED_CSS"; then
    pass "Generated CSS has DO NOT EDIT header (confirms it is auto-generated)"
  else
    fail "Generated CSS missing DO NOT EDIT header"
  fi
fi

if [[ ! -f "$OVERRIDES_CSS" ]]; then
  fail "Brand overrides CSS not found: $OVERRIDES_CSS"
else
  pass "Brand overrides CSS exists: $OVERRIDES_CSS"

  # Check Paragon bridge tokens present (use grep -e to avoid -- being parsed as flags)
  if grep -e "pgn-color-primary" "$OVERRIDES_CSS" >/dev/null 2>&1; then
    pass "Paragon bridge tokens present in mereka-overrides.css"
  else
    fail "Paragon bridge tokens missing from mereka-overrides.css"
  fi

  # Check mereka-color-teal (key palette token)
  if grep -e "mereka-color-teal" "$OVERRIDES_CSS" >/dev/null 2>&1; then
    pass "Mereka palette tokens present in mereka-overrides.css"
  else
    fail "Mereka palette tokens missing from mereka-overrides.css"
  fi
fi

if [[ ! -f "$TOKENS_SCSS" ]]; then
  fail "SCSS tokens file not found: $TOKENS_SCSS"
else
  pass "SCSS tokens file exists: $TOKENS_SCSS"

  # Check key SCSS variables
  if grep -qF "\$color-teal:" "$TOKENS_SCSS"; then
    pass "SCSS token \$color-teal defined in _tokens.scss"
  else
    fail "SCSS token \$color-teal missing from _tokens.scss"
  fi

  if grep -qF "\$mereka-body-font:" "$TOKENS_SCSS"; then
    pass "SCSS font token defined in _tokens.scss"
  else
    fail "SCSS font token missing from _tokens.scss"
  fi
fi

# Canonical and generated should share the same teal value
if [[ -f "$CANONICAL" && -f "$GENERATED_CSS" ]]; then
  CANONICAL_TEAL=$(grep "\-\-color-teal:" "$CANONICAL" | awk '{print $2}' | tr -d ';')
  GENERATED_TEAL=$(grep "\-\-color-teal:" "$GENERATED_CSS" | awk '{print $2}' | tr -d ';')
  if [[ -n "$CANONICAL_TEAL" && "$CANONICAL_TEAL" == "$GENERATED_TEAL" ]]; then
    pass "Teal color token matches between canonical and generated CSS ($CANONICAL_TEAL)"
  elif [[ -z "$CANONICAL_TEAL" ]]; then
    skip "Could not extract teal color from canonical tokens"
  else
    fail "Teal color token mismatch: canonical=$CANONICAL_TEAL generated=$GENERATED_TEAL"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Per-tenant assets directory structure
# ---------------------------------------------------------------------------
section "5. Per-tenant assets directory"

TENANTS_DIR="infrastructure/tutor/themes/mereka/tenants"
TEMPLATE_DIR="$TENANTS_DIR/_template"

if [[ ! -d "$TENANTS_DIR" ]]; then
  fail "Tenants directory not found: $TENANTS_DIR"
else
  pass "Tenants directory exists: $TENANTS_DIR"
fi

if [[ ! -d "$TEMPLATE_DIR" ]]; then
  fail "Tenant template directory not found: $TEMPLATE_DIR"
else
  pass "Tenant _template directory exists"

  for subdir in logos favicons css; do
    if [[ -d "$TEMPLATE_DIR/$subdir" ]]; then
      pass "Template subdirectory exists: $subdir/"
    else
      fail "Template subdirectory missing: $TEMPLATE_DIR/$subdir/"
    fi
  done

  if [[ -f "$TEMPLATE_DIR/README.md" ]]; then
    pass "_template/README.md exists"
  else
    fail "_template/README.md missing"
  fi
fi

# Count real tenant directories (exclude _template)
REAL_TENANTS=()
while IFS= read -r d; do
  slug=$(basename "$d")
  [[ "$slug" == "_template" ]] && continue
  REAL_TENANTS+=("$slug")
done < <(find "$TENANTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)

if [[ ${#REAL_TENANTS[@]} -eq 0 ]]; then
  skip "No provisioned tenant directories found (expected for fresh deployment)"
else
  pass "Found ${#REAL_TENANTS[@]} provisioned tenant director(ies): ${REAL_TENANTS[*]}"
fi

# brand-pack-schema.json
SCHEMA_FILE="infrastructure/tutor/plugins/multi-tenancy/brand-config-schema.json"
if [[ -f "$SCHEMA_FILE" ]]; then
  pass "Brand config JSON schema exists: $SCHEMA_FILE"
  if python3 -c "import json; json.load(open('$SCHEMA_FILE'))" 2>/dev/null; then
    pass "Brand config schema is valid JSON"
  else
    fail "Brand config schema is not valid JSON"
  fi
else
  fail "Brand config JSON schema missing: $SCHEMA_FILE"
fi

# ---------------------------------------------------------------------------
# 6. mereka_tenancy Django app
# ---------------------------------------------------------------------------
section "6. mereka_tenancy Django app"

TENANCY_DIR="infrastructure/tutor/plugins/multi-tenancy"

TENANCY_FILES=(
  "__init__.py"
  "models.py"
  "middleware.py"
  "admin.py"
  "apps.py"
  "setup.py"
  "migrations/__init__.py"
  "migrations/0001_initial.py"
  "management/__init__.py"
  "management/commands/__init__.py"
  "management/commands/provision_tenant.py"
)

for f in "${TENANCY_FILES[@]}"; do
  if [[ -f "$TENANCY_DIR/$f" ]]; then
    pass "mereka_tenancy file exists: $f"
  else
    fail "mereka_tenancy file missing: $TENANCY_DIR/$f"
  fi
done

# Check middleware sets X-Tenant-ID header
if grep -qF "X-Tenant-ID" "$TENANCY_DIR/middleware.py"; then
  pass "TenantResolutionMiddleware sets X-Tenant-ID response header"
else
  fail "TenantResolutionMiddleware missing X-Tenant-ID header"
fi

# Check provision_tenant creates Site + SiteConfiguration + EnterpriseCustomer
PROVISION_CMD="$TENANCY_DIR/management/commands/provision_tenant.py"
for class in "_get_or_create_site" "_get_or_create_site_configuration" "_get_or_create_enterprise_customer" "_get_or_create_tenant_config"; do
  if grep -qF "$class" "$PROVISION_CMD"; then
    pass "provision_tenant implements $class"
  else
    fail "provision_tenant missing $class"
  fi
done

# Check mereka_tenancy is wired into INSTALLED_APPS in mereka_lms.py
if [[ -f "$PLUGIN" ]]; then
  if grep -qF "mereka_tenancy" "$PLUGIN"; then
    pass "mereka_tenancy is referenced in mereka_lms.py (INSTALLED_APPS wiring)"
  else
    fail "mereka_tenancy not referenced in mereka_lms.py — INSTALLED_APPS wiring may be missing"
  fi
fi

# ---------------------------------------------------------------------------
# 7. MFE env.config.jsx
# ---------------------------------------------------------------------------
section "7. MFE env.config.jsx"

ENV_CONFIG="tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"

if [[ ! -f "$ENV_CONFIG" ]]; then
  skip "env.config.jsx not found (tutor_env/ not generated — run tutor config save)"
else
  pass "env.config.jsx exists"

  # Should import mereka SCSS
  if grep -qF "mereka" "$ENV_CONFIG"; then
    pass "env.config.jsx references Mereka customizations"
  else
    fail "env.config.jsx does not reference Mereka customizations"
  fi

  # Should have setConfig function (required by Open edX MFE runtime)
  if grep -qF "setConfig" "$ENV_CONFIG"; then
    pass "env.config.jsx has setConfig function"
  else
    fail "env.config.jsx missing setConfig function"
  fi

  # Footer component should use getConfig() for nav links (not hardcoded array)
  if grep -qF "getConfig()" "$ENV_CONFIG"; then
    pass "env.config.jsx uses getConfig() for runtime values"
  else
    fail "env.config.jsx does not use getConfig() — nav links may be hardcoded"
  fi
fi

# ---------------------------------------------------------------------------
# 8. Provisioning tooling
# ---------------------------------------------------------------------------
section "8. Provisioning tooling"

TENANT_SCRIPTS=(
  "scripts/tenants/provision-tenant.sh"
  "scripts/tenants/validate-tenant-brand-pack.sh"
  "scripts/tenants/sync-tenant-branding.sh"
  "scripts/tenants/brand-pack-template.json"
  "scripts/tenants/provision-all-tenants.sh"
)

for f in "${TENANT_SCRIPTS[@]}"; do
  if [[ -f "$f" ]]; then
    pass "Provisioning script exists: $f"
  else
    fail "Provisioning script missing: $f"
  fi
done

# Provision script must have --dry-run support
if grep -q "dry.run" "scripts/tenants/provision-tenant.sh" 2>/dev/null; then
  pass "provision-tenant.sh supports --dry-run"
else
  fail "provision-tenant.sh missing --dry-run support"
fi

# brand-pack-template.json is valid JSON
if python3 -c "import json; json.load(open('scripts/tenants/brand-pack-template.json'))" 2>/dev/null; then
  pass "brand-pack-template.json is valid JSON"
else
  fail "brand-pack-template.json is not valid JSON"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${YELLOW}SKIP${NC}: $SKIP"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}All checks passed.${NC}"
  exit 0
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  exit 1
fi
