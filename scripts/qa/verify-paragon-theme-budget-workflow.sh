#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/paragon-theme-budget.yml"

echo "Checking paragon theme budget workflow..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if ! rg -n '^on:' "$WORKFLOW" >/dev/null || ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

if ! rg -n './scripts/qa/verify-paragon-token-coverage\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-paragon-token-coverage.sh invocation"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/paragon-theme-budget\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing paragon theme budget log"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Paragon theme budget workflow failed."
  exit 1
fi

echo "✅ Paragon theme budget workflow passed."
