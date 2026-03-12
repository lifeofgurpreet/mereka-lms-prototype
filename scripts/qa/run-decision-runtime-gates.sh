#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

RANGE="${DOCS_POLICY_RANGE:-origin/main...HEAD}"

python3 tools/knowledge/build_review_decision.py --check --repo-root . --range "$RANGE"
python3 tools/knowledge/build_reviewer_obligations.py --check --repo-root .
python3 tools/knowledge/build_evidence_obligations.py --check --repo-root .
python3 tools/knowledge/build_read_first_packs.py --check --repo-root .
python3 tools/knowledge/build_release_readiness.py --check --repo-root .
python3 tools/knowledge/build_runtime_evaluation.py --check --repo-root .
python3 tools/knowledge/verify_decision_runtime.py --repo-root . --range "$RANGE"
python3 tools/docs/verify/verify-doc-catalog-governance.py --range "$RANGE"

echo "DECISION_RUNTIME_GATES_OK"
