#!/usr/bin/env bash
# @covers AC-WC-005
# @spec: ci-cd-pipeline_spec.md
# check-worktree-freshness.sh — Pre-merge gate: prevent builds from stale worktrees
#
# Verifies the current worktree is on main, up-to-date with upstream, and has
# no stale branches checked out. Exit 1 if stale.
#
# Usage:
#   ./scripts/infra/check-worktree-freshness.sh [--max-behind N]
#
# Options:
#   --max-behind N   Max commits behind upstream main (default: 5)

set -euo pipefail

MAX_BEHIND=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-behind) MAX_BEHIND="${2:-5}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--max-behind N]"
      echo "Pre-merge gate: prevents builds from stale worktrees."
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "WARN: $1"; }

echo "=== Worktree Freshness Check ==="
echo "Max behind: $MAX_BEHIND commits"
echo ""

# Check 1: On main branch
BRANCH="$(git branch --show-current 2>/dev/null || echo "")"
if [[ "$BRANCH" == "main" ]]; then
  pass "On branch main"
elif [[ "$BRANCH" == feat/* ]]; then
  warn "On feature branch '$BRANCH' — ensure it's rebased on main before merge"
else
  fail "On unexpected branch '$BRANCH' (expected main or feat/*)"
fi

# Check 2: Fetch and check distance from upstream
git fetch origin main --quiet 2>/dev/null || true
BEHIND="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")"
AHEAD="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")"

if [[ "$BEHIND" -eq 0 ]]; then
  pass "Up-to-date with origin/main (ahead by $AHEAD)"
elif [[ "$BEHIND" -le "$MAX_BEHIND" ]]; then
  warn "Behind origin/main by $BEHIND commits (threshold: $MAX_BEHIND)"
else
  fail "Behind origin/main by $BEHIND commits (max: $MAX_BEHIND) — pull before building"
fi

# Check 3: No other worktrees checked out on main
WORKTREE_COUNT=0
while IFS= read -r line; do
  if [[ "$line" == worktree\ * ]]; then
    WT_PATH="${line#worktree }"
    if [[ "$WT_PATH" != "$(git rev-parse --show-toplevel)" ]]; then
      WT_BRANCH="$(git -C "$WT_PATH" branch --show-current 2>/dev/null || echo "detached")"
      if [[ "$WT_BRANCH" == "main" ]]; then
        fail "Another worktree on main at: $WT_PATH (risk of parallel edits)"
      fi
      WORKTREE_COUNT=$((WORKTREE_COUNT + 1))
    fi
  fi
done <<< "$(git worktree list --porcelain 2>/dev/null)"

if [[ "$WORKTREE_COUNT" -eq 0 ]]; then
  pass "No extra worktrees"
else
  warn "$WORKTREE_COUNT extra worktree(s) found (not on main)"
fi

# Check 4: No uncommitted changes to critical files
DIRTY_CRITICAL="$(git diff --name-only -- deploy/ infrastructure/ scripts/ 2>/dev/null || true)"
if [[ -z "$DIRTY_CRITICAL" ]]; then
  pass "No uncommitted changes in deploy/ infrastructure/ scripts/"
else
  DIRTY_COUNT="$(echo "$DIRTY_CRITICAL" | wc -l)"
  fail "$DIRTY_COUNT uncommitted change(s) in critical paths — commit or stash before building"
fi

# Summary
echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN ==="

if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: STALE — do not build from this worktree"
  exit 1
fi

echo "RESULT: FRESH — safe to build and merge"
exit 0
