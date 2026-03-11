#!/usr/bin/env bash
# Verify the git working tree is clean before an agent makes mutations.
# Checks:
#   - No staged or unstaged modifications
#   - No untracked files (unless --allow-untracked is passed)
#
# Usage:
#   scripts/qa/verify-clean-tree-before-mutation.sh [--allow-untracked]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ALLOW_UNTRACKED=0
for arg in "$@"; do
  if [[ "${arg}" == "--allow-untracked" ]]; then
    ALLOW_UNTRACKED=1
  fi
done

PASS=0
FAIL=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAIL=$((FAIL + 1))
}

echo "=== Clean Tree Verification ==="
echo "Repository: ${REPO_ROOT}"
echo ""

if ! git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}  Not a git repository: ${REPO_ROOT}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Capture porcelain status (column 1-2 = XY status codes)
# ---------------------------------------------------------------------------
PORCELAIN="$(git -C "${REPO_ROOT}" status --porcelain)"

# Split into modified/staged vs untracked
MODIFIED_LINES=""
UNTRACKED_LINES=""

while IFS= read -r line; do
  [[ -z "${line}" ]] && continue
  xy="${line:0:2}"
  if [[ "${xy}" == "??" ]]; then
    UNTRACKED_LINES="${UNTRACKED_LINES}${line}"$'\n'
  else
    MODIFIED_LINES="${MODIFIED_LINES}${line}"$'\n'
  fi
done <<< "${PORCELAIN}"

# ---------------------------------------------------------------------------
# Check 1: No modified / staged files
# ---------------------------------------------------------------------------
echo "--- Modified or staged files ---"
if [[ -z "${MODIFIED_LINES}" ]]; then
  pass "No modified or staged files"
else
  fail "Working tree has modified or staged files:"
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    echo "        ${line}"
  done <<< "${MODIFIED_LINES}"
fi

# ---------------------------------------------------------------------------
# Check 2: No untracked files (conditional)
# ---------------------------------------------------------------------------
echo ""
echo "--- Untracked files ---"
if [[ -z "${UNTRACKED_LINES}" ]]; then
  pass "No untracked files"
elif [[ "${ALLOW_UNTRACKED}" -eq 1 ]]; then
  echo -e "      ${YELLOW}SKIP${NC}  Untracked files present (--allow-untracked passed):"
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    echo "        ${line}"
  done <<< "${UNTRACKED_LINES}"
  PASS=$((PASS + 1))
else
  fail "Untracked files present (pass --allow-untracked to skip this check):"
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    echo "        ${line}"
  done <<< "${UNTRACKED_LINES}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo -e "Passed: ${GREEN}${PASS}${NC}"
echo -e "Failed: ${RED}${FAIL}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}Working tree is clean. Safe to proceed with mutations.${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} check(s) failed — working tree is not clean.${NC}"
  exit 1
fi
