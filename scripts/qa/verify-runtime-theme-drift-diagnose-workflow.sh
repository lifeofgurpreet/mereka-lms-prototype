#!/usr/bin/env bash
# verify-runtime-theme-drift-diagnose-workflow.sh — contract for runtime-theme-drift-diagnose workflow wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/runtime-theme-drift-diagnose.yml"

echo "Checking runtime-theme-drift-diagnose workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: .github/workflows/runtime-theme-drift-diagnose.yml"
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

if ! rg -n 'timeout-minutes:[[:space:]]+30' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing timeout-minutes: 30 contract"
  violations=1
fi

if ! rg -n 'actions/checkout@[0-9a-f]{40}' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow must pin actions/checkout to a full commit SHA"
  violations=1
fi

if ! rg -n 'make qa-runtime-theme-drift-diagnose' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing qa-runtime-theme-drift-diagnose invocation"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/runtime-theme-drift-diagnose\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing runtime-theme-drift-diagnose.log artifact path"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Runtime-theme-drift-diagnose workflow contract failed."
  exit 1
fi

echo "✅ Runtime-theme-drift-diagnose workflow contract passed."
