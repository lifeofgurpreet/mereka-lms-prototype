#!/usr/bin/env bash
# @covers AC-007
# @spec: branding-system_spec.md
# Enforce single contract for token sync: sync script must invoke canonical generator,
# and drift verifier must check generator --check instead of raw token file byte-compare.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYNC_SCRIPT="$REPO_ROOT/scripts/branding/sync-brand-assets.sh"
DRIFT_SCRIPT="$REPO_ROOT/scripts/qa/verify-brand-asset-drift.sh"

PASS=0
FAIL=0

pass() {
  echo "PASS $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "FAIL $1"
  FAIL=$((FAIL + 1))
}

require_pattern() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if grep -qE "$pattern" "$file"; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

require_absent_pattern() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if grep -qE "$pattern" "$file"; then
    fail "$msg"
  else
    pass "$msg"
  fi
}

echo "=== Branding Token Sync Contract ==="

for file in "$SYNC_SCRIPT" "$DRIFT_SCRIPT"; do
  if [[ -f "$file" ]]; then
    pass "${file#$REPO_ROOT/} exists"
  else
    fail "Missing file: ${file#$REPO_ROOT/}"
  fi
done

if [[ -f "$SYNC_SCRIPT" ]]; then
  require_pattern "$SYNC_SCRIPT" 'TOKEN_GENERATOR=' 'sync script defines TOKEN_GENERATOR'
  require_pattern "$SYNC_SCRIPT" '"\$TOKEN_GENERATOR"' 'sync script invokes token generator'
  require_absent_pattern "$SYNC_SCRIPT" 'cp\s+"\$TOKENS_SRC"\s+"\$TOKENS_DEST"' 'sync script does not raw-copy tokens.css into theme token artifact'
fi

if [[ -f "$DRIFT_SCRIPT" ]]; then
  require_pattern "$DRIFT_SCRIPT" 'verify_theme_tokens_sync\(\)' 'drift verifier defines token sync helper'
  require_pattern "$DRIFT_SCRIPT" '"\$generator"\s*--check' 'drift verifier checks canonical generator in --check mode'
  require_absent_pattern "$DRIFT_SCRIPT" 'compare_file\s+\\\n\s*"\$REPO_ROOT/assets/branding/tokens\.css"' 'drift verifier does not byte-compare canonical tokens.css against generated theme css'
fi

echo "Summary: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
