#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! git diff --quiet -- docs/adr/_generated docs/adr/README.md; then
  echo "ADR_GENERATED_DRIFT_FAIL"
  echo "- generated ADR artifacts are out of sync with manifest/source ADR metadata"
  echo "- run:"
  echo "  python3 scripts/qa/build_decision_graph.py"
  echo "  python3 scripts/qa/generate_adr_readme.py"
  echo "  git add docs/adr/_generated docs/adr/README.md"
  exit 1
fi

echo "ADR_GENERATED_DRIFT_OK"
