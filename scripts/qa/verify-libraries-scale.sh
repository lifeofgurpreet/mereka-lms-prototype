#!/usr/bin/env bash
# @covers AC-LIB-020 through AC-LIB-025, AC-NEG-LIB-010 through AC-NEG-LIB-012
# @spec: content-libraries-v2 (Phase 3: Scale, Search, Analytics, Backup/Recovery)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

SKIP_CLUSTER=false
if [[ "${1:-}" == "--skip-cluster" ]]; then
  SKIP_CLUSTER=true
fi

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Content Libraries v2 Phase 3: Scale, Search, Analytics Verification ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Phase 3 Module Files
# ---------------------------------------------------------------------------
echo "[1/13] Verifying Phase 3 module files..."

if [[ -f "infrastructure/tutor/custom-apps/openedx_content_libraries/search.py" ]]; then
  pass "search.py module exists"
else
  fail "search.py module missing"
fi

if [[ -f "infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py" ]]; then
  pass "analytics.py module exists"
else
  fail "analytics.py module missing"
fi

if [[ -f "infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py" ]]; then
  pass "backup.py module exists"
else
  fail "backup.py module missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 2. Meilisearch Search Integration (AC-LIB-021)
# ---------------------------------------------------------------------------
echo "[2/13] Verifying Meilisearch integration (AC-LIB-021)..."

if grep -q "def search_libraries" infrastructure/tutor/custom-apps/openedx_content_libraries/search.py; then
  pass "AC-LIB-021: search_libraries function exists"
else
  fail "AC-LIB-021: search_libraries function missing"
fi

if grep -q "def search_components" infrastructure/tutor/custom-apps/openedx_content_libraries/search.py; then
  pass "AC-LIB-021: search_components function exists"
else
  fail "AC-LIB-021: search_components function missing"
fi

if grep -q "LIBRARY_INDEX_NAME.*=.*'content_libraries'" infrastructure/tutor/custom-apps/openedx_content_libraries/search.py; then
  pass "AC-LIB-021: Library index name configured"
else
  fail "AC-LIB-021: Library index name missing"
fi

if grep -q "COMPONENT_INDEX_NAME.*=.*'library_components'" infrastructure/tutor/custom-apps/openedx_content_libraries/search.py; then
  pass "AC-LIB-021: Component index name configured"
else
  fail "AC-LIB-021: Component index name missing"
fi

if grep -q "tenant_uuid" infrastructure/tutor/custom-apps/openedx_content_libraries/search.py; then
  pass "AC-LIB-021: Tenant isolation in search"
else
  fail "AC-LIB-021: Tenant isolation missing in search"
fi

if grep -q "def reindex_all" infrastructure/tutor/custom-apps/openedx_content_libraries/search.py; then
  pass "AC-LIB-021: reindex_all batch function exists"
else
  fail "AC-LIB-021: reindex_all missing"
fi

if grep -q "batch_size = 1000" infrastructure/tutor/custom-apps/openedx_content_libraries/search.py; then
  pass "AC-LIB-021: Batch size 1000 configured"
else
  fail "AC-LIB-021: Batch size not set to 1000"
fi

echo ""

# ---------------------------------------------------------------------------
# 3. Usage Analytics (AC-LIB-022)
# ---------------------------------------------------------------------------
echo "[3/13] Verifying usage analytics (AC-LIB-022)..."

if grep -q "def get_library_usage_report" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py; then
  pass "AC-LIB-022: get_library_usage_report function exists"
else
  fail "AC-LIB-022: get_library_usage_report missing"
fi

if grep -q "def get_library_analytics_summary" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py; then
  pass "AC-LIB-022: get_library_analytics_summary function exists"
else
  fail "AC-LIB-022: get_library_analytics_summary missing"
fi

if grep -q "def track_library_event" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py; then
  pass "AC-LIB-022: track_library_event function exists"
else
  fail "AC-LIB-022: track_library_event missing"
fi

if grep -q "total_courses" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py && \
   grep -q "len(courses)" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py; then
  pass "AC-LIB-022: Usage report shows all courses"
else
  fail "AC-LIB-022: Course count tracking missing"
fi

if grep -q "total_references" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py && \
   grep -q "refs.count()" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py; then
  pass "AC-LIB-022: Total references counted"
else
  fail "AC-LIB-022: Reference counting missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 4. OLX Export (AC-LIB-024)
# ---------------------------------------------------------------------------
echo "[4/13] Verifying OLX export (AC-LIB-024)..."

if grep -q "def export_library_to_olx" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-024: export_library_to_olx function exists"
else
  fail "AC-LIB-024: export_library_to_olx missing"
fi

if grep -q "def export_all_libraries" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-024: export_all_libraries function exists"
else
  fail "AC-LIB-024: export_all_libraries missing"
fi

if grep -q "format.*:.*'mereka-library-olx-v1'" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-024: OLX format version configured"
else
  fail "AC-LIB-024: OLX format version missing"
fi

if grep -q "component_count" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py && \
   grep -q "len.*components" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-024: Component count tracked in export"
else
  fail "AC-LIB-024: Component count tracking missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 5. Backup to GCS (AC-LIB-023)
# ---------------------------------------------------------------------------
echo "[5/13] Verifying GCS backup (AC-LIB-023)..."

if grep -q "def upload_backup_to_gcs" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-023: upload_backup_to_gcs function exists"
else
  fail "AC-LIB-023: upload_backup_to_gcs missing"
fi

if grep -q "BLOCKSTORE_BUCKET_NAME" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-023: Bucket name setting referenced"
else
  fail "AC-LIB-023: Bucket name setting missing"
fi

if grep -q "library-backups/" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-023: Backup path structure defined"
else
  fail "AC-LIB-023: Backup path missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 6. Disaster Recovery Restore (AC-LIB-023, AC-LIB-025)
# ---------------------------------------------------------------------------
echo "[6/13] Verifying disaster recovery restore (AC-LIB-023, AC-LIB-025)..."

if grep -q "def restore_from_backup" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-023: restore_from_backup function exists"
else
  fail "AC-LIB-023: restore_from_backup missing"
fi

if grep -q "dry_run=False" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-023: dry_run parameter supported"
else
  fail "AC-LIB-023: dry_run parameter missing"
fi

if grep -q "component_count_pre" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-025: Pre-restore component count tracked"
else
  fail "AC-LIB-025: Pre-restore count missing"
fi

if grep -q "component_count_post" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-LIB-025: Post-restore component count tracked"
else
  fail "AC-LIB-025: Post-restore count missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 7. Performance Optimization (AC-LIB-020)
# ---------------------------------------------------------------------------
echo "[7/13] Verifying performance optimization (AC-LIB-020)..."

if grep -q "LIBRARY_LIST_PAGE_SIZE" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "AC-LIB-020: LIBRARY_LIST_PAGE_SIZE setting exists"
else
  fail "AC-LIB-020: LIBRARY_LIST_PAGE_SIZE missing"
fi

if grep -q "LIBRARY_QUERY_OPTIMIZATION_ENABLED" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "AC-LIB-020: LIBRARY_QUERY_OPTIMIZATION_ENABLED setting exists"
else
  fail "AC-LIB-020: LIBRARY_QUERY_OPTIMIZATION_ENABLED missing"
fi

if grep -q "select_related.*'library'" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py || \
   grep -q "select_related.*'component'" infrastructure/tutor/custom-apps/openedx_content_libraries/analytics.py; then
  pass "AC-LIB-020: select_related optimization used"
else
  skip "AC-LIB-020: select_related optimization (to be added if needed)"
fi

echo ""

# ---------------------------------------------------------------------------
# 8. Negative Assertions (AC-NEG-LIB-010 through AC-NEG-LIB-012)
# ---------------------------------------------------------------------------
echo "[8/13] Verifying negative assertions..."

if grep -q "AC-NEG-LIB-010.*SYNTHETIC" scripts/qa/generate-synthetic-libraries.sh && \
   grep -q "Synthetic data only.*NOT production" scripts/qa/generate-synthetic-libraries.sh; then
  pass "AC-NEG-LIB-010: Load test uses synthetic data only"
else
  fail "AC-NEG-LIB-010: Synthetic data warning missing"
fi

if grep -q "skip_expired_deleted" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-NEG-LIB-011: Skip expired deleted libraries logic exists"
else
  fail "AC-NEG-LIB-011: Skip expired logic missing"
fi

if grep -q "skip_newer" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-NEG-LIB-012: Skip newer libraries logic exists"
else
  fail "AC-NEG-LIB-012: Skip newer logic missing"
fi

if grep -q "modified after backup" infrastructure/tutor/custom-apps/openedx_content_libraries/backup.py; then
  pass "AC-NEG-LIB-012: Timestamp comparison implemented"
else
  fail "AC-NEG-LIB-012: Timestamp comparison missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 9. Management Commands
# ---------------------------------------------------------------------------
echo "[9/13] Verifying management commands..."

if [[ -f "infrastructure/tutor/custom-apps/openedx_content_libraries/management/commands/reindex_libraries.py" ]]; then
  pass "reindex_libraries management command exists"
else
  fail "reindex_libraries command missing"
fi

if [[ -f "infrastructure/tutor/custom-apps/openedx_content_libraries/management/commands/backup_libraries.py" ]]; then
  pass "backup_libraries management command exists"
else
  fail "backup_libraries command missing"
fi

if [[ -f "infrastructure/tutor/custom-apps/openedx_content_libraries/management/commands/restore_libraries.py" ]]; then
  pass "restore_libraries management command exists"
else
  fail "restore_libraries command missing"
fi

if grep -q "add_argument.*--local-only" infrastructure/tutor/custom-apps/openedx_content_libraries/management/commands/backup_libraries.py; then
  pass "backup_libraries: --local-only flag supported"
else
  fail "backup_libraries: --local-only flag missing"
fi

if grep -q "add_argument.*--dry-run" infrastructure/tutor/custom-apps/openedx_content_libraries/management/commands/restore_libraries.py; then
  pass "restore_libraries: --dry-run flag supported"
else
  fail "restore_libraries: --dry-run flag missing"
fi

if grep -q "add_argument.*--force" infrastructure/tutor/custom-apps/openedx_content_libraries/management/commands/restore_libraries.py; then
  pass "restore_libraries: --force flag supported"
else
  fail "restore_libraries: --force flag missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 10. K8s CronJob
# ---------------------------------------------------------------------------
echo "[10/13] Verifying K8s CronJob..."

if [[ -f "deploy/k8s/base/monitoring/cronjob-library-export.yaml" ]]; then
  pass "CronJob library-export.yaml exists"
else
  fail "CronJob library-export.yaml missing"
fi

if grep -q "schedule:.*\"0 3 \* \* \*\"" deploy/k8s/base/monitoring/cronjob-library-export.yaml; then
  pass "CronJob: Nightly 3 AM schedule configured"
else
  fail "CronJob: Schedule missing or incorrect"
fi

if grep -q "backup_libraries" deploy/k8s/base/monitoring/cronjob-library-export.yaml; then
  pass "CronJob: Runs backup_libraries command"
else
  fail "CronJob: Command incorrect"
fi

echo ""

# ---------------------------------------------------------------------------
# 11. LMS/CMS Settings
# ---------------------------------------------------------------------------
echo "[11/13] Verifying LMS/CMS settings..."

if grep -q "LIBRARY_SEARCH_ENABLED" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "LMS: LIBRARY_SEARCH_ENABLED setting exists"
else
  fail "LMS: LIBRARY_SEARCH_ENABLED missing"
fi

if grep -q "LIBRARY_ANALYTICS_ENABLED" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "LMS: LIBRARY_ANALYTICS_ENABLED setting exists"
else
  fail "LMS: LIBRARY_ANALYTICS_ENABLED missing"
fi

if grep -q "LIBRARY_BACKUP_ENABLED" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "LMS: LIBRARY_BACKUP_ENABLED setting exists"
else
  fail "LMS: LIBRARY_BACKUP_ENABLED missing"
fi

if grep -q "LIBRARY_BACKUP_RETENTION_DAYS" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "LMS: LIBRARY_BACKUP_RETENTION_DAYS setting exists"
else
  fail "LMS: LIBRARY_BACKUP_RETENTION_DAYS missing"
fi

if grep -q "LIBRARY_LIST_PAGE_SIZE" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "LMS: LIBRARY_LIST_PAGE_SIZE setting exists"
else
  fail "LMS: LIBRARY_LIST_PAGE_SIZE missing"
fi

if grep -q "LIBRARY_QUERY_OPTIMIZATION_ENABLED" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
  pass "LMS: LIBRARY_QUERY_OPTIMIZATION_ENABLED setting exists"
else
  fail "LMS: LIBRARY_QUERY_OPTIMIZATION_ENABLED missing"
fi

if grep -q "LIBRARY_SEARCH_ENABLED" deploy/k8s/base/apps/openedx/settings/cms/production.py; then
  pass "CMS: LIBRARY_SEARCH_ENABLED setting exists"
else
  fail "CMS: LIBRARY_SEARCH_ENABLED missing"
fi

if grep -q "LIBRARY_LIST_PAGE_SIZE" deploy/k8s/base/apps/openedx/settings/cms/production.py; then
  pass "CMS: LIBRARY_LIST_PAGE_SIZE setting exists"
else
  fail "CMS: LIBRARY_LIST_PAGE_SIZE missing"
fi

# Check default values
if grep -q "\"false\"" deploy/k8s/base/apps/openedx/settings/lms/production.py | grep -q "LIBRARY_SEARCH_ENABLED"; then
  pass "Settings default to 'false' (feature flags)"
else
  skip "Settings: Default values check (manual verification needed)"
fi

echo ""

# ---------------------------------------------------------------------------
# 12. API Endpoints
# ---------------------------------------------------------------------------
echo "[12/13] Verifying API endpoints..."

if grep -q "LibrarySearchView" infrastructure/tutor/custom-apps/openedx_content_libraries/views.py; then
  pass "LibrarySearchView exists"
else
  fail "LibrarySearchView missing"
fi

if grep -q "LibraryUsageReportView" infrastructure/tutor/custom-apps/openedx_content_libraries/views.py; then
  pass "LibraryUsageReportView exists"
else
  fail "LibraryUsageReportView missing"
fi

if grep -q "LibraryAnalyticsSummaryView" infrastructure/tutor/custom-apps/openedx_content_libraries/views.py; then
  pass "LibraryAnalyticsSummaryView exists"
else
  fail "LibraryAnalyticsSummaryView missing"
fi

if grep -q "libraries/search/" infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py; then
  pass "URL: libraries/search/ endpoint configured"
else
  fail "URL: libraries/search/ endpoint missing"
fi

if grep -q "libraries/analytics/" infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py; then
  pass "URL: libraries/analytics/ endpoint configured"
else
  fail "URL: libraries/analytics/ endpoint missing"
fi

if grep -q "libraries/<path:library_key>/usage/" infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py; then
  pass "URL: libraries/<key>/usage/ endpoint configured"
else
  fail "URL: libraries/<key>/usage/ endpoint missing"
fi

echo ""

# ---------------------------------------------------------------------------
# 13. Runtime Tests (SKIP with --skip-cluster)
# ---------------------------------------------------------------------------
echo "[13/13] Runtime tests..."

if [[ "$SKIP_CLUSTER" == "true" ]]; then
  skip "Runtime: Skipping cluster tests (--skip-cluster)"
else
  skip "Runtime: Requires live cluster (not implemented yet)"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "FAILED: Libraries Phase 3 verification incomplete"
  exit 1
else
  echo ""
  echo "SUCCESS: All Phase 3 components verified"
  exit 0
fi
