#!/usr/bin/env bash
# verify-generated-surface-lineage.sh — Verify generated surface lineage contract
#
# Ensures that:
# 1. config/generated-surface-lineage.yaml exists and is valid YAML
# 2. schema_version field is present
# 3. Each surface entry has: id, source_files, generator, generated_output, forbidden_direct_edits
# 4. At least 4 surfaces defined
# 5. Spot check: if .github/ci-scripts-static.txt exists, a lineage entry references it
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

echo "=== Generated Surface Lineage Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

LINEAGE_FILE="config/generated-surface-lineage.yaml"

# ---------------------------------------------------------------------------
# 1. Lineage file exists and is valid YAML
# ---------------------------------------------------------------------------
echo "--- Check 1: Lineage file exists and is valid YAML ---"
if [[ ! -f "$LINEAGE_FILE" ]]; then
  fail "$LINEAGE_FILE does not exist"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi
pass "$LINEAGE_FILE exists"

if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$LINEAGE_FILE" 2>/dev/null; then
  pass "$LINEAGE_FILE is valid YAML"
else
  fail "$LINEAGE_FILE is not valid YAML"
  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. schema_version field present
# ---------------------------------------------------------------------------
echo "--- Check 2: schema_version present ---"
if grep -q 'schema_version:' "$LINEAGE_FILE"; then
  pass "Lineage file has schema_version"
else
  fail "Lineage file missing schema_version"
fi

# ---------------------------------------------------------------------------
# 3. Each surface has required fields
# ---------------------------------------------------------------------------
echo "--- Check 3: Surface entries have required fields ---"
field_check=$(python3 -c "
import yaml, sys

with open('$LINEAGE_FILE') as f:
    data = yaml.safe_load(f)

surfaces = data.get('surfaces', [])
required = ['id', 'source_files', 'generator', 'generated_output', 'forbidden_direct_edits']

for s in surfaces:
    sid = s.get('id', 'unknown')
    for r in required:
        if r not in s:
            print(f'MISSING:{sid}:{r}')

print(f'COUNT:{len(surfaces)}')
" 2>/dev/null)

missing_fields=$(echo "$field_check" | grep "^MISSING:" || true)
if [[ -z "$missing_fields" ]]; then
  pass "All surfaces have required fields (id, source_files, generator, generated_output, forbidden_direct_edits)"
else
  while IFS= read -r line; do
    parts="${line#MISSING:}"
    surface_id="${parts%%:*}"
    field_name="${parts#*:}"
    fail "Surface '$surface_id' missing required field '$field_name'"
  done <<< "$missing_fields"
fi

# ---------------------------------------------------------------------------
# 4. At least 4 surfaces defined
# ---------------------------------------------------------------------------
echo "--- Check 4: Minimum surface count ---"
surface_count=$(echo "$field_check" | grep "^COUNT:" | head -1 | cut -d: -f2)
if [[ "${surface_count:-0}" -ge 4 ]]; then
  pass "Surface count ($surface_count) >= 4"
else
  fail "Surface count (${surface_count:-0}) < 4 minimum"
fi

# ---------------------------------------------------------------------------
# 5. Spot check: ci-scripts-static.txt lineage entry
# ---------------------------------------------------------------------------
echo "--- Check 5: Spot check ci-scripts-static.txt lineage ---"
CI_STATIC=".github/ci-scripts-static.txt"
if [[ -f "$CI_STATIC" ]]; then
  spot_check=$(python3 -c "
import yaml, sys

with open('$LINEAGE_FILE') as f:
    data = yaml.safe_load(f)

found = False
for s in data.get('surfaces', []):
    output = s.get('generated_output', '')
    if isinstance(output, list):
        for o in output:
            if '$CI_STATIC' in str(o):
                found = True
                break
    elif '$CI_STATIC' in str(output):
        found = True
    if found:
        break

print('FOUND' if found else 'NOT_FOUND')
" 2>/dev/null)

  if [[ "$spot_check" == "FOUND" ]]; then
    pass "Lineage entry exists for $CI_STATIC"
  else
    fail "No lineage entry references $CI_STATIC as generated_output"
  fi
else
  pass "$CI_STATIC does not exist; spot check skipped"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Generated surface lineage violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All generated surface lineage checks pass."
exit 0
