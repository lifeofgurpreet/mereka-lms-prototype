#!/usr/bin/env bash
# @covers AC-001
# @spec: k8s-deployment_spec.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "${SCRIPT_DIR}/../.." && pwd)}"
SCOPE_MODE="${VERIFY_KUSTOMIZE_NO_DEPRECATED_KEYS_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_KUSTOMIZE_NO_DEPRECATED_KEYS_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "${CHANGED_FILES_RAW//[[:space:]]/}" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      deploy/k8s/*|\
      scripts/qa/verify-kustomize-no-deprecated-keys.sh)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-kustomize-no-deprecated-keys (scope skip: no deprecated-kustomize-key-relevant changes)"
  exit 0
fi

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
