#!/usr/bin/env bash
# @spec: repository-structure_spec.md
# @covers AC-REPO-DEPRECATION-001
# verify-deprecation-discipline.sh — Verify OEP-21 deprecation discipline.
#
# Checks:
#   1. DEPR.md exists at repo root
#   2. Each deprecated item has a removal target date
#   3. Deprecated directories (tools/, ops/) contain only README.md or are absent
#   4. No references to deprecated paths in active scripts
#
# No network calls. No destructive operations.
#
# Usage:
#   ./scripts/qa/verify-deprecation-discipline.sh
#
# Exit codes:
#   0  All checks pass
#   1  One or more checks failed
set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

failures=0

pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }
info() { echo "[INFO] $*"; }

# ---------------------------------------------------------------------------
# 1. DEPR.md exists at repo root
# ---------------------------------------------------------------------------
echo ""
echo "--- 1. DEPR.md presence ---"

if [[ -f "DEPR.md" ]]; then
  pass "DEPR.md exists at repo root"
else
  fail "DEPR.md missing from repo root"
fi

# ---------------------------------------------------------------------------
# 2. Each deprecated item has a removal target date
#    Look for DEPR-NNN blocks that lack a Target removal or Removed row.
# ---------------------------------------------------------------------------
echo ""
echo "--- 2. Deprecation entries have target dates ---"

if [[ -f "DEPR.md" ]]; then
  # Collect DEPR-NNN IDs
  depr_ids=()
  while IFS= read -r line; do
    if [[ "$line" =~ DEPR-([0-9]+) ]]; then
      id="DEPR-${BASH_REMATCH[1]}"
      # Avoid duplicates
      already=0
      for d in "${depr_ids[@]:-}"; do
        [[ "$d" == "$id" ]] && already=1 && break
      done
      [[ "$already" -eq 0 ]] && depr_ids+=("$id")
    fi
  done < "DEPR.md"

  if [[ "${#depr_ids[@]}" -eq 0 ]]; then
    fail "DEPR.md contains no DEPR-NNN entries"
  else
    info "Found ${#depr_ids[@]} deprecation entries: ${depr_ids[*]}"
    for id in "${depr_ids[@]}"; do
      # Each entry should have either "Target removal" or "Removed" (for completed)
      if grep -A 20 "### ${id}" DEPR.md | grep -qE "Target removal|Removed"; then
        pass "$id has a target removal or removal date"
      else
        fail "$id is missing a 'Target removal' or 'Removed' date"
      fi
    done
  fi
fi

# ---------------------------------------------------------------------------
# 3. Deprecated directories are absent or tombstone-only (README.md only)
# ---------------------------------------------------------------------------
echo ""
echo "--- 3. Deprecated directory tombstones ---"

check_deprecated_dir() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    pass "Deprecated directory absent (clean): $path/"
    return
  fi
  if [[ ! -d "$path" ]]; then
    fail "Deprecated path exists but is not a directory: $path"
    return
  fi
  local file_count
  file_count="$(find "$path" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ "$file_count" -eq 1 && -f "$path/README.md" ]]; then
    pass "Deprecated directory tombstone ok: $path/ (README.md only)"
  elif [[ "$file_count" -eq 0 ]]; then
    pass "Deprecated directory is empty (no files): $path/"
  else
    fail "Deprecated directory must be absent or contain only README.md: $path/ ($file_count file(s) found)"
  fi
}

check_deprecated_dir "tools"
check_deprecated_dir "ops"

# ---------------------------------------------------------------------------
# 4. No references to deprecated paths in active scripts
# ---------------------------------------------------------------------------
echo ""
echo "--- 4. No deprecated path references in active scripts ---"

# Pattern: scripts referencing tools/ or ops/ as paths (not as words in comments)
# Exclude: this script itself, DEPR.md, docs/, specs/, ADRs, README files, git history
ACTIVE_SCRIPT_DIRS=("scripts" "infrastructure/tutor" "deploy")

check_no_deprecated_ref() {
  local pattern="$1"
  local description="$2"
  local found_files=()

  for dir in "${ACTIVE_SCRIPT_DIRS[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r -d '' f; do
      # Skip this script, the broken-paths script, markdown files, and DEPR.md
      [[ "$f" == *"verify-deprecation-discipline.sh" ]] && continue
      [[ "$f" == *"verify-no-broken-paths.sh" ]] && continue
      [[ "$f" == *.md ]] && continue
      [[ "$f" == *DEPR* ]] && continue
      found_files+=("$f")
    done < <(grep -rl --null "$pattern" "$dir" 2>/dev/null || true)
  done

  if [[ "${#found_files[@]}" -gt 0 ]]; then
    fail "$description — found in: ${found_files[*]}"
  else
    pass "No active script references to $description"
  fi
}

# Check for hardcoded references to deprecated directory paths
# Use word-boundary patterns to avoid false positives (e.g. "tools" in "toolset")
check_no_deprecated_ref 'scripts/shared/_common\.sh' 'scripts/shared/_common.sh (removed)'

# Check for import-style references to tools/ or ops/ as script paths
# grep for path-style references like "tools/" or "ops/" at start of path component
bad_tools_refs=()
bad_ops_refs=()

for dir in "${ACTIVE_SCRIPT_DIRS[@]}"; do
  [[ -d "$dir" ]] || continue
  while IFS= read -r f; do
    [[ "$f" == *"verify-deprecation-discipline.sh" ]] && continue
    [[ "$f" == *.md ]] && continue
    bad_tools_refs+=("$f")
  done < <(grep -rl --include='*.sh' '^\s*source\s.*\btools/' "$dir" 2>/dev/null || true)
  while IFS= read -r f; do
    [[ "$f" == *"verify-deprecation-discipline.sh" ]] && continue
    [[ "$f" == *.md ]] && continue
    bad_ops_refs+=("$f")
  done < <(grep -rl --include='*.sh' '^\s*source\s.*\bops/' "$dir" 2>/dev/null || true)
done

if [[ "${#bad_tools_refs[@]}" -gt 0 ]]; then
  fail "Active scripts source from deprecated tools/: ${bad_tools_refs[*]}"
else
  pass "No active scripts source from deprecated tools/"
fi

if [[ "${#bad_ops_refs[@]}" -gt 0 ]]; then
  fail "Active scripts source from deprecated ops/: ${bad_ops_refs[*]}"
else
  pass "No active scripts source from deprecated ops/"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "--- Summary ---"
if [[ "$failures" -eq 0 ]]; then
  echo "OK — all deprecation discipline checks passed"
  exit 0
fi
echo "FAIL — $failures check(s) failed" >&2
exit 1
