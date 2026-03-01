#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/frontend-performance-spotcheck.yml"

echo "Checking frontend performance spot-check workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

for input_key in target_environment runtime_url require_runtime_theme; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ workflow missing input: ${input_key}"
    violations=1
  fi
done

if ! rg -n './scripts/qa/verify-frontend-performance-spotcheck\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-frontend-performance-spotcheck.sh invocation"
  violations=1
fi

if ! rg -n -- '--runtime-url|--require-runtime' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing runtime URL/strict runtime arg wiring"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/frontend-performance-spotcheck-\*\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing performance spot-check log glob"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend performance spot-check workflow contract failed."
  exit 1
fi

echo "✅ Frontend performance spot-check workflow contract passed."
