#!/usr/bin/env bash
# verify-csp-report-pipeline.sh — CSP report collector wiring gate (Phase 1)
# @covers AC-SEC-CSP-003, AC-SEC-CSP-004
# @spec: specs/security-hardening_spec.md
#
# Modes:
# - Static (default): validates CSP report URI derivation wiring in source.
# - Runtime (optional): posts a synthetic CSP violation payload to report URI.
#
# Runtime env:
#   RUN_RUNTIME_CHECK=1
#   CSP_REPORT_URI=...   (optional; overrides DSN derivation)
#   SENTRY_DSN=...       (optional; used to derive report URI)
#   STRICT_RUNTIME=1     (fail when runtime endpoint cannot be resolved/reached)
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
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
RUN_RUNTIME_CHECK="${RUN_RUNTIME_CHECK:-0}"
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"

do_pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
do_warn() {
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    do_fail "(strict-runtime) $1"
  else
    WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"
  fi
}
do_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

PROD_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

check_plugin_pattern() {
  local pattern="$1"
  local description="$2"
  if mereka_plugin_has_fixed "$REPO_ROOT" "$pattern"; then
    do_pass "$description"
  else
    do_fail "$description — missing '$pattern' in plugin sources"
  fi
}

check_prod_pattern() {
  local pattern="$1"
  local description="$2"
  if grep -qF "$pattern" "$PROD_PY"; then
    do_pass "$description"
  else
    do_fail "$description — missing '$pattern' in production.py"
  fi
}

printf "${BLUE}=== CSP Report Pipeline Gate (Phase 1) ===${NC}\n"
printf "  repo root: %s\n\n" "$REPO_ROOT"

printf "${BLUE}── 1. Static source checks ──────────────────────────────────────${NC}\n"

check_plugin_pattern "from urllib.parse import urlparse as _urlparse" \
  "Plugin uses URL parsing for DSN-derived CSP report URI"
check_plugin_pattern "def _derive_sentry_csp_report_uri(_dsn):" \
  "Plugin defines sentry DSN -> CSP report URI helper"
check_plugin_pattern "CSP_REPORT_URI = _csp_report_uri" \
  "Plugin sets CSP_REPORT_URI when resolved"

check_prod_pattern "from urllib.parse import urlparse as _urlparse" \
  "production.py uses URL parsing for DSN-derived CSP report URI"
check_prod_pattern "def _derive_sentry_csp_report_uri(_dsn):" \
  "production.py defines sentry DSN -> CSP report URI helper"
check_prod_pattern "CSP_REPORT_URI = _csp_report_uri" \
  "production.py sets CSP_REPORT_URI when resolved"

if mereka_plugin_has_fixed "$REPO_ROOT" "https://sentry.io/api/"; then
  do_fail "Plugin still hardcodes sentry.io API endpoint"
else
  do_pass "Plugin does not hardcode sentry.io API endpoint"
fi

if grep -qF "https://sentry.io/api/" "$PROD_PY"; then
  do_fail "production.py still hardcodes sentry.io API endpoint"
else
  do_pass "production.py does not hardcode sentry.io API endpoint"
fi

printf "\n${BLUE}── 2. Runtime collector check (optional) ───────────────────────${NC}\n"

if [[ "$RUN_RUNTIME_CHECK" != "1" ]]; then
  do_info "Runtime check disabled. Set RUN_RUNTIME_CHECK=1 to POST synthetic CSP report."
else
  derive_uri() {
    python3 - <<'PY'
from urllib.parse import urlparse
import os

explicit = (os.environ.get("CSP_REPORT_URI", "") or "").strip()
if explicit:
    print(explicit)
    raise SystemExit(0)

dsn = (os.environ.get("SENTRY_DSN", "") or "").strip()
if not dsn:
    print("")
    raise SystemExit(0)

try:
    parsed = urlparse(dsn)
except Exception:
    print("")
    raise SystemExit(0)

public_key = (parsed.username or "").strip()
project_id = ((parsed.path or "").rstrip("/").split("/")[-1] or "").strip()
netloc = (parsed.netloc or "").split("@", 1)[-1]
scheme = (parsed.scheme or "https").strip()
if not (public_key and project_id.isdigit() and netloc):
    print("")
    raise SystemExit(0)

print(f"{scheme}://{netloc}/api/{project_id}/security/?sentry_key={public_key}")
PY
  }

  sanitize_uri() {
    python3 - "$1" <<'PY'
import sys
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

uri = sys.argv[1]
parsed = urlparse(uri)
query = parse_qs(parsed.query, keep_blank_values=True)
if "sentry_key" in query:
    query["sentry_key"] = ["***"]
sanitized = urlunparse(parsed._replace(query=urlencode(query, doseq=True)))
print(sanitized)
PY
  }

  report_uri="$(derive_uri)"
  if [[ -z "$report_uri" ]]; then
    do_warn "CSP report URI is unresolved (set CSP_REPORT_URI or SENTRY_DSN)"
  elif ! command -v curl >/dev/null 2>&1; then
    do_warn "curl not found; cannot perform runtime collector check"
  else
    safe_uri="$(sanitize_uri "$report_uri")"
    do_info "Posting synthetic CSP violation to: $safe_uri"

    payload='{"csp-report":{"document-uri":"https://academyv2.mereka.io/","violated-directive":"script-src-elem","effective-directive":"script-src-elem","original-policy":"default-src '\''self'\''; report-uri /csp-report","disposition":"report","blocked-uri":"inline"}}'

    tmp_body="$(mktemp)"
    status_code="$(
      curl -sS -o "$tmp_body" -w "%{http_code}" \
        -X POST \
        -H "Content-Type: application/csp-report" \
        --data "$payload" \
        --max-time 15 \
        "$report_uri" || true
    )"

    if [[ "$status_code" =~ ^2[0-9][0-9]$ ]]; then
      do_pass "Runtime CSP report collector accepted synthetic report (HTTP $status_code)"
    else
      body_preview="$(head -c 200 "$tmp_body" | tr '\n' ' ' || true)"
      do_warn "Runtime CSP report collector response was HTTP ${status_code:-unknown}; body='${body_preview}'"
    fi
    rm -f "$tmp_body"
  fi
fi

printf "\n${BLUE}────────────────────────────────────────────────────────────────${NC}\n"
printf "  PASS: ${GREEN}%d${NC}  FAIL: ${RED}%d${NC}  WARN: ${YELLOW}%d${NC}\n" \
  "$PASS" "$FAIL" "$WARN"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL${NC}"
  exit 1
fi

echo -e "${GREEN}RESULT: PASS${NC}"
exit 0
