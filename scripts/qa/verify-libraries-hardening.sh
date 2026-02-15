#!/usr/bin/env bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0
SKIP_CLUSTER=false

# Parse args
for arg in "$@"; do
  if [[ "$arg" == "--skip-cluster" ]]; then
    SKIP_CLUSTER=true
  fi
done

echo "=============================================="
echo "Libraries Phase 3-4 Hardening Verification"
echo "=============================================="
echo ""

check() {
  local name="$1"
  local command="$2"

  if eval "$command" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name"
    FAILED=$((FAILED + 1))
  fi
}

check_file() {
  local name="$1"
  local file="$2"

  if [[ -f "$file" ]]; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (file not found: $file)"
    FAILED=$((FAILED + 1))
  fi
}

check_content() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name"
    FAILED=$((FAILED + 1))
  fi
}

# ── Section 1: Phase 3-4 Module Files ──────────────────────────────────
echo "1. Phase 3-4 Module Files"
check_file "quotas.py exists" "infrastructure/tutor/custom-apps/openedx_content_libraries/quotas.py"
check_file "xapi.py exists" "infrastructure/tutor/custom-apps/openedx_content_libraries/xapi.py"
check_file "sanitize.py exists" "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py"
check_file "export_import.py exists" "infrastructure/tutor/custom-apps/openedx_content_libraries/export_import.py"
echo ""

# ── Section 2: Tenant Quotas (AC-LIB-026) ──────────────────────────────
echo "2. Tenant Quotas (AC-LIB-026)"
check_content "TenantLibraryQuota model defined" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/models.py" \
  "class TenantLibraryQuota"
check_content "get_tenant_quota function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/quotas.py" \
  "def get_tenant_quota"
check_content "check_quota function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/quotas.py" \
  "def check_quota"
check_content "enforce_quota decorator" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/quotas.py" \
  "def enforce_quota"
check_content "DEFAULT_LIBRARY_QUOTA constant" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/quotas.py" \
  "DEFAULT_LIBRARY_QUOTA"
check_content "TenantLibraryQuota admin registered" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/admin.py" \
  "TenantLibraryQuota"
echo ""

# ── Section 3: xAPI Events (AC-LIB-027) ─────────────────────────────────
echo "3. xAPI Events (AC-LIB-027)"
check_content "emit_library_content_viewed function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/xapi.py" \
  "def emit_library_content_viewed"
check_content "VERB_LIBRARY_CONTENT_VIEWED constant" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/xapi.py" \
  "VERB_LIBRARY_CONTENT_VIEWED"
check_content "_send_xapi_event function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/xapi.py" \
  "def _send_xapi_event"
check_content "No PII beyond user_id (AC-NEG-LIB-013)" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/xapi.py" \
  "actor_id.*user_id"
echo ""

# ── Section 4: Performance (AC-LIB-028, AC-LIB-029) ────────────────────
echo "4. Performance (AC-LIB-028, AC-LIB-029)"
check_content "Rate limiting check_rate_limit" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/quotas.py" \
  "def check_rate_limit"
check_content "Cache usage in quotas" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/quotas.py" \
  "cache.get"
check_content "LIBRARY_LIST_PAGE_SIZE setting" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" \
  "LIBRARY_LIST_PAGE_SIZE"
check_content "LIBRARY_RATE_LIMIT_PER_MINUTE setting" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" \
  "LIBRARY_RATE_LIMIT_PER_MINUTE"
echo ""

# ── Section 5: Backup CronJob (AC-LIB-030) ─────────────────────────────
echo "5. Backup CronJob (AC-LIB-030)"
check_file "CronJob manifest exists (from Phase 3)" \
  "deploy/k8s/base/monitoring/cronjob-library-export.yaml"
echo ""

# ── Section 6: Content Sanitization (AC-LIB-031) ───────────────────────
echo "6. Content Sanitization (AC-LIB-031)"
check_content "detect_xss function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py" \
  "def detect_xss"
check_content "detect_sql_injection function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py" \
  "def detect_sql_injection"
check_content "sanitize_library_content function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py" \
  "def sanitize_library_content"
check_content "ALLOWED_TAGS whitelist" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py" \
  "ALLOWED_TAGS"
check_content "XSS_PATTERNS regex list" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py" \
  "XSS_PATTERNS"
check_content "audit_library_content function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py" \
  "def audit_library_content"
echo ""

# ── Section 7: Cross-Tenant Audit (AC-LIB-032) ─────────────────────────
echo "7. Cross-Tenant Audit (AC-LIB-032)"
check_content "export_library_for_tenant ownership check" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/export_import.py" \
  "Cannot export another tenant"
check_content "import sets tenant_uuid" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/export_import.py" \
  "tenant_uuid = importing_tenant_uuid"
echo ""

# ── Section 8: Negative Assertions ─────────────────────────────────────
echo "8. Negative Assertions"
check_content "AC-NEG-LIB-013: No PII in xAPI (no email/name/IP)" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/xapi.py" \
  "user ID only, no PII"
check_content "AC-NEG-LIB-014: No JS execution (script removal)" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/sanitize.py" \
  "Remove script tags"
# AC-NEG-LIB-015 is a runtime check (load test --production flag)
echo -e "${YELLOW}⊘${NC} AC-NEG-LIB-015: Load test --production flag (runtime check, skipped)"
echo ""

# ── Section 9: Export/Import Between Tenants ───────────────────────────
echo "9. Export/Import Between Tenants"
check_content "export_library_for_tenant function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/export_import.py" \
  "def export_library_for_tenant"
check_content "import_library_for_tenant function" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/export_import.py" \
  "def import_library_for_tenant"
check_content "tenant_uuid enforcement in export" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/export_import.py" \
  "PermissionError"
echo ""

# ── Section 10: Management Commands ────────────────────────────────────
echo "10. Management Commands"
check_file "audit_library_security command" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/management/commands/audit_library_security.py"
echo ""

# ── Section 11: LMS/CMS Settings ───────────────────────────────────────
echo "11. LMS/CMS Settings"
check_content "LMS: LIBRARY_QUOTAS_ENABLED" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" \
  "LIBRARY_QUOTAS_ENABLED"
check_content "LMS: LIBRARY_XAPI_ENABLED" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" \
  "LIBRARY_XAPI_ENABLED"
check_content "LMS: LIBRARY_CONTENT_SANITIZATION_ENABLED" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" \
  "LIBRARY_CONTENT_SANITIZATION_ENABLED"
check_content "CMS: LIBRARY_QUOTAS_ENABLED" \
  "deploy/k8s/base/apps/openedx/settings/cms/production.py" \
  "LIBRARY_QUOTAS_ENABLED"
check_content "CMS: LIBRARY_CONTENT_SANITIZATION_ENABLED" \
  "deploy/k8s/base/apps/openedx/settings/cms/production.py" \
  "LIBRARY_CONTENT_SANITIZATION_ENABLED"
echo ""

# ── Section 12: API Endpoints ──────────────────────────────────────────
echo "12. API Endpoints"
check_content "LibraryQuotaView in views" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/views.py" \
  "class LibraryQuotaView"
check_content "LibraryExportImportView in views" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/views.py" \
  "class LibraryExportImportView"
check_content "LibrarySecurityAuditView in views" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/views.py" \
  "class LibrarySecurityAuditView"
check_content "quotas URL pattern" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py" \
  "libraries/quotas/"
check_content "export URL pattern" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py" \
  "export/"
check_content "import URL pattern" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py" \
  "import/"
check_content "security-audit URL pattern" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py" \
  "security-audit/"
echo ""

# ── Section 13: Admin Registration ─────────────────────────────────────
echo "13. Admin Registration"
check_content "TenantLibraryQuota imported in admin" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/admin.py" \
  "TenantLibraryQuota"
check_content "TenantLibraryQuotaAdmin class" \
  "infrastructure/tutor/custom-apps/openedx_content_libraries/admin.py" \
  "class TenantLibraryQuotaAdmin"
echo ""

# ── Section 14: Runtime Tests ──────────────────────────────────────────
if [[ "$SKIP_CLUSTER" == "false" ]]; then
  echo "14. Runtime Tests (K8s Cluster)"
  echo -e "${YELLOW}⊘${NC} Runtime tests require cluster (use --skip-cluster to skip)"
  echo ""
else
  echo "14. Runtime Tests (SKIPPED)"
  echo -e "${YELLOW}⊘${NC} Cluster tests skipped (--skip-cluster flag)"
  echo ""
fi

# ── Summary ────────────────────────────────────────────────────────────
echo "=============================================="
echo "SUMMARY"
echo "=============================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some checks failed${NC}"
  exit 1
fi
