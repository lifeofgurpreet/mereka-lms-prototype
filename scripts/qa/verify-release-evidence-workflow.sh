#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/release-evidence.yml"

echo "Checking release evidence workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: ${WORKFLOW#"$REPO_ROOT"/}"
  exit 1
fi

if [[ ! -x "$REPO_ROOT/scripts/infra/resolve-image-digest.sh" ]]; then
  echo "❌ Missing executable digest helper: scripts/infra/resolve-image-digest.sh"
  violations=1
fi

if ! rg -n './scripts/infra/resolve-image-digest\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow does not use scripts/infra/resolve-image-digest.sh"
  violations=1
fi

if ! rg -n -- '--output-key openedx_digest' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing openedx digest output wiring"
  violations=1
fi

if ! rg -n -- '--output-key mfe_digest' "$WORKFLOW" >/dev/null; then
  echo "❌ release-evidence workflow missing mfe digest output wiring"
  violations=1
fi

if ! rg -n -- '--openedx-digest "\$\{\{ steps\.digests\.outputs\.openedx_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release dry-run call missing --openedx-digest"
  violations=1
fi

if ! rg -n -- '--mfe-digest "\$\{\{ steps\.digests\.outputs\.mfe_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release dry-run call missing --mfe-digest"
  violations=1
fi

if ! rg -n -- '--require-digests' "$WORKFLOW" >/dev/null; then
  echo "❌ release dry-run call missing --require-digests"
  violations=1
fi

if ! rg -n '"openedx_digest": "\$\{\{ steps\.digests\.outputs\.openedx_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing openedx_digest"
  violations=1
fi

if ! rg -n '"mfe_digest": "\$\{\{ steps\.digests\.outputs\.mfe_digest \}\}"' "$WORKFLOW" >/dev/null; then
  echo "❌ release metadata missing mfe_digest"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Release evidence workflow contract failed."
  exit 1
fi

echo "✅ Release evidence workflow contract passed."
