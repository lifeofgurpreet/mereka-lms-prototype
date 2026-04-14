#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

RANGE="${AGENT_READINESS_RANGE:-${TASK_RUNTIME_RANGE:-${CONTRACT_RUNTIME_RANGE:-${KNOWLEDGE_RUNTIME_RANGE:-${DOCS_POLICY_RANGE:-origin/main...HEAD}}}}}"
AGENT_BUNDLE_DIR="generated/knowledge/agent-task-bundles"

echo "=== Wave 8 Agent Readiness Gates ==="
echo "-> python3 tools/knowledge/build_agent_entrypoints.py --check --repo-root ."
python3 tools/knowledge/build_agent_entrypoints.py --check --repo-root .
echo "-> python3 tools/knowledge/build_agent_task_bundles.py --check --repo-root . --range ${RANGE} --output-dir ${AGENT_BUNDLE_DIR}"
python3 tools/knowledge/build_agent_task_bundles.py --check --repo-root . --range "${RANGE}" --output-dir "${AGENT_BUNDLE_DIR}"
echo "-> python3 tools/knowledge/build_agent_readiness_report.py --check --repo-root . --range ${RANGE}"
python3 tools/knowledge/build_agent_readiness_report.py --check --repo-root . --range "${RANGE}"
echo "-> python3 tools/knowledge/verify_agent_consumption_runtime.py --repo-root . --range ${RANGE}"
python3 tools/knowledge/verify_agent_consumption_runtime.py --repo-root . --range "${RANGE}"
echo "-> bash scripts/qa/run-knowledge-runtime-gates.sh"
bash scripts/qa/run-knowledge-runtime-gates.sh
echo "-> bash scripts/qa/run-cross-repo-contract-gates.sh"
bash scripts/qa/run-cross-repo-contract-gates.sh
echo "-> python3 tools/docs/verify/verify-doc-catalog-governance.py --range ${RANGE}"
python3 tools/docs/verify/verify-doc-catalog-governance.py --range "${RANGE}"
echo "AGENT_READINESS_GATES_OK"
