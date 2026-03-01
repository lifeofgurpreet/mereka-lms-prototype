#!/usr/bin/env bash
# @covers AC-UIA11Y-007, AC-UIA11Y-008, AC-UIA11Y-009
# @spec: mfe-branding-customization_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/accessibility-audit.yml"

echo "Checking accessibility-audit workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit missing workflow_dispatch trigger"
  violations=1
fi

if ! rg -n 'continue-on-error:[[:space:]]*true' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit must remain non-blocking (continue-on-error: true)"
  violations=1
fi

if ! rg -n 'target_url:' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit missing target_url input"
  violations=1
fi

if ! rg -n 'target_environment:' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit missing target_environment input"
  violations=1
fi

if ! rg -n 'apps\.academyv2\.mereka\.(io|dev)' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit missing apps.* MFE target defaults"
  violations=1
fi

if ! rg -n 'wcag22aa' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit missing wcag22aa tag usage"
  violations=1
fi

if ! rg -n './scripts/qa/run-a11y-runtime-lane\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit must invoke canonical run-a11y-runtime-lane.sh wrapper"
  violations=1
fi

if ! rg -n -- '--mode online' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit wrapper step missing --mode online wiring"
  violations=1
fi

if ! rg -n -- '--env "\$\{TARGET_ENV\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit wrapper step missing TARGET_ENV -> --env wiring"
  violations=1
fi

if ! rg -n -- '--target-url' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit wrapper step missing --target-url wiring"
  violations=1
fi

if ! rg -n -- '--routes' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit wrapper step missing route coverage wiring"
  violations=1
fi

if ! rg -n -- '--allow-missing-reports' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit wrapper step missing --allow-missing-reports safety flag"
  violations=1
fi

if ! rg -n 'axe-audit-reports' "$WORKFLOW" >/dev/null; then
  echo "❌ accessibility-audit missing artifact upload step"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Accessibility-audit workflow contract failed."
  exit 1
fi

echo "✅ Accessibility-audit workflow contract passed."
