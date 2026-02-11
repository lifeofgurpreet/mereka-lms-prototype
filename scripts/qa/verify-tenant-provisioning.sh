#!/usr/bin/env bash
# Verify tenant provisioning management command exists and is well-formed.
# AC-001, AC-002, AC-021: Idempotent provisioning with validation.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

log_pass() { printf "PASS: %s\n" "$1"; }
log_fail() { printf "FAIL: %s\n" "$1"; FAILED=1; }

echo "=== Tenant Provisioning Command Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

CMD_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/commands/provision_tenant.py"

# Check 1: Command file exists
if [ -f "$CMD_FILE" ]; then
  log_pass "provision_tenant.py exists"
else
  log_fail "provision_tenant.py not found"
  exit 1
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

# Check 4: Idempotency (get_or_create pattern)
if grep -q "get_or_create" "$CMD_FILE"; then
  log_pass "Uses get_or_create (idempotent)"
else
  log_fail "Does not use get_or_create (not idempotent)"
fi

# Check 5: Creates EnterpriseCustomer
if grep -q "EnterpriseCustomer" "$CMD_FILE"; then
  log_pass "References EnterpriseCustomer model"
else
  log_fail "Does not reference EnterpriseCustomer model"
fi

# Check 6: Creates TenantConfig
if grep -q "TenantConfig" "$CMD_FILE"; then
  log_pass "References TenantConfig model"
else
  log_fail "Does not reference TenantConfig model"
fi

# Check 7: Creates Site
if grep -q "django.contrib.sites.models" "$CMD_FILE" || grep -q "Site.objects" "$CMD_FILE"; then
  log_pass "Creates/uses Django Site"
else
  log_fail "Does not create Django Site"
fi

# Check 8: Creates SiteConfiguration
if grep -q "SiteConfiguration" "$CMD_FILE"; then
  log_pass "Creates/uses SiteConfiguration"
else
  log_fail "Does not create SiteConfiguration"
fi

# Check 9: Input validation
if grep -q "_validate_inputs\|CommandError" "$CMD_FILE"; then
  log_pass "Has input validation"
else
  log_fail "No input validation found"
fi

# Check 10: Management commands package structure
MGMT_INIT="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/__init__.py"
CMD_INIT="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/commands/__init__.py"
if [ -f "$MGMT_INIT" ] && [ -f "$CMD_INIT" ]; then
  log_pass "Management commands package structure correct"
else
  log_fail "Missing __init__.py in management/commands/"
fi

echo
if [ $FAILED -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
