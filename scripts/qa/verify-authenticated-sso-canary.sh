#!/usr/bin/env bash
# @covers AC-042, AC-045
# @spec: auth-sso-enterprise_spec.md
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
#   ./scripts/qa/verify-authenticated-sso-canary.sh --env staging
#   ./scripts/qa/verify-authenticated-sso-canary.sh --env dev
#   ./scripts/qa/verify-authenticated-sso-canary.sh --env prod
#   REQUIRE_SECRETS=0 ./scripts/qa/verify-authenticated-sso-canary.sh --env both
#   REQUIRE_SECRETS=0 ./scripts/qa/verify-authenticated-sso-canary.sh --env all
#
# Env:
#   REQUIRE_SECRETS=1                           Fail when primary creds are missing (default: 1)
#   REQUIRE_STUDIO_CANARY=0                     Fail when Studio staff creds are missing (default: 0)
#   RUN_OIDC_CANARY=1                           Run primary OIDC canary flow (default: 1)
#   RUN_STUDIO_CANARY=1                         Run Studio OIDC canary flow (default: 1)
#   RUN_LOCAL_LOGIN_CANARY=0                    Also run native /authn/login credential canary (default: 0)
#   REQUIRE_LOCAL_CANARY=0                      Fail when local-login creds are missing (default: 0)
#   SSO_CANARY_TIMEOUT_SECONDS=180              Per-run timeout
#   SSO_CANARY_EMAIL[_PROD|_DEV|_STAGING]      Primary canary email
#   SSO_CANARY_PASSWORD[_PROD|_DEV|_STAGING]   Primary canary password
#   SSO_CANARY_STUDIO_EMAIL[_PROD|_DEV|_STAGING]    Optional Studio-access canary email (staff)
#   SSO_CANARY_STUDIO_PASSWORD[_PROD|_DEV|_STAGING] Optional Studio-access canary password
#   LOCAL_CANARY_EMAIL[_PROD|_DEV|_STAGING]    Optional native authn canary email/user
#   LOCAL_CANARY_PASSWORD[_PROD|_DEV|_STAGING] Optional native authn canary password
#   SSO_CANARY_DEBUG=1                          Emit extra diagnostics
#   SSO_CANARY_IGNORE_HTTPS_ERRORS=auto|0|1     TLS mode (default: auto; dev=1, prod/staging=0)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="staging" # staging|dev|prod|both|all
REQUIRE_SECRETS="${REQUIRE_SECRETS:-1}"
REQUIRE_STUDIO_CANARY="${REQUIRE_STUDIO_CANARY:-0}"
RUN_OIDC_CANARY="${RUN_OIDC_CANARY:-1}"
RUN_STUDIO_CANARY="${RUN_STUDIO_CANARY:-1}"
RUN_LOCAL_LOGIN_CANARY="${RUN_LOCAL_LOGIN_CANARY:-0}"
REQUIRE_LOCAL_CANARY="${REQUIRE_LOCAL_CANARY:-0}"
SSO_CANARY_TIMEOUT_SECONDS="${SSO_CANARY_TIMEOUT_SECONDS:-180}"
SSO_CANARY_DEBUG="${SSO_CANARY_DEBUG:-0}"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/var/auth-sso-canary}"
mkdir -p "$OUT_DIR"

usage() {
  cat <<'USAGE_EOF'
Usage: ./scripts/qa/verify-authenticated-sso-canary.sh [--env staging|dev|prod|both|all]

Env:
  REQUIRE_SECRETS=1                            Fail when primary creds are missing (default: 1)
  REQUIRE_STUDIO_CANARY=0                      Fail when Studio staff creds are missing (default: 0)
  RUN_OIDC_CANARY=1                            Run primary OIDC canary flow (default: 1)
  RUN_STUDIO_CANARY=1                          Run Studio OIDC canary flow (default: 1)
  RUN_LOCAL_LOGIN_CANARY=0                     Also run native /authn/login credential canary (default: 0)
  REQUIRE_LOCAL_CANARY=0                       Fail when local-login creds are missing (default: 0)
  SSO_CANARY_TIMEOUT_SECONDS=180               Per-run timeout (seconds)
  SSO_CANARY_EMAIL[_PROD|_DEV|_STAGING]       Primary canary email
  SSO_CANARY_PASSWORD[_PROD|_DEV|_STAGING]    Primary canary password
  SSO_CANARY_STUDIO_EMAIL[_PROD|_DEV|_STAGING]     Optional Studio-access canary email (staff)
  SSO_CANARY_STUDIO_PASSWORD[_PROD|_DEV|_STAGING]  Optional Studio-access canary password
  LOCAL_CANARY_EMAIL[_PROD|_DEV|_STAGING]     Optional native authn canary email/user
  LOCAL_CANARY_PASSWORD[_PROD|_DEV|_STAGING]  Optional native authn canary password
  SSO_CANARY_DEBUG=1                           Enable debug logging
  SSO_CANARY_IGNORE_HTTPS_ERRORS=auto|0|1      TLS mode (default: auto; dev=1, prod/staging=0)
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

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "staging" && "$ENV_SCOPE" != "both" && "$ENV_SCOPE" != "all" ]]; then
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
  local login_flow="${9:-oidc}" # oidc|local
  local ignore_https_errors_raw="${SSO_CANARY_IGNORE_HTTPS_ERRORS:-auto}"
  local ignore_https_errors="0"
  case "$ignore_https_errors_raw" in
    auto)
      if [[ "$env_name" == "dev" ]]; then
        ignore_https_errors="1"
      fi
      ;;
    1|true|TRUE|yes|YES)
      ignore_https_errors="1"
      ;;
    0|false|FALSE|no|NO)
      ignore_https_errors="0"
      ;;
    *)
      echo "WARN: invalid SSO_CANARY_IGNORE_HTTPS_ERRORS=$ignore_https_errors_raw (using auto policy)" >&2
      if [[ "$env_name" == "dev" ]]; then
        ignore_https_errors="1"
      fi
      ;;
  esac

  if ! CANARY_ENV_NAME="$env_name" \
    CANARY_LMS_DOMAIN="$lms_domain" \
    CANARY_STUDIO_DOMAIN="$studio_domain" \
    CANARY_MFE_DOMAIN="$mfe_domain" \
    CANARY_EMAIL="$email" \
    CANARY_PASSWORD="$password" \
    CANARY_RUN_ID="$run_id" \
    CANARY_REQUIRE_STUDIO_ACCESS="$require_studio_access" \
    CANARY_LOGIN_FLOW="$login_flow" \
    CANARY_IGNORE_HTTPS_ERRORS="$ignore_https_errors" \
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
login_flow = os.environ.get("CANARY_LOGIN_FLOW", "oidc").strip().lower()
if login_flow not in {"oidc", "local"}:
    login_flow = "oidc"
debug = os.environ.get("SSO_CANARY_DEBUG", "0") == "1"
out_dir = Path(os.environ["OUT_DIR"])
run_id = os.environ["CANARY_RUN_ID"]
ignore_https_errors = os.environ.get("CANARY_IGNORE_HTTPS_ERRORS", "0") == "1"

_http_trace = []
_studio_cookie_names = set()

base_url = f"https://{lms_domain}"
oidc_login_url = f"{base_url}/auth/login/oidc/"
local_login_url = f"https://{mfe_domain}/authn/login?next=%2F"
login_url = local_login_url if login_flow == "local" else oidc_login_url
dashboard_url = f"{base_url}/dashboard"
studio_url = f"https://{studio_domain}/"
studio_home_url = f"https://{studio_domain}/home/"
sso_mfe_learner_dashboard_url = f"https://{mfe_domain}/learner-dashboard"
home_mfe_url = f"https://{mfe_domain}/"

screenshot_path = out_dir / f"{run_id}-failure.png"
studio_failure_path = out_dir / f"{run_id}-studio-failure.png"

def log(msg: str) -> None:
    print(f"[{env_name}] {msg}")

def _redact_set_cookie(header_value: str) -> str:
    # Never print raw cookie values. Keep cookie names + attributes only.
    parts = [p.strip() for p in header_value.split(",") if p.strip()]
    redacted_parts = []
    for p in parts:
        # Split cookie segments (name=value; attrs...)
        segs = [s.strip() for s in p.split(";")]
        if segs and "=" in segs[0]:
            name = segs[0].split("=", 1)[0]
            segs[0] = f"{name}=<redacted>"
        redacted_parts.append("; ".join(segs))
    return ", ".join(redacted_parts)

def fail(msg: str, page=None, code: int = 1) -> None:
    # Emit useful diagnostics without leaking secrets.
    try:
        trace = globals().get("_http_trace", [])
        if trace:
            log("http_trace (latest 40, redacted cookies):")
            for row in trace[-40:]:
                log("  " + row)
        studio_cookie_names = globals().get("_studio_cookie_names", set())
        if studio_cookie_names:
            log("studio_cookie_names=" + ",".join(sorted(studio_cookie_names)))
    except Exception as exc:
        log(f"diagnostics_failed={exc}")

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

def probe_login_refresh_status(request_context, app_base_url: str) -> str:
    endpoint = f"{app_base_url.rstrip('/')}/login_refresh"
    probes = []
    for method in ("GET", "POST"):
        try:
            if method == "GET":
                resp = request_context.get(endpoint, fail_on_status_code=False)
            else:
                resp = request_context.post(endpoint, fail_on_status_code=False)
            probes.append(f"{method}:{resp.status}")
        except Exception:
            probes.append(f"{method}:err")
    return ",".join(probes)

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    context = browser.new_context(ignore_https_errors=ignore_https_errors)
    page = context.new_page()
    studio_error = {"url": None, "status": None}
    _http_trace.clear()
    _studio_cookie_names.clear()
    if debug:
        log(f"require_studio_access={require_studio_access}")

    def _push_trace(row: str) -> None:
        try:
            _http_trace.append(row)
            # Keep bounded to avoid runaway logs in redirect loops.
            if len(_http_trace) > 400:
                del _http_trace[:200]
        except Exception:
            return

    def _record_trace(resp):
        try:
            url = resp.url or ""
            status = resp.status
            headers = resp.headers or {}
            location = headers.get("location", "")
            set_cookie = headers.get("set-cookie", "")
            set_cookie_redacted = _redact_set_cookie(set_cookie) if set_cookie else ""

            # Record only auth-relevant URLs to keep noise low.
            watch = (
                studio_domain in url
                or "/complete/edx-oauth2" in url
                or "/login/edx-oauth2" in url
                or "/oauth2/authorize" in url
                or "/auth/complete/oidc" in url
                or "/auth/login/oidc" in url
                or "/authn/login" in url
            )
            if not watch:
                return

            row = f"{status} {url}"
            if location:
                row += f" location={location}"
            if set_cookie_redacted:
                row += f" set-cookie={set_cookie_redacted}"
                # Track cookie names for Studio domain debugging.
                for seg in set_cookie.split(","):
                    first = seg.split(";", 1)[0].strip()
                    if "=" in first:
                        _studio_cookie_names.add(first.split("=", 1)[0])
            _push_trace(row)
        except Exception:
            return

    def on_response(resp):
        try:
            url = resp.url or ""
            _record_trace(resp)
            if "/complete/edx-oauth2" in url and resp.status >= 500 and studio_error["status"] is None:
                studio_error["url"] = url
                studio_error["status"] = resp.status
        except Exception:
            return

    def on_request(req):
        try:
            url = req.url or ""
            if studio_domain in url or "/complete/edx-oauth2" in url or "/login/edx-oauth2" in url:
                _push_trace(f"REQ {req.method} {url}")
        except Exception:
            return

    def on_request_finished(req):
        try:
            url = req.url or ""
            if not (studio_domain in url or "/complete/edx-oauth2" in url or "/login/edx-oauth2" in url):
                return
            resp = req.response()
            if resp is None:
                _push_trace(f"RESP <none> {url}")
                return
            headers = resp.headers or {}
            location = headers.get("location", "")
            set_cookie = headers.get("set-cookie", "")
            set_cookie_redacted = _redact_set_cookie(set_cookie) if set_cookie else ""
            row = f"RESP {resp.status} {url}"
            if location:
                row += f" location={location}"
            if set_cookie_redacted:
                row += f" set-cookie={set_cookie_redacted}"
                for seg in set_cookie.split(","):
                    first = seg.split(";", 1)[0].strip()
                    if "=" in first:
                        _studio_cookie_names.add(first.split("=", 1)[0])
            _push_trace(row)
        except Exception:
            return

    def on_request_failed(req):
        try:
            url = req.url or ""
            if studio_domain in url or "/complete/edx-oauth2" in url or "/login/edx-oauth2" in url:
                failure = req.failure or {}
                _push_trace(f"FAILREQ {url} error={failure.get('errorText','')}")
        except Exception:
            return

    def manual_redirect_probe(start_url: str, max_steps: int = 25) -> None:
        """
        Follow redirects manually via APIRequestContext (shared cookies), to avoid
        Playwright's browser-level ERR_TOO_MANY_REDIRECTS masking the chain.
        """
        visited = set()
        url = start_url
        for _ in range(max_steps):
            if url in visited:
                _push_trace(f"LOOP {url}")
                return
            visited.add(url)
            resp = context.request.get(url, max_redirects=0, fail_on_status_code=False)
            status = resp.status
            headers = resp.headers or {}
            location = headers.get("location", "")
            set_cookie = headers.get("set-cookie", "")
            set_cookie_redacted = _redact_set_cookie(set_cookie) if set_cookie else ""
            row = f"API {status} {url}"
            if location:
                row += f" location={location}"
            if set_cookie_redacted:
                row += f" set-cookie={set_cookie_redacted}"
                for seg in set_cookie.split(","):
                    first = seg.split(";", 1)[0].strip()
                    if "=" in first:
                        _studio_cookie_names.add(first.split("=", 1)[0])
            _push_trace(row)

            if status in (301, 302, 303, 307, 308) and location:
                if location.startswith("/"):
                    url = f"https://{studio_domain}{location}"
                elif location.startswith("http://") or location.startswith("https://"):
                    url = location
                else:
                    # Relative URL fallback
                    if url.endswith("/"):
                        url = url + location
                    else:
                        url = url.rsplit("/", 1)[0] + "/" + location
                continue
            return
        _push_trace(f"MAX_REDIRECT_STEPS_EXCEEDED start={start_url}")

    page.on("response", on_response)
    page.on("request", on_request)
    page.on("requestfinished", on_request_finished)
    page.on("requestfailed", on_request_failed)

    try:
        if debug:
            log(f"login_flow={login_flow}")
        if debug:
            log(f"goto={login_url}")
        page.goto(login_url, wait_until="domcontentloaded", timeout=60000)
        assert_not_auth_error_page(page, "login_entrypoint")

        if login_flow == "oidc":
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
        else:
            username_input = page.locator(
                "input[name='emailOrUsername'], "
                "input[name='email'], "
                "input[name='username'], "
                "input[type='email'], "
                "input[autocomplete='username'], "
                "input[id*='email' i], "
                "input[id*='username' i]"
            ).first
            password_input = page.locator(
                "input[name='password'], input[type='password'], input[autocomplete='current-password']"
            ).first

            try:
                username_input.wait_for(state="visible", timeout=30000)
                username_input.fill(email, timeout=30000)
            except Exception as exc:
                fail(f"local_authn_username_input_not_ready: {exc}", page=page)

            try:
                password_input.wait_for(state="visible", timeout=30000)
                password_input.fill(password, timeout=30000)
            except Exception as exc:
                fail(f"local_authn_password_input_not_ready: {exc}", page=page)

            submit_clicked = False
            try:
                page.get_by_role("button", name=re.compile(r"log in|sign in|continue", re.I)).first.click(timeout=20000)
                submit_clicked = True
            except Exception:
                pass
            if not submit_clicked:
                try:
                    password_input.press("Enter")
                except Exception as exc:
                    fail(f"local_authn_submit_failed: {exc}", page=page)

            page.wait_for_load_state("domcontentloaded", timeout=60000)
            if "/authn/login" in (page.url or ""):
                try:
                    page.wait_for_url(
                        re.compile(rf"^https://({re.escape(lms_domain)}|{re.escape(mfe_domain)})/(?!authn/login).*"),
                        timeout=30000,
                    )
                except PWTimeout:
                    pass
            if "/authn/login" in (page.url or ""):
                refresh_probe = probe_login_refresh_status(context.request, f"https://{mfe_domain}")
                fail(
                    f"local_authn_submit_still_on_login url={page.url} "
                    f"(login_refresh_probe={refresh_probe}; credentials rejected or session cookie not set)",
                    page=page,
                )
            assert_not_auth_error_page(page, "local_authn_submitted")

        session_api_base = f"https://{mfe_domain}" if login_flow == "local" else base_url
        me_resp = context.request.get(f"{session_api_base}/api/user/v1/me")
        me_status = me_resp.status
        me_body = me_resp.text() or ""
        if me_status != 200:
            refresh_probe = probe_login_refresh_status(context.request, session_api_base)
            fail(
                f"/api/user/v1/me status={me_status} (expected 200) "
                f"base={session_api_base} login_refresh_probe={refresh_probe}",
                page=page,
            )
        if "username" not in me_body:
            fail("/api/user/v1/me response missing username marker", page=page)

        if login_flow == "local":
            if debug:
                log(f"goto={home_mfe_url}")
            page.goto(home_mfe_url, wait_until="domcontentloaded", timeout=60000)
            page.wait_for_load_state("domcontentloaded", timeout=60000)
            if "/authn/login" in (page.url or ""):
                refresh_probe = probe_login_refresh_status(context.request, f"https://{mfe_domain}")
                fail(
                    f"local_home_redirected_to_authn_login url={page.url} "
                    f"(login_refresh_probe={refresh_probe}; login seemed successful but session did not persist)",
                    page=page,
                )
            assert_not_auth_error_page(page, "local_home_navigation")

            if debug:
                log(f"goto={sso_mfe_learner_dashboard_url}")
            page.goto(sso_mfe_learner_dashboard_url, wait_until="domcontentloaded", timeout=60000)
            page.wait_for_load_state("domcontentloaded", timeout=60000)
            if "/authn/login" in (page.url or ""):
                refresh_probe = probe_login_refresh_status(context.request, f"https://{mfe_domain}")
                fail(
                    f"local_learner_dashboard_redirected_to_authn_login url={page.url} "
                    f"(login_refresh_probe={refresh_probe}; likely cookie domain/session drift)",
                    page=page,
                )
            assert_not_auth_error_page(page, "local_mfe_learner_dashboard")
            log("OK local authn session validated")
            raise SystemExit(0)

        # Studio SSO is sensitive to cookie/session churn if we touch the Authn MFE
        # first (it can trigger refresh flows that overwrite/clear session state).
        # For the Studio-capable canary run, validate Studio directly after OIDC
        # callback, without visiting LMS/MFE pages.
        if require_studio_access:
            if debug:
                log(f"goto={studio_url}")
            manual_redirect_probe(studio_url)
            if debug:
                log(f"manual_probe_entries={len(_http_trace)}")
            try:
                page.goto(studio_url, wait_until="domcontentloaded", timeout=60000)
            except PWError as exc:
                fail(f"studio_goto_error: {exc}", page=page)
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

            if debug:
                log(f"goto={studio_home_url}")
            try:
                page.goto(studio_home_url, wait_until="domcontentloaded", timeout=60000)
            except PWError as exc:
                fail(f"studio_home_goto_error: {exc}", page=page)
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
            raise SystemExit(0)

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
            refresh_probe = probe_login_refresh_status(context.request, f"https://{mfe_domain}")
            fail(
                f"mfe_learner_dashboard_redirected_to_authn_login url={page.url} "
                f"(login_refresh_probe={refresh_probe}; likely cookie or reverse-proxy drift)",
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
  elif [[ "$env_name" == "staging" ]]; then
    lms_domain="$STAGING_LMS_DOMAIN"
    studio_domain="$STAGING_STUDIO_DOMAIN"
    mfe_domain="$STAGING_MFE_DOMAIN"
    email="${SSO_CANARY_EMAIL_STAGING:-${SSO_CANARY_EMAIL:-}}"
    password="${SSO_CANARY_PASSWORD_STAGING:-${SSO_CANARY_PASSWORD:-}}"
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
    "0" \
    "oidc"
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
  elif [[ "$env_name" == "staging" ]]; then
    lms_domain="$STAGING_LMS_DOMAIN"
    studio_domain="$STAGING_STUDIO_DOMAIN"
    mfe_domain="$STAGING_MFE_DOMAIN"
    email="${SSO_CANARY_STUDIO_EMAIL_STAGING:-${SSO_CANARY_STUDIO_EMAIL:-}}"
    password="${SSO_CANARY_STUDIO_PASSWORD_STAGING:-${SSO_CANARY_STUDIO_PASSWORD:-}}"
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
    "1" \
    "oidc"
}

run_local_login_env() {
  local env_name="$1"
  local lms_domain studio_domain mfe_domain email password

  if [[ "$env_name" == "prod" ]]; then
    lms_domain="$LMS_DOMAIN"
    studio_domain="$STUDIO_DOMAIN"
    mfe_domain="$MFE_DOMAIN"
    email="${LOCAL_CANARY_EMAIL_PROD:-${LOCAL_CANARY_EMAIL:-${SSO_CANARY_EMAIL_PROD:-${SSO_CANARY_EMAIL:-}}}}"
    password="${LOCAL_CANARY_PASSWORD_PROD:-${LOCAL_CANARY_PASSWORD:-${SSO_CANARY_PASSWORD_PROD:-${SSO_CANARY_PASSWORD:-}}}}"
  elif [[ "$env_name" == "staging" ]]; then
    lms_domain="$STAGING_LMS_DOMAIN"
    studio_domain="$STAGING_STUDIO_DOMAIN"
    mfe_domain="$STAGING_MFE_DOMAIN"
    email="${LOCAL_CANARY_EMAIL_STAGING:-${LOCAL_CANARY_EMAIL:-${SSO_CANARY_EMAIL_STAGING:-${SSO_CANARY_EMAIL:-}}}}"
    password="${LOCAL_CANARY_PASSWORD_STAGING:-${LOCAL_CANARY_PASSWORD:-${SSO_CANARY_PASSWORD_STAGING:-${SSO_CANARY_PASSWORD:-}}}}"
  else
    lms_domain="$DEV_LMS_DOMAIN"
    studio_domain="$DEV_STUDIO_DOMAIN"
    mfe_domain="$DEV_MFE_DOMAIN"
    email="${LOCAL_CANARY_EMAIL_DEV:-${LOCAL_CANARY_EMAIL:-${SSO_CANARY_EMAIL_DEV:-${SSO_CANARY_EMAIL:-}}}}"
    password="${LOCAL_CANARY_PASSWORD_DEV:-${LOCAL_CANARY_PASSWORD:-${SSO_CANARY_PASSWORD_DEV:-${SSO_CANARY_PASSWORD:-}}}}"
  fi

  if [[ -z "${email:-}" || -z "${password:-}" ]]; then
    if [[ "$REQUIRE_LOCAL_CANARY" == "1" ]]; then
      echo "FAIL $env_name: missing local authn canary credentials (set LOCAL_CANARY_EMAIL[_${env_name^^}] and LOCAL_CANARY_PASSWORD[_${env_name^^}])" >&2
      failures=$((failures + 1))
      return
    fi
    echo "SKIP $env_name: missing local authn canary credentials (REQUIRE_LOCAL_CANARY=0)"
    return
  fi

  run_playwright_canary \
    "$env_name" \
    "$lms_domain" \
    "$studio_domain" \
    "$mfe_domain" \
    "$email" \
    "$password" \
    "$(date -u +%Y%m%dT%H%M%SZ)-${env_name}-local" \
    "0" \
    "local"
}

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  if [[ "$RUN_OIDC_CANARY" == "1" ]]; then
    run_primary_env "prod"
  fi
  if [[ "$RUN_STUDIO_CANARY" == "1" ]]; then
    run_studio_env "prod"
  fi
  if [[ "$RUN_LOCAL_LOGIN_CANARY" == "1" ]]; then
    run_local_login_env "prod"
  fi
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  if [[ "$RUN_OIDC_CANARY" == "1" ]]; then
    run_primary_env "dev"
  fi
  if [[ "$RUN_STUDIO_CANARY" == "1" ]]; then
    run_studio_env "dev"
  fi
  if [[ "$RUN_LOCAL_LOGIN_CANARY" == "1" ]]; then
    run_local_login_env "dev"
  fi
fi

if [[ "$ENV_SCOPE" == "staging" || "$ENV_SCOPE" == "all" ]]; then
  if [[ "$RUN_OIDC_CANARY" == "1" ]]; then
    run_primary_env "staging"
  fi
  if [[ "$RUN_STUDIO_CANARY" == "1" ]]; then
    run_studio_env "staging"
  fi
  if [[ "$RUN_LOCAL_LOGIN_CANARY" == "1" ]]; then
    run_local_login_env "staging"
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  echo "FAILED ($failures runs failed)" >&2
  exit 1
fi

echo "OK"
