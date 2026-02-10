#!/usr/bin/env bash
# Verify request body size limits in Caddyfile.
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
CADDYFILE="${REPO_ROOT}/deploy/k8s/base/apps/caddy/Caddyfile"

echo "=== Body Limits Verification ==="
echo ""

# Test 1: Profile image upload has 1MB limit
echo -n "Checking profile image upload 1MB limit... "
if grep -A 3 '/api/profile_images/\*\/\*/upload' "$CADDYFILE" | grep -q 'max_size 1MB'; then
  echo -e "${GREEN}PASS${NC}"
  echo "  Found: request_body { max_size 1MB } for profile images"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "  Profile image upload limit not found or incorrect"
  ((FAIL++))
fi

# Test 2: General LMS/MFE requests have 4MB limit
echo ""
echo -n "Checking general LMS 4MB limit... "
# Look for general paths (/* or handle_path /*) with max_size 4MB
if grep -B 2 -A 2 'handle_path /\*' "$CADDYFILE" | grep -q 'max_size 4MB'; then
  echo -e "${GREEN}PASS${NC}"
  echo "  Found: request_body { max_size 4MB } for general paths"
  ((PASS++))
else
  echo -e "${YELLOW}WARN${NC}"
  echo "  General 4MB limit not found or may be configured differently"
  ((WARN++))
fi

echo -n "Checking MFE 2MB limit... "
# MFE apps typically have 2MB limit
if grep -B 3 'apps.localhost' "$CADDYFILE" | grep -q 'max_size 2MB' || \
   grep -A 3 'apps.academyv2.mereka.io' "$CADDYFILE" | grep -q 'max_size 2MB'; then
  echo -e "${GREEN}PASS${NC}"
  echo "  Found: request_body { max_size 2MB } for MFE"
  ((PASS++))
else
  echo -e "${YELLOW}WARN${NC}"
  echo "  MFE 2MB limit not found"
  ((WARN++))
fi

# Test 3: Studio has 250MB limit for course imports
echo ""
echo -n "Checking Studio 250MB limit for course imports... "
if grep -B 3 -A 3 'studio.academyv2.mereka.io' "$CADDYFILE" | grep -q 'max_size 250MB' || \
   grep -B 3 -A 3 'studio.localhost' "$CADDYFILE" | grep -q 'max_size 250MB'; then
  echo -e "${GREEN}PASS${NC}"
  echo "  Found: request_body { max_size 250MB } for Studio"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "  Studio 250MB limit not found"
  ((FAIL++))
fi

# Test 4: Count all max_size directives
echo ""
echo "Body limit summary from Caddyfile:"
grep -n 'max_size' "$CADDYFILE" | while IFS=: read -r line_num content; do
  echo "  Line $line_num: $content"
done

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
