#!/usr/bin/env bash
# verify-make-help-contract.sh — enforce Makefile help discoverability contract.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"

echo "Checking Makefile help contract..."

violations=0

if [[ ! -f "$MAKEFILE" ]]; then
  echo "❌ Missing Makefile"
  exit 1
fi

# Guard the regex used by the help target so numeric targets remain visible.
help_pattern="$(cat <<'PAT'
@grep -E '^[a-zA-Z0-9_.-]+:.*?## .*$$'
PAT
)"
if ! grep -Fq -- "$help_pattern" "$MAKEFILE"; then
  echo "❌ Makefile help regex does not include numeric target support"
  violations=1
fi

HELP_OUTPUT="$(make help 2>/dev/null || true)"
if [[ -z "$HELP_OUTPUT" ]]; then
  echo "❌ make help produced no output"
  violations=1
else
  for required in \
    "qa-phase7-dom-audit-full-strict" \
    "qa-phase7-selector-coverage" \
    "qa-phase2-smoke-evidence-prod" \
    "qa-phase2-smoke-evidence-contract" \
    "qa-paragon-theme-budget" \
    "qa-frontend-extended-surfaces" \
    "qa-frontend-runtime-qa-prod" \
    "qa-npm-start-smoke-prod" \
    "qa-frontend-closure-dev-screenshots-mfe" \
    "qa-frontend-contracts"; do
    if ! grep -Fq -- "$required" <<<"$HELP_OUTPUT"; then
      echo "❌ make help missing target entry: $required"
      violations=1
    fi
  done

  qa_line_count="$(grep -cE '^[[:space:]]+qa-' <<<"$HELP_OUTPUT" || true)"
  if [[ "$qa_line_count" -lt 12 ]]; then
    echo "❌ make help exposes too few qa-* targets ($qa_line_count; expected >= 12)"
    violations=1
  fi
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Makefile help contract failed."
  exit 1
fi

echo "✅ Makefile help contract passed."
