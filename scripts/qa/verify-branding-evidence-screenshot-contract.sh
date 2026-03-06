#!/usr/bin/env bash
# @spec: branding-system_spec.md
# @covers AC-BRAND-EVIDENCE-002
# verify-branding-evidence-screenshot-contract.sh
# Guard screenshot-scope contract across branding evidence pipeline + closure workflow.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PIPELINE="$REPO_ROOT/scripts/qa/run-branding-evidence-pipeline.sh"
CAPTURE_SCRIPT="$REPO_ROOT/scripts/qa/capture-branding-screenshots.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/frontend-branding-closure.yml"

echo "Checking branding evidence screenshot-scope contract..."

violations=0

if [[ ! -x "$PIPELINE" ]]; then
  echo "❌ Missing pipeline script: scripts/qa/run-branding-evidence-pipeline.sh"
  violations=1
fi

if [[ ! -x "$CAPTURE_SCRIPT" ]]; then
  echo "❌ Missing screenshot capture script: scripts/qa/capture-branding-screenshots.sh"
  violations=1
fi

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: .github/workflows/frontend-branding-closure.yml"
  violations=1
fi

if [[ "$violations" -eq 0 ]]; then
  if ! rg -n --fixed-strings './scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only' "$CAPTURE_SCRIPT" >/dev/null; then
    echo "❌ capture-branding-screenshots usage missing --mfe-only contract example"
    violations=1
  fi

  if ! rg -n -- '--mfe-only' "$CAPTURE_SCRIPT" >/dev/null; then
    echo "❌ capture-branding-screenshots missing --mfe-only option handling"
    violations=1
  fi

  if ! rg -n 'if \[\[ "\$MFE_ONLY" == "1" \]\]' "$CAPTURE_SCRIPT" >/dev/null; then
    echo "❌ capture-branding-screenshots missing MFE-only URL branch contract"
    violations=1
  fi

  if ! rg -n 'capture-branding-screenshots\.sh[[:space:]]+prod' "$CAPTURE_SCRIPT" >/dev/null \
    || ! rg -n 'capture-branding-screenshots\.sh[[:space:]]+dev' "$CAPTURE_SCRIPT" >/dev/null; then
    echo "❌ capture-branding-screenshots missing prod/dev back-compat invocation examples"
    violations=1
  fi

  if ! rg -n 'SCREENSHOT_SCOPE="\$\{SCREENSHOT_SCOPE:-full\}"' "$PIPELINE" >/dev/null; then
    echo "❌ Pipeline missing SCREENSHOT_SCOPE default (full)"
    violations=1
  fi

  if ! rg -n 'SCREENSHOT_SCOPE=full\|mfe-only' "$PIPELINE" >/dev/null; then
    echo "❌ Pipeline usage text missing SCREENSHOT_SCOPE value contract"
    violations=1
  fi

  if ! rg -n 'SCREENSHOT_SCOPE must be full or mfe-only' "$PIPELINE" >/dev/null; then
    echo "❌ Pipeline missing SCREENSHOT_SCOPE runtime validation"
    violations=1
  fi

  if ! rg -n 'capture-branding-screenshots\.sh "\$\{screenshot_args\[@\]\}"' "$PIPELINE" >/dev/null; then
    echo "❌ Pipeline screenshot gate missing array-based screenshot arg wiring"
    violations=1
  fi

  if ! rg -n 'screenshot_args=\(--env "\$ENV" --mfe-only\)' "$PIPELINE" >/dev/null; then
    echo "❌ Pipeline missing mfe-only screenshot arg wiring"
    violations=1
  fi

  if ! rg -n 'Screenshot scope: \$\{SCREENSHOT_SCOPE\}' "$PIPELINE" >/dev/null; then
    echo "❌ Pipeline summary missing screenshot scope line"
    violations=1
  fi
fi

if [[ "$violations" -eq 0 ]]; then
  if ! rg -n '^[[:space:]]+screenshot_scope:' "$WORKFLOW" >/dev/null; then
    echo "❌ Closure workflow missing screenshot_scope input"
    violations=1
  fi

  if ! rg -n '^[[:space:]]+- full$' "$WORKFLOW" >/dev/null \
    || ! rg -n '^[[:space:]]+- mfe-only$' "$WORKFLOW" >/dev/null; then
    echo "❌ Closure workflow screenshot_scope options missing full or mfe-only"
    violations=1
  fi

  if ! rg -n 'SCREENSHOT_SCOPE="\$\{\{ inputs\.screenshot_scope \|\| '\''full'\'' \}\}"' "$WORKFLOW" >/dev/null; then
    echo "❌ Closure workflow missing screenshot_scope shell variable wiring"
    violations=1
  fi

  if ! rg -n 'SCREENSHOT_SCOPE="\$SCREENSHOT_SCOPE"' "$WORKFLOW" >/dev/null; then
    echo "❌ Closure workflow missing SCREENSHOT_SCOPE env handoff to pipeline"
    violations=1
  fi
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Branding evidence screenshot-scope contract failed."
  exit 1
fi

echo "✅ Branding evidence screenshot-scope contract passed."
