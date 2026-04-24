#!/usr/bin/env bash
# @covers AC-MTA-012, AC-MTA-013, AC-MTA-014
# @spec: multi-tenancy-architecture_spec.md
# Verify TenantResolutionMiddleware exists and is referenced in settings patches.
# AC-MTA-012, AC-MTA-013, AC-MTA-014: Tenant resolution from request hostname.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0

log_pass() { printf "PASS: %s\n" "$1"; }
log_fail() { printf "FAIL: %s\n" "$1"; FAILED=1; }

echo "=== Tenant Middleware Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

MIDDLEWARE_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/middleware.py"

# Check 1: middleware.py exists
if [ -f "$MIDDLEWARE_FILE" ]; then
  log_pass "middleware.py exists"
else
  log_fail "middleware.py not found"
  exit 1
fi

# Check 2: TenantResolutionMiddleware class defined
if grep -q "class TenantResolutionMiddleware" "$MIDDLEWARE_FILE"; then
  log_pass "TenantResolutionMiddleware class defined"
else
  log_fail "TenantResolutionMiddleware class not found"
fi

# Check 3: Sets request.tenant_uuid
if grep -q "request.tenant_uuid" "$MIDDLEWARE_FILE"; then
  log_pass "Sets request.tenant_uuid"
else
  log_fail "Does not set request.tenant_uuid"
fi

# Check 4: Sets X-Tenant-ID response header
if grep -q "X-Tenant-ID" "$MIDDLEWARE_FILE"; then
  log_pass "Sets X-Tenant-ID response header"
else
  log_fail "Does not set X-Tenant-ID response header"
fi

# Check 5: Resolves via Django Sites framework
if grep -q "django.contrib.sites.models" "$MIDDLEWARE_FILE"; then
  log_pass "Uses Django Sites framework for resolution"
else
  log_fail "Does not use Django Sites framework"
fi

# Check 6: Handles hostname prefix stripping (apps., studio., preview.)
if grep -q 'apps\.\|studio\.\|preview\.' "$MIDDLEWARE_FILE"; then
  log_pass "Handles hostname prefix stripping"
else
  log_fail "Does not handle hostname prefix stripping"
fi

# Check 7: Middleware is referenced in apply-patches.sh
PATCHES_FILE="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
if [ -f "$PATCHES_FILE" ] && grep -q "TenantResolutionMiddleware\|mereka_tenancy" "$PATCHES_FILE"; then
  log_pass "Middleware referenced in apply-patches.sh"
else
  log_fail "Middleware NOT referenced in apply-patches.sh (integration pending)"
fi

echo
if [ $FAILED -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
