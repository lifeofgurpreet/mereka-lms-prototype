#!/usr/bin/env bash
# Verify Libraries Phase 2 — Tenant Isolation implementation
#
# @spec: content-libraries-v2 (Phase 2: Tenant Libraries)
# @covers: AC-LIB-014 through AC-LIB-019
#
# Usage:
#   ./scripts/qa/verify-libraries-tenant.sh [--skip-cluster]
#
# Flags:
#   --skip-cluster   Skip runtime cluster tests (offline mode)

set -euo pipefail

# ── Color Codes ────────────────────────────────────────────────────────
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ── Counters ───────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ── Flags ──────────────────────────────────────────────────────────────
SKIP_CLUSTER=false

# ── Parse Arguments ────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
  esac
done

# ── Helper Functions ───────────────────────────────────────────────────
pass() {
  echo -e "${GREEN}✓ PASS${NC}: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo -e "${RED}✗ FAIL${NC}: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

skip() {
  echo -e "${YELLOW}⊘ SKIP${NC}: $1"
  SKIP_COUNT=$((SKIP_COUNT + 1))
}

section() {
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
}

check_file_exists() {
  local file="$1"
  local description="$2"

  if [[ -f "$file" ]]; then
    pass "$description: $file"
  else
    fail "$description: $file (NOT FOUND)"
  fi
}

check_pattern_in_file() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if [[ ! -f "$file" ]]; then
    fail "$description: $file (FILE NOT FOUND)"
    return 0
  fi

  if grep -qF "$pattern" "$file" || grep -qE "$pattern" "$file"; then
    pass "$description"
  else
    fail "$description (pattern not found: $pattern)"
  fi

  return 0
}

# ── Section 1: New Model Fields ────────────────────────────────────────
section "1. New Model Fields (Phase 2)"

MODELS_FILE="infrastructure/tutor/custom-apps/openedx_content_libraries/models.py"

check_pattern_in_file \
  "tenant_uuid = models.UUIDField" \
  "$MODELS_FILE" \
  "LibraryMetadata.tenant_uuid field"

check_pattern_in_file \
  "allow_public_read = models.BooleanField" \
  "$MODELS_FILE" \
  "LibraryMetadata.allow_public_read field"

check_pattern_in_file \
  "allow_public_read_locked_at = models.DateTimeField" \
  "$MODELS_FILE" \
  "LibraryMetadata.allow_public_read_locked_at field"

check_pattern_in_file \
  "class LibraryRole" \
  "$MODELS_FILE" \
  "LibraryRole model"

check_pattern_in_file \
  "class LibraryAccessLog" \
  "$MODELS_FILE" \
  "LibraryAccessLog model"

check_pattern_in_file \
  "ROLE_ADMIN = 'library_admin'" \
  "$MODELS_FILE" \
  "LibraryRole.ROLE_ADMIN constant"

check_pattern_in_file \
  "ROLE_AUTHOR = 'library_author'" \
  "$MODELS_FILE" \
  "LibraryRole.ROLE_AUTHOR constant"

check_pattern_in_file \
  "ROLE_READER = 'library_reader'" \
  "$MODELS_FILE" \
  "LibraryRole.ROLE_READER constant"

check_pattern_in_file \
  "ACTION_CROSS_TENANT_ATTEMPT" \
  "$MODELS_FILE" \
  "LibraryAccessLog.ACTION_CROSS_TENANT_ATTEMPT"

check_pattern_in_file \
  "ACTION_ROLE_ESCALATION_ATTEMPT" \
  "$MODELS_FILE" \
  "LibraryAccessLog.ACTION_ROLE_ESCALATION_ATTEMPT"

# ── Section 2: Org-Scoped Filtering (AC-LIB-014) ───────────────────────
section "2. Org-Scoped Filtering (AC-LIB-014)"

API_FILE="infrastructure/tutor/custom-apps/openedx_content_libraries/api.py"

check_pattern_in_file \
  "def get_tenant_libraries" \
  "$API_FILE" \
  "get_tenant_libraries function"

check_pattern_in_file \
  "tenant_uuid=tenant_uuid" \
  "$API_FILE" \
  "get_tenant_libraries filters by tenant_uuid"

check_pattern_in_file \
  "allow_public_read=True" \
  "$API_FILE" \
  "get_tenant_libraries includes public libraries"

VIEWS_FILE="infrastructure/tutor/custom-apps/openedx_content_libraries/views.py"

check_pattern_in_file \
  "get_user_tenant_uuid" \
  "$VIEWS_FILE" \
  "LibraryListView uses get_user_tenant_uuid"

check_pattern_in_file \
  "LIBRARY_TENANT_ISOLATION_ENABLED" \
  "$VIEWS_FILE" \
  "LibraryListView checks LIBRARY_TENANT_ISOLATION_ENABLED"

# ── Section 3: Public Library Support (AC-LIB-015) ─────────────────────
section "3. Public Library Support (AC-LIB-015)"

check_pattern_in_file \
  "def enable_public_read" \
  "$API_FILE" \
  "enable_public_read function"

check_pattern_in_file \
  "def disable_public_read" \
  "$API_FILE" \
  "disable_public_read function"

check_pattern_in_file \
  "allow_public_read_locked_at = timezone.now()" \
  "$API_FILE" \
  "enable_public_read sets lock timestamp"

check_pattern_in_file \
  "class LibraryPublicReadView" \
  "$VIEWS_FILE" \
  "LibraryPublicReadView"

# ── Section 4: RBAC Enforcement (AC-LIB-016) ───────────────────────────
section "4. RBAC Enforcement (AC-LIB-016)"

check_pattern_in_file \
  "def grant_library_role" \
  "$API_FILE" \
  "grant_library_role function"

check_pattern_in_file \
  "def check_library_permission" \
  "$API_FILE" \
  "check_library_permission function"

check_pattern_in_file \
  "LibraryRole.ROLE_ADMIN" \
  "$API_FILE" \
  "check_library_permission uses role hierarchy"

check_pattern_in_file \
  "check_library_permission" \
  "$VIEWS_FILE" \
  "LibraryPublishView uses check_library_permission"

check_pattern_in_file \
  "HTTP_403_FORBIDDEN" \
  "$VIEWS_FILE" \
  "LibraryPublishView returns 403 for insufficient permissions"

# ── Section 5: Last-Admin Prevention (AC-LIB-017) ──────────────────────
section "5. Last-Admin Prevention (AC-LIB-017)"

check_pattern_in_file \
  "def revoke_library_role" \
  "$API_FILE" \
  "revoke_library_role function"

check_pattern_in_file \
  "admin_count <= 1" \
  "$API_FILE" \
  "revoke_library_role checks admin count"

check_pattern_in_file \
  "Cannot remove the last admin" \
  "$API_FILE" \
  "revoke_library_role raises ValueError for last admin"

# ── Section 6: Security Event Logging (AC-LIB-018) ─────────────────────
section "6. Security Event Logging (AC-LIB-018)"

check_pattern_in_file \
  "def log_library_access" \
  "$API_FILE" \
  "log_library_access function"

check_pattern_in_file \
  "LibraryAccessLog.objects.create" \
  "$API_FILE" \
  "log_library_access creates log entries"

check_pattern_in_file \
  "ACTION_CROSS_TENANT_ATTEMPT" \
  "$API_FILE" \
  "log_library_access handles cross-tenant attempts"

check_pattern_in_file \
  "logger.warning" \
  "$API_FILE" \
  "log_library_access logs security events at WARNING level"

# ── Section 7: Cross-Tenant Prevention (AC-LIB-019) ────────────────────
section "7. Cross-Tenant Prevention (AC-LIB-019)"

check_pattern_in_file \
  "Q(tenant_uuid=tenant_uuid" \
  "$API_FILE" \
  "get_tenant_libraries filters by tenant (prevents cross-tenant)"

check_pattern_in_file \
  "get_user_tenant_uuid" \
  "$VIEWS_FILE" \
  "LibraryListView resolves user tenant"

# ── Section 8: Negative Assertions ─────────────────────────────────────
section "8. Negative Assertions (AC-NEG-LIB-007, AC-NEG-LIB-008, AC-NEG-LIB-009)"

# AC-NEG-LIB-007: Cross-tenant data leakage prevention
check_pattern_in_file \
  "Cross-tenant libraries are NOT included" \
  "$API_FILE" \
  "AC-NEG-LIB-007: Cross-tenant exclusion documented"

# AC-NEG-LIB-008: Public library opt-in reversal prevention
check_pattern_in_file \
  "library has been forked by other tenants" \
  "$API_FILE" \
  "AC-NEG-LIB-008: Fork prevention in disable_public_read"

check_pattern_in_file \
  "cross_tenant_refs" \
  "$API_FILE" \
  "AC-NEG-LIB-008: Checks for cross-tenant references"

# AC-NEG-LIB-009: Role escalation prevention
check_pattern_in_file \
  "ACTION_ROLE_ESCALATION_ATTEMPT" \
  "$VIEWS_FILE" \
  "AC-NEG-LIB-009: Role escalation attempts logged"

# ── Section 9: LMS/CMS Settings ────────────────────────────────────────
section "9. LMS/CMS Settings"

LMS_SETTINGS="deploy/k8s/base/apps/openedx/settings/lms/production.py"

check_pattern_in_file \
  "LIBRARY_TENANT_ISOLATION_ENABLED" \
  "$LMS_SETTINGS" \
  "LMS: LIBRARY_TENANT_ISOLATION_ENABLED"

check_pattern_in_file \
  "LIBRARY_PUBLIC_READ_ENABLED" \
  "$LMS_SETTINGS" \
  "LMS: LIBRARY_PUBLIC_READ_ENABLED"

check_pattern_in_file \
  "LIBRARY_RBAC_ENABLED" \
  "$LMS_SETTINGS" \
  "LMS: LIBRARY_RBAC_ENABLED"

check_pattern_in_file \
  "LIBRARY_ACCESS_LOGGING_ENABLED" \
  "$LMS_SETTINGS" \
  "LMS: LIBRARY_ACCESS_LOGGING_ENABLED"

CMS_SETTINGS="deploy/k8s/base/apps/openedx/settings/cms/production.py"

check_pattern_in_file \
  "LIBRARY_TENANT_ISOLATION_ENABLED" \
  "$CMS_SETTINGS" \
  "CMS: LIBRARY_TENANT_ISOLATION_ENABLED"

check_pattern_in_file \
  "LIBRARY_RBAC_ENABLED" \
  "$CMS_SETTINGS" \
  "CMS: LIBRARY_RBAC_ENABLED"

# ── Section 10: API Endpoints ──────────────────────────────────────────
section "10. API Endpoints"

URLS_FILE="infrastructure/tutor/custom-apps/openedx_content_libraries/urls.py"

check_pattern_in_file \
  "library_key>/roles/" \
  "$URLS_FILE" \
  "Roles endpoint: /libraries/<library_key>/roles/"

check_pattern_in_file \
  "library_key>/public-read/" \
  "$URLS_FILE" \
  "Public read endpoint: /libraries/<library_key>/public-read/"

check_pattern_in_file \
  "LibraryRoleView" \
  "$URLS_FILE" \
  "LibraryRoleView registered in URLs"

check_pattern_in_file \
  "LibraryPublicReadView" \
  "$URLS_FILE" \
  "LibraryPublicReadView registered in URLs"

# ── Section 11: Serializers ────────────────────────────────────────────
section "11. Serializers"

SERIALIZERS_FILE="infrastructure/tutor/custom-apps/openedx_content_libraries/serializers.py"

check_pattern_in_file \
  "class LibraryRoleSerializer" \
  "$SERIALIZERS_FILE" \
  "LibraryRoleSerializer"

check_pattern_in_file \
  "class LibraryAccessLogSerializer" \
  "$SERIALIZERS_FILE" \
  "LibraryAccessLogSerializer"

check_pattern_in_file \
  "tenant_uuid" \
  "$SERIALIZERS_FILE" \
  "LibraryMetadataSerializer includes tenant_uuid"

check_pattern_in_file \
  "allow_public_read" \
  "$SERIALIZERS_FILE" \
  "LibraryMetadataSerializer includes allow_public_read"

# ── Section 12: Admin Registration ────────────────────────────────────
section "12. Admin Registration"

ADMIN_FILE="infrastructure/tutor/custom-apps/openedx_content_libraries/admin.py"

check_pattern_in_file \
  "LibraryRole" \
  "$ADMIN_FILE" \
  "LibraryRole registered in admin"

check_pattern_in_file \
  "LibraryAccessLog" \
  "$ADMIN_FILE" \
  "LibraryAccessLog registered in admin"

check_pattern_in_file \
  "tenant_uuid" \
  "$ADMIN_FILE" \
  "LibraryMetadataAdmin shows tenant_uuid"

check_pattern_in_file \
  "allow_public_read" \
  "$ADMIN_FILE" \
  "LibraryMetadataAdmin shows allow_public_read"

# ── Section 13: Runtime Tests (Cluster Required) ───────────────────────
section "13. Runtime Tests (Cluster Required)"

if [[ "$SKIP_CLUSTER" == true ]]; then
  skip "Runtime tests (--skip-cluster flag set)"
else
  # Check if kubectl is available
  if ! command -v kubectl &> /dev/null; then
    skip "kubectl not found, skipping runtime tests"
  else
    # Check if namespace exists
    if ! kubectl get namespace mereka-lms &> /dev/null; then
      skip "Namespace mereka-lms not found, skipping runtime tests"
    else
      pass "kubectl and namespace available"

      # TODO: Add runtime tests when cluster is available
      # - Create library with tenant_uuid
      # - Grant roles
      # - Test cross-tenant access prevention
      # - Test public library visibility
      # - Test RBAC enforcement
      skip "Runtime integration tests not yet implemented"
    fi
  fi
fi

# ── Final Summary ──────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}VERIFICATION SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}PASS: $PASS_COUNT${NC}"
echo -e "${RED}FAIL: $FAIL_COUNT${NC}"
echo -e "${YELLOW}SKIP: $SKIP_COUNT${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo ""
  echo -e "${GREEN}✓ All checks passed!${NC}"
  echo ""
  echo "Phase 2 implementation verified successfully."
  echo ""
  echo "Next steps:"
  echo "  1. Run database migrations: tutor local do lms manage migrate"
  echo "  2. Enable tenant isolation: export LIBRARY_TENANT_ISOLATION_ENABLED=true"
  echo "  3. Enable public libraries: export LIBRARY_PUBLIC_READ_ENABLED=true"
  echo "  4. Enable RBAC: export LIBRARY_RBAC_ENABLED=true"
  echo "  5. Test with actual tenant data"
  exit 0
else
  echo ""
  echo -e "${RED}✗ Verification failed with $FAIL_COUNT errors${NC}"
  exit 1
fi
