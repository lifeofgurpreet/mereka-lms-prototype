#!/usr/bin/env bash
# verify-branding-evidence-a11y-contract.sh — enforce canonical a11y wiring in branding evidence pipeline.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PIPELINE="$REPO_ROOT/scripts/qa/run-branding-evidence-pipeline.sh"

echo "Checking branding evidence a11y contract..."

violations=0

if [[ ! -f "$PIPELINE" ]]; then
  echo "❌ Missing pipeline script: scripts/qa/run-branding-evidence-pipeline.sh"
  exit 1
fi

if ! rg -n 'A11Y_MODE=.*offline\|online\|hybrid|A11Y_MODE=' "$PIPELINE" >/dev/null; then
  echo "❌ Pipeline missing A11Y_MODE wiring"
  violations=1
fi

if ! rg -n 'A11Y_TARGET=' "$PIPELINE" >/dev/null; then
  echo "❌ Pipeline missing A11Y_TARGET wiring"
  violations=1
fi

if ! rg -n 'A11Y_ROUTES=' "$PIPELINE" >/dev/null; then
  echo "❌ Pipeline missing A11Y_ROUTES wiring"
  violations=1
fi

if ! rg -n 'A11Y_ALLOW_MISSING_REPORTS=' "$PIPELINE" >/dev/null; then
  echo "❌ Pipeline missing A11Y_ALLOW_MISSING_REPORTS wiring"
  violations=1
fi

if ! rg -n './scripts/qa/run-a11y-runtime-lane\.sh' "$PIPELINE" >/dev/null; then
  echo "❌ Pipeline does not invoke canonical run-a11y-runtime-lane.sh wrapper"
  violations=1
fi

if ! rg -n -- '--env \"\$ENV\" --mode \"\$A11Y_MODE\" --target-url \"\$A11Y_TARGET\"' "$PIPELINE" >/dev/null; then
  echo "❌ Pipeline missing explicit env/mode/target-url wrapper argument wiring"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Branding evidence a11y contract failed."
  exit 1
fi

echo "✅ Branding evidence a11y contract passed."
