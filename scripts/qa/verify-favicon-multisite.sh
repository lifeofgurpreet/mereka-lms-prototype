#!/usr/bin/env bash
# Verify favicon is configured for all multi-site domains.
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
THEME_ASSETS_DIR="${REPO_ROOT}/infrastructure/tutor/themes/mereka/lms/static/images"

echo "=== Favicon Multi-Site Verification ==="
echo ""

# Expected domains with favicon rewrites
EXPECTED_DOMAINS=(
  "localhost"
  "academyv2.mereka.io"
  "academyv2.mereka.dev"
  "academy.biji-biji.com"
  "skillourfuture.academy.mereka.io"
  "studio.academyv2.mereka.io"
  "studio.academyv2.mereka.dev"
  "studio.academy.biji-biji.com"
)

# Test 1: Check Caddyfile has favicon rewrite for each domain
echo "Checking Caddyfile favicon rewrites..."
echo ""

for domain in "${EXPECTED_DOMAINS[@]}"; do
  echo -n "Checking $domain favicon rewrite... "
  # Find domain block and check for favicon matcher + rewrite
  if grep -A 5 "$domain" "$CADDYFILE" | grep -q '@favicon_matcher' && \
     grep -A 5 "$domain" "$CADDYFILE" | grep -q 'rewrite @favicon_matcher /theming/asset/images/favicon.ico'; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
  else
    echo -e "${YELLOW}WARN${NC}"
    echo "  Favicon rewrite not found for $domain (may inherit from parent block)"
    ((WARN++))
  fi
done

# Test 2: Verify favicon file exists in theme assets
echo ""
echo -n "Checking favicon file exists in theme assets... "
if [[ -f "$THEME_ASSETS_DIR/favicon.ico" ]]; then
  echo -e "${GREEN}PASS${NC}"
  echo "  Found: $THEME_ASSETS_DIR/favicon.ico"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "  Favicon file not found: $THEME_ASSETS_DIR/favicon.ico"
  ((FAIL++))
fi

# Test 3: Count total favicon rewrite rules
echo ""
FAVICON_COUNT=$(grep -c '@favicon_matcher' "$CADDYFILE" || echo "0")
echo "Total favicon matchers found in Caddyfile: $FAVICON_COUNT"

if [[ $FAVICON_COUNT -ge 3 ]]; then
  echo -e "${GREEN}PASS${NC} (Found $FAVICON_COUNT favicon matchers)"
  ((PASS++))
else
  echo -e "${YELLOW}WARN${NC} (Expected at least 3, found $FAVICON_COUNT)"
  ((WARN++))
fi

# Test 4: Verify rewrite path is consistent
echo ""
echo -n "Checking favicon rewrite path is /theming/asset/images/favicon.ico... "
INCONSISTENT=$(grep -A 1 '@favicon_matcher' "$CADDYFILE" | grep 'rewrite' | \
  grep -v '/theming/asset/images/favicon.ico' | wc -l)
if [[ $INCONSISTENT -eq 0 ]]; then
  echo -e "${GREEN}PASS${NC}"
  ((PASS++))
else
  echo -e "${RED}FAIL${NC}"
  echo "  Found $INCONSISTENT inconsistent favicon rewrite paths"
  ((FAIL++))
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
