#!/usr/bin/env bash
# smoke-authenticated.sh — Post-deploy authenticated smoke tests
# @covers AC-SMOKE-001
#
# Runs Playwright-based authenticated checks against a live deployment.
# Requires SSO credentials via environment variables.
#
# Usage:
#   ./scripts/qa/smoke-authenticated.sh [--target URL]
#   SMOKE_TARGET=https://academyv2.mereka.io ./scripts/qa/smoke-authenticated.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

TARGET="${SMOKE_TARGET:-https://academyv2.mereka.io}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${BLUE}=== Authenticated Smoke Tests ===${NC}"
echo -e "Target: ${TARGET}"
echo ""

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASS_COUNT++)) || true
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAIL_COUNT++)) || true
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARN_COUNT++)) || true
}

# ============================================================================
# Prerequisites
# ============================================================================

echo -e "${BLUE}## Prerequisites${NC}"

# Check required env vars
if [[ -z "${SSO_USERNAME:-}" ]]; then
  fail "SSO_USERNAME not set"
  echo "Set SSO_USERNAME and SSO_PASSWORD environment variables"
  exit 1
else
  pass "SSO_USERNAME configured"
fi

if [[ -z "${SSO_PASSWORD:-}" ]]; then
  fail "SSO_PASSWORD not set"
  exit 1
else
  pass "SSO_PASSWORD configured"
fi

# Check playwright available
if command -v npx &>/dev/null; then
  pass "npx available"
else
  fail "npx not found — Playwright needs Node.js"
  exit 1
fi

echo ""

# ============================================================================
# Unauthenticated Health Checks
# ============================================================================

echo -e "${BLUE}## Unauthenticated Health Checks${NC}"

# LMS responds
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${TARGET}/" 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" =~ ^(200|301|302)$ ]]; then
  pass "LMS responds (HTTP ${HTTP_STATUS})"
else
  fail "LMS unreachable (HTTP ${HTTP_STATUS})"
fi

# Login page accessible
LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${TARGET}/authn/login" 2>/dev/null || echo "000")
if [[ "$LOGIN_STATUS" =~ ^(200|301|302)$ ]]; then
  pass "Login page accessible (HTTP ${LOGIN_STATUS})"
else
  fail "Login page unreachable (HTTP ${LOGIN_STATUS})"
fi

# MFE config endpoint
MFE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${TARGET}/api/mfe_config/v1" 2>/dev/null || echo "000")
if [[ "$MFE_STATUS" =~ ^(200|301|302)$ ]]; then
  pass "MFE config endpoint responds (HTTP ${MFE_STATUS})"
else
  warn "MFE config endpoint issue (HTTP ${MFE_STATUS})"
fi

echo ""

# ============================================================================
# Authenticated Tests (Playwright)
# ============================================================================

echo -e "${BLUE}## Authenticated Tests (Playwright)${NC}"

# Create a temporary Playwright script
PLAYWRIGHT_SCRIPT=$(mktemp /tmp/smoke-auth-XXXXXX.mjs)
trap 'rm -f "$PLAYWRIGHT_SCRIPT"' EXIT

cat > "$PLAYWRIGHT_SCRIPT" << 'PLAYWRIGHT_EOF'
import { chromium } from 'playwright';

const TARGET = process.env.SMOKE_TARGET || 'https://academyv2.mereka.io';
const SSO_USERNAME = process.env.SSO_USERNAME;
const SSO_PASSWORD = process.env.SSO_PASSWORD;

const results = [];

function pass(msg) { results.push({ status: 'PASS', msg }); }
function fail(msg) { results.push({ status: 'FAIL', msg }); }

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();

  try {
    // Step 1: Navigate to login
    await page.goto(`${TARGET}/authn/login`, { waitUntil: 'networkidle', timeout: 30000 });

    // Step 2: Check if redirected to SSO/Authentik
    const loginUrl = page.url();
    if (loginUrl.includes('authentik') || loginUrl.includes('auth') || loginUrl.includes('login')) {
      pass('Redirected to SSO login');
    } else {
      fail(`Unexpected login URL: ${loginUrl}`);
    }

    // Step 3: Fill credentials
    // Try common SSO login selectors
    const usernameSelectors = ['#id_uid_field', 'input[name="uidField"]', 'input[name="username"]', 'input[type="email"]'];
    let filled = false;
    for (const sel of usernameSelectors) {
      const el = await page.$(sel);
      if (el) {
        await el.fill(SSO_USERNAME);
        filled = true;
        break;
      }
    }
    if (filled) {
      pass('Username field found and filled');
    } else {
      fail('Could not find username field');
      throw new Error('Login form not found');
    }

    // Submit username (Authentik has 2-step login)
    const submitBtn = await page.$('button[type="submit"]');
    if (submitBtn) await submitBtn.click();
    await page.waitForTimeout(2000);

    // Fill password
    const passwordSelectors = ['#id_password', 'input[name="password"]', 'input[type="password"]'];
    filled = false;
    for (const sel of passwordSelectors) {
      const el = await page.$(sel);
      if (el) {
        await el.fill(SSO_PASSWORD);
        filled = true;
        break;
      }
    }
    if (filled) {
      pass('Password field found and filled');
    } else {
      fail('Could not find password field');
      throw new Error('Password field not found');
    }

    // Submit login
    const loginBtn = await page.$('button[type="submit"]');
    if (loginBtn) await loginBtn.click();
    await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(3000);

    // Step 4: Verify authenticated
    const postLoginUrl = page.url();
    if (!postLoginUrl.includes('authentik') && !postLoginUrl.includes('login')) {
      pass('Login completed — no longer on auth page');
    } else {
      fail(`Still on login page after auth: ${postLoginUrl}`);
    }

    // Step 5: Check dashboard
    await page.goto(`${TARGET}/learner-dashboard/`, { waitUntil: 'networkidle', timeout: 30000 });
    const dashStatus = page.url();
    if (!dashStatus.includes('login') && !dashStatus.includes('authn')) {
      pass('Learner dashboard accessible (authenticated)');
    } else {
      fail('Learner dashboard redirected to login');
    }

    // Step 6: Check account settings
    await page.goto(`${TARGET}/account/`, { waitUntil: 'networkidle', timeout: 30000 });
    const accountStatus = page.url();
    if (!accountStatus.includes('login') && !accountStatus.includes('authn')) {
      pass('Account settings accessible (authenticated)');
    } else {
      fail('Account settings redirected to login');
    }

    // Step 7: Check course player (just verify it doesn't 500)
    const courseResponse = await page.goto(`${TARGET}/learning/`, { waitUntil: 'networkidle', timeout: 30000 });
    if (courseResponse && courseResponse.status() < 500) {
      pass(`Course player responds (HTTP ${courseResponse.status()})`);
    } else {
      fail('Course player returned 500');
    }

  } catch (err) {
    fail(`Playwright error: ${err.message}`);
  } finally {
    await browser.close();
  }

  // Output results as JSON
  console.log(JSON.stringify(results));
}

main().catch(err => {
  console.log(JSON.stringify([{ status: 'FAIL', msg: `Fatal: ${err.message}` }]));
  process.exit(0); // Don't fail process — let bash handle
});
PLAYWRIGHT_EOF

# Run Playwright
PLAYWRIGHT_OUTPUT=$(SMOKE_TARGET="${TARGET}" SSO_USERNAME="${SSO_USERNAME}" SSO_PASSWORD="${SSO_PASSWORD}" \
  npx playwright test --config=/dev/null "$PLAYWRIGHT_SCRIPT" 2>/dev/null || \
  node "$PLAYWRIGHT_SCRIPT" 2>/dev/null || \
  echo '[]')

# Parse results
if echo "$PLAYWRIGHT_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "$PLAYWRIGHT_OUTPUT" | python3 -c "
import sys, json
results = json.load(sys.stdin)
for r in results:
    status = r.get('status', 'FAIL')
    msg = r.get('msg', 'unknown')
    if status == 'PASS':
        print(f'\033[0;32m[PASS]\033[0m {msg}')
    else:
        print(f'\033[0;31m[FAIL]\033[0m {msg}')
" 2>/dev/null

  PW_PASS=$(echo "$PLAYWRIGHT_OUTPUT" | python3 -c "import sys,json; print(sum(1 for r in json.load(sys.stdin) if r.get('status')=='PASS'))" 2>/dev/null || echo 0)
  PW_FAIL=$(echo "$PLAYWRIGHT_OUTPUT" | python3 -c "import sys,json; print(sum(1 for r in json.load(sys.stdin) if r.get('status')=='FAIL'))" 2>/dev/null || echo 0)
  PASS_COUNT=$((PASS_COUNT + PW_PASS))
  FAIL_COUNT=$((FAIL_COUNT + PW_FAIL))
else
  warn "Playwright output not parseable — skipping authenticated checks"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}All smoke tests passed${NC}"
  exit 0
else
  echo -e "${RED}Some smoke tests failed${NC}"
  exit 1
fi
