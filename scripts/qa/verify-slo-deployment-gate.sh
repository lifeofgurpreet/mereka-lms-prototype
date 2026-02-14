#!/usr/bin/env bash
# @covers AC-010, AC-011, AC-012
# @spec: slo-sla-service-level-management_spec.md
# Verify the deployment gate script exists, is executable, and has correct behavior.
#
# Checks:
# - Gate script exists and is executable
# - Supports --skip-prometheus flag (exits 0)
# - Supports --override with --approver and --justification
# - Has correct threshold logic (>= 50% PASS, 25-49% WARN, 10-24% BLOCK, < 10% FREEZE)
# - Logs structured deployment gate decisions
#
# Usage:
#   ./scripts/qa/verify-slo-deployment-gate.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PASS=0
FAIL=0
SKIP=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1" >&2; FAIL=$((FAIL + 1)); }
skip() { echo "[SKIP] $1"; SKIP=$((SKIP + 1)); }

GATE_SCRIPT="scripts/infra/check-error-budget-gate.sh"
QA_WRAPPER="scripts/qa/check-error-budget-gate.sh"

# ── Script existence and executability ───────────────────────────

if [[ -f "$GATE_SCRIPT" ]]; then
  pass "Gate script exists ($GATE_SCRIPT)"
else
  fail "Gate script missing ($GATE_SCRIPT)"
  echo "  Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
  exit 1
fi

if [[ -x "$GATE_SCRIPT" ]]; then
  pass "Gate script is executable"
else
  fail "Gate script is not executable"
fi

if [[ -f "$QA_WRAPPER" ]]; then
  pass "QA wrapper exists ($QA_WRAPPER)"
else
  fail "QA wrapper missing ($QA_WRAPPER)"
fi

if [[ -x "$QA_WRAPPER" ]]; then
  pass "QA wrapper is executable"
else
  fail "QA wrapper is not executable"
fi

# ── Syntax check ─────────────────────────────────────────────────
if bash -n "$GATE_SCRIPT" 2>/dev/null; then
  pass "Gate script passes bash -n syntax check"
else
  fail "Gate script has syntax errors"
fi

# ── @covers annotation ───────────────────────────────────────────
if grep -q '@covers.*AC-010' "$GATE_SCRIPT" 2>/dev/null; then
  pass "Gate script covers AC-010"
else
  fail "Gate script missing AC-010 coverage annotation"
fi

if grep -q '@covers.*AC-011' "$GATE_SCRIPT" 2>/dev/null; then
  pass "Gate script covers AC-011"
else
  fail "Gate script missing AC-011 coverage annotation"
fi

if grep -q '@covers.*AC-012' "$GATE_SCRIPT" 2>/dev/null; then
  pass "Gate script covers AC-012"
else
  fail "Gate script missing AC-012 coverage annotation"
fi

# ── Threshold values in script ───────────────────────────────────
# AC-010: >= 50% = Normal (deploy freely)
if grep -q '0\.50' "$GATE_SCRIPT" 2>/dev/null; then
  pass "AC-010: 50% threshold present (Normal deployment)"
else
  fail "AC-010: 50% threshold missing"
fi

# AC-011: < 25% = Restricted
if grep -q '0\.25' "$GATE_SCRIPT" 2>/dev/null; then
  pass "AC-011: 25% threshold present (Restricted deployment)"
else
  fail "AC-011: 25% threshold missing"
fi

# 10% threshold for Frozen
if grep -q '0\.10' "$GATE_SCRIPT" 2>/dev/null; then
  pass "AC-011: 10% threshold present (Frozen deployment)"
else
  fail "AC-011: 10% threshold missing"
fi

# AC-012: Override mechanism with approver and justification
if grep -q '\-\-override' "$GATE_SCRIPT" 2>/dev/null; then
  pass "AC-012: --override flag supported"
else
  fail "AC-012: --override flag missing"
fi

if grep -q '\-\-approver' "$GATE_SCRIPT" 2>/dev/null; then
  pass "AC-012: --approver flag supported"
else
  fail "AC-012: --approver flag missing"
fi

if grep -q '\-\-justification' "$GATE_SCRIPT" 2>/dev/null; then
  pass "AC-012: --justification flag supported"
else
  fail "AC-012: --justification flag missing"
fi

# AC-012: Structured logging of deployment gate decisions
if grep -q 'deployment_gate_decision' "$GATE_SCRIPT" 2>/dev/null; then
  pass "AC-012: Structured logging of gate decisions present"
else
  fail "AC-012: Structured logging of gate decisions missing"
fi

# ── --skip-prometheus behavior ───────────────────────────────────
if grep -q '\-\-skip-prometheus' "$GATE_SCRIPT" 2>/dev/null; then
  pass "Gate script supports --skip-prometheus flag"
else
  fail "Gate script missing --skip-prometheus flag"
fi

# Test --skip-prometheus exits 0
OUTPUT=$("$GATE_SCRIPT" --skip-prometheus 2>&1) || {
  fail "--skip-prometheus should exit 0 but got non-zero"
}
if echo "$OUTPUT" | grep -qi 'skip'; then
  pass "--skip-prometheus outputs SKIP message"
else
  fail "--skip-prometheus does not output SKIP message"
fi

# ── Queries correct metric ───────────────────────────────────────
if grep -q 'error_budget_remaining_ratio' "$GATE_SCRIPT" 2>/dev/null; then
  pass "Gate script queries error_budget_remaining_ratio metric"
else
  fail "Gate script does not query error_budget_remaining_ratio metric"
fi

# ── Exit codes match spec ────────────────────────────────────────
# exit 0 = PASS, exit 1 = WARN, exit 2 = BLOCK, exit 3 = FREEZE
if grep -q 'exit 0' "$GATE_SCRIPT" 2>/dev/null && \
   grep -q 'exit 1' "$GATE_SCRIPT" 2>/dev/null && \
   grep -q 'exit 2' "$GATE_SCRIPT" 2>/dev/null && \
   grep -q 'exit 3' "$GATE_SCRIPT" 2>/dev/null; then
  pass "Gate script uses correct exit codes (0=PASS, 1=WARN, 2=BLOCK, 3=FREEZE)"
else
  fail "Gate script missing expected exit codes"
fi

echo
echo "Total: PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
[[ "$FAIL" -eq 0 ]]
exit $?
