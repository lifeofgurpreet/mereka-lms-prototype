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
SMOKE_MFE_BASE_URL="${SMOKE_MFE_BASE_URL:-}"

resolve_playwright_import_spec() {
  if [[ -n "${PLAYWRIGHT_IMPORT_SPEC:-}" ]]; then
    printf '%s' "${PLAYWRIGHT_IMPORT_SPEC}"
    return 0
  fi

  local repo_playwright="${REPO_ROOT}/tests/e2e/node_modules/playwright/index.mjs"
  if [[ -f "$repo_playwright" ]]; then
    printf 'file://%s' "$repo_playwright"
    return 0
  fi

  printf 'playwright'
}

PLAYWRIGHT_IMPORT_SPEC_RESOLVED="$(resolve_playwright_import_spec)"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    --mfe-base-url) SMOKE_MFE_BASE_URL="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

target_origin="${TARGET%/}"
target_host="${target_origin#*://}"
target_host="${target_host%%/*}"

if [[ -z "$SMOKE_MFE_BASE_URL" ]]; then
  case "$target_host" in
    academyv2.mereka.io) SMOKE_MFE_BASE_URL="https://apps.academyv2.mereka.io" ;;
    academyv2.mereka.dev) SMOKE_MFE_BASE_URL="https://apps.academyv2.mereka.dev" ;;
    staging.academyv2.mereka.io) SMOKE_MFE_BASE_URL="https://staging.apps.academyv2.mereka.io" ;;
  esac
fi

LOGIN_PAGE_URL="${target_origin}/login"
OIDC_LOGIN_URL="${target_origin}/auth/login/oidc/"
MFE_BASE_URL="${SMOKE_MFE_BASE_URL%/}"
LEARNER_DASHBOARD_URL="${MFE_BASE_URL:-$target_origin}/learner-dashboard"
ACCOUNT_SETTINGS_URL="${MFE_BASE_URL:-$target_origin}/account/"
LEARNING_URL="${MFE_BASE_URL:-$target_origin}/learning"

echo -e "${BLUE}=== Authenticated Smoke Tests ===${NC}"
echo -e "Target: ${target_origin}"
if [[ -n "$MFE_BASE_URL" ]]; then
  echo -e "MFE base: ${MFE_BASE_URL}"
fi
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

# Check node available
if command -v node &>/dev/null; then
  pass "node available"
else
  fail "node not found — Playwright needs Node.js"
  exit 1
fi

# Check Playwright import is resolvable before running the temp script
if PLAYWRIGHT_IMPORT_SPEC="$PLAYWRIGHT_IMPORT_SPEC_RESOLVED" node -e "import(process.env.PLAYWRIGHT_IMPORT_SPEC || 'playwright').then(() => process.exit(0)).catch(() => process.exit(1))"; then
  pass "Playwright runtime available"
else
  fail "Playwright runtime not available (set PLAYWRIGHT_IMPORT_SPEC or install tests/e2e dependencies)"
  exit 1
fi

echo ""

# ============================================================================
# Unauthenticated Health Checks
# ============================================================================

echo -e "${BLUE}## Unauthenticated Health Checks${NC}"

# LMS responds
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${target_origin}/" 2>/dev/null || echo "000")
if [[ "$HTTP_STATUS" =~ ^(200|301|302)$ ]]; then
  pass "LMS responds (HTTP ${HTTP_STATUS})"
else
  fail "LMS unreachable (HTTP ${HTTP_STATUS})"
fi

# Login page accessible
LOGIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${LOGIN_PAGE_URL}" 2>/dev/null || echo "000")
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
const TARGET = (process.env.SMOKE_TARGET || 'https://academyv2.mereka.io').replace(/\/$/, '');
const SSO_USERNAME = process.env.SSO_USERNAME;
const SSO_PASSWORD = process.env.SSO_PASSWORD;
const MFE_BASE_URL = (process.env.SMOKE_MFE_BASE_URL || '').replace(/\/$/, '');
const playwrightImportSpec = process.env.PLAYWRIGHT_IMPORT_SPEC || 'playwright';
const LOGIN_PAGE_URL = `${TARGET}/login`;
const OIDC_LOGIN_URL = `${TARGET}/auth/login/oidc/`;
const LEARNER_DASHBOARD_URL = `${MFE_BASE_URL || TARGET}/learner-dashboard`;
const ACCOUNT_SETTINGS_URL = `${MFE_BASE_URL || TARGET}/account/`;
const LEARNING_URL = `${MFE_BASE_URL || TARGET}/learning`;

const results = [];

function pass(msg) { results.push({ status: 'PASS', msg }); }
function fail(msg) { results.push({ status: 'FAIL', msg }); }

async function clickPrimaryAction(page, fallbackLabel) {
  const buttonLabels = [/log in/i, /sign in/i, /continue/i, /next/i];
  for (const label of buttonLabels) {
    try {
      await page.getByRole('button', { name: label }).first().click({ timeout: 10000 });
      return;
    } catch (_) {}
  }

  const submitButton = await page.$('button[type="submit"]');
  if (submitButton) {
    await submitButton.click();
    return;
  }

  await page.keyboard.press('Enter');
  if (fallbackLabel) {
    pass(`${fallbackLabel} submitted via Enter`);
  }
}

async function fillFirstVisible(page, selectors, value, label) {
  for (const sel of selectors) {
    const locator = page.locator(sel).first();
    try {
      await locator.waitFor({ state: 'visible', timeout: 10000 });
      await locator.fill(value, { timeout: 10000 });
      pass(`${label} field found and filled`);
      return true;
    } catch (_) {}
  }
  fail(`Could not find ${label.toLowerCase()} field`);
  return false;
}

async function main() {
  const { chromium } = await import(playwrightImportSpec);
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });
  const page = await context.newPage();

  try {
    const loginPageResponse = await page.goto(LOGIN_PAGE_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    const loginPageUrl = page.url();
    if (loginPageResponse && loginPageResponse.status() < 500 && loginPageUrl.includes('/authn/login')) {
      pass('LMS login entrypoint redirects to authn MFE');
    } else {
      fail(`Unexpected LMS login entrypoint result: status=${loginPageResponse ? loginPageResponse.status() : 'none'} url=${loginPageUrl}`);
    }

    await page.goto(OIDC_LOGIN_URL, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForLoadState('domcontentloaded', { timeout: 30000 }).catch(() => {});

    const loginUrl = page.url();
    if (
      loginUrl.includes('auth0') ||
      loginUrl.includes('authentik') ||
      loginUrl.includes('/if/flow/') ||
      loginUrl.includes('/auth/login/oidc') ||
      loginUrl.includes('login')
    ) {
      pass('Redirected to SSO login');
    } else {
      fail(`Unexpected login URL: ${loginUrl}`);
    }

    const usernameReady = await fillFirstVisible(
      page,
      [
        'input[placeholder="Email or Username"]',
        '#id_uid_field',
        'input[name="uidField"]',
        'input[name="username"]',
        'input[type="email"]',
      ],
      SSO_USERNAME,
      'Username',
    );
    if (!usernameReady) {
      throw new Error('SSO username field not found');
    }

    await clickPrimaryAction(page);
    await page.waitForLoadState('domcontentloaded', { timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(1500);

    const passwordReady = await fillFirstVisible(
      page,
      [
        'input[placeholder="Password"]',
        '#id_password',
        'input[name="password"]',
        'input[type="password"]',
      ],
      SSO_PASSWORD,
      'Password',
    );
    if (!passwordReady) {
      throw new Error('SSO password field not found');
    }

    await clickPrimaryAction(page);
    await page.waitForURL(
      url => !/auth0|authentik|\/if\/flow\/|\/auth\/login\/oidc|\/authn\/login|\/login\b/i.test(url),
      { timeout: 60000 },
    ).catch(() => {});
    await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(3000);

    const postLoginUrl = page.url();
    if (!/auth0|authentik|\/if\/flow\/|\/auth\/login\/oidc|\/authn\/login|\/login\b/i.test(postLoginUrl)) {
      pass('Login completed — no longer on auth page');
    } else {
      fail(`Still on login page after auth: ${postLoginUrl}`);
    }

    await page.goto(LEARNER_DASHBOARD_URL, { waitUntil: 'networkidle', timeout: 30000 });
    const dashStatus = page.url();
    if (!dashStatus.includes('login') && !dashStatus.includes('authn')) {
      pass('Learner dashboard accessible (authenticated)');
    } else {
      fail('Learner dashboard redirected to login');
    }

    await page.goto(ACCOUNT_SETTINGS_URL, { waitUntil: 'networkidle', timeout: 30000 });
    const accountStatus = page.url();
    if (!accountStatus.includes('login') && !accountStatus.includes('authn')) {
      pass('Account settings accessible (authenticated)');
    } else {
      fail('Account settings redirected to login');
    }

    const courseResponse = await page.goto(LEARNING_URL, { waitUntil: 'networkidle', timeout: 30000 });
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

  console.log(JSON.stringify(results));
}

main().catch(err => {
  console.log(JSON.stringify([{ status: 'FAIL', msg: `Fatal: ${err.message}` }]));
  process.exit(0);
});
PLAYWRIGHT_EOF

# Run Playwright
PLAYWRIGHT_OUTPUT=$(
  SMOKE_TARGET="${TARGET}" \
  SMOKE_MFE_BASE_URL="${MFE_BASE_URL}" \
  SSO_USERNAME="${SSO_USERNAME}" \
  SSO_PASSWORD="${SSO_PASSWORD}" \
  PLAYWRIGHT_IMPORT_SPEC="${PLAYWRIGHT_IMPORT_SPEC_RESOLVED}" \
  node "$PLAYWRIGHT_SCRIPT" 2>/dev/null || true
)

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
  fail "Playwright output not parseable — authenticated checks did not produce structured results"
  FAIL_COUNT=$((FAIL_COUNT + 1))
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
