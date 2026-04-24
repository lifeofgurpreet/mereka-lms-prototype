#!/usr/bin/env bash
# @covers AC-CI-034
# @spec: ci-cd-pipeline_spec.md
# verify-pr-handoff-guardrails.sh
#
# Ensures PR handoff guardrails remain enforceable in-repo:
# - Required PR template checklist items exist.
# - Local handoff check script exists and validates key failure modes.
# - Ops documentation exists and references the executable command.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PR_TEMPLATE="$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md"
HANDOFF_SCRIPT="$REPO_ROOT/scripts/infra/check-pr-handoff-discipline.sh"
POLICY_DOC="$REPO_ROOT/docs/policies/operations/PR_HANDOFF_POLICY.md"

violations=0
checks=0

fail() {
  echo "  FAIL: $*" >&2
  violations=$((violations + 1))
}

pass() {
  checks=$((checks + 1))
}

require_file() {
  local file="$1"
  local label="$2"
  if [[ -f "$file" ]]; then
    pass "$label exists"
  else
    fail "$label missing: $file"
  fi
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if rg -q --fixed-strings "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label missing in $(basename "$file"): $pattern"
  fi
}

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: rg is required" >&2
  exit 2
fi

echo "=== PR Handoff Guardrails Verification ==="
echo "Repo: $REPO_ROOT"
echo ""

require_file "$PR_TEMPLATE" "PR template"
require_file "$HANDOFF_SCRIPT" "handoff discipline script"
require_file "$POLICY_DOC" "handoff policy doc"

if [[ -f "$PR_TEMPLATE" ]]; then
  require_pattern "$PR_TEMPLATE" "## Handoff Guardrails (Required)" "PR template handoff section heading"
  require_pattern "$PR_TEMPLATE" "./scripts/infra/check-pr-handoff-discipline.sh" "PR template references handoff command"
  require_pattern "$PR_TEMPLATE" "git status --porcelain" "PR template requires clean worktree check"
  require_pattern "$PR_TEMPLATE" "git stash list" "PR template requires stash check"
  require_pattern "$PR_TEMPLATE" "linked a follow-up issue/PR" "PR template requires follow-up linkage"
fi

if [[ -f "$HANDOFF_SCRIPT" ]]; then
  if [[ -x "$HANDOFF_SCRIPT" ]]; then
    pass "handoff discipline script is executable"
  else
    fail "handoff discipline script is not executable: $HANDOFF_SCRIPT"
  fi
  require_pattern "$HANDOFF_SCRIPT" "git status --porcelain" "handoff script checks clean worktree"
  require_pattern "$HANDOFF_SCRIPT" "git stash list" "handoff script checks stash entries"
  require_pattern "$HANDOFF_SCRIPT" "git rev-list --count HEAD..origin/main" "handoff script checks main sync"
  require_pattern "$HANDOFF_SCRIPT" "git rev-list --count \"\${upstream_ref}\"..HEAD" "handoff script checks unpushed commits"
fi

if [[ -f "$POLICY_DOC" ]]; then
  require_pattern "$POLICY_DOC" "check-pr-handoff-discipline.sh" "policy doc references executable check"
  require_pattern "$POLICY_DOC" "No dirty handoff" "policy doc defines no-dirty-handoff rule"
fi

echo ""
echo "=== Summary ==="
echo "Checks     : $checks"
echo "Violations : $violations"
echo ""

if [[ "$violations" -gt 0 ]]; then
  echo "FAIL — PR handoff guardrails are incomplete." >&2
  exit 1
fi

echo "PASS — PR handoff guardrails are enforced."
