#!/usr/bin/env bash
# @covers AC-019
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/npm-start-mfe-smoke.yml"

echo "Checking npm-start smoke workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

for input_key in target_environment base_url learning_path project require_runtime_theme require_branding_markers; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ npm-start smoke workflow missing input: ${input_key}"
    violations=1
  fi
done

if ! rg -n 'uses:[[:space:]]*actions/setup-node@' "$WORKFLOW" >/dev/null; then
  echo "❌ npm-start smoke workflow missing actions/setup-node step"
  violations=1
fi

if ! rg -n './scripts/qa/verify-npm-start-mfe-smoke\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ npm-start smoke workflow missing verify-npm-start-mfe-smoke.sh invocation"
  violations=1
fi

if ! rg -n -- '--require-branding-markers|--allow-unbranded-shell' "$WORKFLOW" >/dev/null; then
  echo "❌ npm-start smoke workflow missing branding marker strictness flag wiring"
  violations=1
fi

if ! rg -n 'uses:[[:space:]]*actions/upload-artifact@' "$WORKFLOW" >/dev/null; then
  echo "❌ npm-start smoke workflow missing upload-artifact step"
  violations=1
fi

if ! rg -n 'var/e2e-artifacts/\*\*' "$WORKFLOW" >/dev/null; then
  echo "❌ npm-start smoke workflow missing e2e artifact upload path"
  violations=1
fi

if ! rg -n 'var/e2e-report/\*\*' "$WORKFLOW" >/dev/null; then
  echo "❌ npm-start smoke workflow missing e2e HTML report upload path"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "NPM-start smoke workflow contract failed."
  exit 1
fi

echo "✅ NPM-start smoke workflow contract passed."
