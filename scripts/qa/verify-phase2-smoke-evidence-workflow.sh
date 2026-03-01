#!/usr/bin/env bash
# verify-phase2-smoke-evidence-workflow.sh — contract for phase2-smoke-evidence workflow wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="$REPO_ROOT/.github/workflows/phase2-smoke-evidence.yml"

echo "Checking phase2-smoke-evidence workflow contract..."

violations=0

if [[ ! -f "$WORKFLOW" ]]; then
  echo "❌ Missing workflow: .github/workflows/phase2-smoke-evidence.yml"
  exit 1
fi

if ! rg -n 'workflow_dispatch:' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing workflow_dispatch trigger"
  violations=1
fi

if ! rg -n '^[[:space:]]+target_environment:' "$WORKFLOW" >/dev/null \
  || ! rg -n '^[[:space:]]+- prod$' "$WORKFLOW" >/dev/null \
  || ! rg -n '^[[:space:]]+- dev$' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing target_environment input contract (prod/dev)"
  violations=1
fi

if ! rg -n '^[[:space:]]+capture_screenshots:' "$WORKFLOW" >/dev/null \
  || ! rg -n 'default:[[:space:]]+false' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing capture_screenshots boolean contract"
  violations=1
fi

if ! rg -n 'runs-on:[[:space:]]+ubuntu-24\.04' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow must run on ubuntu-24.04"
  violations=1
fi

if ! rg -n 'timeout-minutes:[[:space:]]+45' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing timeout-minutes: 45 contract"
  violations=1
fi

if ! rg -n 'actions/checkout@[0-9a-f]{40}' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow must pin actions/checkout to a full commit SHA"
  violations=1
fi

if ! rg -n './scripts/qa/verify-npm-start-mfe-smoke\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-npm-start-mfe-smoke invocation"
  violations=1
fi

if ! rg -n './scripts/qa/verify-paragon-runtime\.sh' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing verify-paragon-runtime preflight invocation"
  violations=1
fi

if ! rg -n -- '--runtime-url https://apps\.academyv2\.mereka\.io|--runtime-url https://apps\.academyv2\.mereka\.dev' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing runtime-url wiring for prod/dev preflight"
  violations=1
fi

if ! rg -n -- '--require-slot-markers' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing preflight slot-marker requirement wiring"
  violations=1
fi

if ! rg -n './scripts/qa/capture-branding-screenshots\.sh --env prod --mfe-only' "$WORKFLOW" >/dev/null \
  || ! rg -n './scripts/qa/capture-branding-screenshots\.sh --env dev --mfe-only' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing screenshot capture command wiring for prod/dev"
  violations=1
fi

if ! rg -n 'if \[\[ "\$CAPTURE_SCREENSHOTS" == "true" \]\]' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing conditional screenshot capture guard"
  violations=1
fi

if ! rg -n 'actions/upload-artifact@v4' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing artifact upload step"
  violations=1
fi

if ! rg -n 'var/qa/phase2-smoke-evidence\.log' "$WORKFLOW" >/dev/null; then
  echo "❌ workflow missing phase2-smoke-evidence.log artifact path"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Phase2-smoke-evidence workflow contract failed."
  exit 1
fi

echo "✅ Phase2-smoke-evidence workflow contract passed."
