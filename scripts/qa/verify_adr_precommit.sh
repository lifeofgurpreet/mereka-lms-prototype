#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

changed="$(git diff --cached --name-only --diff-filter=ACMRTUXB || true)"
if [[ -z "$changed" ]]; then
  exit 0
fi

if ! grep -qE '^(docs/adr/|docs/architecture/|docs/evidence/|docs/runbooks/|scripts/qa/verify_adr_|scripts/qa/build_decision_graph\.py|scripts/qa/resolve_adr_impact\.py)' <<<"$changed"; then
  exit 0
fi

echo "ADR pre-commit checks: running governance suite"
scripts/qa/verify_adr_suite.sh

echo ""
echo "ADR pre-commit checks: impacted ADRs from staged change set"
args=()
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  args+=(--changed-file "$f")
done <<<"$changed"
python3 scripts/qa/resolve_adr_impact.py "${args[@]}"
