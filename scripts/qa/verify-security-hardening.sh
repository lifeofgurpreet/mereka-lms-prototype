#!/usr/bin/env bash
# verify-security-hardening.sh — Static gate for T119 security hardening
# @covers AC-SEC-001, AC-SEC-002, AC-SEC-003, AC-SEC-004, AC-SEC-005
# @spec: specs/security-hardening_spec.md
#
# Verifies:
# 1. HSTS + security response headers configured in Caddy patch (AC-SEC-001)
# 2. CSP baseline settings present in Django production.py (AC-SEC-002)
# 3. Rate limiting configured for auth endpoints (AC-SEC-003)
# 4. Session/CSRF cookie security flags set (AC-SEC-004)
# 5. X-Content-Type-Options / X-Frame-Options headers in Caddy patch (AC-SEC-005)
#
# This is a static repo check — it does not require a running cluster.
# Live header checks are performed by verify-public-branding.sh + curl probes.
#
# Usage: ./scripts/qa/verify-security-hardening.sh
#   Set STRICT=1 to treat WARNs as FAILs.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
STRICT="${STRICT:-0}"

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() {
  if [[ "$STRICT" == "1" ]]; then
    FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} (strict) $1"
  else
    WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"
  fi
}

PATCH_FILE="$REPO_ROOT/infrastructure/tutor/patches/security-hardening.sh"
APPLY_SH="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
PROD_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

echo -e "${BLUE}=== Security Hardening Gate (T119) ===${NC}"
echo "  Caddy patch:    infrastructure/tutor/patches/security-hardening.sh"
echo "  apply-patches:  infrastructure/tutor/apply-patches.sh"
echo "  Django settings: deploy/k8s/base/apps/openedx/settings/lms/production.py"
echo ""

# ── 1. Patch file exists ────────────────────────────────────────────────────
if [[ -f "$PATCH_FILE" ]]; then
  do_pass "security-hardening.sh patch file exists"
else
  do_fail "security-hardening.sh patch file missing: $PATCH_FILE"
fi

# ── 2. Patch registered in apply-patches.sh ────────────────────────────────
if grep -q "security-hardening.sh" "$APPLY_SH" 2>/dev/null; then
  do_pass "security-hardening.sh sourced in apply-patches.sh"
else
  do_fail "security-hardening.sh NOT sourced in apply-patches.sh"
fi

if grep -q "apply_security_hardening_patch" "$APPLY_SH" 2>/dev/null; then
  do_pass "apply_security_hardening_patch called in apply-patches.sh"
else
  do_fail "apply_security_hardening_patch NOT called in apply-patches.sh"
fi

# ── 3. HSTS header in Caddy patch ─────────────────────────────────────────
if grep -q "Strict-Transport-Security" "$PATCH_FILE" 2>/dev/null; then
  do_pass "HSTS header (Strict-Transport-Security) present in Caddy patch"
else
  do_fail "HSTS header missing from Caddy patch"
fi

if grep -q "includeSubDomains" "$PATCH_FILE" 2>/dev/null; then
  do_pass "HSTS includeSubDomains directive present"
else
  do_warn "HSTS includeSubDomains missing — recommended for production"
fi

if grep -q "preload" "$PATCH_FILE" 2>/dev/null; then
  do_pass "HSTS preload directive present"
else
  do_warn "HSTS preload missing — add after verifying HSTS on all sub-domains"
fi

# ── 4. Security response headers in Caddy patch ────────────────────────────
for header in "X-Content-Type-Options" "X-Frame-Options" "Referrer-Policy" "Permissions-Policy"; do
  if grep -q "$header" "$PATCH_FILE" 2>/dev/null; then
    do_pass "Caddy patch includes $header"
  else
    do_fail "Caddy patch missing $header"
  fi
done

# X-XSS-Protection should be set to "0" (disable legacy filter, rely on CSP)
if grep -q 'X-XSS-Protection.*"0"' "$PATCH_FILE" 2>/dev/null; then
  do_pass "X-XSS-Protection set to 0 (deprecate in favour of CSP)"
else
  do_warn "X-XSS-Protection not explicitly disabled — browsers may enable legacy filter"
fi

# ── 5. CSP settings in Django production.py ────────────────────────────────
if [[ -f "$PROD_PY" ]]; then
  if grep -q "CSP_DEFAULT_SRC" "$PROD_PY"; then
    do_pass "CSP_DEFAULT_SRC configured in production.py"
  else
    do_fail "CSP_DEFAULT_SRC missing from production.py"
  fi

  if grep -q "CSP_SCRIPT_SRC" "$PROD_PY"; then
    do_pass "CSP_SCRIPT_SRC configured in production.py"
  else
    do_fail "CSP_SCRIPT_SRC missing from production.py"
  fi

  if grep -q "CSP_REPORT_ONLY" "$PROD_PY"; then
    do_pass "CSP_REPORT_ONLY flag present (controls enforce vs report-only mode)"
  else
    do_warn "CSP_REPORT_ONLY not set — defaulting to enforce mode may break MFEs"
  fi

  if grep -q "CSP_OBJECT_SRC.*'none'" "$PROD_PY"; then
    do_pass "CSP_OBJECT_SRC set to 'none' (blocks Flash/plugins)"
  else
    do_warn "CSP_OBJECT_SRC not restricted to 'none'"
  fi
else
  do_fail "production.py not found: $PROD_PY"
fi

# ── 6. Rate limiting settings in production.py ────────────────────────────
if [[ -f "$PROD_PY" ]]; then
  if grep -q "DEFAULT_THROTTLE_RATES" "$PROD_PY"; then
    do_pass "DEFAULT_THROTTLE_RATES configured in production.py"
  else
    do_fail "DEFAULT_THROTTLE_RATES missing from production.py"
  fi

  if grep -q "login_and_register" "$PROD_PY"; then
    do_pass "login_and_register throttle rate configured"
  else
    do_fail "login_and_register throttle rate missing"
  fi

  if grep -q "password_reset" "$PROD_PY"; then
    do_pass "password_reset throttle rate configured"
  else
    do_fail "password_reset throttle rate missing"
  fi

  if grep -q "MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED" "$PROD_PY"; then
    do_pass "MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED configured"
  else
    do_fail "MAX_FAILED_LOGIN_ATTEMPTS_ALLOWED missing from production.py"
  fi

  if grep -q "MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS" "$PROD_PY"; then
    do_pass "MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS configured"
  else
    do_fail "MAX_FAILED_LOGIN_ATTEMPTS_LOCKOUT_PERIOD_SECS missing from production.py"
  fi
fi

# ── 7. Session / CSRF cookie security flags ───────────────────────────────
if [[ -f "$PROD_PY" ]]; then
  if grep -q "SESSION_COOKIE_SECURE = True" "$PROD_PY"; then
    do_pass "SESSION_COOKIE_SECURE = True set in production.py"
  else
    do_fail "SESSION_COOKIE_SECURE = True missing from production.py"
  fi

  if grep -q "SESSION_COOKIE_HTTPONLY = True" "$PROD_PY"; then
    do_pass "SESSION_COOKIE_HTTPONLY = True set in production.py"
  else
    do_fail "SESSION_COOKIE_HTTPONLY = True missing from production.py"
  fi

  if grep -q "CSRF_COOKIE_SECURE = True" "$PROD_PY"; then
    do_pass "CSRF_COOKIE_SECURE = True set in production.py"
  else
    do_fail "CSRF_COOKIE_SECURE = True missing from production.py"
  fi

  # CSRF_COOKIE_HTTPONLY must remain False — MFEs read the token via JS
  if grep -q "CSRF_COOKIE_HTTPONLY = False" "$PROD_PY"; then
    do_pass "CSRF_COOKIE_HTTPONLY = False (required for MFE JS access)"
  else
    do_warn "CSRF_COOKIE_HTTPONLY not explicitly set to False — MFE CSRF fetches may break"
  fi
fi

# ── 8. Security Hardening sentinel present in patch and production.py ──────
if grep -q "Security Hardening (T119)" "$PATCH_FILE" 2>/dev/null; then
  do_pass "Security hardening sentinel present in patch file"
else
  do_warn "Security hardening sentinel missing from patch — idempotency guard may not work"
fi

if [[ -f "$PROD_PY" ]] && grep -q "Security Hardening (T119)" "$PROD_PY"; then
  do_pass "Security hardening sentinel present in production.py (patch was applied)"
else
  do_warn "Security hardening sentinel not yet in production.py — run apply-patches.sh to apply"
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
