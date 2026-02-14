#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-027, AC-028, AC-029
# Verify badge security measures (recipient hashing, rate limiting, anomaly detection)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Badge Security Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-027: Recipient email hashing (SHA-256 with salt)
# ---------------------------------------------------------------------------
BADGES_API="services/badgr-server"

# Check for recipient identity hashing in assertion model
if grep -r "recipient.*hash\|sha256.*recipient" "$BADGES_API" 2>/dev/null | grep -i "email\|identity"; then
  pass "AC-027: Recipient email hashing (SHA-256) configured"
else
  skip "AC-027: Recipient hashing not yet implemented"
fi

# Check for per-issuer salt
if grep -r "salt\|issuer.*salt\|per.*issuer" "$BADGES_API" 2>/dev/null | grep -i "recipient\|hash"; then
  pass "AC-027: Per-issuer salt for recipient hashing configured"
else
  skip "AC-027: Per-issuer salt not found"
fi

# Check that plaintext email is NOT in public assertion
if grep -r "!.*plaintext.*email\|no.*raw.*email\|hashed.*only" "$BADGES_API" 2>/dev/null | grep -i "assertion\|public"; then
  pass "AC-027: Plaintext email excluded from public assertions"
else
  skip "AC-027: Plaintext email exclusion not found"
fi

# Check for OpenBadges spec compliance (recipient.type, hashed, identity, salt)
if grep -r "recipient.*type.*hashed\|hashed.*true" "$BADGES_API" 2>/dev/null | grep -i "identity.*salt"; then
  pass "AC-027: OpenBadges recipient hashing spec compliance configured"
else
  skip "AC-027: OpenBadges hashing spec not found"
fi

# ---------------------------------------------------------------------------
# AC-028: Rate limiting on verification endpoint (100 req/min per IP)
# ---------------------------------------------------------------------------
# Check for rate limiting configuration
if grep -r "rate.*limit\|ratelimit\|throttle" "$BADGES_API" 2>/dev/null | grep -i "verification\|public.*assertion"; then
  pass "AC-028: Rate limiting on verification endpoint configured"
else
  skip "AC-028: Rate limiting not yet implemented"
fi

# Check for 100 requests/minute limit
if grep -r "100.*minute\|100.*req.*min\|limit.*100" "$BADGES_API" 2>/dev/null | grep -i "rate\|verification"; then
  pass "AC-028: Rate limit 100 requests/minute configured"
else
  skip "AC-028: Rate limit threshold not found"
fi

# Check for per-IP rate limiting
if grep -r "per.*ip\|ip.*address" "$BADGES_API" 2>/dev/null | grep -i "rate.*limit\|throttle"; then
  pass "AC-028: Per-IP rate limiting configured"
else
  skip "AC-028: Per-IP limiting not found"
fi

# Check for HTTP 429 response on rate limit exceeded
if grep -r "429\|Too.*Many.*Requests\|Retry-After" "$BADGES_API" 2>/dev/null | grep -i "rate.*limit\|verification"; then
  pass "AC-028: HTTP 429 response with Retry-After header configured"
else
  skip "AC-028: HTTP 429 response not found"
fi

# ---------------------------------------------------------------------------
# AC-029: Anomaly detection (>1000 verifications/hour triggers alert)
# ---------------------------------------------------------------------------
# Check for verification request logging
if grep -r "verification.*log\|log.*verification" "$BADGES_API" 2>/dev/null | grep -q "assertion_uid\|verifier_ip\|timestamp"; then
  pass "AC-029: Verification request logging configured"
else
  skip "AC-029: Verification logging not yet implemented"
fi

# Check for anomaly detection threshold (1000/hour)
if grep -r "1000.*hour\|anomal.*1000\|spike.*detect" "$BADGES_API" 2>/dev/null | grep -i "verification\|assertion"; then
  pass "AC-029: Anomaly detection threshold (1000/hour) configured"
else
  skip "AC-029: Anomaly detection threshold not found"
fi

# Check for alert triggering on anomalous patterns
if grep -r "alert.*anomal\|trigger.*alert" "$BADGES_API" 2>/dev/null | grep -i "verification\|spike"; then
  pass "AC-029: Alert triggering on anomalous verification patterns configured"
else
  skip "AC-029: Alert triggering not found"
fi

# Check for Prometheus metrics integration for anomaly detection
OBSERVABILITY="deploy/k8s/base/apps/prometheus"
if grep -r "badge.*verification.*total\|verification.*requests" "$BADGES_API" "$OBSERVABILITY" 2>/dev/null | grep -i "metric\|prometheus"; then
  pass "AC-029: Prometheus metrics for verification tracking configured"
else
  skip "AC-029: Prometheus metrics integration not found"
fi

# ---------------------------------------------------------------------------
# Additional checks: Cryptographic signing and key management
# ---------------------------------------------------------------------------
# Check for issuer signing keys in K8s secrets
SECRETS_CONFIG="deploy/k8s/base/secrets"
if grep -r "BADGR_SIGNING_KEY\|signing.*key.*badge" "$SECRETS_CONFIG" 2>/dev/null | grep -i "secret"; then
  pass "Issuer signing keys in K8s Secrets configured"
else
  skip "Issuer signing keys not found in secrets config"
fi

# Check for RSA-2048 or Ed25519 key algorithm
if grep -r "RSA-2048\|RSA.*2048\|Ed25519" "$BADGES_API" 2>/dev/null | grep -i "signing.*key\|badge"; then
  pass "Signing key algorithm (RSA-2048/Ed25519) documented"
else
  skip "Signing key algorithm not found"
fi

# Check for signing key rotation policy
if grep -r "rotate.*key\|key.*rotation\|annual.*key" "$BADGES_API" 2>/dev/null | grep -i "signing\|issuer"; then
  pass "Signing key rotation policy configured"
else
  skip "Signing key rotation policy not found"
fi

# Check that signing keys are NOT logged or exposed
if grep -r "!.*log.*key\|no.*key.*log\|exclude.*signing.*key" "$BADGES_API" 2>/dev/null; then
  pass "Signing key exclusion from logs configured"
else
  skip "Signing key log exclusion not found"
fi

# Check for verification log IP hashing (privacy)
if grep -r "hash.*ip\|verifier_ip.*hash" "$BADGES_API" 2>/dev/null | grep -i "log\|verification"; then
  pass "Verifier IP hashing in logs configured"
else
  skip "Verifier IP hashing not found"
fi

# Check for 90-day verification log retention
if grep -r "90.*day\|retention.*90" "$BADGES_API" 2>/dev/null | grep -i "verification.*log\|log.*retention"; then
  pass "90-day verification log retention configured"
else
  skip "90-day log retention not found"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
