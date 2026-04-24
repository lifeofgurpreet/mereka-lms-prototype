#!/usr/bin/env bash
# verify-ci-scope-contract.sh — Verify CI scope contract integrity
#
# Ensures that:
# 1. config/ci-scope-contract.yaml exists and is valid YAML
# 2. schema_version present
# 3. Each scope has: id, trigger_globs, required_workflows
# 4. At least 3 scopes defined
# 5. "docs-only" scope exists
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

echo "=== CI Scope Contract Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

CONTRACT_FILE="config/ci-scope-contract.yaml"

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
# 3. Each scope has required fields
# ---------------------------------------------------------------------------
echo "--- Check 3: Scope entries have required fields ---"
scope_check=$(python3 -c "
import yaml, sys

with open('$CONTRACT_FILE') as f:
    data = yaml.safe_load(f)

scopes = data.get('scopes', [])
required = ['id', 'trigger_globs', 'required_workflows']

for s in scopes:
    sid = s.get('id', 'unknown')
    for r in required:
        if r not in s:
            print(f'MISSING:{sid}:{r}')

print(f'COUNT:{len(scopes)}')

# Check for specific required scope
ids = [s.get('id', '') for s in scopes]
if 'docs-only' in ids:
    print('DOCS_ONLY:FOUND')
else:
    print('DOCS_ONLY:NOT_FOUND')
" 2>/dev/null)

missing_fields=$(echo "$scope_check" | grep "^MISSING:" || true)
if [[ -z "$missing_fields" ]]; then
  pass "All scopes have required fields (id, trigger_globs, required_workflows)"
else
  while IFS= read -r line; do
    parts="${line#MISSING:}"
    scope_id="${parts%%:*}"
    field_name="${parts#*:}"
    fail "Scope '$scope_id' missing required field '$field_name'"
  done <<< "$missing_fields"
fi

# ---------------------------------------------------------------------------
# 4. At least 3 scopes defined
# ---------------------------------------------------------------------------
echo "--- Check 4: Minimum scope count ---"
scope_count=$(echo "$scope_check" | grep "^COUNT:" | head -1 | cut -d: -f2)
if [[ "${scope_count:-0}" -ge 3 ]]; then
  pass "Scope count ($scope_count) >= 3"
else
  fail "Scope count (${scope_count:-0}) < 3 minimum"
fi

# ---------------------------------------------------------------------------
# 5. "docs-only" scope exists
# ---------------------------------------------------------------------------
echo "--- Check 5: docs-only scope exists ---"
docs_only=$(echo "$scope_check" | grep "^DOCS_ONLY:" | head -1 | cut -d: -f2)
if [[ "$docs_only" == "FOUND" ]]; then
  pass "Scope 'docs-only' exists"
else
  fail "Scope 'docs-only' is missing"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "CI scope contract violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All CI scope contract checks pass."
exit 0
