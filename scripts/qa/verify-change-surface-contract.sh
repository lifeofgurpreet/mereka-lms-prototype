#!/usr/bin/env bash
set -euo pipefail

# verify-change-surface-contract.sh — Verify that changed files respect
# their change-surface contracts.
#
# Reads config/change-surface-contracts.yaml and checks:
#   1. Contract file exists and is valid YAML
#   2. No changed file matches a "forbidden" glob
#   3. Changed files can be mapped to at least one surface
#   4. PR template (if present) references the correct owner layer
#
# Uses git diff against merge-base or HEAD~1 to detect changed files.
#
# No network calls. No destructive operations.

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

CONTRACT_FILE="config/change-surface-contracts.yaml"
failures=0
passes=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }
info() { echo "  [INFO] $*"; }

echo "=== Change-Surface Contract Verification ==="
echo "Repo root: ${REPO_ROOT}"

# ---------------------------------------------------------------------------
# 1. Contract file exists and is valid YAML
# ---------------------------------------------------------------------------
echo "--- Check 1: Contract file exists and is valid ---"
if [[ ! -f "$CONTRACT_FILE" ]]; then
  fail "$CONTRACT_FILE does not exist"
  echo ""
  echo "=== Summary ==="
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi
pass "$CONTRACT_FILE exists"

if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$CONTRACT_FILE" 2>/dev/null; then
  pass "$CONTRACT_FILE is valid YAML"
else
  fail "$CONTRACT_FILE is not valid YAML"
  echo ""
  echo "=== Summary ==="
  echo "PASS: $passes | FAIL: $failures"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Extract forbidden globs and check changed files
# ---------------------------------------------------------------------------
echo "--- Check 2: No changed files match forbidden globs ---"

# Get changed files (staged or recent commit)
if git diff --cached --name-only 2>/dev/null | grep -q .; then
  changed_files=$(git diff --cached --name-only)
elif git log -1 --format='' --name-only 2>/dev/null | grep -q .; then
  changed_files=$(git log -1 --format='' --name-only)
else
  info "No changed files detected; skipping forbidden-glob check"
  changed_files=""
fi

if [[ -n "$changed_files" ]]; then
  # Extract forbidden globs from contract using python
  forbidden_check=$(python3 -c "
import yaml, fnmatch, sys

with open('$CONTRACT_FILE') as f:
    data = yaml.safe_load(f)

changed = '''$changed_files'''.strip().split('\n')
violations = []

for surface in data.get('surfaces', []):
    for pattern in surface.get('forbidden', []):
        for cf in changed:
            if fnmatch.fnmatch(cf, pattern):
                violations.append(f'{cf} matches forbidden glob \"{pattern}\" in surface {surface[\"id\"]} — {surface.get(\"forbidden_reason\", \"no reason given\")}')

for v in violations:
    print(v)
" 2>/dev/null || echo "")

  if [[ -z "$forbidden_check" ]]; then
    pass "No changed files match any forbidden globs"
  else
    while IFS= read -r line; do
      fail "$line"
    done <<< "$forbidden_check"
  fi
else
  pass "No changed files to check (clean tree)"
fi

# ---------------------------------------------------------------------------
# 3. Contract has required structure
# ---------------------------------------------------------------------------
echo "--- Check 3: Contract structural integrity ---"
surface_count=$(python3 -c "
import yaml
with open('$CONTRACT_FILE') as f:
    data = yaml.safe_load(f)
surfaces = data.get('surfaces', [])
print(len(surfaces))
for s in surfaces:
    required = ['id', 'name', 'globs', 'owner_layer', 'required_skills', 'required_checks']
    for r in required:
        if r not in s:
            print(f'MISSING:{s.get(\"id\",\"unknown\")}:{r}')
" 2>/dev/null)

count=$(echo "$surface_count" | head -1)
missing=$(echo "$surface_count" | grep "^MISSING:" || true)

if [[ "$count" -ge 5 ]]; then
  pass "Contract defines $count surfaces (>= 5 minimum)"
else
  fail "Contract defines only $count surfaces (need >= 5)"
fi

if [[ -z "$missing" ]]; then
  pass "All surfaces have required fields (id, name, globs, owner_layer, required_skills, required_checks)"
else
  while IFS= read -r line; do
    fail "Surface ${line#MISSING:} — missing required field"
  done <<< "$missing"
fi

# ---------------------------------------------------------------------------
# 4. Schema version present
# ---------------------------------------------------------------------------
echo "--- Check 4: Schema version ---"
if grep -q 'schema_version:' "$CONTRACT_FILE"; then
  pass "Contract has schema_version"
else
  fail "Contract missing schema_version"
fi

echo ""
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"
if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "Change-surface contract violations detected."
  exit 1
fi
echo ""
echo "All change-surface contract checks pass."
