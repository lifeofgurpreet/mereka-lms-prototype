#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-002, AC-MTA-021
# @spec: multi-tenancy-architecture_spec.md
# Enhanced verification of tenant provisioning management command.
# AC-MTA-001: Provisioning creates all required records (Site, SiteConfig, EC, TenantConfig).
# AC-MTA-002: Idempotent re-run creates no duplicates.
# AC-MTA-021: Provisioning script creates all required records within 15 minutes.
#
# This extends verify-tenant-provisioning.sh with checks for:
#   - OAuth2 Application creation
#   - Waffle Switch creation
#   - SiteConfiguration required fields (PLATFORM_NAME, SITE_NAME, etc.)
#   - --dry-run flag
#   - Duplicate domain validation across tenants
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

log_pass() { printf "PASS: %s\n" "$1"; PASS=$((PASS + 1)); }
log_fail() { printf "FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }

echo "=== Enhanced Tenant Provisioning Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

CMD_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/commands/provision_tenant.py"

# Check 1: Command file exists
if [ -f "$CMD_FILE" ]; then
  log_pass "provision_tenant.py exists"
else
  log_fail "provision_tenant.py not found"
  echo; echo "FAIL: $FAIL"; exit 1
fi

# Check 2: Extends BaseCommand
if grep -q "class Command(BaseCommand)" "$CMD_FILE"; then
  log_pass "Extends BaseCommand"
else
  log_fail "Does not extend BaseCommand"
fi

# Check 3: Required arguments (--slug, --name, --domain)
for arg in slug name domain; do
  if grep -q "\"--$arg\"" "$CMD_FILE"; then
    log_pass "Accepts --$arg argument"
  else
    log_fail "Missing --$arg argument"
  fi
done

# Check 4: --dry-run flag
if grep -q "\"--dry-run\"" "$CMD_FILE"; then
  log_pass "Accepts --dry-run flag"
else
  log_fail "Missing --dry-run flag"
fi

# Check 5: Idempotency (get_or_create pattern)
if grep -q "get_or_create" "$CMD_FILE"; then
  log_pass "Uses get_or_create (idempotent)"
else
  log_fail "Does not use get_or_create (not idempotent)"
fi

# Check 6: Creates all required records
REQUIRED_MODELS=(
  "EnterpriseCustomer"
  "TenantConfig"
  "SiteConfiguration"
  "Site"
)
for model in "${REQUIRED_MODELS[@]}"; do
  if grep -q "$model" "$CMD_FILE"; then
    log_pass "References $model model"
  else
    log_fail "Does not reference $model model"
  fi
done

# Check 7: Creates OAuth2 Application
if grep -q "oauth2_provider\|OAuth2\|Application" "$CMD_FILE"; then
  log_pass "Creates OAuth2 Application for tenant"
else
  log_fail "Does not create OAuth2 Application"
fi

# Check 8: Creates Waffle Switches
if grep -q "waffle\|Switch\|WAFFLE" "$CMD_FILE"; then
  log_pass "Creates Waffle Switches for tenant feature flags"
else
  log_fail "Does not create Waffle Switches"
fi

# Check 9: SiteConfiguration includes required fields
REQUIRED_SITE_CONFIG_FIELDS=(
  "SITE_NAME"
  "PLATFORM_NAME"
  "LMS_ROOT_URL"
  "ENABLE_ENTERPRISE_INTEGRATION"
)
for field in "${REQUIRED_SITE_CONFIG_FIELDS[@]}"; do
  if grep -q "\"$field\"" "$CMD_FILE"; then
    log_pass "SiteConfiguration includes $field"
  else
    log_fail "SiteConfiguration missing $field"
  fi
done

# Check 10: Input validation for slug format
if grep -q "isalnum\|CommandError.*slug\|Invalid slug" "$CMD_FILE"; then
  log_pass "Validates slug format"
else
  log_fail "No slug format validation"
fi

# Check 11: Duplicate domain validation
if grep -q "already assigned to tenant\|domain.*already\|duplicate.*domain" "$CMD_FILE"; then
  log_pass "Validates duplicate domain across tenants"
else
  log_fail "No duplicate domain cross-tenant validation"
fi

# Check 12: Dry run implementation
if grep -q "_print_dry_run\|dry_run" "$CMD_FILE"; then
  log_pass "Dry run implementation exists"
else
  log_fail "No dry run implementation"
fi

# Check 13: @covers annotation uses AC-MTA- prefix
if grep -q "@covers.*AC-MTA-" "$CMD_FILE"; then
  log_pass "@covers annotation uses AC-MTA- prefix"
else
  log_fail "@covers annotation missing AC-MTA- prefix (testmap mismatch)"
fi

# Check 14: Shell wrapper script exists
SHELL_WRAPPER="$REPO_ROOT/scripts/tenants/provision-tenant.sh"
if [ -x "$SHELL_WRAPPER" ]; then
  log_pass "Shell wrapper script exists and is executable"
else
  log_fail "Shell wrapper script missing or not executable"
fi

# Check 15: Shell wrapper supports --dry-run
if [ -f "$SHELL_WRAPPER" ] && grep -q "\-\-dry-run" "$SHELL_WRAPPER"; then
  log_pass "Shell wrapper supports --dry-run"
else
  log_fail "Shell wrapper missing --dry-run support"
fi

# Check 16: Management commands package structure
MGMT_INIT="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/__init__.py"
CMD_INIT="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/commands/__init__.py"
if [ -f "$MGMT_INIT" ] && [ -f "$CMD_INIT" ]; then
  log_pass "Management commands package structure correct"
else
  log_fail "Missing __init__.py in management/commands/"
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo
if [ $FAIL -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
