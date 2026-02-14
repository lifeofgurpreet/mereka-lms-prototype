#!/usr/bin/env bash
# Verification script for Mux Video Upload (Video Phase 3: Studio Upload Workflow)
#
# @spec: video-pipeline-delivery_spec.md (Phase 3)
# @covers: AC-VPD-003
#
# Usage:
#   ./scripts/qa/verify-video-upload.sh [--env local|production]

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

API_BASE="${BASE_URL}/api/mux/upload"

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

echo "Mux Video Upload Verification (Phase 3)"
echo "========================================"

AUTH_TOKEN="${VIDEO_UPLOAD_API_TOKEN:-}"
if [[ -z "$AUTH_TOKEN" ]]; then
  echo -e "${YELLOW}Warning: VIDEO_UPLOAD_API_TOKEN not set${NC}"
  echo "Set token via: export VIDEO_UPLOAD_API_TOKEN=<jwt>"
fi

section "AC-VPD-003: Create Direct Upload URL"

if [[ -n "$AUTH_TOKEN" ]]; then
  # Test direct upload creation
  REQUEST='{
    "course_key": "course-v1:MerekaAcademy+QA101+2024",
    "filename": "test-video.mp4",
    "filesize_bytes": 1048576,
    "video_title": "QA Test Video"
  }'

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$REQUEST" \
    "${API_BASE}/create/" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Direct upload creation returns HTTP 200"

    # Verify response contains required fields
    if echo "$BODY" | jq -e '.upload_id' >/dev/null 2>&1; then
      pass "Response contains upload_id"
    else
      fail "Response missing upload_id"
    fi

    if echo "$BODY" | jq -e '.upload_url' >/dev/null 2>&1; then
      pass "Response contains upload_url"

      UPLOAD_URL=$(echo "$BODY" | jq -r '.upload_url')
      if [[ "$UPLOAD_URL" == https://storage.googleapis.com/* ]]; then
        pass "Upload URL is from Google Cloud Storage (Mux backend)"
      else
        fail "Upload URL format unexpected: $UPLOAD_URL"
      fi
    else
      fail "Response missing upload_url"
    fi

    if echo "$BODY" | jq -e '.timeout' >/dev/null 2>&1; then
      TIMEOUT=$(echo "$BODY" | jq -r '.timeout')
      if [[ "$TIMEOUT" -ge 86400 ]]; then
        pass "Upload URL timeout is >= 24 hours (actual: ${TIMEOUT}s)"
      else
        fail "Upload URL timeout too short: ${TIMEOUT}s (expected >= 86400s)"
      fi
    else
      fail "Response missing timeout"
    fi

    if echo "$BODY" | jq -e '.mux_upload_id' >/dev/null 2>&1; then
      pass "Response contains mux_upload_id (database record created)"

      # Store upload_id for status check
      UPLOAD_ID=$(echo "$BODY" | jq -r '.upload_id')

      # Test upload status endpoint
      sleep 1  # Brief delay
      STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        "${API_BASE}/${UPLOAD_ID}/status/" || echo "000")

      STATUS_HTTP_CODE=$(echo "$STATUS_RESPONSE" | tail -n 1)
      STATUS_BODY=$(echo "$STATUS_RESPONSE" | sed '$d')

      if [[ "$STATUS_HTTP_CODE" == "200" ]]; then
        pass "Upload status endpoint returns HTTP 200"

        if echo "$STATUS_BODY" | jq -e '.status' >/dev/null 2>&1; then
          STATUS=$(echo "$STATUS_BODY" | jq -r '.status')
          if [[ "$STATUS" == "pending" ]]; then
            pass "Upload status is 'pending' (as expected for new upload)"
          else
            echo -e "${YELLOW}INFO${NC}: Upload status is '$STATUS' (expected 'pending')"
          fi
        else
          fail "Status response missing 'status' field"
        fi
      else
        fail "Upload status endpoint HTTP ${STATUS_HTTP_CODE} (expected 200)"
      fi
    else
      fail "Response missing mux_upload_id"
    fi

  elif [[ "$HTTP_CODE" == "503" ]]; then
    echo -e "${YELLOW}INFO${NC}: Feature disabled (ENABLE_MUX_STUDIO_UPLOAD=false)"
    skip "Direct upload creation (feature flag disabled)"
  else
    fail "HTTP ${HTTP_CODE} (expected 200)"
    echo "Response: $BODY"
  fi
else
  skip "AC-VPD-003 (requires auth token)"
fi

section "Feature Flag Check"

# Verify feature flag exists in LMS settings
if [[ "$ENV" == "production" ]]; then
  echo -e "${YELLOW}INFO${NC}: Feature flag check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('ENABLE_MUX_STUDIO_UPLOAD:', settings.ENABLE_MUX_STUDIO_UPLOAD)\""
else
  # Local check via Docker
  if command -v tutor &> /dev/null; then
    FEATURE_FLAG=$(tutor local exec lms python manage.py lms shell -c \
      "from django.conf import settings; print(settings.ENABLE_MUX_STUDIO_UPLOAD)" 2>/dev/null || echo "UNKNOWN")

    if [[ "$FEATURE_FLAG" == "True" || "$FEATURE_FLAG" == "False" ]]; then
      pass "ENABLE_MUX_STUDIO_UPLOAD setting exists (value: $FEATURE_FLAG)"
    else
      echo -e "${YELLOW}INFO${NC}: Could not verify feature flag (tutor not running or setting not found)"
    fi
  fi
fi

section "Mux Credentials Check"

# Verify Mux credentials are set (non-empty)
if [[ "$ENV" == "production" ]]; then
  echo -e "${YELLOW}INFO${NC}: Mux credentials check requires K8s secret access"
  echo "Manual check: kubectl get secret mereka-lms-runtime-secrets -n mereka-lms -o json | jq '.data | keys | map(select(startswith(\"MUX_\")))'"
else
  # Local check
  if command -v tutor &> /dev/null; then
    MUX_TOKEN_ID=$(tutor local exec lms python manage.py lms shell -c \
      "from django.conf import settings; print('SET' if settings.MUX_TOKEN_ID else 'UNSET')" 2>/dev/null || echo "UNKNOWN")

    if [[ "$MUX_TOKEN_ID" == "SET" ]]; then
      pass "MUX_TOKEN_ID is configured"
    else
      fail "MUX_TOKEN_ID not configured (required for Mux API calls)"
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
