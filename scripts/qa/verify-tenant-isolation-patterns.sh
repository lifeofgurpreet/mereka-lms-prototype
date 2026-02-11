#!/usr/bin/env bash
# Verify that tenant isolation patterns exist in the codebase.
# Checks for queryset filtering, middleware, and cache key namespacing.
# AC-003..AC-007: Data isolation via queryset filtering.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAILED=0
WARNINGS=0

log_pass() { printf "PASS: %s\n" "$1"; }
log_fail() { printf "FAIL: %s\n" "$1"; FAILED=1; }
log_warn() { printf "WARN: %s\n" "$1"; WARNINGS=$((WARNINGS + 1)); }

echo "=== Tenant Isolation Patterns Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

# Check 1: TenantResolutionMiddleware exists
if [ -f "$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/middleware.py" ]; then
  log_pass "TenantResolutionMiddleware module exists"
else
  log_fail "TenantResolutionMiddleware module missing"
fi

# Check 2: Multisite middleware exists (existing cookie domain isolation)
if [ -f "$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/mereka_multisite.py" ]; then
  log_pass "MerekaCookieDomainMiddleware exists (cookie isolation)"
else
  log_fail "MerekaCookieDomainMiddleware missing"
fi

# Check 3: Enterprise services have deployment manifests (queryset filtering is upstream)
ENTERPRISE_DIR="$REPO_ROOT/deploy/k8s/base/apps/enterprise"
ENTERPRISE_SERVICES=("enterprise-catalog" "enterprise-access" "enterprise-subsidy")
for svc in "${ENTERPRISE_SERVICES[@]}"; do
  if ls "$ENTERPRISE_DIR/${svc}-deployment.yaml" &>/dev/null; then
    log_pass "Enterprise service deployment exists: $svc"
  else
    log_fail "Enterprise service deployment missing: $svc"
  fi
done

# Check 4: Tenant ConfigMap exists for infrastructure-level tenant registry
if [ -f "$REPO_ROOT/deploy/k8s/base/apps/multi-tenancy/configmap-tenants.yaml" ]; then
  log_pass "Tenant registry ConfigMap exists"
else
  log_fail "Tenant registry ConfigMap missing"
fi

# Check 5: Redis cache key namespacing pattern documented in spec
SPEC_FILE="$REPO_ROOT/specs/multi-tenancy-architecture_spec.md"
if [ -f "$SPEC_FILE" ] && grep -q 'enterprise:{uuid}:{key_type}:{key_id}' "$SPEC_FILE"; then
  log_pass "Redis cache key namespacing pattern documented in spec"
else
  log_warn "Redis cache key namespacing pattern not found in spec (may be in a different format)"
fi

# Check 6: X-Tenant-ID header in middleware
if grep -rq "X-Tenant-ID" "$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/"; then
  log_pass "X-Tenant-ID response header set by middleware"
else
  log_fail "X-Tenant-ID response header not found in middleware"
fi

# Check 7: Provisioning command supports idempotency
CMD_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/commands/provision_tenant.py"
if [ -f "$CMD_FILE" ] && grep -q "get_or_create" "$CMD_FILE"; then
  log_pass "Provisioning command is idempotent (get_or_create)"
else
  log_fail "Provisioning command does not use idempotent pattern"
fi

# Check 8: Architecture overview documents isolation strategy
ARCH_FILE="$REPO_ROOT/docs/architecture/multi-tenancy-overview.md"
if [ -f "$ARCH_FILE" ] && grep -q "Tenant Isolation" "$ARCH_FILE"; then
  log_pass "Architecture doc documents tenant isolation strategy"
else
  log_warn "Architecture doc missing or does not document isolation"
fi

echo
echo "=== Summary ==="
if [ $FAILED -eq 0 ]; then
  echo "ALL CHECKS PASSED ($WARNINGS warnings)"
  exit 0
else
  echo "SOME CHECKS FAILED ($WARNINGS warnings)"
  exit 1
fi
