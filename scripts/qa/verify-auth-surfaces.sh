#!/usr/bin/env bash
# Verify that authentication entrypoints exist and redirect as expected.
#
# This script is designed to run without credentials and can run in CI.
#
# Checks:
# - LMS OIDC entrypoint redirects to Authentik authorize URL
# - Discovery/Credentials/Ecommerce /login redirects to /login/edx-oauth2/
# - MFE config endpoint is reachable (used by MFEs for auth + backend wiring)
# - (Optional hardening) /admin/login redirects to /login (SSO entrypoint)
#
# Usage:
#   ./scripts/qa/verify-auth-surfaces.sh prod
#   ./scripts/qa/verify-auth-surfaces.sh dev
#
# Optional:
#   STRICT_ADMIN_LOGIN_REDIRECT=1  # fail if /admin/login doesn't redirect to /login

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENVIRONMENT="${1:-}"
if [[ -z "$ENVIRONMENT" || ( "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ) ]]; then
  echo "Usage: $0 {prod|dev}" >&2
  exit 1
fi

STRICT_ADMIN_LOGIN_REDIRECT="${STRICT_ADMIN_LOGIN_REDIRECT:-0}"
if [[ "$ENVIRONMENT" == "prod" ]]; then
  REQUIRE_OIDC_PKCE="${REQUIRE_OIDC_PKCE:-1}"
else
  REQUIRE_OIDC_PKCE="${REQUIRE_OIDC_PKCE:-0}"
fi

failures=0

log_ok() { printf "✓ %s\n" "$*"; }
log_fail() { printf "✗ %s\n" "$*" >&2; failures=$((failures + 1)); }
log_warn() { printf "! %s\n" "$*" >&2; }

curl_loc() {
  # Prints "code location"
  local url="$1"
  local method="${2:-HEAD}"
  local out code loc
  if [[ "$method" == "HEAD" ]]; then
    out="$(curl -sS -I "$url" || true)"
  else
    # Use GET to exercise middleware redirects (some stacks don't redirect on HEAD).
    out="$(curl -sS -D - "$url" -o /dev/null || true)"
  fi
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

require_status() {
  local url="$1"
  local label="$2"
  local expected="$3"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || echo "000")"
  if [[ "$code" == "$expected" ]]; then
    log_ok "$label ($code)"
  else
    log_fail "$label (expected $expected, got $code) url=$url"
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

require_authentik_accepts_authorize_url() {
  local start_url="$1"
  local label="$2"

  local code loc auth_code
  read -r code loc < <(curl_loc "$start_url")
  if [[ "$code" != "302" || "$loc" != https://auth0.mereka.io/* ]]; then
    log_fail "$label (expected 302 -> Authentik authorize, got code=$code loc=$loc) url=$start_url"
    return 1
  fi

  auth_code="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 15 "$loc" || echo "000")"
  if [[ "$auth_code" == "200" || "$auth_code" == "302" || "$auth_code" == "303" ]]; then
    log_ok "$label (Authentik authorize accepts redirect_uri: $auth_code)"
    return 0
  fi

  log_fail "$label (Authentik authorize rejected redirect_uri: $auth_code) url=$loc"
  return 1
}

expected_cookie_domain_for_host() {
  local host="${1,,}"
  local tenant="$host"

  for prefix in apps. studio. preview.; do
    if [[ "$tenant" == "$prefix"* ]]; then
      tenant="${tenant#"$prefix"}"
      break
    fi
  done

  if [[ "$tenant" == *"biji-biji.com" ]]; then
    printf ".biji-biji.com\n"
    return 0
  fi

  printf ".%s\n" "$tenant"
}

require_oidc_session_cookie_domain() {
  local url="$1"
  local label="$2"
  local host="$3"
  local expected cookie_headers cookie_line cookie_line_lc

  expected="$(expected_cookie_domain_for_host "$host" | tr '[:upper:]' '[:lower:]')"
  cookie_headers="$(curl -sS -D - -o /dev/null "$url" || true)"
  cookie_line="$(
    printf "%s\n" "$cookie_headers" \
      | awk 'tolower($1)=="set-cookie:" && tolower($2) ~ /^sessionid=/{print; exit}'
  )"

  if [[ -z "$cookie_line" ]]; then
    log_fail "$label (missing Set-Cookie for sessionid) url=$url"
    return 1
  fi

  cookie_line_lc="$(printf "%s" "$cookie_line" | tr '[:upper:]' '[:lower:]')"
  if [[ "$cookie_line_lc" == *"domain=${expected}"* ]]; then
    log_ok "$label (session cookie domain=${expected})"
  else
    log_fail "$label (expected session cookie domain=${expected}, got: $cookie_line) url=$url"
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

require_body_contains() {
  local url="$1"
  local label="$2"
  local needle="$3"
  local body
  body="$(curl -sS "$url" || true)"
  if [[ -n "$body" && "$body" == *"$needle"* ]]; then
    log_ok "$label (contains '$needle')"
  else
    log_fail "$label (expected body contains '$needle') url=$url"
  fi
}

check_studio_signin_redirect() {
  local studio_host="$1"
  local expected_lms_host="$2"
  local url="https://${studio_host}/signin"
  local code loc
  read -r code loc < <(curl_loc "$url")
  if [[ "$code" == "302" && "$loc" == https://"${expected_lms_host}"/login* ]]; then
    log_ok "${studio_host}: /signin redirects to ${expected_lms_host}/login"
  else
    log_fail "${studio_host}: /signin does not redirect to ${expected_lms_host}/login (code=$code loc=$loc) url=$url"
  fi
}

check_studio_home_next_scheme() {
  local studio_host="$1"
  local url="https://${studio_host}/"
  local body
  body="$(curl -sS "$url" || true)"
  if [[ -z "$body" ]]; then
    log_fail "${studio_host}: Studio home page not reachable"
    return 1
  fi

  # If Studio thinks it's behind HTTP, it generates login/register links like:
  #   /login/?next=http%3A%2F%2Fstudio...
  # This breaks Secure cookie flows (OAuth state cookies won't persist reliably).
  if [[ "$body" == *"next=http%3A%2F%2F${studio_host}"* ]]; then
    log_fail "${studio_host}: Studio home page contains insecure next=http:// links (proxy forwarded-proto drift)"
    return 1
  fi

  log_ok "${studio_host}: Studio home page next= links do not use http://"
  return 0
}

check_admin_login_redirect() {
  local svc="$1"
  local base="$2"
  local url="https://${svc}.${base}/admin/login/?next=/admin/"
  local code loc
  read -r code loc < <(curl_loc "$url" "GET")

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

if [[ "$ENVIRONMENT" == "prod" ]]; then
  LMS_DOMAINS=("$LMS_DOMAIN" "$BIJI_DOMAIN" "$SKILLOURFUTURE_DOMAIN")
  LMS_ALIAS_DOMAINS=("$PREVIEW_DOMAIN")
  STUDIO_HOSTS=("studio.${LMS_DOMAIN}" "$BIJI_STUDIO_DOMAIN")
  MFE_HOSTS=("apps.${LMS_DOMAIN}" "$BIJI_MFE_DOMAIN")
  ECOSYSTEM_BASE="$LMS_DOMAIN"
else
  LMS_DOMAINS=("$DEV_LMS_DOMAIN")
  LMS_ALIAS_DOMAINS=("$DEV_PREVIEW_DOMAIN")
  STUDIO_HOSTS=("studio.${DEV_LMS_DOMAIN}")
  MFE_HOSTS=("apps.${DEV_LMS_DOMAIN}")
  ECOSYSTEM_BASE="$DEV_LMS_DOMAIN"
fi

echo "Environment: $ENVIRONMENT"
echo "LMS domains: ${LMS_DOMAINS[*]}"

# LMS OIDC SSO entrypoint must work on all served LMS domains.
for domain in "${LMS_DOMAINS[@]}"; do
  require_302_location_contains \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: LMS OIDC entrypoint" \
    "auth0.mereka.io/application/o/authorize/"

  # Make sure redirect_uri is aligned with the domain we're testing.
  require_302_location_contains \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: OIDC redirect_uri matches domain" \
    "redirect_uri=https://${domain}/auth/complete/oidc/"

  if [[ "$REQUIRE_OIDC_PKCE" == "1" ]]; then
    require_302_location_contains \
      "https://${domain}/auth/login/oidc/" \
      "${domain}: OIDC PKCE code_challenge_method present" \
      "code_challenge_method="
    require_302_location_contains \
      "https://${domain}/auth/login/oidc/" \
      "${domain}: OIDC PKCE code_challenge present" \
      "code_challenge="
  fi

  # Make sure Authentik actually accepts the authorize request for this redirect_uri.
  require_authentik_accepts_authorize_url \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: Authentik authorize validates redirect_uri"

  require_oidc_session_cookie_domain \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: OIDC session cookie domain" \
    "$domain"
done

# LMS aliases (same stack, extra hostnames) must also support OIDC.
for domain in "${LMS_ALIAS_DOMAINS[@]}"; do
  require_302_location_contains \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: LMS OIDC entrypoint (alias)" \
    "auth0.mereka.io/application/o/authorize/"

  require_302_location_contains \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: OIDC redirect_uri matches domain (alias)" \
    "redirect_uri=https://${domain}/auth/complete/oidc/"

  if [[ "$REQUIRE_OIDC_PKCE" == "1" ]]; then
    require_302_location_contains \
      "https://${domain}/auth/login/oidc/" \
      "${domain}: OIDC PKCE code_challenge_method present (alias)" \
      "code_challenge_method="
    require_302_location_contains \
      "https://${domain}/auth/login/oidc/" \
      "${domain}: OIDC PKCE code_challenge present (alias)" \
      "code_challenge="
  fi

  require_authentik_accepts_authorize_url \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: Authentik authorize validates redirect_uri (alias)"

  require_oidc_session_cookie_domain \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: OIDC session cookie domain (alias)" \
    "$domain"
done

# Studio does not implement /auth/login/oidc/; it should bounce to the correct LMS /login.
if [[ "$ENVIRONMENT" == "prod" ]]; then
  check_studio_signin_redirect "studio.${LMS_DOMAIN}" "$LMS_DOMAIN"
  check_studio_signin_redirect "$BIJI_STUDIO_DOMAIN" "$BIJI_DOMAIN"
  check_studio_home_next_scheme "studio.${LMS_DOMAIN}"
  check_studio_home_next_scheme "$BIJI_STUDIO_DOMAIN"
else
  check_studio_signin_redirect "studio.${DEV_LMS_DOMAIN}" "$DEV_LMS_DOMAIN"
  check_studio_home_next_scheme "studio.${DEV_LMS_DOMAIN}"
fi

# MFE login should be reachable on all configured MFE hosts.
for mfe in "${MFE_HOSTS[@]}"; do
  require_200 "https://${mfe}/authn/login" "${mfe}: Authn MFE login"
  require_200 "https://${mfe}/api/mfe_config/v1" "${mfe}: MFE config endpoint"
done

# MFE config must be site-correct (prevents SSO/login drift across microsites).
require_body_contains \
  "https://apps.${ECOSYSTEM_BASE}/api/mfe_config/v1" \
  "Primary MFE config LMS_BASE_URL" \
  "\"LMS_BASE_URL\": \"https://${ECOSYSTEM_BASE}\""

if [[ "$ENVIRONMENT" == "prod" ]]; then
  require_body_contains \
    "https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1" \
    "Biji MFE config LMS_BASE_URL" \
    "\"LMS_BASE_URL\": \"https://${BIJI_DOMAIN}\""
  require_body_contains \
    "https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1" \
    "Biji MFE config STUDIO_BASE_URL" \
    "\"STUDIO_BASE_URL\": \"https://${BIJI_STUDIO_DOMAIN}\""
fi

for svc in discovery credentials ecommerce; do
  require_302_location_is \
    "https://${svc}.${ECOSYSTEM_BASE}/login/" \
    "${svc}: /login SSO entrypoint" \
    "/login/edx-oauth2/"

  # Verify OAuth handshake starts towards the LMS (which itself uses Authentik OIDC).
  require_302_location_contains \
    "https://${svc}.${ECOSYSTEM_BASE}/login/edx-oauth2/" \
    "${svc}: /login/edx-oauth2 redirects to LMS oauth2/authorize" \
    "https://${ECOSYSTEM_BASE}/oauth2/authorize"
done

for svc in discovery credentials ecommerce; do
  check_admin_login_redirect "$svc" "$ECOSYSTEM_BASE"
done

# Notes and forum are API-first. They do not have their own SSO entrypoints.
# We still verify they are reachable so operators don't misdiagnose outages as "SSO missing".
require_body_contains \
  "https://notes.${ECOSYSTEM_BASE}/" \
  "notes: API banner" \
  "edX Notes API"

# Forum service returns 401 when unauthenticated (expected).
require_status \
  "https://forum.${ECOSYSTEM_BASE}/" \
  "forum: unauthenticated response" \
  "401"

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "FAILED ($failures checks failed)" >&2
  exit 1
fi

echo ""
echo "OK"
