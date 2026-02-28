#!/usr/bin/env bash
# verify-wcag-contrast-v2.sh — WCAG contrast policy v2 contract verifier
# @covers AC-WCAG2-001, AC-WCAG2-002, AC-WCAG2-003
#
# Verifies:
# - Policy document exists with complete token pair audit
# - All 27 existing pairs documented
# - Layer discrepancy section present
# - Remediation plan documented
# - CI has accessibility/contrast gates
#
# Usage: ./scripts/qa/verify-wcag-contrast-v2.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
POLICY="$REPO_ROOT/docs/architecture/WCAG_CONTRAST_POLICY_V2.md"
ORIGINAL_VERIFIER="$REPO_ROOT/scripts/qa/verify-contrast-compliance.sh"
CI_CONFIG="$REPO_ROOT/.github/workflows/ci.yml"

PASS=0
FAIL=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }

echo "=== WCAG Contrast Policy v2 Contract Verification ==="
echo ""

# 1. Contract document exists
echo "--- Contract existence (AC-WCAG2-001) ---"
if [ ! -f "$POLICY" ]; then
  do_fail "WCAG_CONTRAST_POLICY_V2.md not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL ==="
  exit 1
fi
do_pass "WCAG_CONTRAST_POLICY_V2.md exists"

# 2. Original contrast verifier exists
if [ ! -f "$ORIGINAL_VERIFIER" ]; then
  do_fail "verify-contrast-compliance.sh not found"
else
  do_pass "verify-contrast-compliance.sh exists"
fi

# 3. Contract references WCAG 2.1 AA standard
echo ""
echo "--- WCAG 2.1 AA standard reference ---"
if grep -q "WCAG 2.1 Level AA\|WCAG 2.1 AA" "$POLICY"; then
  do_pass "Policy references WCAG 2.1 AA standard"
else
  do_fail "Policy missing WCAG 2.1 AA reference"
fi

# 4. Contract contains token pair audit table
echo ""
echo "--- Token pair audit table (AC-WCAG2-001) ---"
if grep -q "Complete Token Pair Audit" "$POLICY"; then
  do_pass "Token pair audit section present"
else
  do_fail "Missing token pair audit section"
fi

if grep -q "| Component | Foreground Token | Background Token" "$POLICY"; then
  do_pass "Token pair audit table structure present"
else
  do_fail "Missing token pair audit table structure"
fi

# 5. All 27 existing pairs documented (check for key color names)
echo ""
echo "--- Coverage of 27 existing pairs (AC-WCAG2-002) ---"

# Check for ink scale colors
if grep -q "ink-900" "$POLICY"; then
  do_pass "ink-900 pairs documented"
else
  do_fail "ink-900 pairs missing from audit"
fi

if grep -q "ink-700" "$POLICY"; then
  do_pass "ink-700 pairs documented"
else
  do_fail "ink-700 pairs missing from audit"
fi

if grep -q "ink-500" "$POLICY"; then
  do_pass "ink-500 pairs documented"
else
  do_fail "ink-500 pairs missing from audit"
fi

if grep -q "ink-300" "$POLICY"; then
  do_pass "ink-300 pairs documented"
else
  do_fail "ink-300 pairs missing from audit"
fi

# Check for brand colors
if grep -q "teal" "$POLICY"; then
  do_pass "teal pairs documented"
else
  do_fail "teal pairs missing from audit"
fi

if grep -q "magenta" "$POLICY"; then
  do_pass "magenta pairs documented"
else
  do_fail "magenta pairs missing from audit"
fi

if grep -q "blue" "$POLICY"; then
  do_pass "blue pairs documented"
else
  do_fail "blue pairs missing from audit"
fi

# Check for semantic colors
if grep -q "forest" "$POLICY"; then
  do_pass "forest pairs documented"
else
  do_fail "forest pairs missing from audit"
fi

if grep -q "burgundy" "$POLICY"; then
  do_pass "burgundy pairs documented"
else
  do_fail "burgundy pairs missing from audit"
fi

if grep -q "gold" "$POLICY"; then
  do_pass "gold pairs documented"
else
  do_fail "gold pairs missing from audit"
fi

if grep -q "sky" "$POLICY"; then
  do_pass "sky pairs documented"
else
  do_fail "sky pairs missing from audit"
fi

if grep -q "pink" "$POLICY"; then
  do_pass "pink pairs documented"
else
  do_fail "pink pairs missing from audit"
fi

# 6. Layer discrepancy section exists
echo ""
echo "--- Layer discrepancy tracking (AC-WCAG2-001) ---"
if grep -q "Layer Discrepancy\|Layer discrepancy" "$POLICY"; then
  do_pass "Layer discrepancy section present"
else
  do_fail "Layer discrepancy section missing"
fi

if grep -q "drift" "$POLICY"; then
  do_pass "Drift terminology documented"
else
  do_fail "Drift terminology missing"
fi

# 7. Unified color values documented (drift resolved 2026-02-25)
echo ""
echo "--- Unified color values documented (drift resolved) ---"
if grep -q "#237072\|#237072" "$POLICY"; then
  do_pass "Teal unified value #237072 documented"
else
  do_fail "Teal unified value #237072 not documented in policy"
fi

if grep -q "#6B6B6B\|#6b6b6b" "$POLICY"; then
  do_pass "ink-500 unified value #6B6B6B documented"
else
  do_fail "ink-500 unified value #6B6B6B not documented in policy"
fi

# 8. Remediation plan section exists
echo ""
echo "--- Remediation plan (AC-WCAG2-001) ---"
if grep -q "Remediation Plan\|remediation plan" "$POLICY"; then
  do_pass "Remediation plan section present"
else
  do_fail "Remediation plan section missing"
fi

# 9. Link to ACCESSIBILITY_CONFORMANCE_POLICY.md
echo ""
echo "--- Cross-references ---"
if grep -q "ACCESSIBILITY_CONFORMANCE_POLICY" "$POLICY"; then
  do_pass "Link to ACCESSIBILITY_CONFORMANCE_POLICY.md present"
else
  do_fail "Link to ACCESSIBILITY_CONFORMANCE_POLICY.md missing"
fi

# 10. Link to verify-contrast-compliance.sh
if grep -q "verify-contrast-compliance" "$POLICY"; then
  do_pass "Link to verify-contrast-compliance.sh present"
else
  do_fail "Link to verify-contrast-compliance.sh missing"
fi

# 11. Non-text contrast (3.0:1 UI elements) mentioned
echo ""
echo "--- Non-text contrast coverage ---"
if grep -q "UI component\|Non-text\|non-text" "$POLICY"; then
  do_pass "Non-text contrast (3.0:1 UI elements) mentioned"
else
  do_fail "Non-text contrast not mentioned"
fi

# 12. Total coverage count documented
echo ""
echo "--- Coverage metrics ---"
if grep -q "27 token pairs\|27 pairs" "$POLICY"; then
  do_pass "Total 27 token pairs documented"
else
  do_fail "Total pair count not documented"
fi

# 13. CI has accessibility/contrast verification jobs
echo ""
echo "--- CI gate enforcement (AC-WCAG2-003) ---"
if [ ! -f "$CI_CONFIG" ]; then
  do_fail "CI config file not found"
else
  if grep -q "verify-contrast-compliance\|verify-wcag-contrast" "$CI_CONFIG"; then
    do_pass "CI has contrast verification jobs"
  else
    do_fail "CI missing contrast verification jobs"
  fi

  if grep -q "verify-accessibility-conformance\|accessibility" "$CI_CONFIG"; then
    do_pass "CI has accessibility conformance gate"
  else
    do_fail "CI missing accessibility conformance gate"
  fi
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
