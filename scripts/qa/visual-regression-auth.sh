#!/usr/bin/env bash
# @covers AC-VRA-001, AC-VRA-002, AC-VRA-003, AC-VRA-004, AC-VRA-005
# @spec: branding-system_spec.md
#
# visual-regression-auth.sh — Authenticated visual-regression harness (curl-only)
#
# Logs in via POST /login_ajax, acquires a session cookie, then verifies each
# protected route returns HTTP 200 (not a redirect to /login) and contains the
# expected page markers.
#
# Routes tested:
#   /dashboard              — Learner dashboard
#   /courses/<id>/course/   — Course outline  (skipped unless --course-id given)
#   /u/<username>           — Profile page
#   /account/settings       — Account settings
#   /course/<id>            — Studio course authoring (separate base URL)
#
# Usage:
#   ./scripts/qa/visual-regression-auth.sh \
#       --base-url https://academyv2.mereka.io \
#       --username learner@example.com \
#       --password hunter2 \
#       [--studio-url https://studio.academyv2.mereka.io] \
#       [--course-id course-v1:Mereka+CS101+2024_T1] \
#       [--timeout 15] \
#       [--no-color]
#
# Exit codes:
#   0  All enabled routes PASS
#   1  One or more routes FAIL
#   2  Usage / argument error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shared/config.sh
source "$SCRIPT_DIR/../shared/config.sh"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
BASE_URL=""
STUDIO_URL=""
USERNAME=""
PASSWORD=""
COURSE_ID=""
TIMEOUT=15
NO_COLOR=0

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") --base-url <url> --username <user> --password <pass> [options]

Required:
  --base-url <url>      LMS base URL (e.g. https://academyv2.mereka.io)
  --username <user>     LMS username or email
  --password <pass>     LMS password

Optional:
  --studio-url <url>    Studio base URL (default: auto-derived from --base-url)
  --course-id <id>      Course ID for /courses/<id>/course/ + Studio /course/<id>
                        If omitted those routes are skipped.
  --timeout <secs>      curl max time per request (default: $TIMEOUT)
  --no-color            Disable ANSI colours in output
  -h, --help            Show this help

Environment variables (alternative to flags):
  LMS_BASE_URL, LMS_USERNAME, LMS_PASSWORD, STUDIO_BASE_URL, COURSE_ID

Examples:
  # Basic — public prod LMS
  ./scripts/qa/visual-regression-auth.sh \\
      --base-url https://academyv2.mereka.io \\
      --username admin@mereka.io \\
      --password 's3cr3t'

  # With course routes
  ./scripts/qa/visual-regression-auth.sh \\
      --base-url https://academyv2.mereka.io \\
      --username admin@mereka.io \\
      --password 's3cr3t' \\
      --course-id 'course-v1:Mereka+CS101+2024_T1'

  # Against nonprod
  ./scripts/qa/visual-regression-auth.sh \\
      --base-url https://academyv2.mereka.dev \\
      --username testuser@mereka.dev \\
      --password 'devpass'
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-url)   BASE_URL="${2:?'--base-url requires a value'}"; shift 2 ;;
    --studio-url) STUDIO_URL="${2:?'--studio-url requires a value'}"; shift 2 ;;
    --username)   USERNAME="${2:?'--username requires a value'}"; shift 2 ;;
    --password)   PASSWORD="${2:?'--password requires a value'}"; shift 2 ;;
    --course-id)  COURSE_ID="${2:?'--course-id requires a value'}"; shift 2 ;;
    --timeout)    TIMEOUT="${2:?'--timeout requires a value'}"; shift 2 ;;
    --no-color)   NO_COLOR=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Allow env-var overrides as fallback
BASE_URL="${BASE_URL:-${LMS_BASE_URL:-}}"
USERNAME="${USERNAME:-${LMS_USERNAME:-}}"
PASSWORD="${PASSWORD:-${LMS_PASSWORD:-}}"
STUDIO_URL="${STUDIO_URL:-${STUDIO_BASE_URL:-}}"
COURSE_ID="${COURSE_ID:-${COURSE_ID:-}}"

# ---------------------------------------------------------------------------
# Validate required args
# ---------------------------------------------------------------------------
errors=()
[[ -z "$BASE_URL" ]]  && errors+=("--base-url is required")
[[ -z "$USERNAME" ]]  && errors+=("--username is required")
[[ -z "$PASSWORD" ]]  && errors+=("--password is required")

if [[ ${#errors[@]} -gt 0 ]]; then
  for e in "${errors[@]}"; do
    echo "ERROR: $e" >&2
  done
  echo >&2
  usage >&2
  exit 2
fi

# Strip trailing slash
BASE_URL="${BASE_URL%/}"

# Derive Studio URL if not provided
if [[ -z "$STUDIO_URL" ]]; then
  # Replace leading scheme+host: https://lms.example.com → https://studio.lms.example.com
  # Works for academyv2.mereka.io → studio.academyv2.mereka.io
  host_part="${BASE_URL#https://}"
  host_part="${host_part#http://}"
  scheme="${BASE_URL%%://*}"
  STUDIO_URL="${scheme}://studio.${host_part}"
fi
STUDIO_URL="${STUDIO_URL%/}"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
if [[ "$NO_COLOR" -eq 0 ]] && [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
PASSED=0
FAILED=0
SKIPPED=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIPPED=$((SKIPPED + 1)); }
info() { echo -e "${CYAN}INFO${NC} $1"; }

# ---------------------------------------------------------------------------
# Temp dir for cookies + response bodies
# ---------------------------------------------------------------------------
TMPDIR_AUTH="$(mktemp -d)"
COOKIE_JAR="${TMPDIR_AUTH}/cookies.txt"
trap 'rm -rf "$TMPDIR_AUTH"' EXIT

# ---------------------------------------------------------------------------
# Helper: curl wrapper (shares cookie jar)
# ---------------------------------------------------------------------------
lms_curl() {
  # Usage: lms_curl [extra curl args] <url>
  curl \
    --silent \
    --show-error \
    --max-time "$TIMEOUT" \
    --cookie "$COOKIE_JAR" \
    --cookie-jar "$COOKIE_JAR" \
    "$@"
}

# ---------------------------------------------------------------------------
# Step 1: Fetch login page to get CSRF token
# ---------------------------------------------------------------------------
echo "=== Authenticated Visual Regression Harness ==="
echo "Base URL:   $BASE_URL"
echo "Studio URL: $STUDIO_URL"
echo "Username:   $USERNAME"
[[ -n "$COURSE_ID" ]] && echo "Course ID:  $COURSE_ID"
echo

info "Fetching CSRF token from $BASE_URL/login ..."
login_page="${TMPDIR_AUTH}/login.html"
http_code=$(lms_curl \
  --output "$login_page" \
  --write-out "%{http_code}" \
  --location \
  "${BASE_URL}/login" 2>/dev/null || echo "000")

if [[ "$http_code" != "200" ]]; then
  echo "ERROR: Could not fetch login page (HTTP $http_code). Check --base-url." >&2
  exit 2
fi

# Extract csrftoken from cookie jar or page source
csrf_token=""
# Try cookie jar first (most reliable)
csrf_token=$(grep -oP 'csrftoken\s+\K\S+' "$COOKIE_JAR" 2>/dev/null | head -1 || true)
# Fallback: extract from page HTML (meta tag or hidden input)
if [[ -z "$csrf_token" ]]; then
  csrf_token=$(grep -oP '(?<=csrfmiddlewaretoken" value=")[^"]+' "$login_page" 2>/dev/null | head -1 || true)
fi
if [[ -z "$csrf_token" ]]; then
  csrf_token=$(grep -oP '(?<=name="csrfmiddlewaretoken" value=")[^"]+' "$login_page" 2>/dev/null | head -1 || true)
fi

if [[ -z "$csrf_token" ]]; then
  echo "ERROR: Could not extract CSRF token from login page." >&2
  echo "  Ensure $BASE_URL/login returns a Django-rendered login form." >&2
  exit 2
fi

info "CSRF token obtained (${csrf_token:0:12}...)"

# ---------------------------------------------------------------------------
# Step 2: POST to /login_ajax
# ---------------------------------------------------------------------------
info "Authenticating as '$USERNAME' via POST $BASE_URL/login_ajax ..."
auth_response="${TMPDIR_AUTH}/auth_response.json"

auth_http=$(lms_curl \
  --output "$auth_response" \
  --write-out "%{http_code}" \
  --request POST \
  --header "X-CSRFToken: ${csrf_token}" \
  --header "Referer: ${BASE_URL}/login" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "email=${USERNAME}" \
  --data-urlencode "password=${PASSWORD}" \
  "${BASE_URL}/login_ajax" 2>/dev/null || echo "000")

# login_ajax returns HTTP 200 with a JSON body even on auth failure
if [[ "$auth_http" != "200" ]]; then
  echo "ERROR: /login_ajax returned HTTP $auth_http (expected 200)." >&2
  exit 2
fi

# Check JSON success field
auth_success=$(grep -oP '"success"\s*:\s*\K(true|false)' "$auth_response" 2>/dev/null | head -1 || true)
if [[ "$auth_success" != "true" ]]; then
  auth_value=$(grep -oP '"value"\s*:\s*"\K[^"]+' "$auth_response" 2>/dev/null | head -1 || true)
  echo "ERROR: Authentication failed. Server response: ${auth_value:-see $auth_response}" >&2
  exit 2
fi

info "Authentication successful."
echo

# ---------------------------------------------------------------------------
# Step 3: Check each protected route
# ---------------------------------------------------------------------------
# Each entry: "label|path|base|marker_regex"
#   base    = LMS or STUDIO
#   marker  = grep -P pattern expected in response body (empty = skip body check)
declare -a ROUTES
ROUTES=(
  "Learner dashboard|/dashboard|LMS|dashboard|id=\"\\blearner-dashboard\\b\"|class=\"dashboard\"|data-course|<title>Dashboard"
  "Account settings|/account/settings|LMS|class=\"account-settings\"|account-settings|account/settings|<title>Account"
  "Profile page|/u/${USERNAME}|LMS|class=\"u-field\"|\"profile-page\"|id=\"content\"|<title>"
)

if [[ -n "$COURSE_ID" ]]; then
  ROUTES+=(
    "Course outline|/courses/${COURSE_ID}/course/|LMS|class=\"course-outline\"|courseware|course-content|<title>"
    "Studio course|/course/${COURSE_ID}|STUDIO|course-outline|xblock|<title>"
  )
fi

# Route check function
# Usage: check_route "label" "path" "base_url" "marker1" ["marker2" ...]
check_route() {
  local label="$1"
  local path="$2"
  local base="$3"
  shift 3
  local markers=("$@")

  local url="${base}${path}"
  local body_file="${TMPDIR_AUTH}/route_$(echo "$label" | tr ' /' '__').html"

  # Fetch with redirect following; capture final HTTP code
  local http_code
  http_code=$(lms_curl \
    --output "$body_file" \
    --write-out "%{http_code}" \
    --location \
    --max-redirs 5 \
    "$url" 2>/dev/null || echo "000")

  # Check: must not redirect back to /login (unauthenticated redirect)
  local final_url
  final_url=$(lms_curl \
    --output /dev/null \
    --write-out "%{url_effective}" \
    --location \
    --max-redirs 5 \
    "$url" 2>/dev/null || echo "")

  if [[ "$http_code" == "000" ]]; then
    fail "[$label] connection error (timeout or DNS) — $url"
    return
  fi

  if [[ "$http_code" == "302" || "$http_code" == "301" ]]; then
    fail "[$label] HTTP $http_code redirect (authentication may have failed) — $url"
    return
  fi

  if [[ "$http_code" != "200" ]]; then
    fail "[$label] HTTP $http_code (expected 200) — $url"
    return
  fi

  # Check final URL did not land on a login page
  if echo "$final_url" | grep -qE '/login(\?|$)|/signin(\?|$)'; then
    fail "[$label] redirected to login page — session cookie not accepted by $url"
    return
  fi

  pass "[$label] HTTP 200 — $url"

  # Body marker checks (any one match is sufficient)
  if [[ ${#markers[@]} -gt 0 ]]; then
    local matched=0
    for marker in "${markers[@]}"; do
      if grep -qP "$marker" "$body_file" 2>/dev/null; then
        matched=1
        break
      fi
    done
    if [[ "$matched" -eq 1 ]]; then
      pass "[$label] expected page marker found"
    else
      fail "[$label] page marker not found — page may be an error or wrong content"
      # Emit first 3 lines for debug context (no secrets in HTML headers)
      head -3 "$body_file" | sed 's/^/  > /' || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# Parse and run ROUTES
# ---------------------------------------------------------------------------
for route_spec in "${ROUTES[@]}"; do
  IFS='|' read -r label path base_key marker_blob <<< "$route_spec"

  # Determine base URL
  case "$base_key" in
    STUDIO) base_addr="$STUDIO_URL" ;;
    *)      base_addr="$BASE_URL" ;;
  esac

  # Split marker_blob on | into array (already split above — markers are the rest)
  IFS='|' read -r -a markers <<< "$marker_blob"

  # Skip profile route if username looks like an email (/ in path is fine; Open edX
  # uses the username portion before @). Warn if username is an email address.
  if [[ "$path" == "/u/"* ]] && [[ "$USERNAME" == *"@"* ]]; then
    skip "[$label] --username looks like an email; /u/<username> path may not resolve. Pass a username instead."
    continue
  fi

  check_route "$label" "$path" "$base_addr" "${markers[@]}"
done

# Handle missing course routes
if [[ -z "$COURSE_ID" ]]; then
  skip "[Course outline] --course-id not provided"
  skip "[Studio course] --course-id not provided"
fi

echo

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASSED  ${RED}FAIL:${NC} $FAILED  ${YELLOW}SKIP:${NC} $SKIPPED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Action required: $FAILED route(s) failed authentication or content checks."
  echo "  1. Verify credentials and --base-url are correct."
  echo "  2. Check session cookie is being set: $COOKIE_JAR"
  echo "  3. Review LMS logs: kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50"
  echo "  4. For Studio failures: check SESSION_COOKIE_NAME (must be studio_session_id)."
  exit 1
fi

echo "All authenticated route checks passed."
exit 0
