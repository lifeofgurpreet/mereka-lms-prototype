#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/mfe-selector-hardening.yml"

echo "Checking MFE selector hardening workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if ! rg -n '^on:' "$WORKFLOW" >/dev/null || ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

if ! rg -n "^[[:space:]]+pgn_selector_ceiling:" "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing input: pgn_selector_ceiling"
  violations=1
fi

if ! rg -n './scripts/qa/verify-mfe-selector-hardening\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-mfe-selector-hardening.sh invocation"
  violations=1
fi

if ! rg -n 'PGN_SELECTOR_CEILING=' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing PGN_SELECTOR_CEILING wiring"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/mfe-selector-hardening\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing selector hardening log"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "MFE selector hardening workflow contract failed."
  exit 1
fi

echo "✅ MFE selector hardening workflow contract passed."
