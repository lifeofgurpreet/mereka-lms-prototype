#!/usr/bin/env bash
# Standalone gate: no generated Python artifacts under deploy/k8s/
#
# Detects __pycache__ directories and *.pyc files.
# These are build artifacts that should never be committed to the deploy tree.
#
# Usage:
#   scripts/qa/no_generated_python_artifacts.sh [SCOPE_DIR]
#   Default SCOPE_DIR: deploy/k8s/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCOPE_DIR="${1:-${REPO_ROOT}/deploy/k8s}"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

hits=0

# Find __pycache__ directories
while IFS= read -r -d '' dir; do
  echo -e "${RED}[FAIL]${NC} __pycache__ directory found: $dir"
  hits=$((hits + 1))
done < <(find "$SCOPE_DIR" -type d -name "__pycache__" -print0 2>/dev/null)

# Find *.pyc files
while IFS= read -r -d '' f; do
  echo -e "${RED}[FAIL]${NC} Compiled Python artifact: $f"
  hits=$((hits + 1))
done < <(find "$SCOPE_DIR" -type f -name "*.pyc" -print0 2>/dev/null)

if [[ $hits -gt 0 ]]; then
  echo ""
  echo -e "${RED}FAIL${NC}: $hits Python artifact(s) found in $SCOPE_DIR"
  echo "      Remove with: find $SCOPE_DIR -name '__pycache__' -o -name '*.pyc' | xargs rm -rf"
  exit 1
fi

echo -e "${GREEN}PASS${NC}: No generated Python artifacts found in $SCOPE_DIR"
