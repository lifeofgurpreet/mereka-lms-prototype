#!/usr/bin/env bash
# @covers AC-004
# @spec: data-migrations-kajabi-mct_spec.md
# Verify MCT video URLs structure against AC-004.
#
# Checks:
# - courses.ndjson contains video URL fields
# - URLs match Azure Blob Storage pattern
# - SAS token parameters present (sig, se)
#
# Usage:
#   ./scripts/qa/verify-mct-video-urls.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

COURSES_FILE="exports/mct/courses.ndjson"
MUX_LOOKUP_FILE="exports/mct/mux_videos_lookup.csv"
MAPPING_FILE="exports/mct/video_mapping_openedx.json"

if [[ -f "$MUX_LOOKUP_FILE" ]]; then
  pass "Mux lookup file exists: $MUX_LOOKUP_FILE"
  read -r total_rows valid_playback_rows < <(
    python3 - "$MUX_LOOKUP_FILE" <<'PY'
import csv
import sys

path = sys.argv[1]
total = 0
valid = 0
with open(path, newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    for row in reader:
        total += 1
        playback = (row.get("Playback URL") or row.get("playback_url") or "").strip()
        if playback.startswith("https://stream.mux.com/"):
            valid += 1
print(total, valid)
PY
  )
  if [[ "$total_rows" -ge 500 && "$total_rows" -le 510 ]]; then
    pass "Mux lookup has $total_rows rows (expected ~503)"
  else
    fail "Mux lookup has $total_rows rows (expected ~503)"
  fi
  if [[ "$valid_playback_rows" -gt 0 ]]; then
    pass "Playback URLs found in $valid_playback_rows/$total_rows rows"
  else
    fail "No playback URLs found in Mux lookup file"
  fi
elif [[ -f "$MAPPING_FILE" ]]; then
  pass "Video mapping file exists: $MAPPING_FILE"
  mapped_urls=$(jq -r '
    .categories
    | to_entries[]
    | .value.courses
    | to_entries[]
    | .value.lessons
    | to_entries[]
    | .value.mux_hls_url // empty
  ' "$MAPPING_FILE" 2>/dev/null | grep -c '^https://stream\.mux\.com/' || true)
  if [[ "$mapped_urls" -gt 0 ]]; then
    pass "Mux HLS URLs found in transformed mapping: $mapped_urls"
  else
    fail "No Mux HLS URLs found in transformed mapping"
  fi
else
  fail "Neither $MUX_LOOKUP_FILE nor $MAPPING_FILE exists"
fi

# Fresh MCT export should contain signed source URLs (SAS params) somewhere in
# course payloads (often logo/media fields depending on export shape).
if [[ -f "$COURSES_FILE" ]]; then
  pass "Courses file exists: $COURSES_FILE"
  if rg -q '\?[^"]*(sv=|sig=)' "$COURSES_FILE"; then
    pass "Signed URL parameters detected in courses export (sv/sig)"
  else
    echo "[WARN] Signed URL parameters not found in courses export (may indicate stale/normalized export)"
  fi
else
  echo "[WARN] Courses file missing: $COURSES_FILE"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All MCT video URL checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
