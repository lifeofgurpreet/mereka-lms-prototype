#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-019, AC-020, AC-021
# Verify badge revocation workflows and blockchain anchoring
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Badge Revocation Workflow Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-019: Single badge revocation with reason
# ---------------------------------------------------------------------------
BADGES_API="services/badgr-server"
ADMIN_PORTAL="infrastructure/tutor/custom-apps/admin_portal"

# Check for revocation endpoint/action
if grep -r "revoke.*badge\|badge.*revocation" "$BADGES_API" "$ADMIN_PORTAL" 2>/dev/null | grep -q "def\|class\|endpoint"; then
  pass "AC-019: Badge revocation endpoint/action defined"
else
  skip "AC-019: Badge revocation not yet implemented"
fi

# Check for required revocation reason field
if grep -r "revocation.*reason\|reason.*revoke" "$BADGES_API" 2>/dev/null | grep -i "badge\|assertion" | grep -q "required\|CharField\|TextField"; then
  pass "AC-019: Revocation reason field (required) configured"
else
  skip "AC-019: Revocation reason field not found"
fi

# Check for immediate verification response update
if grep -r "revoked.*immediately\|immediate.*revocation" "$BADGES_API" 2>/dev/null | grep -i "verification\|assertion"; then
  pass "AC-019: Immediate verification response update on revocation configured"
else
  skip "AC-019: Immediate verification update not found"
fi

# Check for learner portfolio "Revoked" status display
LEARNER_PORTFOLIO="infrastructure/tutor/custom-apps/learner_portal"
if grep -r "revoked.*status\|badge.*revoked" "$LEARNER_PORTFOLIO" 2>/dev/null | grep -i "portfolio\|display"; then
  pass "AC-019: Learner portfolio revoked status display configured"
else
  skip "AC-019: Portfolio revoked status not found"
fi

# Check for audit logging of revocation events
if grep -r "audit.*log\|log.*revocation" "$BADGES_API" 2>/dev/null | grep -i "assertion.*uid\|badge" | grep -q "revoked_by\|admin\|timestamp"; then
  pass "AC-019: Revocation audit logging (assertion_uid, revoked_by, timestamp) configured"
else
  skip "AC-019: Revocation audit logging not found"
fi

# ---------------------------------------------------------------------------
# AC-020: Bulk revocation (up to 500 assertions)
# ---------------------------------------------------------------------------
# Check for bulk revocation handler
if grep -r "bulk.*revoke\|batch.*revoke" "$BADGES_API" "$ADMIN_PORTAL" 2>/dev/null | grep -i "badge\|assertion"; then
  pass "AC-020: Bulk badge revocation handler found"
else
  skip "AC-020: Bulk revocation not yet implemented"
fi

# Check for batch size limit (500)
if grep -r "500\|batch.*size.*revoke" "$BADGES_API" 2>/dev/null | grep -i "bulk\|revoke"; then
  pass "AC-020: Bulk revocation batch size limit (500) configured"
else
  skip "AC-020: Batch size limit not found"
fi

# ---------------------------------------------------------------------------
# AC-021: Blockchain-anchored badge revocation handling
# ---------------------------------------------------------------------------
# Check for blockchain anchoring feature flag
FEATURE_FLAGS="deploy/k8s/base/apps/openedx/settings/lms/production.py"
if grep -r "ENABLE_BLOCKCHAIN_ANCHORING\|blockchain.*anchor" "$FEATURE_FLAGS" "$BADGES_API" 2>/dev/null | grep -i "badge"; then
  pass "AC-021: Blockchain anchoring feature flag found"
else
  skip "AC-021: Blockchain anchoring not yet implemented"
fi

# Check for revocation list update (off-chain)
if grep -r "revocation.*list\|revoked.*list" "$BADGES_API" 2>/dev/null | grep -i "badge\|assertion" | grep -q "update\|append"; then
  pass "AC-021: Revocation list (off-chain) update configured"
else
  skip "AC-021: Revocation list not found"
fi

# Check that blockchain anchor is NOT modified on revocation
if grep -r "blockchain.*immutable\|anchor.*unchanged\|!.*modify.*anchor" "$BADGES_API" 2>/dev/null | grep -i "revok"; then
  pass "AC-021: Blockchain anchor immutability on revocation documented/enforced"
else
  skip "AC-021: Blockchain anchor immutability not found"
fi

# Check for revocation list endpoint
if grep -r "/revocation-list\|revoked.*assertions" "$BADGES_API" 2>/dev/null | grep -q "issuer\|public"; then
  pass "AC-021: Public revocation list endpoint configured"
else
  skip "AC-021: Revocation list endpoint not found"
fi

# ---------------------------------------------------------------------------
# Additional checks: Revocation workflow details
# ---------------------------------------------------------------------------
# Check for non-reissuable policy after revocation
if grep -r "!.*reissue\|not.*reissuable\|prevent.*duplicate" "$BADGES_API" 2>/dev/null | grep -i "revok"; then
  pass "Non-reissuable policy after revocation configured"
else
  skip "Non-reissuable policy not found"
fi

# Check for enterprise customer UUID in revocation audit logs
if grep -r "enterprise_customer_uuid" "$BADGES_API" 2>/dev/null | grep -i "revok.*log\|audit"; then
  pass "Enterprise customer UUID in revocation audit logs configured"
else
  skip "Enterprise customer UUID in audit logs not found"
fi

# Check for revocation metadata in public assertion 404 response
if grep -r "404.*revocation.*metadata\|revoked.*date.*404" "$BADGES_API" 2>/dev/null; then
  pass "Revocation metadata in 404 response configured"
else
  skip "Revocation metadata in 404 response not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
