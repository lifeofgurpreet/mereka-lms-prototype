#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_PATH=".github/workflows/docs-compliance.yml"

if [ ! -f "$WORKFLOW_PATH" ]; then
  echo "missing workflow: $WORKFLOW_PATH"
  exit 1
fi

grep -q "name: Resolve docs base ref context" "$WORKFLOW_PATH"
grep -q 'DOCS_BASE_REF=${BASE_REF}' "$WORKFLOW_PATH"
grep -q 'DOCS_POLICY_RANGE=${POLICY_RANGE}' "$WORKFLOW_PATH"

BASE_REF_SOURCE_COUNT=$(grep -F -c 'BASE_REF="origin/${{ github.base_ref }}"' "$WORKFLOW_PATH")
if [ "$BASE_REF_SOURCE_COUNT" -ne 1 ]; then
  echo "expected exactly 1 BASE_REF source declaration, found $BASE_REF_SOURCE_COUNT"
  exit 1
fi

grep -q -- '--range "$DOCS_POLICY_RANGE"' "$WORKFLOW_PATH"
grep -q -- '--policy-range "$DOCS_POLICY_RANGE"' "$WORKFLOW_PATH"
grep -q -- '--base-ref "$DOCS_BASE_REF"' "$WORKFLOW_PATH"
grep -q 'git diff --name-only "$DOCS_POLICY_RANGE"' "$WORKFLOW_PATH"
grep -q 'echo "- base_ref=${DOCS_BASE_REF}"' "$WORKFLOW_PATH"
grep -q 'echo "- policy_range=${DOCS_POLICY_RANGE}"' "$WORKFLOW_PATH"

echo "verify-docs-compliance-workflow-contract self-test: OK"
