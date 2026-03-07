#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="docs/qa/run-docs-world-class-gates.sh"

if [ ! -f "$SCRIPT_PATH" ]; then
  echo "missing script: $SCRIPT_PATH"
  exit 1
fi

grep -q "SYNC_STRATEGY=\"auto\"" "$SCRIPT_PATH"
grep -q "BASE_REF=\"origin/main\"" "$SCRIPT_PATH"
grep -q -- "--sync-strategy" "$SCRIPT_PATH"
grep -q -- "--base-ref" "$SCRIPT_PATH"
grep -q "run branch sync with --base-ref before checks" "$SCRIPT_PATH"
grep -q "Invalid --sync-strategy" "$SCRIPT_PATH"
grep -q "FAIL: run docs world-class gates from a dedicated docs branch, not" "$SCRIPT_PATH"
grep -q "Use a docs/\\* branch in the isolated docs worktree (do not run from" "$SCRIPT_PATH"
grep -q "Worktree has local changes; using merge fallback without rebase attempt." "$SCRIPT_PATH"
grep -q "Rebase failed; falling back to merge strategy." "$SCRIPT_PATH"
grep -q "FAIL: rebase strategy requested but worktree has local changes." "$SCRIPT_PATH"
grep -q "verify-docs-policy.sh --range \"\${BASE_REF}...HEAD\"" "$SCRIPT_PATH"

echo "run-docs-world-class-gates self-test: OK"
