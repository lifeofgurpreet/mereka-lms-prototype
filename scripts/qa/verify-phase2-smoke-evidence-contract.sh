#!/usr/bin/env bash
# verify-phase2-smoke-evidence-contract.sh — enforce Phase 2 smoke-evidence make lane contract.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MAKEFILE="$REPO_ROOT/Makefile"

echo "Checking Phase 2 smoke-evidence contract..."

violations=0

fail() {
  echo "❌ $*"
  violations=1
}

pass() {
  echo "✅ $*"
}

if [[ ! -f "$MAKEFILE" ]]; then
  echo "❌ Missing Makefile"
  exit 1
fi

if rg -n '^qa-phase2-smoke-evidence-prod:' "$MAKEFILE" >/dev/null; then
  pass "Makefile exposes qa-phase2-smoke-evidence-prod target"
else
  fail "Makefile missing qa-phase2-smoke-evidence-prod target"
fi

if rg -n '^qa-phase2-smoke-evidence-dev:' "$MAKEFILE" >/dev/null; then
  pass "Makefile exposes qa-phase2-smoke-evidence-dev target"
else
  fail "Makefile missing qa-phase2-smoke-evidence-dev target"
fi

if rg -n --fixed-strings './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --require-runtime-theme --require-branding-markers' "$MAKEFILE" >/dev/null; then
  pass "Prod phase2 lane enforces runtime-theme smoke gate"
else
  fail "Prod phase2 lane missing runtime-theme smoke gate"
fi

if rg -n --fixed-strings './scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.io --require-runtime --require-slot-markers' "$MAKEFILE" >/dev/null; then
  pass "Prod phase2 lane enforces runtime preflight gate"
else
  fail "Prod phase2 lane missing runtime preflight gate"
fi

if rg -n --fixed-strings './scripts/qa/capture-branding-screenshots.sh --env prod --mfe-only' "$MAKEFILE" >/dev/null; then
  pass "Prod phase2 lane captures MFE-only screenshots"
else
  fail "Prod phase2 lane missing MFE-only screenshot capture"
fi

if rg -n --fixed-strings './scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.dev --require-branding-markers' "$MAKEFILE" >/dev/null; then
  pass "Dev phase2 lane enforces branding-marker smoke gate"
else
  fail "Dev phase2 lane missing branding-marker smoke gate"
fi

if rg -n --fixed-strings './scripts/qa/verify-paragon-runtime.sh --runtime-url https://apps.academyv2.mereka.dev --require-slot-markers' "$MAKEFILE" >/dev/null; then
  pass "Dev phase2 lane enforces runtime preflight gate"
else
  fail "Dev phase2 lane missing runtime preflight gate"
fi

if rg -n --fixed-strings './scripts/qa/capture-branding-screenshots.sh --env dev --mfe-only' "$MAKEFILE" >/dev/null; then
  pass "Dev phase2 lane captures MFE-only screenshots"
else
  fail "Dev phase2 lane missing MFE-only screenshot capture"
fi

HELP_OUTPUT="$(make help 2>/dev/null || true)"
if [[ -z "$HELP_OUTPUT" ]]; then
  fail "make help produced no output"
else
  if grep -Fq 'qa-phase2-smoke-evidence-prod' <<<"$HELP_OUTPUT"; then
    pass "make help includes qa-phase2-smoke-evidence-prod"
  else
    fail "make help missing qa-phase2-smoke-evidence-prod"
  fi
  if grep -Fq 'qa-phase2-smoke-evidence-dev' <<<"$HELP_OUTPUT"; then
    pass "make help includes qa-phase2-smoke-evidence-dev"
  else
    fail "make help missing qa-phase2-smoke-evidence-dev"
  fi
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Phase 2 smoke-evidence contract failed."
  exit 1
fi

echo "Phase 2 smoke-evidence contract passed."
