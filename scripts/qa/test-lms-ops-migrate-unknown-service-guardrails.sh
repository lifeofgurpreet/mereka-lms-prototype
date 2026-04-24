#!/usr/bin/env bash
# Guardrail test: unknown --service selectors must fail fast for lms-ops migrate commands.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LMS_OPS="$REPO_ROOT/bin/lms-ops"
UNKNOWN_SERVICE="__unknown_service_guardrail__"

run_expect_fail() {
  local label="$1"
  shift
  set +e
  "$@" >/tmp/lms-ops-unknown-service.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/lms-ops-unknown-service.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

if [[ ! -x "$LMS_OPS" ]]; then
  echo "FAIL lms-ops missing or not executable: $LMS_OPS" >&2
  exit 1
fi

run_expect_fail "migrate plan rejects unknown service" \
  "$LMS_OPS" migrate plan --service "$UNKNOWN_SERVICE"
if grep -q "not found in migration registry" /tmp/lms-ops-unknown-service.out; then
  echo "PASS migrate plan unknown-service error surfaced"
else
  echo "FAIL migrate plan missing unknown-service error" >&2
  cat /tmp/lms-ops-unknown-service.out >&2 || true
  exit 1
fi

run_expect_fail "migrate apply dry-run rejects unknown service" \
  "$LMS_OPS" migrate apply --dry-run --service "$UNKNOWN_SERVICE"
if grep -q "unknown service" /tmp/lms-ops-unknown-service.out; then
  echo "PASS migrate apply unknown-service error surfaced"
else
  echo "FAIL migrate apply missing unknown-service error" >&2
  cat /tmp/lms-ops-unknown-service.out >&2 || true
  exit 1
fi

run_expect_fail "migrate verify rejects unknown service" \
  "$LMS_OPS" migrate verify --service "$UNKNOWN_SERVICE" --format json
if grep -q '"reason": "unknown_service"' /tmp/lms-ops-unknown-service.out; then
  echo "PASS migrate verify unknown-service JSON marker surfaced"
else
  echo "FAIL migrate verify missing unknown-service JSON marker" >&2
  cat /tmp/lms-ops-unknown-service.out >&2 || true
  exit 1
fi

echo "OK"
