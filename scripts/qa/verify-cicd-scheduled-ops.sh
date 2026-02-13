#!/usr/bin/env bash
# @covers AC-022, AC-023, AC-024, AC-029, AC-030
# @spec: ci-cd-pipeline_spec.md
# Verify scheduled operations workflows (health checks, DR evidence, SSO canary)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "Verifying scheduled operations workflows..."
echo ""

# AC-022: public-health-check.yml validates branding on prod and dev
WORKFLOW=".github/workflows/public-health-check.yml"
if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-022: $WORKFLOW not found"
else
  if grep -q "run-branding-gates.sh prod" "$WORKFLOW" && \
     grep -q "run-branding-gates.sh dev" "$WORKFLOW"; then
    pass "AC-022: public-health-check.yml validates branding for prod and dev"
  else
    fail "AC-022: public-health-check.yml missing branding gates for both environments"
  fi
fi

# AC-023: operations-gates-runtime.yml uploads artifacts with 30-day retention
WORKFLOW=".github/workflows/operations-gates-runtime.yml"
if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-023: $WORKFLOW not found"
else
  if grep -q "retention-days: 30" "$WORKFLOW" || \
     grep -A 5 "upload-artifact" "$WORKFLOW" | grep -q "retention-days: 30"; then
    pass "AC-023: operations-gates-runtime.yml uses 30-day artifact retention"
  else
    fail "AC-023: operations-gates-runtime.yml missing 30-day retention setting"
  fi
fi

# AC-024: dr-evidence-bundle.yml runs 1st of month, uploads with 120-day retention
WORKFLOW=".github/workflows/dr-evidence-bundle.yml"
if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-024: $WORKFLOW not found"
else
  has_monthly_schedule=0
  has_120day_retention=0

  # Check for 1st of month cron schedule (various patterns)
  if grep -E "cron:.*'[^']*1 \* \*'|cron:.*\"[^\"]*1 \* \*\"" "$WORKFLOW" || \
     grep -A 2 "schedule:" "$WORKFLOW" | grep -E "1 .* \* \*"; then
    has_monthly_schedule=1
  fi

  # Check for 120-day retention
  if grep -q "retention-days: 120" "$WORKFLOW"; then
    has_120day_retention=1
  fi

  if [[ $has_monthly_schedule -eq 1 && $has_120day_retention -eq 1 ]]; then
    pass "AC-024: dr-evidence-bundle.yml runs 1st of month with 120-day retention"
  elif [[ $has_monthly_schedule -eq 0 ]]; then
    fail "AC-024: dr-evidence-bundle.yml missing monthly schedule"
  else
    fail "AC-024: dr-evidence-bundle.yml missing 120-day retention"
  fi
fi

# AC-029: SSO canary runs every 6h, authenticates to LMS and Studio
WORKFLOW=".github/workflows/authenticated-sso-canary.yml"
if [[ ! -f "$WORKFLOW" ]]; then
  fail "AC-029: $WORKFLOW not found"
else
  has_6h_schedule=0
  has_auth_check=0

  # Check for 6-hour cron (various patterns: */6, 0 */6, etc.)
  if grep -E "cron:.*'\*/6|cron:.*\"0 \*/6|cron:.*0 \*/6" "$WORKFLOW"; then
    has_6h_schedule=1
  fi

  # Check for authentication steps (SSO canary script or Playwright)
  if grep -q "verify-authenticated-sso-canary.sh" "$WORKFLOW" || \
     (grep -q "SSO_CANARY_EMAIL" "$WORKFLOW" && grep -q "playwright" "$WORKFLOW"); then
    has_auth_check=1
  fi

  if [[ $has_6h_schedule -eq 1 && $has_auth_check -eq 1 ]]; then
    pass "AC-029: authenticated-sso-canary.yml runs every 6h with auth checks"
  elif [[ $has_6h_schedule -eq 0 ]]; then
    fail "AC-029: authenticated-sso-canary.yml missing 6-hour schedule"
  else
    fail "AC-029: authenticated-sso-canary.yml missing authentication steps"
  fi
fi

# AC-030: SSO canary failure uploads artifacts (screenshots, logs)
if [[ -f "$WORKFLOW" ]]; then
  if grep -q "upload-artifact\|upload.*artifact" "$WORKFLOW"; then
    # Check for always() condition (may be on previous line)
    if grep -B 2 -A 3 "upload-artifact\|upload.*artifact" "$WORKFLOW" | grep -q "always()"; then
      pass "AC-030: authenticated-sso-canary.yml uploads artifacts on failure"
    else
      fail "AC-030: authenticated-sso-canary.yml has artifact upload but not running on failure"
    fi
  else
    fail "AC-030: authenticated-sso-canary.yml missing artifact upload"
  fi
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
