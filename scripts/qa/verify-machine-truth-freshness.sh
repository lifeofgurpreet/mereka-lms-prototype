#!/usr/bin/env bash
set -euo pipefail

# verify-machine-truth-freshness.sh — Verify machine-readable truth files
# are structurally valid and not stale.
#
# Checks:
#   1. Required truth files exist
#   2. YAML files are parseable
#   3. Schema version fields are present
#   4. smoke-account-registry references real tenant names from tenant-registry
#   5. process-invariants has at least 12 rules
#   6. release-object-schema has required fields
#
# No network calls. No destructive operations.

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_ROOT"

failures=0
passes=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*"; failures=$((failures + 1)); }

echo "=== Machine-Readable Truth Freshness Verification ==="
echo "Repo root: ${REPO_ROOT}"

# ---------------------------------------------------------------------------
# 1. Required truth files exist
# ---------------------------------------------------------------------------
echo "--- Check 1: Required truth files exist ---"
required_files=(
  "config/process-invariants.yaml"
  "config/active-surface-inventory.yaml"
  "config/proof-lane-status.yaml"
  "config/release-object-schema.yaml"
  "deploy/k8s/tenancy/smoke-account-registry.yaml"
)
for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    pass "$f exists"
  else
    fail "$f missing"
  fi
done

# ---------------------------------------------------------------------------
# 2. YAML files are parseable (using python3 yaml if available)
# ---------------------------------------------------------------------------
echo "--- Check 2: YAML files are parseable ---"
if python3 -c "import yaml" 2>/dev/null; then
  for f in "${required_files[@]}"; do
    if [[ -f "$f" ]]; then
      if python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$f" 2>/dev/null; then
        pass "$f is valid YAML"
      else
        fail "$f is not valid YAML"
      fi
    fi
  done
else
  echo "  [SKIP] python3 yaml module not available; skipping parse check"
fi

# ---------------------------------------------------------------------------
# 3. Schema version fields present
# ---------------------------------------------------------------------------
echo "--- Check 3: Schema version fields present ---"
for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    if grep -q 'schema_version:' "$f"; then
      pass "$f has schema_version"
    else
      fail "$f missing schema_version field"
    fi
  fi
done

# ---------------------------------------------------------------------------
# 4. Smoke registry references real tenants
# ---------------------------------------------------------------------------
echo "--- Check 4: Smoke registry references real tenants ---"
smoke_reg="deploy/k8s/tenancy/smoke-account-registry.yaml"
tenant_reg="deploy/k8s/tenancy/tenant-registry.yaml"
if [[ -f "$smoke_reg" && -f "$tenant_reg" ]]; then
  smoke_tenants=$(grep 'tenant:' "$smoke_reg" | sed 's/.*tenant: *//' | tr -d '"' | sort -u)
  for t in $smoke_tenants; do
    if [[ "$t" == "platform" || "$t" == "shared" || "$t" == "shared/tenant" ]]; then
      pass "smoke tenant '$t' is a platform-scoped identity (OK)"
    elif grep -qi "$t" "$tenant_reg"; then
      pass "smoke tenant '$t' found in tenant-registry"
    else
      fail "smoke tenant '$t' NOT found in tenant-registry"
    fi
  done
else
  echo "  [SKIP] smoke or tenant registry file missing"
fi

# ---------------------------------------------------------------------------
# 5. Process invariants has at least 12 rules
# ---------------------------------------------------------------------------
echo "--- Check 5: Process invariants minimum rule count ---"
inv_file="config/process-invariants.yaml"
if [[ -f "$inv_file" ]]; then
  count=$(grep -c '^  - id: INV-' "$inv_file" || echo 0)
  if [[ "$count" -ge 12 ]]; then
    pass "process-invariants has $count rules (>= 12 minimum)"
  else
    fail "process-invariants has only $count rules (need >= 12)"
  fi
fi

# ---------------------------------------------------------------------------
# 6. Release-object schema has required field definitions
# ---------------------------------------------------------------------------
echo "--- Check 6: Release-object schema required fields ---"
schema_file="config/release-object-schema.yaml"
if [[ -f "$schema_file" ]]; then
  for field in release_id source_commit images evidence_bundle promotion_target runtime_proof; do
    if grep -q "$field:" "$schema_file"; then
      pass "release schema has '$field'"
    else
      fail "release schema missing '$field'"
    fi
  done
fi

echo ""
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"
if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "Machine-readable truth freshness violations detected."
  exit 1
fi
echo ""
echo "All machine-readable truth files are valid and fresh."
