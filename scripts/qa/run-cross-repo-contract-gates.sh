#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
RANGE_SPEC="${CONTRACT_RUNTIME_RANGE:-${KNOWLEDGE_RUNTIME_RANGE:-${DOCS_POLICY_RANGE:-origin/main...HEAD}}}"

echo "=== Wave 6 Cross-Repo Contract Gates ==="

run() {
  echo "-> $*"
  "$@"
}

run python3 tools/contracts/build_cross_repo_manifest.py --check --range "$RANGE_SPEC" --repo-root .
run python3 tools/contracts/build_deployment_impact_report.py --check --range "$RANGE_SPEC" --repo-root .
run python3 tools/contracts/build_release_obligations.py --check --range "$RANGE_SPEC" --repo-root .
run python3 tools/contracts/verify_cross_repo_contracts.py --range "$RANGE_SPEC" --repo-root .

echo "CROSS_REPO_CONTRACT_GATES_OK"
