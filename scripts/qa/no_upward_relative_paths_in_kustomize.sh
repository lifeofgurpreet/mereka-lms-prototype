#!/usr/bin/env bash
# Standalone gate: no upward path traversal (../../../) in kustomization files
#
# Kustomize resources/ and patches/ paths that escape the deploy/k8s/ subtree
# via ../../.. traversal break deploy-package portability. All referenced files
# must live within the deploy package boundary.
#
# Usage:
#   scripts/qa/no_upward_relative_paths_in_kustomize.sh [SCOPE_DIR]
#   Default SCOPE_DIR: deploy/k8s/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_DIR="${1:-${REPO_ROOT}/deploy/k8s}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

hits=0

results=""
set +e
results=$(rg -n \
  --glob 'kustomization.yaml' \
  --glob 'kustomization.yml' \
  -- '\.\./\.\./\.\.' "$SCOPE_DIR" 2>/dev/null)
rc=$?
set -e

if [[ $rc -ne 0 && $rc -ne 1 ]]; then
  echo "rg error (rc=$rc)" >&2
  exit "$rc"
fi

if [[ -n "$results" ]]; then
  echo -e "${RED}[FAIL]${NC} Upward path traversal found in kustomization files:"
  while IFS= read -r line; do
    echo "  $line"
    hits=$((hits + 1))
  done <<< "$results"
fi

if [[ $hits -gt 0 ]]; then
  echo ""
  echo -e "${RED}FAIL${NC}: $hits upward path traversal reference(s) found in $SCOPE_DIR"
  echo "      References must stay within the deploy/k8s/ subtree."
  exit 1
fi

echo -e "${GREEN}PASS${NC}: No upward path traversal found in kustomization files under $SCOPE_DIR"
