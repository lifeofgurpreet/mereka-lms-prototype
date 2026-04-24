#!/usr/bin/env bash
set -euo pipefail

# verify-admin-merge-exceptions.sh — Verify admin merge exception ledger integrity
#
# Checks:
#   1. Ledger file exists and is valid YAML
#   2. Policy declaration is present
#   3. Every exception entry uses the canonical machine-readable schema
#   4. Duplicate PR or commit entries are rejected
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

# 2. Policy field present
echo "--- Check 2: Policy declaration ---"
if grep -q 'rule:.*[Aa]dmin merge' "$LEDGER"; then
  pass "Policy declaration present"
else
  fail "Policy declaration missing or unclear"
fi

# 3. Every exception uses the canonical machine-readable schema
echo "--- Check 3: Exception entry completeness ---"
entry_check=$(python3 -c "
import yaml
import re
with open('$LEDGER') as f:
    data = yaml.safe_load(f)
exceptions = data.get('exceptions', []) or []
if not exceptions:
    print('EMPTY')
else:
    required = ['date', 'pr', 'commit', 'bypassed_checks', 'justification', 'follow_up', 'logged_by']
    seen_prs = set()
    seen_commits = set()
    for i, e in enumerate(exceptions):
        for r in required:
            if r not in e or not e[r]:
                print(f'MISSING:{i}:{r}')
        bypassed = e.get('bypassed_checks')
        if bypassed is not None and (not isinstance(bypassed, list) or not bypassed):
            print(f'INVALID:{i}:bypassed_checks')
        date = str(e.get('date', ''))
        if date and not re.fullmatch(r'\d{4}-\d{2}-\d{2}', date):
            print(f'INVALID:{i}:date')
        pr = str(e.get('pr', ''))
        if pr and pr != 'direct push to main (no PR)' and not re.fullmatch(r'https://github\.com/[^/]+/[^/]+/pull/\d+', pr):
            print(f'INVALID:{i}:pr')
        commit = str(e.get('commit', ''))
        if commit and commit != 'see squash merge' and not re.fullmatch(r'[0-9a-f]{7,40}', commit):
            print(f'INVALID:{i}:commit')
        if pr:
            if pr in seen_prs:
                print(f'DUPLICATE:{i}:pr')
            seen_prs.add(pr)
        if commit and commit != 'see squash merge':
            if commit in seen_commits:
                print(f'DUPLICATE:{i}:commit')
            seen_commits.add(commit)
    print(f'COUNT:{len(exceptions)}')
" 2>/dev/null || echo "ERROR")

if grep -q "^EMPTY$" <<<"$entry_check"; then
  pass "No exceptions logged (clean record)"
elif grep -q "^MISSING:" <<<"$entry_check"; then
  while IFS= read -r line; do
    fail "Exception entry $line"
  done <<< "$(echo "$entry_check" | grep "^MISSING:")"
elif grep -qE "^(INVALID|DUPLICATE):" <<<"$entry_check"; then
  while IFS= read -r line; do
    fail "Exception entry $line"
  done <<< "$(echo "$entry_check" | grep -E "^(INVALID|DUPLICATE):")"
else
  count=$(echo "$entry_check" | grep "^COUNT:" | cut -d: -f2)
  pass "All $count exception entries use the canonical schema"
fi

echo ""
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"
if [[ "$failures" -gt 0 ]]; then
  echo "Admin merge exception violations detected."
  exit 1
fi
echo "All admin merge exception checks pass."
