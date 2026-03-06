#!/usr/bin/env bash
# check-pr-handoff-discipline.sh
#
# Local guard to prevent local-only code from being stranded outside PRs.
# Run this before handing work to another agent or switching tasks.
#
# Usage:
#   ./scripts/infra/check-pr-handoff-discipline.sh
#   ./scripts/infra/check-pr-handoff-discipline.sh --max-behind 0
#   ./scripts/infra/check-pr-handoff-discipline.sh --allow-stash
set -euo pipefail

MAX_BEHIND=0
ALLOW_STASH=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-behind)
      MAX_BEHIND="${2:-0}"
      shift 2
      ;;
    --allow-stash)
      ALLOW_STASH=1
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--max-behind N] [--allow-stash]"
      echo "Fails on dirty worktree, parked stash entries, or unsynced branch."
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

echo "=== PR Handoff Discipline Check ==="
echo "Repo: $REPO_ROOT"
echo "Max behind allowed: $MAX_BEHIND"
echo ""

branch="$(git branch --show-current 2>/dev/null || true)"
if [[ -z "$branch" ]]; then
  fail "detached HEAD (checkout a branch before handoff)"
else
  pass "current branch: $branch"
fi

git fetch origin main --quiet 2>/dev/null || true
behind_main="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
ahead_main="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
if [[ "$behind_main" -gt "$MAX_BEHIND" ]]; then
  fail "branch is behind origin/main by $behind_main commits (ahead by $ahead_main)"
else
  pass "branch sync vs origin/main: behind=$behind_main ahead=$ahead_main"
fi

status_output="$(git status --porcelain)"
if [[ -n "$status_output" ]]; then
  fail "working tree is not clean (commit, stash intentionally, or discard before handoff)"
else
  pass "working tree clean"
fi

stash_count="$(git stash list | wc -l | tr -d '[:space:]')"
if [[ "$stash_count" -gt 0 ]]; then
  if [[ "$ALLOW_STASH" -eq 1 ]]; then
    warn "stash entries present ($stash_count) but --allow-stash set"
  else
    fail "stash has $stash_count entrie(s) (feature work must be committed to a branch/PR)"
  fi
else
  pass "no stash entries"
fi

if upstream_ref="$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"; then
  unpushed="$(git rev-list --count "${upstream_ref}"..HEAD 2>/dev/null || echo 0)"
  if [[ "$unpushed" -gt 0 ]]; then
    fail "branch has $unpushed unpushed commit(s) vs $upstream_ref"
  else
    pass "no unpushed commits vs $upstream_ref"
  fi
else
  warn "branch has no upstream tracking ref (set upstream before handoff)"
fi

echo ""
echo "=== Summary: PASS=$PASS FAIL=$FAIL WARN=$WARN ==="
if [[ "$FAIL" -gt 0 ]]; then
  echo "RESULT: FAIL — handoff is unsafe; ship or clean local state first."
  exit 1
fi
echo "RESULT: PASS — handoff discipline checks are satisfied."
exit 0
