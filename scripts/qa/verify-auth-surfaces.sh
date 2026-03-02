#!/usr/bin/env bash
# @covers AC-042
# @spec: auth-sso-enterprise_spec.md
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
#   ./scripts/qa/verify-auth-surfaces.sh staging
#
# Optional:
#   STRICT_ADMIN_LOGIN_REDIRECT=1  # fail if /admin/login doesn't redirect to /login

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENVIRONMENT="${1:-}"
if [[ -z "$ENVIRONMENT" || ( "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "staging" ) ]]; then
  echo "Usage: $0 {prod|dev|staging}" >&2
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
host_resolves() { getent hosts "$1" >/dev/null 2>&1; }

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

http_diag() {
  # Prints one-line diagnostics for failing HTTP checks.
  local url="$1"
  local method="${2:-GET}"
  local header_file body_file status location ctype server req_id cf_ray body_head
  header_file="$(mktemp)"
  body_file="$(mktemp)"

  if [[ "$method" == "HEAD" ]]; then
    curl -sS -I -D "$header_file" "$url" -o /dev/null >/dev/null 2>&1 || true
  else
    curl -sS -X "$method" -D "$header_file" "$url" -o "$body_file" >/dev/null 2>&1 || true
  fi

  status="$(awk 'NR==1 {print $2}' "$header_file")"
  location="$(awk -F': ' 'tolower($1)=="location" {print $2}' "$header_file" | tr -d '\r' | head -n1)"
  ctype="$(awk -F': ' 'tolower($1)=="content-type" {print $2}' "$header_file" | tr -d '\r' | head -n1)"
  server="$(awk -F': ' 'tolower($1)=="server" {print $2}' "$header_file" | tr -d '\r' | head -n1)"
  req_id="$(awk -F': ' 'tolower($1)=="x-request-id" {print $2}' "$header_file" | tr -d '\r' | head -n1)"
  cf_ray="$(awk -F': ' 'tolower($1)=="cf-ray" {print $2}' "$header_file" | tr -d '\r' | head -n1)"
  body_head="$(head -c 180 "$body_file" 2>/dev/null | tr '\r\n' ' ' | sed 's/[[:space:]]\\+/ /g')"

  rm -f "$header_file" "$body_file"
  printf "diag{method=%s,status=%s,location=%s,content-type=%s,server=%s,x-request-id=%s,cf-ray=%s,body=%s}" \
    "${method:-GET}" "${status:-000}" "${location:--}" "${ctype:--}" "${server:--}" "${req_id:--}" "${cf_ray:--}" "${body_head:--}"
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
    log_fail "$label (expected $expected, got $code) url=$url $(http_diag "$url" "GET")"
  fi
}

require_status_one_of() {
  local url="$1"
  local label="$2"
  shift 2
  local code expected ok=0
  code="$(curl -sS -o /dev/null -w "%{http_code}" "$url" || echo "000")"
  for expected in "$@"; do
    if [[ "$code" == "$expected" ]]; then
      ok=1
      break
    fi
  done
  if [[ "$ok" -eq 1 ]]; then
    log_ok "$label ($code)"
  else
    log_fail "$label (expected one of: $*, got $code) url=$url $(http_diag "$url" "GET")"
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
    log_fail "$label (expected 302 + location contains '$needle', got code=$code loc=$loc) url=$url $(http_diag "$url" "GET")"
  fi
}

require_authentik_accepts_authorize_url() {
  local start_url="$1"
  local label="$2"

  local code loc auth_code
  read -r code loc < <(curl_loc "$start_url")
  if [[ "$code" != "302" || "$loc" != "https://${AUTHENTIK_DOMAIN_FOR_ENV}/"* ]]; then
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
  elif [[ "${ALLOW_HOST_ONLY_SESSION_COOKIE:-0}" == "1" && "$cookie_line_lc" != *"domain="* ]]; then
    log_ok "$label (host-only session cookie accepted for non-prod)"
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
    log_fail "$label (expected 302 -> $expected, got code=$code loc=$loc) url=$url $(http_diag "$url" "GET")"
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

require_body_contains_one_of() {
  local url="$1"
  local label="$2"
  shift 2
  local body needle
  body="$(curl -sS "$url" || true)"
  if [[ -z "$body" ]]; then
    log_fail "$label (empty response body) url=$url"
    return
  fi
  for needle in "$@"; do
    if [[ "$body" == *"$needle"* ]]; then
      log_ok "$label (contains '$needle')"
      return
    fi
  done
  log_fail "$label (expected body contains one of: $*) url=$url"
}

check_forum_health_contract() {
  local forum_host="$1"
  local heartbeat_url="https://${forum_host}/heartbeat"
  local healthz_url="https://${forum_host}/healthz"
  local heartbeat_code healthz_code

  heartbeat_code="$(curl -sS -o /dev/null -w "%{http_code}" "$heartbeat_url" || echo "000")"
  if [[ "$heartbeat_code" == "200" ]]; then
    log_ok "forum: heartbeat (200)"
    return
  fi

  if [[ "$ENVIRONMENT" != "prod" ]]; then
    healthz_code="$(curl -sS -o /dev/null -w "%{http_code}" "$healthz_url" || echo "000")"
    if [[ "$healthz_code" == "200" ]]; then
      log_warn "forum: /heartbeat returned ${heartbeat_code}; accepting /healthz=200 fallback for ${ENVIRONMENT}"
      log_ok "forum: health fallback (/healthz=200)"
      return
    fi
  fi

  log_fail "forum: heartbeat (expected 200, got ${heartbeat_code}) url=${heartbeat_url}"
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
  body="$(curl -sS -L --max-redirs 15 "$url" || true)"
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
    log_fail "${svc}: /admin/login does not redirect to /login (code=$code loc=$loc) url=$url $(http_diag "$url" "GET")"
    return 1
  fi

  log_warn "${svc}: /admin/login does not redirect to /login yet (code=$code loc=$loc). This is OK if hardening not deployed. $(http_diag "$url" "GET")"
  return 0
}

if [[ "$ENVIRONMENT" == "prod" ]]; then
  LMS_DOMAINS=("$LMS_DOMAIN" "$BIJI_DOMAIN" "$SKILLOURFUTURE_DOMAIN")
  LMS_ALIAS_DOMAINS=("$PREVIEW_DOMAIN")
  STUDIO_HOSTS=("studio.${LMS_DOMAIN}" "$BIJI_STUDIO_DOMAIN")
  MFE_HOSTS=("apps.${LMS_DOMAIN}" "$BIJI_MFE_DOMAIN")
  ECOSYSTEM_BASE="$LMS_DOMAIN"
  AUTHENTIK_DOMAIN_FOR_ENV="$AUTHENTIK_DOMAIN"
  ALLOW_HOST_ONLY_SESSION_COOKIE="${ALLOW_HOST_ONLY_SESSION_COOKIE:-0}"
elif [[ "$ENVIRONMENT" == "staging" ]]; then
  LMS_DOMAINS=("$STAGING_LMS_DOMAIN")
  LMS_ALIAS_DOMAINS=()
  STUDIO_HOSTS=("$STAGING_STUDIO_DOMAIN")
  MFE_HOSTS=("$STAGING_MFE_DOMAIN")
  ECOSYSTEM_BASE="$STAGING_LMS_DOMAIN"
  AUTHENTIK_DOMAIN_FOR_ENV="$STAGING_AUTHENTIK_DOMAIN"
  ALLOW_HOST_ONLY_SESSION_COOKIE="${ALLOW_HOST_ONLY_SESSION_COOKIE:-1}"
  ALLOW_UNRESOLVED_OPTIONAL_HOSTS="${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-1}"
else
  LMS_DOMAINS=("$DEV_LMS_DOMAIN")
  LMS_ALIAS_DOMAINS=("$DEV_PREVIEW_DOMAIN")
  STUDIO_HOSTS=("studio.${DEV_LMS_DOMAIN}")
  MFE_HOSTS=("apps.${DEV_LMS_DOMAIN}")
  ECOSYSTEM_BASE="$DEV_LMS_DOMAIN"
  AUTHENTIK_DOMAIN_FOR_ENV="$DEV_AUTHENTIK_DOMAIN"
  ALLOW_HOST_ONLY_SESSION_COOKIE="${ALLOW_HOST_ONLY_SESSION_COOKIE:-1}"
fi

echo "Environment: $ENVIRONMENT"
echo "LMS domains: ${LMS_DOMAINS[*]}"

# LMS OIDC SSO entrypoint must work on all served LMS domains.
for domain in "${LMS_DOMAINS[@]}"; do
  require_302_location_contains \
    "https://${domain}/auth/login/oidc/" \
    "${domain}: LMS OIDC entrypoint" \
    "${AUTHENTIK_DOMAIN_FOR_ENV}/application/o/authorize/"

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
    "${AUTHENTIK_DOMAIN_FOR_ENV}/application/o/authorize/"

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

  # Studio callback endpoint must never 500 (missing state should be handled gracefully).
  require_status_one_of \
    "https://studio.${LMS_DOMAIN}/complete/edx-oauth2/" \
    "studio.${LMS_DOMAIN}: /complete/edx-oauth2 does not 500" \
    "302" "400" "403" "404"
  require_status_one_of \
    "https://${BIJI_STUDIO_DOMAIN}/complete/edx-oauth2/" \
    "${BIJI_STUDIO_DOMAIN}: /complete/edx-oauth2 does not 500" \
    "302" "400" "403" "404"
elif [[ "$ENVIRONMENT" == "staging" ]]; then
  if host_resolves "$STAGING_STUDIO_DOMAIN"; then
    check_studio_signin_redirect "$STAGING_STUDIO_DOMAIN" "$STAGING_LMS_DOMAIN"
    check_studio_home_next_scheme "$STAGING_STUDIO_DOMAIN"
    require_status_one_of \
      "https://${STAGING_STUDIO_DOMAIN}/complete/edx-oauth2/" \
      "${STAGING_STUDIO_DOMAIN}: /complete/edx-oauth2 does not 500" \
      "302" "400" "403" "404"
  elif [[ "${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-0}" == "1" ]]; then
    log_warn "staging optional host unresolved: ${STAGING_STUDIO_DOMAIN} (skipping Studio checks)"
  else
    log_fail "staging required host unresolved: ${STAGING_STUDIO_DOMAIN}"
  fi
else
  check_studio_signin_redirect "studio.${DEV_LMS_DOMAIN}" "$DEV_LMS_DOMAIN"
  check_studio_home_next_scheme "studio.${DEV_LMS_DOMAIN}"

  require_status_one_of \
    "https://studio.${DEV_LMS_DOMAIN}/complete/edx-oauth2/" \
    "studio.${DEV_LMS_DOMAIN}: /complete/edx-oauth2 does not 500" \
    "302" "400" "403" "404"
fi

# MFE login should be reachable on all configured MFE hosts.
for mfe in "${MFE_HOSTS[@]}"; do
  if [[ "${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-0}" == "1" ]] && ! host_resolves "$mfe"; then
    log_warn "optional MFE host unresolved: ${mfe} (skipping)"
    continue
  fi
  require_200 "https://${mfe}/authn/login" "${mfe}: Authn MFE login"
  require_200 "https://${mfe}/api/mfe_config/v1" "${mfe}: MFE config endpoint"
done

# MFE config must be site-correct (prevents SSO/login drift across microsites).
if [[ "${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-0}" == "1" ]] && ! host_resolves "apps.${ECOSYSTEM_BASE}"; then
  log_warn "optional primary MFE host unresolved: apps.${ECOSYSTEM_BASE} (skipping MFE config checks)"
else
  require_body_contains \
    "https://apps.${ECOSYSTEM_BASE}/api/mfe_config/v1" \
    "Primary MFE config LMS_BASE_URL" \
    "\"LMS_BASE_URL\": \"https://${ECOSYSTEM_BASE}\""

  primary_mfe_config="$(curl -fsSL "https://apps.${ECOSYSTEM_BASE}/api/mfe_config/v1")" || primary_mfe_config=""
  if rg -q --fixed-strings "\"REFRESH_ACCESS_TOKEN_ENDPOINT\": \"https://apps.${ECOSYSTEM_BASE}/login_refresh\"" <<<"$primary_mfe_config" \
    || rg -q --fixed-strings "\"REFRESH_ACCESS_TOKEN_ENDPOINT\": \"/login_refresh\"" <<<"$primary_mfe_config"; then
    echo "✓ Primary MFE config refresh endpoint is same-origin (absolute or relative)"
  else
    echo "✗ Primary MFE config refresh endpoint is same-origin (prevents 401 login_refresh) (expected REFRESH_ACCESS_TOKEN_ENDPOINT to be https://apps.${ECOSYSTEM_BASE}/login_refresh OR /login_refresh) url=https://apps.${ECOSYSTEM_BASE}/api/mfe_config/v1" >&2
    failures=$((failures + 1))
  fi

  # Sanity-check the reverse-proxy exists: unauthenticated HEAD should return 405 (POST only),
  # not 404/500. We do not require 401 here because the endpoint can be hit without session.
  require_status \
    "https://apps.${ECOSYSTEM_BASE}/login_refresh" \
    "Primary MFE host exposes /login_refresh" \
    "405"
fi

if [[ "$ENVIRONMENT" == "prod" ]]; then
  require_body_contains \
    "https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1" \
    "Biji MFE config LMS_BASE_URL" \
    "\"LMS_BASE_URL\": \"https://${BIJI_DOMAIN}\""
  require_body_contains \
    "https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1" \
    "Biji MFE config STUDIO_BASE_URL" \
    "\"STUDIO_BASE_URL\": \"https://${BIJI_STUDIO_DOMAIN}\""

  biji_mfe_config="$(curl -fsSL "https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1")" || biji_mfe_config=""
  if rg -q --fixed-strings "\"REFRESH_ACCESS_TOKEN_ENDPOINT\": \"https://${BIJI_MFE_DOMAIN}/login_refresh\"" <<<"$biji_mfe_config" \
    || rg -q --fixed-strings "\"REFRESH_ACCESS_TOKEN_ENDPOINT\": \"/login_refresh\"" <<<"$biji_mfe_config"; then
    echo "✓ Biji MFE config refresh endpoint is same-origin (absolute or relative)"
  else
    echo "✗ Biji MFE config refresh endpoint is same-origin (expected REFRESH_ACCESS_TOKEN_ENDPOINT to be https://${BIJI_MFE_DOMAIN}/login_refresh OR /login_refresh) url=https://${BIJI_MFE_DOMAIN}/api/mfe_config/v1" >&2
    failures=$((failures + 1))
  fi

  require_status \
    "https://${BIJI_MFE_DOMAIN}/login_refresh" \
    "Biji MFE host exposes /login_refresh" \
    "405"
fi

for svc in discovery credentials ecommerce; do
  if [[ "${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-0}" == "1" ]] && ! host_resolves "${svc}.${ECOSYSTEM_BASE}"; then
    log_warn "optional service host unresolved: ${svc}.${ECOSYSTEM_BASE} (skipping auth entrypoint checks)"
    continue
  fi
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
  if [[ "${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-0}" == "1" ]] && ! host_resolves "${svc}.${ECOSYSTEM_BASE}"; then
    continue
  fi
  check_admin_login_redirect "$svc" "$ECOSYSTEM_BASE"
done

# Notes and forum are API-first. They do not have their own SSO entrypoints.
# We still verify they are reachable so operators don't misdiagnose outages as "SSO missing".
if [[ "${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-0}" == "1" ]] && ! host_resolves "notes.${ECOSYSTEM_BASE}"; then
  log_warn "optional service host unresolved: notes.${ECOSYSTEM_BASE} (skipping)"
else
  require_body_contains_one_of \
    "https://notes.${ECOSYSTEM_BASE}/" \
    "notes: service banner" \
    "Mereka Notes Service" \
    "edX Notes API"
fi

# Forum has had multiple deployment architectures over time.
# Current production contract requires /heartbeat=200. Non-prod accepts /healthz fallback.
if [[ "${ALLOW_UNRESOLVED_OPTIONAL_HOSTS:-0}" == "1" ]] && ! host_resolves "forum.${ECOSYSTEM_BASE}"; then
  log_warn "optional service host unresolved: forum.${ECOSYSTEM_BASE} (skipping)"
else
  require_status_one_of \
    "https://forum.${ECOSYSTEM_BASE}/" \
    "forum: reachable" \
    "200" "401" "404"

  check_forum_health_contract "forum.${ECOSYSTEM_BASE}"
fi

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "FAILED ($failures checks failed)" >&2
  exit 1
fi

echo ""
echo "OK"
