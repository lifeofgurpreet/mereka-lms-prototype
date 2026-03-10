#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

python3 tools/docs/build_domain_access_reference.py --check --repo-root .
python3 tools/docs/build_team_topology_reference.py --check --repo-root .
python3 tools/docs/verify/verify_team_handbook.py --repo-root .
python3 tools/docs/verify/verify-doc-catalog-governance.py --range "${DOCS_POLICY_RANGE:-origin/main...HEAD}"

echo "TEAM_HANDBOOK_GATES_OK"
