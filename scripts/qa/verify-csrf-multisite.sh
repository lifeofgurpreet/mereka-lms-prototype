#!/usr/bin/env bash
# Verify CSRF trusted origins cover all multi-site domains.
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

# Expected code patterns that produce CSRF trusted origins.
# The production.py constructs URLs dynamically from MEREKA_* variables,
# so we check for the variable patterns rather than literal URLs.
EXPECTED_PATTERNS=(
  "MEREKA_LMS_BASE_URL"
  "MEREKA_STUDIO_BASE_URL"
  "MEREKA_MFE_BASE_URL"
  "MEREKA_BIJI_DOMAIN"
  "MEREKA_SKILLOURFUTURE_DOMAIN"
)

# Parse arguments
CHECK_ONLY=0
if [[ $# -gt 0 && "$1" == "--check-origins-only" ]]; then
  CHECK_ONLY=1
fi

echo "=== CSRF Multi-Site Verification ==="
echo ""

# Extract CSRF_TRUSTED_ORIGINS from LMS settings
extract_csrf_origins() {
  # Look for CSRF_TRUSTED_ORIGINS in LMS settings
  if ! grep -q 'CSRF_TRUSTED_ORIGINS' "$LMS_SETTINGS"; then
    echo -e "${RED}FAIL${NC}: CSRF_TRUSTED_ORIGINS not found in LMS settings"
    FAIL=$((FAIL + 1))
    return 1
  fi

  echo "CSRF_TRUSTED_ORIGINS references found in LMS settings:"
  grep -n 'CSRF_TRUSTED_ORIGINS' "$LMS_SETTINGS" | while read -r line; do
    echo "  $line"
  done
  echo ""
}

# Check if all expected code patterns are present in CSRF_TRUSTED_ORIGINS blocks
check_expected_domains() {
  MISSING=()
  # Extract lines referencing CSRF_TRUSTED_ORIGINS
  csrf_context=$(grep -B2 -A2 'CSRF_TRUSTED_ORIGINS' "$LMS_SETTINGS" 2>/dev/null || true)

  for pattern in "${EXPECTED_PATTERNS[@]}"; do
    echo -n "Checking CSRF origin for $pattern... "
    if echo "$csrf_context" | grep -q "$pattern"; then
      echo -e "${GREEN}PASS${NC}"
      PASS=$((PASS + 1))
    else
      echo -e "${RED}FAIL${NC}"
      MISSING+=("$pattern")
      FAIL=$((FAIL + 1))
    fi
  done

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Missing CSRF origin patterns:${NC}"
    for pattern in "${MISSING[@]}"; do
      echo "  - $pattern"
    done
  fi
}

# Main execution
if [[ $CHECK_ONLY -eq 1 ]]; then
  extract_csrf_origins
else
  extract_csrf_origins
  echo ""
  check_expected_domains
fi

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
