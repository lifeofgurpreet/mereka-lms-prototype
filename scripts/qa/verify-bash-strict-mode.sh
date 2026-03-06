#!/usr/bin/env bash
# verify-bash-strict-mode.sh
#
# Enforces strict Bash mode for verification scripts to reduce brittle behavior
# and hidden runtime failures in CI.
set -euo pipefail

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required" >&2
  exit 2
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

PASS_COUNT=0
FAIL_COUNT=0
WAIVER_COUNT=0

pass() {
  echo "  PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "  FAIL: $1" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

waive() {
  echo "  WAIVE: $1"
  WAIVER_COUNT=$((WAIVER_COUNT + 1))
}

echo "=== Bash Strict Mode Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

while IFS= read -r script_path; do
  [[ -f "$script_path" ]] || continue

  # Legacy scripts may opt out explicitly while still being audited.
  if grep -q "lint: allow-no-euo" "$script_path"; then
    waive "$script_path explicitly allows non-strict mode (lint: allow-no-euo)"
    continue
  fi

  shebang="$(head -n1 "$script_path")"
  if [[ ! "$shebang" =~ ^#!/usr/bin/env\ bash$ ]] && [[ ! "$shebang" =~ ^#!/bin/bash$ ]]; then
    fail "$script_path must use a bash shebang"
    continue
  fi

  header="$(head -n80 "$script_path")"
  if grep -qE '^[[:space:]]*set -euo pipefail([[:space:]]|$)' <<<"$header"; then
    pass "$script_path"
  else
    fail "$script_path missing strict mode: set -euo pipefail"
  fi
done < <(git ls-files "scripts/**/verify-*.sh")

echo ""
echo "=== Summary ==="
echo "Pass   : $PASS_COUNT"
echo "Waived : $WAIVER_COUNT"
echo "Fail   : $FAIL_COUNT"
echo ""

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  echo "FAIL — strict mode violations found." >&2
  exit 1
fi

echo "PASS — all verification scripts satisfy strict mode policy."
