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
                 run_runtime_theme_contract_gate run_npm_start_smoke_gate run_screenshot_gate \
                 run_certificate_branding_gate run_live_dom_audit_gate \
                 live_dom_audit_project live_dom_audit_min_hits selector_audit_path \
                 runtime_theme_url runtime_theme_timeout_seconds learning_path; do
  if ! rg -n "^[[:space:]]+${input_key}:" "$WORKFLOW" >/dev/null; then
    echo "❌ frontend closure workflow missing input: ${input_key}"
    violations=1
  fi
done

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

if ! rg -n 'REQUIRE_BRANDING_MARKERS=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire REQUIRE_BRANDING_MARKERS into pipeline env"
  violations=1
fi

if ! rg -n 'RUN_CERTIFICATE_BRANDING=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire RUN_CERTIFICATE_BRANDING into pipeline env"
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

if ! rg -n 'SELECTOR_AUDIT_PATH=' "$WORKFLOW" >/dev/null; then
  echo "❌ frontend closure workflow does not wire SELECTOR_AUDIT_PATH into pipeline env"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Frontend branding closure workflow contract failed."
  exit 1
fi

echo "✅ Frontend branding closure workflow contract passed."
