#!/usr/bin/env bash
# @spec: verifiable-credentials-types_spec.md
# @covers AC-CRED-001, AC-CRED-002, AC-CRED-003, AC-CRED-004, AC-CRED-005, AC-CRED-006, AC-CRED-007, AC-CRED-008
#
# Verification of CRED-010: Credential Types & Mapping spec compliance.
# Static checks run against repo configuration files.
# Runtime ACs (live credential issuance, OBv3 validation) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-credentials-types.sh [--help]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify CRED-010: Credential Types & Mapping spec compliance (8 ACs).

OPTIONS:
    --help            Show this help message
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# Counters
PASS=0
FAIL=0
SKIP=0

pass_() { PASS=$((PASS + 1)); printf "PASS: %s\n" "$1"; }
fail_() { FAIL=$((FAIL + 1)); printf "FAIL: %s\n" "$1"; }
skip_() { SKIP=$((SKIP + 1)); printf "SKIP: %s\n" "$1"; }

# Key file paths
CREDENTIALS_SETTINGS="$REPO_ROOT/deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py"
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

echo "========================================================"
echo "  Verifiable Credentials Types & Mapping Verification"
echo "  Spec: verifiable-credentials-types_spec.md (8 ACs)"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo

###########################################################################
# SECTION 1: App Configuration (AC-CRED-001)
###########################################################################
echo "--- App Configuration ---"

# AC-CRED-001: verifiable_credentials app is enabled
if [ -f "$CREDENTIALS_SETTINGS" ]; then
  if grep -q 'ENABLE_VERIFIABLE_CREDENTIALS = True' "$CREDENTIALS_SETTINGS"; then
    pass_ "AC-CRED-001: verifiable_credentials app enabled in Credentials Service settings"
  else
    fail_ "AC-CRED-001: ENABLE_VERIFIABLE_CREDENTIALS not set to True in Credentials settings"
  fi
else
  fail_ "AC-CRED-001: Credentials production.py not found at $CREDENTIALS_SETTINGS"
fi

###########################################################################
# SECTION 2: Credential Type Mapping (AC-CRED-002, AC-CRED-003)
###########################################################################
echo "--- Credential Type Mapping ---"

# AC-CRED-002: Program Credential contains correct VC type
# Runtime: requires program completion and credential issuance. Mark SKIP.
skip_ "AC-CRED-002: Program Credential VC JSON contains type: [\"VerifiableCredential\", \"AchievementCredential\"] (requires runtime issuance)"

# AC-CRED-003: Course Certificate maps course data correctly
# Runtime: requires course completion and credential issuance. Mark SKIP.
skip_ "AC-CRED-003: Course Certificate VC JSON maps course name, description, and criteria (requires runtime issuance)"

###########################################################################
# SECTION 3: Recipient Binding (AC-CRED-004)
###########################################################################
echo "--- Recipient Binding ---"

# AC-CRED-004: credentialSubject.identifier uses opaque user ID, not email
# Runtime: requires credential inspection. Mark SKIP.
skip_ "AC-CRED-004: credentialSubject.identifier contains opaque user ID, not raw email (requires runtime issuance)"

###########################################################################
# SECTION 4: Multi-Tenant Branding (AC-CRED-005, AC-CRED-007)
###########################################################################
echo "--- Multi-Tenant Branding ---"

# AC-CRED-005: Tenant-specific Issuer Profiles
# Runtime: requires tenant setup + credential issuance. Mark SKIP.
skip_ "AC-CRED-005: Credentials from tenant A and B use correct respective Issuer Profiles (requires runtime issuance)"

# AC-CRED-007: Default Mereka Academy Issuer Profile
# Runtime: requires non-enterprise learner credential issuance. Mark SKIP.
skip_ "AC-CRED-007: Non-enterprise learner credential uses \"Mereka Academy\" issuer with correct logo (requires runtime issuance)"

###########################################################################
# SECTION 5: Feature Flags (AC-CRED-006)
###########################################################################
echo "--- Feature Flags ---"

# AC-CRED-006: ENABLE_VERIFIABLE_CREDENTIALS flag gates VC issuance
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q 'FEATURES\["ENABLE_VERIFIABLE_CREDENTIALS"\]' "$LMS_SETTINGS" || \
     grep -q 'ENABLE_VERIFIABLE_CREDENTIALS' "$LMS_SETTINGS"; then
    pass_ "AC-CRED-006: ENABLE_VERIFIABLE_CREDENTIALS feature flag configured in LMS settings"
  else
    fail_ "AC-CRED-006: ENABLE_VERIFIABLE_CREDENTIALS feature flag not found in LMS settings"
  fi

  if grep -q 'FEATURES\["ENABLE_LEARNER_CREDENTIAL_WALLET"\]' "$LMS_SETTINGS" || \
     grep -q 'ENABLE_LEARNER_CREDENTIAL_WALLET' "$LMS_SETTINGS"; then
    pass_ "AC-CRED-006: ENABLE_LEARNER_CREDENTIAL_WALLET feature flag configured in LMS settings"
  else
    fail_ "AC-CRED-006: ENABLE_LEARNER_CREDENTIAL_WALLET feature flag not found in LMS settings"
  fi
else
  fail_ "AC-CRED-006: LMS production.py not found at $LMS_SETTINGS"
fi

###########################################################################
# SECTION 6: OBv3 Validation (AC-CRED-008)
###########################################################################
echo "--- OBv3 Validation ---"

# AC-CRED-008: VC JSON validates against OBv3 JSON-LD context
# Runtime: requires credential issuance + JSON-LD validator. Mark SKIP.
skip_ "AC-CRED-008: Credential VC JSON validates against OBv3 JSON-LD context (requires runtime issuance + validator)"

###########################################################################
# Summary
###########################################################################
echo
echo "========================================================"
echo "  Summary"
echo "========================================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo "SKIP: $SKIP"
echo "TOTAL: $((PASS + FAIL + SKIP))"
echo

if [ "$FAIL" -gt 0 ]; then
  echo "❌ Verification FAILED with $FAIL failed check(s)"
  exit 1
else
  echo "✅ Verification PASSED (static checks complete; $SKIP runtime checks skipped)"
  exit 0
fi
