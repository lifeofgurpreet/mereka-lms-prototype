#!/usr/bin/env bash
# @covers AC-001
# @spec: k8s-deployment_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "Checking kustomization files for deprecated keys..."

pattern='^[[:space:]]*(patchesStrategicMerge|patchesJson6902|commonLabels):'

if rg -n "$pattern" "$REPO_ROOT/deploy/k8s" -g 'kustomization.yaml' >/tmp/kustomize-deprecated-keys.txt; then
  echo "❌ Deprecated kustomize keys found:"
  sed 's/^/  /' /tmp/kustomize-deprecated-keys.txt
  rm -f /tmp/kustomize-deprecated-keys.txt
  exit 1
fi

rm -f /tmp/kustomize-deprecated-keys.txt
echo "✅ Kustomize deprecation key check passed."
