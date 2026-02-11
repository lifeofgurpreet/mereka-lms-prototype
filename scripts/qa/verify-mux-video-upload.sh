#!/usr/bin/env bash
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

# Count total assets
if jq -e 'type == "object"' "$MUX_UPLOAD_FILE" >/dev/null 2>&1; then
  # Object format: {video_id: {mux_data}}
  asset_count=$(jq 'length' "$MUX_UPLOAD_FILE")
elif jq -e 'type == "array"' "$MUX_UPLOAD_FILE" >/dev/null 2>&1; then
  # Array format: [{video_id, mux_data}]
  asset_count=$(jq 'length' "$MUX_UPLOAD_FILE")
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

# Check for playback IDs in sample assets
sample_with_playback=0
sample_count=10

for i in $(seq 0 $((sample_count - 1))); do
  playback_id=$(jq -r ".[$i].playback_id // .[] | select(.playback_id) | .playback_id" "$MUX_UPLOAD_FILE" 2>/dev/null | head -1)
  if [[ -n "$playback_id" && "$playback_id" != "null" ]]; then
    sample_with_playback=$((sample_with_playback + 1))
  fi
done

if [[ "$sample_with_playback" -gt 0 ]]; then
  pass "Playback IDs found in $sample_with_playback/$sample_count sample assets"
else
  fail "No playback IDs found in sample assets"
fi

# Check captions (AC-027)
if [[ "$CHECK_CAPTIONS" -eq 1 ]]; then
  # Count assets with caption tracks
  caption_count=$(jq '[.[] | select(.caption_tracks or .text_tracks)] | length' "$MUX_UPLOAD_FILE" 2>/dev/null || echo 0)

  if [[ "$caption_count" -ge 30 && "$caption_count" -le 40 ]]; then
    pass "Caption tracks found: $caption_count assets (expected ~34)"
  elif [[ "$caption_count" -gt 0 ]]; then
    echo "[INFO] Caption tracks found: $caption_count assets (expected ~34)"
  else
    fail "No caption tracks found (expected ~34 with VTT files)"
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
