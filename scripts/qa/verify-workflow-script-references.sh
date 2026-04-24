#!/usr/bin/env bash
# @covers AC-CI-014
# @spec: ci-cd-pipeline_spec.md
# Ensure GitHub workflow script references are resolvable and executable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"

PASS=0
FAIL=0

pass() {
  echo "PASS $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL $1"
  FAIL=$((FAIL + 1))
}

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  fail ".github/workflows directory not found"
  echo "Summary: PASS=$PASS FAIL=$FAIL"
  exit 1
fi

declare -A seen_refs=()
ref_count=0

while IFS= read -r line; do
  workflow="${line%%:*}"
  script_ref="${line#*:}"
  key="${workflow}|${script_ref}"
  if [[ -n "${seen_refs[$key]+x}" ]]; then
    continue
  fi
  seen_refs["$key"]=1
  ref_count=$((ref_count + 1))

  abs_script="$REPO_ROOT/$script_ref"
  if [[ ! -e "$abs_script" ]]; then
    fail "$workflow references missing script: $script_ref"
    continue
  fi

  if [[ ! -f "$abs_script" ]]; then
    fail "$workflow reference is not a file: $script_ref"
    continue
  fi

  if [[ ! -x "$abs_script" ]]; then
    fail "$workflow references non-executable script: $script_ref"
    continue
  fi

  pass "$workflow -> $script_ref"
done < <(
  rg -No "scripts/[A-Za-z0-9_./-]+\\.sh" "$WORKFLOWS_DIR" \
    | awk -F: '{print $1 ":" $NF}' \
    | sort -u
)

if [[ "$ref_count" -eq 0 ]]; then
  fail "no scripts/*.sh workflow references found (unexpected)"
fi

echo "Summary: PASS=$PASS FAIL=$FAIL refs=$ref_count"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
