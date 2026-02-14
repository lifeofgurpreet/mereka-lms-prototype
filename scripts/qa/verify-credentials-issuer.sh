#!/usr/bin/env bash
# Verification script for Verifiable Credentials Issuer Identity (CRED-020)
#
# @spec: verifiable-credentials-issuer_spec.md
# @covers: AC-CRED-010, AC-CRED-011, AC-CRED-012, AC-CRED-013, AC-CRED-014, AC-CRED-015
#
# Usage:
#   ./scripts/qa/verify-credentials-issuer.sh [--env local|production]
#
# Environment:
#   - local: Test against localhost (Docker Compose)
#   - production: Test against academyv2.mereka.io (default)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Environment selection
ENV="${1:-production}"
if [[ "$ENV" == "--env" ]]; then
  ENV="${2:-production}"
fi

# Set base URLs based on environment
if [[ "$ENV" == "local" ]]; then
  CREDENTIALS_URL="http://credentials.localhost:8002"
  echo -e "${YELLOW}Testing against LOCAL environment: ${CREDENTIALS_URL}${NC}"
else
  CREDENTIALS_URL="https://credentials.academyv2.mereka.io"
  echo -e "${YELLOW}Testing against PRODUCTION environment: ${CREDENTIALS_URL}${NC}"
fi

DID_DOCUMENT_URL="${CREDENTIALS_URL}/.well-known/did.json"

# Test results tracking
PASSED=0
FAILED=0
TOTAL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  ((PASSED++))
  ((TOTAL++))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  ((FAILED++))
  ((TOTAL++))
}

skip() {
  echo -e "${YELLOW}⊘ SKIP${NC}: $1"
  ((TOTAL++))
}

section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check prerequisites
command -v curl >/dev/null 2>&1 || { echo "curl is required but not installed"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed"; exit 1; }

echo "Verifiable Credentials Issuer Identity Verification"
echo "===================================================="
echo ""

###############################################################################
# AC-CRED-010: DID Document Endpoint
###############################################################################

section "AC-CRED-010: DID Document Endpoint"

echo "Fetching DID document from ${DID_DOCUMENT_URL}..."
DID_RESPONSE=$(curl -s -w "\n%{http_code}" "${DID_DOCUMENT_URL}" || echo "000")
HTTP_CODE=$(echo "$DID_RESPONSE" | tail -n 1)
DID_BODY=$(echo "$DID_RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" == "200" ]]; then
  pass "DID document endpoint returns HTTP 200"
else
  fail "DID document endpoint returns HTTP ${HTTP_CODE} (expected 200)"
  echo "Response: ${DID_BODY}"
fi

# Verify DID document structure
if echo "$DID_BODY" | jq -e '.id' >/dev/null 2>&1; then
  DID_ID=$(echo "$DID_BODY" | jq -r '.id')

  if [[ "$ENV" == "local" ]]; then
    EXPECTED_DID="did:web:credentials.localhost:8002"
  else
    EXPECTED_DID="did:web:credentials.academyv2.mereka.io"
  fi

  if [[ "$DID_ID" == "$EXPECTED_DID" ]]; then
    pass "DID document contains correct id: ${DID_ID}"
  else
    fail "DID document id mismatch: got '${DID_ID}', expected '${EXPECTED_DID}'"
  fi
else
  fail "DID document missing 'id' field"
fi

# Verify @context
if echo "$DID_BODY" | jq -e '.["@context"]' >/dev/null 2>&1; then
  CONTEXTS=$(echo "$DID_BODY" | jq -r '.["@context"] | join(",")')
  if echo "$CONTEXTS" | grep -q "https://www.w3.org/ns/did/v1"; then
    pass "DID document contains W3C DID v1 context"
  else
    fail "DID document missing W3C DID v1 context"
  fi

  if echo "$CONTEXTS" | grep -q "https://w3id.org/security/suites/ed25519-2020/v1"; then
    pass "DID document contains Ed25519-2020 suite context"
  else
    fail "DID document missing Ed25519-2020 suite context"
  fi
else
  fail "DID document missing '@context' field"
fi

# Verify verificationMethod
if echo "$DID_BODY" | jq -e '.verificationMethod' >/dev/null 2>&1; then
  VM_COUNT=$(echo "$DID_BODY" | jq '.verificationMethod | length')
  if [[ "$VM_COUNT" -ge 1 ]]; then
    pass "DID document contains ${VM_COUNT} verification method(s)"

    # Check first verification method structure
    VM=$(echo "$DID_BODY" | jq '.verificationMethod[0]')

    if echo "$VM" | jq -e '.id' >/dev/null 2>&1; then
      VM_ID=$(echo "$VM" | jq -r '.id')
      pass "Verification method has id: ${VM_ID}"
    else
      fail "Verification method missing 'id' field"
    fi

    if echo "$VM" | jq -e '.type' >/dev/null 2>&1; then
      VM_TYPE=$(echo "$VM" | jq -r '.type')
      if [[ "$VM_TYPE" == "Ed25519VerificationKey2020" ]]; then
        pass "Verification method type is Ed25519VerificationKey2020"
      else
        fail "Verification method type is '${VM_TYPE}' (expected Ed25519VerificationKey2020)"
      fi
    else
      fail "Verification method missing 'type' field"
    fi

    if echo "$VM" | jq -e '.controller' >/dev/null 2>&1; then
      VM_CONTROLLER=$(echo "$VM" | jq -r '.controller')
      if [[ "$VM_CONTROLLER" == "$DID_ID" ]]; then
        pass "Verification method controller matches DID: ${VM_CONTROLLER}"
      else
        fail "Verification method controller mismatch: got '${VM_CONTROLLER}', expected '${DID_ID}'"
      fi
    else
      fail "Verification method missing 'controller' field"
    fi

    if echo "$VM" | jq -e '.publicKeyBase64' >/dev/null 2>&1; then
      PUBLIC_KEY=$(echo "$VM" | jq -r '.publicKeyBase64')
      if [[ -n "$PUBLIC_KEY" ]] && [[ "$PUBLIC_KEY" != "null" ]]; then
        pass "Verification method contains publicKeyBase64"
      else
        fail "Verification method publicKeyBase64 is empty or null"
      fi
    else
      fail "Verification method missing 'publicKeyBase64' field"
    fi
  else
    fail "DID document has no verification methods"
  fi
else
  fail "DID document missing 'verificationMethod' field"
fi

# Verify assertionMethod
if echo "$DID_BODY" | jq -e '.assertionMethod' >/dev/null 2>&1; then
  AM_COUNT=$(echo "$DID_BODY" | jq '.assertionMethod | length')
  if [[ "$AM_COUNT" -ge 1 ]]; then
    pass "DID document contains ${AM_COUNT} assertion method(s)"
  else
    fail "DID document has no assertion methods"
  fi
else
  fail "DID document missing 'assertionMethod' field"
fi

###############################################################################
# AC-CRED-011: Proof Object in Issued VCs
###############################################################################

section "AC-CRED-011: Proof Object in Issued VCs"

echo "Note: This AC requires an actual VC issuance endpoint to test."
echo "Skipping automated verification (requires API implementation)."
echo ""
echo "Manual verification steps:"
echo "1. Issue a test VC via the Credentials Service API"
echo "2. Verify the VC contains a 'proof' object with:"
echo "   - 'type': Should match VERIFIABLE_CREDENTIALS.SIGNATURE_SUITE (Ed25519Signature2020)"
echo "   - 'created': ISO 8601 timestamp"
echo "   - 'verificationMethod': References the DID document key (e.g., ${DID_ID}#key-1)"
echo "   - 'proofPurpose': 'assertionMethod'"
echo "   - 'proofValue': Base64-encoded signature"

skip "AC-CRED-011: Proof object verification (requires VC issuance API)"

###############################################################################
# AC-CRED-012: K8s Secret Sync
###############################################################################

section "AC-CRED-012: K8s Secret Sync (ExternalSecrets)"

if [[ "$ENV" == "production" ]]; then
  echo "Checking K8s secret in mereka-lms namespace..."

  if command -v kubectl >/dev/null 2>&1; then
    if kubectl get secret openedx-secrets -n mereka-lms >/dev/null 2>&1; then
      pass "K8s secret 'openedx-secrets' exists in mereka-lms namespace"

      # Check if VC_SIGNING_PRIVATE_KEY is present
      if kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.VC_SIGNING_PRIVATE_KEY}' >/dev/null 2>&1; then
        VC_KEY_PRESENT=$(kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.VC_SIGNING_PRIVATE_KEY}' | wc -c)
        if [[ "$VC_KEY_PRESENT" -gt 0 ]]; then
          pass "VC_SIGNING_PRIVATE_KEY present in openedx-secrets"
        else
          fail "VC_SIGNING_PRIVATE_KEY is empty in openedx-secrets"
        fi
      else
        fail "VC_SIGNING_PRIVATE_KEY missing from openedx-secrets"
      fi

      # Verify ExternalSecret exists and is syncing
      if kubectl get externalsecret openedx-secrets -n mereka-lms >/dev/null 2>&1; then
        pass "ExternalSecret 'openedx-secrets' exists"

        ES_STATUS=$(kubectl get externalsecret openedx-secrets -n mereka-lms -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [[ "$ES_STATUS" == "True" ]]; then
          pass "ExternalSecret sync status: Ready"
        else
          fail "ExternalSecret sync status: Not Ready (${ES_STATUS})"
        fi
      else
        fail "ExternalSecret 'openedx-secrets' not found"
      fi
    else
      fail "K8s secret 'openedx-secrets' not found in mereka-lms namespace"
    fi
  else
    skip "kubectl not available, skipping K8s secret verification"
  fi
else
  skip "AC-CRED-012: K8s secret sync (only applicable in production)"
fi

###############################################################################
# AC-CRED-013: Key Rotation - Multiple Keys in DID Document
###############################################################################

section "AC-CRED-013: Key Rotation - Multiple Keys in DID Document"

echo "Note: Key rotation is a manual process."
echo "This AC can only be verified after a key rotation has been performed."
echo ""
echo "Current verification method count: ${VM_COUNT}"

if [[ "$VM_COUNT" -gt 1 ]]; then
  pass "DID document contains multiple verification methods (key rotation performed)"
else
  skip "AC-CRED-013: Key rotation verification (only ${VM_COUNT} key present, rotation not yet performed)"
  echo "To test key rotation:"
  echo "1. Follow docs/operations/credential-key-rotation-runbook.md"
  echo "2. Re-run this script to verify both old and new keys are present"
fi

###############################################################################
# AC-CRED-014: Old Key Verification After Rotation
###############################################################################

section "AC-CRED-014: Old Key Verification After Rotation"

echo "Note: This AC requires:"
echo "1. A key rotation to have been performed (AC-CRED-013)"
echo "2. A VC signed with the old key"
echo "3. A verifier implementation to test signature verification"
echo ""

if [[ "$VM_COUNT" -gt 1 ]]; then
  skip "AC-CRED-014: Old key verification (requires verifier implementation)"
  echo "Manual verification steps:"
  echo "1. Obtain a VC signed with the old key (issued before rotation)"
  echo "2. Extract the 'proof.verificationMethod' from the VC"
  echo "3. Resolve the verification method from the DID document"
  echo "4. Verify the VC signature using the old public key"
  echo "5. Verification should succeed"
else
  skip "AC-CRED-014: Old key verification (no key rotation performed yet)"
fi

###############################################################################
# AC-CRED-015: No credentialStatus in v1 VCs
###############################################################################

section "AC-CRED-015: No credentialStatus in v1 VCs"

echo "Note: This AC requires an actual VC issuance endpoint to test."
echo "Verification requires inspecting an issued VC JSON."
echo ""
echo "Manual verification steps:"
echo "1. Issue a test VC via the Credentials Service API"
echo "2. Verify the VC JSON does NOT contain a 'credentialStatus' field"
echo "3. This is expected in v1 (no revocation support)"

skip "AC-CRED-015: No credentialStatus field (requires VC issuance API)"

###############################################################################
# Cache Headers Verification
###############################################################################

section "Additional: Cache Headers"

echo "Checking Cache-Control headers on DID document..."
CACHE_HEADER=$(curl -s -I "${DID_DOCUMENT_URL}" | grep -i "cache-control" || echo "")

if [[ -n "$CACHE_HEADER" ]]; then
  echo "Cache-Control: ${CACHE_HEADER}"
  if echo "$CACHE_HEADER" | grep -qi "max-age"; then
    pass "DID document sets Cache-Control with max-age"
  else
    fail "DID document Cache-Control missing max-age directive"
  fi
else
  fail "DID document missing Cache-Control header"
fi

###############################################################################
# Summary
###############################################################################

section "Verification Summary"

echo "Total tests: ${TOTAL}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"
echo -e "Skipped: ${YELLOW}$((TOTAL - PASSED - FAILED))${NC}"
echo ""

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}✓ All automated tests passed!${NC}"
  echo ""
  echo "Note: Some ACs require manual verification (VC issuance API, key rotation)."
  echo "See skipped tests above for manual verification steps."
  exit 0
else
  echo -e "${RED}✗ ${FAILED} test(s) failed${NC}"
  echo ""
  echo "Review failures above and consult:"
  echo "- specs/verifiable-credentials-issuer_spec.md"
  echo "- docs/operations/credential-key-rotation-runbook.md"
  exit 1
fi
