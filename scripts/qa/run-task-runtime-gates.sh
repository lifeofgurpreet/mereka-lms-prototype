#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

RANGE="${TASK_RUNTIME_RANGE:-${KNOWLEDGE_RUNTIME_RANGE:-${DOCS_POLICY_RANGE:-origin/main...HEAD}}}"

echo "=== Wave 7 Task Runtime Gates ==="
echo "-> python3 tools/knowledge/build_task_bundle.py --repo-root . --range ${RANGE}"
python3 tools/knowledge/build_task_bundle.py --repo-root . --range "${RANGE}"
echo "-> python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range ${RANGE}"
python3 tools/knowledge/build_task_bundle.py --check --repo-root . --range "${RANGE}"
echo "-> python3 tools/knowledge/build_skill_index.py --repo-root . --range ${RANGE}"
python3 tools/knowledge/build_skill_index.py --repo-root . --range "${RANGE}"
echo "-> python3 tools/knowledge/build_skill_index.py --check --repo-root . --range ${RANGE}"
python3 tools/knowledge/build_skill_index.py --check --repo-root . --range "${RANGE}"
echo "-> python3 tools/knowledge/verify_task_runtime.py --repo-root . --range ${RANGE}"
python3 tools/knowledge/verify_task_runtime.py --repo-root . --range "${RANGE}"
echo "TASK_RUNTIME_GATES_OK"
