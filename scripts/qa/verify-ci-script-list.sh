#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
#
# verify-ci-script-list.sh - Validate ci-scripts-static.txt integrity
#
# Ensures:
#   0. Generated output matches the authoritative registry
#   1. Every script listed actually exists on disk
#   2. No duplicate entries
#   3. Every script is executable
#   4. Release-blocking verify scripts remain CI-bound (static list or direct workflow)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_MODE="${VERIFY_CI_SCRIPT_LIST_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_CI_SCRIPT_LIST_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

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

should_skip_scope() {
  local changed_path

  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r changed_path; do
    [[ -n "$changed_path" ]] || continue
    case "$changed_path" in
      .github/ci-scripts-static.txt|\
      .github/workflows/*|\
      scripts/*|\
      verification/catalogs/verification_catalog.json|\
      scripts/governance/script-registry.yaml)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

LIST_FILE="$REPO_ROOT/.github/ci-scripts-static.txt"
CATALOG_JSON="$REPO_ROOT/verification/catalogs/verification_catalog.json"
GENERATOR="$REPO_ROOT/scripts/governance/generate-ci-static-inventory.py"

if should_skip_scope; then
  echo "PASS verify-ci-script-list (scope skip: no ci-script-inventory authority changes)"
  exit 0
fi

echo "=== CI Script List Validation ==="
echo

# --- Check 0: Generated output is current ---
echo "--- Check 0: Generated output is current ---"
if [[ ! -x "$GENERATOR" ]]; then
  do_fail "generator missing or not executable: $GENERATOR"
elif python3 "$GENERATOR" --check; then
  do_pass "ci-scripts-static.txt matches script-registry.yaml ci_static_inventory"
else
  do_fail "ci-scripts-static.txt is stale relative to script-registry.yaml ci_static_inventory"
fi

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

# --- Check 4: Release-blocking coverage is enforced ---
echo "--- Check 4: Release-blocking coverage ---"
coverage_fail=0
coverage_warn=0
coverage_pass=0

if [[ ! -f "$CATALOG_JSON" ]]; then
  do_warn "Verification catalog missing; cannot evaluate release-blocking script coverage"
else
  while IFS=$'\t' read -r level message; do
    [[ -z "${level:-}" ]] && continue
    case "$level" in
      FAIL)
        do_fail "$message"
        coverage_fail=$((coverage_fail + 1))
        ;;
      WARN)
        do_warn "$message"
        coverage_warn=$((coverage_warn + 1))
        ;;
      PASS)
        do_pass "$message"
        coverage_pass=$((coverage_pass + 1))
        ;;
      *)
        do_warn "Unknown coverage checker output: $level $message"
        coverage_warn=$((coverage_warn + 1))
        ;;
    esac
  done < <(python3 - "$CATALOG_JSON" "$LIST_FILE" <<'PY'
from __future__ import annotations

import json
import sys
from pathlib import Path

catalog_path = Path(sys.argv[1])
list_path = Path(sys.argv[2])

catalog = json.loads(catalog_path.read_text(encoding="utf-8"))

listed: set[str] = set()
for raw in list_path.read_text(encoding="utf-8").splitlines():
    stripped = raw.strip()
    if not stripped or stripped.startswith("#"):
        continue
    clean = stripped.split(" #", 1)[0].strip()
    if not clean:
        continue
    listed.add(clean.split()[0])

release_scripts = []
for entry in catalog.get("scripts", []):
    path = entry.get("path", "")
    if not path.startswith("scripts/qa/verify-"):
        continue
    if entry.get("tier") != "release_blocking":
        continue
    if entry.get("status") != "active":
        continue
    release_scripts.append(entry)

failed = 0
warned = 0
for entry in sorted(release_scripts, key=lambda item: item.get("path", "")):
    path = entry.get("path", "")
    binding = set(entry.get("ci_binding") or [])
    in_list = path in listed
    workflow_direct = "workflow_direct" in binding
    ci_static = "ci_static" in binding

    if ci_static and not in_list:
        print(f"FAIL\t{path}: catalog says ci_static but script is missing from ci-scripts-static.txt")
        failed += 1
        continue

    if in_list and not ci_static:
        print(f"WARN\t{path}: listed in ci-scripts-static.txt but catalog ci_binding lacks ci_static (regenerate catalog)")
        warned += 1

    if not in_list and not workflow_direct:
        print(f"FAIL\t{path}: release-blocking script is not CI-bound (neither static list nor workflow_direct)")
        failed += 1

if failed == 0:
    print(f"PASS\trelease-blocking coverage intact for {len(release_scripts)} scripts")
else:
    print(f"FAIL\trelease-blocking coverage failures: {failed}")
if warned > 0:
    print(f"WARN\trelease-blocking coverage warnings: {warned}")
PY
)
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
