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
#   REQUIRE_SECRETS=1                   Fail when creds are missing (default: 1)
#   SSO_CANARY_TIMEOUT_SECONDS=120      Per-environment timeout
#   SSO_CANARY_EMAIL[_PROD|_DEV]        Canary email
#   SSO_CANARY_PASSWORD[_PROD|_DEV]     Canary password
#   SSO_CANARY_DEBUG=1                  Emit extra diagnostics
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="prod" # prod|dev|both
REQUIRE_SECRETS="${REQUIRE_SECRETS:-1}"
SSO_CANARY_TIMEOUT_SECONDS="${SSO_CANARY_TIMEOUT_SECONDS:-120}"
SSO_CANARY_DEBUG="${SSO_CANARY_DEBUG:-0}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/var/auth-sso-canary}"
mkdir -p "$OUT_DIR"

usage() {
  cat <<EOF
Usage: $0 [--env prod|dev|both]

Env:
  REQUIRE_SECRETS=1                   Fail when credentials are missing (default: 1)
  SSO_CANARY_TIMEOUT_SECONDS=120      Per-environment timeout (seconds)
  SSO_CANARY_EMAIL[_PROD|_DEV]        Canary email
  SSO_CANARY_PASSWORD[_PROD|_DEV]     Canary password
  SSO_CANARY_DEBUG=1                  Enable debug logging
EOF
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

run_env() {
  local env_name="$1"
  local lms_domain mfe_domain email password

  if [[ "$env_name" == "prod" ]]; then
    lms_domain="$LMS_DOMAIN"
    mfe_domain="$MFE_DOMAIN"
    email="${SSO_CANARY_EMAIL_PROD:-${SSO_CANARY_EMAIL:-}}"
    password="${SSO_CANARY_PASSWORD_PROD:-${SSO_CANARY_PASSWORD:-}}"
  else
    lms_domain="$DEV_LMS_DOMAIN"
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

  if ! timeout "${SSO_CANARY_TIMEOUT_SECONDS}s" python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path
from playwright.sync_api import Error as PWError, TimeoutError as PWTimeout, sync_playwright

env_name = os.environ["CANARY_ENV_NAME"]
lms_domain = os.environ["CANARY_LMS_DOMAIN"]
mfe_domain = os.environ["CANARY_MFE_DOMAIN"]
email = os.environ["CANARY_EMAIL"]
password = os.environ["CANARY_PASSWORD"]
debug = os.environ.get("SSO_CANARY_DEBUG", "0") == "1"
out_dir = Path(os.environ["OUT_DIR"])
run_id = os.environ["CANARY_RUN_ID"]

base_url = f"https://{lms_domain}"
login_url = f"{base_url}/auth/login/oidc/"
dashboard_url = f"{base_url}/dashboard"
sso_mfe_learner_dashboard_url = f"https://{mfe_domain}/learner-dashboard"
screenshot_path = out_dir / f"{run_id}-failure.png"

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
    if "unknown error" in body and "powered by authentik" in body:
        fail(f"{phase}: Authentik error page encountered (unknown error)", page=page)
    if "we couldn't sign you in" in body and "not authorized" in body:
        fail(f"{phase}: Open edX authorization denied after callback", page=page)
    if "your account is disabled" in body:
        fail(f"{phase}: Open edX reports account disabled (check OIDC user password state)", page=page)

def wait_for_app_return(page) -> None:
    # Browser/network layers can occasionally throw ERR_NETWORK_CHANGED during redirect chains.
    # Retry a couple times before declaring failure.
    attempts = 0
    last_exc = None
    while attempts < 3:
        attempts += 1
        try:
            page.wait_for_url(
                re.compile(
                    rf"^https://({re.escape(lms_domain)}|{re.escape(mfe_domain)})/"
                ),
                timeout=60000,
            )
            return
        except PWError as exc:
            last_exc = exc
            msg = str(exc)
            if "ERR_NETWORK_CHANGED" in msg or "net::ERR_NETWORK_CHANGED" in msg:
                # Small backoff before retry.
                page.wait_for_timeout(1500)
                continue
            raise
    fail(f"post_callback navigation failed after retries: {last_exc}", page=page)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(ignore_https_errors=False)
    page = context.new_page()

    try:
        if debug:
            log(f"goto={login_url}")
        page.goto(login_url, wait_until="domcontentloaded", timeout=60000)
        assert_not_auth_error_page(page, "oidc_entrypoint")

        # Stage 1: identify user in Authentik
        page.get_by_placeholder("Email or Username").fill(email, timeout=30000)
        page.get_by_role("button", name=re.compile(r"Log in", re.I)).click(timeout=20000)
        page.wait_for_load_state("domcontentloaded", timeout=60000)
        assert_not_auth_error_page(page, "authentik_username_submitted")

        # Stage 2: submit password
        page.get_by_placeholder("Password").fill(password, timeout=30000)
        page.get_by_role("button", name=re.compile(r"Continue", re.I)).click(timeout=20000)
        page.wait_for_load_state("domcontentloaded", timeout=60000)
        assert_not_auth_error_page(page, "authentik_password_submitted")

        # We expect callback to leave Authentik domain.
        # Depending on the flow, we may land on LMS or Authn MFE first.
        wait_for_app_return(page)
        assert_not_auth_error_page(page, "post_callback")
        if debug:
            log(f"post_callback_url={page.url}")

        # Validate the authenticated browser session against a logged-in LMS endpoint.
        me_resp = context.request.get(f"{base_url}/api/user/v1/me")
        me_status = me_resp.status
        me_body = me_resp.text()
        if me_status != 200:
            fail(f"/api/user/v1/me status={me_status} (expected 200)", page=page)
        if "username" not in (me_body or ""):
            fail("/api/user/v1/me response missing username marker", page=page)

        # Optional UX guardrail: dashboard should not end on an auth error page.
        page.goto(dashboard_url, wait_until="domcontentloaded", timeout=60000)
        # Some stacks bounce through apps/authn/login before returning to dashboard.
        if "/authn/login" in (page.url or ""):
            try:
                page.wait_for_url(
                    re.compile(
                        rf"^https://({re.escape(lms_domain)}|{re.escape(mfe_domain)})/(?!authn/login).*"
                    ),
                    timeout=30000,
                )
            except PWTimeout:
                # Keep this as non-fatal if session API already proved login and
                # no explicit auth error page is shown.
                pass
        assert_not_auth_error_page(page, "dashboard_navigation")

        # Cross-domain regression guardrail:
        # After successful LMS SSO, MFEs must be able to refresh the session (login_refresh)
        # and load authenticated surfaces. This catches the common failure mode where
        # REFRESH_ACCESS_TOKEN_ENDPOINT is cross-origin and cookies are not sent, causing
        # MFEs to loop back to /authn/login.
        page.goto(sso_mfe_learner_dashboard_url, wait_until="domcontentloaded", timeout=60000)
        page.wait_for_load_state("domcontentloaded", timeout=60000)
        if "/authn/login" in (page.url or ""):
            fail(
                f"mfe_learner_dashboard_redirected_to_authn_login url={page.url} "
                "(likely login_refresh 401 / cookie or reverse-proxy drift)",
                page=page,
            )
        assert_not_auth_error_page(page, "mfe_learner_dashboard")

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

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
  CANARY_ENV_NAME="prod" \
  CANARY_LMS_DOMAIN="$LMS_DOMAIN" \
  CANARY_MFE_DOMAIN="$MFE_DOMAIN" \
  CANARY_EMAIL="${SSO_CANARY_EMAIL_PROD:-${SSO_CANARY_EMAIL:-}}" \
  CANARY_PASSWORD="${SSO_CANARY_PASSWORD_PROD:-${SSO_CANARY_PASSWORD:-}}" \
  CANARY_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-prod" \
  OUT_DIR="$OUT_DIR" \
  SSO_CANARY_DEBUG="$SSO_CANARY_DEBUG" \
  run_env "prod"
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
  CANARY_ENV_NAME="dev" \
  CANARY_LMS_DOMAIN="$DEV_LMS_DOMAIN" \
  CANARY_MFE_DOMAIN="$DEV_MFE_DOMAIN" \
  CANARY_EMAIL="${SSO_CANARY_EMAIL_DEV:-${SSO_CANARY_EMAIL:-}}" \
  CANARY_PASSWORD="${SSO_CANARY_PASSWORD_DEV:-${SSO_CANARY_PASSWORD:-}}" \
  CANARY_RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-dev" \
  OUT_DIR="$OUT_DIR" \
  SSO_CANARY_DEBUG="$SSO_CANARY_DEBUG" \
  run_env "dev"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "FAILED ($failures environments failed)" >&2
  exit 1
fi

echo "OK"
