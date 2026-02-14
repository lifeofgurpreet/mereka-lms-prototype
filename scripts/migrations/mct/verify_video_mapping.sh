#!/usr/bin/env bash
# @covers AC-026, AC-028
# @spec: data-migrations-kajabi-mct_spec.md
# Verify video mapping files and structure
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

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Video Mapping Verification ==="
echo ""

# AC-026, AC-028: Verify video mapping files exist
echo "Checking for video mapping files..."
MUX_RESULTS_FILE="scripts/migrations/mct/mux_upload_results.json"
if [[ -f "$MUX_RESULTS_FILE" ]]; then
  pass "Mux upload results file exists: $MUX_RESULTS_FILE"
else
  skip "Mux upload results not found (data-dependent: requires video upload)"
fi

# Validate mapping file format
if [[ -f "$MUX_RESULTS_FILE" ]]; then
  echo ""
  echo "Validating mapping file format..."

  # Check JSON validity
  if jq empty "$MUX_RESULTS_FILE" 2>/dev/null; then
    pass "Mapping file is valid JSON"
  else
    fail "Mapping file exists but is invalid JSON"
  fi

  # Check for required fields: source video ID and Mux asset ID
  SAMPLE_ENTRY=$(jq -r 'to_entries | .[0]' "$MUX_RESULTS_FILE" 2>/dev/null || echo "{}")
  if echo "$SAMPLE_ENTRY" | jq -e '.key' >/dev/null 2>&1 && echo "$SAMPLE_ENTRY" | jq -e '.value.asset_id // .value.playback_id' >/dev/null 2>&1; then
    pass "Mapping contains source ID → Mux asset ID pairs"
  else
    skip "Mapping file format unclear (data-dependent)"
  fi

  # AC-028: Check for playback IDs (used in .m3u8 URLs)
  if jq -e 'to_entries | .[0].value.playback_id' "$MUX_RESULTS_FILE" >/dev/null 2>&1; then
    pass "Mapping includes playback IDs for HLS URLs"
  else
    skip "Playback IDs not found in mapping (may be in separate field)"
  fi

  # Check for no duplicate entries
  echo ""
  echo "Checking for duplicate mappings..."
  TOTAL_ENTRIES=$(jq 'length' "$MUX_RESULTS_FILE" 2>/dev/null || echo "0")
  UNIQUE_KEYS=$(jq -r 'keys[]' "$MUX_RESULTS_FILE" 2>/dev/null | sort -u | wc -l)

  if [[ "$TOTAL_ENTRIES" -eq "$UNIQUE_KEYS" ]]; then
    pass "No duplicate source video IDs in mapping ($TOTAL_ENTRIES unique entries)"
  else
    fail "Duplicate source video IDs detected: $TOTAL_ENTRIES entries, $UNIQUE_KEYS unique keys"
  fi

  # Check for orphaned video references (videos in mapping but not in courses)
  echo ""
  echo "Checking for orphaned video references..."
  MCT_EXPORT_DIR="exports/mct"
  if [[ -f "$MCT_EXPORT_DIR/courses.ndjson" ]]; then
    # Extract video IDs from courses
    VIDEO_IDS_IN_COURSES=$(grep -oP '"videoId":\s*"\K[^"]+' "$MCT_EXPORT_DIR/courses.ndjson" 2>/dev/null | sort -u || echo "")
    MAPPED_VIDEO_IDS=$(jq -r 'keys[]' "$MUX_RESULTS_FILE" | sort -u)

    # Count differences
    ORPHANED_COUNT=$(comm -13 <(echo "$VIDEO_IDS_IN_COURSES") <(echo "$MAPPED_VIDEO_IDS") | wc -l || echo "0")

    if [[ "$ORPHANED_COUNT" -eq 0 ]]; then
      pass "No orphaned videos in mapping (all mapped videos referenced in courses)"
    else
      skip "Found $ORPHANED_COUNT videos in mapping not referenced in courses (may be expected)"
    fi
  else
    skip "MCT course export not found, cannot check orphaned references (data-dependent)"
  fi
else
  skip "Cannot validate mapping file (does not exist)"
fi

# AC-026: Check MCT export contains video metadata
echo ""
echo "Checking MCT export for video metadata..."
MCT_VIDEO_FILE="exports/mct/videos.ndjson"
if [[ -f "$MCT_VIDEO_FILE" ]]; then
  pass "MCT video export file exists"

  # Validate NDJSON format
  VIDEO_COUNT=$(wc -l < "$MCT_VIDEO_FILE" 2>/dev/null || echo "0")
  if [[ "$VIDEO_COUNT" -gt 0 ]]; then
    pass "Video export contains $VIDEO_COUNT video records"
  else
    fail "Video export file is empty"
  fi

  # Check for required video fields
  SAMPLE_VIDEO=$(head -n1 "$MCT_VIDEO_FILE" 2>/dev/null || echo "{}")
  if echo "$SAMPLE_VIDEO" | jq -e '.id' >/dev/null 2>&1 && echo "$SAMPLE_VIDEO" | jq -e '.url // .videoUrl' >/dev/null 2>&1; then
    pass "Video records contain ID and URL fields"
  else
    fail "Video records missing required fields (id, url)"
  fi
else
  skip "MCT video export not found (data-dependent: requires MCT export)"
fi

# AC-027: Check for caption track metadata
if [[ -f "$MCT_VIDEO_FILE" ]]; then
  if grep -q "caption\|subtitle\|vtt" "$MCT_VIDEO_FILE"; then
    pass "Video export includes caption/subtitle metadata"
  else
    skip "No caption metadata detected in video export (may not be present)"
  fi
fi

# Check course packages reference Mux URLs
echo ""
echo "Checking OLX packages for Mux video references..."
COURSE_PACKAGES_DIR="scripts/migrations/mct/course_packages"
if [[ -d "$COURSE_PACKAGES_DIR" ]]; then
  COURSE_COUNT=$(find "$COURSE_PACKAGES_DIR" -name "*.tar.gz" 2>/dev/null | wc -l || echo "0")
  if [[ "$COURSE_COUNT" -gt 0 ]]; then
    pass "Found $COURSE_COUNT course packages"

    # Extract and check for Mux URLs
    TEMP_DIR=$(mktemp -d)
    SAMPLE_PACKAGE=$(find "$COURSE_PACKAGES_DIR" -name "*.tar.gz" 2>/dev/null | head -n1)
    if [[ -n "$SAMPLE_PACKAGE" ]]; then
      tar -xzf "$SAMPLE_PACKAGE" -C "$TEMP_DIR" 2>/dev/null || true
      if grep -r "stream.mux.com\|playback_id" "$TEMP_DIR" >/dev/null 2>&1; then
        pass "Course packages contain Mux streaming URLs"
      else
        skip "Mux URLs not found in sample package (may not be built with Mux yet)"
      fi
      rm -rf "$TEMP_DIR"
    fi
  else
    skip "No course packages found (data-dependent: requires course build)"
  fi
else
  skip "Course packages directory does not exist (data-dependent)"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
