#!/usr/bin/env bash
# Verify that authentication entrypoints exist and redirect as expected.
#
# This script is designed to run without credentials and can run in CI.
#
# Checks:
# - LMS OIDC entrypoint redirects to Authentik authorize URL
# - Discovery/Credentials/Ecommerce /login redirects to /login/edx-oauth2/
# - (Optional hardening) /admin/login redirects to /login (SSO entrypoint)
#
# Usage:
#   ./scripts/qa/verify-auth-surfaces.sh prod
#   ./scripts/qa/verify-auth-surfaces.sh dev
#
# Optional:
#   STRICT_ADMIN_LOGIN_REDIRECT=1  # fail if /admin/login doesn't redirect to /login

set -euo pipefail

ENVIRONMENT="${1:-}"
if [[ -z "$ENVIRONMENT" || ( "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ) ]]; then
  echo "Usage: $0 {prod|dev}" >&2
  exit 1
fi

STRICT_ADMIN_LOGIN_REDIRECT="${STRICT_ADMIN_LOGIN_REDIRECT:-0}"

if [[ "$ENVIRONMENT" == "prod" ]]; then
  LMS_BASE="academyv2.mereka.io"
elif [[ "$ENVIRONMENT" == "dev" ]]; then
  LMS_BASE="academyv2.mereka.dev"
fi

failures=0

log_ok() { printf "✓ %s\n" "$*"; }
log_fail() { printf "✗ %s\n" "$*" >&2; failures=$((failures + 1)); }
log_warn() { printf "! %s\n" "$*" >&2; }

curl_loc() {
  # Prints "code location"
  local url="$1"
  local out code loc
  out="$(curl -sS -I "$url" || true)"
  code="$(printf "%s\n" "$out" | awk 'NR==1 {print $2}')"
  loc="$(printf "%s\n" "$out" | awk -F': ' 'tolower($1)=="location" {print $2}' | tr -d '\r' | head -n 1)"
  printf "%s %s\n" "${code:-000}" "${loc:-}"
}

require_200() {
  local url="$1"
  local label="$2"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || echo "000")"
  if [[ "$code" == "200" ]]; then
    log_ok "$label ($code)"
  else
    log_fail "$label ($code) url=$url"
  fi
}

require_302_location_contains() {
  local url="$1"
  local label="$2"
  local needle="$3"
  local code loc
  read -r code loc < <(curl_loc "$url")
  if [[ "$code" == "302" && "$loc" == *"$needle"* ]]; then
    log_ok "$label (302 -> contains '$needle')"
  else
    log_fail "$label (expected 302 + location contains '$needle', got code=$code loc=$loc) url=$url"
  fi
}

require_302_location_is() {
  local url="$1"
  local label="$2"
  local expected="$3"
  local code loc
  read -r code loc < <(curl_loc "$url")
  if [[ "$code" == "302" && "$loc" == "$expected" ]]; then
    log_ok "$label (302 -> $expected)"
  else
    log_fail "$label (expected 302 -> $expected, got code=$code loc=$loc) url=$url"
  fi
}

check_admin_login_redirect() {
  local svc="$1"
  local base="$2"
  local url="https://${svc}.${base}/admin/login/?next=/admin/"
  local code loc
  read -r code loc < <(curl_loc "$url")

  if [[ "$code" == "302" && "$loc" == /login/* ]]; then
    log_ok "${svc}: /admin/login redirects to SSO (/login)"
    return 0
  fi

  if [[ "$STRICT_ADMIN_LOGIN_REDIRECT" == "1" ]]; then
    log_fail "${svc}: /admin/login does not redirect to /login (code=$code loc=$loc) url=$url"
    return 1
  fi

  log_warn "${svc}: /admin/login does not redirect to /login yet (code=$code loc=$loc). This is OK if hardening not deployed."
  return 0
}

echo "Environment: $ENVIRONMENT (LMS base: $LMS_BASE)"

# LMS OIDC SSO entrypoint.
require_302_location_contains \
  "https://${LMS_BASE}/auth/login/oidc/" \
  "LMS OIDC entrypoint" \
  "auth0.mereka.io/application/o/authorize/"

# MFE login should be reachable.
require_200 \
  "https://apps.${LMS_BASE}/authn/login" \
  "Authn MFE login"

for svc in discovery credentials ecommerce; do
  require_302_location_is \
    "https://${svc}.${LMS_BASE}/login/" \
    "${svc}: /login SSO entrypoint" \
    "/login/edx-oauth2/"
done

for svc in discovery credentials ecommerce; do
  check_admin_login_redirect "$svc" "$LMS_BASE"
done

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "FAILED ($failures checks failed)" >&2
  exit 1
fi

echo ""
echo "OK"
