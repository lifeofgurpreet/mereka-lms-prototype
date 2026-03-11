#!/usr/bin/env bash
# Verify git worktree health for multi-agent parallel workflows.
# Checks:
#   - Each registered worktree path exists on disk
#   - No worktree is on main branch (warn only, not fatal)
#   - No two worktrees share the same branch (fatal)
#
# Usage:
#   scripts/qa/verify-worktree-sanity.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PASS=0
FAIL=0
WARN=0

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

warn() {
  echo -e "${YELLOW}WARN${NC}  $1"
  WARN=$((WARN + 1))
}

echo "=== Worktree Sanity Verification ==="
echo "Repository: ${REPO_ROOT}"
echo ""

if ! git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
  echo -e "${RED}FAIL${NC}  Not a git repository: ${REPO_ROOT}"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse worktree list
# Each stanza from `git worktree list --porcelain`:
#   worktree <path>
#   HEAD <sha>
#   branch refs/heads/<name>   (or "detached")
# Stanzas are blank-line separated.
# ---------------------------------------------------------------------------
WORKTREE_RAW="$(git -C "${REPO_ROOT}" worktree list --porcelain)"

declare -a WT_PATHS=()
declare -a WT_BRANCHES=()

current_path=""
current_branch=""

while IFS= read -r line; do
  if [[ "${line}" == worktree\ * ]]; then
    # Start of new stanza — save previous if populated
    if [[ -n "${current_path}" ]]; then
      WT_PATHS+=("${current_path}")
      WT_BRANCHES+=("${current_branch}")
    fi
    current_path="${line#worktree }"
    current_branch=""
  elif [[ "${line}" == branch\ refs/heads/* ]]; then
    current_branch="${line#branch refs/heads/}"
  elif [[ "${line}" == detached ]]; then
    current_branch="(detached)"
  fi
done <<< "${WORKTREE_RAW}"

# Capture the last stanza
if [[ -n "${current_path}" ]]; then
  WT_PATHS+=("${current_path}")
  WT_BRANCHES+=("${current_branch}")
fi

WORKTREE_COUNT="${#WT_PATHS[@]}"

echo "Found ${WORKTREE_COUNT} worktree(s)."
echo ""

# ---------------------------------------------------------------------------
# Print summary table header
# ---------------------------------------------------------------------------
printf "%-55s %-30s %s\n" "PATH" "BRANCH" "STATUS"
printf "%-55s %-30s %s\n" "$(printf '%0.s-' {1..55})" "$(printf '%0.s-' {1..30})" "------"

declare -A BRANCH_SEEN=()

for i in "${!WT_PATHS[@]}"; do
  wt_path="${WT_PATHS[$i]}"
  wt_branch="${WT_BRANCHES[$i]}"
  row_status=""

  if [[ -d "${wt_path}" ]]; then
    row_status="${GREEN}OK${NC}"
  else
    row_status="${RED}MISSING${NC}"
  fi

  printf "%-55s %-30s " "${wt_path}" "${wt_branch}"
  echo -e "${row_status}"
done

echo ""

# ---------------------------------------------------------------------------
# Check 1: Each path exists on disk
# ---------------------------------------------------------------------------
echo "--- Path existence ---"
for i in "${!WT_PATHS[@]}"; do
  wt_path="${WT_PATHS[$i]}"
  wt_branch="${WT_BRANCHES[$i]}"
  if [[ -d "${wt_path}" ]]; then
    pass "Worktree path exists: ${wt_path} (branch: ${wt_branch})"
  else
    fail "Worktree path does not exist on disk: ${wt_path} (branch: ${wt_branch})"
  fi
done

# ---------------------------------------------------------------------------
# Check 2: No worktree on main (warn only)
# ---------------------------------------------------------------------------
echo ""
echo "--- Main branch usage (warn only) ---"
MAIN_COUNT=0
for i in "${!WT_PATHS[@]}"; do
  wt_branch="${WT_BRANCHES[$i]}"
  wt_path="${WT_PATHS[$i]}"
  if [[ "${wt_branch}" == "main" ]]; then
    MAIN_COUNT=$((MAIN_COUNT + 1))
    warn "Worktree on main branch: ${wt_path}"
  fi
done
if [[ "${MAIN_COUNT}" -eq 0 ]]; then
  pass "No worktree is checked out on main"
fi

# ---------------------------------------------------------------------------
# Check 3: No two worktrees share the same branch
# ---------------------------------------------------------------------------
echo ""
echo "--- Branch uniqueness ---"
declare -A BRANCH_FIRST_PATH=()
DUPLICATE_FOUND=0

for i in "${!WT_PATHS[@]}"; do
  wt_branch="${WT_BRANCHES[$i]}"
  wt_path="${WT_PATHS[$i]}"

  # Skip detached HEADs — they can share "(detached)" label
  if [[ "${wt_branch}" == "(detached)" ]]; then
    continue
  fi

  if [[ -n "${BRANCH_FIRST_PATH[${wt_branch}]+isset}" ]]; then
    fail "Branch '${wt_branch}' used by multiple worktrees:"
    echo "        First:    ${BRANCH_FIRST_PATH[${wt_branch}]}"
    echo "        Duplicate: ${wt_path}"
    DUPLICATE_FOUND=1
  else
    BRANCH_FIRST_PATH["${wt_branch}"]="${wt_path}"
  fi
done

if [[ "${DUPLICATE_FOUND}" -eq 0 ]]; then
  pass "All worktrees are on unique branches"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Summary ==="
echo "Worktrees scanned: ${WORKTREE_COUNT}"
echo -e "Passed:  ${GREEN}${PASS}${NC}"
echo -e "Warnings: ${YELLOW}${WARN}${NC}"
echo -e "Failed:  ${RED}${FAIL}${NC}"
echo ""

if [[ ${FAIL} -eq 0 ]]; then
  echo -e "${GREEN}Worktree sanity checks passed.${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} check(s) failed.${NC}"
  exit 1
fi
