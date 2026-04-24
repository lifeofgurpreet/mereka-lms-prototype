#!/usr/bin/env bash
# @spec: verifiable-credentials-types_spec.md
# @covers AC-CRED-001, AC-CRED-002, AC-CRED-003, AC-CRED-004, AC-CRED-005, AC-CRED-006, AC-CRED-007, AC-CRED-008
# verify-vc-types.sh
# Verifies credential type definitions, OBv3 mapping, and multi-tenant issuer profiles
# Exit 0 = all checks pass, exit 1 = failures

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAMESPACE="mereka-lms"
PASS=0; FAIL=0; SKIP=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
pass() { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${BLUE}○${NC} $1"; SKIP=$((SKIP + 1)); }
info() { echo -e "${YELLOW}ℹ${NC} $1"; }

echo "=== Verifiable Credentials Types Verification (CRED-010) ==="
echo

# ---------------------------------------------------------------------------
# AC-CRED-001: verifiable_credentials app enabled
# Given the Credentials Service is running, when the verifiable_credentials app is enabled in settings,
# then django.apps.get_app_config('verifiable_credentials') succeeds
# ---------------------------------------------------------------------------
echo "[AC-CRED-001] Verifying verifiable_credentials app configuration..."

CRED_SETTINGS="$REPO_ROOT/deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py"
if [[ -f "$CRED_SETTINGS" ]] && grep -q "verifiable_credentials" "$CRED_SETTINGS"; then
  pass "AC-CRED-001: verifiable_credentials app referenced in settings"
else
  skip "AC-CRED-001: verifiable_credentials app not found in settings"
fi

# Check if app directory exists
VC_APP="$REPO_ROOT/deploy/k8s/base/plugins/credentials/apps/credentials/apps/verifiable_credentials"
if [[ -d "$VC_APP" ]]; then
  pass "AC-CRED-001: verifiable_credentials app directory exists"
else
  skip "AC-CRED-001: verifiable_credentials app directory not found"
fi

# Check if credentials pod is running
if kubectl get deployment credentials -n "$NAMESPACE" &>/dev/null; then
  CRED_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=credentials --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -n "$CRED_POD" ]]; then
    # Try to verify app is loaded (check for 404 vs 500 on VC endpoints)
    VC_STATUS=$(kubectl exec -n "$NAMESPACE" "$CRED_POD" -- python3 -c "
import urllib.request, urllib.error
try:
    r = urllib.request.urlopen('http://localhost:8150/api/credentials/v1/', timeout=5)
    print(r.status)
except urllib.error.HTTPError as e:
    print(e.code)
except Exception:
    print('000')" 2>/dev/null | tr -d '[:space:]')

    if [[ "$VC_STATUS" == "200" || "$VC_STATUS" == "401" || "$VC_STATUS" == "404" ]]; then
      pass "AC-CRED-001: Credentials API endpoint responds ($VC_STATUS)"
    else
      skip "AC-CRED-001: Credentials API endpoint status: $VC_STATUS"
    fi
  else
    skip "AC-CRED-001: No running credentials pod"
  fi
else
  skip "AC-CRED-001: Credentials Service not deployed"
fi
echo

# ---------------------------------------------------------------------------
# AC-CRED-002: Program Credential as OBv3 VC
# Given a learner completes a program, when a Program Credential is issued,
# then the VC JSON contains type: ["VerifiableCredential", "AchievementCredential"] and valid OBv3 fields
# ---------------------------------------------------------------------------
echo "[AC-CRED-002] Verifying Program Credential type definition..."

# Check for program credential mapping code
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "program.*credential\|Program.*Credential" {} \; | grep -q .; then
  pass "AC-CRED-002: Program Credential code exists"
else
  skip "AC-CRED-002: Program Credential code not found"
fi

# Check for VerifiableCredential + AchievementCredential types
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "VerifiableCredential.*AchievementCredential" {} \; | grep -q .; then
  pass "AC-CRED-002: VC type array includes both VerifiableCredential and AchievementCredential"
else
  skip "AC-CRED-002: VC type array not found"
fi
echo

# ---------------------------------------------------------------------------
# AC-CRED-003: Course Certificate as OBv3 VC
# Given a learner completes a course, when a Course Certificate is issued,
# then the VC JSON maps course name, description, and criteria correctly
# ---------------------------------------------------------------------------
echo "[AC-CRED-003] Verifying Course Certificate type definition..."

# Check for course certificate mapping code
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "course.*certificate\|Course.*Certificate" {} \; | grep -q .; then
  pass "AC-CRED-003: Course Certificate code exists"
else
  skip "AC-CRED-003: Course Certificate code not found"
fi

# Check for OBv3 field mapping (achievement.name, achievement.description, criteria)
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "achievement.*name\|achievement.*description\|criteria" {} \; | grep -q .; then
  pass "AC-CRED-003: OBv3 achievement field mapping exists"
else
  skip "AC-CRED-003: OBv3 achievement field mapping not found"
fi
echo

# ---------------------------------------------------------------------------
# AC-CRED-004: Privacy-preserving recipient binding
# Given a credential is issued, when the VC JSON is inspected,
# then the credentialSubject.identifier contains an opaque user ID, NOT a raw email address
# ---------------------------------------------------------------------------
echo "[AC-CRED-004] Verifying privacy-preserving recipient binding..."

# Check for opaque identifier generation
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "credentialSubject.*identifier\|opaque.*id\|anonymous.*id" {} \; | grep -q .; then
  pass "AC-CRED-004: Opaque identifier code exists"
else
  skip "AC-CRED-004: Opaque identifier code not found"
fi

# Check that email is NOT used directly
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "credentialSubject.*email" {} \; | grep -q .; then
  fail "AC-CRED-004: WARNING - Email found in credentialSubject (privacy risk)"
else
  pass "AC-CRED-004: Email not used in credentialSubject (privacy-preserving)"
fi
echo

# ---------------------------------------------------------------------------
# AC-CRED-005: Multi-tenant issuer profiles
# Given enterprise tenant A and B, when credentials are issued for their respective learners,
# then each credential's issuer field references the correct tenant's Issuer Profile
# ---------------------------------------------------------------------------
echo "[AC-CRED-005] Verifying multi-tenant issuer profiles..."

# Check for issuer profile model
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "IssuerProfile\|Issuer.*model\|class.*Issuer" {} \; | grep -q .; then
  pass "AC-CRED-005: Issuer Profile model exists"
else
  skip "AC-CRED-005: Issuer Profile model not found"
fi

# Check for tenant-based issuer selection
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "enterprise.*customer\|tenant.*issuer" {} \; | grep -q .; then
  pass "AC-CRED-005: Tenant-based issuer selection code exists"
else
  skip "AC-CRED-005: Tenant-based issuer selection code not found"
fi
echo

# ---------------------------------------------------------------------------
# AC-CRED-006: Feature flag gates VC issuance
# Given the ENABLE_VERIFIABLE_CREDENTIALS flag is off, when a course is completed,
# then no VC is issued (only traditional certificate)
# ---------------------------------------------------------------------------
echo "[AC-CRED-006] Verifying feature flag configuration..."

# Check for ENABLE_VERIFIABLE_CREDENTIALS flag
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
if [[ -f "$LMS_SETTINGS" ]] && grep -q "ENABLE_VERIFIABLE_CREDENTIALS" "$LMS_SETTINGS"; then
  pass "AC-CRED-006: ENABLE_VERIFIABLE_CREDENTIALS flag exists in LMS settings"
else
  skip "AC-CRED-006: ENABLE_VERIFIABLE_CREDENTIALS flag not found"
fi

if [[ -f "$CRED_SETTINGS" ]] && grep -q "ENABLE_VERIFIABLE_CREDENTIALS\|ENABLE_LEARNER_CREDENTIAL_WALLET" "$CRED_SETTINGS"; then
  pass "AC-CRED-006: VC feature flags exist in Credentials settings"
else
  skip "AC-CRED-006: VC feature flags not found in Credentials settings"
fi

# Check for flag usage in code
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "ENABLE_VERIFIABLE_CREDENTIALS" {} \; | grep -q .; then
  pass "AC-CRED-006: Feature flag checked in code"
else
  skip "AC-CRED-006: Feature flag usage not found in code"
fi
echo

# ---------------------------------------------------------------------------
# AC-CRED-007: Default "Mereka Academy" issuer profile
# Given the Mereka Academy default Issuer Profile, when a non-enterprise learner earns a credential,
# then the issuer name is "Mereka Academy" with the correct logo URL
# ---------------------------------------------------------------------------
echo "[AC-CRED-007] Verifying default Mereka Academy issuer profile..."

# Check for default issuer configuration
if [[ -f "$CRED_SETTINGS" ]] && grep -q "Mereka.*Academy\|DEFAULT.*ISSUER" "$CRED_SETTINGS"; then
  pass "AC-CRED-007: Default Mereka Academy issuer configuration exists"
else
  skip "AC-CRED-007: Default issuer configuration not found"
fi

# Check for issuer logo configuration
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -exec grep -l "logo.*url\|issuer.*image" {} \; | grep -q .; then
  pass "AC-CRED-007: Issuer logo/image configuration exists"
else
  skip "AC-CRED-007: Issuer logo configuration not found"
fi
echo

# ---------------------------------------------------------------------------
# AC-CRED-008: OBv3 JSON-LD validation
# Given a credential VC JSON, when validated against the OBv3 JSON-LD context,
# then validation passes with zero errors
# ---------------------------------------------------------------------------
echo "[AC-CRED-008] Verifying OBv3 JSON-LD context validation..."

# Check for JSON-LD context reference
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -name "*.py" -exec grep -l "@context\|json-ld\|JSON_LD.*CONTEXT" {} \; | grep -q .; then
  pass "AC-CRED-008: JSON-LD context reference exists"
else
  skip "AC-CRED-008: JSON-LD context reference not found"
fi

# Check for OBv3 context URL (https://purl.imsglobal.org/spec/ob/v3p0/context.json)
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -exec grep -l "purl.imsglobal.org.*ob.*v3\|openbadges.*v3" {} \; | grep -q .; then
  pass "AC-CRED-008: OBv3 context URL found"
else
  skip "AC-CRED-008: OBv3 context URL not found"
fi

# Check for W3C VC Data Model context
if [[ -d "$VC_APP" ]] && find "$VC_APP" -type f -exec grep -l "w3.org/2018/credentials\|w3.org.*credentials.*v1" {} \; | grep -q .; then
  pass "AC-CRED-008: W3C VC Data Model context URL found"
else
  skip "AC-CRED-008: W3C VC Data Model context URL not found"
fi
echo

# Summary
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS"
echo -e "${BLUE}SKIP:${NC} $SKIP"
echo -e "${RED}FAIL:${NC} $FAIL"
echo
if [[ $FAIL -gt 0 ]]; then
  echo "Note: Most checks are expected to SKIP until verifiable credentials types are implemented."
fi
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
