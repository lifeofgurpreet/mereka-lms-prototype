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

if ! rg -n 'image_digest:[[:space:]]*\$\{\{ steps\.digest\.outputs\.digest \}\}' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing image_digest output wiring from digest steps"
  violations=1
fi

if [[ "$(rg -n './scripts/infra/resolve-image-digest\.sh --image-ref' "$BUILD_WORKFLOW" | wc -l | tr -d '[:space:]')" -lt 2 ]]; then
  echo "❌ build workflow does not use shared digest helper for both openedx and mfe"
  violations=1
fi

if ! rg -n 'update_gitops requires build_openedx=true and build_mfe=true' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing manual dispatch gate requiring both builds for deterministic digest capture"
  violations=1
fi

if ! rg -n -- '--target-env "\$\{TARGET_ENV\}"' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ release-openedx-gitops.sh is not called with explicit --target-env"
  violations=1
fi

if ! rg -n -- '--openedx-digest "\$\{OPENEDX_DIGEST\}"' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ release-openedx-gitops.sh is not called with --openedx-digest"
  violations=1
fi

if ! rg -n -- '--mfe-digest "\$\{MFE_DIGEST\}"' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ release-openedx-gitops.sh is not called with --mfe-digest"
  violations=1
fi

if ! rg -n -- '--require-digests' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ release-openedx-gitops.sh is not called with --require-digests"
  violations=1
fi

# Build workflow must not publish mutable latest tags to Artifact Registry.
if rg -n 'docker push .*:latest([[:space:]]|$)' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ build workflow publishes mutable :latest tags"
  violations=1
fi

if rg -n '\$\{\{[[:space:]]*env\.REGISTRY[[:space:]]*\}\}/(openedx|mfe):latest' "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ build workflow tags Artifact Registry images as :latest"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Build workflow contract failed."
  exit 1
fi

echo "✅ Build workflow contract passed."
