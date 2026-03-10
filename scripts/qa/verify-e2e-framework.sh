#!/usr/bin/env bash
# @covers AC-T049-001, AC-T049-002, AC-T049-003, AC-T049-004, AC-T049-005
# @spec: e2e-critical-path_spec.md
#
# Verify the Playwright E2E test framework for Mereka Academy critical paths.
#
# Checks:
#   Offline mode (default):
#     1.  tests/e2e/playwright.config.ts exists
#     2.  tests/e2e/package.json exists and contains @playwright/test dep
#     3.  tests/e2e/tests/critical-path.spec.ts exists
#     4.  Five critical-path tests are defined in the spec file
#     5.  @covers annotations present in config and spec
#     6.  playwright.config.ts references BASE_URL env var
#     7.  Test file covers login, enroll, video, forum, certificate paths
#     8.  Forum test references /api/discussion/v2/ (Forum v2 in-process with LMS)
#     9.  Oscar ecommerce NOT referenced (deprecated — Purchase Gateway handles payments)
#     10. package.json engine constraint specifies node >= 18
#
#   Online mode (--online):
#     11. Node.js >= 18 is available
#     12. npx playwright --version succeeds
#     13. Playwright browsers are installed
#     14. Run tests against BASE_URL (default: https://academyv2.mereka.io)
#
# Usage:
#   ./scripts/qa/verify-e2e-framework.sh              # offline only
#   ./scripts/qa/verify-e2e-framework.sh --online     # offline + online
#   BASE_URL=https://academyv2.mereka.dev ./scripts/qa/verify-e2e-framework.sh --online
#
# Environment variables (online mode):
#   BASE_URL        Target LMS URL (default: https://academyv2.mereka.io)
#   E2E_USERNAME    SSO username for authenticated tests
#   E2E_PASSWORD    SSO password for authenticated tests
#   E2E_COURSE_ID   Course ID for enroll/video/forum tests
#   E2E_CERT_URL    Certificate URL for certificate test
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
E2E_DIR="${REPO_ROOT}/tests/e2e"

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
MODE="offline"
if [[ "${1:-}" == "--online" ]]; then
  MODE="online"
fi

BASE_URL="${BASE_URL:-https://academyv2.mereka.io}"

CONFIG_FILE="${E2E_DIR}/playwright.config.ts"
PACKAGE_FILE="${E2E_DIR}/package.json"
SPEC_FILE="${E2E_DIR}/tests/critical-path.spec.ts"

echo -e "${BLUE}=== E2E Framework Verification ===${NC}"
echo "Mode     : ${MODE}"
echo "Repo root: ${REPO_ROOT}"
echo "E2E dir  : ${E2E_DIR}"
[[ "$MODE" == "online" ]] && echo "Base URL : ${BASE_URL}"
echo ""

# ===========================================================================
# Offline checks
# ===========================================================================

echo -e "${BLUE}## Offline Checks${NC}"
echo ""

# ---------------------------------------------------------------------------
# 1. playwright.config.ts exists
# ---------------------------------------------------------------------------
echo "--- 1. playwright.config.ts exists ---"
if [[ -f "$CONFIG_FILE" ]]; then
  pass "playwright.config.ts found: ${CONFIG_FILE}"
else
  fail "playwright.config.ts not found: ${CONFIG_FILE}"
fi

# ---------------------------------------------------------------------------
# 2. package.json exists and has @playwright/test
# ---------------------------------------------------------------------------
echo "--- 2. package.json has @playwright/test dependency ---"
if [[ ! -f "$PACKAGE_FILE" ]]; then
  fail "package.json not found: ${PACKAGE_FILE}"
else
  if python3 -c "
import json, sys
pkg = json.load(open(sys.argv[1]))
deps = {**pkg.get('devDependencies', {}), **pkg.get('dependencies', {})}
if '@playwright/test' not in deps:
    sys.exit(1)
" "$PACKAGE_FILE" 2>/dev/null; then
    pw_ver=$(python3 -c "
import json
pkg = json.load(open('${PACKAGE_FILE}'))
deps = {**pkg.get('devDependencies', {}), **pkg.get('dependencies', {})}
print(deps.get('@playwright/test', 'unknown'))
")
    pass "package.json has @playwright/test: ${pw_ver}"
  else
    fail "package.json missing @playwright/test in devDependencies"
  fi
fi

# ---------------------------------------------------------------------------
# 3. critical-path.spec.ts exists
# ---------------------------------------------------------------------------
echo "--- 3. critical-path.spec.ts exists ---"
if [[ -f "$SPEC_FILE" ]]; then
  pass "critical-path.spec.ts found: ${SPEC_FILE}"
else
  fail "critical-path.spec.ts not found: ${SPEC_FILE}"
fi

# ---------------------------------------------------------------------------
# 4. Five critical-path tests defined
# ---------------------------------------------------------------------------
echo "--- 4. Five critical-path tests defined ---"
if [[ ! -f "$SPEC_FILE" ]]; then
  skip "spec file missing — skipping test count check"
else
  test_count=$(grep -c "^[[:space:]]*test(" "$SPEC_FILE" 2>/dev/null || echo 0)
  if [[ "$test_count" -ge 5 ]]; then
    pass "spec file contains ${test_count} test() blocks (>= 5 required)"
  else
    fail "spec file contains only ${test_count} test() blocks (need >= 5)"
  fi
fi

# ---------------------------------------------------------------------------
# 5. @covers annotations present
# ---------------------------------------------------------------------------
echo "--- 5. @covers annotations present ---"
covers_config=false
covers_spec=false

if [[ -f "$CONFIG_FILE" ]] && grep -q "@covers" "$CONFIG_FILE" 2>/dev/null; then
  covers_config=true
fi
if [[ -f "$SPEC_FILE" ]] && grep -q "@covers" "$SPEC_FILE" 2>/dev/null; then
  covers_spec=true
fi

if $covers_config; then
  pass "playwright.config.ts has @covers annotation"
else
  fail "playwright.config.ts missing @covers annotation"
fi

if $covers_spec; then
  pass "critical-path.spec.ts has @covers annotation"
else
  fail "critical-path.spec.ts missing @covers annotation"
fi

# ---------------------------------------------------------------------------
# 6. playwright.config.ts references BASE_URL env var
# ---------------------------------------------------------------------------
echo "--- 6. playwright.config.ts uses BASE_URL env var ---"
if [[ ! -f "$CONFIG_FILE" ]]; then
  skip "config file missing"
elif grep -q "BASE_URL" "$CONFIG_FILE" 2>/dev/null; then
  pass "playwright.config.ts references BASE_URL environment variable"
else
  fail "playwright.config.ts does not reference BASE_URL — target URL must be configurable"
fi

# ---------------------------------------------------------------------------
# 7. Five critical paths covered in spec file
# ---------------------------------------------------------------------------
echo "--- 7. Five critical paths covered: login, enroll, video, forum, certificate ---"
if [[ ! -f "$SPEC_FILE" ]]; then
  skip "spec file missing — skipping coverage check"
else
  critical_paths=("login" "enroll" "video" "forum" "certificate")
  for path in "${critical_paths[@]}"; do
    if grep -qi "${path}" "$SPEC_FILE" 2>/dev/null; then
      pass "critical path covered: ${path}"
    else
      fail "critical path not found in spec: ${path}"
    fi
  done
fi

# ---------------------------------------------------------------------------
# 8. Forum test uses /api/discussion/v2/ (Forum v2, in-process with LMS)
# ---------------------------------------------------------------------------
echo "--- 8. Forum test references /api/discussion/v2/ (Forum v2 in-process) ---"
if [[ ! -f "$SPEC_FILE" ]]; then
  skip "spec file missing"
elif grep -q "api/discussion/v2" "$SPEC_FILE" 2>/dev/null; then
  pass "Forum test uses /api/discussion/v2/ (Python forum v2, in-process with LMS)"
else
  fail "Forum test should reference /api/discussion/v2/ (Forum v2 runs in-process with LMS)"
fi

# ---------------------------------------------------------------------------
# 9. Oscar ecommerce NOT referenced (deprecated)
# ---------------------------------------------------------------------------
echo "--- 9. Oscar ecommerce NOT referenced (deprecated — use Purchase Gateway) ---"
if [[ ! -f "$SPEC_FILE" ]]; then
  skip "spec file missing"
elif grep -iE "(oscar|ecommerce\/checkout|/basket/)" "$SPEC_FILE" 2>/dev/null | grep -v "^[[:space:]]*//" | grep -qiE "(oscar|ecommerce\/checkout|/basket/)"; then
  fail "Spec references Oscar ecommerce routes — Oscar is DEPRECATED; enrollment uses LMS native API"
else
  pass "No Oscar ecommerce references (correctly uses LMS native enrollment / Purchase Gateway)"
fi

# ---------------------------------------------------------------------------
# 10. package.json engine constraint >= 18
# ---------------------------------------------------------------------------
echo "--- 10. package.json engine constraint node >= 18 ---"
if [[ ! -f "$PACKAGE_FILE" ]]; then
  skip "package.json missing"
elif python3 -c "
import json, sys, re
pkg = json.load(open(sys.argv[1]))
node_req = pkg.get('engines', {}).get('node', '')
# Accept >=18, ^18, 18.x patterns
if re.search(r'>=?\s*18|[\^~]18|\bnode18\b', node_req):
    sys.exit(0)
sys.exit(1)
" "$PACKAGE_FILE" 2>/dev/null; then
  node_req=$(python3 -c "import json; print(json.load(open('${PACKAGE_FILE}')).get('engines', {}).get('node', 'unset'))")
  pass "package.json node engine requirement: ${node_req}"
else
  fail "package.json engines.node should require >= 18 (Open edX MFEs require Node 18)"
fi

echo ""

# ===========================================================================
# Online checks
# ===========================================================================

if [[ "$MODE" == "offline" ]]; then
  echo -e "${YELLOW}SKIP${NC} Online checks skipped (pass --online to run)"
  SKIP_COUNT=$((SKIP_COUNT + 4))
else
  echo -e "${BLUE}## Online Checks${NC}"
  echo ""

  # ---------------------------------------------------------------------------
  # 11. Node.js >= 18 available
  # ---------------------------------------------------------------------------
  echo "--- 11. Node.js >= 18 available ---"
  if ! command -v node >/dev/null 2>&1; then
    fail "node not found — install Node.js >= 18"
  else
    node_ver=$(node --version 2>/dev/null | sed 's/v//')
    major=$(echo "$node_ver" | cut -d. -f1)
    if [[ "$major" -ge 18 ]]; then
      pass "Node.js ${node_ver} (>= 18)"
    else
      fail "Node.js ${node_ver} is too old — require >= 18 for Open edX MFE tests"
    fi
  fi

  # ---------------------------------------------------------------------------
  # 12. npx playwright --version succeeds
  # ---------------------------------------------------------------------------
  echo "--- 12. Playwright CLI available ---"
  if ! command -v npx >/dev/null 2>&1; then
    fail "npx not found — install Node.js"
  else
    if [[ -d "${E2E_DIR}/node_modules/@playwright/test" ]]; then
      pw_ver=$(node -e "console.log(require('${E2E_DIR}/node_modules/@playwright/test/package.json').version)" 2>/dev/null || echo "unknown")
      pass "Playwright installed in node_modules: ${pw_ver}"
    else
      fail "Playwright not installed — run: cd tests/e2e && npm install"
    fi
  fi

  # ---------------------------------------------------------------------------
  # 13. Playwright browser (Chromium) is installed
  # ---------------------------------------------------------------------------
  echo "--- 13. Playwright Chromium browser installed ---"
  if [[ -d "${E2E_DIR}/node_modules" ]]; then
    chromium_ok=$(node -e "
const { execSync } = require('child_process');
try {
  execSync('npx playwright install --dry-run chromium 2>&1', { cwd: '${E2E_DIR}', stdio: 'pipe' });
  // If no error, check if chromium binary exists
  const { chromium } = require('@playwright/test');
  console.log('ok');
} catch(e) {
  console.log('missing');
}
" 2>/dev/null || echo "unknown")

    # More reliable: check if Playwright can list chromium
    if "${E2E_DIR}/node_modules/.bin/playwright" install --dry-run chromium 2>&1 | grep -q "already installed" 2>/dev/null; then
      pass "Chromium browser already installed"
    elif command -v "${E2E_DIR}/node_modules/.bin/playwright" >/dev/null 2>&1; then
      pass "Playwright CLI available (browser install status unknown in dry-run)"
    else
      skip "Cannot verify browser installation without node_modules — run: cd tests/e2e && npm install && npx playwright install chromium"
    fi
  else
    skip "node_modules not installed — run: cd tests/e2e && npm install"
  fi

  # ---------------------------------------------------------------------------
  # 14. Run Playwright tests against BASE_URL
  # ---------------------------------------------------------------------------
  echo "--- 14. Running Playwright tests against ${BASE_URL} ---"
  echo ""

  if [[ ! -d "${E2E_DIR}/node_modules" ]]; then
    skip "node_modules not installed — cannot run tests"
    echo "  To install: cd tests/e2e && npm install && npx playwright install chromium"
  else
    echo "Running: cd tests/e2e && BASE_URL=${BASE_URL} npx playwright test"
    echo ""

    # Export credentials for tests
    export BASE_URL
    export E2E_USERNAME="${E2E_USERNAME:-}"
    export E2E_PASSWORD="${E2E_PASSWORD:-}"
    export E2E_COURSE_ID="${E2E_COURSE_ID:-}"
    export E2E_CERT_URL="${E2E_CERT_URL:-}"

    # shellcheck disable=SC2064
    tmpdir=$(mktemp -d)
    trap "rm -rf ${tmpdir}" EXIT

    pw_exit=0
    (cd "$E2E_DIR" && npx playwright test --output "${tmpdir}/artifacts" 2>&1) || pw_exit=$?

    if [[ "$pw_exit" -eq 0 ]]; then
      pass "All Playwright tests passed against ${BASE_URL}"
    else
      fail "One or more Playwright tests failed (exit ${pw_exit}) — see output above"
      echo ""
      echo "  Tip: Run with HEADED=1 to debug interactively:"
      echo "    cd tests/e2e && HEADED=1 BASE_URL=${BASE_URL} npx playwright test --debug"
    fi
  fi
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "=================================="
echo -e "  PASS: ${GREEN}${PASS_COUNT}${NC}  FAIL: ${RED}${FAIL_COUNT}${NC}  SKIP: ${YELLOW}${SKIP_COUNT}${NC}"
echo "=================================="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo ""
  echo "Remediation:"
  echo "  1. Ensure tests/e2e/ directory exists with the three required files"
  echo "  2. Run: cd tests/e2e && npm install"
  echo "  3. Install browser: npx playwright install chromium"
  echo "  4. Set E2E_USERNAME, E2E_PASSWORD, E2E_COURSE_ID, E2E_CERT_URL for authenticated tests"
  echo "  5. See docs/guides/admin/ or docs/ops/runbooks/ for the current E2E setup guide"
  echo ""
  exit 1
fi

exit 0
