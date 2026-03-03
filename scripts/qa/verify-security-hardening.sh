#!/usr/bin/env bash
# verify-security-hardening.sh — Static gate for T119 security hardening
# @covers AC-SEC-001, AC-SEC-002, AC-SEC-003, AC-SEC-004, AC-SEC-005
# @spec: specs/security-hardening_spec.md
#
# Verifies:
# 1. Security response headers configured in the static MFE Caddyfile (HSTS, X-CTO, XFO, Referrer, Permissions).
# 2. CSP baseline settings present in plugin source and generated production settings.
# 3. Rate limiting configured for auth endpoints.
# 4. Session/CSRF cookie security flags set.
#
# This is a static repo check — it does not require a running cluster.
# Live header checks are performed by verify-public-branding.sh + curl probes.
#
# Usage: ./scripts/qa/verify-security-hardening.sh
#   Set STRICT=1 to treat WARNs as FAILs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
STRICT="${STRICT:-0}"

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() {
  if [[ "$STRICT" == "1" ]]; then
    FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} (strict) $1"
  else
    WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"
  fi
}

PLUGIN_FILE="$PLUGIN_MAIN"
MFE_CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
PROD_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

check_file_exists() {
  local file="$1"
  local description="$2"
  if [[ -f "$file" ]]; then
    do_pass "$description exists: $file"
    return 0
  fi
  do_fail "$description missing: $file"
  return 1
}

check_pattern() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  if [[ ! -f "$file" ]]; then
    do_fail "$description - file not found: $file"
    return 1
  fi
  if grep -qF "$pattern" "$file" 2>/dev/null; then
    do_pass "$description"
    return 0
  fi
  do_fail "$description - pattern not found in $file"
  return 1
}

check_plugin_pattern() {
  local pattern="$1"
  local description="$2"
  if [[ ! -f "$PLUGIN_FILE" ]] && ! mereka_plugin_has_any "$REPO_ROOT"; then
    do_fail "$description - plugin contract sources not found"
    return 1
  fi
  if mereka_plugin_has_fixed "$REPO_ROOT" "$pattern"; then
    do_pass "$description"
    return 0
  fi
  do_fail "$description - pattern not found in plugin contract sources"
  return 1
}

pattern_present() {
  local file="$1"
  local pattern="$2"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  grep -qF "$pattern" "$file" 2>/dev/null
}

printf "${BLUE}=== Security Hardening Gate (T119)${NC}\n"
printf "  plugin source:  %s\n" "$PLUGIN_MAIN"
printf "  mfe caddyfile:  deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile\n"
printf "  django settings: deploy/k8s/base/apps/openedx/settings/lms/production.py\n\n"

# ── 1. Security hardening in plugin settings ─────────────────────────────
check_plugin_pattern "CSP_DEFAULT_SRC" "CSP_DEFAULT_SRC configured in plugin production settings hook"
check_plugin_pattern "CSP_SCRIPT_SRC" "CSP_SCRIPT_SRC configured in plugin production settings hook"
check_plugin_pattern "CSP_REPORT_ONLY" "CSP_REPORT_ONLY flag present in plugin"
check_plugin_pattern "DEFAULT_THROTTLE_RATES" "DEFAULT_THROTTLE_RATES block added in plugin"
check_plugin_pattern "SESSION_COOKIE_SECURE = True" "Session hardening flags added in plugin"
check_plugin_pattern "CSRF_COOKIE_SECURE = True" "CSRF hardening flags added in plugin"
check_plugin_pattern "CSRF_COOKIE_HTTPONLY = False" "CSRF_HTTPONLY false remains required for MFE"
check_plugin_pattern "REST_FRAMEWORK.setdefault(\"DEFAULT_THROTTLE_RATES\"" "REST_FRAMEWORK throttle defaults are initialized in plugin"

# ── 2. Caddy security headers (static k8s Caddyfile) ─────────────────────
check_file_exists "$MFE_CADDYFILE" "MFE static k8s Caddyfile"
if [[ -f "$MFE_CADDYFILE" ]]; then
  for header in "Strict-Transport-Security" "X-Content-Type-Options" "X-Frame-Options" "Content-Security-Policy" "Referrer-Policy" "Permissions-Policy"; do
    check_pattern "$MFE_CADDYFILE" "$header" "MFE Caddyfile includes $header"
  done

  if pattern_present "$MFE_CADDYFILE" "includeSubDomains"; then
    do_pass "MFE Caddyfile includes HSTS includeSubDomains"
  else
    do_warn "MFE Caddyfile HSTS includeSubDomains missing — recommended for production"
  fi

  if pattern_present "$MFE_CADDYFILE" "preload"; then
    do_pass "MFE Caddyfile includes preload directive"
  else
    do_warn "MFE Caddyfile preload missing — add only after DNS/domain validation"
  fi
fi

# ── 3. CSP settings in generated production.py ────────────────────────────
check_file_exists "$PROD_PY" "Generated LMS production.py"
if [[ -f "$PROD_PY" ]]; then
  check_pattern "$PROD_PY" "CSP_DEFAULT_SRC" "CSP_DEFAULT_SRC configured in production.py"
  check_pattern "$PROD_PY" "CSP_SCRIPT_SRC" "CSP_SCRIPT_SRC configured in production.py"

  if check_pattern "$PROD_PY" "CSP_REPORT_ONLY" "CSP_REPORT_ONLY present in production.py"; then :; fi

  if grep -qE "CSP_OBJECT_SRC.*'none'" "$PROD_PY"; then
    do_pass "CSP_OBJECT_SRC restricts object sources"
  else
    do_warn "CSP_OBJECT_SRC not explicitly restricted to 'none'"
  fi
fi

# ── 4. Rate limiting + session flags in generated production.py ───────────
if [[ -f "$PROD_PY" ]]; then
  check_pattern "$PROD_PY" "DEFAULT_THROTTLE_RATES" "DEFAULT_THROTTLE_RATES configured in production.py"
  check_pattern "$PROD_PY" "login_and_register" "login_and_register throttle rate configured"
  check_pattern "$PROD_PY" "password_reset" "password_reset throttle rate configured"
  check_pattern "$PROD_PY" "MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED" "MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED configured"
  check_pattern "$PROD_PY" "MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS" "MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS configured"

  check_pattern "$PROD_PY" "SESSION_COOKIE_SECURE = True" "SESSION_COOKIE_SECURE = True in production.py"
  check_pattern "$PROD_PY" "SESSION_COOKIE_HTTPONLY = True" "SESSION_COOKIE_HTTPONLY = True in production.py"
  check_pattern "$PROD_PY" "CSRF_COOKIE_SECURE = True" "CSRF_COOKIE_SECURE = True in production.py"

  if pattern_present "$PROD_PY" "CSRF_COOKIE_HTTPONLY = False"; then
    do_pass "CSRF_COOKIE_HTTPONLY = False in production.py (required for MFE CSRF token fetch)"
  else
    do_warn "CSRF_COOKIE_HTTPONLY is not explicitly False in production.py"
  fi
fi

# ── Summary ────────────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "\n${RED}GATE FAILED${NC} — $FAIL check(s) failed."
  exit 1
fi

echo -e "\n${GREEN}GATE PASSED${NC}"
exit 0
