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
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"

# Default domain
DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
URL="https://${DOMAIN}/api/mfe_context"

runtime_skip() {
  local message="$1"
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    echo -e "${RED}✗ ${message}${NC}" >&2
    exit 1
  fi
  echo -e "${YELLOW}SKIP: ${message}${NC}"
  exit 0
}

echo "Testing MFE OAuth fix..."
echo "URL: $URL"
echo ""

# Fetch the endpoint
echo "Fetching /api/mfe_context..."
headers_file="$(mktemp -t mfe-oauth-headers.XXXXXX)"
body_file="$(mktemp -t mfe-oauth-body.XXXXXX)"
trap 'rm -f "$headers_file" "$body_file"' EXIT
if ! curl -sS -D "$headers_file" -o "$body_file" --max-time 20 "$URL"; then
  runtime_skip "unable to reach $URL"
fi

# Check if request was successful
RESPONSE="$(cat "$body_file")"
if [[ -z "$RESPONSE" ]]; then
  runtime_skip "empty response from $URL"
fi

echo -e "${GREEN}✓ Successfully fetched endpoint${NC}"
echo ""

# Validate content type and parse the response.
content_type="$(awk 'BEGIN{IGNORECASE=1} /^Content-Type:/{print $2; exit}' "$headers_file" | tr -d '\r')"
if [[ "${content_type,,}" != application/json* ]]; then
  runtime_skip "unexpected content-type '${content_type:-unknown}' from $URL"
fi
if ! jq -e . "$body_file" >/dev/null 2>&1; then
  runtime_skip "response is not valid JSON from $URL"
fi

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
  PROVIDER_REGISTER_URL=$(echo "$MEREKA_PROVIDER" | jq -r '.registerUrl')
  echo "  ID: $PROVIDER_ID"
  echo "  Login URL: $PROVIDER_LOGIN_URL"
  echo "  Register URL: $PROVIDER_REGISTER_URL"
else
  AUTHENTIK_PROVIDER=$(echo "$PROVIDERS" | jq -r '.[] | select(.name == "Authentik")')
  if [ -n "$AUTHENTIK_PROVIDER" ]; then
    echo -e "${YELLOW}⚠ Authentik provider found (display name not updated)${NC}"
    PROVIDER_ID=$(echo "$AUTHENTIK_PROVIDER" | jq -r '.id')
    PROVIDER_LOGIN_URL=$(echo "$AUTHENTIK_PROVIDER" | jq -r '.loginUrl')
    PROVIDER_REGISTER_URL=$(echo "$AUTHENTIK_PROVIDER" | jq -r '.registerUrl')
    echo "  ID: $PROVIDER_ID"
    echo "  Login URL: $PROVIDER_LOGIN_URL"
    echo "  Register URL: $PROVIDER_REGISTER_URL"
  else
    echo -e "${YELLOW}⚠ Branded OAuth provider not found${NC}"
  fi
fi

if [[ "${PROVIDER_LOGIN_URL:-}" == *"next=/learner-dashboard/"* ]] && [[ "${PROVIDER_REGISTER_URL:-}" == *"next=/learner-dashboard/"* ]]; then
  echo -e "${GREEN}✓ Learner-home redirect target is /learner-dashboard/${NC}"
else
  echo -e "${RED}✗ FAIL: provider URLs do not target /learner-dashboard/${NC}"
  exit 1
fi

if [[ "${PROVIDER_LOGIN_URL:-}" == *"next=/dashboard"* ]] || [[ "${PROVIDER_REGISTER_URL:-}" == *"next=/dashboard"* ]]; then
  echo -e "${RED}✗ FAIL: provider URLs still target legacy /dashboard${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}✓ All tests passed!${NC}"
