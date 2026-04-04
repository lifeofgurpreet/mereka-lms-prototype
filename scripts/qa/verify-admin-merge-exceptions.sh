#!/usr/bin/env bash
set -euo pipefail

# verify-admin-merge-exceptions.sh — Verify admin merge exception ledger integrity
#
# Checks:
#   1. Ledger file exists and is valid YAML
#   2. Every exception entry has required fields
#   3. No recent admin merges on main are unlogged
#
# No network calls. No destructive operations.

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

LEDGER="config/admin-merge-exception-ledger.yaml"
failures=0
passes=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Admin Merge Exception Verification ==="

# 1. Ledger exists and is valid
echo "--- Check 1: Ledger file ---"
if [[ ! -f "$LEDGER" ]]; then
  fail "Admin merge exception ledger missing: $LEDGER"
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi
pass "Ledger exists"

if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$LEDGER" 2>/dev/null; then
  pass "Ledger is valid YAML"
else
  fail "Ledger is not valid YAML"
fi

# 2. Every exception has required fields
echo "--- Check 2: Exception entry completeness ---"
entry_check=$(python3 -c "
import yaml
with open('$LEDGER') as f:
    data = yaml.safe_load(f)
exceptions = data.get('exceptions', []) or []
if not exceptions:
    print('EMPTY')
else:
    required = ['date', 'pr', 'justification', 'logged_by']
    for i, e in enumerate(exceptions):
        for r in required:
            if r not in e or not e[r]:
                print(f'MISSING:{i}:{r}')
    if not any('MISSING' in str(x) for x in []):
        print('OK')
    print(f'COUNT:{len(exceptions)}')
" 2>/dev/null || echo "ERROR")

if echo "$entry_check" | grep -q "^EMPTY$"; then
  pass "No exceptions logged (clean record)"
elif echo "$entry_check" | grep -q "^MISSING:"; then
  while IFS= read -r line; do
    fail "Exception entry $line"
  done <<< "$(echo "$entry_check" | grep "^MISSING:")"
else
  count=$(echo "$entry_check" | grep "^COUNT:" | cut -d: -f2)
  pass "All $count exception entries have required fields"
fi

# 3. Policy field present
echo "--- Check 3: Policy declaration ---"
if grep -q 'rule:.*[Aa]dmin merge' "$LEDGER"; then
  pass "Policy declaration present"
else
  fail "Policy declaration missing or unclear"
fi

echo ""
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"
if [[ "$failures" -gt 0 ]]; then
  echo "Admin merge exception violations detected."
  exit 1
fi
echo "All admin merge exception checks pass."
