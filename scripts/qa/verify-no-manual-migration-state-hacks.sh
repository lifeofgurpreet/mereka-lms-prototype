#!/usr/bin/env bash
# Enforce migration safety: operational scripts/workflows must not use manual migration-state hacks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

# Only enforce on executable/automation surfaces. Docs can discuss anti-patterns.
TARGETS=(
  "$REPO_ROOT/scripts"
  "$REPO_ROOT/.github/workflows"
)

# Patterns that bypass canonical migration flows and can corrupt state.
PATTERNS=(
  'migrate --fake'
  '--fake-initial'
  'TRUNCATE[[:space:]]+TABLE[[:space:]]+django_migrations'
  'DELETE[[:space:]]+FROM[[:space:]]+django_migrations'
  'UPDATE[[:space:]]+django_migrations'
  'INSERT[[:space:]]+INTO[[:space:]]+django_migrations'
)

echo "=== Manual Migration State Hack Guardrail ==="
echo

if [[ ! -d "$REPO_ROOT/scripts" ]]; then
  fail "scripts directory missing"
fi

if [[ ! -d "$REPO_ROOT/.github/workflows" ]]; then
  fail ".github/workflows directory missing"
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"
  exit 1
fi

matches=0
for pattern in "${PATTERNS[@]}"; do
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    fail "Forbidden migration-state pattern found: $line"
    matches=$((matches + 1))
  done < <(
    rg -n -i --no-messages --glob '!**/*.md' \
      --glob '!**/verify-no-manual-migration-state-hacks.sh' \
      -e "$pattern" -- "${TARGETS[@]}" || true
  )
done

if [[ "$matches" -eq 0 ]]; then
  pass "No forbidden manual migration-state patterns found in scripts/workflows"
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
