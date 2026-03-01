#!/usr/bin/env bash
# @covers AC-MFE-003, AC-MFE-004
# @spec: mfe-branding-customization_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/frontend-branding-closure.yml"

echo "Checking frontend branding closure workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

for input_key in target_environment cross_browser_matrix require_runtime_theme require_branding_markers require_webkit \
                 run_runtime_theme_contract_gate run_npm_start_smoke_gate run_screenshot_gate live_dom_audit_profile \
                 screenshot_scope \
                 run_certificate_branding_gate run_live_dom_audit_gate \
                 live_dom_audit_project live_dom_audit_min_hits live_dom_audit_routes live_dom_audit_selectors live_dom_audit_min_custom_hits selector_audit_path \
                 runtime_theme_url runtime_theme_timeout_seconds learning_path a11y_mode a11y_target_url a11y_routes a11y_allow_missing_reports; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ frontend closure workflow missing input: ${input_key}"
    violations=1
  fi
done

if ! rg -n '^[[:space:]]+- phase7_strict$' "$WORKFLOW" >/dev/null \
  || ! rg -n '^[[:space:]]+- phase7_full$' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow live_dom_audit_profile options missing phase7_strict or phase7_full"
  violations=1
fi

if ! rg -n '^[[:space:]]+screenshot_scope:' "$WORKFLOW" >/dev/null \
  || ! rg -n '^[[:space:]]+- full$' "$WORKFLOW" >/dev/null \
  || ! rg -n '^[[:space:]]+- mfe-only$' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow screenshot_scope options missing full or mfe-only"
  violations=1
fi

if ! rg -n './scripts/qa/run-branding-evidence-pipeline\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow missing run-branding-evidence-pipeline.sh invocation"
  violations=1
fi

if ! rg -n -- '--frontend-only' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow missing --frontend-only pipeline mode"
  violations=1
fi

if ! rg -n 'RUN_RUNTIME_THEME_CONTRACT=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire RUN_RUNTIME_THEME_CONTRACT into pipeline env"
  violations=1
fi

if ! rg -n 'A11Y_MODE=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire A11Y_MODE into pipeline env"
  violations=1
fi

if ! rg -n 'A11Y_TARGET=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire A11Y_TARGET into pipeline env"
  violations=1
fi

if ! rg -n 'A11Y_ROUTES=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire A11Y_ROUTES into pipeline env"
  violations=1
fi

if ! rg -n 'A11Y_ALLOW_MISSING_REPORTS=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire A11Y_ALLOW_MISSING_REPORTS into pipeline env"
  violations=1
fi

if ! rg -n 'RUNTIME_THEME_URL=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire RUNTIME_THEME_URL into pipeline env"
  violations=1
fi

if ! rg -n 'RUNTIME_THEME_TIMEOUT_SECONDS=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire RUNTIME_THEME_TIMEOUT_SECONDS into pipeline env"
  violations=1
fi

if ! rg -n 'RUN_MFE_LIVE_DOM_AUDIT=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire RUN_MFE_LIVE_DOM_AUDIT into pipeline env"
  violations=1
fi

if ! rg -n 'LIVE_DOM_AUDIT_PROFILE=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire LIVE_DOM_AUDIT_PROFILE into run logic"
  violations=1
fi

if ! rg -n 'REQUIRE_BRANDING_MARKERS=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire REQUIRE_BRANDING_MARKERS into pipeline env"
  violations=1
fi

if ! rg -n 'RUN_CERTIFICATE_BRANDING=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire RUN_CERTIFICATE_BRANDING into pipeline env"
  violations=1
fi

if ! rg -n 'SCREENSHOT_SCOPE=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire SCREENSHOT_SCOPE into pipeline env"
  violations=1
fi

if ! rg -n 'LIVE_DOM_AUDIT_PROJECT=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire LIVE_DOM_AUDIT_PROJECT into pipeline env"
  violations=1
fi

if ! rg -n 'LIVE_DOM_AUDIT_MIN_HITS=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire LIVE_DOM_AUDIT_MIN_HITS into pipeline env"
  violations=1
fi

if ! rg -n 'LIVE_DOM_AUDIT_ROUTES=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire LIVE_DOM_AUDIT_ROUTES into pipeline env"
  violations=1
fi

if ! rg -n 'LIVE_DOM_AUDIT_SELECTORS=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire LIVE_DOM_AUDIT_SELECTORS into pipeline env"
  violations=1
fi

if ! rg -n 'LIVE_DOM_AUDIT_MIN_CUSTOM_HITS=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire LIVE_DOM_AUDIT_MIN_CUSTOM_HITS into pipeline env"
  violations=1
fi

if ! rg -n 'SELECTOR_AUDIT_PATH=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire SELECTOR_AUDIT_PATH into pipeline env"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend branding closure workflow contract failed."
  exit 1
fi

echo "✅ Frontend branding closure workflow contract passed."
