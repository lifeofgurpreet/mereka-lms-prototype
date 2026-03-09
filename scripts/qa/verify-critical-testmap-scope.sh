#!/usr/bin/env bash
# Guardrail: critical enterprise/domain/migration testmaps must not map to unrelated purchase-gateway tests.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TESTMAPS=(
  "specs/_generated/testmaps/multi-site-domains_spec.testmap.yml"
  "specs/_generated/testmaps/multi-tenancy-architecture_spec.testmap.yml"
  "specs/_generated/testmaps/enterprise-microservices_spec.testmap.yml"
  "specs/_generated/testmaps/data-migrations-kajabi-mct_spec.testmap.yml"
)

DISALLOWED_PATTERN='services/purchase-gateway|verify-purchase-gateway|test_checkout_route|test_fulfillment|test_webhook_handler'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "PASS: $*"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "FAIL: $*"
}

echo "=== Critical Testmap Scope Verification ==="

for rel_path in "${TESTMAPS[@]}"; do
  abs_path="$REPO_ROOT/$rel_path"

  if [[ ! -f "$abs_path" ]]; then
    fail "missing testmap: $rel_path"
    continue
  fi

  if rg -n "$DISALLOWED_PATTERN" "$abs_path" >/tmp/critical-testmap-scope.$$ 2>&1; then
    fail "unrelated purchase-gateway mapping detected in $rel_path"
    sed -n '1,40p' /tmp/critical-testmap-scope.$$
  else
    pass "$rel_path has no unrelated purchase-gateway mappings"
  fi
  rm -f /tmp/critical-testmap-scope.$$ || true
done

echo ""
echo "=== Summary: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT} ==="

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
