#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
#
# verify-ci-script-list.sh - Validate ci-scripts-static.txt integrity
#
# Ensures:
#   1. Every script listed actually exists on disk
#   2. No duplicate entries
#   3. Every script is executable
#   4. No scripts in scripts/qa/verify-*.sh are missing from the list

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0

do_pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
do_fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
do_warn() { echo -e "${YELLOW}WARN${NC} $1"; WARNED=$((WARNED + 1)); }

LIST_FILE="$REPO_ROOT/.github/ci-scripts-static.txt"

echo "=== CI Script List Validation ==="
echo

if [[ ! -f "$LIST_FILE" ]]; then
  do_fail "ci-scripts-static.txt not found at $LIST_FILE"
  exit 1
fi

# --- Check 1: Dead entries (scripts that don't exist) ---
echo "--- Check 1: Dead entries ---"
dead_count=0
while IFS= read -r entry; do
  # Strip inline comments and whitespace
  clean="${entry%% #*}"
  clean="${clean#"${clean%%[![:space:]]*}"}"
  clean="${clean%"${clean##*[![:space:]]}"}"
  [[ -z "$clean" ]] && continue

  script_path=$(echo "$clean" | awk '{print $1}')
  if [[ ! -f "$REPO_ROOT/$script_path" ]]; then
    do_fail "Dead entry: $script_path (file does not exist)"
    dead_count=$((dead_count + 1))
  fi
done < <(grep -v '^\s*$' "$LIST_FILE" | grep -v '^\s*#')

if [[ $dead_count -eq 0 ]]; then
  do_pass "No dead entries"
fi

# --- Check 2: Duplicate entries ---
echo "--- Check 2: Duplicates ---"
dupes=$(grep -v '^\s*$' "$LIST_FILE" | grep -v '^\s*#' | awk '{print $1}' | sort | uniq -d)
if [[ -n "$dupes" ]]; then
  while IFS= read -r dup; do
    do_fail "Duplicate entry: $dup"
  done <<< "$dupes"
else
  do_pass "No duplicate entries"
fi

# --- Check 3: Scripts are executable ---
echo "--- Check 3: Executable ---"
non_exec=0
while IFS= read -r entry; do
  clean="${entry%% #*}"
  clean="${clean#"${clean%%[![:space:]]*}"}"
  clean="${clean%"${clean##*[![:space:]]}"}"
  [[ -z "$clean" ]] && continue

  script_path=$(echo "$clean" | awk '{print $1}')
  full_path="$REPO_ROOT/$script_path"
  if [[ -f "$full_path" && ! -x "$full_path" ]]; then
    do_warn "Not executable: $script_path"
    non_exec=$((non_exec + 1))
  fi
done < <(grep -v '^\s*$' "$LIST_FILE" | grep -v '^\s*#')

if [[ $non_exec -eq 0 ]]; then
  do_pass "All scripts are executable"
fi

# --- Check 4: Missing verify-*.sh scripts ---
echo "--- Check 4: Missing scripts ---"
listed_scripts=$(grep -v '^\s*$' "$LIST_FILE" | grep -v '^\s*#' | awk '{print $1}' | sort)
missing=0

# Check scripts/qa/verify-*.sh that are NOT in the list
# Exclude scripts that are intentionally not in CI (need cluster, need auth, etc.)
SKIP_PATTERNS="verify-public-branding|verify-authenticated|verify-image-freshness"

while IFS= read -r script; do
  rel_path="${script#$REPO_ROOT/}"
  if ! echo "$listed_scripts" | grep -qF "$rel_path"; then
    basename_script=$(basename "$script")
    if echo "$basename_script" | grep -qE "$SKIP_PATTERNS"; then
      continue  # Intentionally excluded
    fi
    do_warn "Not in CI: $rel_path"
    missing=$((missing + 1))
  fi
done < <(find "$REPO_ROOT/scripts/qa" -maxdepth 1 -name "verify-*.sh" -type f | sort)

if [[ $missing -eq 0 ]]; then
  do_pass "All verify-*.sh scripts are in CI list"
fi

# --- Summary ---
total_scripts=$(grep -v '^\s*$' "$LIST_FILE" | grep -v '^\s*#' | wc -l)
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASSED | ${RED}FAIL:${NC} $FAILED | ${YELLOW}WARN:${NC} $WARNED"
echo "Total scripts in list: $total_scripts"
echo

if [[ $FAILED -gt 0 ]]; then
  echo "CI script list has integrity issues. Fix before merging."
  exit 1
fi

echo "CI script list is valid."
exit 0
