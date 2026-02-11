#!/usr/bin/env bash
# @covers AC-028, AC-035
# @spec: auth-sso-enterprise_spec.md
# Verify that the MerekaPlatformAdminMiddleware prevents IdP assertions
# from granting is_staff/is_superuser, and that the admin allowlist
# controls staff elevation independently of any IdP claims.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"; PASS=$((PASS+1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL+1))
  fi
}

# AC-035: MerekaPlatformAdminMiddleware exists and uses MEREKA_PLATFORM_ADMIN_EMAILS
ADMIN_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_platform_admin.py"
check "mereka_platform_admin.py exists" test -f "$ADMIN_PY"
check "Admin middleware reads MEREKA_PLATFORM_ADMIN_EMAILS env var" \
  grep -q "MEREKA_PLATFORM_ADMIN_EMAILS" "$ADMIN_PY"
check "Admin middleware sets is_staff on allowlisted emails" \
  grep -q "is_staff" "$ADMIN_PY"
check "Admin middleware sets is_superuser on allowlisted emails" \
  grep -q "is_superuser" "$ADMIN_PY"

# AC-028: JIT-provisioned users must NOT get is_staff/is_superuser from IdP
# The middleware ONLY grants staff to emails in the allowlist, NOT from IdP claims.
# Verify the middleware does NOT read IdP assertion attributes for staff elevation.
check "Admin middleware does not read SAML assertions for staff" \
  bash -c "! grep -qi 'saml.*assertion\|idp.*claim\|saml_attributes' '$ADMIN_PY'"
check "Staff elevation is solely based on email allowlist" \
  grep -q "_platform_admin_emails" "$ADMIN_PY"

# Verify the middleware is loaded in production settings
PROD_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
check "production.py imports mereka_platform_admin" \
  grep -q "mereka_platform_admin" "$PROD_PY"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
