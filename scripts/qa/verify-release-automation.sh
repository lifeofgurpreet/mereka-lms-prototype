#!/usr/bin/env bash
# @covers AC-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"
RELEASE_SCRIPT="$REPO_ROOT/scripts/infra/release-openedx-gitops.sh"
BUILD_WORKFLOW="$WORKFLOWS_DIR/build-tutor-images.yml"
BUILD_WORKFLOW_CONTRACT="$REPO_ROOT/scripts/qa/verify-build-workflow-contract.sh"
RELEASE_INVOKE_CHECKER="$REPO_ROOT/scripts/qa/verify-release-workflow-invocation.sh"
RELEASE_DRY_RUN_CHECKER="$REPO_ROOT/scripts/qa/verify-release-dry-run-contract.sh"
RELEASE_EVIDENCE_WORKFLOW_CHECKER="$REPO_ROOT/scripts/qa/verify-release-evidence-workflow.sh"

echo "Checking release automation contract for explicit target environment..."

violations=0

# Any workflow invoking release-openedx-gitops.sh must pass --target-env.
while IFS= read -r workflow_file; do
  if rg -n '\./scripts/infra/release-openedx-gitops\.sh' "$workflow_file" >/dev/null; then
    if ! rg -n -- '--target-env' "$workflow_file" >/dev/null; then
      echo "❌ Missing --target-env in workflow ${workflow_file#"$REPO_ROOT"/}"
      violations=1
    fi
  fi
done < <(find "$WORKFLOWS_DIR" -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

# build-tutor-images must force explicit target selection during manual dispatch.
if ! rg -n "target_environment:" "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ Missing target_environment input in ${BUILD_WORKFLOW#"$REPO_ROOT"/}"
  violations=1
fi
if ! rg -n "default:[[:space:]]*select-environment" "$BUILD_WORKFLOW" >/dev/null; then
  echo "❌ target_environment default is not select-environment in ${BUILD_WORKFLOW#"$REPO_ROOT"/}"
  violations=1
fi

# release-openedx script must enforce explicit --target-env in CI mode.
if ! rg -n 'TARGET_ENV_SET' "$RELEASE_SCRIPT" >/dev/null; then
  echo "❌ Missing TARGET_ENV_SET guard variable in ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  violations=1
fi
if ! rg -n 'CI mode requires explicit --target-env' "$RELEASE_SCRIPT" >/dev/null; then
  echo "❌ Missing CI explicit --target-env guard in ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  violations=1
fi
if ! rg -n 'CI production apply requires both --openedx-digest and --mfe-digest' "$RELEASE_SCRIPT" >/dev/null; then
  echo "❌ Missing CI production digest safety gate in ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  violations=1
fi

# release-openedx script should support optional digest pinning flags.
if ! rg -n -- '--openedx-digest' "$RELEASE_SCRIPT" >/dev/null; then
  echo "❌ Missing --openedx-digest support in ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  violations=1
fi
if ! rg -n -- '--mfe-digest' "$RELEASE_SCRIPT" >/dev/null; then
  echo "❌ Missing --mfe-digest support in ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  violations=1
fi
if ! rg -n -- '--require-digests' "$RELEASE_SCRIPT" >/dev/null; then
  echo "❌ Missing --require-digests support in ${RELEASE_SCRIPT#"$REPO_ROOT"/}"
  violations=1
fi

if [[ ! -f "$BUILD_WORKFLOW_CONTRACT" ]]; then
  echo "❌ Missing build workflow contract checker: ${BUILD_WORKFLOW_CONTRACT#"$REPO_ROOT"/}"
  violations=1
fi

if [[ ! -f "$RELEASE_INVOKE_CHECKER" ]]; then
  echo "❌ Missing release invocation checker: ${RELEASE_INVOKE_CHECKER#"$REPO_ROOT"/}"
  violations=1
fi

if [[ ! -f "$RELEASE_DRY_RUN_CHECKER" ]]; then
  echo "❌ Missing release dry-run checker: ${RELEASE_DRY_RUN_CHECKER#"$REPO_ROOT"/}"
  violations=1
fi

if [[ ! -f "$RELEASE_EVIDENCE_WORKFLOW_CHECKER" ]]; then
  echo "❌ Missing release evidence workflow checker: ${RELEASE_EVIDENCE_WORKFLOW_CHECKER#"$REPO_ROOT"/}"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Release automation contract failed."
  exit 1
fi

echo "✅ Release automation contract passed."
