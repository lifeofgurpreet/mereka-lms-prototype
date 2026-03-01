#!/usr/bin/env bash
# verify-frontend-extended-surfaces-workflow.sh — contract for frontend-extended-surfaces workflow wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/frontend-extended-surfaces.yml"

echo "Checking frontend extended surfaces workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: .github/workflows/frontend-extended-surfaces.yml"
  exit 1
fi

if ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

if ! rg -n 'runs-on:[[:space:]]+ubuntu-24\.04' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow must run on ubuntu-24.04"
  violations=1
fi

if ! rg -n 'timeout-minutes:[[:space:]]+45' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing timeout-minutes: 45 contract"
  violations=1
fi

if ! rg -n 'actions/checkout@[0-9a-f]{40}' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow must pin actions/checkout to a full commit SHA"
  violations=1
fi

if ! rg -n 'make qa-frontend-extended-surfaces' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing make qa-frontend-extended-surfaces invocation"
  violations=1
fi

if ! rg -n 'mkdir -p var/qa' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing var/qa log directory bootstrap"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/frontend-extended-surfaces\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing frontend-extended-surfaces.log artifact path"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend extended surfaces workflow contract failed."
  exit 1
fi

echo "✅ Frontend extended surfaces workflow contract passed."
