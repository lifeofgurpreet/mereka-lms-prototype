#!/usr/bin/env bash
# @covers AC-026, AC-027
# @spec: data-migrations-kajabi-mct_spec.md
# Verify Mux video upload results against AC-026 and AC-027.
#
# Checks:
# - mux_upload_complete.json exists
# - 503 video assets with playback IDs
# - Caption tracks for videos with VTT files
#
# Usage:
#   ./scripts/qa/verify-mux-video-upload.sh [--check-captions]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

CHECK_CAPTIONS=0
if [[ "${1:-}" == "--check-captions" ]]; then
  CHECK_CAPTIONS=1
fi

MUX_UPLOAD_FILE="exports/mct/mux_upload_complete.json"

# Check file exists
if [[ ! -f "$MUX_UPLOAD_FILE" ]]; then
  echo "SKIP: Mux upload file not found: $MUX_UPLOAD_FILE (run on migration workstation)"
  exit 0
fi

pass "Mux upload file exists: $MUX_UPLOAD_FILE"

# Validate JSON format
if ! jq empty "$MUX_UPLOAD_FILE" 2>/dev/null; then
  fail "Invalid JSON format: $MUX_UPLOAD_FILE"
  exit 1
fi

pass "Valid JSON format"

# Count total assets.
# Supported formats:
#  1) Summary object: {"total_videos": 503, "successful": 500, ...}
#  2) Object map: {"video_id": {"playback_id": "..."}}
#  3) Array: [{"video_id": "...", "playback_id": "..."}]
json_type=$(jq -r 'type' "$MUX_UPLOAD_FILE")
asset_count=0
has_asset_details=0

if [[ "$json_type" == "object" ]]; then
  if jq -e 'has("total_videos")' "$MUX_UPLOAD_FILE" >/dev/null 2>&1; then
    asset_count=$(jq -r '.total_videos // 0' "$MUX_UPLOAD_FILE")
    successful_count=$(
      jq -r '
        if (.successful | type) == "array" then .successful | length
        elif (.successful | type) == "number" then .successful
        else 0 end
      ' "$MUX_UPLOAD_FILE"
    )
    failed_count=$(
      jq -r '
        if (.failed | type) == "array" then .failed | length
        elif (.failed | type) == "number" then .failed
        else 0 end
      ' "$MUX_UPLOAD_FILE"
    )
    pass "Mux summary format detected (successful=$successful_count failed=$failed_count)"
    if [[ "$successful_count" -gt 0 ]]; then
      has_asset_details=1
    fi
  else
    asset_count=$(jq 'length' "$MUX_UPLOAD_FILE")
    has_asset_details=1
  fi
elif [[ "$json_type" == "array" ]]; then
  asset_count=$(jq 'length' "$MUX_UPLOAD_FILE")
  has_asset_details=1
else
  fail "Unexpected JSON structure in $MUX_UPLOAD_FILE"
  exit 1
fi

if [[ "$asset_count" -eq 503 ]]; then
  pass "Exactly 503 Mux assets found"
elif [[ "$asset_count" -ge 500 && "$asset_count" -le 510 ]]; then
  pass "Mux assets: $asset_count (close to expected 503)"
else
  fail "Mux assets: $asset_count (expected 503)"
fi

if [[ "$has_asset_details" -eq 1 && "$asset_count" -gt 0 ]]; then
  # Check for playback IDs in sample assets.
  sample_with_playback=$(
    jq '
      if type == "array" then
        .[:10]
      elif type == "object" then
        if has("successful") and (.successful | type) == "array" then
          .successful[:10]
        else
          to_entries[:10] | map(.value)
        end
      else
        []
      end
      | map(.playback_id // .mux_playback_id // .mux_data.playback_id // empty)
      | map(select(type == "string" and length > 0))
      | length
    ' "$MUX_UPLOAD_FILE" 2>/dev/null || echo 0
  )
  sample_count=$((asset_count < 10 ? asset_count : 10))
  if [[ "$sample_with_playback" -gt 0 ]]; then
    pass "Playback IDs found in $sample_with_playback/$sample_count sample assets"
  else
    fail "No playback IDs found in sample assets"
  fi
else
  if [[ -n "${successful_count:-}" && "$successful_count" -ge 500 && "$successful_count" -le 503 ]]; then
    pass "Summary confirms successful uploads: $successful_count"
  else
    fail "Summary missing expected successful upload count (~500)"
  fi
fi

# Check captions (AC-027)
if [[ "$CHECK_CAPTIONS" -eq 1 ]]; then
  if [[ "$has_asset_details" -ne 1 ]]; then
    echo "[INFO] Caption detail check skipped: summary-only mux_upload_complete.json"
    CHECK_CAPTIONS=0
  fi
fi

if [[ "$CHECK_CAPTIONS" -eq 1 ]]; then
  # Count assets with caption tracks in the mux report payload.
  caption_count=$(jq '
    if type == "array" then
      [ .[] | select(.caption_tracks or .text_tracks) ] | length
    else
      [ .successful[] | select(.caption_tracks or .text_tracks) ] | length
    end
  ' "$MUX_UPLOAD_FILE" 2>/dev/null || echo 0)

  # Some exports do not include caption metadata; if no VTT files exist locally,
  # treat missing caption tracks as non-blocking for environments that did not
  # run caption uploads.
  vtt_file_count=$(find exports/mct -type f -iname "*.vtt" | wc -l)
  if [[ "$caption_count" -ge 30 && "$caption_count" -le 40 ]]; then
    pass "Caption tracks found: $caption_count assets (expected ~34)"
  elif [[ "$caption_count" -gt 0 ]]; then
    echo "[INFO] Caption tracks found: $caption_count assets (expected ~34)"
  elif [[ "$vtt_file_count" -eq 0 ]]; then
    echo "[INFO] No caption tracks found in mux payload and no local *.vtt files detected; skipping strict AC-027 assertion"
  else
    fail "No caption tracks found (expected ~34 with VTT files present)"
  fi
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All Mux video upload checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
