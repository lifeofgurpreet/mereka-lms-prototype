#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "=== Wave 4 Knowledge Integrity Gates ==="

run() {
  echo "-> $*"
  "$@"
}

run python3 tools/knowledge/report_knowledge_control_plane.py --repo-root .
run python3 tools/knowledge/build_knowledge_catalog.py --check --repo-root .
run python3 tools/knowledge/build_knowledge_graph.py --check --repo-root .
run python3 tools/knowledge/build_wrapper_retirement_ledger.py --check --repo-root .
run python3 tools/specs/report_spec_metadata_coverage.py --repo-root .
run python3 tools/specs/verify_spec_frontmatter.py --repo-root .
run python3 tools/specs/verify_spec_taxonomy.py --repo-root .
run python3 tools/specs/verify_spec_paths.py --repo-root .
run python3 tools/specs/verify_docs_specs_boundary.py --repo-root .
run python3 scripts/qa/spec-tools/build_spec_catalog.py --check --repo-root .
run python3 tools/docs/verify/build-doc-catalog.py --root . --check
run bash tools/docs/verify/verify-docs-policy.sh --range origin/main...HEAD
run python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD

echo "KNOWLEDGE_INTEGRITY_GATES_OK"
