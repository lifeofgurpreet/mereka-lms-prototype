#!/usr/bin/env bash
# @spec: design-tokens-system_spec.md
# @covers AC-004, AC-005, AC-006, AC-007, AC-008, AC-010, AC-012
# Verify design token CI integration: file existence, provenance validity,
# CI workflow step, and token value propagation to theme overrides and MFE SCSS.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCOPE_MODE="${VERIFY_DESIGN_TOKEN_CI_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_DESIGN_TOKEN_CI_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"
PASS=0; FAIL=0

should_skip_scope() {
  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "$CHANGED_FILES_RAW" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      scripts/qa/verify-design-token-ci.sh|\
      assets/branding/tokens.css|\
      assets/branding/tokens.provenance.json|\
      infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css|\
      infrastructure/tutor/themes/mereka/mfe/*)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-design-token-ci (scope skip: no design-token-ci authority changes)"
  exit 0
fi

check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "PASS: $desc"; PASS=$((PASS+1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL+1))
  fi
}

TOKENS="$REPO_ROOT/assets/branding/tokens.css"
PROVENANCE="$REPO_ROOT/assets/branding/tokens.provenance.json"
OVERRIDES="$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css/mereka-overrides.css"
MFE_SCSS_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe"
CI_WORKFLOW="$REPO_ROOT/.github/workflows/ci.yml"

# --- AC-004: Token file structure ---
check "tokens.css exists and is non-empty" test -s "$TOKENS"
check "tokens.css contains :root selector" grep -q ":root" "$TOKENS"
check "tokens.css uses kebab-case token names" grep -qP '^\s+--[a-z][a-z0-9-]+:' "$TOKENS"

# --- AC-005, AC-006, AC-007: Provenance tracking ---
check "tokens.provenance.json exists and is non-empty" test -s "$PROVENANCE"
check "tokens.provenance.json is valid JSON" python3 -c "import json; json.load(open('$PROVENANCE'))"
check "provenance has source_repo field" python3 -c "
import json, sys
p = json.load(open('$PROVENANCE'))
sys.exit(0 if p.get('source_repo') else 1)
"
check "provenance has source_commit (40-char SHA)" python3 -c "
import json, re, sys
p = json.load(open('$PROVENANCE'))
sys.exit(0 if re.fullmatch(r'[0-9a-f]{40}', p.get('source_commit','')) else 1)
"
check "provenance has source_sha256 (64-char SHA256)" python3 -c "
import json, re, sys
p = json.load(open('$PROVENANCE'))
sys.exit(0 if re.fullmatch(r'[0-9a-f]{64}', p.get('source_sha256','')) else 1)
"

# --- AC-010: SHA256 content match ---
check "tokens.css SHA256 matches provenance" python3 -c "
import hashlib, json, sys
prov = json.load(open('$PROVENANCE'))
actual = hashlib.sha256(open('$TOKENS','rb').read()).hexdigest()
sys.exit(0 if prov.get('source_sha256','').lower() == actual else 1)
"

# --- CI workflow has design token validation ---
check "CI workflow has design-token-validation job" grep -q "design-token-validation" "$CI_WORKFLOW"
check "CI workflow runs verify-token-drift.sh" grep -q "verify-token-drift.sh" "$CI_WORKFLOW"

# --- AC-008, AC-012: Token values in overrides ---
check "mereka-overrides.css exists" test -f "$OVERRIDES"
check "--color-teal value in mereka-overrides.css" python3 -c "
import re, sys
tokens = open('$TOKENS').read()
overrides = open('$OVERRIDES').read()
m = re.search(r'--color-teal:\s*(#[0-9a-fA-F]{6})', tokens)
sys.exit(0 if m and m.group(1).lower() in overrides.lower() else 1)
"
check "--mereka-color-teal in mereka-overrides.css" grep -q "\-\-mereka-color-teal" "$OVERRIDES"
check "--mereka-font-heading in mereka-overrides.css" grep -q "\-\-mereka-font-heading" "$OVERRIDES"
check "--mereka-font-body in mereka-overrides.css" grep -q "\-\-mereka-font-body" "$OVERRIDES"

# --- AC-012: Token values in MFE SCSS ---
check "mfe/mereka.scss exists" test -f "$MFE_SCSS_DIR/mereka.scss"
check "--mereka-color-teal referenced in mfe scss tree" grep -rq "mereka-color-teal" "$MFE_SCSS_DIR"
check "--mereka-color-blue referenced in mfe scss tree" grep -rq "mereka-color-blue" "$MFE_SCSS_DIR"
check "--mereka-font-heading referenced in mfe scss tree" grep -rq "mereka-font-heading" "$MFE_SCSS_DIR"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
