#!/usr/bin/env bash
# Seeded-defect self-test for verify-critical-testmap-scope.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-critical-testmap-scope.sh"

tmpdir="$(mktemp -d -t verify-critical-testmap-scope.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/specs/testmaps"

create_testmaps() {
  for path in \
    multi-site-domains_spec.testmap.yml \
    multi-tenancy-architecture_spec.testmap.yml \
    enterprise-microservices_spec.testmap.yml \
    data-migrations-kajabi-mct_spec.testmap.yml; do
    cat >"$tmpdir/specs/testmaps/$path" <<'EOF'
spec: sample
tests:
  - scripts/qa/verify-auth-hardening.sh
EOF
  done
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-critical-testmap-scope.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-critical-testmap-scope.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-critical-testmap-scope.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

create_testmaps
run_expect_pass "critical maps pass when no purchase-gateway mappings are present"

cat >>"$tmpdir/specs/testmaps/enterprise-microservices_spec.testmap.yml" <<'EOF'
  - services/purchase-gateway/tests/unit/test_fulfillment.py
EOF
run_expect_fail "critical maps reject purchase-gateway coupling drift"

echo "OK"
