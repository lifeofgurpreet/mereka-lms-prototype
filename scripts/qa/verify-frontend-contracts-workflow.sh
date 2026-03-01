#!/usr/bin/env bash
# verify-frontend-contracts-workflow.sh — contract for frontend-contracts workflow wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/frontend-contracts.yml"

echo "Checking frontend contracts workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: .github/workflows/frontend-contracts.yml"
  exit 1
fi

if ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

if ! rg -n 'make qa-frontend-contracts' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing make qa-frontend-contracts invocation"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/frontend-contracts\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing frontend-contracts.log artifact path"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend contracts workflow contract failed."
  exit 1
fi

echo "✅ Frontend contracts workflow contract passed."
