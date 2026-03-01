#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/a11y-tenant-branding.yml"

echo "Checking a11y tenant branding workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if ! rg -n "^[[:space:]]+live_mode:" "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing input: live_mode"
  violations=1
fi

if ! rg -n './scripts/qa/verify-a11y-tenant-branding\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-a11y-tenant-branding.sh invocation"
  violations=1
fi

if ! rg -n 'A11Y_TENANT_LIVE=1' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing live-mode env wiring (A11Y_TENANT_LIVE=1)"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/a11y-tenant-branding-\*\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing a11y tenant branding log glob"
  violations=1
fi

if ! rg -n 'var/a11y/\*\*' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing var/a11y output"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "A11y tenant branding workflow contract failed."
  exit 1
fi

echo "✅ A11y tenant branding workflow contract passed."
