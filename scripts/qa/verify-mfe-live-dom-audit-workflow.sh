#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/mfe-live-dom-audit.yml"

echo "Checking MFE live DOM audit workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

for input_key in target_environment base_url require_runtime_theme require_branding_markers audit_profile \
                 selector_audit_path selector_audit_routes selector_audit_selectors \
                 min_selector_hits min_custom_selector_hits project; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ workflow missing input: ${input_key}"
    violations=1
  fi
done

if ! rg -n './scripts/qa/verify-mfe-live-dom-audit\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-mfe-live-dom-audit.sh invocation"
  violations=1
fi

if ! rg -n 'AUDIT_PROFILE=' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing audit profile wiring"
  violations=1
fi

if ! rg -n '^[[:space:]]+- phase7_strict$' "$WORKFLOW" >/dev/null \
  || ! rg -n '^[[:space:]]+- phase7_full$' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow audit_profile options missing phase7_strict or phase7_full"
  violations=1
fi

if ! rg -n -- '--selector-audit-path|--min-selector-hits|--min-custom-selector-hits' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing selector path/min-hit arg wiring"
  violations=1
fi

if ! rg -n 'selector_audit_routes|selector_audit_selectors' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing selector route/custom-selector input wiring"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'Summarize live DOM audit|GITHUB_STEP_SUMMARY' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing run summary step"
  violations=1
fi

if ! rg -n 'var/qa/mfe-live-dom-audit-\*\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow artifact path missing live DOM audit log glob"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "MFE live DOM audit workflow contract failed."
  exit 1
fi

echo "✅ MFE live DOM audit workflow contract passed."
