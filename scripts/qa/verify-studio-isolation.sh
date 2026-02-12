#!/usr/bin/env bash
# @covers AC-006
# @spec: multi-site-domains_spec.md
# Verify Studio (CMS) is only accessible on studio.* subdomains.
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
INGRESS_STUDIO_PROD="${REPO_ROOT}/deploy/k8s/overlays/production/ingress-openedx-studio.yaml"

echo "=== Studio Isolation Verification ==="
echo ""

# Test 1: Caddyfile routes CMS only to studio.* domains
echo "Checking Caddyfile for Studio routing..."
echo ""

echo -n "Checking studio.academyv2.mereka.io routes to cms:8000... "
if grep -q 'studio.academyv2.mereka.io' "$CADDYFILE" && \
   grep -A 10 'studio.academyv2.mereka.io' "$CADDYFILE" | grep -q 'proxy "cms:8000"'; then
  echo -e "${GREEN}PASS${NC}"
  PASS=$((PASS + 1))
else
  echo -e "${RED}FAIL${NC}"
  echo "  Studio domain not found or not routing to cms:8000"
  FAIL=$((FAIL + 1))
fi

echo -n "Checking studio.academyv2.mereka.dev routes to cms:8000... "
if grep -q 'studio.academyv2.mereka.dev' "$CADDYFILE" && \
   grep -A 10 'studio.academyv2.mereka.dev' "$CADDYFILE" | grep -q 'proxy "cms:8000"'; then
  echo -e "${GREEN}PASS${NC}"
  PASS=$((PASS + 1))
else
  echo -e "${YELLOW}WARN${NC}"
  echo "  Dev studio domain not found (may be local-only)"
  WARN=$((WARN + 1))
fi

echo -n "Checking studio.academy.biji-biji.com routes to cms:8000... "
if grep -q 'studio.academy.biji-biji.com' "$CADDYFILE" && \
   grep -A 10 'studio.academy.biji-biji.com' "$CADDYFILE" | grep -q 'proxy "cms:8000"'; then
  echo -e "${GREEN}PASS${NC}"
  PASS=$((PASS + 1))
else
  echo -e "${YELLOW}WARN${NC}"
  echo "  Biji-Biji studio domain not found in Caddyfile"
  WARN=$((WARN + 1))
fi

# Test 2: Non-studio domains do NOT route to cms
echo ""
echo "Checking non-studio domains do NOT route to cms:8000..."
echo ""

NON_STUDIO_DOMAINS=(
  "academyv2.mereka.io"
  "apps.academyv2.mereka.io"
  "academy.biji-biji.com"
)

for domain in "${NON_STUDIO_DOMAINS[@]}"; do
  echo -n "Checking $domain does not route to cms... "
  # Find the line containing this domain (it may be in a comma-separated list)
  # Then extract the block and check if it routes to cms:8000

  # Search for lines with the domain, excluding studio/discovery/ecommerce/notes/credentials/admin/enterprise subdomains
  line_num=$(grep -n "http://${domain}" "$CADDYFILE" | grep -v "studio\.${domain}" | grep -v "apps\.${domain}" | grep -v "discovery\.${domain}" | grep -v "ecommerce\.${domain}" | grep -v "notes\.${domain}" | grep -v "credentials\.${domain}" | grep -v "admin\.${domain}" | grep -v "enterprise\.${domain}" | head -1 | cut -d: -f1)

  if [[ -n "$line_num" ]]; then
    # Get the block (from line_num to closing brace)
    block=$(sed -n "${line_num},/^}/p" "$CADDYFILE")
    if echo "$block" | grep -q 'proxy "cms:8000"'; then
      echo -e "${RED}FAIL${NC}"
      echo "  $domain incorrectly routes to cms:8000"
      FAIL=$((FAIL + 1))
    else
      echo -e "${GREEN}PASS${NC}"
      PASS=$((PASS + 1))
    fi
  else
    echo -e "${YELLOW}WARN${NC}"
    echo "  $domain not found in Caddyfile"
    WARN=$((WARN + 1))
  fi
done

# Test 3: Ingress for Studio has correct host rules
echo ""
echo "Checking Studio Ingress configuration..."
echo ""

if [[ -f "$INGRESS_STUDIO_PROD" ]]; then
  echo -n "Checking studio.academyv2.mereka.io in Ingress... "
  if grep -q 'studio.academyv2.mereka.io' "$INGRESS_STUDIO_PROD"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${RED}FAIL${NC}"
    echo "  studio.academyv2.mereka.io not found in Studio Ingress"
    FAIL=$((FAIL + 1))
  fi

  echo -n "Checking Ingress service target is caddy... "
  if grep -A 5 'service:' "$INGRESS_STUDIO_PROD" | grep -q 'name: caddy'; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
  else
    echo -e "${YELLOW}WARN${NC}"
    echo "  Ingress service target may not be caddy"
    WARN=$((WARN + 1))
  fi
else
  echo -e "${YELLOW}WARN${NC}"
  echo "  Studio Ingress file not found: $INGRESS_STUDIO_PROD"
  WARN=$((WARN + 1))
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
