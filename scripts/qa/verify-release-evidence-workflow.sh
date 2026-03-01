#!/usr/bin/env bash
# @covers AC-019
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/release-evidence.yml"

echo "Checking release evidence workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if [[ ! -x "$REPO_ROOT/scripts/infra/resolve-image-digest.sh" ]]; then
  echo "❌ Missing executable digest helper: scripts/infra/resolve-image-digest.sh"
  violations=1
fi

if ! rg -n -e 'uses:[[:space:]]*google-github-actions/auth@' -e 'uses:[[:space:]]*\./\.github/actions/gcp-gke-auth' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing GCP auth step (google-github-actions/auth or local gcp-gke-auth action)"
  violations=1
fi

if ! rg -n 'gcloud auth configure-docker' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing Artifact Registry docker auth configuration"
  violations=1
fi

if ! rg -n './scripts/infra/resolve-image-digest\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow does not use scripts/infra/resolve-image-digest.sh"
  violations=1
fi

if ! rg -n -- '--output-key openedx_digest' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing openedx digest output wiring"
  violations=1
fi

if ! rg -n -- '--output-key mfe_digest' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing mfe digest output wiring"
  violations=1
fi

if ! rg -n -- '--openedx-digest "\$\{\{ steps\.digests\.outputs\.openedx_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release dry-run call missing --openedx-digest"
  violations=1
fi

if ! rg -n -- '--mfe-digest "\$\{\{ steps\.digests\.outputs\.mfe_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release dry-run call missing --mfe-digest"
  violations=1
fi

if ! rg -n -- '--require-digests' "$WORKFLOW" >/dev/null; then
  echo "❌ release dry-run call missing --require-digests"
  violations=1
fi

if ! rg -n 'require_runtime_theme' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing require_runtime_theme input"
  violations=1
fi

if ! rg -n 'require_branding_markers' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing require_branding_markers input"
  violations=1
fi

if ! rg -n 'runtime_theme_url' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing runtime_theme_url input"
  violations=1
fi

if ! rg -n 'run_npm_start_smoke' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing run_npm_start_smoke input"
  violations=1
fi

if ! rg -n 'run_accessibility_scan' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing run_accessibility_scan input"
  violations=1
fi

if ! rg -n 'a11y_mode' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing a11y_mode input"
  violations=1
fi

if ! rg -n 'a11y_target_url' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing a11y_target_url input"
  violations=1
fi

if ! rg -n 'a11y_routes' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing a11y_routes input"
  violations=1
fi

if ! rg -n 'a11y_allow_missing_reports' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing a11y_allow_missing_reports input"
  violations=1
fi

if ! rg -n 'run_certificate_branding' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing run_certificate_branding input"
  violations=1
fi

if ! rg -n 'run_live_dom_audit' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing run_live_dom_audit input"
  violations=1
fi

if ! rg -n 'learning_path' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing learning_path input"
  violations=1
fi

if ! rg -n 'npm_start_project' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing npm_start_project input"
  violations=1
fi

if ! rg -n 'live_dom_audit_project' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing live_dom_audit_project input"
  violations=1
fi

if ! rg -n 'live_dom_audit_min_hits' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing live_dom_audit_min_hits input"
  violations=1
fi

if ! rg -n 'live_dom_audit_profile' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing live_dom_audit_profile input"
  violations=1
fi

if ! rg -n 'live_dom_audit_routes' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing live_dom_audit_routes input"
  violations=1
fi

if ! rg -n 'live_dom_audit_selectors' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing live_dom_audit_selectors input"
  violations=1
fi

if ! rg -n 'live_dom_audit_min_custom_hits' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing live_dom_audit_min_custom_hits input"
  violations=1
fi

if ! rg -n 'selector_audit_path' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing selector_audit_path input"
  violations=1
fi

if ! rg -n './scripts/qa/verify-paragon-runtime\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing frontend runtime theme contract step"
  violations=1
fi

if ! rg -n -- 'args\+=\(--runtime-url' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow runtime contract step missing --runtime-url argument wiring"
  violations=1
fi

if ! rg -n -- '--require-runtime' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow runtime contract step missing strict-mode support (--require-runtime)"
  violations=1
fi

if ! rg -n -- '--require-slot-markers|--allow-missing-slot-markers' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow runtime contract step missing slot-marker policy wiring"
  violations=1
fi

if ! rg -n './scripts/qa/verify-npm-start-mfe-smoke\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing npm-start smoke lane step"
  violations=1
fi

if ! rg -n './scripts/qa/verify-accessibility\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing accessibility lane step"
  violations=1
fi

if ! rg -n -- '--offline|--online' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow accessibility lane missing mode wiring"
  violations=1
fi

if ! rg -n -- '--target' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow accessibility lane missing target URL wiring"
  violations=1
fi

if ! rg -n './scripts/qa/verify-certificate-branding\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing certificate branding lane step"
  violations=1
fi

if ! rg -n './scripts/qa/verify-mfe-live-dom-audit\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing live DOM selector audit lane step"
  violations=1
fi

if ! rg -n 'Summarize release evidence|GITHUB_STEP_SUMMARY' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing run summary step"
  violations=1
fi

if ! rg -n -- '--require-branding-markers|--allow-unbranded-shell' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow npm-start smoke step missing branding marker wiring"
  violations=1
fi

if ! rg -n -- '--audit-profile|--selector-audit-path|--min-selector-hits|--min-custom-selector-hits' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow live DOM selector audit step missing selector path/min-hit wiring"
  violations=1
fi

if ! rg -n -- '--selector-audit-routes|--selector-audit-selectors' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow live DOM selector audit step missing optional route/custom-selector wiring"
  violations=1
fi

if ! rg -n '"openedx_digest": "\$\{\{ steps\.digests\.outputs\.openedx_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing openedx_digest"
  violations=1
fi

if ! rg -n '"mfe_digest": "\$\{\{ steps\.digests\.outputs\.mfe_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing mfe_digest"
  violations=1
fi

if ! rg -n '"require_runtime_theme": "\$\{\{ inputs\.require_runtime_theme \|\| '\''false'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing require_runtime_theme field"
  violations=1
fi

if ! rg -n '"require_branding_markers": "\$\{\{ inputs\.require_branding_markers \|\| '\''true'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing require_branding_markers field"
  violations=1
fi

if ! rg -n '"runtime_theme_url": "\$\{\{ inputs\.runtime_theme_url \|\| '\'''\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing runtime_theme_url field"
  violations=1
fi

if ! rg -n '"run_npm_start_smoke": "\$\{\{ inputs\.run_npm_start_smoke \|\| '\''false'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing run_npm_start_smoke field"
  violations=1
fi

if ! rg -n '"run_accessibility_scan": "\$\{\{ inputs\.run_accessibility_scan \|\| '\''true'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing run_accessibility_scan field"
  violations=1
fi

if ! rg -n '"a11y_mode": "\$\{\{ inputs\.a11y_mode \|\| '\''offline'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing a11y_mode field"
  violations=1
fi

if ! rg -n '"a11y_target_url": "\$\{\{ inputs\.a11y_target_url \|\| '\'''\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing a11y_target_url field"
  violations=1
fi

if ! rg -n '"a11y_routes": "\$\{\{ inputs\.a11y_routes \|\| '\'''\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing a11y_routes field"
  violations=1
fi

if ! rg -n '"a11y_allow_missing_reports": "\$\{\{ inputs\.a11y_allow_missing_reports \|\| '\''false'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing a11y_allow_missing_reports field"
  violations=1
fi

if ! rg -n '"run_certificate_branding": "\$\{\{ inputs\.run_certificate_branding \|\| '\''true'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing run_certificate_branding field"
  violations=1
fi

if ! rg -n '"run_live_dom_audit": "\$\{\{ inputs\.run_live_dom_audit \|\| '\''false'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing run_live_dom_audit field"
  violations=1
fi

if ! rg -n '"learning_path": "\$\{\{ inputs\.learning_path \|\| '\''/learning'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing learning_path field"
  violations=1
fi

if ! rg -n '"npm_start_project": "\$\{\{ inputs\.npm_start_project \|\| '\''chromium'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing npm_start_project field"
  violations=1
fi

if ! rg -n '"live_dom_audit_project": "\$\{\{ inputs\.live_dom_audit_project \|\| '\''chromium'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing live_dom_audit_project field"
  violations=1
fi

if ! rg -n '"live_dom_audit_min_hits": "\$\{\{ inputs\.live_dom_audit_min_hits \|\| '\''3'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing live_dom_audit_min_hits field"
  violations=1
fi

if ! rg -n '"live_dom_audit_profile": "\$\{\{ inputs\.live_dom_audit_profile \|\| '\''standard'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing live_dom_audit_profile field"
  violations=1
fi

if ! rg -n '"live_dom_audit_routes": "\$\{\{ inputs\.live_dom_audit_routes \|\| '\'''\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing live_dom_audit_routes field"
  violations=1
fi

if ! rg -n '"live_dom_audit_selectors": "\$\{\{ inputs\.live_dom_audit_selectors \|\| '\'''\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing live_dom_audit_selectors field"
  violations=1
fi

if ! rg -n '"live_dom_audit_min_custom_hits": "\$\{\{ inputs\.live_dom_audit_min_custom_hits \|\| '\''0'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing live_dom_audit_min_custom_hits field"
  violations=1
fi

if ! rg -n '"selector_audit_path": "\$\{\{ inputs\.selector_audit_path \|\| '\''/authn/login'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing selector_audit_path field"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Release evidence workflow contract failed."
  exit 1
fi

echo "✅ Release evidence workflow contract passed."
