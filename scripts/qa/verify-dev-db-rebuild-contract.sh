#!/usr/bin/env bash
# Verify canonical dev DB rebuild guardrails stay enforced.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$REPO_ROOT/scripts/infra/rebuild-dev-openedx-db.sh"
# Check both canonical and legacy paths (docs were reorganized)
if [[ -f "$REPO_ROOT/docs/ops/runbooks/DEV_DB_REBUILD_CANONICAL.md" ]]; then
  RUNBOOK_PATH="$REPO_ROOT/docs/ops/runbooks/DEV_DB_REBUILD_CANONICAL.md"
elif [[ -f "$REPO_ROOT/docs/operations/runbooks/DEV_DB_REBUILD_CANONICAL.md" ]]; then
  RUNBOOK_PATH="$REPO_ROOT/docs/operations/runbooks/DEV_DB_REBUILD_CANONICAL.md"
else
  RUNBOOK_PATH="$REPO_ROOT/docs/ops/runbooks/DEV_DB_REBUILD_CANONICAL.md"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAIL=$((FAIL + 1))
}

require_grep() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if grep -qE "$pattern" "$file"; then
    pass "$message"
  else
    fail "$message"
  fi
}

echo "=== Dev DB Rebuild Guardrail Contract ==="
echo

if [[ -f "$SCRIPT_PATH" ]]; then
  pass "Rebuild script exists: scripts/infra/rebuild-dev-openedx-db.sh"
else
  fail "Missing rebuild script: scripts/infra/rebuild-dev-openedx-db.sh"
fi

if [[ -x "$SCRIPT_PATH" ]]; then
  pass "Rebuild script is executable"
else
  fail "Rebuild script is not executable"
fi

if [[ -f "$RUNBOOK_PATH" ]]; then
  pass "Runbook exists: docs/operations/runbooks/DEV_DB_REBUILD_CANONICAL.md"
else
  fail "Missing runbook: docs/operations/runbooks/DEV_DB_REBUILD_CANONICAL.md"
fi

if [[ -f "$SCRIPT_PATH" ]]; then
  require_grep "$SCRIPT_PATH" 'set -euo pipefail' "Script uses strict bash mode"
  require_grep "$SCRIPT_PATH" 'RUN_DESTRUCTIVE:-0' "Script defaults to dry-run"
  require_grep "$SCRIPT_PATH" 'CONFIRM_REBUILD_DEV_DB' "Script requires destructive confirmation variable"
  require_grep "$SCRIPT_PATH" 'REBUILD_DEV_DB' "Script includes explicit destructive confirmation token"
  require_grep "$SCRIPT_PATH" 'velero backup create' "Script includes Velero pre-op backup step"
  require_grep "$SCRIPT_PATH" 'ALLOW_PROD_CONTEXT' "Script includes production-context override guard"
  require_grep "$SCRIPT_PATH" 'K8S_CONTEXT:-rke2-nonprod' "Script defaults to non-prod context"
fi

if [[ -f "$RUNBOOK_PATH" ]]; then
  require_grep "$RUNBOOK_PATH" 'scripts/infra/rebuild-dev-openedx-db.sh' "Runbook references canonical rebuild script"
  require_grep "$RUNBOOK_PATH" 'RUN_DESTRUCTIVE=1' "Runbook documents guarded destructive mode"
  require_grep "$RUNBOOK_PATH" 'CONFIRM_REBUILD_DEV_DB=REBUILD_DEV_DB' "Runbook documents explicit confirmation token"
  require_grep "$RUNBOOK_PATH" 'velero' "Runbook documents backup/restore flow"
  require_grep "$RUNBOOK_PATH" 'no ad-hoc.*migrate --fake' "Runbook forbids ad-hoc fake migration recovery"
fi

echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

exit 0
