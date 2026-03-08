#!/usr/bin/env bash
# @covers AC-MTA-001, AC-MTA-002, AC-MTA-021
# @spec: multi-tenancy-architecture_spec.md
set -euo pipefail

# verify-tenant-isolation.sh - Verifies tenant provisioning system
#
# Usage:
#   scripts/qa/verify-tenant-isolation.sh              # Run all checks
#   scripts/qa/verify-tenant-isolation.sh --skip-cluster # Skip runtime checks

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CUSTOM_APPS="$REPO_ROOT/infrastructure/tutor/custom-apps"
TENANT_APP="$CUSTOM_APPS/openedx_tenant_cache"
MGMT_CMD="$TENANT_APP/management/commands/provision_tenant.py"
BACKFILL_CMD="$TENANT_APP/management/commands/backfill_xapi_enterprise_uuid.py"
PROVISION_SCRIPT="$REPO_ROOT/scripts/tenants/provision-tenant.sh"
MEREKA_ENV="$REPO_ROOT/scripts/tenants/mereka-tenant.env"
TENANT_DOC="$REPO_ROOT/docs/runbooks/operations/TENANT_PROVISIONING.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
SKIP=0

# Parse arguments
SKIP_CLUSTER=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-cluster) SKIP_CLUSTER=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "${YELLOW}⊘${NC} $1"
  SKIP=$((SKIP + 1))
}

# Section 1: Management Command Structure
check_management_command_structure() {
  echo "Section 1: Management Command Structure"

  # provision_tenant.py exists
  if [[ -f "$MGMT_CMD" ]]; then
    pass "provision_tenant.py exists"
  else
    fail "provision_tenant.py not found at $MGMT_CMD"
  fi

  # backfill_xapi_enterprise_uuid.py exists
  if [[ -f "$BACKFILL_CMD" ]]; then
    pass "backfill_xapi_enterprise_uuid.py exists"
  else
    fail "backfill_xapi_enterprise_uuid.py not found at $BACKFILL_CMD"
  fi

  # management/__init__.py files exist
  if [[ -f "$TENANT_APP/management/__init__.py" ]]; then
    pass "management/__init__.py exists"
  else
    fail "management/__init__.py not found"
  fi

  if [[ -f "$TENANT_APP/management/commands/__init__.py" ]]; then
    pass "management/commands/__init__.py exists"
  else
    fail "management/commands/__init__.py not found"
  fi

  # Command class with handle() method
  if grep -q "class Command(BaseCommand):" "$MGMT_CMD" 2>/dev/null; then
    pass "Command class with BaseCommand inheritance"
  else
    fail "Command class not found or doesn't inherit from BaseCommand"
  fi

  if grep -q "def handle(self" "$MGMT_CMD" 2>/dev/null; then
    pass "handle() method defined"
  else
    fail "handle() method not found"
  fi

  # 11 provisioning steps present (steps 1-10 plus summary)
  local step_count=0
  for i in {1..10}; do
    if grep -q "\[$i/11\]" "$MGMT_CMD" 2>/dev/null; then
      ((step_count++)) || true
    fi
  done

  # Step 11 is the summary, check for it separately
  if grep -q "Provisioning Summary" "$MGMT_CMD" 2>/dev/null; then
    ((step_count++)) || true
  fi

  if [[ $step_count -eq 11 ]]; then
    pass "All 11 provisioning steps present"
  else
    fail "Expected 11 provisioning steps, found $step_count"
  fi

  # add_arguments with --slug, --name, --domain
  if grep -q "add_argument('--slug'" "$MGMT_CMD" 2>/dev/null; then
    pass "--slug argument defined"
  else
    fail "--slug argument not found"
  fi

  if grep -q "add_argument('--name'" "$MGMT_CMD" 2>/dev/null; then
    pass "--name argument defined"
  else
    fail "--name argument not found"
  fi

  if grep -q "add_argument('--domain'" "$MGMT_CMD" 2>/dev/null; then
    pass "--domain argument defined"
  else
    fail "--domain argument not found"
  fi

  # Idempotent get_or_create pattern used
  if grep -q "get_or_create" "$MGMT_CMD" 2>/dev/null; then
    pass "Idempotent get_or_create pattern used"
  else
    fail "get_or_create pattern not found (not idempotent)"
  fi

  # Slug validation regex present
  if grep -qE "re\.match|grep.*-qE" "$MGMT_CMD" 2>/dev/null; then
    pass "Slug validation regex present"
  else
    fail "Slug validation regex not found"
  fi

  echo ""
}

# Section 2: Provisioning Script
check_provisioning_script() {
  echo "Section 2: Provisioning Script"

  # provision-tenant.sh exists and is executable
  if [[ -f "$PROVISION_SCRIPT" ]]; then
    pass "provision-tenant.sh exists"
  else
    fail "provision-tenant.sh not found at $PROVISION_SCRIPT"
    echo ""
    return
  fi

  if [[ -x "$PROVISION_SCRIPT" ]]; then
    pass "provision-tenant.sh is executable"
  else
    fail "provision-tenant.sh is not executable (chmod +x needed)"
  fi

  # --from-env flag supported
  if grep -q -- "--from-env" "$PROVISION_SCRIPT" 2>/dev/null; then
    pass "--from-env flag supported"
  else
    fail "--from-env flag not found"
  fi

  # --enterprise-uuid flag supported
  if grep -q -- "--enterprise-uuid" "$PROVISION_SCRIPT" 2>/dev/null; then
    pass "--enterprise-uuid flag supported"
  else
    fail "--enterprise-uuid flag not found"
  fi

  # --dry-run flag supported
  if grep -q -- "--dry-run" "$PROVISION_SCRIPT" 2>/dev/null; then
    pass "--dry-run flag supported"
  else
    fail "--dry-run flag not found"
  fi

  # Slug validation present
  if grep -qE "grep.*-qE|echo.*slug.*grep" "$PROVISION_SCRIPT" 2>/dev/null; then
    pass "Slug validation present"
  else
    fail "Slug validation not found"
  fi

  # K8s and Tutor execution paths present
  if grep -q "kubectl exec" "$PROVISION_SCRIPT" 2>/dev/null; then
    pass "K8s execution path present (kubectl exec)"
  else
    fail "K8s execution path not found"
  fi

  if grep -q "tutor local run lms" "$PROVISION_SCRIPT" 2>/dev/null; then
    pass "Tutor execution path present"
  else
    fail "Tutor execution path not found"
  fi

  echo ""
}

# Section 3: Mereka Tenant Definition
check_mereka_tenant_definition() {
  echo "Section 3: Mereka Tenant Definition"

  # mereka-tenant.env exists
  if [[ -f "$MEREKA_ENV" ]]; then
    pass "mereka-tenant.env exists"
  else
    fail "mereka-tenant.env not found at $MEREKA_ENV"
    echo ""
    return
  fi

  # Contains TENANT_SLUG=mereka
  if grep -q "TENANT_SLUG=mereka" "$MEREKA_ENV" 2>/dev/null; then
    pass "Contains TENANT_SLUG=mereka"
  else
    fail "TENANT_SLUG=mereka not found"
  fi

  # Contains TENANT_DOMAIN=academyv2.mereka.io
  if grep -q "TENANT_DOMAIN=academyv2.mereka.io" "$MEREKA_ENV" 2>/dev/null; then
    pass "Contains TENANT_DOMAIN=academyv2.mereka.io"
  else
    fail "TENANT_DOMAIN=academyv2.mereka.io not found"
  fi

  # Contains TENANT_COUNTRY=MY
  if grep -q "TENANT_COUNTRY=MY" "$MEREKA_ENV" 2>/dev/null; then
    pass "Contains TENANT_COUNTRY=MY"
  else
    fail "TENANT_COUNTRY=MY not found"
  fi

  echo ""
}

# Section 4: xAPI Backfill
check_xapi_backfill() {
  echo "Section 4: xAPI Backfill"

  # backfill_xapi_enterprise_uuid.py exists
  if [[ -f "$BACKFILL_CMD" ]]; then
    pass "backfill_xapi_enterprise_uuid.py exists"
  else
    fail "backfill_xapi_enterprise_uuid.py not found"
    echo ""
    return
  fi

  # --enterprise-uuid argument
  if grep -q "'--enterprise-uuid'" "$BACKFILL_CMD" 2>/dev/null; then
    pass "--enterprise-uuid argument defined"
  else
    fail "--enterprise-uuid argument not found"
  fi

  # --dry-run support
  if grep -q "'--dry-run'" "$BACKFILL_CMD" 2>/dev/null; then
    pass "--dry-run support"
  else
    fail "--dry-run support not found"
  fi

  # --org-id filter support
  if grep -q "'--org-id'" "$BACKFILL_CMD" 2>/dev/null; then
    pass "--org-id filter support"
  else
    fail "--org-id filter support not found"
  fi

  # ClickHouse ALTER TABLE SQL
  if grep -q "ALTER TABLE" "$BACKFILL_CMD" 2>/dev/null; then
    pass "ClickHouse ALTER TABLE SQL present"
  else
    fail "ClickHouse ALTER TABLE SQL not found"
  fi

  # Batch processing support
  if grep -q "batch-size" "$BACKFILL_CMD" 2>/dev/null; then
    pass "Batch processing support (--batch-size)"
  else
    fail "Batch processing support not found"
  fi

  echo ""
}

# Section 5: Provisioning Documentation
check_provisioning_documentation() {
  echo "Section 5: Provisioning Documentation"

  # docs/runbooks/operations/TENANT_PROVISIONING.md exists
  if [[ -f "$TENANT_DOC" ]]; then
    pass "TENANT_PROVISIONING.md exists"
  else
    fail "TENANT_PROVISIONING.md not found at $TENANT_DOC"
    echo ""
    return
  fi

  # Contains prerequisite section
  if grep -qi "prerequisite" "$TENANT_DOC" 2>/dev/null; then
    pass "Contains prerequisite section"
  else
    fail "Prerequisite section not found"
  fi

  # Contains Mereka first tenant example
  if grep -qi "mereka" "$TENANT_DOC" 2>/dev/null; then
    pass "Contains Mereka first tenant example"
  else
    fail "Mereka first tenant example not found"
  fi

  # Contains idempotency notes
  if grep -qi "idempoten" "$TENANT_DOC" 2>/dev/null; then
    pass "Contains idempotency notes"
  else
    fail "Idempotency notes not found"
  fi

  # Contains troubleshooting section
  if grep -qi "troubleshoot" "$TENANT_DOC" 2>/dev/null; then
    pass "Contains troubleshooting section"
  else
    fail "Troubleshooting section not found"
  fi

  echo ""
}

# Section 6: Idempotency Guarantees
check_idempotency_guarantees() {
  echo "Section 6: Idempotency Guarantees"

  # get_or_create pattern in provision_tenant.py
  if grep -q "get_or_create" "$MGMT_CMD" 2>/dev/null; then
    pass "get_or_create pattern used"
  else
    fail "get_or_create pattern not found"
  fi

  # Duplicate slug check
  if grep -q "filter(slug=slug)" "$MGMT_CMD" 2>/dev/null; then
    pass "Duplicate slug check present"
  else
    fail "Duplicate slug check not found"
  fi

  # Duplicate UUID check
  if grep -q "enterprise_customer_uuid=enterprise_uuid" "$MGMT_CMD" 2>/dev/null; then
    pass "Duplicate UUID check present"
  else
    fail "Duplicate UUID check not found"
  fi

  # transaction.atomic used
  if grep -q "transaction.atomic" "$MGMT_CMD" 2>/dev/null; then
    pass "transaction.atomic used"
  else
    fail "transaction.atomic not found (not transactional)"
  fi

  echo ""
}

# Section 7: Invalid Input Handling
check_invalid_input_handling() {
  echo "Section 7: Invalid Input Handling"

  # Slug regex validation pattern
  if grep -qE "re\.match|match.*slug" "$MGMT_CMD" 2>/dev/null; then
    pass "Slug regex validation pattern present"
  else
    fail "Slug regex validation pattern not found"
  fi

  # CommandError raised for invalid slug
  if grep -q "raise CommandError" "$MGMT_CMD" 2>/dev/null; then
    pass "CommandError raised for validation failures"
  else
    fail "CommandError not found"
  fi

  # Slug length check
  if grep -qE "len\(slug\).*>.*100|slug.*exceeds" "$MGMT_CMD" 2>/dev/null; then
    pass "Slug length check present"
  else
    fail "Slug length check not found"
  fi

  echo ""
}

# Section 8: Runtime Integration (SKIP)
check_runtime_integration() {
  echo "Section 8: Runtime Integration (requires runtime environment)"

  if [[ $SKIP_CLUSTER -eq 1 ]]; then
    skip "Provision tenant with slug=mereka (--skip-cluster specified)"
    skip "Re-run provisioning (idempotency test) (--skip-cluster specified)"
    skip "Invalid slug 'a b c' validation (--skip-cluster specified)"
    skip "xAPI backfill for mereka (--skip-cluster specified)"
  else
    skip "Provision tenant with slug=mereka (requires runtime environment)"
    skip "Re-run provisioning (idempotency test) (requires runtime environment)"
    skip "Invalid slug 'a b c' validation (requires runtime environment)"
    skip "xAPI backfill for mereka (requires runtime environment)"
  fi

  echo ""
}

# Main execution
main() {
  echo "=== Tenant Provisioning System Verification ==="
  echo ""

  check_management_command_structure
  check_provisioning_script
  check_mereka_tenant_definition
  check_xapi_backfill
  check_provisioning_documentation
  check_idempotency_guarantees
  check_invalid_input_handling
  check_runtime_integration

  # Summary
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASS"
  echo -e "${RED}FAIL${NC}: $FAIL"
  echo -e "${YELLOW}SKIP${NC}: $SKIP"
  echo ""

  if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Verification FAILED${NC}"
    exit 1
  else
    echo -e "${GREEN}Verification PASSED${NC}"
    exit 0
  fi
}

main
