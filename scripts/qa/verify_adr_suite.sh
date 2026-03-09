#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

python3 scripts/qa/verify_adr_manifest.py
python3 scripts/qa/verify_adr_frontmatter.py
python3 scripts/qa/generate_adr_aux_maps.py
python3 scripts/qa/verify_adr_aux_maps.py
python3 scripts/qa/verify_adr_readme.py
python3 scripts/qa/verify_exception_expiry.py
python3 scripts/qa/verify_adr_links.py
python3 scripts/qa/build_decision_graph.py
python3 scripts/qa/generate_adr_readme.py
scripts/qa/verify_adr_generated_clean.sh
python3 scripts/qa/resolve_adr_impact.py --changed-file docs/adr/manifest.yaml >/dev/null

echo "ADR_SUITE_OK"
