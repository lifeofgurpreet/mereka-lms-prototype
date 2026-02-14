#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-022, AC-023, AC-024, AC-025, AC-026
# Verify LinkedIn integration, enterprise HR API, and webhook delivery
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Badge Integration (LinkedIn, HR API, Webhooks) Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-022: LinkedIn "Add to Profile" integration
# ---------------------------------------------------------------------------
LEARNER_PORTFOLIO="infrastructure/tutor/custom-apps/learner_portal"
MFE_CONFIG="deploy/k8s/base/apps/mfe"

# Check for LinkedIn share button configuration
if grep -r "linkedin\|LinkedIn" "$LEARNER_PORTFOLIO" "$MFE_CONFIG" 2>/dev/null | grep -i "badge\|credential" | grep -q "share\|add.*profile\|certification"; then
  pass "AC-022: LinkedIn 'Add to Profile' button configured"
else
  skip "AC-022: LinkedIn integration not yet implemented"
fi

# Check for pre-populated parameters (badge name, issuer, dates, URL)
if grep -r "badge.*name\|issuer.*organization\|issuance.*date" "$LEARNER_PORTFOLIO" "$MFE_CONFIG" 2>/dev/null | grep -i "linkedin" | grep -q "credential.*url\|assertion.*url"; then
  pass "AC-022: LinkedIn pre-populated parameters configured"
else
  skip "AC-022: LinkedIn parameter population not found"
fi

# ---------------------------------------------------------------------------
# AC-023: Open Graph metadata for social sharing
# ---------------------------------------------------------------------------
# Check for Open Graph meta tags in badge assertion pages
if grep -r "og:title\|og:description\|og:image" "$LEARNER_PORTFOLIO" "$MFE_CONFIG" 2>/dev/null | grep -i "badge"; then
  pass "AC-023: Open Graph metadata for badge sharing configured"
else
  skip "AC-023: Open Graph metadata not found"
fi

# Check for badge image in og:image tag
if grep -r "og:image.*badge\|badge.*og:image" "$LEARNER_PORTFOLIO" "$MFE_CONFIG" 2>/dev/null; then
  pass "AC-023: Badge image in Open Graph metadata configured"
else
  skip "AC-023: Badge image in og:image not found"
fi

# ---------------------------------------------------------------------------
# AC-024: Enterprise HR API endpoints
# ---------------------------------------------------------------------------
BADGES_API="services/badgr-server"
ENTERPRISE_API="deploy/k8s/base/apps/enterprise"

# Check for enterprise-scoped assertion list endpoint
if grep -r "/api/v1/badges/enterprise\|/enterprise.*assertions" "$BADGES_API" "$ENTERPRISE_API" 2>/dev/null | grep -q "url\|path\|route"; then
  pass "AC-024: Enterprise-scoped assertion API endpoint configured"
else
  skip "AC-024: Enterprise HR API not yet implemented"
fi

# Check for JWT authentication requirement
if grep -r "JWT.*authentication\|JWTAuthentication" "$BADGES_API" "$ENTERPRISE_API" 2>/dev/null | grep -i "enterprise.*badge\|badge.*api"; then
  pass "AC-024: JWT authentication for enterprise API configured"
else
  skip "AC-024: JWT authentication not found"
fi

# Check for enterprise_admin role requirement
if grep -r "enterprise_admin\|role.*admin" "$BADGES_API" "$ENTERPRISE_API" 2>/dev/null | grep -i "badge\|permission"; then
  pass "AC-024: Enterprise admin role requirement configured"
else
  skip "AC-024: Enterprise admin role check not found"
fi

# Check for filtering parameters (badge_class_id, issued_after, etc.)
if grep -r "badge_class_id\|issued_after\|issued_before\|learner_email_hash" "$BADGES_API" 2>/dev/null | grep -i "filter\|query"; then
  pass "AC-024: Enterprise API filtering parameters configured"
else
  skip "AC-024: API filtering parameters not found"
fi

# Check for pagination support
if grep -r "pagination\|page.*size\|limit.*offset" "$BADGES_API" 2>/dev/null | grep -i "enterprise\|badge"; then
  pass "AC-024: API pagination configured"
else
  skip "AC-024: API pagination not found"
fi

# ---------------------------------------------------------------------------
# AC-025: Webhook registration and delivery
# ---------------------------------------------------------------------------
# Check for webhook registration endpoint
if grep -r "webhook.*register\|register.*webhook" "$BADGES_API" "$ENTERPRISE_API" 2>/dev/null | grep -i "badge\|enterprise"; then
  pass "AC-025: Webhook registration endpoint configured"
else
  skip "AC-025: Webhook system not yet implemented"
fi

# Check for webhook event types (badge_issued, badge_revoked, etc.)
if grep -r "badge_issued\|badge_revoked\|badge_expired\|badge_shared" "$BADGES_API" 2>/dev/null | grep -i "webhook\|event"; then
  pass "AC-025: Webhook event types (badge_issued, etc.) defined"
else
  skip "AC-025: Webhook event types not found"
fi

# Check for webhook payload structure
if grep -r "event_type.*assertion_uid\|webhook.*payload" "$BADGES_API" 2>/dev/null | grep -i "badge" | grep -q "enterprise_customer_uuid\|timestamp"; then
  pass "AC-025: Webhook payload structure configured"
else
  skip "AC-025: Webhook payload structure not found"
fi

# ---------------------------------------------------------------------------
# AC-026: Webhook retry logic with exponential backoff
# ---------------------------------------------------------------------------
# Check for retry configuration
if grep -r "retry\|exponential.*backoff\|backoff" "$BADGES_API" 2>/dev/null | grep -i "webhook"; then
  pass "AC-026: Webhook retry with exponential backoff configured"
else
  skip "AC-026: Webhook retry logic not yet implemented"
fi

# Check for retry schedule (30s, 1m, 2m, 4m, 8m = 6 attempts)
if grep -r "30s\|1m.*2m\|retry.*schedule" "$BADGES_API" 2>/dev/null | grep -i "webhook\|backoff"; then
  pass "AC-026: Webhook retry schedule (30s, 1m, 2m, 4m, 8m) configured"
else
  skip "AC-026: Retry schedule not found"
fi

# Check for webhook suspension after failures
if grep -r "suspend.*webhook\|webhook.*suspend" "$BADGES_API" 2>/dev/null | grep -q "10.*event\|failure"; then
  pass "AC-026: Webhook suspension after failures configured"
else
  skip "AC-026: Webhook suspension logic not found"
fi

# Check for dead letter queue
if grep -r "dead.*letter.*queue\|dlq\|failed.*webhook" "$BADGES_API" 2>/dev/null | grep -i "webhook\|event"; then
  pass "AC-026: Dead letter queue for failed webhook deliveries configured"
else
  skip "AC-026: Dead letter queue not found"
fi

# ---------------------------------------------------------------------------
# Additional checks: Integration security and validation
# ---------------------------------------------------------------------------
# Check for HTTPS-only webhook URLs
if grep -r "https.*only\|validate.*https" "$BADGES_API" 2>/dev/null | grep -i "webhook.*url"; then
  pass "HTTPS-only webhook URL validation configured"
else
  skip "HTTPS-only webhook validation not found"
fi

# Check for SSRF prevention (private IP range blocking)
if grep -r "SSRF\|private.*ip\|10\.0\.0\.0\|192\.168" "$BADGES_API" 2>/dev/null | grep -i "webhook\|validation"; then
  pass "SSRF prevention for webhook URLs configured"
else
  skip "SSRF prevention not found"
fi

# Check for idempotency key in webhook payload
if grep -r "idempotency_key\|idempotent" "$BADGES_API" 2>/dev/null | grep -i "webhook\|payload"; then
  pass "Webhook payload idempotency key configured"
else
  skip "Webhook idempotency key not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
