#!/usr/bin/env bash
# Verify TenantConfig model exists in the codebase.
# AC-001: TenantConfig extends EnterpriseCustomer with a OneToOneField.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

log_pass() { printf "PASS: %s\n" "$1"; }
log_fail() { printf "FAIL: %s\n" "$1"; FAILED=1; }

echo "=== Tenant Model Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

MODEL_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/models.py"

# Check 1: models.py exists
if [ -f "$MODEL_FILE" ]; then
  log_pass "models.py exists at infrastructure/tutor/plugins/multi-tenancy/"
else
  log_fail "models.py not found at infrastructure/tutor/plugins/multi-tenancy/"
  exit 1
fi

# Check 2: TenantConfig class defined
if grep -q "class TenantConfig" "$MODEL_FILE"; then
  log_pass "TenantConfig class defined"
else
  log_fail "TenantConfig class not found in models.py"
fi

# Check 3: OneToOneField to EnterpriseCustomer
if grep -q 'OneToOneField' "$MODEL_FILE" && grep -q 'enterprise.EnterpriseCustomer' "$MODEL_FILE"; then
  log_pass "OneToOneField to enterprise.EnterpriseCustomer present"
else
  log_fail "Missing OneToOneField to enterprise.EnterpriseCustomer"
fi

# Check 4: Required fields
for field in slug branding_config sso_config feature_flags is_active provisioned_at; do
  if grep -q "$field" "$MODEL_FILE"; then
    log_pass "Field '$field' present"
  else
    log_fail "Field '$field' missing"
  fi
done

# Check 5: app_label is mereka_tenancy
if grep -q 'app_label = "mereka_tenancy"' "$MODEL_FILE"; then
  log_pass "app_label is 'mereka_tenancy'"
else
  log_fail "app_label is not 'mereka_tenancy'"
fi

# Check 6: apps.py exists with AppConfig
APPS_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/apps.py"
if [ -f "$APPS_FILE" ] && grep -q "MerekaTenancyConfig" "$APPS_FILE"; then
  log_pass "apps.py with MerekaTenancyConfig exists"
else
  log_fail "apps.py or MerekaTenancyConfig missing"
fi

echo
if [ $FAILED -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
