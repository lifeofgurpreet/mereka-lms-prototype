#!/usr/bin/env bash
# Verify Phase 7 runtime DOM audit contract:
# - canonical selector list exists and is non-empty
# - strict wrapper exists and delegates to verify script
# - verify script exposes phase7_strict profile + selector-file support
# - workflows expose strict profile option for operator entry points
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SELECTOR_FILE="$REPO_ROOT/scripts/qa/mfe-live-dom-phase7-selectors.txt"
WRAPPER="$REPO_ROOT/scripts/qa/run-phase7-dom-audit.sh"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-mfe-live-dom-audit.sh"
LIVE_DOM_WORKFLOW="$REPO_ROOT/.github/workflows/mfe-live-dom-audit.yml"
CLOSURE_WORKFLOW="$REPO_ROOT/.github/workflows/frontend-branding-closure.yml"
RELEASE_WORKFLOW="$REPO_ROOT/.github/workflows/release-evidence.yml"

violations=0

fail() {
  echo "❌ $*"
  violations=1
}

pass() {
  echo "✅ $*"
}

if [[ ! -f "$SELECTOR_FILE" ]]; then
  fail "Missing selector list: scripts/qa/mfe-live-dom-phase7-selectors.txt"
else
  selector_count="$(grep -Ev '^\s*($|#)' "$SELECTOR_FILE" | wc -l | tr -d ' ')"
  if [[ "$selector_count" -lt 5 ]]; then
    fail "Selector list too small ($selector_count entries, expected >=5)"
  else
    pass "Selector list exists with $selector_count selectors"
  fi
fi

if [[ ! -x "$WRAPPER" ]]; then
  fail "Missing executable wrapper: scripts/qa/run-phase7-dom-audit.sh"
else
  if rg -n -- '--audit-profile phase7_strict' "$WRAPPER" >/dev/null; then
    pass "Wrapper delegates with --audit-profile phase7_strict"
  else
    fail "Wrapper does not enforce --audit-profile phase7_strict"
  fi
fi

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  fail "Missing executable verifier: scripts/qa/verify-mfe-live-dom-audit.sh"
else
  if rg -n 'phase7_strict' "$VERIFY_SCRIPT" >/dev/null; then
    pass "Verifier supports phase7_strict profile"
  else
    fail "Verifier missing phase7_strict profile support"
  fi
  if rg -n 'selector-audit-selectors-file|SELECTOR_AUDIT_SELECTORS_FILE' "$VERIFY_SCRIPT" >/dev/null; then
    pass "Verifier supports selector list file input"
  else
    fail "Verifier missing selector file support"
  fi
fi

for wf in "$LIVE_DOM_WORKFLOW" "$CLOSURE_WORKFLOW" "$RELEASE_WORKFLOW"; do
  rel="${wf#"$REPO_ROOT"/}"
  if [[ ! -f "$wf" ]]; then
    fail "Missing workflow: $rel"
    continue
  fi
  if rg -n 'phase7_strict' "$wf" >/dev/null; then
    pass "$rel exposes phase7_strict profile option"
  else
    fail "$rel missing phase7_strict profile option"
  fi
done

if [[ "$violations" -ne 0 ]]; then
  echo "Phase 7 DOM audit contract failed."
  exit 1
fi

echo "Phase 7 DOM audit contract passed."
