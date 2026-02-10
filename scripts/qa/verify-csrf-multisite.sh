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

# Expected domains
EXPECTED_DOMAINS=(
  "https://academyv2.mereka.io"
  "https://studio.academyv2.mereka.io"
  "https://apps.academyv2.mereka.io"
  "https://academy.biji-biji.com"
  "https://apps.academy.biji-biji.com"
  "https://skillourfuture.academy.mereka.io"
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
    ((FAIL++))
    return 1
  fi

  # Extract origins (multi-line aware)
  CSRF_ORIGINS=$(python3 -c "
import re
with open('$LMS_SETTINGS', 'r') as f:
    content = f.read()
    # Find CSRF_TRUSTED_ORIGINS.append() calls
    matches = re.findall(r'CSRF_TRUSTED_ORIGINS\.append\([\"']([^\"']+)[\"']\)', content)
    for m in matches:
        print(m)
" 2>/dev/null || echo "")

  if [[ -z "$CSRF_ORIGINS" ]]; then
    echo -e "${YELLOW}WARN${NC}: Could not extract CSRF_TRUSTED_ORIGINS from LMS settings"
    ((WARN++))
    return 1
  fi

  echo "Configured CSRF_TRUSTED_ORIGINS:"
  echo "$CSRF_ORIGINS" | while read -r origin; do
    echo "  - $origin"
  done
  echo ""
}

# Check if all expected domains are present
check_expected_domains() {
  MISSING=()
  for domain in "${EXPECTED_DOMAINS[@]}"; do
    echo -n "Checking $domain... "
    if grep -q "$domain" "$LMS_SETTINGS"; then
      echo -e "${GREEN}PASS${NC}"
      ((PASS++))
    else
      echo -e "${RED}FAIL${NC}"
      MISSING+=("$domain")
      ((FAIL++))
    fi
  done

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}Missing CSRF origins:${NC}"
    for domain in "${MISSING[@]}"; do
      echo "  - $domain"
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
