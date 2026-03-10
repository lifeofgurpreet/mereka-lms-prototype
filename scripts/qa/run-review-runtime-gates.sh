#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RANGE="${REVIEW_RUNTIME_RANGE:-${DOCS_POLICY_RANGE:-origin/main...HEAD}}"

python3 tools/docs/verify/build-doc-catalog.py --check --root .
python3 tools/knowledge/build_wave9_findings_ledger.py --check --repo-root .
python3 tools/docs/verify/verify_temporal_integrity.py
python3 tools/docs/verify/verify_generated_navigation.py
bash scripts/qa/verify-release-automation.sh
bash scripts/qa/verify-release-workflow-invocation.sh
python3 tools/knowledge/verify_review_runtime.py --repo-root . --range "$RANGE"
python3 tools/docs/verify/verify-doc-catalog-governance.py --range "$RANGE"

echo "REVIEW_RUNTIME_GATES_OK"
