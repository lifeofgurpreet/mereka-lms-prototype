#!/usr/bin/env bash
# Seeded-defect test for verify-zero-pending-migrations.sh --service behavior.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$REPO_ROOT/scripts/release/verify-zero-pending-migrations.sh"

tmpdir="$(mktemp -d -t verify-zero-pending-service-filter.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s/migrations"

cat >"$tmpdir/deploy/k8s/migrations/registry.yaml" <<'EOF'
version: "1.0.0"
services:
  - name: service-a
    schema_owner: true
    database: mysql
    migration_command: "python manage.py migrate --noinput"
    pending_check: "echo 0"
    health_endpoint: "/health/"
    health_port: 8000
    release_critical: true
    disabled: true
EOF

run_expect_pass() {
  local label="$1"
  shift
  if "$@" >/tmp/verify-zero-pending-service-filter.out 2>&1; then
    echo "PASS ${label}"
  else
    echo "FAIL ${label}: expected success" >&2
    cat /tmp/verify-zero-pending-service-filter.out >&2 || true
    exit 1
  fi
}

run_expect_fail() {
  local label="$1"
  shift
  set +e
  "$@" >/tmp/verify-zero-pending-service-filter.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-zero-pending-service-filter.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass "known disabled service selector succeeds" \
  env REPO_ROOT_OVERRIDE="$tmpdir" bash "$TARGET" --service service-a --json
if grep -q '"name": "service-a"' /tmp/verify-zero-pending-service-filter.out; then
  echo "PASS known service appears in JSON output"
else
  echo "FAIL known service missing from JSON output" >&2
  cat /tmp/verify-zero-pending-service-filter.out >&2 || true
  exit 1
fi

run_expect_fail "unknown service selector fails fast" \
  env REPO_ROOT_OVERRIDE="$tmpdir" bash "$TARGET" --service does-not-exist --json
if grep -q '"reason": "unknown_service"' /tmp/verify-zero-pending-service-filter.out; then
  echo "PASS unknown selector surfaced in JSON result"
else
  echo "FAIL unknown selector JSON marker missing" >&2
  cat /tmp/verify-zero-pending-service-filter.out >&2 || true
  exit 1
fi

echo "OK"
