#!/usr/bin/env bash
# Seeded-defect static contract test for bin/lms-ops migrate behavior.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$REPO_ROOT/bin/lms-ops"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }

echo "=== lms-ops migrate contract ==="

if [[ ! -f "$TARGET" ]]; then
  fail "bin/lms-ops missing"
  echo "=== Results: $PASS PASS / $FAIL FAIL ==="
  exit 1
fi
pass "bin/lms-ops exists"

if bash -n "$TARGET"; then
  pass "bin/lms-ops has valid bash syntax"
else
  fail "bin/lms-ops bash syntax check failed"
fi

if grep -q -- '--service)' "$TARGET"; then
  pass "global parser supports --service"
else
  fail "missing --service parser support"
fi

if grep -q 'deploy/k8s/migrations/registry.yaml' "$TARGET"; then
  pass "migrate apply reads registry as source of truth"
else
  fail "migrate apply does not reference migration registry"
fi

if grep -q 'MISSING_JOB' "$TARGET"; then
  pass "migrate apply handles missing job_manifest entries"
else
  fail "migrate apply missing MISSING_JOB handling"
fi

if grep -q 'ERR_UNKNOWN' "$TARGET"; then
  pass "migrate apply rejects unknown --service values"
else
  fail "migrate apply missing unknown-service handling"
fi

if grep -q '\[\[ -n "\$SERVICE_FILTER" \]\] && args+=("--service" "\$SERVICE_FILTER")' "$TARGET"; then
  pass "migrate verify forwards --service filter"
else
  fail "migrate verify missing --service forwarding"
fi

if grep -q '\[\[ "\$FORMAT" != "json" \]\]' "$TARGET"; then
  pass "migrate verify suppresses headers in --format json mode"
else
  fail "migrate verify missing json-mode header suppression"
fi

if grep -q 'local args=("--lane" "$LANE")' "$TARGET"; then
  pass "smoke wave uses normalized lane variable"
else
  fail "smoke wave lane wiring mismatch"
fi

if grep -q 'CANONICAL_LANE' "$TARGET"; then
  fail "stale CANONICAL_LANE reference still present"
else
  pass "no stale CANONICAL_LANE reference remains"
fi

echo "=== Results: $PASS PASS / $FAIL FAIL ==="
[[ "$FAIL" -eq 0 ]]
