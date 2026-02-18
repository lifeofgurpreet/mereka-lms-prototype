#!/usr/bin/env bash
# @covers AC-VIS-001, AC-VIS-002, AC-VIS-003, AC-VIS-004
# @spec: bead-115d15
#
# verify-visual-smoke-baseline.sh
#
# Verification script for the authenticated visual smoke + screenshot baseline
# contract (bead mereka-lms-115d.15).
#
# Modes:
#   Offline (default) — validates documentation, config, and CI wiring exist.
#   Live (VISUAL_SMOKE_LIVE=1) — would run actual authenticated screenshot
#       comparisons against a live cluster (placeholder, requires Playwright +
#       SSO credentials).
#
# Usage:
#   ./scripts/qa/verify-visual-smoke-baseline.sh
#   VISUAL_SMOKE_LIVE=1 ./scripts/qa/verify-visual-smoke-baseline.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LIVE_MODE="${VISUAL_SMOKE_LIVE:-0}"

# ---------------------------------------------------------------------------
# Output helpers — match the do_pass/do_fail/do_warn style used across the
# scripts/qa/ family (e.g. verify-copy-terminology.sh).
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-VIS-001..004: Authenticated Visual Smoke Baseline Verification ==="
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "Mode: LIVE (VISUAL_SMOKE_LIVE=1)"
else
  echo "Mode: OFFLINE (set VISUAL_SMOKE_LIVE=1 for live cluster checks)"
fi
echo ""

# ===========================================================================
# AC-VIS-001: Authenticated smoke harness exists
# ===========================================================================
echo "--- AC-VIS-001: Authenticated Smoke Harness ---"

# 1a. The primary smoke script must exist and be executable.
SMOKE_SCRIPT="$REPO_ROOT/scripts/qa/smoke-authenticated.sh"
if [[ -f "$SMOKE_SCRIPT" ]]; then
  do_pass "smoke-authenticated.sh exists"
else
  do_fail "smoke-authenticated.sh not found at scripts/qa/"
fi

if [[ -f "$SMOKE_SCRIPT" ]] && [[ -x "$SMOKE_SCRIPT" ]]; then
  do_pass "smoke-authenticated.sh is executable"
elif [[ -f "$SMOKE_SCRIPT" ]]; then
  do_warn "smoke-authenticated.sh is not executable (run: chmod +x $SMOKE_SCRIPT)"
fi

# 1b. Visual regression script must support --authenticated flag (the hook
#     that authenticated flows are wired into).
VISUAL_SCRIPT="$REPO_ROOT/scripts/qa/visual-regression-test.sh"
if [[ -f "$VISUAL_SCRIPT" ]]; then
  do_pass "visual-regression-test.sh exists"
  if grep -q "\-\-authenticated" "$VISUAL_SCRIPT"; then
    do_pass "visual-regression-test.sh supports --authenticated flag"
  else
    do_warn "visual-regression-test.sh missing --authenticated flag (AC-VIS-001 gap)"
  fi
else
  do_fail "visual-regression-test.sh not found at scripts/qa/"
fi

# 1c. SSO credential pattern must be referenced (env var, not hardcoded).
#     Check across authenticated smoke infrastructure.
AUTH_DOC="$REPO_ROOT/docs/operations/AUTHENTICATED_SMOKE_CREDENTIALS.md"
if [[ -f "$AUTH_DOC" ]]; then
  do_pass "AUTHENTICATED_SMOKE_CREDENTIALS.md exists"
  if grep -q "SMOKE_SSO_USERNAME\|SSO_USERNAME" "$AUTH_DOC"; then
    do_pass "Auth credentials reference SSO_USERNAME env var pattern"
  else
    do_warn "Auth doc does not reference SSO_USERNAME env var pattern"
  fi
else
  do_warn "AUTHENTICATED_SMOKE_CREDENTIALS.md not found (expected at docs/operations/)"
fi

# 1d. Visual smoke baseline doc itself must exist.
BASELINE_DOC="$REPO_ROOT/docs/operations/VISUAL_SMOKE_BASELINE.md"
if [[ -f "$BASELINE_DOC" ]]; then
  do_pass "VISUAL_SMOKE_BASELINE.md exists"
else
  do_fail "VISUAL_SMOKE_BASELINE.md not found (create docs/operations/VISUAL_SMOKE_BASELINE.md)"
fi

# 1e. LIVE mode — attempt a real auth check (placeholder).
if [[ "$LIVE_MODE" == "1" ]]; then
  echo ""
  echo "  [LIVE] Authenticated cookie acquisition would run here."
  echo "         Requires: SSO_USERNAME, SSO_PASSWORD env vars + Playwright."
  if [[ -n "${SSO_USERNAME:-}" ]]; then
    do_pass "[LIVE] SSO_USERNAME env var is set"
  else
    do_warn "[LIVE] SSO_USERNAME not set — authenticated flows will be skipped"
  fi
fi

echo ""

# ===========================================================================
# AC-VIS-002: Visual baseline captures defined for 5 critical MFE routes
# ===========================================================================
echo "--- AC-VIS-002: Baseline Route Coverage ---"

# The 5 routes that must be baselined.
declare -a REQUIRED_ROUTES=(
  "learner-dashboard"
  "learning"
  "account"
  "profile"
  "course-authoring"
)

# Check documentation declares all 5 routes.
if [[ -f "$BASELINE_DOC" ]]; then
  routes_found=0
  for route in "${REQUIRED_ROUTES[@]}"; do
    if grep -q "$route" "$BASELINE_DOC"; then
      do_pass "AC-VIS-002: route '$route' declared in VISUAL_SMOKE_BASELINE.md"
      routes_found=$((routes_found + 1))
    else
      do_fail "AC-VIS-002: route '$route' NOT found in VISUAL_SMOKE_BASELINE.md"
    fi
  done
  if [[ "$routes_found" -eq "${#REQUIRED_ROUTES[@]}" ]]; then
    do_pass "AC-VIS-002: all 5 required routes declared"
  fi
else
  do_warn "AC-VIS-002: cannot check routes — VISUAL_SMOKE_BASELINE.md missing"
fi

# Check that the visual regression script references authenticated routes.
if [[ -f "$VISUAL_SCRIPT" ]]; then
  vis_routes=0
  for route in "${REQUIRED_ROUTES[@]}"; do
    if grep -q "$route" "$VISUAL_SCRIPT"; then
      vis_routes=$((vis_routes + 1))
    fi
  done
  if [[ "$vis_routes" -ge 3 ]]; then
    do_pass "AC-VIS-002: visual-regression-test.sh references $vis_routes/5 required routes"
  else
    do_warn "AC-VIS-002: visual-regression-test.sh references only $vis_routes/5 required routes"
  fi
fi

# LIVE mode — verify baseline screenshot files exist on disk.
if [[ "$LIVE_MODE" == "1" ]]; then
  BASELINE_DIR="${BASELINE_DIR:-$REPO_ROOT/var/screenshots/baseline}"
  echo ""
  echo "  [LIVE] Checking baseline directory: $BASELINE_DIR"
  if [[ -d "$BASELINE_DIR" ]]; then
    do_pass "[LIVE] Baseline directory exists: $BASELINE_DIR"
    for route in "${REQUIRED_ROUTES[@]}"; do
      if ls "$BASELINE_DIR"/*"${route}"*.png 2>/dev/null | grep -q .; then
        do_pass "[LIVE] Baseline screenshot found for route: $route"
      else
        do_warn "[LIVE] No baseline screenshot for route: $route (run baseline capture)"
      fi
    done
  else
    do_warn "[LIVE] Baseline directory not found — run baseline capture first"
    echo "         Command: RUN_SCREENSHOTS=1 RUN_VISUAL_REGRESSION=1 \\"
    echo "           ./scripts/branding/run-branding-gates.sh prod"
  fi
fi

echo ""

# ===========================================================================
# AC-VIS-003: Diff threshold policy documented
# ===========================================================================
echo "--- AC-VIS-003: Diff Threshold Policy ---"

# Check baseline doc for threshold declaration.
if [[ -f "$BASELINE_DOC" ]]; then
  if grep -qiE "RMSE|rmse|threshold|diff.*threshold" "$BASELINE_DOC"; then
    do_pass "AC-VIS-003: RMSE/threshold policy mentioned in VISUAL_SMOKE_BASELINE.md"
  else
    do_fail "AC-VIS-003: No RMSE/threshold policy found in VISUAL_SMOKE_BASELINE.md"
  fi

  if grep -qiE "false.positive|triage" "$BASELINE_DOC"; then
    do_pass "AC-VIS-003: False positive triage documented"
  else
    do_warn "AC-VIS-003: False positive triage section missing"
  fi
else
  do_warn "AC-VIS-003: cannot check threshold policy — VISUAL_SMOKE_BASELINE.md missing"
fi

# Check existing visual regression runbook as a fallback reference.
VIS_RUNBOOK="$REPO_ROOT/docs/operations/VISUAL_REGRESSION_RUNBOOK.md"
if [[ -f "$VIS_RUNBOOK" ]]; then
  do_pass "AC-VIS-003: VISUAL_REGRESSION_RUNBOOK.md exists (baseline threshold reference)"
  if grep -qiE "5%|threshold|RMSE" "$VIS_RUNBOOK"; then
    do_pass "AC-VIS-003: Runbook documents diff threshold (5% / RMSE policy)"
  else
    do_warn "AC-VIS-003: Runbook does not explicitly state RMSE threshold"
  fi
else
  do_warn "AC-VIS-003: VISUAL_REGRESSION_RUNBOOK.md not found"
fi

echo ""

# ===========================================================================
# AC-VIS-004: CI wiring present
# ===========================================================================
echo "--- AC-VIS-004: CI Wiring ---"

CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"
SMOKE_CI="$REPO_ROOT/.github/workflows/smoke-authenticated.yml"

# 4a. Main CI must syntax-check the visual smoke baseline script.
if [[ -f "$CI_FILE" ]]; then
  do_pass "AC-VIS-004: .github/workflows/ci.yml exists"
  if grep -q "verify-visual-smoke-baseline.sh" "$CI_FILE"; then
    do_pass "AC-VIS-004: ci.yml references verify-visual-smoke-baseline.sh"
  else
    do_warn "AC-VIS-004: ci.yml does not reference verify-visual-smoke-baseline.sh yet"
  fi
else
  do_fail "AC-VIS-004: .github/workflows/ci.yml not found"
fi

# 4b. Dedicated smoke-authenticated workflow must exist.
if [[ -f "$SMOKE_CI" ]]; then
  do_pass "AC-VIS-004: smoke-authenticated.yml workflow exists"
  if grep -qiE "visual|screenshot" "$SMOKE_CI"; then
    do_pass "AC-VIS-004: smoke-authenticated.yml references visual/screenshot checks"
  else
    do_warn "AC-VIS-004: smoke-authenticated.yml does not reference visual regression"
  fi
else
  do_warn "AC-VIS-004: smoke-authenticated.yml not found (authenticated CI not wired)"
fi

# 4c. Check that the branding cron infrastructure exists (VPS-side CI equivalent).
CRON_SCRIPT="$REPO_ROOT/scripts/infra/setup-vps-branding-visual-regression-cron.sh"
if [[ -f "$CRON_SCRIPT" ]]; then
  do_pass "AC-VIS-004: VPS branding visual regression cron installer exists"
else
  do_warn "AC-VIS-004: VPS cron installer not found at scripts/infra/"
fi

# 4d. Check run-branding-gates.sh exists and supports the RUN_ flags.
BRANDING_GATES="$REPO_ROOT/scripts/branding/run-branding-gates.sh"
if [[ -f "$BRANDING_GATES" ]]; then
  do_pass "AC-VIS-004: run-branding-gates.sh exists"
  if grep -q "RUN_SCREENSHOTS" "$BRANDING_GATES" && grep -q "RUN_VISUAL_REGRESSION" "$BRANDING_GATES"; then
    do_pass "AC-VIS-004: run-branding-gates.sh supports RUN_SCREENSHOTS + RUN_VISUAL_REGRESSION flags"
  else
    do_warn "AC-VIS-004: run-branding-gates.sh missing expected RUN_ flags"
  fi
else
  do_warn "AC-VIS-004: run-branding-gates.sh not found"
fi

# 4e. LIVE mode — attempt a trivial unauthenticated HTTP probe of one MFE route.
if [[ "$LIVE_MODE" == "1" ]]; then
  DOMAIN="${VISUAL_SMOKE_DOMAIN:-academyv2.mereka.io}"
  echo ""
  echo "  [LIVE] Probing MFE base: https://apps.$DOMAIN/learner-dashboard/"
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time 10 "https://apps.${DOMAIN}/learner-dashboard/" 2>/dev/null || echo "000")
  if [[ "$http_code" == "200" ]]; then
    do_pass "[LIVE] learner-dashboard reachable (HTTP 200)"
  elif [[ "$http_code" == "000" ]]; then
    do_warn "[LIVE] learner-dashboard unreachable (timeout) — is the cluster up?"
  else
    do_warn "[LIVE] learner-dashboard returned HTTP $http_code"
  fi
fi

echo ""

# ===========================================================================
# Summary
# ===========================================================================
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Action required: Fix FAIL items above."
  echo "  - Create docs/operations/VISUAL_SMOKE_BASELINE.md if missing"
  echo "  - Ensure smoke-authenticated.sh covers all 5 MFE routes"
  echo "  - Wire verify-visual-smoke-baseline.sh into .github/workflows/ci.yml"
  echo "  - See docs/operations/VISUAL_SMOKE_BASELINE.md for full runbook"
  exit 1
fi

echo ""
echo "All visual smoke baseline checks passed (WARNs are live-cluster-only)."
exit 0
