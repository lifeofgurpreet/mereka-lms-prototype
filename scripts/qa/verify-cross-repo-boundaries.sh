#!/usr/bin/env bash
# verify-cross-repo-boundaries.sh — Verify cross-repo boundary contract
#
# Ensures that:
# 1. config/repo-boundary-contract.yaml exists and is valid YAML
# 2. schema_version present
# 3. At least 2 repos defined
# 4. Each repo has "owns" and "does_not_own" fields
# 5. Contract has transitional entries for production/rke2-nonprod overlay paths
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

echo "=== Cross-Repo Boundary Contract Verification ==="
echo "Repo root: ${REPO_ROOT}"
echo

CONTRACT_FILE="config/repo-boundary-contract.yaml"

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
# 3. At least 2 repos defined
# ---------------------------------------------------------------------------
echo "--- Check 3: Minimum repo count ---"
struct_check=$(python3 -c "
import yaml, sys

with open('$CONTRACT_FILE') as f:
    data = yaml.safe_load(f)

repos = data.get('repos', data.get('repositories', []))
print(f'COUNT:{len(repos)}')

for repo in repos:
    rid = repo.get('id', repo.get('name', 'unknown'))
    if 'owns' not in repo:
        print(f'MISSING_OWNS:{rid}')
    if 'does_not_own' not in repo:
        print(f'MISSING_DOES_NOT_OWN:{rid}')
" 2>/dev/null)

repo_count=$(echo "$struct_check" | grep "^COUNT:" | head -1 | cut -d: -f2)
if [[ "${repo_count:-0}" -ge 2 ]]; then
  pass "Repo count ($repo_count) >= 2"
else
  fail "Repo count (${repo_count:-0}) < 2 minimum"
fi

# ---------------------------------------------------------------------------
# 4. Each repo has "owns" and "does_not_own" fields
# ---------------------------------------------------------------------------
echo "--- Check 4: Each repo has owns and does_not_own ---"
missing_owns=$(echo "$struct_check" | grep "^MISSING_OWNS:" || true)
missing_dno=$(echo "$struct_check" | grep "^MISSING_DOES_NOT_OWN:" || true)

if [[ -z "$missing_owns" && -z "$missing_dno" ]]; then
  pass "All repos have 'owns' and 'does_not_own' fields"
else
  if [[ -n "$missing_owns" ]]; then
    while IFS= read -r line; do
      rid="${line#MISSING_OWNS:}"
      fail "Repo '$rid' missing 'owns' field"
    done <<< "$missing_owns"
  fi
  if [[ -n "$missing_dno" ]]; then
    while IFS= read -r line; do
      rid="${line#MISSING_DOES_NOT_OWN:}"
      fail "Repo '$rid' missing 'does_not_own' field"
    done <<< "$missing_dno"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Contract has transitional entries for production/rke2-nonprod overlay paths
# ---------------------------------------------------------------------------
echo "--- Check 5: Transitional entries for overlay paths ---"
transitional_check=$(python3 -c "
import yaml, sys, json

with open('$CONTRACT_FILE') as f:
    data = yaml.safe_load(f)

# Flatten all text to search for transitional mentions of these paths
text = json.dumps(data)
paths_to_check = [
    'deploy/k8s/overlays/production',
    'deploy/k8s/overlays/rke2-nonprod',
]

found = []
missing = []
for path in paths_to_check:
    if path in text:
        found.append(path)
    else:
        missing.append(path)

for f in found:
    print(f'FOUND:{f}')
for m in missing:
    print(f'MISSING:{m}')
" 2>/dev/null)

found_paths=$(echo "$transitional_check" | grep "^FOUND:" || true)
missing_paths=$(echo "$transitional_check" | grep "^MISSING:" || true)

if [[ -n "$found_paths" ]]; then
  while IFS= read -r line; do
    path="${line#FOUND:}"
    pass "Transitional entry found for $path"
  done <<< "$found_paths"
fi

if [[ -n "$missing_paths" ]]; then
  while IFS= read -r line; do
    path="${line#MISSING:}"
    fail "No transitional entry for $path in boundary contract"
  done <<< "$missing_paths"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS${NC}: $PASSED | ${RED}FAIL${NC}: $FAILED"
echo

if [[ "$FAILED" -gt 0 ]]; then
  echo "Cross-repo boundary contract violations detected."
  echo "Fix ALL failures before merging."
  exit 1
fi

echo "All cross-repo boundary contract checks pass."
exit 0
