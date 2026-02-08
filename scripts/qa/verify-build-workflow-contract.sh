#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_WORKFLOW="$REPO_ROOT/.github/workflows/build-tutor-images.yml"
RELEASE_INVOKE_CHECKER="$REPO_ROOT/scripts/qa/verify-release-workflow-invocation.sh"

echo "Checking build workflow contract..."

violations=0

if [[ ! -f "$BUILD_WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${BUILD_WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if [[ ! -f "$RELEASE_INVOKE_CHECKER" ]]; then
  echo "❌ Missing checker: ${RELEASE_INVOKE_CHECKER#"$REPO_ROOT"/}"
  exit 1
fi

# Required inputs
if ! rg -n '^[[:space:]]+update_gitops:' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing update_gitops workflow input"
  violations=1
fi

if ! rg -n '^[[:space:]]+target_environment:' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing target_environment workflow input"
  violations=1
fi

# Must default target environment to production.
if ! rg -n '^[[:space:]]+default:[[:space:]]+production$' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ target_environment default is not production"
  violations=1
fi

# Guard against stale input naming in docs/code drift.
if rg -n 'deploy_to_production' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Found stale deploy_to_production input or reference"
  violations=1
fi

# Update job contract
if ! rg -n 'if:[[:space:]]+\$\{\{[[:space:]]*inputs\.update_gitops' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ update-gitops job does not gate on inputs.update_gitops"
  violations=1
fi

if ! rg -n 'TARGET_ENV="\$\{\{ inputs\.target_environment \|\| '\''production'\'' \}\}"' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing TARGET_ENV wiring from workflow input"
  violations=1
fi

if ! rg -n -- '--target-env "\$\{TARGET_ENV\}"' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ release-openedx-gitops.sh is not called with explicit --target-env"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Build workflow contract failed."
  exit 1
fi

echo "✅ Build workflow contract passed."
