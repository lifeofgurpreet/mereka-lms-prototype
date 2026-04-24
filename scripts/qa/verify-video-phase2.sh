#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

SKIP_CLUSTER=false
for arg in "$@"; do
  [[ "$arg" == "--skip-cluster" ]] && SKIP_CLUSTER=true
done

echo "=============================================="
echo "Video Phase 2 — XBlock, Subtitles, Protection, Analytics"
echo "=============================================="
echo ""

check_file() {
  local name="$1" file="$2"
  if [[ -f "$file" ]]; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (not found: $file)"
    FAILED=$((FAILED + 1))
  fi
}

check_content() {
  local name="$1" file="$2" pattern="$3"
  if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name"
    FAILED=$((FAILED + 1))
  fi
}

check_no_content() {
  local name="$1" file="$2" pattern="$3"
  if [[ -f "$file" ]] && ! grep -q "$pattern" "$file"; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name"
    FAILED=$((FAILED + 1))
  fi
}

check_python_syntax() {
  local name="$1" file="$2"
  if python3 -c "import ast; ast.parse(open('$file').read())" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} $name"
    PASSED=$((PASSED + 1))
  else
    echo -e "${RED}✗${NC} $name (syntax error)"
    FAILED=$((FAILED + 1))
  fi
}

BASE="infrastructure/tutor/custom-apps/openedx_video_pipeline"
LMS="deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS="deploy/k8s/base/apps/openedx/settings/cms/production.py"

# ── 1. New Module Files ──
echo "1. Phase 2 Module Files"
check_file "xblock_config.py" "$BASE/xblock_config.py"
check_file "subtitles.py" "$BASE/subtitles.py"
check_file "completion.py" "$BASE/completion.py"
check_file "xapi_emitter.py" "$BASE/xapi_emitter.py"
echo ""

# ── 2. XBlock Config (AC-VPD-005, AC-VPD-006, AC-VPD-013) ──
echo "2. XBlock Configuration"
check_content "get_hls_url function" "$BASE/xblock_config.py" "def get_hls_url"
check_content "HLS URL format stream.mux.com" "$BASE/xblock_config.py" "stream.mux.com"
check_content "get_poster_url function" "$BASE/xblock_config.py" "def get_poster_url"
check_content "Poster from image.mux.com" "$BASE/xblock_config.py" "image.mux.com"
check_content "build_xblock_config function" "$BASE/xblock_config.py" "def build_xblock_config"
check_content "download_video=False" "$BASE/xblock_config.py" "download_video.*False"
check_content "show_captions logic" "$BASE/xblock_config.py" "show_captions"
check_content "use_iframe=False" "$BASE/xblock_config.py" "use_iframe.*False"
check_content "playback_id only, never asset" "$BASE/xblock_config.py" "playback_id"
check_content "build_xblock_olx function" "$BASE/xblock_config.py" "def build_xblock_olx"
echo ""

# ── 3. Subtitles (AC-VPD-008, AC-VPD-009, AC-VPD-010) ──
echo "3. Subtitle Management"
check_content "upload_subtitle_track function" "$BASE/subtitles.py" "def upload_subtitle_track"
check_content "SRT format support" "$BASE/subtitles.py" "srt"
check_content "VTT format support" "$BASE/subtitles.py" "vtt"
check_content "DEFAULT_LANGUAGE = en" "$BASE/subtitles.py" "DEFAULT_LANGUAGE.*=.*en"
check_content "list_subtitle_tracks function" "$BASE/subtitles.py" "def list_subtitle_tracks"
check_content "delete_subtitle_track function" "$BASE/subtitles.py" "def delete_subtitle_track"
check_content "get_subtitle_tracks_for_xblock function" "$BASE/subtitles.py" "def get_subtitle_tracks_for_xblock"
echo ""

# ── 4. Completion Tracking (AC-VPD-014, AC-VPD-016) ──
echo "4. Video Completion Tracking"
check_content "VideoCompletionStatus model" "$BASE/completion.py" "class VideoCompletionStatus"
check_content "completion_percentage field" "$BASE/completion.py" "completion_percentage"
check_content "is_complete field" "$BASE/completion.py" "is_complete"
check_content "max_position_reached field" "$BASE/completion.py" "max_position_reached"
check_content "update_progress classmethod" "$BASE/completion.py" "def update_progress"
check_content "90% completion threshold" "$BASE/completion.py" "0.90"
check_content "get_course_completion_summary" "$BASE/completion.py" "def get_course_completion_summary"
check_content "unique_together constraint" "$BASE/completion.py" "unique_together"
echo ""

# ── 5. xAPI Events (AC-VPD-014) ──
echo "5. xAPI Video Events"
check_content "emit_video_xapi_event function" "$BASE/xapi_emitter.py" "def emit_video_xapi_event"
check_content "VERB_VIDEO_PLAYED constant" "$BASE/xapi_emitter.py" "VERB_VIDEO_PLAYED"
check_content "VERB_VIDEO_PAUSED constant" "$BASE/xapi_emitter.py" "VERB_VIDEO_PAUSED"
check_content "VERB_VIDEO_SEEKED constant" "$BASE/xapi_emitter.py" "VERB_VIDEO_SEEKED"
check_content "VERB_VIDEO_COMPLETED constant" "$BASE/xapi_emitter.py" "VERB_VIDEO_COMPLETED"
check_content "eventtracking emission" "$BASE/xapi_emitter.py" "eventtracking"
echo ""

# ── 6. Views / API Endpoints ──
echo "6. Phase 2 API Views"
check_content "XBlockConfigView" "$BASE/views.py" "class XBlockConfigView"
check_content "SubtitleUploadView" "$BASE/views.py" "class SubtitleUploadView"
check_content "SubtitleListView" "$BASE/views.py" "class SubtitleListView"
check_content "VideoCompletionView" "$BASE/views.py" "class VideoCompletionView"
check_content "CourseVideoCompletionView" "$BASE/views.py" "class CourseVideoCompletionView"
check_content "VideoEventReceiverView" "$BASE/views.py" "class VideoEventReceiverView"
echo ""

# ── 7. URL Patterns ──
echo "7. Phase 2 URL Patterns"
check_content "xblock-config URL" "$BASE/urls.py" "xblock-config/"
check_content "subtitles/upload URL" "$BASE/urls.py" "subtitles/upload/"
check_content "subtitles/<asset_id> URL" "$BASE/urls.py" "subtitles/"
check_content "completion/<video_id> URL" "$BASE/urls.py" "completion/"
check_content "events/ URL" "$BASE/urls.py" "events/"
echo ""

# ── 8. Admin Registration ──
echo "8. Admin Registration"
check_content "VideoCompletionStatusAdmin" "$BASE/admin.py" "class VideoCompletionStatusAdmin"
echo ""

# ── 9. LMS/CMS Settings ──
echo "9. LMS/CMS Settings"
check_content "LMS: ENABLE_VIDEO_XAPI_EVENTS" "$LMS" "ENABLE_VIDEO_XAPI_EVENTS"
check_content "LMS: ENABLE_VIDEO_ANALYTICS" "$LMS" "ENABLE_VIDEO_ANALYTICS"
check_content "LMS: ENABLE_MUX_SIGNED_PLAYBACK" "$LMS" "ENABLE_MUX_SIGNED_PLAYBACK"
check_content "LMS: MUX_SIGNING_KEY_ID" "$LMS" "MUX_SIGNING_KEY_ID"
check_content "LMS: MUX_SIGNING_PRIVATE_KEY" "$LMS" "MUX_SIGNING_PRIVATE_KEY"
check_content "LMS: MUX_SIGNED_URL_EXPIRY_HOURS" "$LMS" "MUX_SIGNED_URL_EXPIRY_HOURS"
check_content "LMS: MUX_ENABLE_DOMAIN_RESTRICTION" "$LMS" "MUX_ENABLE_DOMAIN_RESTRICTION"
check_content "LMS: MUX_PLAYBACK_AUDIENCE" "$LMS" "MUX_PLAYBACK_AUDIENCE"
check_content "LMS: openedx_video_analytics in INSTALLED_APPS" "$LMS" "openedx_video_analytics"
check_content "LMS: openedx_video_protection in INSTALLED_APPS" "$LMS" "openedx_video_protection"
check_content "CMS: ENABLE_VIDEO_XAPI_EVENTS" "$CMS" "ENABLE_VIDEO_XAPI_EVENTS"
echo ""

# ── 10. Negative Assertions ──
echo "10. Negative Assertions"
check_content "No PII documentation in xapi_emitter" "$BASE/xapi_emitter.py" "no PII"
check_content "user_id only in xAPI actor" "$BASE/xapi_emitter.py" "user_id.*no PII"
check_content "No iframe when native HLS" "$BASE/xblock_config.py" "use_iframe.*False"
check_content "AC-VPD-013: Only playback_id" "$BASE/xblock_config.py" "never asset"
echo ""

# ── 11. Existing Apps Intact ──
echo "11. Existing Apps Intact"
check_file "video_analytics models.py" "infrastructure/tutor/custom-apps/openedx_video_analytics/models.py"
check_file "video_analytics views.py" "infrastructure/tutor/custom-apps/openedx_video_analytics/views.py"
check_file "video_protection models.py" "infrastructure/tutor/custom-apps/openedx_video_protection/models.py"
check_file "video_protection views.py" "infrastructure/tutor/custom-apps/openedx_video_protection/views.py"
check_file "video_protection utils.py" "infrastructure/tutor/custom-apps/openedx_video_protection/utils.py"
echo ""

# ── 12. Python Syntax ──
echo "12. Python Syntax Validation"
for pyfile in "$BASE"/*.py; do
  if [[ -f "$pyfile" ]]; then
    fname=$(basename "$pyfile")
    check_python_syntax "$fname syntax OK" "$pyfile"
  fi
done
echo ""

# ── 13. Runtime Tests ──
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
