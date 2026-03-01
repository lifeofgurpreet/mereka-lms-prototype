#!/usr/bin/env bash
# verify-a11y-runtime-lane-contract.sh — guard the canonical a11y wrapper + Makefile wiring.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WRAPPER="$REPO_ROOT/scripts/qa/run-a11y-runtime-lane.sh"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-accessibility.sh"
MAKEFILE="$REPO_ROOT/Makefile"

echo "Checking a11y runtime lane contract..."

violations=0

if [[ ! -x "$WRAPPER" ]]; then
  echo "❌ Missing executable wrapper: scripts/qa/run-a11y-runtime-lane.sh"
  violations=1
fi

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "❌ Missing executable verifier: scripts/qa/verify-accessibility.sh"
  violations=1
fi

if [[ -x "$WRAPPER" ]]; then
  if ! rg -n -- '--mode <offline\|online\|hybrid>' "$WRAPPER" >/dev/null; then
    echo "❌ Wrapper usage missing offline|online|hybrid mode contract"
    violations=1
  fi
  if ! rg -n -- 'exec "\$VERIFY_SCRIPT"' "$WRAPPER" >/dev/null; then
    echo "❌ Wrapper does not delegate to verify-accessibility.sh"
    violations=1
  fi
fi

if [[ -f "$MAKEFILE" ]]; then
  for target in qa-a11y-prod qa-a11y-dev qa-a11y-prod-online qa-a11y-dev-online qa-a11y-prod-hybrid qa-a11y-dev-hybrid; do
    if ! rg -n "^${target}:" "$MAKEFILE" >/dev/null; then
      echo "❌ Makefile missing target: ${target}"
      violations=1
    fi
  done

  if ! rg -n --fixed-strings './scripts/qa/run-a11y-runtime-lane.sh --env prod --mode offline' "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile target qa-a11y-prod is not wired to --env prod --mode offline"
    violations=1
  fi
  if ! rg -n --fixed-strings './scripts/qa/run-a11y-runtime-lane.sh --env dev --mode offline' "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile target qa-a11y-dev is not wired to --env dev --mode offline"
    violations=1
  fi
  if ! rg -n --fixed-strings './scripts/qa/run-a11y-runtime-lane.sh --env prod --mode online' "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile target qa-a11y-prod-online is not wired to --env prod --mode online"
    violations=1
  fi
  if ! rg -n --fixed-strings './scripts/qa/run-a11y-runtime-lane.sh --env dev --mode online' "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile target qa-a11y-dev-online is not wired to --env dev --mode online"
    violations=1
  fi
  if ! rg -n --fixed-strings './scripts/qa/run-a11y-runtime-lane.sh --env prod --mode hybrid --allow-missing-reports' "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile target qa-a11y-prod-hybrid is not wired to --env prod --mode hybrid --allow-missing-reports"
    violations=1
  fi
  if ! rg -n --fixed-strings './scripts/qa/run-a11y-runtime-lane.sh --env dev --mode hybrid --allow-missing-reports' "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile target qa-a11y-dev-hybrid is not wired to --env dev --mode hybrid --allow-missing-reports"
    violations=1
  fi

  if ! rg -n 'run-a11y-runtime-lane\.sh' "$MAKEFILE" >/dev/null; then
    echo "❌ Makefile a11y targets are not wired through run-a11y-runtime-lane.sh"
    violations=1
  fi
else
  echo "❌ Missing Makefile"
  violations=1
fi

if [[ "$violations" -ne 0 ]]; then
  echo "A11y runtime lane contract failed."
  exit 1
fi

echo "✅ A11y runtime lane contract passed."
