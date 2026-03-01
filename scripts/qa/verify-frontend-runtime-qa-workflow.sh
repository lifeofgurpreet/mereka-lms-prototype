#!/usr/bin/env bash
# verify-frontend-runtime-qa-workflow.sh — contract for frontend-runtime-qa workflow wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/frontend-runtime-qa.yml"

echo "Checking frontend runtime QA workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

for input_key in target_environment capture_screenshots; do
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

if ! rg -n 'make qa-frontend-runtime-qa-prod' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing qa-frontend-runtime-qa-prod invocation"
  violations=1
fi

if ! rg -n 'make qa-frontend-runtime-qa-dev' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing qa-frontend-runtime-qa-dev invocation"
  violations=1
fi

if ! rg -n './scripts/qa/capture-branding-screenshots\.sh --env "\$TARGET_ENV" --mfe-only' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing optional MFE screenshot capture wiring"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/frontend-runtime-qa\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing frontend-runtime-qa log"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend runtime QA workflow contract failed."
  exit 1
fi

echo "✅ Frontend runtime QA workflow contract passed."
