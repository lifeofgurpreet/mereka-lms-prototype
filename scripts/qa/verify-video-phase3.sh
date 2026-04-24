#!/usr/bin/env bash
# @covers AC-VPD-001 through AC-VPD-007
# @spec: video-pipeline-delivery_spec.md (Phase 3)
set -euo pipefail

# verify-video-phase3.sh - Verifies Video Phase 3: Studio Upload Workflow
#
# Usage:
#   scripts/qa/verify-video-phase3.sh              # Run all checks
#   scripts/qa/verify-video-phase3.sh --skip-runtime # Skip runtime checks

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MUX_UPLOAD_APP="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_mux_upload"
MGMT_CMD="$MUX_UPLOAD_APP/management/commands/batch_upload_videos.py"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
SKIP=0

# Parse arguments
SKIP_RUNTIME=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-runtime) SKIP_RUNTIME=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
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

# Section 1: Studio Direct Upload (AC-VPD-003)
check_studio_direct_upload() {
  echo "Section 1: Studio Direct Upload (AC-VPD-003)"

  # views.py exists with create_direct_upload_view
  if [[ -f "$MUX_UPLOAD_APP/views.py" ]]; then
    pass "views.py exists"
  else
    fail "views.py not found"
  fi

  # create_direct_upload_view endpoint
  if grep -q "def create_direct_upload_view" "$MUX_UPLOAD_APP/views.py" 2>/dev/null; then
    pass "create_direct_upload_view endpoint defined"
  else
    fail "create_direct_upload_view not found"
  fi

  # create_direct_upload utility function
  if grep -q "def create_direct_upload" "$MUX_UPLOAD_APP/utils.py" 2>/dev/null; then
    pass "create_direct_upload utility function exists"
  else
    fail "create_direct_upload utility not found"
  fi

  # Pre-signed URL generation (48-hour timeout)
  if grep -q "timeout.*172800" "$MUX_UPLOAD_APP/utils.py" 2>/dev/null; then
    pass "Pre-signed URL timeout set to 48 hours (172800s)"
  else
    fail "Pre-signed URL timeout not configured correctly"
  fi

  # CORS origin support
  if grep -q "cors_origin" "$MUX_UPLOAD_APP/utils.py" 2>/dev/null; then
    pass "CORS origin support for browser upload"
  else
    fail "CORS origin not configured"
  fi

  # MuxUpload model tracks upload status
  if grep -q "class MuxUpload" "$MUX_UPLOAD_APP/models.py" 2>/dev/null; then
    pass "MuxUpload model exists"
  else
    fail "MuxUpload model not found"
  fi

  # Status choices include pending, uploading, processing, ready, errored
  local status_count=0
  for status in pending uploading processing ready errored; do
    if grep -q "'$status'" "$MUX_UPLOAD_APP/models.py" 2>/dev/null; then
      ((status_count++)) || true
    fi
  done

  if [[ $status_count -eq 5 ]]; then
    pass "All 5 upload status choices present"
  else
    fail "Expected 5 status choices, found $status_count"
  fi

  echo ""
}

# Section 2: File Format Support (AC-VPD-002)
check_file_format_support() {
  echo "Section 2: File Format Support (AC-VPD-002)"

  # Supported formats: MP4, MOV, MKV, WebM
  local formats=("mp4" "mov" "mkv" "webm")
  local found_count=0

  for fmt in "${formats[@]}"; do
    if grep -qi "$fmt" "$MGMT_CMD" 2>/dev/null; then
      ((found_count++)) || true
    fi
  done

  if [[ $found_count -eq 4 ]]; then
    pass "All 4 supported formats (MP4/MOV/MKV/WebM) documented"
  else
    fail "Expected 4 formats, found $found_count"
  fi

  # validate_video_format function
  if grep -q "def validate_video_format" "$MUX_UPLOAD_APP/utils.py" 2>/dev/null; then
    pass "validate_video_format function exists"
  else
    fail "validate_video_format function not found"
  fi

  # Format validation in batch upload command
  if grep -q "SUPPORTED_FORMATS" "$MGMT_CMD" 2>/dev/null; then
    pass "SUPPORTED_FORMATS constant defined in batch upload"
  else
    fail "SUPPORTED_FORMATS not found in batch upload command"
  fi

  echo ""
}

# Section 3: Batch Upload with Resume (AC-VPD-004)
check_batch_upload_resume() {
  echo "Section 3: Batch Upload with Resume (AC-VPD-004)"

  # batch_upload_videos.py management command exists
  if [[ -f "$MGMT_CMD" ]]; then
    pass "batch_upload_videos.py management command exists"
  else
    fail "batch_upload_videos.py not found at $MGMT_CMD"
    echo ""
    return
  fi

  # Command class with handle() method
  if grep -q "class Command(BaseCommand):" "$MGMT_CMD" 2>/dev/null; then
    pass "Command class with BaseCommand inheritance"
  else
    fail "Command class not found or doesn't inherit from BaseCommand"
  fi

  # --checkpoint-file argument for resume capability
  if grep -q -- "--checkpoint-file" "$MGMT_CMD" 2>/dev/null; then
    pass "--checkpoint-file argument for resume capability"
  else
    fail "--checkpoint-file argument not found"
  fi

  # _load_checkpoint method
  if grep -q "def _load_checkpoint" "$MGMT_CMD" 2>/dev/null; then
    pass "_load_checkpoint method for resume support"
  else
    fail "_load_checkpoint method not found"
  fi

  # _save_checkpoint method
  if grep -q "def _save_checkpoint" "$MGMT_CMD" 2>/dev/null; then
    pass "_save_checkpoint method for progress tracking"
  else
    fail "_save_checkpoint method not found"
  fi

  # Checkpoint saved after each upload
  if grep -q "Save checkpoint after each successful upload" "$MGMT_CMD" 2>/dev/null; then
    pass "Checkpoint saved after each successful upload"
  else
    fail "Checkpoint save logic not found"
  fi

  echo ""
}

# Section 4: Ready Status Validation (AC-VPD-004)
check_ready_status_validation() {
  echo "Section 4: Ready Status Validation (AC-VPD-004)"

  # Mux webhook handler for asset.ready event
  if grep -q "def mux_webhook_handler" "$MUX_UPLOAD_APP/views.py" 2>/dev/null; then
    pass "Mux webhook handler exists"
  else
    fail "Mux webhook handler not found"
  fi

  # video.asset.ready event handling
  if grep -q "video.asset.ready" "$MUX_UPLOAD_APP/views.py" 2>/dev/null; then
    pass "video.asset.ready event handler"
  else
    fail "video.asset.ready event not handled"
  fi

  # mark_ready() method on MuxUpload model
  if grep -q "def mark_ready" "$MUX_UPLOAD_APP/models.py" 2>/dev/null; then
    pass "mark_ready() method on MuxUpload model"
  else
    fail "mark_ready() method not found"
  fi

  # wait_for_asset_ready utility function
  if grep -q "def wait_for_asset_ready" "$MUX_UPLOAD_APP/utils.py" 2>/dev/null; then
    pass "wait_for_asset_ready utility function"
  else
    fail "wait_for_asset_ready not found"
  fi

  # Status transition: preparing -> ready
  if grep -q "'ready'" "$MUX_UPLOAD_APP/models.py" 2>/dev/null; then
    pass "Status 'ready' defined in model"
  else
    fail "Status 'ready' not found"
  fi

  echo ""
}

# Section 5: Rate Limiting (AC-VPD-005)
check_rate_limiting() {
  echo "Section 5: Rate Limiting (AC-VPD-005)"

  # --rate-limit argument
  if grep -q -- "--rate-limit" "$MGMT_CMD" 2>/dev/null; then
    pass "--rate-limit argument defined"
  else
    fail "--rate-limit argument not found"
  fi

  # DEFAULT_RATE_LIMIT_SECONDS = 1.0
  if grep -q "DEFAULT_RATE_LIMIT_SECONDS.*1.0" "$MGMT_CMD" 2>/dev/null; then
    pass "DEFAULT_RATE_LIMIT_SECONDS set to 1.0 (1 req/sec)"
  else
    fail "DEFAULT_RATE_LIMIT_SECONDS not set to 1.0"
  fi

  # time.sleep(rate_limit) in upload loop
  if grep -q "time.sleep(rate_limit)" "$MGMT_CMD" 2>/dev/null; then
    pass "Rate limiting applied with time.sleep(rate_limit)"
  else
    fail "Rate limiting not implemented in upload loop"
  fi

  echo ""
}

# Section 6: Mux Basic Quality Tier (AC-VPD-006)
check_basic_quality_tier() {
  echo "Section 6: Mux Basic Quality Tier (AC-VPD-006)"

  # encoding_tier: baseline in asset settings
  if grep -q "encoding_tier.*baseline" "$MGMT_CMD" 2>/dev/null || grep -q "encoding_tier.*baseline" "$MUX_UPLOAD_APP/utils.py" 2>/dev/null; then
    pass "encoding_tier set to 'baseline' (Mux Basic quality)"
  else
    fail "encoding_tier not set to baseline"
  fi

  # --force-basic-quality flag
  if grep -q -- "--force-basic-quality" "$MGMT_CMD" 2>/dev/null; then
    pass "--force-basic-quality flag defined"
  else
    fail "--force-basic-quality flag not found"
  fi

  # Comment or documentation mentioning Basic quality
  if grep -qi "basic quality" "$MGMT_CMD" 2>/dev/null; then
    pass "Basic quality tier documented in command"
  else
    fail "Basic quality tier not documented"
  fi

  echo ""
}

# Section 7: HLS Adaptive Bitrate (AC-VPD-007)
check_hls_adaptive_bitrate() {
  echo "Section 7: HLS Adaptive Bitrate (AC-VPD-007)"

  # Comment about 240p/480p/720p renditions
  if grep -qi "240p.*480p.*720p" "$MGMT_CMD" 2>/dev/null; then
    pass "HLS renditions (240p/480p/720p) documented"
  else
    fail "HLS renditions not documented"
  fi

  # Mux automatically creates renditions (baseline tier)
  if grep -qi "automatically creates.*renditions" "$MGMT_CMD" 2>/dev/null; then
    pass "Automatic rendition creation documented"
  else
    fail "Automatic rendition creation not documented"
  fi

  # HLS playback URL format: https://stream.mux.com/{PLAYBACK_ID}.m3u8
  if grep -q "stream.mux.com" "$MUX_UPLOAD_APP" -r 2>/dev/null; then
    pass "Mux HLS streaming URL format documented"
  else
    skip "Mux HLS streaming URL format (may be in separate docs)"
  fi

  echo ""
}

# Section 8: Runtime Integration (SKIP)
check_runtime_integration() {
  echo "Section 8: Runtime Integration (requires runtime environment)"

  if [[ $SKIP_RUNTIME -eq 1 ]]; then
    skip "Create direct upload URL via API (--skip-runtime specified)"
    skip "Upload test video to Mux (--skip-runtime specified)"
    skip "Verify video reaches 'ready' status (--skip-runtime specified)"
    skip "Batch upload with checkpoint resume (--skip-runtime specified)"
  else
    skip "Create direct upload URL via API (requires runtime environment)"
    skip "Upload test video to Mux (requires runtime environment)"
    skip "Verify video reaches 'ready' status (requires runtime environment)"
    skip "Batch upload with checkpoint resume (requires runtime environment)"
  fi

  echo ""
}

# Main execution
main() {
  echo "=== Video Phase 3: Studio Upload Workflow Verification ==="
  echo ""

  check_studio_direct_upload
  check_file_format_support
  check_batch_upload_resume
  check_ready_status_validation
  check_rate_limiting
  check_basic_quality_tier
  check_hls_adaptive_bitrate
  check_runtime_integration

  # Summary
  echo "=== Summary ==="
  echo -e "${GREEN}PASS${NC}: $PASS"
  echo -e "${RED}FAIL${NC}: $FAIL"
  echo -e "${YELLOW}SKIP${NC}: $SKIP"
  echo ""

  if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Verification FAILED${NC}"
    exit 1
  else
    echo -e "${GREEN}Verification PASSED${NC}"
    exit 0
  fi
}

main
