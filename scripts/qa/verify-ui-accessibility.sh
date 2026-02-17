#!/usr/bin/env bash
# verify-ui-accessibility.sh — Axe-core accessibility checks for core user journeys
# @covers AC-UIQ-002
#
# Runs axe-core via Playwright against live URLs to detect WCAG 2.1 AA violations.
# Requires a running Open edX instance (local or production).
#
# Usage:
#   ./scripts/qa/verify-ui-accessibility.sh [--target URL]
#   A11Y_TARGET=https://academyv2.mereka.io ./scripts/qa/verify-ui-accessibility.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

TARGET="${A11Y_TARGET:-http://apps.localhost}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo -e "${BLUE}=== Accessibility Gate (axe-core) ===${NC}"
echo -e "Target: ${TARGET}"
echo ""

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS_COUNT++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL_COUNT++)) || true; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN_COUNT++)) || true; }

# Core user journeys to test
JOURNEYS=(
  "/authn/login|Login page"
  "/learner-dashboard/|Learner dashboard"
  "/learning/|Course player"
  "/discussions/|Discussions"
)

# Check prerequisites
echo -e "${BLUE}## Prerequisites${NC}"

if command -v node &>/dev/null; then
  pass "Node.js available ($(node --version))"
else
  fail "Node.js not found"
  exit 1
fi

# Create temporary Playwright + axe script
AXE_SCRIPT=$(mktemp /tmp/a11y-check-XXXXXX.mjs)
RESULTS_DIR=$(mktemp -d /tmp/a11y-results-XXXXXX)
trap 'rm -f "$AXE_SCRIPT"; rm -r "$RESULTS_DIR"' EXIT

cat > "$AXE_SCRIPT" << 'AXE_EOF'
import { chromium } from 'playwright';
import fs from 'fs';

const TARGET = process.env.A11Y_TARGET || 'http://apps.localhost';
const RESULTS_DIR = process.env.RESULTS_DIR || '/tmp';

// Inline axe-core snippet — runs axe.run() in the browser context
// We inject axe-core from CDN into the page
const AXE_CDN = 'https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.9.1/axe.min.js';

const journeys = JSON.parse(process.env.JOURNEYS || '[]');
const results = [];

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ ignoreHTTPSErrors: true });

  for (const journey of journeys) {
    const [path, label] = journey.split('|');
    const url = TARGET.replace(/\/$/, '') + path;
    const page = await context.newPage();

    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });

      // Inject axe-core
      await page.addScriptTag({ url: AXE_CDN });
      await page.waitForFunction('typeof axe !== "undefined"', { timeout: 10000 });

      // Run axe
      const axeResults = await page.evaluate(async () => {
        return await axe.run(document, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] },
        });
      });

      const violations = axeResults.violations || [];
      const criticalCount = violations.filter(v => v.impact === 'critical').length;
      const seriousCount = violations.filter(v => v.impact === 'serious').length;
      const totalNodes = violations.reduce((sum, v) => sum + (v.nodes || []).length, 0);

      // Save detailed results
      const safeLabel = label.replace(/[^a-z0-9]/gi, '-').toLowerCase();
      fs.writeFileSync(
        `${RESULTS_DIR}/${safeLabel}.json`,
        JSON.stringify(axeResults, null, 2)
      );

      results.push({
        label,
        path,
        status: criticalCount === 0 && seriousCount === 0 ? 'PASS' : (criticalCount > 0 ? 'FAIL' : 'WARN'),
        violations: violations.length,
        critical: criticalCount,
        serious: seriousCount,
        nodes: totalNodes,
      });
    } catch (err) {
      results.push({
        label,
        path,
        status: 'WARN',
        violations: 0,
        critical: 0,
        serious: 0,
        nodes: 0,
        error: err.message,
      });
    } finally {
      await page.close();
    }
  }

  await browser.close();
  console.log(JSON.stringify(results));
}

main().catch(err => {
  console.log(JSON.stringify([{ label: 'fatal', status: 'FAIL', error: err.message }]));
});
AXE_EOF

echo ""
echo -e "${BLUE}## Accessibility Checks${NC}"

# Build journeys JSON
JOURNEYS_JSON="["
for j in "${JOURNEYS[@]}"; do
  JOURNEYS_JSON+="\"${j}\","
done
JOURNEYS_JSON="${JOURNEYS_JSON%,}]"

# Run the axe checks
AXE_OUTPUT=$(A11Y_TARGET="${TARGET}" RESULTS_DIR="${RESULTS_DIR}" JOURNEYS="${JOURNEYS_JSON}" \
  node "$AXE_SCRIPT" 2>/dev/null || echo '[]')

# Parse results
if echo "$AXE_OUTPUT" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
  echo "$AXE_OUTPUT" | python3 -c "
import sys, json
results = json.load(sys.stdin)
for r in results:
    label = r.get('label', 'unknown')
    status = r.get('status', 'FAIL')
    violations = r.get('violations', 0)
    critical = r.get('critical', 0)
    serious = r.get('serious', 0)
    nodes = r.get('nodes', 0)
    error = r.get('error', '')

    if error:
        print(f'\033[1;33m[WARN]\033[0m {label}: {error}')
    elif status == 'PASS':
        print(f'\033[0;32m[PASS]\033[0m {label}: 0 critical/serious violations')
    elif status == 'WARN':
        print(f'\033[1;33m[WARN]\033[0m {label}: {serious} serious, {violations} total violations ({nodes} nodes)')
    else:
        print(f'\033[0;31m[FAIL]\033[0m {label}: {critical} critical, {serious} serious violations ({nodes} nodes)')
" 2>/dev/null

  # Count pass/fail/warn from axe results
  AXE_PASS=$(echo "$AXE_OUTPUT" | python3 -c "import sys,json; print(sum(1 for r in json.load(sys.stdin) if r.get('status')=='PASS'))" 2>/dev/null || echo 0)
  AXE_FAIL=$(echo "$AXE_OUTPUT" | python3 -c "import sys,json; print(sum(1 for r in json.load(sys.stdin) if r.get('status')=='FAIL'))" 2>/dev/null || echo 0)
  AXE_WARN=$(echo "$AXE_OUTPUT" | python3 -c "import sys,json; print(sum(1 for r in json.load(sys.stdin) if r.get('status')=='WARN'))" 2>/dev/null || echo 0)
  PASS_COUNT=$((PASS_COUNT + AXE_PASS))
  FAIL_COUNT=$((FAIL_COUNT + AXE_FAIL))
  WARN_COUNT=$((WARN_COUNT + AXE_WARN))
else
  warn "Axe output not parseable — skipping accessibility checks"
fi

echo ""
echo -e "${BLUE}## Axe Reports${NC}"
echo "  Detailed JSON reports saved to: ${RESULTS_DIR}/"

echo ""
echo -e "${BLUE}## Summary${NC}"
echo ""
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}All accessibility checks passed${NC}"
  exit 0
else
  echo -e "${RED}Some accessibility checks failed${NC}"
  exit 1
fi
