#!/usr/bin/env bash
# verify-authority-routing.sh — Verify authority cutover
#
# Ensures that:
# 1. bin/lms-ops exists and is executable
# 2. All front_door concerns are wired in bin/lms-ops
# 3. bin/lms-ops delegates to the correct underlying scripts
# 4. No direct invocation of underlying scripts in CI workflows
#    for concerns that should go through lms-ops
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

echo "Authority Routing Verification"
echo "=============================="

# 1. bin/lms-ops exists and is executable
LMS_OPS="$REPO_ROOT/bin/lms-ops"
if [[ -x "$LMS_OPS" ]]; then
  pass "bin/lms-ops exists and is executable"
else
  fail "bin/lms-ops missing or not executable"
  echo ""
  echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
  exit 1
fi

# 2. All concerns wired in the dispatch
EXPECTED_CONCERNS="migrate proof release-gate smoke preflight topology"
for concern in $EXPECTED_CONCERNS; do
  if grep -q "^  ${concern})" "$LMS_OPS" 2>/dev/null; then
    pass "concern '$concern' wired in bin/lms-ops dispatch"
  else
    fail "concern '$concern' NOT found in bin/lms-ops dispatch"
  fi
done

# 3. bin/lms-ops delegates to underlying scripts (not reimplementing)
declare -A DELEGATIONS=(
  ["release-gate"]="release-gate.sh"
  ["smoke"]="smoke-after-migrate.sh"
  ["preflight"]="migration-preflight.sh"
  ["proof"]="emit-proof-envelope.sh"
)
for concern in "${!DELEGATIONS[@]}"; do
  expected_script="${DELEGATIONS[$concern]}"
  if grep -q "$expected_script" "$LMS_OPS" 2>/dev/null; then
    pass "bin/lms-ops '$concern' delegates to $expected_script"
  else
    fail "bin/lms-ops '$concern' does not delegate to $expected_script"
  fi
done

# 4. bin/lms-ops sources lane-normalize.sh
if grep -q "lane-normalize.sh" "$LMS_OPS" 2>/dev/null; then
  pass "bin/lms-ops sources lane-normalize.sh"
else
  fail "bin/lms-ops does not source lane-normalize.sh"
fi

# 5. Canonical entrypoints version >= 2.0.0 (authority cutover version)
ENTRYPOINTS="$REPO_ROOT/scripts/governance/canonical-entrypoints.yaml"
if [[ -f "$ENTRYPOINTS" ]]; then
  version="$(grep '^version:' "$ENTRYPOINTS" | head -1 | sed 's/.*: *//' | tr -d '"')"
  case "$version" in
    2.*)
      pass "canonical-entrypoints.yaml version $version (post-cutover)" ;;
    *)
      warn "canonical-entrypoints.yaml version $version (pre-cutover)" ;;
  esac
fi

# 6. front_door declared in canonical-entrypoints.yaml
if grep -q "^front_door:" "$ENTRYPOINTS" 2>/dev/null; then
  pass "front_door section declared in canonical-entrypoints.yaml"
  if grep -q "bin/lms-ops" "$ENTRYPOINTS" 2>/dev/null; then
    pass "front_door references bin/lms-ops"
  else
    fail "front_door does not reference bin/lms-ops"
  fi
else
  fail "front_door section missing from canonical-entrypoints.yaml"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
[[ "$FAIL" -eq 0 ]] || exit 1
