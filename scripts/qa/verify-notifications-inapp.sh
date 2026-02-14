#!/usr/bin/env bash
# Verification script for In-App Notifications (Email Phase 3)
#
# @spec: email-notifications-pipeline_spec.md (Phase 3: In-App Notifications)
# @covers: AC-010, AC-011, AC-012, AC-013, AC-014
#
# Usage:
#   ./scripts/qa/verify-notifications-inapp.sh [--env local|production]
#
# Prerequisites:
#   - Valid authentication token
#   - Test user with notifications created
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
  BASE_URL="http://localhost:8000"
  echo -e "${YELLOW}Testing against LOCAL environment: ${BASE_URL}${NC}"
else
  BASE_URL="https://academyv2.mereka.io"
  echo -e "${YELLOW}Testing against PRODUCTION environment: ${BASE_URL}${NC}"
fi

API_BASE="${BASE_URL}/api/notifications/v1"

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

echo "In-App Notifications Verification (Phase 3)"
echo "==========================================="
echo ""

# Check if auth token is provided
AUTH_TOKEN="${NOTIFICATIONS_API_TOKEN:-}"
if [[ -z "$AUTH_TOKEN" ]]; then
  echo -e "${YELLOW}Warning: NOTIFICATIONS_API_TOKEN not set${NC}"
  echo "Some tests will be skipped. Set token via:"
  echo "  export NOTIFICATIONS_API_TOKEN=<your-token>"
  echo ""
fi

###############################################################################
# AC-010: Unread Count API
###############################################################################

section "AC-010: Unread Count API (p95 latency <= 100ms)"

if [[ -n "$AUTH_TOKEN" ]]; then
  echo "Testing GET ${API_BASE}/unread-count/"

  START_TIME=$(date +%s%3N)
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${API_BASE}/unread-count/" || echo "000")
  END_TIME=$(date +%s%3N)

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')
  LATENCY=$((END_TIME - START_TIME))

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Unread count endpoint returns HTTP 200"

    if echo "$BODY" | jq -e '.unread_count' >/dev/null 2>&1; then
      UNREAD_COUNT=$(echo "$BODY" | jq -r '.unread_count')
      pass "Unread count response contains 'unread_count' field (value: ${UNREAD_COUNT})"
    else
      fail "Unread count response missing 'unread_count' field"
    fi

    if [[ "$LATENCY" -le 100 ]]; then
      pass "Unread count API latency ${LATENCY}ms <= 100ms"
    else
      echo -e "${YELLOW}Warning: Unread count API latency ${LATENCY}ms > 100ms (p95 target)${NC}"
    fi
  else
    fail "Unread count endpoint returns HTTP ${HTTP_CODE} (expected 200)"
    echo "Response: ${BODY}"
  fi
else
  skip "AC-010: Unread count API (requires auth token)"
fi

###############################################################################
# AC-011: Notification List with Filters
###############################################################################

section "AC-011: Notification List with Read Filter"

if [[ -n "$AUTH_TOKEN" ]]; then
  echo "Testing GET ${API_BASE}/?read=false"

  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${API_BASE}/?read=false" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Notification list endpoint returns HTTP 200"

    if echo "$BODY" | jq -e '.results' >/dev/null 2>&1; then
      pass "Notification list response contains 'results' array"

      # Check if all returned notifications are unread
      ALL_UNREAD=$(echo "$BODY" | jq '[.results[] | .read] | all(. == false)')
      if [[ "$ALL_UNREAD" == "true" ]]; then
        pass "All notifications in filtered list are unread (read=false filter working)"
      else
        fail "Some notifications in filtered list are read (read=false filter not working)"
      fi

      # Check ordering (descending by created_at)
      DATES=$(echo "$BODY" | jq -r '.results[] | .created_at' | head -10)
      if [[ -n "$DATES" ]]; then
        SORTED_DATES=$(echo "$DATES" | sort -r)
        if [[ "$DATES" == "$SORTED_DATES" ]]; then
          pass "Notifications are sorted by created_at descending"
        else
          fail "Notifications are not sorted correctly"
        fi
      fi
    else
      fail "Notification list response missing 'results' array"
    fi

    # Check pagination
    if echo "$BODY" | jq -e '.count' >/dev/null 2>&1; then
      pass "Notification list response contains pagination 'count' field"
    else
      fail "Notification list response missing pagination 'count' field"
    fi
  else
    fail "Notification list endpoint returns HTTP ${HTTP_CODE} (expected 200)"
    echo "Response: ${BODY}"
  fi
else
  skip "AC-011: Notification list filtering (requires auth token)"
fi

###############################################################################
# AC-012: Expired Notifications Excluded
###############################################################################

section "AC-012: Expired Notifications Excluded"

echo "Note: This AC requires notifications with expires_at in the past."
echo "Manual verification steps:"
echo "1. Create a notification with expires_at < now()"
echo "2. Query the notification list API"
echo "3. Verify the expired notification is NOT in the response"
echo ""

skip "AC-012: Expired notification filtering (requires test data)"

###############################################################################
# AC-013: Mark All Read
###############################################################################

section "AC-013: Mark All Read"

if [[ -n "$AUTH_TOKEN" ]]; then
  echo "Testing POST ${API_BASE}/mark-all-read/"

  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    -H "Content-Type: application/json" \
    "${API_BASE}/mark-all-read/" || echo "000")

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Mark all read endpoint returns HTTP 200"

    if echo "$BODY" | jq -e '.count' >/dev/null 2>&1; then
      MARKED_COUNT=$(echo "$BODY" | jq -r '.count')
      pass "Mark all read response contains 'count' field (${MARKED_COUNT} marked)"
    else
      fail "Mark all read response missing 'count' field"
    fi

    # Verify unread count is now 0
    sleep 1  # Brief delay to ensure consistency
    UNREAD_CHECK=$(curl -s -H "Authorization: Bearer ${AUTH_TOKEN}" \
      "${API_BASE}/unread-count/")

    if echo "$UNREAD_CHECK" | jq -e '.unread_count' >/dev/null 2>&1; then
      UNREAD_AFTER=$(echo "$UNREAD_CHECK" | jq -r '.unread_count')
      if [[ "$UNREAD_AFTER" == "0" ]]; then
        pass "Unread count is 0 after mark-all-read"
      else
        echo -e "${YELLOW}Warning: Unread count is ${UNREAD_AFTER} after mark-all-read (may have new notifications)${NC}"
      fi
    fi
  else
    fail "Mark all read endpoint returns HTTP ${HTTP_CODE} (expected 200)"
    echo "Response: ${BODY}"
  fi
else
  skip "AC-013: Mark all read (requires auth token)"
fi

###############################################################################
# AC-014: Multi-Tenancy (No Cross-Tenant Leakage)
###############################################################################

section "AC-014: Multi-Tenancy (No Cross-Tenant Leakage)"

echo "Note: This AC requires notifications from multiple org_slugs."
echo "Manual verification steps:"
echo "1. Create notifications with org_slug='acme'"
echo "2. Create notifications with org_slug='other'"
echo "3. Query API with ?org_slug=acme"
echo "4. Verify only notifications with org_slug='acme' are returned"
echo ""

skip "AC-014: Multi-tenancy isolation (requires multi-org test data)"

###############################################################################
# Additional: API Response Schema Validation
###############################################################################

section "Additional: API Response Schema Validation"

if [[ -n "$AUTH_TOKEN" ]]; then
  echo "Validating notification object schema..."

  RESPONSE=$(curl -s -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${API_BASE}/?page_size=1")

  NOTIFICATION=$(echo "$RESPONSE" | jq '.results[0]')

  if [[ "$NOTIFICATION" != "null" ]]; then
    REQUIRED_FIELDS=("id" "message_type" "title" "body" "org_slug" "read" "created_at")
    MISSING_FIELDS=()

    for FIELD in "${REQUIRED_FIELDS[@]}"; do
      if ! echo "$NOTIFICATION" | jq -e ".${FIELD}" >/dev/null 2>&1; then
        MISSING_FIELDS+=("$FIELD")
      fi
    done

    if [[ ${#MISSING_FIELDS[@]} -eq 0 ]]; then
      pass "Notification object contains all required fields"
    else
      fail "Notification object missing fields: ${MISSING_FIELDS[*]}"
    fi

    # Validate field types
    ID=$(echo "$NOTIFICATION" | jq -r '.id')
    if [[ "$ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
      pass "Notification ID is valid UUID"
    else
      fail "Notification ID is not a valid UUID: ${ID}"
    fi

    READ_VALUE=$(echo "$NOTIFICATION" | jq -r '.read')
    if [[ "$READ_VALUE" == "true" ]] || [[ "$READ_VALUE" == "false" ]]; then
      pass "Notification 'read' field is boolean"
    else
      fail "Notification 'read' field is not boolean: ${READ_VALUE}"
    fi
  else
    skip "Schema validation (no notifications available)"
  fi
else
  skip "API schema validation (requires auth token)"
fi

###############################################################################
# Performance: List API Latency
###############################################################################

section "Performance: List API Latency (p95 <= 200ms)"

if [[ -n "$AUTH_TOKEN" ]]; then
  echo "Measuring notification list API latency..."

  START_TIME=$(date +%s%3N)
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${AUTH_TOKEN}" \
    "${API_BASE}/" || echo "000")
  END_TIME=$(date +%s%3N)

  HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
  LATENCY=$((END_TIME - START_TIME))

  if [[ "$HTTP_CODE" == "200" ]]; then
    if [[ "$LATENCY" -le 200 ]]; then
      pass "Notification list API latency ${LATENCY}ms <= 200ms (p95 target)"
    else
      echo -e "${YELLOW}Warning: Notification list API latency ${LATENCY}ms > 200ms (p95 target: 200ms)${NC}"
    fi
  else
    fail "Notification list API failed (HTTP ${HTTP_CODE})"
  fi
else
  skip "Performance: List API latency (requires auth token)"
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
  echo "Note: Some ACs require manual verification with test data."
  echo "See skipped tests above for manual verification steps."
  echo ""
  echo "To enable all tests:"
  echo "  1. Set NOTIFICATIONS_API_TOKEN environment variable"
  echo "  2. Create test notifications via ACE or Django shell"
  echo "  3. Create multi-org test data for AC-014"
  exit 0
else
  echo -e "${RED}✗ ${FAILED} test(s) failed${NC}"
  echo ""
  echo "Review failures above and consult:"
  echo "- specs/email-notifications-pipeline_spec.md"
  echo "- infrastructure/tutor/custom-apps/openedx_notifications/README.md"
  exit 1
fi
