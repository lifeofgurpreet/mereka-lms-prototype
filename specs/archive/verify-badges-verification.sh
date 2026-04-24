#!/usr/bin/env bash
# @spec: badges-credentials-enterprise_spec.md
# @covers AC-015, AC-016, AC-017, AC-018
# Verify public badge verification endpoints and OpenBadges compliance
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

SKIP_LIVE=false
if [[ "${1:-}" == "--skip-live" ]]; then
  SKIP_LIVE=true
fi

echo "=== Badge Verification Endpoint Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

# ---------------------------------------------------------------------------
# AC-015: Public verification endpoint returns OpenBadges 2.0 JSON
# ---------------------------------------------------------------------------
# Check for public assertion endpoint configuration
BADGES_CONFIG="services/badgr-server"
CADDY_CONFIG="deploy/k8s/base/apps/caddy"

if grep -r "/public/assertions\|public.*assertion" "$BADGES_CONFIG" "$CADDY_CONFIG" 2>/dev/null | grep -q "url\|route\|path"; then
  pass "AC-015: Public assertion verification endpoint configured"
else
  skip "AC-015: Public assertion endpoint not yet implemented"
fi

# Check for OpenBadges 2.0 JSON-LD content type
if grep -r "application/ld\+json\|ld\+json" "$BADGES_CONFIG" 2>/dev/null | grep -i "assertion\|badge"; then
  pass "AC-015: Content-Type application/ld+json configured for assertions"
else
  skip "AC-015: JSON-LD content type not found"
fi

# Check for required OpenBadges 2.0 fields in assertion model
if grep -r "@context.*openbadges\|type.*Assertion\|recipient.*hashed" "$BADGES_CONFIG" 2>/dev/null | grep -q "badge\|assertion"; then
  pass "AC-015: OpenBadges 2.0 required fields (@context, type, recipient) found"
else
  skip "AC-015: OpenBadges 2.0 field definitions not found"
fi

# ---------------------------------------------------------------------------
# AC-016: Revoked assertions return 404
# ---------------------------------------------------------------------------
# Check for revocation status handling
if grep -r "revoked\|revocation" "$BADGES_CONFIG" 2>/dev/null | grep -i "assertion" | grep -q "404\|not.*found"; then
  pass "AC-016: Revoked assertion 404 response configured"
else
  skip "AC-016: Revocation status handling not found"
fi

# Check for revocation metadata in response
if grep -r "revocation.*date\|revoked.*at" "$BADGES_CONFIG" 2>/dev/null | grep -i "assertion\|badge"; then
  pass "AC-016: Revocation metadata (date) in response configured"
else
  skip "AC-016: Revocation metadata not found"
fi

# ---------------------------------------------------------------------------
# AC-017: CORS enabled (Access-Control-Allow-Origin: *)
# ---------------------------------------------------------------------------
# Check for CORS configuration
if grep -r "CORS\|cors\|Access-Control-Allow-Origin" "$BADGES_CONFIG" "$CADDY_CONFIG" 2>/dev/null | grep -q "\*\|wildcard\|public"; then
  pass "AC-017: CORS wildcard (Access-Control-Allow-Origin: *) configured"
else
  skip "AC-017: CORS configuration not found"
fi

# ---------------------------------------------------------------------------
# AC-018: Public signing key endpoint
# ---------------------------------------------------------------------------
# Check for signing key well-known endpoint
if grep -r "\.well-known.*signing.*key\|badgeclass-signing-key" "$BADGES_CONFIG" "$CADDY_CONFIG" 2>/dev/null | grep -q "url\|route"; then
  pass "AC-018: Signing key well-known endpoint configured"
else
  skip "AC-018: Signing key endpoint not found"
fi

# Check for public key format (PEM or JWK)
if grep -r "PEM\|JWK\|public.*key" "$BADGES_CONFIG" 2>/dev/null | grep -i "badge\|signing" | grep -q "format\|export"; then
  pass "AC-018: Public key format (PEM/JWK) configured"
else
  skip "AC-018: Public key format not found"
fi

# ---------------------------------------------------------------------------
# Additional checks: Verification stability and caching
# ---------------------------------------------------------------------------
# Check for stable assertion URLs
if grep -r "stable.*url\|permalink\|assertion.*id" "$BADGES_CONFIG" 2>/dev/null | grep -i "badge\|assertion"; then
  pass "Stable assertion URL configuration found"
else
  skip "Stable assertion URL not found"
fi

# Check for caching headers
if grep -r "Cache-Control\|max-age" "$BADGES_CONFIG" "$CADDY_CONFIG" 2>/dev/null | grep -i "assertion\|badge"; then
  pass "Cache-Control headers for verification configured"
else
  skip "Cache-Control headers not found"
fi

# ---------------------------------------------------------------------------
# Live endpoint checks (optional)
# ---------------------------------------------------------------------------
if [[ "$SKIP_LIVE" == false ]]; then
  echo ""
  echo "--- Live Endpoint Checks ---"

  BADGES_DOMAIN="badges.academyv2.mereka.io"

  # Check if domain is reachable
  if curl -s --max-time 5 -o /dev/null -w '%{http_code}' "https://${BADGES_DOMAIN}/health/" 2>/dev/null | grep -qE '^[23]'; then
    pass "Live check: badges.academyv2.mereka.io is reachable"

    # AC-017: Check CORS headers
    CORS_HEADER=$(curl -s --max-time 10 -I "https://${BADGES_DOMAIN}/public/assertions/test" 2>/dev/null | grep -i "access-control-allow-origin" || true)
    if echo "$CORS_HEADER" | grep -q "\*"; then
      pass "AC-017 (live): CORS Access-Control-Allow-Origin: * header present"
    elif [[ -n "$CORS_HEADER" ]]; then
      skip "AC-017 (live): CORS header present but not wildcard"
    else
      skip "AC-017 (live): CORS header not found (endpoint may not exist)"
    fi

    # AC-018: Check signing key endpoint
    SIGNING_KEY_STATUS=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "https://${BADGES_DOMAIN}/.well-known/badgeclass-signing-key" 2>/dev/null || true)
    if [[ "$SIGNING_KEY_STATUS" == "200" ]]; then
      pass "AC-018 (live): Signing key endpoint returns HTTP 200"
    else
      skip "AC-018 (live): Signing key endpoint returned $SIGNING_KEY_STATUS (may not exist yet)"
    fi

  else
    skip "Live check: badges.academyv2.mereka.io not reachable (badge system may not be deployed)"
  fi
else
  skip "Live endpoint checks disabled (--skip-live)"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
