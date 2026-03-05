#!/usr/bin/env bash
# @covers AC-CI-020
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG_JSON="$REPO_ROOT/docs/operations/verification/verification_catalog.json"
CATALOG_MD="$REPO_ROOT/docs/operations/verification/VERIFICATION_CATALOG.md"

if [[ ! -f "$CATALOG_JSON" ]]; then
  echo "FAIL verification catalog JSON missing: $CATALOG_JSON" >&2
  exit 1
fi
if [[ ! -f "$CATALOG_MD" ]]; then
  echo "FAIL verification catalog markdown missing: $CATALOG_MD" >&2
  exit 1
fi

python3 "$REPO_ROOT/scripts/qa/generate-verification-catalog.py" --check

echo "PASS verification catalog is present and up to date"
