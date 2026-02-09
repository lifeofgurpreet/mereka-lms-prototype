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
  local lms_domain email password run_id

  if [[ "$env_name" == "prod" ]]; then
    lms_domain="$LMS_DOMAIN"
    email="${SSO_CANARY_EMAIL_PROD:-${SSO_CANARY_EMAIL:-}}"
    password="${SSO_CANARY_PASSWORD_PROD:-${SSO_CANARY_PASSWORD:-}}"
  else
    lms_domain="$DEV_LMS_DOMAIN"
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

  run_id="$(date -u +%Y%m%dT%H%M%SZ)-${env_name}"

  if ! timeout "${SSO_CANARY_TIMEOUT_SECONDS}s" python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path
from playwright.sync_api import TimeoutError as PWTimeout, sync_playwright

env_name = os.environ["CANARY_ENV_NAME"]
lms_domain = os.environ["CANARY_LMS_DOMAIN"]
email = os.environ["CANARY_EMAIL"]
password = os.environ["CANARY_PASSWORD"]
debug = os.environ.get("SSO_CANARY_DEBUG", "0") == "1"
out_dir = Path(os.environ["OUT_DIR"])
run_id = os.environ["CANARY_RUN_ID"]

base_url = f"https://{lms_domain}"
login_url = f"{base_url}/auth/login/oidc/"
dashboard_url = f"{base_url}/dashboard"
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

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(ignore_https_errors=False)
    page = context.new_page()

    try:
        if debug:
            log(f"goto={login_url}")
        page.goto(login_url, wait_until="domcontentloaded", timeout=60000)

        # Stage 1: identify user in Authentik
        page.get_by_placeholder("Email or Username").fill(email, timeout=30000)
        page.get_by_role("button", name=re.compile(r"Log in", re.I)).click(timeout=20000)

        # Stage 2: submit password
        page.get_by_placeholder("Password").fill(password, timeout=30000)
        page.get_by_role("button", name=re.compile(r"Continue", re.I)).click(timeout=20000)

        # We expect to leave auth0 and land on LMS host after callback exchange.
        page.wait_for_url(re.compile(rf"^https://{re.escape(lms_domain)}/"), timeout=60000)
        if debug:
            log(f"post_callback_url={page.url}")

        # Validate the authenticated browser session against a logged-in endpoint.
        me = page.evaluate(
            """
            async () => {
              try {
                const res = await fetch('/api/user/v1/me', { credentials: 'include' });
                const body = await res.text();
                return { status: res.status, body };
              } catch (err) {
                return { status: 0, body: String(err) };
              }
            }
            """
        )
        if int(me.get("status", 0)) != 200:
            fail(f"/api/user/v1/me status={me.get('status')} (expected 200)", page=page)
        if "username" not in (me.get("body") or ""):
            fail("/api/user/v1/me response missing username marker", page=page)

        # Final guardrail: dashboard should stay authenticated (not bounce to login).
        page.goto(dashboard_url, wait_until="domcontentloaded", timeout=60000)
        current = page.url
        if "/login" in current or "auth0.mereka.io" in current:
            fail(f"dashboard redirected to unauthenticated flow: {current}", page=page)

        log("OK authenticated session validated")
    except PWTimeout as exc:
        fail(f"timeout: {exc}", page=page)
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
