#!/usr/bin/env bash
# Seeded-defect self-test for verify-verification-sprawl-budget.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-verification-sprawl-budget.sh"

tmpdir="$(mktemp -d -t verify-sprawl-budget.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/docs/operations/verification"

CATALOG_JSON="$tmpdir/docs/operations/verification/verification_catalog.json"
BUDGET_JSON="$tmpdir/docs/operations/verification/verification_sprawl_budget.json"

cat >"$CATALOG_JSON" <<'EOF'
{
  "summary": {
    "total_verify_scripts": 12,
    "ci_static_bound": 11,
    "statuses": {
      "manual_only": 1,
      "deprecated_candidate": 0
    }
  }
}
EOF

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-sprawl-budget.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-sprawl-budget.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-sprawl-budget.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$BUDGET_JSON" <<'EOF'
{
  "max_total_verify_scripts": 20,
  "max_manual_only_scripts": 2,
  "max_deprecated_candidate_scripts": 1,
  "min_ci_static_bound": 8
}
EOF
run_expect_pass "budget passes when metrics are within thresholds"

cat >"$BUDGET_JSON" <<'EOF'
{
  "max_total_verify_scripts": 20,
  "max_manual_only_scripts": 0,
  "max_deprecated_candidate_scripts": 1,
  "min_ci_static_bound": 8
}
EOF
run_expect_fail "manual-only overflow is rejected"

cat >"$BUDGET_JSON" <<'EOF'
{
  "max_total_verify_scripts": 20,
  "max_manual_only_scripts": 2,
  "max_deprecated_candidate_scripts": 1,
  "min_ci_static_bound": 12
}
EOF
run_expect_fail "ci static floor violations are rejected"

echo "OK"
