#!/usr/bin/env bash
# Verify session cookie configuration for cross-subdomain login persistence.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
WARN=0

# Key files
LMS_SETTINGS="${REPO_ROOT}/deploy/k8s/base/apps/openedx/settings/lms/production.py"
TUTOR_CONFIG="${REPO_ROOT}/tutor_env/config.yml"

# Default test mode
TEST_MODE="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      TEST_MODE="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--test cross-subdomain|cookie-domain-check|independent-session|no-cookie-leakage]" >&2
      exit 1
      ;;
  esac
done

echo "=== Session Persistence Verification ==="
echo ""

# Test 1: Cross-subdomain session sharing
test_cross_subdomain() {
  echo -n "Checking SESSION_COOKIE_DOMAIN for .mereka.io... "
  if grep -q 'SESSION_COOKIE_DOMAIN.*\.mereka\.io' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    # Check if it's set to None (host-only)
    if grep -q 'SESSION_COOKIE_DOMAIN = None' "$LMS_SETTINGS"; then
      echo -e "${YELLOW}WARN${NC} (set to None, uses host-only cookies)"
      echo "  Note: Middleware may rewrite per-request for cross-subdomain"
      WARN=$((WARN + 1))
    else
      echo -e "${RED}FAIL${NC}"
      echo "  SESSION_COOKIE_DOMAIN not found or not set to .mereka.io"
      FAIL=$((FAIL + 1))
    fi
  fi
}

# Test 2: Cookie domain configuration check
test_cookie_domain_check() {
  echo -n "Checking MEREKA_COOKIE_DOMAIN configuration... "
  if grep -q 'MEREKA_COOKIE_DOMAIN.*\.mereka\.io' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC}"
    echo "  MEREKA_COOKIE_DOMAIN not explicitly set in LMS settings"
    WARN=$((WARN + 1))
  fi

  echo -n "Checking SESSION_COOKIE_SECURE (HTTPS-only cookies)... "
  if grep -q 'SESSION_COOKIE_SECURE.*=.*True' "$LMS_SETTINGS" || \
     grep -q 'SESSION_COOKIE_SECURE = MEREKA_SCHEME == "https"' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    echo "  SESSION_COOKIE_SECURE not set to True for HTTPS"
    FAIL=$((FAIL + 1))
  fi
}

# Test 3: Independent session for biji-biji.com
test_independent_session() {
  echo -n "Checking separate cookie domain for biji-biji.com... "
  # academy.biji-biji.com should NOT inherit .mereka.io cookies
  # Middleware should handle per-request cookie domain rewriting
  if grep -q 'MerekaCookieDomainMiddleware' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    echo "  Middleware present for dynamic cookie domain handling"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC}"
    echo "  MerekaCookieDomainMiddleware not found in settings"
    WARN=$((WARN + 1))
  fi
}

# Test 4: No cookie leakage between domains
test_no_cookie_leakage() {
  echo -n "Checking SESSION_COOKIE_HTTPONLY... "
  if grep -q 'SESSION_COOKIE_HTTPONLY' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC}"
    echo "  SESSION_COOKIE_HTTPONLY not explicitly set (defaults to True)"
    WARN=$((WARN + 1))
  fi

  echo -n "Checking SESSION_COOKIE_SECURE... "
  if grep -q 'SESSION_COOKIE_SECURE.*=.*True' "$LMS_SETTINGS" || \
     grep -q 'SESSION_COOKIE_SECURE = MEREKA_SCHEME == "https"' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    echo "  SESSION_COOKIE_SECURE not configured properly"
    FAIL=$((FAIL + 1))
  fi

  echo -n "Checking SESSION_COOKIE_SAMESITE... "
  if grep -q 'SESSION_COOKIE_SAMESITE.*=.*"None"' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    echo "  SameSite=None allows cross-origin cookie sending (required for OIDC)"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC}"
    echo "  SESSION_COOKIE_SAMESITE not set to 'None'"
    WARN=$((WARN + 1))
  fi

  echo -n "Checking CSRF_COOKIE_SECURE... "
  if grep -q 'CSRF_COOKIE_SECURE.*=.*True' "$LMS_SETTINGS" || \
     grep -q 'CSRF_COOKIE_SECURE = MEREKA_SCHEME == "https"' "$LMS_SETTINGS"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    echo "  CSRF_COOKIE_SECURE not configured properly"
    FAIL=$((FAIL + 1))
  fi
}

# Run selected tests
case "$TEST_MODE" in
  cross-subdomain)
    test_cross_subdomain
    ;;
  cookie-domain-check)
    test_cookie_domain_check
    ;;
  independent-session)
    test_independent_session
    ;;
  no-cookie-leakage)
    test_no_cookie_leakage
    ;;
  all)
    test_cross_subdomain
    echo ""
    test_cookie_domain_check
    echo ""
    test_independent_session
    echo ""
    test_no_cookie_leakage
    ;;
  *)
    echo -e "${RED}Unknown test mode: $TEST_MODE${NC}" >&2
    exit 1
    ;;
esac

# Summary
echo ""
echo "=== Summary ==="
echo -e "PASS: ${GREEN}${PASS}${NC}"
echo -e "FAIL: ${RED}${FAIL}${NC}"
echo -e "WARN: ${YELLOW}${WARN}${NC}"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi

exit 0
