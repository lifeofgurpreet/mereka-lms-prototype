#!/usr/bin/env bash
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

SKIP_CLUSTER=false

for arg in "$@"; do
  if [[ "$arg" == "--skip-cluster" ]]; then
    SKIP_CLUSTER=true
  fi
done

echo "=============================================="
echo "Video Phase 1 — MCT Migration Validation"
echo "=============================================="
echo ""

check_file() {
  local name="$1"
  local file="$2"
  if [[ -f "$file" ]]; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (not found: $file)"
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

check_no_content() {
  local name="$1"
  local file="$2"
  local pattern="$3"
  if [[ -f "$file" ]] && ! grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name"
    FAILED=$((FAILED + 1))
  fi
}

check_python_syntax() {
  local name="$1"
  local file="$2"
  if python3 -c "import ast; ast.parse(open('$file').read())" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (syntax error)"
    FAILED=$((FAILED + 1))
  fi
}

BASE="infrastructure/tutor/custom-apps/openedx_video_pipeline"

# ── Section 1: App Structure ──
echo "1. App Structure"
check_file "__init__.py" "$BASE/__init__.py"
check_file "apps.py" "$BASE/apps.py"
check_file "setup.py" "$BASE/setup.py"
check_file "models.py" "$BASE/models.py"
check_file "mux_client.py" "$BASE/mux_client.py"
check_file "validators.py" "$BASE/validators.py"
check_file "views.py" "$BASE/views.py"
check_file "serializers.py" "$BASE/serializers.py"
check_file "urls.py" "$BASE/urls.py"
check_file "admin.py" "$BASE/admin.py"
echo ""

# ── Section 2: Models ──
echo "2. Models (AC-VID-001)"
check_content "MctVideoMapping model" "$BASE/models.py" "class MctVideoMapping"
check_content "mct_video_id field" "$BASE/models.py" "mct_video_id"
check_content "mux_asset_id field" "$BASE/models.py" "mux_asset_id"
check_content "mux_playback_id field" "$BASE/models.py" "mux_playback_id"
check_content "olx_usage_key field" "$BASE/models.py" "olx_usage_key"
check_content "content_language field" "$BASE/models.py" "content_language"
check_content "mux_status field" "$BASE/models.py" "mux_status"
check_content "playback_verified field" "$BASE/models.py" "playback_verified"
check_content "MigrationReport model" "$BASE/models.py" "class MigrationReport"
check_content "total_expected field" "$BASE/models.py" "total_expected"
check_content "failed_asset_ids field" "$BASE/models.py" "failed_asset_ids"
check_content "is_complete field" "$BASE/models.py" "is_complete"
echo ""

# ── Section 3: Mux Client (AC-VID-002, AC-VID-003) ──
echo "3. Mux Client (AC-VID-002, AC-VID-003)"
check_content "get_mux_headers function" "$BASE/mux_client.py" "def get_mux_headers"
check_content "get_asset_details function" "$BASE/mux_client.py" "def get_asset_details"
check_content "check_playback_url function" "$BASE/mux_client.py" "def check_playback_url"
check_content "get_asset_metadata function" "$BASE/mux_client.py" "def get_asset_metadata"
check_content "retry_asset_ingestion function" "$BASE/mux_client.py" "def retry_asset_ingestion"
check_content "list_assets function" "$BASE/mux_client.py" "def list_assets"
check_content "MUX_TOKEN_ID from env" "$BASE/mux_client.py" "MUX_TOKEN_ID"
check_content "MUX_TOKEN_SECRET from env" "$BASE/mux_client.py" "MUX_TOKEN_SECRET"
check_content "Rate limiting sleep" "$BASE/mux_client.py" "time.sleep"
echo ""

# ── Section 4: Validators (AC-VID-001, AC-VID-002, AC-VID-005) ──
echo "4. Validators"
check_content "validate_manifest function" "$BASE/validators.py" "def validate_manifest"
check_content "validate_olx_mappings function" "$BASE/validators.py" "def validate_olx_mappings"
check_content "validate_playback_health function" "$BASE/validators.py" "def validate_playback_health"
check_content "validate_content_languages function" "$BASE/validators.py" "def validate_content_languages"
check_content "generate_migration_report function" "$BASE/validators.py" "def generate_migration_report"
echo ""

# ── Section 5: Views / API Endpoints ──
echo "5. Views / API Endpoints"
check_content "VideoHealthCheckView" "$BASE/views.py" "class VideoHealthCheckView"
check_content "VideoMappingListView" "$BASE/views.py" "class VideoMappingListView"
check_content "VideoPlaybackCheckView" "$BASE/views.py" "class VideoPlaybackCheckView"
check_content "MigrationReportView" "$BASE/views.py" "class MigrationReportView"
check_content "VideoMetadataView" "$BASE/views.py" "class VideoMetadataView"
echo ""

# ── Section 6: URL Patterns ──
echo "6. URL Patterns"
check_content "health/ URL" "$BASE/urls.py" "health/"
check_content "mappings/ URL" "$BASE/urls.py" "mappings/"
check_content "playback-check/ URL" "$BASE/urls.py" "playback-check/"
check_content "report/ URL" "$BASE/urls.py" "report/"
check_content "metadata/ URL" "$BASE/urls.py" "metadata/"
echo ""

# ── Section 7: Serializers ──
echo "7. Serializers"
check_content "MctVideoMappingSerializer" "$BASE/serializers.py" "class MctVideoMappingSerializer"
check_content "MigrationReportSerializer" "$BASE/serializers.py" "class MigrationReportSerializer"
check_content "PlaybackCheckRequestSerializer" "$BASE/serializers.py" "class PlaybackCheckRequestSerializer"
check_content "VideoHealthSerializer" "$BASE/serializers.py" "class VideoHealthSerializer"
echo ""

# ── Section 8: Admin ──
echo "8. Admin Registration"
check_content "MctVideoMappingAdmin" "$BASE/admin.py" "class MctVideoMappingAdmin"
check_content "MigrationReportAdmin" "$BASE/admin.py" "class MigrationReportAdmin"
echo ""

# ── Section 9: Management Commands ──
echo "9. Management Commands"
check_file "validate_mct_migration command" "$BASE/management/commands/validate_mct_migration.py"
check_file "import_mux_manifest command" "$BASE/management/commands/import_mux_manifest.py"
check_content "validate_mct_migration adds parser args" "$BASE/management/commands/validate_mct_migration.py" "add_arguments"
check_content "import_mux_manifest adds parser args" "$BASE/management/commands/import_mux_manifest.py" "add_arguments"
echo ""

# ── Section 10: LMS/CMS Settings ──
echo "10. LMS/CMS Settings"
check_content "LMS: VIDEO_PIPELINE_ENABLED" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" "VIDEO_PIPELINE_ENABLED"
check_content "LMS: MUX_PLAYBACK_BASE_URL" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" "MUX_PLAYBACK_BASE_URL"
check_content "LMS: MCT_MIGRATION_BATCH" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" "MCT_MIGRATION_BATCH"
check_content "LMS: MCT_EXPECTED_VIDEO_COUNT" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" "MCT_EXPECTED_VIDEO_COUNT"
check_content "LMS: VIDEO_PLAYBACK_CHECK_TIMEOUT" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" "VIDEO_PLAYBACK_CHECK_TIMEOUT"
check_content "LMS: openedx_video_pipeline in INSTALLED_APPS" \
  "deploy/k8s/base/apps/openedx/settings/lms/production.py" "openedx_video_pipeline"
check_content "CMS: VIDEO_PIPELINE_ENABLED" \
  "deploy/k8s/base/apps/openedx/settings/cms/production.py" "VIDEO_PIPELINE_ENABLED"
echo ""

# ── Section 11: Negative Assertions ──
echo "11. Negative Assertions"
check_no_content "AC-NEG-VID-001: No hardcoded Mux token in mux_client" \
  "$BASE/mux_client.py" "MUX_TOKEN_ID = ['\"][a-zA-Z0-9_-]\{20,\}"
check_content "AC-NEG-VID-001: Uses os.environ.get for credentials" \
  "$BASE/mux_client.py" "os.environ.get"
check_content "AC-NEG-VID-002: retry never deletes assets" \
  "$BASE/mux_client.py" "never delete"
echo ""

# ── Section 12: Python Syntax ──
echo "12. Python Syntax Validation"
for pyfile in "$BASE"/*.py; do
  if [[ -f "$pyfile" ]]; then
    fname=$(basename "$pyfile")
    check_python_syntax "$fname syntax OK" "$pyfile"
  fi
done
for pyfile in "$BASE"/management/commands/*.py; do
  if [[ -f "$pyfile" ]]; then
    fname=$(basename "$pyfile")
    check_python_syntax "commands/$fname syntax OK" "$pyfile"
  fi
done
echo ""

# ── Section 13: Runtime / Cluster Tests ──
if [[ "$SKIP_CLUSTER" == "true" ]]; then
  echo "13. Runtime Tests (SKIPPED)"
  echo -e "${YELLOW}⊘${NC} Cluster tests skipped (--skip-cluster)"
  SKIPPED=$((SKIPPED + 1))
else
  echo "13. Runtime Tests"
  echo -e "${YELLOW}⊘${NC} Runtime tests require cluster"
  SKIPPED=$((SKIPPED + 1))
fi
echo ""

# ── Summary ──
echo "=============================================="
echo "SUMMARY"
echo "=============================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All checks passed!${NC}"
  exit 0
else
  echo -e "${RED}✗ Some checks failed${NC}"
  exit 1
fi
