#!/usr/bin/env bash
# Test script to verify the MFE OAuth fix is working

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default domain
DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
URL="https://${DOMAIN}/api/mfe_context"

echo "Testing MFE OAuth fix..."
echo "URL: $URL"
echo ""

# Fetch the endpoint
echo "Fetching /api/mfe_context..."
RESPONSE=$(curl -s "$URL")

# Check if request was successful
if [ -z "$RESPONSE" ]; then
  echo -e "${RED}✗ Failed to fetch endpoint${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Successfully fetched endpoint${NC}"
echo ""

# Parse the response
PROVIDERS=$(echo "$RESPONSE" | jq -r '.contextData.providers // []')
PROVIDER_COUNT=$(echo "$PROVIDERS" | jq 'length')

echo "Provider count: $PROVIDER_COUNT"
echo ""

if [ "$PROVIDER_COUNT" -eq 0 ]; then
  echo -e "${RED}✗ FAIL: Providers array is empty${NC}"
  echo ""
  echo "Full response:"
  echo "$RESPONSE" | jq '.'
  exit 1
fi

echo -e "${GREEN}✓ PASS: Found $PROVIDER_COUNT provider(s)${NC}"
echo ""

# Display providers
echo "Providers:"
echo "$PROVIDERS" | jq -r '.[] | "  - \(.name) (id: \(.id))"'
echo ""

# Display full provider details
echo "Full provider details:"
echo "$PROVIDERS" | jq '.'
echo ""

# Check for the branded provider label
MEREKA_PROVIDER=$(echo "$PROVIDERS" | jq -r '.[] | select(.name == "Mereka")')
if [ -n "$MEREKA_PROVIDER" ]; then
  echo -e "${GREEN}✓ Mereka provider found${NC}"
  PROVIDER_ID=$(echo "$MEREKA_PROVIDER" | jq -r '.id')
  PROVIDER_LOGIN_URL=$(echo "$MEREKA_PROVIDER" | jq -r '.loginUrl')
  echo "  ID: $PROVIDER_ID"
  echo "  Login URL: $PROVIDER_LOGIN_URL"
else
  AUTHENTIK_PROVIDER=$(echo "$PROVIDERS" | jq -r '.[] | select(.name == "Authentik")')
  if [ -n "$AUTHENTIK_PROVIDER" ]; then
    echo -e "${YELLOW}⚠ Authentik provider found (display name not updated)${NC}"
    PROVIDER_ID=$(echo "$AUTHENTIK_PROVIDER" | jq -r '.id')
    PROVIDER_LOGIN_URL=$(echo "$AUTHENTIK_PROVIDER" | jq -r '.loginUrl')
    echo "  ID: $PROVIDER_ID"
    echo "  Login URL: $PROVIDER_LOGIN_URL"
  else
    echo -e "${YELLOW}⚠ Branded OAuth provider not found${NC}"
  fi
fi

echo ""
echo -e "${GREEN}✓ All tests passed!${NC}"
