#!/usr/bin/env bash
# verify-proof-gate-contract.sh — Verify proof gate contract integrity
#
# Ensures that:
# 1. config/proof-gate-contract.yaml exists and is valid YAML
# 2. schema_version present
# 3. Each gate has: id, predecessor, successor, required_state
# 4. At least 3 gates defined
# 5. Gate "live-asset-before-canary" exists
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); echo -e "  ${GREEN}PASS${NC}: $1"; }
fail() { FAILED=$((FAILED + 1)); echo -e "  ${RED}FAIL${NC}: $1" >&2; }

echo "=== Proof Gate Contract Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

CONTRACT_FILE="config/proof-gate-contract.yaml"

# ---------------------------------------------------------------------------
# 1. Contract file exists and is valid YAML
# ---------------------------------------------------------------------------
echo "--- Check 1: Contract file exists and is valid YAML ---"
if [[ ! -f "$CONTRACT_FILE" ]]; then
  fail "$CONTRACT_FILE does not exist"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi
pass "$CONTRACT_FILE exists"

if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$CONTRACT_FILE" 2>/dev/null; then
  pass "$CONTRACT_FILE is valid YAML"
else
  fail "$CONTRACT_FILE is not valid YAML"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. schema_version present
# ---------------------------------------------------------------------------
echo "--- Check 2: schema_version present ---"
if grep -q 'schema_version:' "$CONTRACT_FILE"; then
  pass "Contract has schema_version"
else
  fail "Contract missing schema_version"
fi

# ---------------------------------------------------------------------------
# 3. Each gate has required fields
# ---------------------------------------------------------------------------
echo "--- Check 3: Gate entries have required fields ---"
gate_check=$(python3 -c "
import yaml, sys

with open('$CONTRACT_FILE') as f:
    data = yaml.safe_load(f)

gates = data.get('gates', [])
required = ['id', 'predecessor', 'successor', 'required_state']

for g in gates:
    gid = g.get('id', 'unknown')
    for r in required:
        if r not in g:
            print(f'MISSING:{gid}:{r}')

print(f'COUNT:{len(gates)}')

# Check for specific critical gate
ids = [g.get('id', '') for g in gates]
if 'live-asset-before-canary' in ids:
    print('CRITICAL_GATE:FOUND')
else:
    print('CRITICAL_GATE:NOT_FOUND')
" 2>/dev/null)

missing_fields=$(echo "$gate_check" | grep "^MISSING:" || true)
if [[ -z "$missing_fields" ]]; then
  pass "All gates have required fields (id, predecessor, successor, required_state)"
else
  while IFS= read -r line; do
    parts="${line#MISSING:}"
    gate_id="${parts%%:*}"
    field_name="${parts#*:}"
    fail "Gate '$gate_id' missing required field '$field_name'"
  done <<< "$missing_fields"
fi

# ---------------------------------------------------------------------------
# 4. At least 3 gates defined
# ---------------------------------------------------------------------------
echo "--- Check 4: Minimum gate count ---"
gate_count=$(echo "$gate_check" | grep "^COUNT:" | head -1 | cut -d: -f2)
if [[ "${gate_count:-0}" -ge 3 ]]; then
  pass "Gate count ($gate_count) >= 3"
else
  fail "Gate count (${gate_count:-0}) < 3 minimum"
fi

# ---------------------------------------------------------------------------
# 5. Critical gate "live-asset-before-canary" exists
# ---------------------------------------------------------------------------
echo "--- Check 5: Critical gate exists ---"
critical_gate=$(echo "$gate_check" | grep "^CRITICAL_GATE:" | head -1 | cut -d: -f2)
if [[ "$critical_gate" == "FOUND" ]]; then
  pass "Gate 'live-asset-before-canary' exists"
else
  fail "Gate 'live-asset-before-canary' is missing (most critical gate)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Proof gate contract violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All proof gate contract checks pass."
exit 0
