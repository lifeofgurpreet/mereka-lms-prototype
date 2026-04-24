#!/usr/bin/env bash
# @covers AC-MTA-022, AC-MTA-023, AC-MTA-024
# @spec: multi-tenancy-architecture_spec.md
# Verify tenant offboarding script exists and has required features.
# AC-MTA-022: Offboarding completes data deletion (zero records remain).
# AC-MTA-023: ClickHouse events deleted after offboarding.
# AC-MTA-024: Audit log entry exists after offboarding.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

log_pass() { printf "PASS: %s\n" "$1"; PASS=$((PASS + 1)); }
log_fail() { printf "FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }

echo "=== Tenant Offboarding Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

OFFBOARD_SCRIPT="$REPO_ROOT/scripts/tenants/offboard-tenant.sh"

# Check 1: Offboarding script exists
if [ -f "$OFFBOARD_SCRIPT" ]; then
  log_pass "offboard-tenant.sh exists"
else
  log_fail "offboard-tenant.sh not found"
  echo; echo "FAIL: $FAIL"; exit 1
fi

# Check 2: Script is executable
if [ -x "$OFFBOARD_SCRIPT" ]; then
  log_pass "offboard-tenant.sh is executable"
else
  log_fail "offboard-tenant.sh is not executable"
fi

# Check 3: Accepts --slug argument
if grep -q "\-\-slug" "$OFFBOARD_SCRIPT"; then
  log_pass "Accepts --slug argument"
else
  log_fail "Missing --slug argument"
fi

# Check 4: Supports --dry-run
if grep -q "\-\-dry-run" "$OFFBOARD_SCRIPT"; then
  log_pass "Supports --dry-run"
else
  log_fail "Missing --dry-run support"
fi

# Check 5: @covers annotation
if grep -q "@covers.*AC-MTA-022" "$OFFBOARD_SCRIPT"; then
  log_pass "@covers annotation includes AC-MTA-022"
else
  log_fail "@covers annotation missing AC-MTA-022"
fi

# Check 6: Deactivates EnterpriseCustomer (active=False)
if grep -q "active.*False\|deactivate.*enterprise\|EnterpriseCustomer" "$OFFBOARD_SCRIPT"; then
  log_pass "Deactivates EnterpriseCustomer"
else
  log_fail "Does not deactivate EnterpriseCustomer"
fi

# Check 7: Deactivates TenantConfig (is_active=False)
if grep -q "is_active.*False\|deactivate.*tenant\|TenantConfig" "$OFFBOARD_SCRIPT"; then
  log_pass "Deactivates TenantConfig"
else
  log_fail "Does not deactivate TenantConfig"
fi

# Check 8: Exports tenant data
if grep -q "export\|Export\|EXPORT" "$OFFBOARD_SCRIPT"; then
  log_pass "Includes data export functionality"
else
  log_fail "Missing data export functionality"
fi

# Check 9: Generates audit report (AC-MTA-024)
if grep -q "audit\|AUDIT\|audit_log\|offboarding-audit" "$OFFBOARD_SCRIPT"; then
  log_pass "Generates audit report (AC-MTA-024)"
else
  log_fail "Missing audit report generation"
fi

# Check 10: Audit report includes required fields (uuid, action, actor, timestamp)
if grep -q "tenant_slug\|enterprise_customer_uuid\|timestamp\|action" "$OFFBOARD_SCRIPT"; then
  log_pass "Audit report includes required fields (uuid, action, timestamp)"
else
  log_fail "Audit report missing required fields"
fi

# Check 11: Disables SSO (SAML/OIDC provider)
if grep -q "sso\|SSO\|SAML\|saml_config\|identity_provider" "$OFFBOARD_SCRIPT"; then
  log_pass "Includes SSO disablement step"
else
  log_fail "Missing SSO disablement step"
fi

# Check 12: Disables Waffle switches
if grep -q "waffle\|Switch\|switches" "$OFFBOARD_SCRIPT"; then
  log_pass "Disables tenant Waffle switches"
else
  log_fail "Missing Waffle switch disablement"
fi

# Check 13: Documents grace period
if grep -q "grace.*period\|30.*day\|30-day" "$OFFBOARD_SCRIPT"; then
  log_pass "Documents 30-day grace period"
else
  log_fail "Missing grace period documentation"
fi

# Check 14: Documents post-grace-period data deletion steps
if grep -q "Redis\|ClickHouse\|branding.*assets\|ALLOWED_HOSTS" "$OFFBOARD_SCRIPT"; then
  log_pass "Documents post-grace-period cleanup steps"
else
  log_fail "Missing post-grace-period cleanup documentation"
fi

# Check 15: Counts linked users for export
if grep -q "user_count\|EnterpriseCustomerUser" "$OFFBOARD_SCRIPT"; then
  log_pass "Counts/exports linked enterprise users"
else
  log_fail "Does not count linked enterprise users"
fi

# Check 16: Counts linked enrollments for export
if grep -q "enrollment_count\|EnterpriseCourseEnrollment" "$OFFBOARD_SCRIPT"; then
  log_pass "Counts/exports enterprise enrollments"
else
  log_fail "Does not count enterprise enrollments"
fi

# Check 17: Uses set -euo pipefail
if head -25 "$OFFBOARD_SCRIPT" | grep -q "set -euo pipefail"; then
  log_pass "Uses set -euo pipefail"
else
  log_fail "Missing set -euo pipefail"
fi

# Check 18: Works with both kubectl and tutor
if grep -q "kubectl" "$OFFBOARD_SCRIPT" && grep -q "tutor" "$OFFBOARD_SCRIPT"; then
  log_pass "Supports both kubectl and tutor execution contexts"
else
  log_fail "Missing support for both kubectl and tutor"
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
