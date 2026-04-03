#!/usr/bin/env bash
# Verify Phase 7 runtime DOM audit contract:
# - canonical selector lists exist and are non-empty
# - strict/full wrappers exist and delegate to verify script
# - verify script exposes phase7_strict + phase7_full profiles + selector-file + authenticated support
# - workflows expose strict profile option plus authenticated controls for operator entry points
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SELECTOR_FILE="$REPO_ROOT/scripts/qa/mfe-live-dom-phase7-selectors.txt"
FULL_SELECTOR_FILE="$REPO_ROOT/scripts/qa/mfe-live-dom-phase7-full-selectors.txt"
WRAPPER="$REPO_ROOT/scripts/qa/run-phase7-dom-audit.sh"
FULL_WRAPPER="$REPO_ROOT/scripts/qa/run-phase7-dom-audit-full.sh"
SELECTOR_COVERAGE_SCRIPT="$REPO_ROOT/scripts/qa/verify-mfe-selector-coverage.sh"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-mfe-live-dom-audit.sh"
LIVE_DOM_WORKFLOW="$REPO_ROOT/.github/workflows/mfe-live-dom-audit.yml"
CLOSURE_WORKFLOW="$REPO_ROOT/.github/workflows/frontend-branding-closure.yml"
RELEASE_WORKFLOW="$REPO_ROOT/.github/workflows/release-evidence.yml"
MAKEFILE="$REPO_ROOT/Makefile"

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

if [[ ! -f "$FULL_SELECTOR_FILE" ]]; then
  fail "Missing expanded selector list: scripts/qa/mfe-live-dom-phase7-full-selectors.txt"
else
  full_selector_count="$(grep -Ev '^\s*($|#)' "$FULL_SELECTOR_FILE" | wc -l | tr -d ' ')"
  if [[ "$full_selector_count" -lt 40 ]]; then
    fail "Expanded selector list too small ($full_selector_count entries, expected >=40)"
  else
    pass "Expanded selector list exists with $full_selector_count selectors"
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

if [[ ! -x "$FULL_WRAPPER" ]]; then
  fail "Missing executable wrapper: scripts/qa/run-phase7-dom-audit-full.sh"
else
  if rg -n -- '--audit-profile phase7_full' "$FULL_WRAPPER" >/dev/null; then
    pass "Expanded wrapper delegates with --audit-profile phase7_full"
  else
    fail "Expanded wrapper does not enforce --audit-profile phase7_full"
  fi
fi

if [[ ! -x "$SELECTOR_COVERAGE_SCRIPT" ]]; then
  fail "Missing executable coverage checker: scripts/qa/verify-mfe-selector-coverage.sh"
else
  pass "Selector coverage checker exists"
fi

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  fail "Missing executable verifier: scripts/qa/verify-mfe-live-dom-audit.sh"
else
  if rg -n 'phase7_strict' "$VERIFY_SCRIPT" >/dev/null \
    && rg -n 'phase7_full' "$VERIFY_SCRIPT" >/dev/null; then
    pass "Verifier supports phase7_strict + phase7_full profiles"
  else
    fail "Verifier missing phase7_strict or phase7_full profile support"
  fi
  if rg -n 'selector-audit-selectors-file|SELECTOR_AUDIT_SELECTORS_FILE' "$VERIFY_SCRIPT" >/dev/null; then
    pass "Verifier supports selector list file input"
  else
    fail "Verifier missing selector file support"
  fi
  if rg -n 'canonical auth/account context-card markers present' "$VERIFY_SCRIPT" >/dev/null \
    && rg -n 'mereka-additional-profile-fields mereka-progress-certificate-status mereka-shell-panel mb-3' "$VERIFY_SCRIPT" >/dev/null; then
    pass "Verifier guards canonical auth/account context-card source markers"
  else
    fail "Verifier missing canonical auth/account context-card source-marker guard"
  fi
  if rg -n -- '--authenticated|--context|--namespace' "$VERIFY_SCRIPT" >/dev/null \
    && rg -n 'SafeCookieData\.create' "$VERIFY_SCRIPT" >/dev/null; then
    pass "Verifier supports authenticated learner-mode storage state minting"
  else
    fail "Verifier missing authenticated learner-mode support"
  fi
fi

for wf in "$LIVE_DOM_WORKFLOW" "$CLOSURE_WORKFLOW" "$RELEASE_WORKFLOW"; do
  rel="${wf#"$REPO_ROOT"/}"
  if [[ ! -f "$wf" ]]; then
    fail "Missing workflow: $rel"
    continue
  fi
  if rg -n 'phase7_strict' "$wf" >/dev/null && rg -n 'phase7_full' "$wf" >/dev/null; then
    pass "$rel exposes phase7_strict + phase7_full profile options"
  else
    fail "$rel missing phase7_strict or phase7_full profile option"
  fi
done

if rg -n 'authenticated:' "$LIVE_DOM_WORKFLOW" >/dev/null \
  && rg -n 'kube_context:' "$LIVE_DOM_WORKFLOW" >/dev/null \
  && rg -n 'namespace:' "$LIVE_DOM_WORKFLOW" >/dev/null; then
  pass "Live DOM workflow exposes authenticated mode inputs"
else
  fail "Live DOM workflow missing authenticated mode inputs"
fi

if [[ ! -f "$MAKEFILE" ]]; then
  fail "Missing Makefile for operator target checks"
else
  if rg -n '^qa-phase7-dom-audit:' "$MAKEFILE" >/dev/null \
    && rg -n 'run-phase7-dom-audit\.sh --env prod' "$MAKEFILE" >/dev/null; then
    pass "Makefile exposes qa-phase7-dom-audit target"
  else
    fail "Makefile missing qa-phase7-dom-audit target wiring"
  fi

  if rg -n '^qa-phase7-dom-audit-dev:' "$MAKEFILE" >/dev/null \
    && rg -n 'run-phase7-dom-audit\.sh --env dev' "$MAKEFILE" >/dev/null; then
    pass "Makefile exposes qa-phase7-dom-audit-dev target"
  else
    fail "Makefile missing qa-phase7-dom-audit-dev target wiring"
  fi

  if rg -n '^qa-phase7-dom-audit-full:' "$MAKEFILE" >/dev/null \
    && rg -n 'run-phase7-dom-audit-full\.sh --env prod' "$MAKEFILE" >/dev/null; then
    pass "Makefile exposes qa-phase7-dom-audit-full target"
  else
    fail "Makefile missing qa-phase7-dom-audit-full target wiring"
  fi

  if rg -n '^qa-phase7-dom-audit-full-dev:' "$MAKEFILE" >/dev/null \
    && rg -n 'run-phase7-dom-audit-full\.sh --env dev' "$MAKEFILE" >/dev/null; then
    pass "Makefile exposes qa-phase7-dom-audit-full-dev target"
  else
    fail "Makefile missing qa-phase7-dom-audit-full-dev target wiring"
  fi

  if rg -n '^qa-phase7-dom-audit-full-dev-auth:' "$MAKEFILE" >/dev/null \
    && rg -n 'run-phase7-dom-audit-full\.sh --env dev --authenticated --context rke2-nonprod --namespace mereka-lms-dev' "$MAKEFILE" >/dev/null; then
    pass "Makefile exposes authenticated dev DOM audit target"
  else
    fail "Makefile missing authenticated dev DOM audit target wiring"
  fi

  if rg -n '^qa-mfe-selector-coverage:' "$MAKEFILE" >/dev/null \
    && rg -n 'verify-mfe-selector-coverage\.sh' "$MAKEFILE" >/dev/null; then
    pass "Makefile exposes qa-mfe-selector-coverage target"
  else
    fail "Makefile missing qa-mfe-selector-coverage target wiring"
  fi
fi

if [[ "$violations" -ne 0 ]]; then
  echo "Phase 7 DOM audit contract failed."
  exit 1
fi

echo "Phase 7 DOM audit contract passed."
