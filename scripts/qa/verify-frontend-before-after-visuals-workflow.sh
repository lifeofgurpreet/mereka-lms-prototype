#!/usr/bin/env bash
# verify-frontend-before-after-visuals-workflow.sh
# Contract for the frontend-before-after-visuals workflow.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/frontend-before-after-visuals.yml"

echo "Checking frontend-before-after-visuals workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: .github/workflows/frontend-before-after-visuals.yml"
  exit 1
fi

if ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

for input_key in target_environment capture_screenshots screenshot_scope threshold strict_file_set allow_bootstrap require_runtime_theme; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ workflow missing input: ${input_key}"
    violations=1
  fi
done

if ! rg -n 'runs-on:[[:space:]]+ubuntu-24\.04' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow must run on ubuntu-24.04"
  violations=1
fi

if ! rg -n 'actions/checkout@[0-9a-f]{40}' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow must pin actions/checkout to a full commit SHA"
  violations=1
fi

if ! rg -n 'capture-branding-screenshots\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing optional screenshot capture wiring"
  violations=1
fi

if ! rg -n 'build-branding-before-after-report\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing before/after report generation invocation"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/evidence/branding-before-after/\*\*' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing branding-before-after evidence directory"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend-before-after-visuals workflow contract failed."
  exit 1
fi

echo "✅ Frontend-before-after-visuals workflow contract passed."
