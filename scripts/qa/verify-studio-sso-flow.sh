#!/usr/bin/env bash
# @spec: auth-sso-enterprise_spec.md
# @covers AC-SSO-BYPASS-001, AC-SSO-BYPASS-002, AC-SSO-BYPASS-003, AC-SSO-BYPASS-004
# Verify Studio SSO bypass middleware behavior (ADR-013).
# Usage: ./scripts/qa/verify-studio-sso-flow.sh [domain]
set -euo pipefail

DOMAIN="${1:-academyv2.mereka.io}"
if [[ "$DOMAIN" == *.mereka.dev ]]; then
  AUTHENTIK_DOMAIN="auth0.mereka.dev"
elif [[ "$DOMAIN" == staging.*.mereka.io || "$DOMAIN" == *.staging.academyv2.mereka.io ]]; then
  AUTHENTIK_DOMAIN="staging.auth0.mereka.io"
else
  AUTHENTIK_DOMAIN="auth0.mereka.io"
fi
PASS=0
FAIL=0

check() {
  local label="$1"
  local url="$2"
  local expect_pattern="$3"

  local redirect
  redirect="$(curl -sS -o /dev/null -w '%{redirect_url}' "$url")"

  if echo "$redirect" | grep -qE "$expect_pattern"; then
    echo "PASS  $label"
    echo "      -> $redirect"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $label"
    echo "      expected pattern: $expect_pattern"
    echo "      got: $redirect"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Studio SSO Bypass Verification ==="
echo "Domain: $DOMAIN"
echo ""

# @covers AC-SSO-BYPASS-001
# Test 1: /login?next=/oauth2/authorize... should preserve the OAuth intent
# through the tenant MFE authn entrypoint rather than leaking cross-tenant.
check "OAuth login preserves tenant MFE authn path" \
  "https://${DOMAIN}/login?next=/oauth2/authorize%3Fclient_id%3Dcms-sso%26response_type%3Dcode" \
  "apps\.${DOMAIN}/authn/login\\?next=%2Foauth2%2Fauthorize"

# @covers AC-SSO-BYPASS-002
# Test 2: /login (no next param) should redirect to MFE authn as usual
check "Plain login goes to MFE authn" \
  "https://${DOMAIN}/login" \
  "apps\.${DOMAIN}/authn"

# @covers AC-SSO-BYPASS-003
# Test 3: /login?next=/dashboard should redirect to MFE authn (not bypassed)
check "Non-OAuth next goes to MFE authn" \
  "https://${DOMAIN}/login?next=/dashboard" \
  "apps\.${DOMAIN}/authn"

# @covers AC-SSO-BYPASS-004
# Test 4: Full chain trace - Studio login initiates OAuth flow
# The /auth/login/oidc/ redirect should ultimately point to Authentik
echo ""
echo "--- Full chain trace ---"
OIDC_URL="$(curl -sS -o /dev/null -w '%{redirect_url}' \
  "https://${DOMAIN}/auth/login/oidc/?next=/oauth2/authorize%3Fclient_id%3Dcms-sso")"

if echo "$OIDC_URL" | grep -qE "${AUTHENTIK_DOMAIN//./\\.}/application/o/authorize"; then
  echo "PASS  OIDC redirects to Authentik"
  echo "      -> ${OIDC_URL:0:120}..."
  PASS=$((PASS + 1))
else
  echo "FAIL  OIDC should redirect to Authentik"
  echo "      got: $OIDC_URL"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
