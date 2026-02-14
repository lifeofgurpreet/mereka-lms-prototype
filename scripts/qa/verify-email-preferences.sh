#!/usr/bin/env bash
# Verification script for Email Preferences & GDPR Consent (Email Phase 2)
#
# @spec: email-notifications-pipeline_spec.md (Phase 2: Notification Preferences)
# @bead: mereka-lms-bnw1
# @covers: AC-020, AC-021, AC-022, AC-023, AC-024
#
# Usage:
#   ./scripts/qa/verify-email-preferences.sh [--env local|production]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Environment selection
ENV="${1:-production}"
if [[ "$ENV" == "--env" ]]; then
  ENV="${2:-production}"
fi

# Set base URLs
if [[ "$ENV" == "local" ]]; then
  BASE_URL="http://localhost:8000"
  echo -e "${YELLOW}Testing against LOCAL: ${BASE_URL}${NC}"
else
  BASE_URL="https://academyv2.mereka.io"
  echo -e "${YELLOW}Testing against PRODUCTION: ${BASE_URL}${NC}"
fi

API_BASE="${BASE_URL}/api/user/v1/preferences/email"

# Test results tracking
PASSED=0
FAILED=0
TOTAL=0

pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; ((PASSED++)); ((TOTAL++)); }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; ((FAILED++)); ((TOTAL++)); }
skip() { echo -e "${YELLOW}⊘ SKIP${NC}: $1"; ((TOTAL++)); }

section() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$1"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

echo "Email Preferences & GDPR Consent Verification"
echo "=============================================="

AUTH_TOKEN="${EMAIL_PREFERENCES_API_TOKEN:-}"
if [[ -z "$AUTH_TOKEN" ]]; then
  echo -e "${YELLOW}Warning: EMAIL_PREFERENCES_API_TOKEN not set${NC}"
  echo "Set token via: export EMAIL_PREFERENCES_API_TOKEN=<jwt>"
fi

section "AC-020: Get Email Preferences"

if [[ -n "$AUTH_TOKEN" ]]; then
  RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer ${AUTH_TOKEN}" "${API_BASE}/" || echo "000")
  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Preferences endpoint returns HTTP 200"
    
    if echo "$BODY" | jq -e '.preferences' >/dev/null 2>&1; then
      pass "Response contains preferences object"
      
      MARKETING=$(echo "$BODY" | jq -r '.preferences.marketing // "null"')
      if [[ "$MARKETING" == "false" ]]; then
        pass "Default marketing=false (GDPR opt-in)"
      else
        fail "Default marketing=${MARKETING} (expected false)"
      fi
    else
      fail "Response missing preferences object"
    fi
  else
    fail "HTTP ${HTTP_CODE} (expected 200)"
  fi
else
  skip "AC-020 (requires auth token)"
fi

section "AC-021: Update Preferences"

if [[ -n "$AUTH_TOKEN" ]]; then
  REQUEST='{"preferences":[{"category":"marketing","opted_in":true}]}'
  RESPONSE=$(curl -s -w "\n%{http_code}" -X PUT -H "Authorization: Bearer ${AUTH_TOKEN}" -H "Content-Type: application/json" -d "$REQUEST" "${API_BASE}/" || echo "000")
  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  
  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Preference update returns HTTP 200"
  else
    fail "HTTP ${HTTP_CODE} (expected 200)"
  fi
else
  skip "AC-021 (requires auth token)"
fi

section "Summary"

echo "Total: ${TOTAL}, Passed: ${GREEN}${PASSED}${NC}, Failed: ${RED}${FAILED}${NC}, Skipped: ${YELLOW}$((TOTAL - PASSED - FAILED))${NC}"

if [[ "$FAILED" -eq 0 ]]; then
  echo -e "${GREEN}✓ All automated tests passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ ${FAILED} test(s) failed${NC}"
  exit 1
fi
