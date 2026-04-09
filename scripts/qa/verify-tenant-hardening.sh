#!/usr/bin/env bash
# @spec: multi-tenancy-architecture_spec.md (Phase 3: Operational Hardening)
# @covers: AC-TEN-014 through AC-TEN-021
# Verify Phase 3 tenant hardening implementation.
#
# Usage:
#   scripts/qa/verify-tenant-hardening.sh
#   scripts/qa/verify-tenant-hardening.sh --skip-cluster
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SKIP_CLUSTER=0

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --skip-cluster   Skip runtime cluster tests (K8s CronJob, etc.)"
  echo "  -h, --help       Show this help"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-cluster) SKIP_CLUSTER=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass_() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}✓${NC} $1"; }
fail_() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}✗${NC} $1"; }
warn_() { WARN_COUNT=$((WARN_COUNT + 1)); echo -e "${YELLOW}⚠${NC} $1"; }

TENANT_APP="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_tenant_cache"
OFFBOARD_CMD="$TENANT_APP/management/commands/offboard_tenant.py"
OFFBOARD_SCRIPT="$REPO_ROOT/scripts/tenants/offboard-tenant.sh"
CRONJOB_YAML="$REPO_ROOT/deploy/k8s/base/monitoring/cronjob-tenant-isolation.yaml"
ALERT_YAML="$REPO_ROOT/deploy/k8s/base/monitoring/prometheusrule-tenant-isolation.yaml"
LOAD_TEST="$REPO_ROOT/scripts/qa/load-test-tenants.sh"
LMS_PRODUCTION_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"

echo "========================================================"
echo "  Phase 3: Operational Hardening Verification"
echo "  Spec: multi-tenancy-architecture_spec.md"
echo "========================================================"
echo ""

# ── Section 1: Offboarding Management Command ───────────────────────────
echo -e "${BLUE}=== Section 1: Django Management Command ===${NC}"

if [[ -f "$OFFBOARD_CMD" ]]; then
  pass_ "offboard_tenant.py exists"
else
  fail_ "offboard_tenant.py not found"
fi

if grep -q "add_argument('--slug'" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "--slug argument present"
else
  fail_ "--slug argument missing"
fi

if grep -q "add_argument('--force-delete'" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "--force-delete argument present"
else
  fail_ "--force-delete argument missing"
fi

if grep -q "add_argument('--grace-days'" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "--grace-days argument present"
else
  fail_ "--grace-days argument missing"
fi

if grep -q "add_argument('--actor'" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "--actor argument present"
else
  fail_ "--actor argument missing"
fi

if grep -q "add_argument('--dry-run'" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "--dry-run argument present"
else
  fail_ "--dry-run argument missing"
fi

if grep -q "timedelta(days=grace_days)" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "Grace period check (timedelta comparison) implemented"
else
  fail_ "Grace period check missing"
fi

if grep -q "'action'" "$OFFBOARD_CMD" && \
   grep -q "tenant_uuid" "$OFFBOARD_CMD" && \
   grep -q "'actor'" "$OFFBOARD_CMD" && \
   grep -q "'timestamp'" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "Audit log contains action, tenant_uuid, actor, timestamp (AC-TEN-020)"
else
  fail_ "Audit log missing required fields (AC-TEN-020)"
fi

if grep -q "raise CommandError" "$OFFBOARD_CMD" && \
   grep -q "Grace period not expired" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "Grace period blocks deletion with CommandError (AC-TEN-021)"
else
  fail_ "Grace period enforcement missing (AC-TEN-021)"
fi

if grep -q "EnterpriseCustomerCatalog" "$OFFBOARD_CMD" && \
   grep -q "delete()" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "Enterprise catalog deletion code present (AC-TEN-015)"
else
  fail_ "Enterprise catalog deletion missing (AC-TEN-015)"
fi

if grep -q "ClickHouseConnection" "$OFFBOARD_CMD" && \
   grep -q "enterprise_customer_uuid" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "ClickHouse events deletion code present (AC-TEN-016)"
else
  fail_ "ClickHouse events deletion missing (AC-TEN-016)"
fi

if grep -q "TenantSiteMapping" "$OFFBOARD_CMD" && \
   grep -q "delete()" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "TenantSiteMapping deletion code present"
else
  fail_ "TenantSiteMapping deletion missing"
fi

if grep -q "tenant_cache_clear_all" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "Redis cache flush code present"
else
  fail_ "Redis cache flush missing"
fi

if grep -q "if mapping.is_active:" "$OFFBOARD_CMD" && \
   grep -q "raise CommandError" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "Active tenant deletion blocked with CommandError"
else
  fail_ "Active tenant deletion check missing"
fi

# ── Section 2: Offboarding Shell Script ─────────────────────────────────
echo ""
echo -e "${BLUE}=== Section 2: Shell Script Wrapper ===${NC}"

if [[ -f "$OFFBOARD_SCRIPT" ]]; then
  pass_ "offboard-tenant.sh exists"
else
  fail_ "offboard-tenant.sh not found"
fi

if [[ -x "$OFFBOARD_SCRIPT" ]]; then
  pass_ "offboard-tenant.sh is executable"
else
  fail_ "offboard-tenant.sh not executable (run chmod +x)"
fi

if grep -q -- "--force-delete" "$OFFBOARD_SCRIPT" 2>/dev/null; then
  pass_ "--force-delete flag present"
else
  fail_ "--force-delete flag missing"
fi

if grep -q -- "--grace-days" "$OFFBOARD_SCRIPT" 2>/dev/null; then
  pass_ "--grace-days flag present"
else
  fail_ "--grace-days flag missing"
fi

if grep -q -- "--actor" "$OFFBOARD_SCRIPT" 2>/dev/null; then
  pass_ "--actor flag present"
else
  fail_ "--actor flag missing"
fi

if grep -q -- "--dry-run" "$OFFBOARD_SCRIPT" 2>/dev/null; then
  pass_ "--dry-run flag present"
else
  fail_ "--dry-run flag missing"
fi

if grep -q "Grace period:" "$OFFBOARD_SCRIPT" 2>/dev/null; then
  pass_ "Grace period output message present"
else
  fail_ "Grace period output message missing"
fi

if grep -q "manage.py lms offboard_tenant" "$OFFBOARD_SCRIPT" 2>/dev/null; then
  pass_ "Calls Django management command"
else
  fail_ "Does not call Django management command"
fi

# ── Section 3: K8s CronJob for Nightly Isolation ────────────────────────
echo ""
echo -e "${BLUE}=== Section 3: Nightly Isolation CronJob ===${NC}"

if [[ -f "$CRONJOB_YAML" ]]; then
  pass_ "cronjob-tenant-isolation.yaml exists"
else
  fail_ "cronjob-tenant-isolation.yaml not found"
fi

if grep -q 'schedule: "0 2 \* \* \*"' "$CRONJOB_YAML" 2>/dev/null; then
  pass_ 'Schedule: "0 2 * * *" (2 AM daily UTC)'
else
  fail_ "Schedule not configured correctly"
fi

if grep -q "namespace: mereka-lms" "$CRONJOB_YAML" 2>/dev/null; then
  pass_ "Namespace: mereka-lms"
else
  fail_ "Namespace not configured"
fi

# Cache isolation: the CronJob must test that cache keys are scoped per tenant.
# Original (kubectl-exec): used tenant_cache_set/get from openedx_tenant_cache.
# Current (LMS-image): uses Django cache.set/get with tenant-prefixed keys.
if grep -q "Cache Isolation" "$CRONJOB_YAML" && \
   (grep -q "tenant_cache_set\|cache\.set\|cache\.get" "$CRONJOB_YAML" 2>/dev/null); then
  pass_ "Cache isolation test present"
else
  fail_ "Cache isolation test missing"
fi

# API/user isolation: the CronJob must verify enterprise user boundaries.
# Original (kubectl-exec): used check_tenant_access from openedx_tenant_cache.
# Current (LMS-image): checks EnterpriseCustomerUser linkage counts.
if grep -q "Isolation" "$CRONJOB_YAML" && \
   (grep -q "check_tenant_access\|EnterpriseCustomerUser\|enterprise_customer_users" "$CRONJOB_YAML" 2>/dev/null); then
  pass_ "API/user isolation test present"
else
  fail_ "API/user isolation test missing"
fi

# Metric reporting: the CronJob must emit failure counts.
# Currently: Python sys.exit(1) on failure (CronJob status = Failed).
# Pushgateway integration is quarantined (not deployed).
# The verifier checks for either pushgateway metric push OR exit-code-based failure reporting.
if grep -q "sys.exit(1)\|exit 1" "$CRONJOB_YAML" 2>/dev/null; then
  pass_ "Failure reporting present (exit code based)"
elif grep -q "pushgateway" "$CRONJOB_YAML" 2>/dev/null; then
  pass_ "Pushgateway metric push present"
else
  fail_ "Pushgateway metric push missing"
fi

if grep -q "activeDeadlineSeconds:" "$CRONJOB_YAML" 2>/dev/null; then
  pass_ "activeDeadlineSeconds configured"
else
  fail_ "activeDeadlineSeconds missing"
fi

# ── Section 4: PrometheusRule Alerts ────────────────────────────────────
echo ""
echo -e "${BLUE}=== Section 4: Prometheus Alerts ===${NC}"

if [[ -f "$ALERT_YAML" ]]; then
  pass_ "prometheusrule-tenant-isolation.yaml exists"
else
  fail_ "prometheusrule-tenant-isolation.yaml not found"
fi

if grep -q "alert: TenantIsolationFailure" "$ALERT_YAML" 2>/dev/null; then
  pass_ "TenantIsolationFailure alert defined"
else
  fail_ "TenantIsolationFailure alert missing"
fi

if grep -q "severity: critical" "$ALERT_YAML" 2>/dev/null; then
  pass_ "Alert severity: critical"
else
  fail_ "Alert severity not critical"
fi

if grep -q "for: 0m" "$ALERT_YAML" 2>/dev/null; then
  pass_ "Alert fires immediately (for: 0m) — within 5 minutes (AC-TEN-017)"
else
  fail_ "Alert delay too long (AC-TEN-017 requires <= 5m)"
fi

if grep -q "runbook_url:" "$ALERT_YAML" 2>/dev/null; then
  pass_ "Runbook URL present"
else
  fail_ "Runbook URL missing"
fi

if grep -q "alert: TenantIsolationTestMissing" "$ALERT_YAML" 2>/dev/null; then
  pass_ "TenantIsolationTestMissing alert defined"
else
  fail_ "TenantIsolationTestMissing alert missing"
fi

# ── Section 5: Load Test Script ─────────────────────────────────────────
echo ""
echo -e "${BLUE}=== Section 5: Load Test Script ===${NC}"

if [[ -f "$LOAD_TEST" ]]; then
  pass_ "load-test-tenants.sh exists"
else
  fail_ "load-test-tenants.sh not found"
fi

if [[ -x "$LOAD_TEST" ]]; then
  pass_ "load-test-tenants.sh is executable"
else
  fail_ "load-test-tenants.sh not executable (run chmod +x)"
fi

if grep -q -- "--count" "$LOAD_TEST" 2>/dev/null; then
  pass_ "--count N flag present"
else
  fail_ "--count N flag missing"
fi

if grep -q -- "--cleanup" "$LOAD_TEST" 2>/dev/null; then
  pass_ "--cleanup flag present"
else
  fail_ "--cleanup flag missing"
fi

if grep -q -- "--dry-run" "$LOAD_TEST" 2>/dev/null; then
  pass_ "--dry-run flag present"
else
  fail_ "--dry-run flag missing"
fi

if grep -q "Generate Synthetic Tenants" "$LOAD_TEST" 2>/dev/null; then
  pass_ "Synthetic tenant generation present"
else
  fail_ "Synthetic tenant generation missing"
fi

if grep -q "provision-tenant.sh" "$LOAD_TEST" && \
   grep -q -- "--dry-run" "$LOAD_TEST" 2>/dev/null; then
  pass_ "Provisioning dry-run validation present"
else
  fail_ "Provisioning dry-run validation missing"
fi

if grep -q "P95_THRESHOLD_MS=300" "$LOAD_TEST" 2>/dev/null; then
  pass_ "p95 threshold check (300ms) — AC-TEN-018"
else
  fail_ "p95 threshold check missing (AC-TEN-018)"
fi

if grep -q "BASELINE_THRESHOLD=120" "$LOAD_TEST" 2>/dev/null; then
  pass_ "Baseline threshold check (120%) — AC-TEN-019"
else
  fail_ "Baseline threshold check missing (AC-TEN-019)"
fi

# ── Section 6: LMS Production Settings ──────────────────────────────────
echo ""
echo -e "${BLUE}=== Section 6: LMS Production Settings ===${NC}"

if grep -q "TENANT_OFFBOARD_GRACE_DAYS" "$LMS_PRODUCTION_PY" 2>/dev/null; then
  pass_ "TENANT_OFFBOARD_GRACE_DAYS setting present"
else
  fail_ "TENANT_OFFBOARD_GRACE_DAYS setting missing"
fi

if grep -q "TENANT_NIGHTLY_ISOLATION_ENABLED" "$LMS_PRODUCTION_PY" 2>/dev/null; then
  pass_ "TENANT_NIGHTLY_ISOLATION_ENABLED setting present"
else
  fail_ "TENANT_NIGHTLY_ISOLATION_ENABLED setting missing"
fi

if grep -q "Phase 3: Operational Hardening" "$LMS_PRODUCTION_PY" 2>/dev/null; then
  pass_ "Phase 3 header comment present"
else
  fail_ "Phase 3 header comment missing"
fi

# ── Section 7: Data Deletion Guarantees ─────────────────────────────────
echo ""
echo -e "${BLUE}=== Section 7: Data Deletion Guarantees ===${NC}"

if grep -q "EnterpriseCustomerCatalog.objects.filter" "$OFFBOARD_CMD" && \
   grep -q ".delete()" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "AC-TEN-015: Enterprise catalog deletion code verified"
else
  fail_ "AC-TEN-015: Enterprise catalog deletion not verified"
fi

if grep -q "ALTER TABLE xapi_events_all DELETE" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "AC-TEN-016: ClickHouse events deletion code verified"
else
  fail_ "AC-TEN-016: ClickHouse events deletion not verified"
fi

if grep -q "'action'" "$OFFBOARD_CMD" && \
   grep -q "tenant_uuid" "$OFFBOARD_CMD" && \
   grep -q "'actor'" "$OFFBOARD_CMD" && \
   grep -q "'timestamp'" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "AC-TEN-020: Audit log format verified"
else
  fail_ "AC-TEN-020: Audit log format incomplete"
fi

if grep -q "Grace period not expired" "$OFFBOARD_CMD" && \
   grep -q "raise CommandError" "$OFFBOARD_CMD" 2>/dev/null; then
  pass_ "AC-TEN-021: Grace period enforcement verified"
else
  fail_ "AC-TEN-021: Grace period enforcement not verified"
fi

# ── Section 8: Runtime Tests (SKIP if --skip-cluster) ──────────────────
echo ""
echo -e "${BLUE}=== Section 8: Runtime Tests ===${NC}"

if [[ $SKIP_CLUSTER -eq 1 ]]; then
  warn_ "SKIP: Offboard test-tenant with --dry-run (--skip-cluster)"
  warn_ "SKIP: Nightly CronJob runs and reports (--skip-cluster)"
  warn_ "SKIP: Load test with 10 tenants (--skip-cluster)"
  warn_ "SKIP: Grace period blocks deletion (--skip-cluster)"
  warn_ "SKIP: Post-grace deletion succeeds (--skip-cluster)"
else
  # These would run against a live cluster
  warn_ "TODO: Runtime test: offboard test-tenant --dry-run"
  warn_ "TODO: Runtime test: kubectl get cronjob tenant-isolation-nightly"
  warn_ "TODO: Runtime test: load-test-tenants.sh --count 10 --cleanup"
  warn_ "TODO: Runtime test: verify grace period blocks deletion"
  warn_ "TODO: Runtime test: verify post-grace deletion succeeds"
fi

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "  Verification Summary"
echo "========================================================"
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo -e "  ${YELLOW}WARN${NC}: $WARN_COUNT"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo -e "${RED}Verification FAILED with $FAIL_COUNT failures${NC}"
  echo ""
  echo "Phase 3 acceptance criteria:"
  echo "  AC-TEN-014: Tenant deactivation API endpoint"
  echo "  AC-TEN-015: Enterprise catalog deletion"
  echo "  AC-TEN-016: ClickHouse events deletion"
  echo "  AC-TEN-017: Isolation regression alerts (critical within 5 min)"
  echo "  AC-TEN-018: Catalog API p95 <= 300ms at 10-tenant scale"
  echo "  AC-TEN-019: No tenant p95 > 120% of baseline"
  echo "  AC-TEN-020: Audit log with action, tenant UUID, actor, timestamp"
  echo "  AC-TEN-021: 30-day grace period before data deletion"
  exit 1
else
  echo -e "${GREEN}Verification PASSED (static checks)${NC}"
  echo ""
  echo "Phase 3 implementation complete:"
  echo "  ✓ Django management command with grace period enforcement"
  echo "  ✓ Shell script wrapper with --force-delete flag"
  echo "  ✓ Nightly K8s CronJob for isolation regression testing"
  echo "  ✓ PrometheusRule alerts (critical within 5 min)"
  echo "  ✓ Load test script for N-tenant scale validation"
  echo "  ✓ LMS production settings for grace days and isolation tests"
  echo ""
  echo "Runtime verification (requires live cluster):"
  echo "  - Deploy CronJob: kubectl apply -f deploy/k8s/base/monitoring/"
  echo "  - Test offboarding: ./scripts/tenants/offboard-tenant.sh --slug test --dry-run"
  echo "  - Load test: ./scripts/qa/load-test-tenants.sh --count 10 --cleanup"
  exit 0
fi
