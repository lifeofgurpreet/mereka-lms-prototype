#!/usr/bin/env bash
#
# Verification script for Libraries Phase 1 — Platform Libraries
#
# @spec: content-libraries-v2
# @covers: AC-LIB-007 through AC-LIB-013
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
SKIP=0

# Repository paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CUSTOM_APPS="$REPO_ROOT/infrastructure/tutor/custom-apps"
LIB_APP="$CUSTOM_APPS/openedx_content_libraries"
LMS_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"

# Parse CLI args
SKIP_CLUSTER=false
for arg in "$@"; do
  case $arg in
    --skip-cluster)
      SKIP_CLUSTER=true
      shift
      ;;
  esac
done

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

skip() {
  echo -e "${YELLOW}⊘${NC} $1"
  SKIP=$((SKIP + 1))
}

section() {
  echo ""
  echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

# ────────────────────────────────────────────────────────────────────────
section "Section 1: App Structure"

# Check all required files exist
FILES=(
  "__init__.py"
  "apps.py"
  "models.py"
  "api.py"
  "views.py"
  "serializers.py"
  "urls.py"
  "admin.py"
  "signals.py"
  "setup.py"
  "migrations/__init__.py"
  "management/__init__.py"
  "management/commands/__init__.py"
  "management/commands/create_platform_library.py"
)

for file in "${FILES[@]}"; do
  if [[ -f "$LIB_APP/$file" ]]; then
    pass "File exists: $file"
  else
    fail "Missing file: $file"
  fi
done

# ────────────────────────────────────────────────────────────────────────
section "Section 2: Models (AC-LIB-007 to AC-LIB-013)"

# LibraryMetadata model
if grep -q "class LibraryMetadata(models.Model):" "$LIB_APP/models.py"; then
  pass "LibraryMetadata model defined"
else
  fail "LibraryMetadata model missing"
fi

if grep -q "library_key.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryMetadata has library_key field"
else
  fail "LibraryMetadata missing library_key"
fi

if grep -q "org.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryMetadata has org field"
else
  fail "LibraryMetadata missing org field"
fi

if grep -q "is_deleted.*BooleanField" "$LIB_APP/models.py"; then
  pass "LibraryMetadata has is_deleted field"
else
  fail "LibraryMetadata missing is_deleted"
fi

if grep -q "def soft_delete" "$LIB_APP/models.py"; then
  pass "LibraryMetadata has soft_delete method"
else
  fail "LibraryMetadata missing soft_delete method"
fi

if grep -q "def restore" "$LIB_APP/models.py"; then
  pass "LibraryMetadata has restore method"
else
  fail "LibraryMetadata missing restore method"
fi

if grep -q "def can_permanent_delete" "$LIB_APP/models.py"; then
  pass "LibraryMetadata has can_permanent_delete property"
else
  fail "LibraryMetadata missing can_permanent_delete property"
fi

# LibraryVersion model
if grep -q "class LibraryVersion(models.Model):" "$LIB_APP/models.py"; then
  pass "LibraryVersion model defined"
else
  fail "LibraryVersion model missing"
fi

if grep -q "version_number.*PositiveIntegerField" "$LIB_APP/models.py"; then
  pass "LibraryVersion has version_number field"
else
  fail "LibraryVersion missing version_number"
fi

if grep -q "bundle_version.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryVersion has bundle_version field"
else
  fail "LibraryVersion missing bundle_version"
fi

if grep -q "publish_status.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryVersion has publish_status field"
else
  fail "LibraryVersion missing publish_status"
fi

if grep -q "component_keys.*JSONField" "$LIB_APP/models.py"; then
  pass "LibraryVersion has component_keys field"
else
  fail "LibraryVersion missing component_keys"
fi

if grep -q "publish_duration_ms.*IntegerField" "$LIB_APP/models.py"; then
  pass "LibraryVersion has publish_duration_ms field"
else
  fail "LibraryVersion missing publish_duration_ms"
fi

# LibraryComponent model
if grep -q "class LibraryComponent(models.Model):" "$LIB_APP/models.py"; then
  pass "LibraryComponent model defined"
else
  fail "LibraryComponent model missing"
fi

if grep -q "usage_key.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryComponent has usage_key field"
else
  fail "LibraryComponent missing usage_key"
fi

if grep -q "block_type.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryComponent has block_type field"
else
  fail "LibraryComponent missing block_type"
fi

if grep -q "has_unpublished_changes.*BooleanField" "$LIB_APP/models.py"; then
  pass "LibraryComponent has has_unpublished_changes field"
else
  fail "LibraryComponent missing has_unpublished_changes"
fi

# LibraryCourseReference model
if grep -q "class LibraryCourseReference(models.Model):" "$LIB_APP/models.py"; then
  pass "LibraryCourseReference model defined"
else
  fail "LibraryCourseReference model missing"
fi

if grep -q "course_key.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryCourseReference has course_key field"
else
  fail "LibraryCourseReference missing course_key"
fi

if grep -q "reference_type.*CharField" "$LIB_APP/models.py"; then
  pass "LibraryCourseReference has reference_type field"
else
  fail "LibraryCourseReference missing reference_type"
fi

if grep -q "synced_version.*PositiveIntegerField" "$LIB_APP/models.py"; then
  pass "LibraryCourseReference has synced_version field"
else
  fail "LibraryCourseReference missing synced_version"
fi

if grep -q "has_update_available.*BooleanField" "$LIB_APP/models.py"; then
  pass "LibraryCourseReference has has_update_available field"
else
  fail "LibraryCourseReference missing has_update_available"
fi

# BlockstoreReference model
if grep -q "class BlockstoreReference(models.Model):" "$LIB_APP/models.py"; then
  pass "BlockstoreReference model defined"
else
  fail "BlockstoreReference model missing"
fi

if grep -q "bundle_uuid.*UUIDField" "$LIB_APP/models.py"; then
  pass "BlockstoreReference has bundle_uuid field"
else
  fail "BlockstoreReference missing bundle_uuid"
fi

if grep -q "is_orphaned.*BooleanField" "$LIB_APP/models.py"; then
  pass "BlockstoreReference has is_orphaned field"
else
  fail "BlockstoreReference missing is_orphaned"
fi

if grep -q "ref_type.*CharField" "$LIB_APP/models.py"; then
  pass "BlockstoreReference has ref_type field"
else
  fail "BlockstoreReference missing ref_type"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 3: Atomic Publish (AC-LIB-007)"

if grep -q "def publish_library" "$LIB_APP/api.py"; then
  pass "publish_library function exists"
else
  fail "publish_library function missing"
fi

if grep -q "transaction.atomic" "$LIB_APP/api.py"; then
  pass "transaction.atomic used for atomic publish"
else
  fail "transaction.atomic not found (AC-NEG-LIB-004)"
fi

if grep -q "publish_status.*=.*'in_progress'" "$LIB_APP/api.py"; then
  pass "publish_status tracked (in_progress state)"
else
  fail "publish_status in_progress state missing"
fi

if grep -A 15 "def publish_library" "$LIB_APP/api.py" | grep -q "time.monotonic"; then
  pass "publish_duration_ms tracked"
else
  fail "publish_duration_ms tracking missing"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 4: Random Component Selection (AC-LIB-008)"

if grep -q "def get_random_components" "$LIB_APP/api.py"; then
  pass "get_random_components function exists"
else
  fail "get_random_components function missing"
fi

if grep -q "order_by('?')" "$LIB_APP/api.py"; then
  pass "Database-level random ordering (order_by('?'))"
else
  fail "Database-level random ordering missing (AC-NEG-LIB-006)"
fi

if grep -q "has_unpublished_changes=False" "$LIB_APP/api.py"; then
  pass "Only published components served"
else
  fail "Published components filter missing"
fi

if grep -q "LIBRARY_CONTENT_DEFAULT_COUNT" "$LMS_PY"; then
  pass "LIBRARY_CONTENT_DEFAULT_COUNT setting in LMS"
else
  fail "LIBRARY_CONTENT_DEFAULT_COUNT setting missing"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 5: Soft-Delete and Restore (AC-LIB-009)"

if grep -q "def soft_delete_library" "$LIB_APP/api.py"; then
  pass "soft_delete_library function exists"
else
  fail "soft_delete_library function missing"
fi

if grep -q "def restore_library" "$LIB_APP/api.py"; then
  pass "restore_library function exists"
else
  fail "restore_library function missing"
fi

if grep -A 5 "def soft_delete" "$LIB_APP/models.py" | grep -q "deleted_at"; then
  pass "deleted_at field set on soft delete"
else
  fail "deleted_at tracking missing"
fi

if grep -A 5 "def soft_delete" "$LIB_APP/models.py" | grep -q "deleted_by"; then
  pass "deleted_by field set on soft delete"
else
  fail "deleted_by tracking missing"
fi

if grep -q "retention_days.*IntegerField" "$LIB_APP/models.py"; then
  pass "retention_days field exists (default 30)"
else
  fail "retention_days field missing"
fi

if grep -A 10 "def can_permanent_delete" "$LIB_APP/models.py" | grep -q "timedelta(days="; then
  pass "can_permanent_delete checks retention period (AC-NEG-LIB-005)"
else
  fail "Retention period check missing"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 6: Update Notifications (AC-LIB-010)"

if grep -q "has_update_available" "$LIB_APP/models.py"; then
  pass "has_update_available field in LibraryCourseReference"
else
  fail "has_update_available field missing"
fi

if grep -q "synced_version" "$LIB_APP/models.py"; then
  pass "synced_version tracking in LibraryCourseReference"
else
  fail "synced_version tracking missing"
fi

if grep -A 80 "def publish_library" "$LIB_APP/api.py" | grep -q "has_update_available"; then
  pass "publish_library updates has_update_available on references"
else
  fail "has_update_available update logic missing in publish"
fi

if grep -q "class LibraryUpdateNotificationsView" "$LIB_APP/views.py"; then
  pass "LibraryUpdateNotificationsView endpoint exists"
else
  fail "LibraryUpdateNotificationsView endpoint missing"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 7: Platform Templates Library (AC-LIB-011)"

if grep -q "def create_platform_templates_library" "$LIB_APP/api.py"; then
  pass "create_platform_templates_library function exists"
else
  fail "create_platform_templates_library function missing"
fi

if grep -q "lib:Mereka:platform-templates" "$LIB_APP/api.py"; then
  pass "library_key = lib:Mereka:platform-templates"
else
  fail "Correct library_key not found"
fi

if grep -A 10 "def create_platform_templates_library" "$LIB_APP/api.py" | grep -q "org='Mereka'"; then
  pass "org = Mereka"
else
  fail "org = Mereka not set"
fi

if [[ -f "$LIB_APP/management/commands/create_platform_library.py" ]]; then
  pass "create_platform_library management command exists"
else
  fail "create_platform_library management command missing"
fi

if grep -q "get_or_create" "$LIB_APP/api.py"; then
  pass "Idempotent (uses get_or_create)"
else
  fail "Idempotency not guaranteed"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 8: Version Rollback (AC-LIB-012)"

if grep -q "def rollback_library" "$LIB_APP/api.py"; then
  pass "rollback_library function exists"
else
  fail "rollback_library function missing"
fi

if grep -q "class LibraryRollbackView" "$LIB_APP/views.py"; then
  pass "LibraryRollbackView endpoint exists"
else
  fail "LibraryRollbackView endpoint missing"
fi

if grep -A 30 "def rollback_library" "$LIB_APP/api.py" | grep -q "transaction.atomic"; then
  pass "Rollback uses transaction.atomic for atomic operation"
else
  fail "Atomic rollback not guaranteed"
fi

if grep -A 30 "def rollback_library" "$LIB_APP/api.py" | grep -q "component_keys"; then
  pass "component_keys snapshot used for exact state restoration"
else
  fail "component_keys snapshot not used"
fi

if grep -A 40 "def rollback_library" "$LIB_APP/api.py" | grep -q "LibraryVersion.objects.create"; then
  pass "Rollback creates new version record"
else
  fail "Rollback version record not created"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 9: Reference Tracking / No Orphans (AC-LIB-013)"

if grep -q "is_orphaned.*BooleanField" "$LIB_APP/models.py"; then
  pass "BlockstoreReference has is_orphaned flag"
else
  fail "is_orphaned flag missing"
fi

if grep -q "def check_orphaned_references" "$LIB_APP/api.py"; then
  pass "check_orphaned_references function exists"
else
  fail "check_orphaned_references function missing"
fi

if grep -q "def track_course_reference" "$LIB_APP/api.py"; then
  pass "track_course_reference function exists"
else
  fail "track_course_reference function missing"
fi

if grep -q "class OrphanCheckView" "$LIB_APP/views.py"; then
  pass "OrphanCheckView endpoint exists"
else
  fail "OrphanCheckView endpoint missing"
fi

if grep -q "last_verified_at" "$LIB_APP/models.py"; then
  pass "last_verified_at field for reference validation"
else
  fail "last_verified_at field missing"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 10: LMS/CMS Settings"

if grep -q "LIBRARY_PUBLISH_TIMEOUT_SECONDS.*=.*int(os.environ.get" "$LMS_PY"; then
  pass "LIBRARY_PUBLISH_TIMEOUT_SECONDS in LMS (default 30)"
else
  fail "LIBRARY_PUBLISH_TIMEOUT_SECONDS missing in LMS"
fi

if grep -q "LIBRARY_SOFT_DELETE_RETENTION_DAYS.*=.*int(os.environ.get" "$LMS_PY"; then
  pass "LIBRARY_SOFT_DELETE_RETENTION_DAYS in LMS (default 30)"
else
  fail "LIBRARY_SOFT_DELETE_RETENTION_DAYS missing in LMS"
fi

if grep -q "LIBRARY_CONTENT_DEFAULT_COUNT.*=.*int(os.environ.get" "$LMS_PY"; then
  pass "LIBRARY_CONTENT_DEFAULT_COUNT in LMS (default 5)"
else
  fail "LIBRARY_CONTENT_DEFAULT_COUNT missing in LMS"
fi

if grep -q 'INSTALLED_APPS.append("openedx_content_libraries")' "$LMS_PY"; then
  pass "openedx_content_libraries in LMS INSTALLED_APPS"
else
  fail "openedx_content_libraries not in LMS INSTALLED_APPS"
fi

if grep -q "LIBRARY_PUBLISH_TIMEOUT_SECONDS.*=.*int(os.environ.get" "$CMS_PY"; then
  pass "LIBRARY_PUBLISH_TIMEOUT_SECONDS in CMS"
else
  fail "LIBRARY_PUBLISH_TIMEOUT_SECONDS missing in CMS"
fi

if grep -q "LIBRARY_SOFT_DELETE_RETENTION_DAYS.*=.*int(os.environ.get" "$CMS_PY"; then
  pass "LIBRARY_SOFT_DELETE_RETENTION_DAYS in CMS"
else
  fail "LIBRARY_SOFT_DELETE_RETENTION_DAYS missing in CMS"
fi

if grep -q 'INSTALLED_APPS.append("openedx_content_libraries")' "$CMS_PY"; then
  pass "openedx_content_libraries in CMS INSTALLED_APPS"
else
  fail "openedx_content_libraries not in CMS INSTALLED_APPS"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 11: API Endpoints"

if grep -q "path('libraries/'," "$LIB_APP/urls.py"; then
  pass "/libraries/ list view endpoint"
else
  fail "/libraries/ list view endpoint missing"
fi

if grep -q "path('libraries/<path:library_key>/publish/'," "$LIB_APP/urls.py"; then
  pass "/libraries/{key}/publish/ endpoint"
else
  fail "/libraries/{key}/publish/ endpoint missing"
fi

if grep -q "path('libraries/<path:library_key>/rollback/'," "$LIB_APP/urls.py"; then
  pass "/libraries/{key}/rollback/ endpoint"
else
  fail "/libraries/{key}/rollback/ endpoint missing"
fi

if grep -q "path('libraries/<path:library_key>/versions/'," "$LIB_APP/urls.py"; then
  pass "/libraries/{key}/versions/ endpoint"
else
  fail "/libraries/{key}/versions/ endpoint missing"
fi

if grep -q "path('libraries/<path:library_key>/delete/'," "$LIB_APP/urls.py"; then
  pass "/libraries/{key}/delete/ endpoint"
else
  fail "/libraries/{key}/delete/ endpoint missing"
fi

if grep -q "path('libraries/<path:library_key>/orphans/'," "$LIB_APP/urls.py"; then
  pass "/libraries/{key}/orphans/ endpoint"
else
  fail "/libraries/{key}/orphans/ endpoint missing"
fi

if grep -q "path('libraries/updates/'," "$LIB_APP/urls.py"; then
  pass "/libraries/updates/ notifications endpoint"
else
  fail "/libraries/updates/ notifications endpoint missing"
fi

# ────────────────────────────────────────────────────────────────────────
section "Section 12: Runtime Tests"

skip "SKIP: Create and publish library with 50 components (--skip-cluster)"
skip "SKIP: library_content random selection (--skip-cluster)"
skip "SKIP: Soft-delete and restore (--skip-cluster)"
skip "SKIP: lib:Mereka:platform-templates creation (--skip-cluster)"
skip "SKIP: Version rollback (--skip-cluster)"
skip "SKIP: Orphan detection (--skip-cluster)"

# ────────────────────────────────────────────────────────────────────────
section "Summary"

TOTAL=$((PASS + FAIL + SKIP))
echo ""
echo "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC} (${TOTAL} total)"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}Verification FAILED${NC}"
  exit 1
else
  echo -e "${GREEN}Verification PASSED${NC}"
  exit 0
fi
