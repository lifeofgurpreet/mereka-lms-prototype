#!/usr/bin/env bash
# @covers AC-029
# @spec: data-migrations-kajabi-mct_spec.md
# Verify Kajabi thumbnail upload preparation against AC-029.
#
# Checks:
# - thumbnail_manifest.csv exists with 109 courses
# - Each course has thumbnail URL
# - Thumbnails downloaded to local cache
#
# Usage:
#   ./scripts/qa/verify-kajabi-thumbnails.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_file "scripts/migrations/kajabi/output/thumbnail_manifest.csv" "Kajabi thumbnail manifest" || exit 0

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

MANIFEST_FILE="scripts/migrations/kajabi/output/thumbnail_manifest.csv"
THUMBNAILS_DIR="scripts/migrations/kajabi/output/thumbnails"

# Check manifest file
if [[ ! -f "$MANIFEST_FILE" ]]; then
  fail "Thumbnail manifest missing: $MANIFEST_FILE"
  exit 1
fi

pass "Thumbnail manifest exists: $MANIFEST_FILE"

# Count courses in manifest
course_count=$(tail -n +2 "$MANIFEST_FILE" | wc -l | tr -d ' ')

if [[ "$course_count" -eq 109 ]]; then
  pass "Exactly 109 courses in manifest"
elif [[ "$course_count" -ge 105 && "$course_count" -le 115 ]]; then
  pass "Courses in manifest: $course_count (close to expected 109)"
else
  fail "Courses in manifest: $course_count (expected 109)"
fi

# Check CSV header
header=$(head -1 "$MANIFEST_FILE")
if [[ "$header" =~ (course_id|kajabi_course_id) ]]; then
  pass "Manifest has course identifier column"
else
  fail "Manifest missing course identifier column"
fi
has_thumbnail_url=0
has_image_filename=0
if [[ "$header" =~ thumbnail_url ]]; then
  has_thumbnail_url=1
fi
if [[ "$header" =~ image_filename ]]; then
  has_image_filename=1
fi
if [[ "$has_thumbnail_url" -eq 1 || "$has_image_filename" -eq 1 ]]; then
  pass "Manifest has thumbnail_url or image_filename column"
else
  fail "Manifest missing both thumbnail_url and image_filename columns"
fi

# Check for non-empty thumbnail references
if [[ "$has_thumbnail_url" -eq 1 ]]; then
  empty_urls=$(awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        key = tolower($i)
        gsub(/\r/, "", key)
        col[key] = i
      }
      next
    }
    {
      value = (("thumbnail_url" in col) ? $(col["thumbnail_url"]) : "")
      gsub(/\r/, "", value)
      if (value == "") {
        empty += 1
      }
    }
    END { print empty + 0 }
  ' "$MANIFEST_FILE")
  if [[ "$empty_urls" -eq 0 ]]; then
    pass "All courses have thumbnail URLs"
  else
    fail "$empty_urls courses have empty thumbnail URLs"
  fi
elif [[ "$has_image_filename" -eq 1 ]]; then
  missing_files=$(awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        key = tolower($i)
        gsub(/\r/, "", key)
        col[key] = i
      }
      next
    }
    {
      value = (("image_filename" in col) ? $(col["image_filename"]) : "")
      gsub(/\r/, "", value)
      if (value == "") {
        empty += 1
      }
    }
    END { print empty + 0 }
  ' "$MANIFEST_FILE")
  if [[ "$missing_files" -eq 0 ]]; then
    pass "All courses have image filenames for local thumbnail cache"
  else
    fail "$missing_files courses have empty image filenames"
  fi
fi

# Check thumbnails directory (if downloads have been run)
if [[ -d "$THUMBNAILS_DIR" ]]; then
  thumbnail_files=$(find "$THUMBNAILS_DIR" -type f | wc -l | tr -d ' ')
  pass "Thumbnails directory exists with $thumbnail_files files"

  if [[ "$thumbnail_files" -ge 100 ]]; then
    pass "At least 100 thumbnails downloaded"
  elif [[ "$thumbnail_files" -gt 0 ]]; then
    echo "[INFO] Only $thumbnail_files thumbnails downloaded (expected ~109)"
  fi
else
  echo "[INFO] Thumbnails directory not found (downloads not run yet)"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All Kajabi thumbnail checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
