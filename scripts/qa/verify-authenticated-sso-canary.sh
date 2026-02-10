#!/usr/bin/env bash
# Verify real authenticated SSO login (OIDC callback + post-login session).
#
# This check is intentionally credentialed and validates what public redirect checks cannot:
# - Authentik login form flow actually completes
# - LMS callback (/auth/complete/oidc/) results in a real logged-in browser session
# - Session can access a logged-in API endpoint
#
# Secrets are read from environment variables only (never CLI args), to avoid leaking
# credentials in process lists or logs.
#
# Usage:
#   ./scripts/qa/verify-authenticated-sso-canary.sh --env prod
#   ./scripts/qa/verify-authenticated-sso-canary.sh --env dev
#   REQUIRE_SECRETS=0 ./scripts/qa/verify-authenticated-sso-canary.sh --env both
#
# Env:
#   REQUIRE_SECRETS=1                        Fail when primary creds are missing (default: 1)
#   REQUIRE_STUDIO_CANARY=0                  Fail when Studio staff creds are missing (default: 0)
#   SSO_CANARY_TIMEOUT_SECONDS=180           Per-run timeout
#   SSO_CANARY_EMAIL[_PROD|_DEV]             Primary canary email
#   SSO_CANARY_PASSWORD[_PROD|_DEV]          Primary canary password
#   SSO_CANARY_STUDIO_EMAIL[_PROD|_DEV]      Optional Studio-access canary email (staff)
#   SSO_CANARY_STUDIO_PASSWORD[_PROD|_DEV]   Optional Studio-access canary password
#   SSO_CANARY_DEBUG=1                       Emit extra diagnostics
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="prod" # prod|dev|both
REQUIRE_SECRETS="${REQUIRE_SECRETS:-1}"
REQUIRE_STUDIO_CANARY="${REQUIRE_STUDIO_CANARY:-0}"
SSO_CANARY_TIMEOUT_SECONDS="${SSO_CANARY_TIMEOUT_SECONDS:-180}"
SSO_CANARY_DEBUG="${SSO_CANARY_DEBUG:-0}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/var/auth-sso-canary}"
mkdir -p "$OUT_DIR"

usage() {
  cat <<'USAGE_EOF'
Usage: ./scripts/qa/verify-authenticated-sso-canary.sh [--env prod|dev|both]

Env:
  REQUIRE_SECRETS=1                        Fail when primary creds are missing (default: 1)
  REQUIRE_STUDIO_CANARY=0                  Fail when Studio staff creds are missing (default: 0)
  SSO_CANARY_TIMEOUT_SECONDS=180           Per-run timeout (seconds)
  SSO_CANARY_EMAIL[_PROD|_DEV]             Primary canary email
  SSO_CANARY_PASSWORD[_PROD|_DEV]          Primary canary password
  SSO_CANARY_STUDIO_EMAIL[_PROD|_DEV]      Optional Studio-access canary email (staff)
  SSO_CANARY_STUDIO_PASSWORD[_PROD|_DEV]   Optional Studio-access canary password
  SSO_CANARY_DEBUG=1                       Enable debug logging
USAGE_EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "both" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

failures=0

run_playwright_canary() {
  local env_name="$1"
  local lms_domain="$2"
  local studio_domain="$3"
  local mfe_domain="$4"
  local email="$5"
  local password="$6"
  local run_id="$7"
  local require_studio_access="$8" # 0|1

  if ! CANARY_ENV_NAME="$env_name" \
    CANARY_LMS_DOMAIN="$lms_domain" \
    CANARY_STUDIO_DOMAIN="$studio_domain" \
    CANARY_MFE_DOMAIN="$mfe_domain" \
    CANARY_EMAIL="$email" \
    CANARY_PASSWORD="$password" \
    CANARY_RUN_ID="$run_id" \
    CANARY_REQUIRE_STUDIO_ACCESS="$require_studio_access" \
    OUT_DIR="$OUT_DIR" \
    SSO_CANARY_DEBUG="$SSO_CANARY_DEBUG" \
    timeout "${SSO_CANARY_TIMEOUT_SECONDS}s" python3 - <<'PY'
import os
import re
from pathlib import Path
from playwright.sync_api import Error as PWError, TimeoutError as PWTimeout, sync_playwright

env_name = os.environ["CANARY_ENV_NAME"]
lms_domain = os.environ["CANARY_LMS_DOMAIN"]
studio_domain = os.environ["CANARY_STUDIO_DOMAIN"]
mfe_domain = os.environ["CANARY_MFE_DOMAIN"]
email = os.environ["CANARY_EMAIL"]
password = os.environ["CANARY_PASSWORD"]
require_studio_access = os.environ.get("CANARY_REQUIRE_STUDIO_ACCESS", "0") == "1"
debug = os.environ.get("SSO_CANARY_DEBUG", "0") == "1"
out_dir = Path(os.environ["OUT_DIR"])
run_id = os.environ["CANARY_RUN_ID"]

base_url = f"https://{lms_domain}"
login_url = f"{base_url}/auth/login/oidc/"
dashboard_url = f"{base_url}/dashboard"
studio_url = f"https://{studio_domain}/"
studio_home_url = f"https://{studio_domain}/home/"
sso_mfe_learner_dashboard_url = f"https://{mfe_domain}/learner-dashboard"

screenshot_path = out_dir / f"{run_id}-failure.png"
studio_failure_path = out_dir / f"{run_id}-studio-failure.png"

def log(msg: str) -> None:
    print(f"[{env_name}] {msg}")

def fail(msg: str, page=None, code: int = 1) -> None:
    if page is not None:
        try:
            page.screenshot(path=str(screenshot_path), full_page=True)
            log(f"screenshot={screenshot_path}")
        except Exception as exc:
            log(f"screenshot_failed={exc}")
    log(f"FAIL {msg}")
    raise SystemExit(code)

def assert_not_auth_error_page(page, phase: str) -> None:
    url = (page.url or "").lower()
    if "error=" in url and ("auth/callback" in url or "authn/login" in url or "/login" in url):
        fail(f"{phase}: callback/login error query detected in url={page.url}", page=page)

    try:
        body = page.inner_text("body", timeout=3000).lower()
    except Exception:
        body = ""

    if "authentication process canceled" in body:
        fail(f"{phase}: Authentik reported canceled authentication", page=page)
    if "request has been denied" in body:
        fail(f"{phase}: Authentik denied the authorization request (policy/assignment likely)", page=page)
    if "no authentication methods available" in body:
        fail(f"{phase}: Authentik MFA required but user has no available methods", page=page)
    if "unknown error" in body and "powered by authentik" in body:
        fail(f"{phase}: Authentik error page encountered (unknown error)", page=page)
    if "the request failed and the interceptors did not return an alternative response" in body:
        fail(f"{phase}: Authentik interceptor error page encountered", page=page)
    if "we couldn't sign you in" in body and "not authorized" in body:
        fail(f"{phase}: Open edX authorization denied after callback", page=page)
    if "your account is disabled" in body:
        fail(f"{phase}: Open edX reports account disabled (check OIDC user password state)", page=page)

def wait_for_app_return(page) -> None:
    attempts = 0
    last_exc = None
    while attempts < 3:
        attempts += 1
        try:
            page.wait_for_url(
                re.compile(rf"^https://({re.escape(lms_domain)}|{re.escape(mfe_domain)})/"),
                timeout=60000,
            )
            return
        except PWError as exc:
            last_exc = exc
            msg = str(exc)
            if "ERR_NETWORK_CHANGED" in msg or "net::ERR_NETWORK_CHANGED" in msg:
                page.wait_for_timeout(1500)
                continue
            raise
    fail(f"post_callback navigation failed after retries: {last_exc}", page=page)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(ignore_https_errors=False)
    page = context.new_page()
    studio_error = {"url": None, "status": None}

    def on_response(resp):
        try:
            url = resp.url or ""
            if "/complete/edx-oauth2" in url and resp.status >= 500 and studio_error["status"] is None:
                studio_error["url"] = url
                studio_error["status"] = resp.status
        except Exception:
            return

    page.on("response", on_response)

    try:
        if debug:
            log(f"goto={login_url}")
        page.goto(login_url, wait_until="domcontentloaded", timeout=60000)
        assert_not_auth_error_page(page, "oidc_entrypoint")

        page.get_by_placeholder("Email or Username").fill(email, timeout=30000)
        page.get_by_role("button", name=re.compile(r"Log in", re.I)).click(timeout=20000)
        page.wait_for_load_state("domcontentloaded", timeout=60000)
        assert_not_auth_error_page(page, "authentik_username_submitted")

        page.get_by_placeholder("Password").fill(password, timeout=30000)
        page.get_by_role("button", name=re.compile(r"Continue", re.I)).click(timeout=20000)
        page.wait_for_load_state("domcontentloaded", timeout=60000)
        assert_not_auth_error_page(page, "authentik_password_submitted")

        wait_for_app_return(page)
        assert_not_auth_error_page(page, "post_callback")
        if debug:
            log(f"post_callback_url={page.url}")

        me_resp = context.request.get(f"{base_url}/api/user/v1/me")
        me_status = me_resp.status
        me_body = me_resp.text() or ""
        if me_status != 200:
            fail(f"/api/user/v1/me status={me_status} (expected 200)", page=page)
        if "username" not in me_body:
            fail("/api/user/v1/me response missing username marker", page=page)

        page.goto(dashboard_url, wait_until="domcontentloaded", timeout=60000)
        if "/authn/login" in (page.url or ""):
            try:
                page.wait_for_url(
                    re.compile(rf"^https://({re.escape(lms_domain)}|{re.escape(mfe_domain)})/(?!authn/login).*"),
                    timeout=30000,
                )
            except PWTimeout:
                pass
        assert_not_auth_error_page(page, "dashboard_navigation")

        page.goto(sso_mfe_learner_dashboard_url, wait_until="domcontentloaded", timeout=60000)
        page.wait_for_load_state("domcontentloaded", timeout=60000)
        if "/authn/login" in (page.url or ""):
            fail(
                f"mfe_learner_dashboard_redirected_to_authn_login url={page.url} "
                "(likely login_refresh 401 / cookie or reverse-proxy drift)",
                page=page,
            )
        assert_not_auth_error_page(page, "mfe_learner_dashboard")

        if debug:
            log(f"goto={studio_url}")
        page.goto(studio_url, wait_until="domcontentloaded", timeout=60000)
        page.wait_for_load_state("domcontentloaded", timeout=60000)
        try:
            body = page.inner_text("body", timeout=5000).lower()
        except Exception:
            body = ""
        if "the studio servers encountered an error" in body or "an error occurred in studio" in body:
            try:
                page.screenshot(path=str(studio_failure_path), full_page=True)
                log(f"studio_screenshot={studio_failure_path}")
            except Exception as exc:
                log(f"studio_screenshot_failed={exc}")
            fail(f"studio_error_page url={page.url}", page=page)
        if studio_error["status"] is not None:
            try:
                page.screenshot(path=str(studio_failure_path), full_page=True)
                log(f"studio_screenshot={studio_failure_path}")
            except Exception as exc:
                log(f"studio_screenshot_failed={exc}")
            fail(f"studio_complete_edx_oauth2_http_{studio_error['status']} url={studio_error['url']}", page=page)

        if require_studio_access:
            if debug:
                log(f"goto={studio_home_url}")
            page.goto(studio_home_url, wait_until="domcontentloaded", timeout=60000)
            page.wait_for_load_state("domcontentloaded", timeout=60000)
            try:
                body = page.inner_text("body", timeout=5000).lower()
            except Exception:
                body = ""
            if "the studio servers encountered an error" in body or "an error occurred in studio" in body:
                fail(f"studio_error_page url={page.url}", page=page)
            if "/signin" in (page.url or "") or "already have a studio account? sign in" in body:
                fail(f"studio_access_required_but_not_authenticated url={page.url}", page=page)
            if "/home" not in (page.url or ""):
                fail(f"studio_access_expected_home_but_got url={page.url}", page=page)

        log("OK authenticated session validated")
    except (PWTimeout, PWError) as exc:
        fail(f"timeout_or_browser_error: {exc}", page=page)
    finally:
        browser.close()
PY
  then
    failures=$((failures + 1))
  fi
}

run_primary_env() {
  local env_name="$1"
  local lms_domain studio_domain mfe_domain email password

  if [[ "$env_name" == "prod" ]]; then
    lms_domain="$LMS_DOMAIN"
    studio_domain="$STUDIO_DOMAIN"
    mfe_domain="$MFE_DOMAIN"
    email="${SSO_CANARY_EMAIL_PROD:-${SSO_CANARY_EMAIL:-}}"
    password="${SSO_CANARY_PASSWORD_PROD:-${SSO_CANARY_PASSWORD:-}}"
  else
    lms_domain="$DEV_LMS_DOMAIN"
    studio_domain="$DEV_STUDIO_DOMAIN"
    mfe_domain="$DEV_MFE_DOMAIN"
    email="${SSO_CANARY_EMAIL_DEV:-${SSO_CANARY_EMAIL:-}}"
    password="${SSO_CANARY_PASSWORD_DEV:-${SSO_CANARY_PASSWORD:-}}"
  fi

  if [[ -z "${email:-}" || -z "${password:-}" ]]; then
    if [[ "$REQUIRE_SECRETS" == "1" ]]; then
      echo "FAIL $env_name: missing SSO canary credentials (set SSO_CANARY_EMAIL[_${env_name^^}] and SSO_CANARY_PASSWORD[_${env_name^^}])" >&2
      failures=$((failures + 1))
      return
    fi
    echo "SKIP $env_name: missing SSO canary credentials (REQUIRE_SECRETS=0)"
    return
  fi

  run_playwright_canary \
    "$env_name" \
    "$lms_domain" \
    "$studio_domain" \
    "$mfe_domain" \
    "$email" \
    "$password" \
    "$(date -u +%Y%m%dT%H%M%SZ)-${env_name}" \
    "0"
}

run_studio_env() {
  local env_name="$1"
  local lms_domain studio_domain mfe_domain email password

  if [[ "$env_name" == "prod" ]]; then
    lms_domain="$LMS_DOMAIN"
    studio_domain="$STUDIO_DOMAIN"
    mfe_domain="$MFE_DOMAIN"
    email="${SSO_CANARY_STUDIO_EMAIL_PROD:-${SSO_CANARY_STUDIO_EMAIL:-}}"
    password="${SSO_CANARY_STUDIO_PASSWORD_PROD:-${SSO_CANARY_STUDIO_PASSWORD:-}}"
  else
    lms_domain="$DEV_LMS_DOMAIN"
    studio_domain="$DEV_STUDIO_DOMAIN"
    mfe_domain="$DEV_MFE_DOMAIN"
    email="${SSO_CANARY_STUDIO_EMAIL_DEV:-${SSO_CANARY_STUDIO_EMAIL:-}}"
    password="${SSO_CANARY_STUDIO_PASSWORD_DEV:-${SSO_CANARY_STUDIO_PASSWORD:-}}"
  fi

  if [[ -z "${email:-}" || -z "${password:-}" ]]; then
    if [[ "$REQUIRE_STUDIO_CANARY" == "1" ]]; then
      echo "FAIL $env_name: missing Studio SSO canary credentials (set SSO_CANARY_STUDIO_EMAIL[_${env_name^^}] and SSO_CANARY_STUDIO_PASSWORD[_${env_name^^}])" >&2
      failures=$((failures + 1))
      return
    fi
    echo "SKIP $env_name: missing Studio SSO canary credentials (REQUIRE_STUDIO_CANARY=0)"
    return
  fi

  run_playwright_canary \
    "$env_name" \
    "$lms_domain" \
    "$studio_domain" \
    "$mfe_domain" \
    "$email" \
    "$password" \
    "$(date -u +%Y%m%dT%H%M%SZ)-${env_name}-studio" \
    "1"
}

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
  run_primary_env "prod"
  run_studio_env "prod"
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
  run_primary_env "dev"
  run_studio_env "dev"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "FAILED ($failures runs failed)" >&2
  exit 1
fi

echo "OK"
