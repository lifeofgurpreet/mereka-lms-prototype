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

if ! rg -n 'learning_path' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing learning_path input"
  violations=1
fi

if ! rg -n 'npm_start_project' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing npm_start_project input"
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

if ! rg -n -- '--require-branding-markers|--allow-unbranded-shell' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow npm-start smoke step missing branding marker wiring"
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

if ! rg -n '"learning_path": "\$\{\{ inputs\.learning_path \|\| '\''/learning'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing learning_path field"
  violations=1
fi

if ! rg -n '"npm_start_project": "\$\{\{ inputs\.npm_start_project \|\| '\''chromium'\'' \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing npm_start_project field"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Release evidence workflow contract failed."
  exit 1
fi

echo "✅ Release evidence workflow contract passed."
