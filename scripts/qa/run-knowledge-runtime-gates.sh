#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== Wave 5 Knowledge Runtime Gates ==="

run() {
  echo "-> $*"
  "$@"
}

run bash scripts/qa/run-knowledge-integrity-gates.sh
run python3 tools/knowledge/build_change_manifest.py --check --range origin/main...HEAD --repo-root .
run python3 tools/knowledge/build_review_bundle.py --check --range origin/main...HEAD --repo-root .
run python3 tools/knowledge/build_truth_impact_report.py --check --range origin/main...HEAD --repo-root .
run python3 tools/knowledge/build_wrapper_retirement_report.py --check --repo-root .
run python3 tools/knowledge/verify_knowledge_runtime.py --range origin/main...HEAD --repo-root .

echo "KNOWLEDGE_RUNTIME_GATES_OK"
