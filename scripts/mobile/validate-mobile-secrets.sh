#!/usr/bin/env bash
set -euo pipefail
# @spec: proposals/mobile-apps-secrets-management_spec.md
# @covers: AC-001 AC-002 AC-003 AC-004 AC-005 AC-006

# This validator is not implemented. It MUST fail unless explicitly opted out.
# Exiting 0 without validation is a lie. Exiting 1 is honest.

echo "FAIL: mobile secrets validation is not implemented"
echo ""
echo "  Acceptance criteria NOT verified:"
echo "    AC-001: secret rotation policy"
echo "    AC-002: secret storage encryption"
echo "    AC-003: secret access audit trail"
echo "    AC-004: secret expiry enforcement"
echo "    AC-005: secret distribution security"
echo "    AC-006: secret revocation procedure"
echo ""

if [[ "${MOBILE_SECRETS_NOT_IMPLEMENTED_OK:-}" == "1" ]]; then
  echo "  MOBILE_SECRETS_NOT_IMPLEMENTED_OK=1 set — accepting this gap explicitly."
  exit 0
fi

echo "  Set MOBILE_SECRETS_NOT_IMPLEMENTED_OK=1 to explicitly accept this gap."
echo "  Do NOT set this in production CI without a tracking issue."
exit 1
