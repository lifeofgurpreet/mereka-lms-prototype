#!/usr/bin/env bash
# @spec: branding-system_spec.md
# @covers AC-TBQA-001, AC-TBQA-002, AC-TBQA-003, AC-TBQA-004, AC-TBQA-005
#
# Consolidated tenant branding QA runner.
# Executes all tenant branding verification suites (10 total) and produces a unified
# summary table with per-suite PASS/FAIL/WARN counts.
#
# Usage:
#   ./scripts/qa/run-tenant-branding-qa.sh
#
# Exit codes:
#   0 — all suites passed (WARNs are non-blocking)
#   1 — one or more suites had FAIL > 0

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RUN_BRANDING_GATES_LIVE="${RUN_BRANDING_GATES_LIVE:-1}"
if [[ "$RUN_BRANDING_GATES_LIVE" == "1" ]]; then
  BRANDING_GATES_COMMAND="scripts/branding/run-branding-gates.sh"
else
  BRANDING_GATES_COMMAND="RUN_LIVE_GATE=0 scripts/branding/run-branding-gates.sh"
fi

# In source-only mode, default long runtime suites to off unless explicitly overridden.
if [[ -z "${RUN_TENANT_RUNTIME+x}" ]]; then
  if [[ "$RUN_BRANDING_GATES_LIVE" == "0" ]]; then
    RUN_TENANT_RUNTIME=0
  else
    RUN_TENANT_RUNTIME=1
  fi
fi
if [[ -z "${RUN_MULTISITE_GOVERNANCE+x}" ]]; then
  if [[ "$RUN_BRANDING_GATES_LIVE" == "0" ]]; then
    RUN_MULTISITE_GOVERNANCE=0
  else
    RUN_MULTISITE_GOVERNANCE=1
  fi
fi

# ── colour helpers ──────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── result arrays (parallel-indexed) ────────────────────────────────────────
SUITE_NAMES=()
SUITE_EXITS=()
SUITE_PASS=()
SUITE_FAIL=()
SUITE_WARN=()

# ── suite runner ─────────────────────────────────────────────────────────────
# AC-TBQA-001: single command runs all 9 tenant branding verification suites
# AC-TBQA-005: idempotent — no side-effects, pure read operations
run_suite() {
  local label="$1"
  local command="$2"

  echo ""
  echo -e "${CYAN}── ${label} ──${NC}"
  local output
  local exit_code=0
  output=$(bash -lc "cd '$REPO_ROOT' && $command" 2>&1) || exit_code=$?
  echo "$output"
  # Strip ANSI color codes so summary parsing works for colorized scripts.
  local clean_output
  clean_output="$(echo "$output" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')"

  # AC-TBQA-004: parse PASS / FAIL / WARN counts from summary line
  # Handles multiple summary formats produced by the sub-scripts:
  #   "PASS: N | FAIL: N | SKIP: N"
  #   "PASS: N | FAIL: N | WARN: N"
  #   "N PASS / N FAIL / N WARN"
  #   "PASS: N"  "FAIL: N"  "WARN: N"  (separate lines, plugin slot format)
  local pass="-" fail="-" warn="-"

  # Try "N PASS / N FAIL / N WARN" format (footer-variant-matrix style)
  local summary_line
  summary_line=$(echo "$clean_output" | grep -E '[0-9]+ PASS' | tail -1 || true)
  if [[ -n "$summary_line" ]]; then
    pass=$(echo "$summary_line" | grep -oP '\d+(?= PASS)' || echo "-")
    fail=$(echo "$summary_line" | grep -oP '\d+(?= FAIL)' || echo "-")
    warn=$(echo "$summary_line" | grep -oP '\d+(?= WARN)' || echo "-")
  fi

  # Try "PASS: N | FAIL: N" pipe-separated format (analytics-key / selector style)
  if [[ "$pass" == "-" ]]; then
    local pipe_line
    pipe_line=$(echo "$clean_output" | grep -E 'PASS:.*FAIL:' | tail -1 || true)
    if [[ -n "$pipe_line" ]]; then
      pass=$(echo "$pipe_line" | grep -oP 'PASS:\s*\K\d+' || echo "-")
      fail=$(echo "$pipe_line" | grep -oP 'FAIL:\s*\K\d+' || echo "-")
      warn=$(echo "$pipe_line" | grep -oP 'WARN:\s*\K\d+' || echo "-")
    fi
  fi

  # Try separate-line format produced by verify-plugin-slot-migration-register.sh:
  #   "PASS: N"
  #   "FAIL: N"
  #   "WARN: N"
  if [[ "$pass" == "-" ]]; then
    local p_line f_line w_line
    p_line=$(echo "$clean_output" | grep -E '^PASS: [0-9]+$' | tail -1 || true)
    f_line=$(echo "$clean_output" | grep -E '^FAIL: [0-9]+$' | tail -1 || true)
    w_line=$(echo "$clean_output" | grep -E '^WARN: [0-9]+$' | tail -1 || true)
    if [[ -n "$p_line" ]]; then
      pass=$(echo "$p_line" | grep -oP '\d+' || echo "-")
      fail=$(echo "$f_line" | grep -oP '\d+' || echo "0")
      warn=$(echo "$w_line" | grep -oP '\d+' || echo "0")
    fi
  fi

  # Fallback: count bracket-style result lines ([PASS]/[FAIL]/[WARN]).
  if [[ "$pass" == "-" ]]; then
    local bracket_pass bracket_fail bracket_warn
    bracket_pass=$(echo "$clean_output" | grep -c '\[PASS\]' || true)
    bracket_fail=$(echo "$clean_output" | grep -c '\[FAIL\]' || true)
    bracket_warn=$(echo "$clean_output" | grep -c '\[WARN\]' || true)
    if [[ "$bracket_pass" -gt 0 || "$bracket_fail" -gt 0 || "$bracket_warn" -gt 0 ]]; then
      pass="$bracket_pass"
      fail="$bracket_fail"
      warn="$bracket_warn"
    fi
  fi

  # Normalize missing warn/fail fields when a pass count was parsed.
  if [[ "$pass" != "-" && "$fail" == "-" ]]; then
    fail="0"
  fi
  if [[ "$pass" != "-" && "$warn" == "-" ]]; then
    warn="0"
  fi

  SUITE_NAMES+=("$label")
  SUITE_EXITS+=("$exit_code")
  SUITE_PASS+=("$pass")
  SUITE_FAIL+=("$fail")
  SUITE_WARN+=("$warn")
}

# ── header ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}========================================"
echo    "Tenant Branding QA — Consolidated Runner"
echo -e "========================================${NC}"
echo    "Repo: $REPO_ROOT"
echo    "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo    "Live branding gates: $RUN_BRANDING_GATES_LIVE"
echo    "Tenant runtime suite: $RUN_TENANT_RUNTIME"
echo    "Multisite governance suite: $RUN_MULTISITE_GOVERNANCE"

# ── AC-TBQA-001: run all 10 suites in order ──────────────────────────────────
run_suite "Analytics Key (8jao.1)"          "scripts/qa/verify-analytics-key.sh"
run_suite "Selector Hardening (8jao.3)"     "scripts/qa/verify-mfe-selector-hardening.sh"
run_suite "MFE CSS Architecture"            "scripts/qa/verify-mfe-css-architecture.sh"
run_suite "Token Integrity (8jao.4)"        "scripts/qa/verify-branding-token-integrity.sh"
run_suite "Plugin Slot Register (8jao.9)"   "scripts/qa/verify-plugin-slot-migration-register.sh"
run_suite "Footer Variant Matrix (8jao.10)" "scripts/qa/verify-footer-variant-matrix.sh"
run_suite "RTL Theme Assets"                "scripts/qa/verify-rtl-theme-assets.sh"
if [[ "$RUN_TENANT_RUNTIME" == "1" ]]; then
  run_suite "Tenant Branding Runtime"         "scripts/qa/verify-tenant-branding-runtime.sh"
else
  run_suite "Tenant Branding Runtime"         "echo 'SKIP: disabled (RUN_TENANT_RUNTIME=0)'; echo 'PASS: 0 | FAIL: 0 | WARN: 0'"
fi
run_suite "Branding Gates"                  "$BRANDING_GATES_COMMAND"
if [[ "$RUN_MULTISITE_GOVERNANCE" == "1" ]]; then
  run_suite "Multisite Governance"            "SKIP_DEV_ON_BOTH=1 scripts/qa/run-multisite-governance-gates.sh --env both"
else
  run_suite "Multisite Governance"            "echo 'SKIP: disabled (RUN_MULTISITE_GOVERNANCE=0)'; echo 'PASS: 0 | FAIL: 0 | WARN: 0'"
fi

# ── AC-TBQA-004: consolidated summary table ──────────────────────────────────
echo ""
echo -e "${BOLD}========================================"
echo    "Tenant Branding QA — Consolidated Report"
echo -e "========================================${NC}"
echo ""

# Column widths
local_fmt="%-31s  %-8s  %4s  %4s  %4s"
# shellcheck disable=SC2059
printf "${local_fmt}\n" "Suite" "Status" "PASS" "FAIL" "WARN"
printf '%s\n' "$(printf '─%.0s' {1..31})  $(printf '─%.0s' {1..8})  $(printf '─%.0s' {1..4})  $(printf '─%.0s' {1..4})  $(printf '─%.0s' {1..4})"

total_pass=0
total_fail_count=0
total_warn=0
overall_exit=0

for i in "${!SUITE_NAMES[@]}"; do
  name="${SUITE_NAMES[$i]}"
  exit_code="${SUITE_EXITS[$i]}"
  p="${SUITE_PASS[$i]}"
  f="${SUITE_FAIL[$i]}"
  w="${SUITE_WARN[$i]}"

  if [[ "$exit_code" -eq 0 ]]; then
    status_str="✅ PASS"
  else
    status_str="❌ FAIL"
    overall_exit=1
  fi

  # shellcheck disable=SC2059
  printf "${local_fmt}\n" "$name" "$status_str" "$p" "$f" "$w"

  # Accumulate numeric totals (skip "-" placeholders)
  [[ "$p" =~ ^[0-9]+$ ]] && total_pass=$((total_pass + p))
  [[ "$f" =~ ^[0-9]+$ ]] && total_fail_count=$((total_fail_count + f))
  [[ "$w" =~ ^[0-9]+$ ]] && total_warn=$((total_warn + w))
done

printf '%s\n' "$(printf '─%.0s' {1..31})  $(printf '─%.0s' {1..8})  $(printf '─%.0s' {1..4})  $(printf '─%.0s' {1..4})  $(printf '─%.0s' {1..4})"
# shellcheck disable=SC2059
printf "${local_fmt}\n" "TOTAL" "" "$total_pass" "$total_fail_count" "$total_warn"

# ── AC-TBQA-002: WARN taxonomy ───────────────────────────────────────────────
echo ""
echo "WARN Taxonomy (non-blocking):"
echo "  - blocked-by-design: Feature requires live cluster or external service"
echo "  - aspirational:      Documented but not yet implemented"
echo "  - config-drift:      Minor config difference, not a regression"

# ── AC-TBQA-003: quick-fail rule ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}========================================"
if [[ "$overall_exit" -eq 0 ]]; then
  echo -e "${GREEN}RESULT: ALL SUITES PASSED${NC}"
  if [[ "$total_warn" -gt 0 ]]; then
    echo -e "${YELLOW}  ($total_warn WARN(s) — non-blocking, see taxonomy above)${NC}"
  fi
else
  echo -e "${RED}RESULT: ONE OR MORE SUITES FAILED${NC}"
  echo ""
  echo "Failed suites:"
  for i in "${!SUITE_NAMES[@]}"; do
    if [[ "${SUITE_EXITS[$i]}" -ne 0 ]]; then
      echo "  - ${SUITE_NAMES[$i]}"
    fi
  done
fi
echo -e "${BOLD}========================================${NC}"

exit "$overall_exit"
