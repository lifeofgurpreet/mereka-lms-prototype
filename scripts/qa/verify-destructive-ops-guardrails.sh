#!/usr/bin/env bash
# Verify destructive infra script guardrails stay fail-closed.

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

require_pattern() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if grep -qE "$pattern" "$path"; then
    pass "$message"
  else
    fail "$message"
  fi
}

echo "=== Destructive Ops Guardrail Contract ==="
echo

mapfile -t destructive_scripts < <(rg -l 'RUN_DESTRUCTIVE' "$REPO_ROOT/scripts/infra"/*.sh 2>/dev/null | sort)
if [[ "${#destructive_scripts[@]}" -eq 0 ]]; then
  fail "No RUN_DESTRUCTIVE infra scripts discovered; guardrail coverage cannot be verified"
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"
  exit 1
fi

pass "Discovered ${#destructive_scripts[@]} destructive infra script(s)"

for path in "${destructive_scripts[@]}"; do
  rel="${path#${REPO_ROOT}/}"
  require_pattern "$path" 'set -euo pipefail' "${rel}: strict bash mode"
  require_pattern "$path" 'RUN_DESTRUCTIVE="\$\{RUN_DESTRUCTIVE:-0\}"' "${rel}: RUN_DESTRUCTIVE defaults to 0"
  require_pattern "$path" 'CONFIRM_' "${rel}: explicit confirm variable is present"
  require_pattern "$path" 'CONFIRM_TOKEN=' "${rel}: explicit confirm token is present"

  if grep -q 'velero backup create' "$path"; then
    pass "${rel}: pre-op Velero backup call present"
  elif grep -q 'SAFETY_EXEMPT_NO_BACKUP=1' "$path"; then
    pass "${rel}: backup exemption marker present"
  else
    fail "${rel}: missing backup policy anchor (velero backup create or SAFETY_EXEMPT_NO_BACKUP=1)"
  fi

done

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
