#!/usr/bin/env bash
# verify-csp-headers.sh — CSP configuration gate (Phase 0 scaffold)
# @covers AC-SEC-CSP-001, AC-SEC-CSP-002, AC-SEC-CSP-003, AC-SEC-CSP-004
# @spec: specs/security-hardening_spec.md
#
# Verifies:
# 1. CSP_SCRIPT_SRC is configured in the plugin (unsafe-inline / unsafe-eval present, expected).
# 2. CSP_REPORT_ONLY flag is present and configurable.
# 3. CSP_REPORT_URI wiring exists (env-configurable, defaults to disabled).
# 4. CSP nonce injection is configured (CSP_INCLUDE_NONCE_IN).
# 5. Live LMS CSP header check (report mode — exit 0 even if directives differ).
#
# This script NEVER fails on unsafe-inline/unsafe-eval presence — those are
# intentional until Phase 2 of the nonce migration (see docs/adr/025-csp-nonce-migration.md).
#
# Offline mode (no cluster): parses plugin source files only.
# Online mode: also curls the LMS and reports which directives are present.
#
# Usage:
#   ./scripts/qa/verify-csp-headers.sh              # offline (CI default)
#   LMS_URL=https://academyv2.mereka.io ./scripts/qa/verify-csp-headers.sh  # online
#   STRICT=1 ./scripts/qa/verify-csp-headers.sh     # treat WARNs as FAILs
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
STRICT="${STRICT:-0}"
LMS_URL="${LMS_URL:-}"

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
do_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

check_plugin_pattern() {
  local pattern="$1"
  local description="$2"
  if mereka_plugin_has_fixed "$REPO_ROOT" "$pattern"; then
    do_pass "$description"
    return 0
  fi
  do_fail "$description — pattern '$pattern' not found in plugin contract sources"
  return 1
}

check_plugin_regex() {
  local pattern="$1"
  local description="$2"
  if mereka_plugin_has_regex "$REPO_ROOT" "$pattern"; then
    do_pass "$description"
    return 0
  fi
  do_fail "$description — regex '$pattern' not found in plugin contract sources"
  return 1
}

printf "${BLUE}=== CSP Headers Gate (Phase 0 — ADR-025)${NC}\n"
printf "  repo root: %s\n\n" "$REPO_ROOT"

# ── 1. Static source checks ───────────────────────────────────────────────────

printf "${BLUE}── 1. Plugin source: CSP directives ────────────────────────────${NC}\n"

check_plugin_pattern "CSP_SCRIPT_SRC" \
  "CSP_SCRIPT_SRC defined in plugin"

check_plugin_pattern "CSP_DEFAULT_SRC" \
  "CSP_DEFAULT_SRC defined in plugin"

check_plugin_pattern "CSP_STYLE_SRC" \
  "CSP_STYLE_SRC defined in plugin"

check_plugin_pattern "CSP_IMG_SRC" \
  "CSP_IMG_SRC defined in plugin"

check_plugin_pattern "CSP_CONNECT_SRC" \
  "CSP_CONNECT_SRC defined in plugin"

check_plugin_pattern "CSP_OBJECT_SRC" \
  "CSP_OBJECT_SRC defined in plugin (should be 'none')"

check_plugin_pattern "CSP_FORM_ACTION" \
  "CSP_FORM_ACTION defined in plugin (should be 'self')"

# Confirm the permissive directives are still present (Phase 0 — expected)
check_plugin_pattern "'unsafe-inline'" \
  "unsafe-inline present (Phase 0 — intentional, see ADR-025)"

check_plugin_pattern "'unsafe-eval'" \
  "unsafe-eval present (Phase 0 — intentional, see ADR-025)"

printf "\n${BLUE}── 2. Plugin source: report-only / report-uri wiring ───────────${NC}\n"

check_plugin_pattern "CSP_REPORT_ONLY" \
  "CSP_REPORT_ONLY flag present (env-configurable)"

check_plugin_pattern "CSP_REPORT_URI" \
  "CSP_REPORT_URI wiring present (env-configurable, defaults to disabled)"

check_plugin_pattern "CSP_INCLUDE_NONCE_IN" \
  "CSP_INCLUDE_NONCE_IN set (nonce injection scaffold — Phase 0)"

check_plugin_regex "csp\.middleware\.CSPMiddleware" \
  "CSPMiddleware added to MIDDLEWARE stack"

printf "\n${BLUE}── 3. ADR-025 exists ────────────────────────────────────────────${NC}\n"

ADR_FILE="$REPO_ROOT/docs/adr/025-csp-nonce-migration.md"
if [[ -f "$ADR_FILE" ]]; then
  do_pass "ADR-025 CSP nonce migration document present"
else
  do_fail "ADR-025 missing: $ADR_FILE"
fi

# ── 2. Live header check (optional — report-only mode) ────────────────────────

if [[ -n "$LMS_URL" ]]; then
  printf "\n${BLUE}── 4. Live LMS CSP header report ────────────────────────────────${NC}\n"
  do_info "Fetching headers from $LMS_URL ..."

  if ! command -v curl &>/dev/null; then
    do_warn "curl not available — skipping live header check"
  else
    # Capture headers with 10s timeout; do not fail the gate on network errors
    csp_header=""
    csp_ro_header=""
    if http_response=$(curl -sI --max-time 10 "$LMS_URL" 2>/dev/null); then
      csp_header=$(printf '%s' "$http_response" \
        | grep -i '^content-security-policy:' \
        | grep -v 'report-only' || true)
      csp_ro_header=$(printf '%s' "$http_response" \
        | grep -i '^content-security-policy-report-only:' || true)
    else
      do_warn "Could not reach $LMS_URL — skipping live header check"
    fi

    if [[ -n "$csp_header" ]]; then
      do_info "CSP enforcement header present"
      # Report directives — informational only, no PASS/FAIL
      for directive in "unsafe-inline" "unsafe-eval" "nonce-" "strict-dynamic" "report-uri"; do
        if printf '%s' "$csp_header" | grep -qi "$directive"; then
          do_info "  directive present: $directive"
        fi
      done
    else
      do_warn "No Content-Security-Policy enforcement header found on $LMS_URL"
      do_info "  (Expected during Phase 0 if CSP_REPORT_ONLY=true)"
    fi

    if [[ -n "$csp_ro_header" ]]; then
      do_info "Content-Security-Policy-Report-Only header present"
      for directive in "nonce-" "strict-dynamic" "report-uri"; do
        if printf '%s' "$csp_ro_header" | grep -qi "$directive"; then
          do_info "  report-only directive present: $directive"
        fi
      done
    else
      do_info "No CSP-Report-Only header (expected until Phase 1 — Caddy not yet wired)"
    fi
  fi
else
  printf "\n"
  do_info "Offline mode — set LMS_URL=https://academyv2.mereka.io for live header check"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

printf "\n${BLUE}────────────────────────────────────────────────────────────────${NC}\n"
printf "  PASS: ${GREEN}%d${NC}  FAIL: ${RED}%d${NC}  WARN: ${YELLOW}%d${NC}\n" \
  "$PASS" "$FAIL" "$WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL${NC}"
  exit 1
fi

echo -e "${GREEN}RESULT: PASS${NC}"
exit 0
