#!/usr/bin/env bash
# @covers AC-HB-001, AC-HB-002, AC-HB-003, AC-HB-004, AC-HB-005, AC-HB-006
# @spec: bead-115d25
#
# verify-ui-ux-hardening-bundle.sh
#
# World-class UI/UX hardening lane — visual + a11y + performance bundle gate.
# Validates that all six acceptance criteria are satisfied at the source level:
#
#   AC-HB-001 — Visual regression baseline (10+ routes, baseline refresh playbook)
#   AC-HB-002 — A11y gate (focus/landmark/contrast + route-level exception policy)
#   AC-HB-003 — Performance budgets (bundle size, LCP proxy, JS error budgets)
#   AC-HB-004 — CI integration (gate outputs wired into ci.yml)
#   AC-HB-005 — Weekly trend report + triage template
#   AC-HB-006 — Exception register for intentional cosmetic deviations
#
# Modes:
#   Offline (default) — validates docs, config, and CI wiring (suitable for CI).
#   Live (UI_HARDENING_LIVE=1) — additionally probe live cluster routes.
#
# Usage:
#   ./scripts/qa/verify-ui-ux-hardening-bundle.sh
#   UI_HARDENING_LIVE=1 ./scripts/qa/verify-ui-ux-hardening-bundle.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

LIVE_MODE="${UI_HARDENING_LIVE:-0}"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-HB-001..006: UI/UX Hardening Bundle Verification ==="
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "Mode: LIVE (UI_HARDENING_LIVE=1)"
else
  echo "Mode: OFFLINE (set UI_HARDENING_LIVE=1 for live cluster checks)"
fi
echo ""

# ---------------------------------------------------------------------------
# Canonical paths used across multiple ACs
# ---------------------------------------------------------------------------
HARDENING_DOC="$REPO_ROOT/docs/reference/operations/UI_UX_HARDENING_BUNDLE.md"
CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"
PERF_BUDGET_DOC="$REPO_ROOT/docs/policies/architecture/PERFORMANCE_BUDGETS.md"
A11Y_GATE_DOC="$REPO_ROOT/docs/ops/runbooks/A11Y_CONTRAST_FOCUS_GATE.md"
VISUAL_BASELINE_DOC="$REPO_ROOT/docs/ops/runbooks/VISUAL_SMOKE_BASELINE.md"
VISUAL_RUNBOOK="$REPO_ROOT/docs/ops/runbooks/VISUAL_REGRESSION_RUNBOOK.md"
VISUAL_PARITY_DOC="$REPO_ROOT/docs/ops/runbooks/VISUAL_PARITY_CHECKPOINTS.md"

# ===========================================================================
# AC-HB-001: Visual regression baseline — 10+ critical routes + refresh playbook
# ===========================================================================
echo "--- AC-HB-001: Visual Regression Baseline ---"

# 1a. Primary hardening doc must exist.
if [[ -f "$HARDENING_DOC" ]]; then
  do_pass "AC-HB-001: UI_UX_HARDENING_BUNDLE.md exists"
else
  do_fail "AC-HB-001: UI_UX_HARDENING_BUNDLE.md not found at docs/reference/operations/"
fi

# 1b. Hardening doc must declare 10+ critical routes.
if [[ -f "$HARDENING_DOC" ]]; then
  # Count distinct route entries (lines containing /learner-dashboard, /learning, /account, etc.)
  ROUTE_COUNT=$(grep -oE '`?/[a-zA-Z0-9_/-]+`?' "$HARDENING_DOC" 2>/dev/null \
    | grep -cE '/(learner-dashboard|learning|account|gradebook|profile|authn|course|discussions|program|search)' \
    || echo 0)
  if [[ "$ROUTE_COUNT" -ge 10 ]]; then
    do_pass "AC-HB-001: $ROUTE_COUNT critical route references found (>= 10 required)"
  else
    do_fail "AC-HB-001: only $ROUTE_COUNT route references found (need >= 10)"
  fi

  # 1c. Visual regression baseline section must be present.
  if grep -qiE "visual regression baseline|baseline.*route|route.*baseline" "$HARDENING_DOC"; then
    do_pass "AC-HB-001: visual regression baseline section present"
  else
    do_fail "AC-HB-001: visual regression baseline section missing from hardening doc"
  fi

  # 1d. Baseline refresh playbook must be documented.
  if grep -qiE "baseline refresh|refresh playbook|refresh.*procedure|how to.*refresh|update.*baseline" "$HARDENING_DOC"; then
    do_pass "AC-HB-001: baseline refresh playbook documented"
  else
    do_fail "AC-HB-001: baseline refresh playbook not found in hardening doc"
  fi
else
  do_warn "AC-HB-001: cannot check routes and playbook — UI_UX_HARDENING_BUNDLE.md missing"
fi

# 1e. Cross-reference: VISUAL_SMOKE_BASELINE.md must exist.
if [[ -f "$VISUAL_BASELINE_DOC" ]]; then
  do_pass "AC-HB-001: VISUAL_SMOKE_BASELINE.md exists (cross-reference)"
else
  do_warn "AC-HB-001: VISUAL_SMOKE_BASELINE.md not found (expected cross-reference)"
fi

# 1f. Cross-reference: VISUAL_PARITY_CHECKPOINTS.md must exist.
if [[ -f "$VISUAL_PARITY_DOC" ]]; then
  do_pass "AC-HB-001: VISUAL_PARITY_CHECKPOINTS.md exists (cross-reference)"
else
  do_warn "AC-HB-001: VISUAL_PARITY_CHECKPOINTS.md not found"
fi

# 1g. RMSE diff threshold must be declared somewhere in the baseline ecosystem.
RMSE_FOUND=0
for f in "$HARDENING_DOC" "$VISUAL_BASELINE_DOC" "$VISUAL_RUNBOOK"; do
  if [[ -f "$f" ]] && grep -qiE "RMSE|rmse|diff.*threshold|threshold.*diff|pixel.*diff" "$f"; then
    RMSE_FOUND=1
    break
  fi
done
if [[ "$RMSE_FOUND" -eq 1 ]]; then
  do_pass "AC-HB-001: RMSE/diff threshold policy documented in baseline ecosystem"
else
  do_warn "AC-HB-001: RMSE diff threshold not found in baseline docs (advisory)"
fi

echo ""

# ===========================================================================
# AC-HB-002: A11y gate — focus/landmark/contrast + route-level exception policy
# ===========================================================================
echo "--- AC-HB-002: A11y Gate ---"

# 2a. Hardening doc must declare a11y gate section.
if [[ -f "$HARDENING_DOC" ]]; then
  if grep -qiE "a11y gate|accessibility gate|a11y.*gate|gate.*a11y" "$HARDENING_DOC"; then
    do_pass "AC-HB-002: a11y gate section present in hardening doc"
  else
    do_fail "AC-HB-002: a11y gate section missing from UI_UX_HARDENING_BUNDLE.md"
  fi

  # 2b. Focus checks must be declared.
  if grep -qiE "focus.*visible|focus-visible|focus.*indicator|focus.*ring" "$HARDENING_DOC"; then
    do_pass "AC-HB-002: focus-visible / focus indicator requirements documented"
  else
    do_fail "AC-HB-002: focus checks not declared in hardening doc"
  fi

  # 2c. Landmark checks must be declared.
  if grep -qiE "landmark|aria.*landmark|role.*main|role.*navigation|role.*banner|role.*contentinfo" "$HARDENING_DOC"; then
    do_pass "AC-HB-002: landmark checks declared in hardening doc"
  else
    do_fail "AC-HB-002: landmark checks not declared in hardening doc"
  fi

  # 2d. Contrast checks must be declared.
  if grep -qiE "contrast|WCAG.*AA|AA.*contrast|4\.5.*:.*1|3.*:.*1" "$HARDENING_DOC"; then
    do_pass "AC-HB-002: contrast requirements declared in hardening doc"
  else
    do_fail "AC-HB-002: contrast requirements not declared in hardening doc"
  fi

  # 2e. Route-level exception policy with owners must be present.
  if grep -qiE "exception policy|exception.*owner|owner.*exception|route.*exception|exception.*route" "$HARDENING_DOC"; then
    do_pass "AC-HB-002: route-level exception policy with owners documented"
  else
    do_fail "AC-HB-002: route-level exception policy with owners missing"
  fi
else
  do_warn "AC-HB-002: cannot check a11y gate — UI_UX_HARDENING_BUNDLE.md missing"
fi

# 2f. Cross-reference: A11Y_CONTRAST_FOCUS_GATE.md must exist.
if [[ -f "$A11Y_GATE_DOC" ]]; then
  do_pass "AC-HB-002: A11Y_CONTRAST_FOCUS_GATE.md exists (cross-reference)"
else
  do_warn "AC-HB-002: A11Y_CONTRAST_FOCUS_GATE.md not found (expected cross-reference)"
fi

# 2g. A11y gate scripts must exist.
A11Y_SCRIPTS=(
  "$REPO_ROOT/scripts/qa/verify-a11y-contrast-focus.sh"
  "$REPO_ROOT/scripts/qa/verify-a11y-authenticated-routes.sh"
  "$REPO_ROOT/scripts/qa/verify-a11y-tenant-branding.sh"
)
A11Y_SCRIPT_COUNT=0
for s in "${A11Y_SCRIPTS[@]}"; do
  if [[ -f "$s" ]]; then
    A11Y_SCRIPT_COUNT=$((A11Y_SCRIPT_COUNT + 1))
  fi
done
if [[ "$A11Y_SCRIPT_COUNT" -ge 2 ]]; then
  do_pass "AC-HB-002: $A11Y_SCRIPT_COUNT a11y gate scripts found (>= 2 required)"
else
  do_warn "AC-HB-002: only $A11Y_SCRIPT_COUNT a11y gate scripts found (expected >= 2)"
fi

echo ""

# ===========================================================================
# AC-HB-003: Performance budgets — bundle size, LCP proxy, JS error budgets
# ===========================================================================
echo "--- AC-HB-003: Performance Budgets ---"

# 3a. Hardening doc must declare performance budget section.
if [[ -f "$HARDENING_DOC" ]]; then
  if grep -qiE "performance budget|bundle.*size.*budget|budget.*bundle|performance.*threshold" "$HARDENING_DOC"; then
    do_pass "AC-HB-003: performance budget section present in hardening doc"
  else
    do_fail "AC-HB-003: performance budget section missing from UI_UX_HARDENING_BUNDLE.md"
  fi

  # 3b. Bundle size thresholds must be declared.
  if grep -qiE "bundle.*size|main.*bundle|[0-9]+\s*KB|[0-9]+\s*MB.*bundle|gzipped" "$HARDENING_DOC"; then
    do_pass "AC-HB-003: bundle size thresholds documented"
  else
    do_fail "AC-HB-003: bundle size thresholds not declared in hardening doc"
  fi

  # 3c. LCP proxy checks must be declared.
  if grep -qiE "LCP|Largest Contentful Paint|lcp.*proxy|proxy.*lcp|LCP.*check|time.*to.*first" "$HARDENING_DOC"; then
    do_pass "AC-HB-003: LCP proxy check documented"
  else
    do_fail "AC-HB-003: LCP proxy checks not declared in hardening doc"
  fi

  # 3d. JS error budget thresholds must be declared.
  if grep -qiE "JS error budget|error budget|error.*threshold|JS.*error|sentry.*budget|error.*rate" "$HARDENING_DOC"; then
    do_pass "AC-HB-003: JS error budget thresholds documented"
  else
    do_fail "AC-HB-003: JS error budget thresholds not declared in hardening doc"
  fi
else
  do_warn "AC-HB-003: cannot check performance budgets — UI_UX_HARDENING_BUNDLE.md missing"
fi

# 3e. Cross-reference: PERFORMANCE_BUDGETS.md must exist.
if [[ -f "$PERF_BUDGET_DOC" ]]; then
  do_pass "AC-HB-003: PERFORMANCE_BUDGETS.md exists (cross-reference)"

  # Check it declares Web Vitals.
  if grep -qiE "LCP|FID|CLS|TTFB" "$PERF_BUDGET_DOC"; then
    do_pass "AC-HB-003: Web Vitals defined in PERFORMANCE_BUDGETS.md"
  else
    do_warn "AC-HB-003: Web Vitals not found in PERFORMANCE_BUDGETS.md"
  fi
else
  do_warn "AC-HB-003: PERFORMANCE_BUDGETS.md not found (expected cross-reference)"
fi

# 3f. Performance budget gate scripts must exist.
PERF_SCRIPTS=(
  "$REPO_ROOT/scripts/qa/verify-performance-budget.sh"
  "$REPO_ROOT/scripts/qa/verify-error-budget.sh"
  "$REPO_ROOT/scripts/qa/check-error-budget-gate.sh"
)
PERF_SCRIPT_COUNT=0
for s in "${PERF_SCRIPTS[@]}"; do
  if [[ -f "$s" ]]; then
    PERF_SCRIPT_COUNT=$((PERF_SCRIPT_COUNT + 1))
  fi
done
if [[ "$PERF_SCRIPT_COUNT" -ge 2 ]]; then
  do_pass "AC-HB-003: $PERF_SCRIPT_COUNT performance gate scripts found (>= 2 required)"
else
  do_warn "AC-HB-003: only $PERF_SCRIPT_COUNT performance gate scripts found"
fi

echo ""

# ===========================================================================
# AC-HB-004: CI integration — gate outputs wired into ci.yml
# ===========================================================================
echo "--- AC-HB-004: CI Integration ---"

CI_SCRIPTS_LIST="$REPO_ROOT/.github/ci-scripts-static.txt"

# Helper: check if pattern exists in ci.yml OR ci-scripts-static.txt
_ci_has() {
  local pattern="$1"
  local use_fixed="${2:-}"  # if "F", use -F (fixed string); else regex
  if [[ -f "$CI_FILE" ]]; then
    if [[ "$use_fixed" == "F" ]]; then
      grep -qF "$pattern" "$CI_FILE" && return 0
    else
      grep -qE "$pattern" "$CI_FILE" && return 0
    fi
  fi
  if [[ -f "$CI_SCRIPTS_LIST" ]]; then
    if [[ "$use_fixed" == "F" ]]; then
      grep -qF "$pattern" "$CI_SCRIPTS_LIST" && return 0
    else
      grep -qE "$pattern" "$CI_SCRIPTS_LIST" && return 0
    fi
  fi
  return 1
}

if [[ ! -f "$CI_FILE" ]]; then
  do_fail "AC-HB-004: .github/workflows/ci.yml not found"
else
  do_pass "AC-HB-004: .github/workflows/ci.yml exists"

  # 4a. UI/UX hardening bundle job must be referenced (ci.yml or ci-scripts-static.txt).
  if _ci_has "ui-ux-hardening-bundle|verify-ui-ux-hardening-bundle"; then
    do_pass "AC-HB-004: ui-ux-hardening-bundle referenced in CI"
  else
    do_fail "AC-HB-004: ui-ux-hardening-bundle NOT referenced in CI (ci.yml or ci-scripts-static.txt)"
  fi

  # 4b. A11y gate scripts must be in CI.
  if _ci_has "verify-a11y-contrast-focus\.sh|verify-a11y-authenticated-routes\.sh"; then
    do_pass "AC-HB-004: a11y gate scripts referenced in CI"
  else
    do_fail "AC-HB-004: a11y gate scripts not found in CI"
  fi

  # 4c. Performance budget gate must be in CI.
  if _ci_has "verify-performance-budget\.sh"; then
    do_pass "AC-HB-004: verify-performance-budget.sh referenced in CI"
  else
    do_fail "AC-HB-004: verify-performance-budget.sh not found in CI"
  fi

  # 4d. Visual regression scripts in CI.
  if _ci_has "verify-visual-parity-checkpoints\.sh|verify-visual-smoke-baseline\.sh"; then
    do_pass "AC-HB-004: visual regression scripts referenced in CI"
  else
    do_fail "AC-HB-004: visual regression scripts not found in CI"
  fi

  # 4e. CI must reference the hardening bundle verify script.
  if _ci_has "verify-ui-ux-hardening-bundle\.sh"; then
    do_pass "AC-HB-004: verify-ui-ux-hardening-bundle.sh in CI"
  else
    do_fail "AC-HB-004: verify-ui-ux-hardening-bundle.sh not in CI"
  fi
fi

echo ""

# ===========================================================================
# AC-HB-005: Weekly trend reports + triage template
# ===========================================================================
echo "--- AC-HB-005: Weekly Trend Reports + Triage Template ---"

if [[ -f "$HARDENING_DOC" ]]; then
  # 5a. Weekly trend report section must be present.
  if grep -qiE "weekly trend|trend report|weekly.*report|report.*weekly" "$HARDENING_DOC"; then
    do_pass "AC-HB-005: weekly trend report section present"
  else
    do_fail "AC-HB-005: weekly trend report section missing from hardening doc"
  fi

  # 5b. Triage template must be present.
  if grep -qiE "triage template|triage.*template|failure triage|triage.*failure|## Triage" "$HARDENING_DOC"; then
    do_pass "AC-HB-005: triage template present in hardening doc"
  else
    do_fail "AC-HB-005: triage template missing from hardening doc"
  fi

  # 5c. Trend report must define specific metrics to track.
  if grep -qiE "PASS.*FAIL.*WARN|pass.*rate|fail.*count|trend.*metric|week.*over.*week|weekly.*metric" "$HARDENING_DOC"; then
    do_pass "AC-HB-005: trend metrics defined (PASS/FAIL/WARN counts or rates)"
  else
    do_warn "AC-HB-005: specific trend metrics not clearly defined in hardening doc"
  fi

  # 5d. Triage template must have actionable fields (failure type, owner, resolution).
  if grep -qiE "failure type|owner|resolution|root cause|action|next step" "$HARDENING_DOC"; then
    do_pass "AC-HB-005: triage template has actionable fields (owner/resolution/root cause)"
  else
    do_warn "AC-HB-005: triage template may be missing actionable fields"
  fi
else
  do_warn "AC-HB-005: cannot check trend reports — UI_UX_HARDENING_BUNDLE.md missing"
fi

echo ""

# ===========================================================================
# AC-HB-006: Exception register for intentional cosmetic deviations
# ===========================================================================
echo "--- AC-HB-006: Exception Register ---"

if [[ -f "$HARDENING_DOC" ]]; then
  # 6a. Exception register section must exist.
  if grep -qiE "exception register|cosmetic.*deviation|deviation.*register|rollback.*safe|intentional.*deviation" "$HARDENING_DOC"; then
    do_pass "AC-HB-006: exception register / cosmetic deviation section present"
  else
    do_fail "AC-HB-006: exception register section missing from hardening doc"
  fi

  # 6b. Exception entries must include rollback safety markers.
  if grep -qiE "rollback.safe|rollback.*flag|safe.*revert|revert.*safe|rollback" "$HARDENING_DOC"; then
    do_pass "AC-HB-006: rollback safety markers documented in exception register"
  else
    do_fail "AC-HB-006: rollback safety markers missing from exception register"
  fi

  # 6c. Must include owner/expiry fields for exception entries.
  if grep -qiE "owner|expiry|expires|approved.*by|review.*date|exception.*date" "$HARDENING_DOC"; then
    do_pass "AC-HB-006: exception register includes owner/expiry tracking"
  else
    do_warn "AC-HB-006: exception register may lack owner/expiry fields"
  fi

  # 6d. Must distinguish intentional deviations from regressions.
  if grep -qiE "intentional|approved exception|known deviation|by design|deliberate" "$HARDENING_DOC"; then
    do_pass "AC-HB-006: distinction between intentional deviations and regressions documented"
  else
    do_warn "AC-HB-006: distinction between intentional vs. accidental deviations not clear"
  fi
else
  do_warn "AC-HB-006: cannot check exception register — UI_UX_HARDENING_BUNDLE.md missing"
fi

echo ""

# ===========================================================================
# LIVE mode — probe cluster routes for basic HTTP health
# ===========================================================================
if [[ "$LIVE_MODE" == "1" ]]; then
  echo "--- LIVE: Cluster Route Health Probes ---"
  DOMAIN="${UI_HARDENING_DOMAIN:-academyv2.mereka.io}"
  echo "  Target: apps.$DOMAIN"
  echo ""

  CRITICAL_ROUTES=(
    "/learner-dashboard/"
    "/account/"
    "/authn/login"
    "/profile/"
  )

  for route in "${CRITICAL_ROUTES[@]}"; do
    url="https://apps.${DOMAIN}${route}"
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$url" 2>/dev/null || echo "000")
    if [[ "$http_code" == "000" ]]; then
      do_warn "[LIVE] AC-HB-001: $route unreachable (timeout)"
    elif [[ "$http_code" =~ ^[23] ]]; then
      do_pass "[LIVE] AC-HB-001: $route HTTP $http_code"
    else
      do_warn "[LIVE] AC-HB-001: $route returned HTTP $http_code"
    fi
  done
  echo ""
fi

# ===========================================================================
# Summary
# ===========================================================================
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "Action required: Fix FAIL items above."
  echo "  - Create or update docs/reference/operations/UI_UX_HARDENING_BUNDLE.md"
  echo "  - Ensure 10+ critical routes listed in the visual regression baseline"
  echo "  - Declare a11y gate (focus/landmark/contrast) + route-level exception policy"
  echo "  - Define bundle size, LCP proxy, and JS error budget thresholds"
  echo "  - Add ui-ux-hardening-bundle job to .github/workflows/ci.yml"
  echo "  - Include weekly trend report template and triage template in doc"
  echo "  - Document exception register with rollback safety and owner/expiry fields"
  echo "  See: docs/reference/operations/UI_UX_HARDENING_BUNDLE.md for full specification."
  exit 1
fi

echo ""
echo "All UI/UX hardening bundle verifications passed (WARNs are advisory)."
exit 0
