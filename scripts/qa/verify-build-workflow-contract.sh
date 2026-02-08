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

# Staging must be explicitly enabled via repository variable gate.
if ! rg -n 'ENABLE_STAGING_ENV:[[:space:]]*\$\{\{ vars\.ENABLE_STAGING_ENV \|\| '\''false'\'' \}\}' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing ENABLE_STAGING_ENV guard variable wiring in update-gitops job"
  violations=1
fi

# Must force explicit target selection during manual dispatch.
if ! rg -n '^[[:space:]]+default:[[:space:]]+select-environment$' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ target_environment default is not select-environment"
  violations=1
fi

# Guard against stale input naming in docs/code drift.
if rg -n 'deploy_to_production' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Found stale deploy_to_production input or reference"
  violations=1
fi

# Update job contract
if ! rg -n "inputs\\.update_gitops[[:space:]]*&&[[:space:]]*inputs\\.target_environment[[:space:]]*!=[[:space:]]*'select-environment'" "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ update-gitops manual dispatch gate is missing explicit target selection"
  violations=1
fi

if ! rg -n 'target_environment=staging is disabled' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing staging-disabled guard messaging in manual dispatch validation"
  violations=1
fi

if ! rg -n 'TARGET_ENV="\$\{\{ github\.event_name == '\''workflow_dispatch'\'' && inputs\.target_environment \|\| '\''production'\'' \}\}"' "$BUILD_WORKFLOW" >/dev/null; then
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
