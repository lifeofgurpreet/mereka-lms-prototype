#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/paragon-runtime-contract.yml"

echo "Checking paragon runtime contract workflow..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

for input_key in target_environment runtime_url require_runtime_theme require_slot_markers; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ workflow missing input: ${input_key}"
    violations=1
  fi
done

if ! rg -n './scripts/qa/verify-paragon-runtime\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-paragon-runtime.sh invocation"
  violations=1
fi

if ! rg -n -- '--runtime-url|--require-runtime|--require-slot-markers|--allow-missing-slot-markers' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing runtime URL/strict marker arg wiring"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/paragon-runtime-contract\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing paragon runtime contract log"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Paragon runtime contract workflow failed."
  exit 1
fi

echo "✅ Paragon runtime contract workflow passed."
