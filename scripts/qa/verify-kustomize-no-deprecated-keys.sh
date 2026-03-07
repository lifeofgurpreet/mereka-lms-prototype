#!/usr/bin/env bash
# @covers AC-001
# @spec: k8s-deployment_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"

echo "Checking kustomization files for deprecated keys..."

pattern='^[[:space:]]*(patchesStrategicMerge|patchesJson6902|commonLabels):'

TMP_MATCH_FILE="$(mktemp -t kustomize-deprecated-keys.XXXXXX)"
if rg -n "$pattern" "$REPO_ROOT/deploy/k8s" -g 'kustomization.yaml' >"$TMP_MATCH_FILE"; then
  echo "❌ Deprecated kustomize keys found:"
  sed 's/^/  /' "$TMP_MATCH_FILE"
  rm -f "$TMP_MATCH_FILE"
  exit 1
fi

rm -f "$TMP_MATCH_FILE"
echo "✅ Kustomize deprecation key check passed."
