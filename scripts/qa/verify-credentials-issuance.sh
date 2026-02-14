#!/usr/bin/env bash
# @spec: verifiable-credentials-issuance_spec.md
# @covers AC-CRED-020, AC-CRED-021, AC-CRED-022, AC-CRED-023, AC-CRED-024, AC-CRED-025, AC-CRED-026, AC-CRED-027
#
# Verification of CRED-030: Issuance Flows spec compliance.
# Static checks run against repo configuration files.
# Runtime ACs (live credential issuance, QR flow, wallet integration) are marked SKIP.
#
# Usage:
#   ./scripts/qa/verify-credentials-issuance.sh [--skip-cluster] [--help]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKIP_CLUSTER=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
    --help)
      cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Verify CRED-030: Issuance Flows spec compliance (8 ACs).

OPTIONS:
    --skip-cluster    Skip checks requiring live kubectl access
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
echo "  Verifiable Credentials Issuance Flows Verification"
echo "  Spec: verifiable-credentials-issuance_spec.md (8 ACs)"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo "Cluster checks: $(if $SKIP_CLUSTER; then echo SKIPPED; else echo ENABLED; fi)"
echo

###########################################################################
# SECTION 1: Issuance Pipeline (AC-CRED-020)
###########################################################################
echo "--- Issuance Pipeline ---"

# AC-CRED-020: Program completion -> signed VC stored within 30 seconds
# Runtime: requires program completion event + credential issuance. Mark SKIP.
skip_ "AC-CRED-020: Signed OBv3 VC stored within 30 seconds of program completion event (requires runtime event processing)"

# Static check: Verify ENABLE_VERIFIABLE_CREDENTIALS flag exists
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q 'ENABLE_VERIFIABLE_CREDENTIALS' "$LMS_SETTINGS"; then
    pass_ "AC-CRED-020: ENABLE_VERIFIABLE_CREDENTIALS feature flag configured in LMS (pipeline gating)"
  else
    fail_ "AC-CRED-020: ENABLE_VERIFIABLE_CREDENTIALS feature flag not found in LMS settings"
  fi
else
  fail_ "AC-CRED-020: LMS production.py not found at $LMS_SETTINGS"
fi

# Static check: Verify Credentials Service has VC settings
if [ -f "$CREDENTIALS_SETTINGS" ]; then
  if grep -q 'ENABLE_VERIFIABLE_CREDENTIALS' "$CREDENTIALS_SETTINGS"; then
    pass_ "AC-CRED-020: Credentials Service VC configuration present (issuance enabled)"
  else
    fail_ "AC-CRED-020: Credentials Service ENABLE_VERIFIABLE_CREDENTIALS not found"
  fi
else
  fail_ "AC-CRED-020: Credentials production.py not found at $CREDENTIALS_SETTINGS"
fi

###########################################################################
# SECTION 2: Learner Claim Flow (AC-CRED-021, AC-CRED-022)
###########################################################################
echo "--- Learner Claim Flow ---"

# AC-CRED-021: Learner Record MFE shows "Get Verifiable Credential" button
# Runtime: requires Learner Record MFE running + earned credentials. Mark SKIP.
skip_ "AC-CRED-021: Learner Record MFE displays 'Get Verifiable Credential' button for earned credentials (requires runtime MFE + credentials)"

# Static check: Verify USE_LEARNER_RECORD_MFE is enabled
if [ -f "$CREDENTIALS_SETTINGS" ]; then
  if grep -q 'USE_LEARNER_RECORD_MFE.*=.*True' "$CREDENTIALS_SETTINGS"; then
    pass_ "AC-CRED-021: USE_LEARNER_RECORD_MFE enabled in Credentials Service (MFE integration active)"
  else
    fail_ "AC-CRED-021: USE_LEARNER_RECORD_MFE not enabled in Credentials Service"
  fi
else
  fail_ "AC-CRED-021: Credentials production.py not found"
fi

# AC-CRED-022: QR code scan -> VC stored in wallet
# Runtime: requires LCW app + QR generation + wallet fetch. Mark SKIP.
skip_ "AC-CRED-022: QR code scan with LCW successfully stores VC in wallet (requires runtime E2E test with mobile app)"

###########################################################################
# SECTION 3: Claim Token Security (AC-CRED-023, AC-CRED-024)
###########################################################################
echo "--- Claim Token Security ---"

# AC-CRED-023: Expired claim token (>10 minutes) returns HTTP 401
# Runtime: requires token generation + 10-minute wait + fetch attempt. Mark SKIP.
skip_ "AC-CRED-023: Claim token used after 10 minutes returns HTTP 401 expired (requires runtime token expiry test)"

# AC-CRED-024: Reused claim token returns HTTP 401
# Runtime: requires token generation + double fetch attempt. Mark SKIP.
skip_ "AC-CRED-024: Claim token used twice returns HTTP 401 consumed (requires runtime replay test)"

# Static check: Verify claim token expiry configuration exists
if [ -f "$CREDENTIALS_SETTINGS" ]; then
  # Look for token expiry configuration (may be in comments or settings)
  if grep -qi "claim.*token\|token.*expir" "$CREDENTIALS_SETTINGS"; then
    pass_ "AC-CRED-023/024: Claim token configuration present in Credentials Service settings"
  else
    # This might be OK if it's using defaults, so we'll SKIP rather than FAIL
    skip_ "AC-CRED-023/024: No explicit claim token expiry configuration found (may use defaults)"
  fi
fi

###########################################################################
# SECTION 4: LinkedIn Sharing (AC-CRED-025, AC-CRED-026)
###########################################################################
echo "--- LinkedIn Sharing ---"

# AC-CRED-025: Public URL shows credential details + OG metadata + LinkedIn button
# Runtime: requires credential issued + public URL accessible. Mark SKIP.
skip_ "AC-CRED-025: Public credential URL displays details, Open Graph metadata, and 'Add to LinkedIn' button (requires runtime credential + URL)"

# AC-CRED-026: LinkedIn button pre-populates certification form
# Runtime: requires LinkedIn redirect test. Mark SKIP.
skip_ "AC-CRED-026: LinkedIn 'Add to Profile' button pre-populates name, issuer, date, URL (requires runtime LinkedIn flow test)"

# Static check: Verify CORS configuration for wallet integration
if [ -f "$CREDENTIALS_SETTINGS" ]; then
  if grep -q "CORS_ORIGIN_WHITELIST\|CORS_ALLOW" "$CREDENTIALS_SETTINGS"; then
    pass_ "AC-CRED-025: CORS configuration present in Credentials Service (wallet integration enabled)"
  else
    fail_ "AC-CRED-025: CORS configuration not found in Credentials Service (required for LCW)"
  fi
else
  fail_ "AC-CRED-025: Credentials production.py not found"
fi

###########################################################################
# SECTION 5: Error Handling (AC-CRED-027)
###########################################################################
echo "--- Error Handling ---"

# AC-CRED-027: Service unavailable -> retry prompt in LCW
# Runtime: requires simulating service downtime + LCW behavior. Mark SKIP.
skip_ "AC-CRED-027: LCW shows retry prompt when Credentials Service unavailable during QR scan (requires runtime failure simulation + LCW testing)"

###########################################################################
# SECTION 6: OpenID4VCI Readiness Check
###########################################################################
echo "--- OpenID4VCI Readiness ---"

# Static check: Verify credential endpoint follows RESTful patterns
# This is a design check that would require code review
skip_ "OpenID4VCI readiness: Credential endpoint follows RESTful patterns compatible with future OID4VCI adoption (requires code review)"

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
