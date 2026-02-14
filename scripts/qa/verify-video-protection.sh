#!/usr/bin/env bash
# Verification script for Video Content Protection (Video Phase 5: Signed Playback)
#
# @spec: video-pipeline-delivery_spec.md (Phase 5)
# @bead: mereka-lms-2k9i
#
# Usage:
#   ./scripts/qa/verify-video-protection.sh [--env local|production]

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

API_BASE="${BASE_URL}/api/mux/protection"

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

echo "Video Content Protection Verification (Phase 5)"
echo "==============================================="

AUTH_TOKEN="${VIDEO_PROTECTION_API_TOKEN:-}"
if [[ -z "$AUTH_TOKEN" ]]; then
  echo -e "${YELLOW}Warning: VIDEO_PROTECTION_API_TOKEN not set${NC}"
  echo "Set token via: export VIDEO_PROTECTION_API_TOKEN=<jwt>"
fi

section "Feature Flag Check"

# Verify feature flag exists in LMS settings
if [[ "$ENV" == "production" ]]; then
  echo -e "${YELLOW}INFO${NC}: Feature flag check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('ENABLE_MUX_SIGNED_PLAYBACK:', settings.ENABLE_MUX_SIGNED_PLAYBACK)\""
else
  # Local check via Docker
  if command -v tutor &> /dev/null; then
    FEATURE_FLAG=$(tutor local exec lms python manage.py lms shell -c \
      "from django.conf import settings; print(settings.ENABLE_MUX_SIGNED_PLAYBACK)" 2>/dev/null || echo "UNKNOWN")

    if [[ "$FEATURE_FLAG" == "True" || "$FEATURE_FLAG" == "False" ]]; then
      pass "ENABLE_MUX_SIGNED_PLAYBACK setting exists (value: $FEATURE_FLAG)"
    else
      echo -e "${YELLOW}INFO${NC}: Could not verify feature flag (tutor not running or setting not found)"
    fi
  fi
fi

section "Generate Signed URL API (Enrolled User)"

if [[ -n "$AUTH_TOKEN" ]]; then
  # Test signed URL generation for enrolled user
  REQUEST='{
    "playback_id": "test-video-protection-123",
    "course_key": "course-v1:MerekaAcademy+QA101+2024",
    "expiry_hours": 12
  }'

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$REQUEST" \
    "${API_BASE}/signed-url/" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "201" ]]; then
    pass "Signed URL generation returns HTTP 201 Created"

    # Verify response contains required fields
    if echo "$BODY" | jq -e '.url' >/dev/null 2>&1; then
      URL=$(echo "$BODY" | jq -r '.url')
      if [[ "$URL" == https://stream.mux.com/* ]]; then
        pass "Response contains valid Mux URL"
      else
        fail "Response URL format incorrect: $URL"
      fi
    else
      fail "Response missing url field"
    fi

    if echo "$BODY" | jq -e '.expires_at' >/dev/null 2>&1; then
      pass "Response contains expires_at timestamp"
    else
      fail "Response missing expires_at field"
    fi

    if echo "$BODY" | jq -e '.playback_id' >/dev/null 2>&1; then
      PLAYBACK_ID=$(echo "$BODY" | jq -r '.playback_id')
      if [[ "$PLAYBACK_ID" == "test-video-protection-123" ]]; then
        pass "Response contains correct playback_id"
      else
        fail "Response playback_id mismatch: $PLAYBACK_ID"
      fi
    else
      fail "Response missing playback_id"
    fi

    # Check if URL contains token query parameter
    if echo "$URL" | grep -q "token="; then
      pass "Signed URL contains JWT token parameter"
    else
      fail "Signed URL missing token parameter"
    fi

  elif [[ "$HTTP_CODE" == "503" ]]; then
    echo -e "${YELLOW}INFO${NC}: Feature disabled (ENABLE_MUX_SIGNED_PLAYBACK=false)"
    skip "Signed URL generation (feature flag disabled)"
  elif [[ "$HTTP_CODE" == "403" ]]; then
    echo -e "${YELLOW}INFO${NC}: User not enrolled (expected for unenrolled test user)"
    skip "Signed URL generation (not enrolled in test course)"
  else
    fail "HTTP ${HTTP_CODE} (expected 201 or 503)"
    echo "Response: $BODY"
  fi
else
  skip "Signed URL generation test (requires auth token)"
fi

section "Check Video Access API"

if [[ -n "$AUTH_TOKEN" ]]; then
  # Test access check endpoint
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${API_BASE}/check-access/?course_key=course-v1:MerekaAcademy+QA101+2024" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Access check API returns HTTP 200 OK"

    # Verify response structure
    if echo "$BODY" | jq -e '.has_access' >/dev/null 2>&1; then
      pass "Response contains has_access field"
    else
      fail "Response missing has_access field"
    fi

    if echo "$BODY" | jq -e '.feature_enabled' >/dev/null 2>&1; then
      FEATURE_ENABLED=$(echo "$BODY" | jq -r '.feature_enabled')
      if [[ "$FEATURE_ENABLED" == "true" || "$FEATURE_ENABLED" == "false" ]]; then
        pass "Response contains valid feature_enabled field"
      else
        fail "Response feature_enabled has unexpected value: $FEATURE_ENABLED"
      fi
    else
      fail "Response missing feature_enabled field"
    fi

    if echo "$BODY" | jq -e '.enrollment_status' >/dev/null 2>&1; then
      ENROLLMENT_STATUS=$(echo "$BODY" | jq -r '.enrollment_status')
      if [[ "$ENROLLMENT_STATUS" == "enrolled" || "$ENROLLMENT_STATUS" == "not_enrolled" ]]; then
        pass "Response contains valid enrollment_status"
      else
        fail "Response enrollment_status has unexpected value: $ENROLLMENT_STATUS"
      fi
    else
      fail "Response missing enrollment_status field"
    fi

  else
    fail "HTTP ${HTTP_CODE} (expected 200)"
    echo "Response: $BODY"
  fi
else
  skip "Access check API test (requires auth token)"
fi

section "JWT Token Format Validation"

if [[ -n "$AUTH_TOKEN" && "$HTTP_CODE" == "201" ]]; then
  # Extract JWT token from signed URL
  if echo "$URL" | grep -q "token="; then
    JWT_TOKEN=$(echo "$URL" | sed -n 's/.*token=\([^&]*\).*/\1/p')

    # Check JWT structure (header.payload.signature)
    if [[ $(echo "$JWT_TOKEN" | tr -cd '.' | wc -c) -eq 2 ]]; then
      pass "JWT token has valid structure (3 parts)"
    else
      fail "JWT token structure invalid (expected 3 parts separated by dots)"
    fi

    # Decode JWT payload (base64url decode)
    PAYLOAD=$(echo "$JWT_TOKEN" | cut -d'.' -f2)
    # Add padding if needed
    PADDING=$(( (4 - ${#PAYLOAD} % 4) % 4 ))
    PADDED_PAYLOAD="${PAYLOAD}$(printf '%*s' $PADDING | tr ' ' '=')"
    # Decode (handle both + and - variants)
    DECODED=$(echo "$PADDED_PAYLOAD" | tr '_-' '/+' | base64 -d 2>/dev/null || echo "{}")

    # Check for required JWT claims
    if echo "$DECODED" | jq -e '.sub' >/dev/null 2>&1; then
      pass "JWT contains 'sub' claim (playback ID)"
    else
      fail "JWT missing 'sub' claim"
    fi

    if echo "$DECODED" | jq -e '.kid' >/dev/null 2>&1; then
      pass "JWT contains 'kid' claim (signing key ID)"
    else
      fail "JWT missing 'kid' claim"
    fi

    if echo "$DECODED" | jq -e '.exp' >/dev/null 2>&1; then
      EXP=$(echo "$DECODED" | jq -r '.exp')
      CURRENT_TIME=$(date +%s)
      if [[ "$EXP" -gt "$CURRENT_TIME" ]]; then
        pass "JWT expiry is in the future (valid)"
      else
        fail "JWT expiry is in the past (already expired)"
      fi
    else
      fail "JWT missing 'exp' claim"
    fi

    if echo "$DECODED" | jq -e '.aud' >/dev/null 2>&1; then
      pass "JWT contains 'aud' claim (audience/domain restriction)"
    else
      echo -e "${YELLOW}INFO${NC}: JWT missing 'aud' claim (domain restriction not set)"
    fi

  else
    skip "JWT validation (no token in URL)"
  fi
else
  skip "JWT validation (requires successful signed URL generation)"
fi

section "Enrollment Verification (Unenrolled User)"

# Note: This test requires a separate auth token for an unenrolled user
UNENROLLED_TOKEN="${VIDEO_PROTECTION_UNENROLLED_TOKEN:-}"
if [[ -n "$UNENROLLED_TOKEN" ]]; then
  REQUEST='{
    "playback_id": "test-video-protection-123",
    "course_key": "course-v1:MerekaAcademy+QA101+2024",
    "expiry_hours": 12
  }'

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${UNENROLLED_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$REQUEST" \
    "${API_BASE}/signed-url/" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "403" ]]; then
    pass "Unenrolled user receives HTTP 403 Forbidden"

    if echo "$BODY" | jq -e '.error' >/dev/null 2>&1; then
      ERROR_MSG=$(echo "$BODY" | jq -r '.error')
      if echo "$ERROR_MSG" | grep -qi "enroll"; then
        pass "Error message mentions enrollment requirement"
      else
        echo -e "${YELLOW}INFO${NC}: Error message: $ERROR_MSG"
      fi
    fi
  else
    fail "Unenrolled user received HTTP ${HTTP_CODE} (expected 403)"
    echo "Response: $BODY"
  fi
else
  skip "Unenrolled user test (requires VIDEO_PROTECTION_UNENROLLED_TOKEN)"
fi

section "Rate Limiting Test"

if [[ -n "$AUTH_TOKEN" && "$ENABLE_RATE_LIMIT_TEST" == "true" ]]; then
  echo -e "${YELLOW}INFO${NC}: Rate limit test (100 requests) - this will take ~30 seconds"

  RATE_LIMIT_REQUESTS=105  # Exceed limit of 100
  RATE_LIMITED=false

  for i in $(seq 1 $RATE_LIMIT_REQUESTS); do
    RESPONSE=$(curl -s -w "\n%{http_code}" \
      -X POST \
      -H "Authorization: Bearer ${AUTH_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$REQUEST" \
      "${API_BASE}/signed-url/" || echo "000")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    if [[ "$HTTP_CODE" == "429" ]]; then
      RATE_LIMITED=true
      break
    fi

    # Progress indicator every 10 requests
    if [[ $((i % 10)) -eq 0 ]]; then
      echo -ne "\rRequests sent: $i/$RATE_LIMIT_REQUESTS"
    fi
  done
  echo ""  # Newline after progress

  if [[ "$RATE_LIMITED" == "true" ]]; then
    pass "Rate limiting enforced (received HTTP 429 after exceeding limit)"
  else
    fail "Rate limiting not enforced (expected HTTP 429 after 100 requests)"
  fi
else
  skip "Rate limiting test (set ENABLE_RATE_LIMIT_TEST=true to run)"
fi

section "Database Models Check"

# Verify models exist in Django (requires shell access)
if [[ "$ENV" == "production" ]]; then
  echo -e "${YELLOW}INFO${NC}: Database models check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from openedx_video_protection.models import SignedPlaybackToken, VideoAccessLog; print('Models OK')\""
else
  if command -v tutor &> /dev/null; then
    MODELS_CHECK=$(tutor local exec lms python manage.py lms shell -c \
      "from openedx_video_protection.models import SignedPlaybackToken, VideoAccessLog; print('Models OK')" 2>/dev/null || echo "FAIL")

    if [[ "$MODELS_CHECK" == "Models OK" ]]; then
      pass "Django models exist (SignedPlaybackToken, VideoAccessLog)"
    else
      echo -e "${YELLOW}INFO${NC}: Could not verify models (tutor not running)"
    fi
  fi
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
