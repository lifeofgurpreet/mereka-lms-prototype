#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/certificate-branding.yml"

echo "Checking certificate branding workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if ! rg -n '^on:' "$WORKFLOW" >/dev/null || ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

if ! rg -n './scripts/qa/verify-certificate-branding\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-certificate-branding.sh invocation"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/certificate-branding\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing certificate branding log"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Certificate branding workflow contract failed."
  exit 1
fi

echo "✅ Certificate branding workflow contract passed."
