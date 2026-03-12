#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 tools/docs/build_adr_ledger.py --check
python3 tools/docs/verify/verify_adr_frontmatter.py --repo-root .
python3 tools/docs/verify/verify_adr_ledger_integrity.py --repo-root .
python3 tools/docs/verify/verify_adr_hot_path.py
python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD

echo "ADR_GATES_OK"
