#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

python3 tools/skills/build_skill_registry.py --check --repo-root .
python3 tools/skills/build_command_registry.py --check --repo-root .
python3 tools/skills/build_scenario_packs.py --check --repo-root .
python3 tools/skills/build_skill_dependency_graph.py --check --repo-root .
python3 tools/skills/build_skill_abi_maps.py --check --repo-root .
python3 tools/skills/build_pack_registry.py --check --repo-root .
python3 tools/skills/build_runtime_convergence_report.py --check --repo-root .
python3 tools/skills/verify_agent_pack_schemas.py --repo-root .
python3 tools/skills/verify_skill_runtime.py --repo-root .
python3 tools/skills/verify_agent_pack_runtime.py --repo-root .
python3 tools/docs/verify/verify-doc-catalog-governance.py --range "${DOCS_POLICY_RANGE:-origin/main...HEAD}"

echo "AGENT_PACK_RUNTIME_GATES_OK"
