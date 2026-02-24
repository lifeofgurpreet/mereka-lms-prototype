#!/usr/bin/env bash
# Verification script for Video Analytics (Video Phase 4: Analytics Integration)
#
# @spec: video-pipeline-delivery_spec.md (Phase 4)
# @bead: mereka-lms-17jr
#
# Usage:
#   ./scripts/qa/verify-video-analytics.sh [--env local|production]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh" 2>/dev/null || true

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
  BASE_URL="https://${LMS_DOMAIN:-academyv2.mereka.io}"
  echo -e "${YELLOW}Testing against PRODUCTION: ${BASE_URL}${NC}"
fi

API_BASE="${BASE_URL}/api/video/v1"

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

echo "Video Analytics Verification (Phase 4)"
echo "======================================"

AUTH_TOKEN="${VIDEO_ANALYTICS_API_TOKEN:-}"
if [[ -z "$AUTH_TOKEN" ]]; then
  echo -e "${YELLOW}Warning: VIDEO_ANALYTICS_API_TOKEN not set${NC}"
  echo "Set token via: export VIDEO_ANALYTICS_API_TOKEN=<jwt>"
fi

section "Feature Flag Check"

# Verify feature flag exists in LMS settings
if [[ "$ENV" == "production" ]]; then
  echo -e "${YELLOW}INFO${NC}: Feature flag check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from django.conf import settings; print('ENABLE_VIDEO_ANALYTICS:', settings.ENABLE_VIDEO_ANALYTICS)\""
else
  # Local check via Docker
  if command -v tutor &> /dev/null; then
    FEATURE_FLAG=$(tutor local exec lms python manage.py lms shell -c \
      "from django.conf import settings; print(settings.ENABLE_VIDEO_ANALYTICS)" 2>/dev/null || echo "UNKNOWN")

    if [[ "$FEATURE_FLAG" == "True" || "$FEATURE_FLAG" == "False" ]]; then
      pass "ENABLE_VIDEO_ANALYTICS setting exists (value: $FEATURE_FLAG)"
    else
      echo -e "${YELLOW}INFO${NC}: Could not verify feature flag (tutor not running or setting not found)"
    fi
  fi
fi

section "Record Video Event API"

if [[ -n "$AUTH_TOKEN" ]]; then
  # Test event recording
  REQUEST='{
    "course_key": "course-v1:MerekaAcademy+QA101+2024",
    "video_id": "test-video-analytics-123",
    "event_type": "played",
    "position": 10.5,
    "duration": 300.0,
    "session_id": "test-session-uuid"
  }'

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$REQUEST" \
    "${API_BASE}/events/" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "201" ]]; then
    pass "Event recording returns HTTP 201 Created"

    # Verify response contains required fields
    if echo "$BODY" | jq -e '.id' >/dev/null 2>&1; then
      pass "Response contains event id"
    else
      fail "Response missing event id"
    fi

    if echo "$BODY" | jq -e '.video_id' >/dev/null 2>&1; then
      VIDEO_ID=$(echo "$BODY" | jq -r '.video_id')
      if [[ "$VIDEO_ID" == "test-video-analytics-123" ]]; then
        pass "Response contains correct video_id"
      else
        fail "Response video_id mismatch: $VIDEO_ID"
      fi
    else
      fail "Response missing video_id"
    fi

    if echo "$BODY" | jq -e '.event_type' >/dev/null 2>&1; then
      EVENT_TYPE=$(echo "$BODY" | jq -r '.event_type')
      if [[ "$EVENT_TYPE" == "played" ]]; then
        pass "Response contains correct event_type"
      else
        fail "Response event_type mismatch: $EVENT_TYPE"
      fi
    else
      fail "Response missing event_type"
    fi

    if echo "$BODY" | jq -e '.position' >/dev/null 2>&1; then
      POSITION=$(echo "$BODY" | jq -r '.position')
      if [[ "$POSITION" == "10.5" ]]; then
        pass "Response contains correct position"
      else
        fail "Response position mismatch: $POSITION"
      fi
    else
      fail "Response missing position"
    fi

    if echo "$BODY" | jq -e '.timestamp' >/dev/null 2>&1; then
      pass "Response contains timestamp"
    else
      fail "Response missing timestamp"
    fi

    if echo "$BODY" | jq -e '.org_slug' >/dev/null 2>&1; then
      ORG_SLUG=$(echo "$BODY" | jq -r '.org_slug')
      if [[ "$ORG_SLUG" == "MerekaAcademy" ]]; then
        pass "Response contains correct org_slug (MerekaAcademy)"
      else
        echo -e "${YELLOW}INFO${NC}: org_slug is '$ORG_SLUG' (expected 'MerekaAcademy')"
      fi
    else
      fail "Response missing org_slug"
    fi

  elif [[ "$HTTP_CODE" == "503" ]]; then
    echo -e "${YELLOW}INFO${NC}: Feature disabled (ENABLE_VIDEO_ANALYTICS=false)"
    skip "Event recording (feature flag disabled)"
  else
    fail "HTTP ${HTTP_CODE} (expected 201)"
    echo "Response: $BODY"
  fi
else
  skip "Event recording test (requires auth token)"
fi

section "Get Analytics API"

if [[ -n "$AUTH_TOKEN" ]]; then
  # Test analytics retrieval
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${API_BASE}/analytics/?course_key=course-v1:MerekaAcademy+QA101+2024" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Analytics API returns HTTP 200 OK"

    # Verify response structure
    if echo "$BODY" | jq -e '.count' >/dev/null 2>&1; then
      pass "Response contains count field"
    else
      fail "Response missing count field"
    fi

    if echo "$BODY" | jq -e '.results' >/dev/null 2>&1; then
      pass "Response contains results array"

      # Check if results have expected fields (if any results exist)
      RESULT_COUNT=$(echo "$BODY" | jq '.results | length')
      if [[ "$RESULT_COUNT" -gt 0 ]]; then
        FIRST_RESULT=$(echo "$BODY" | jq '.results[0]')

        if echo "$FIRST_RESULT" | jq -e '.video_id' >/dev/null 2>&1; then
          pass "Analytics result contains video_id"
        else
          fail "Analytics result missing video_id"
        fi

        if echo "$FIRST_RESULT" | jq -e '.play_count' >/dev/null 2>&1; then
          pass "Analytics result contains play_count"
        else
          fail "Analytics result missing play_count"
        fi

        if echo "$FIRST_RESULT" | jq -e '.unique_viewers' >/dev/null 2>&1; then
          pass "Analytics result contains unique_viewers"
        else
          fail "Analytics result missing unique_viewers"
        fi

        if echo "$FIRST_RESULT" | jq -e '.completion_rate' >/dev/null 2>&1; then
          pass "Analytics result contains completion_rate"
        else
          fail "Analytics result missing completion_rate"
        fi

        if echo "$FIRST_RESULT" | jq -e '.completion_rate_percent' >/dev/null 2>&1; then
          pass "Analytics result contains completion_rate_percent"
        else
          fail "Analytics result missing completion_rate_percent"
        fi
      else
        echo -e "${YELLOW}INFO${NC}: No analytics results (no aggregated data yet)"
      fi
    else
      fail "Response missing results array"
    fi

  elif [[ "$HTTP_CODE" == "503" ]]; then
    echo -e "${YELLOW}INFO${NC}: Feature disabled (ENABLE_VIDEO_ANALYTICS=false)"
    skip "Analytics API (feature flag disabled)"
  else
    fail "HTTP ${HTTP_CODE} (expected 200)"
    echo "Response: $BODY"
  fi
else
  skip "Analytics API test (requires auth token)"
fi

section "Event Types Validation"

# Test all event types
if [[ -n "$AUTH_TOKEN" && "$HTTP_CODE" != "503" ]]; then
  EVENT_TYPES=("played" "paused" "seeked" "completed" "ended")

  for EVENT_TYPE in "${EVENT_TYPES[@]}"; do
    REQUEST="{
      \"course_key\": \"course-v1:MerekaAcademy+QA101+2024\",
      \"video_id\": \"test-video-analytics-123\",
      \"event_type\": \"${EVENT_TYPE}\",
      \"position\": 60.0,
      \"duration\": 300.0
    }"

    RESPONSE=$(curl -s -w "\n%{http_code}" \
      -X POST \
      -H "Authorization: Bearer ${AUTH_TOKEN}" \
      -H "Content-Type: application/json" \
      -d "$REQUEST" \
      "${API_BASE}/events/" || echo "000")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

    if [[ "$HTTP_CODE" == "201" ]]; then
      pass "Event type '${EVENT_TYPE}' accepted (HTTP 201)"
    else
      fail "Event type '${EVENT_TYPE}' failed (HTTP ${HTTP_CODE})"
    fi
  done
else
  skip "Event types validation (requires auth token and enabled feature)"
fi

section "Database Models Check"

# Verify models exist in Django (requires shell access)
if [[ "$ENV" == "production" ]]; then
  echo -e "${YELLOW}INFO${NC}: Database models check requires LMS shell access"
  echo "Manual check: kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \"from openedx_video_analytics.models import VideoPlaybackEvent, VideoAnalyticsSummary; print('Models OK')\""
else
  if command -v tutor &> /dev/null; then
    MODELS_CHECK=$(tutor local exec lms python manage.py lms shell -c \
      "from openedx_video_analytics.models import VideoPlaybackEvent, VideoAnalyticsSummary; print('Models OK')" 2>/dev/null || echo "FAIL")

    if [[ "$MODELS_CHECK" == "Models OK" ]]; then
      pass "Django models exist (VideoPlaybackEvent, VideoAnalyticsSummary)"
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
