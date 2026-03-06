#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

CHECKS=(
  "scripts/qa/verify-ci-script-list.sh"
  "scripts/qa/verify-verification-catalog.sh"
  "scripts/qa/verify-deprecated-verification-hygiene.sh"
)

echo "=== Verification Manifest Integrity ==="
echo "Repo: $REPO_ROOT"
echo ""

for check in "${CHECKS[@]}"; do
  abs="$REPO_ROOT/$check"
  if [[ ! -f "$abs" ]]; then
    echo "FAIL missing check script: $check" >&2
    exit 1
  fi
  echo "--- Running: $check ---"
  "$abs"
  echo ""
done

echo "PASS verification manifest integrity checks"
