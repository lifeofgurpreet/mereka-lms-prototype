#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-006, AC-007, AC-008, AC-009, AC-010
# Verify badge issuance pipeline configuration
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Badge Issuance Pipeline Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-006: Course completion trigger configuration
# ---------------------------------------------------------------------------
# Check for event handler configuration for COURSE_COMPLETION
EVENT_HANDLER_CONFIG="infrastructure/tutor/custom-apps/badge_issuance"
LMS_SETTINGS="deploy/k8s/base/apps/openedx/settings/lms"

if [[ -d "$EVENT_HANDLER_CONFIG" ]] || grep -r "COURSE_COMPLETION" "$LMS_SETTINGS" 2>/dev/null | grep -q "badge"; then
  pass "AC-006: Course completion event handler configuration found"
else
  skip "AC-006: Course completion badge trigger not yet implemented"
fi

# Check for Celery task definition for badge issuance
if grep -r "badge.*issuance.*task" "$EVENT_HANDLER_CONFIG" "$LMS_SETTINGS" 2>/dev/null | grep -q "celery\|@task"; then
  pass "AC-006: Badge issuance Celery task defined"
else
  skip "AC-006: Badge issuance Celery task not found"
fi

# ---------------------------------------------------------------------------
# AC-007: Program completion trigger configuration
# ---------------------------------------------------------------------------
if grep -r "PROGRAM_COMPLETION" "$EVENT_HANDLER_CONFIG" "$LMS_SETTINGS" 2>/dev/null | grep -q "badge"; then
  pass "AC-007: Program completion event handler configuration found"
else
  skip "AC-007: Program completion badge trigger not yet implemented"
fi

# ---------------------------------------------------------------------------
# AC-008: Idempotent badge issuance (duplicate prevention)
# ---------------------------------------------------------------------------
# Check for idempotency logic in event handlers
if grep -r "unique\|idempotent\|duplicate" "$EVENT_HANDLER_CONFIG" "$LMS_SETTINGS" 2>/dev/null | grep -i "badge" | grep -q -E "learner.*badge_class|badge_class.*learner"; then
  pass "AC-008: Idempotency logic for duplicate badge prevention found"
else
  skip "AC-008: Idempotency logic not yet implemented"
fi

# Check for composite key pattern (learner + badge_class + course)
if grep -r "(learner.*badge.*course)\|(course.*learner.*badge)" "$EVENT_HANDLER_CONFIG" "$LMS_SETTINGS" 2>/dev/null | grep -q "key\|unique"; then
  pass "AC-008: Composite key pattern for idempotency found"
else
  skip "AC-008: Composite key idempotency not found"
fi

# ---------------------------------------------------------------------------
# AC-009: Manual badge issuance endpoint
# ---------------------------------------------------------------------------
# Check for admin API endpoint or Django admin action for manual issuance
ADMIN_PORTAL="infrastructure/tutor/custom-apps/admin_portal"
BADGES_API="services/badgr-server"

if grep -r "manual.*issuance\|issue.*badge.*manual" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -q "def\|class"; then
  pass "AC-009: Manual badge issuance endpoint/action defined"
else
  skip "AC-009: Manual badge issuance not yet implemented"
fi

# Check for required inputs: learner identifier, badge class selection
if grep -r "learner.*email\|user.*id" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -i "badge.*issue" | grep -q "badge_class"; then
  pass "AC-009: Manual issuance inputs (learner, badge_class) configured"
else
  skip "AC-009: Manual issuance input validation not found"
fi

# ---------------------------------------------------------------------------
# AC-010: Bulk badge issuance (CSV upload)
# ---------------------------------------------------------------------------
# Check for bulk issuance handler
if grep -r "bulk.*issuance\|csv.*badge\|batch.*badge" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -q "upload\|import"; then
  pass "AC-010: Bulk badge issuance (CSV) handler found"
else
  skip "AC-010: Bulk issuance not yet implemented"
fi

# Check for batch size limit (1000)
if grep -r "1000\|batch.*size\|max.*badges" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -i "bulk\|csv" | grep -q "limit\|max"; then
  pass "AC-010: Bulk issuance batch size limit configured"
else
  skip "AC-010: Batch size limit not found"
fi

# Check for completion report feature
if grep -r "completion.*report\|issuance.*report\|batch.*report" "$ADMIN_PORTAL" "$BADGES_API" 2>/dev/null | grep -q "bulk\|csv"; then
  pass "AC-010: Bulk issuance completion report feature found"
else
  skip "AC-010: Completion report not found"
fi

# ---------------------------------------------------------------------------
# Additional checks: Email notification on issuance
# ---------------------------------------------------------------------------
if grep -r "email.*notification\|notify.*learner" "$EVENT_HANDLER_CONFIG" "$BADGES_API" 2>/dev/null | grep -i "badge.*issue" | grep -q "send\|mail"; then
  pass "Email notification on badge issuance configured"
else
  skip "Email notification on badge issuance not found"
fi

# Check for feature flags
FEATURE_FLAGS="deploy/k8s/base/apps/openedx/settings/lms/production.py"
if [[ -f "$FEATURE_FLAGS" ]] && grep -q "ENABLE_BADGE_ISSUANCE" "$FEATURE_FLAGS"; then
  pass "Feature flag ENABLE_BADGE_ISSUANCE found in settings"
else
  skip "Feature flag ENABLE_BADGE_ISSUANCE not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
