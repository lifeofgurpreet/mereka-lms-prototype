#!/usr/bin/env bash
# @covers AC-MFE-002, AC-MFE-004
# @spec: mfe-branding-customization_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/cross-browser-branding-smoke.yml"

echo "Checking cross-browser branding smoke workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

for input_key in target_environment cross_browser learning_path require_runtime_theme require_branding_markers require_webkit; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ cross-browser workflow missing input: ${input_key}"
    violations=1
  fi
done

if ! rg -n './scripts/qa/verify-cross-browser-branding-smoke\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ cross-browser workflow missing verify-cross-browser-branding-smoke.sh invocation"
  violations=1
fi

if ! rg -n -- '--require-runtime-theme' "$WORKFLOW" >/dev/null; then
  echo "❌ cross-browser workflow does not wire --require-runtime-theme"
  violations=1
fi

if ! rg -n -- '--require-branding-markers|--allow-unbranded-shell' "$WORKFLOW" >/dev/null; then
  echo "❌ cross-browser workflow does not wire branding marker strictness flags"
  violations=1
fi

if ! rg -n -- '--strict-webkit' "$WORKFLOW" >/dev/null; then
  echo "❌ cross-browser workflow does not wire --strict-webkit"
  violations=1
fi

if ! rg -n 'uses:[[:space:]]*actions/upload-artifact@' "$WORKFLOW" >/dev/null; then
  echo "❌ cross-browser workflow missing upload-artifact step"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Cross-browser branding workflow contract failed."
  exit 1
fi

echo "✅ Cross-browser branding workflow contract passed."
