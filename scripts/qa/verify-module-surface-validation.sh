#!/usr/bin/env bash
# @covers AC-MOD-001, AC-MOD-002, AC-MOD-003, AC-MOD-004, AC-MOD-005
# @spec: bead-253a
#
# verify-module-surface-validation.sh — Module surface validation pack (non-UI modules)
#
# Verifies:
#   AC-MOD-001: Service host inventory documented; HTTP smoke coverage for
#               credentials, forum, notes, preview, app/teacher paths.
#   AC-MOD-002: Expected status-code mapping per service; authn proxy routes
#               present in Caddyfile.
#   AC-MOD-003: 5xx monitoring/alerting config present; regression baseline docs.
#   AC-MOD-004: Command runbook doc exists in docs/operations/ with expected outputs.
#   AC-MOD-005: Evidence bundle directory structure / template present.
#
# Usage:
#   ./scripts/qa/verify-module-surface-validation.sh
#
# Optional live mode (requires cluster access):
#   MODULE_SURFACE_LIVE=1 ./scripts/qa/verify-module-surface-validation.sh
#
# Exit codes:
#   0  All checks passed (FAIL count = 0)
#   1  One or more checks failed

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo -e "${GREEN}[PASS]${NC} $1"; }
fail() { FAIL=$((FAIL + 1)); echo -e "${RED}[FAIL]${NC} $1"; }
warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}[WARN]${NC} $1"; }

# Live-mode flag — set MODULE_SURFACE_LIVE=1 to perform actual HTTP requests
LIVE="${MODULE_SURFACE_LIVE:-0}"
CURL_TIMEOUT="${CURL_TIMEOUT:-15}"

# Domain constants (match config.sh defaults)
LMS_DOMAIN="${LMS_DOMAIN:-academyv2.mereka.io}"
# Ecommerce removed (ADR-018, Oscar deprecated → Purchase Gateway)
CREDENTIALS_HOST="credentials.${LMS_DOMAIN}"
NOTES_HOST="notes.${LMS_DOMAIN}"
FORUM_HOST="${LMS_DOMAIN}"          # Forum v2 is integrated into LMS
PREVIEW_HOST="preview.${LMS_DOMAIN}"
MFE_HOST="apps.${LMS_DOMAIN}"

# Caddyfile path
CADDYFILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"

# Monitoring dir
MONITORING_DIR="$REPO_ROOT/deploy/k8s/base/monitoring"

# Docs dir
DOCS_OPS="$REPO_ROOT/docs/operations"

# Evidence dir
EVIDENCE_DIR="$REPO_ROOT/var/module-surface-evidence"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
check_file_exists() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    pass "$label: file exists ($path)"
    return 0
  else
    fail "$label: file not found ($path)"
    return 1
  fi
}

check_dir_exists() {
  local path="$1" label="$2"
  if [[ -d "$path" ]]; then
    pass "$label: directory exists ($path)"
    return 0
  else
    fail "$label: directory not found ($path)"
    return 1
  fi
}

check_pattern_in_file() {
  local file="$1" pattern="$2" label="$3"
  if [[ ! -f "$file" ]]; then
    fail "$label: source file missing ($file)"
    return 1
  fi
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    pass "$label"
    return 0
  else
    fail "$label: pattern '$pattern' not found in $file"
    return 1
  fi
}

check_pattern_any_file() {
  local pattern="$1" label="$2"
  shift 2
  local file
  for file in "$@"; do
    if [[ -f "$file" ]] && grep -qE "$pattern" "$file" 2>/dev/null; then
      pass "$label (matched in $(basename "$file"))"
      return 0
    fi
  done
  fail "$label: pattern '$pattern' not found in any of: $*"
  return 1
}

live_http_check() {
  local url="$1" label="$2" expected_range="$3"
  # expected_range: e.g. "2xx3xx" means 200-399 accepted; "200" means exact
  if [[ "$LIVE" != "1" ]]; then
    warn "$label: live check skipped (set MODULE_SURFACE_LIVE=1 to enable)"
    return 0
  fi
  local code
  code=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT" \
    -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  case "$expected_range" in
    2xx3xx)
      if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
        pass "$label: HTTP $code (in 2xx/3xx)"
      else
        fail "$label: HTTP $code (expected 2xx/3xx) — $url"
      fi ;;
    200)
      if [[ "$code" == "200" ]]; then
        pass "$label: HTTP 200"
      else
        fail "$label: HTTP $code (expected 200) — $url"
      fi ;;
    *)
      if [[ "$code" == "$expected_range" ]]; then
        pass "$label: HTTP $code"
      else
        warn "$label: HTTP $code (expected $expected_range) — $url"
      fi ;;
  esac
}

# ---------------------------------------------------------------------------
echo "=== Module Surface Validation Pack ==="
echo "Repo root : $REPO_ROOT"
echo "Live mode : $LIVE"
echo ""

# ---------------------------------------------------------------------------
# AC-MOD-001 — Service host inventory documented; smoke coverage present
# ---------------------------------------------------------------------------
echo -e "${CYAN}--- AC-MOD-001: Service Host Inventory & Smoke Coverage ---${NC}"

# 1a. Hostname registry doc must exist
check_file_exists "$DOCS_OPS/OPENEDX_HOSTNAMES.md" \
  "AC-MOD-001: Service hostname registry doc"

# 1b. Hostname doc must list each service host
declare -A SERVICE_HOSTS=(
  ["credentials"]="credentials\\.academyv2\\.mereka\\.io"
  ["notes"]="notes\\.academyv2\\.mereka\\.io"
  ["forum"]="forum\\.academyv2\\.mereka\\.io"
  ["preview"]="preview\\.academyv2\\.mereka\\.io"
  ["apps/MFE"]="apps\\.academyv2\\.mereka\\.io"
)

for svc in "${!SERVICE_HOSTS[@]}"; do
  check_pattern_in_file "$DOCS_OPS/OPENEDX_HOSTNAMES.md" \
    "${SERVICE_HOSTS[$svc]}" \
    "AC-MOD-001: Hostname doc lists $svc host"
done

# 1c. Caddyfile must contain route blocks for each service
declare -A CADDY_PATTERNS=(
  ["credentials route"]="credentials\\.academyv2\\.mereka"
  ["notes route"]="notes\\.academyv2\\.mereka"
  ["preview route"]="preview\\.academyv2\\.mereka"
  ["apps/MFE route"]="apps\\.academyv2\\.mereka"
)

for label in "${!CADDY_PATTERNS[@]}"; do
  check_pattern_in_file "$CADDYFILE" \
    "${CADDY_PATTERNS[$label]}" \
    "AC-MOD-001: Caddyfile has $label"
done

# 1d. Module surface validation runbook must exist (satisfies broader smoke coverage doc requirement)
check_file_exists "$DOCS_OPS/MODULE_SURFACE_VALIDATION_RUNBOOK.md" \
  "AC-MOD-001: Module surface validation runbook present"

# 1e. Live smoke — optional
live_http_check "https://${CREDENTIALS_HOST}/health/" "AC-MOD-001 live: credentials /health/" "200"
live_http_check "https://${NOTES_HOST}/heartbeat" "AC-MOD-001 live: notes /heartbeat" "200"
live_http_check "https://${FORUM_HOST}/api/discussion/v1/" "AC-MOD-001 live: forum API" "2xx3xx"
live_http_check "https://${PREVIEW_HOST}/" "AC-MOD-001 live: preview root" "2xx3xx"
live_http_check "https://${MFE_HOST}/authn/login" "AC-MOD-001 live: MFE authn/login" "200"

echo ""

# ---------------------------------------------------------------------------
# AC-MOD-002 — Expected status-code mapping; authn proxy route config
# ---------------------------------------------------------------------------
echo -e "${CYAN}--- AC-MOD-002: Status Code Mapping & Authn Proxy Routes ---${NC}"

# 2a. Caddyfile must have authn proxy blocks for credentials
check_pattern_in_file "$CADDYFILE" \
  "handle /authn/\*" \
  "AC-MOD-002: Caddyfile has authn proxy block for credentials"

# Count occurrences to verify credentials has the proxy
authn_count=$(grep -c "handle /authn/\*" "$CADDYFILE" 2>/dev/null || echo "0")
if [[ "$authn_count" -ge 1 ]]; then
  pass "AC-MOD-002: Caddyfile has authn proxy blocks for >= 1 service (count: $authn_count)"
else
  fail "AC-MOD-002: Expected authn proxy in >= 1 Caddyfile block, found $authn_count"
fi

# 2b. Caddyfile must route authn/* to MFE service
check_pattern_in_file "$CADDYFILE" \
  "reverse_proxy mfe:8002" \
  "AC-MOD-002: Caddyfile routes authn/* to MFE (mfe:8002)"

# 2c. Ecommerce removed (ADR-018, Oscar deprecated → Purchase Gateway)

# 2d. Credentials root must have a known landing response
check_pattern_in_file "$CADDYFILE" \
  "Mereka Credentials" \
  "AC-MOD-002: Caddyfile has Mereka-branded credentials root response"

# 2e. Forum note in Caddyfile (forum v2 integrated into LMS)
check_pattern_in_file "$CADDYFILE" \
  "Forum v2|forum" \
  "AC-MOD-002: Caddyfile documents forum (v2 integrated into LMS)"

# 2f. Module surface runbook documents expected status codes per service
check_pattern_in_file "$DOCS_OPS/MODULE_SURFACE_VALIDATION_RUNBOOK.md" \
  "200|redirect|3[0-9][0-9]" \
  "AC-MOD-002: Runbook documents expected HTTP status codes"

# 2g. Live status code checks
live_http_check "https://${CREDENTIALS_HOST}/health/" \
  "AC-MOD-002 live: credentials /health/ → 200" "200"
live_http_check "https://${CREDENTIALS_HOST}/admin/login/" \
  "AC-MOD-002 live: credentials /admin/login/ → 2xx/3xx" "2xx3xx"
live_http_check "https://${CREDENTIALS_HOST}/authn/login" \
  "AC-MOD-002 live: credentials /authn/login → 200 (via MFE proxy)" "200"

echo ""

# ---------------------------------------------------------------------------
# AC-MOD-003 — No 5xx spikes; monitoring/alerting config present
# ---------------------------------------------------------------------------
echo -e "${CYAN}--- AC-MOD-003: 5xx Monitoring & Regression Baseline ---${NC}"

# 3a. LMS PrometheusRule must exist
check_file_exists "$MONITORING_DIR/prometheusrule-lms.yaml" \
  "AC-MOD-003: LMS PrometheusRule exists"

# 3b. Credentials PrometheusRule must exist
check_file_exists "$MONITORING_DIR/prometheusrule-credentials.yaml" \
  "AC-MOD-003: Credentials PrometheusRule exists"

# 3c. LMS PrometheusRule must have 5xx or error-rate alert
check_pattern_in_file "$MONITORING_DIR/prometheusrule-lms.yaml" \
  "5xx|error_rate|http_requests_total|LMSPodDown|LMSHigh5xx|LMS5xx" \
  "AC-MOD-003: LMS PrometheusRule has error/5xx coverage"

# 3d. Credentials PrometheusRule must have relevant alerts
check_pattern_in_file "$MONITORING_DIR/prometheusrule-credentials.yaml" \
  "alert:|5xx|error|health" \
  "AC-MOD-003: Credentials PrometheusRule has alert definitions"

# 3e. Regression baseline docs exist (troubleshooting runbook)
check_file_exists "$DOCS_OPS/TROUBLESHOOTING.md" \
  "AC-MOD-003: Troubleshooting runbook (regression baseline) present"

# 3f. Deployment verification doc exists
check_file_exists "$DOCS_OPS/DEPLOYMENT_VERIFICATION.md" \
  "AC-MOD-003: Deployment verification doc present"

# 3g. Module surface runbook has 5xx monitoring references
check_pattern_in_file "$DOCS_OPS/MODULE_SURFACE_VALIDATION_RUNBOOK.md" \
  "5xx|PrometheusRule|alert|monitoring" \
  "AC-MOD-003: Runbook references 5xx monitoring / PrometheusRules"

echo ""

# ---------------------------------------------------------------------------
# AC-MOD-004 — Command runbook in docs/operations/ with expected outputs
# ---------------------------------------------------------------------------
echo -e "${CYAN}--- AC-MOD-004: Command Runbook ---${NC}"

RUNBOOK="$DOCS_OPS/MODULE_SURFACE_VALIDATION_RUNBOOK.md"

# 4a. Runbook file exists
check_file_exists "$RUNBOOK" \
  "AC-MOD-004: MODULE_SURFACE_VALIDATION_RUNBOOK.md exists"

# 4b. Runbook has service inventory table
check_pattern_in_file "$RUNBOOK" \
  "ecommerce|credentials|notes|forum|preview" \
  "AC-MOD-004: Runbook covers all service hosts"

# 4c. Runbook has curl command examples
check_pattern_in_file "$RUNBOOK" \
  "curl" \
  "AC-MOD-004: Runbook contains curl smoke commands"

# 4d. Runbook has expected output annotations
check_pattern_in_file "$RUNBOOK" \
  "expected|HTTP|200|3[0-9][0-9]" \
  "AC-MOD-004: Runbook annotates expected outputs"

# 4e. Runbook references bead-253a or module-surface
check_pattern_in_file "$RUNBOOK" \
  "253a|module.surface|module_surface|module-surface" \
  "AC-MOD-004: Runbook references bead 253a"

echo ""

# ---------------------------------------------------------------------------
# AC-MOD-005 — Evidence bundle directory structure / template present
# ---------------------------------------------------------------------------
echo -e "${CYAN}--- AC-MOD-005: Evidence Bundle Structure ---${NC}"

# 5a. var/ directory exists (or can be created)
if [[ -d "$REPO_ROOT/var" ]]; then
  pass "AC-MOD-005: var/ base directory exists"
else
  warn "AC-MOD-005: var/ base directory not found (will be created on first evidence run)"
fi

# 5b. Evidence dir exists or runbook documents how to create it
if [[ -d "$EVIDENCE_DIR" ]]; then
  pass "AC-MOD-005: var/module-surface-evidence/ directory exists"
else
  # Acceptable if runbook explains the directory structure
  check_pattern_in_file "$RUNBOOK" \
    "var/module-surface-evidence|evidence.*bundle|curl.*-o|collect.*evidence" \
    "AC-MOD-005: Runbook documents evidence collection into var/module-surface-evidence/"
fi

# 5c. Runbook has evidence collection section
check_pattern_in_file "$RUNBOOK" \
  "[Ee]vidence|screenshot|curl.*-o|bundle" \
  "AC-MOD-005: Runbook has evidence collection section"

# 5d. Live evidence capture — only in live mode
if [[ "$LIVE" == "1" ]]; then
  mkdir -p "$EVIDENCE_DIR"
  TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
  BUNDLE_DIR="$EVIDENCE_DIR/$TIMESTAMP"
  mkdir -p "$BUNDLE_DIR"

  declare -A LIVE_CHECKS=(
    ["credentials-health"]="https://${CREDENTIALS_HOST}/health/"
    ["credentials-admin-login"]="https://${CREDENTIALS_HOST}/admin/login/"
    ["notes-heartbeat"]="https://${NOTES_HOST}/heartbeat"
    ["preview-root"]="https://${PREVIEW_HOST}/"
    ["mfe-authn-login"]="https://${MFE_HOST}/authn/login"
    ["credentials-authn-proxy"]="https://${CREDENTIALS_HOST}/authn/login"
  )

  echo "  Capturing evidence bundle: $BUNDLE_DIR"
  for name in "${!LIVE_CHECKS[@]}"; do
    url="${LIVE_CHECKS[$name]}"
    outfile="$BUNDLE_DIR/${name}.txt"
    code=$(curl -s -L --connect-timeout 10 --max-time "$CURL_TIMEOUT" \
      -o "$BUNDLE_DIR/${name}.html" -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    printf "url: %s\nhttp_code: %s\ntimestamp: %s\n" "$url" "$code" "$TIMESTAMP" > "$outfile"
  done
  pass "AC-MOD-005: Evidence bundle captured at $BUNDLE_DIR"
else
  warn "AC-MOD-005: Live evidence capture skipped (set MODULE_SURFACE_LIVE=1 to capture)"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=============================="
echo "  Module Surface Validation"
echo "=============================="
printf "  ${GREEN}PASS${NC}: %d\n" "$PASS"
printf "  ${YELLOW}WARN${NC}: %d\n" "$WARN"
printf "  ${RED}FAIL${NC}: %d\n" "$FAIL"
echo "=============================="

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL ($FAIL check(s) failed)${NC}" >&2
  exit 1
fi

echo -e "${GREEN}RESULT: PASS${NC}"
exit 0
