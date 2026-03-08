#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="tools/docs/verify/run-docs-world-class-gates.sh"

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
grep -q "FAIL: base ref not found:" "$SCRIPT_PATH"
grep -q "FAIL: run docs world-class gates from a dedicated docs branch, not" "$SCRIPT_PATH"
grep -q "Use a docs/\\* branch in the isolated docs worktree (do not run from" "$SCRIPT_PATH"
grep -q "Worktree has local changes; using merge fallback without rebase attempt." "$SCRIPT_PATH"
grep -q "Rebase failed; falling back to merge strategy." "$SCRIPT_PATH"
grep -q "FAIL: rebase strategy requested but worktree has local changes." "$SCRIPT_PATH"
grep -q "verify-docs-policy.sh --range \"\${BASE_REF}...HEAD\"" "$SCRIPT_PATH"
grep -q "build-doc-catalog.py --check" "$SCRIPT_PATH"
grep -q "build-doc-catalog-test.sh" "$SCRIPT_PATH"
grep -q "verify-evidence-status-root-policy" "$SCRIPT_PATH"
grep -q "scan-doc-catalog-residue" "$SCRIPT_PATH"

HELP_OUT=$(mktemp)
INVALID_SYNC_OUT=$(mktemp)
INVALID_BASE_OUT=$(mktemp)
trap 'rm -f "$HELP_OUT" "$INVALID_SYNC_OUT" "$INVALID_BASE_OUT"' EXIT

bash "$SCRIPT_PATH" --help >"$HELP_OUT" 2>&1
grep -q -- "--sync-strategy auto|rebase|merge" "$HELP_OUT"
grep -q -- "--base-ref ref" "$HELP_OUT"

if bash "$SCRIPT_PATH" --sync-strategy invalid >"$INVALID_SYNC_OUT" 2>&1; then
  echo "expected invalid sync-strategy to fail"
  cat "$INVALID_SYNC_OUT"
  exit 1
fi
grep -q "Invalid --sync-strategy: invalid (expected auto|rebase|merge)" "$INVALID_SYNC_OUT"

if bash "$SCRIPT_PATH" --base-ref refs/heads/does-not-exist >"$INVALID_BASE_OUT" 2>&1; then
  echo "expected invalid base-ref to fail"
  cat "$INVALID_BASE_OUT"
  exit 1
fi
grep -q "FAIL: base ref not found: refs/heads/does-not-exist" "$INVALID_BASE_OUT"

echo "run-docs-world-class-gates self-test: OK"
