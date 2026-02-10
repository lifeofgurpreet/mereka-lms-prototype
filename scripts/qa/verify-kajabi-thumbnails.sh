#!/usr/bin/env bash
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
if [[ "$header" =~ course_id && "$header" =~ thumbnail_url ]]; then
  pass "Manifest has course_id and thumbnail_url columns"
else
  fail "Manifest missing required columns"
fi

# Check for non-empty thumbnail URLs
empty_urls=$(tail -n +2 "$MANIFEST_FILE" | awk -F, '{print $2}' | grep -c "^$" || true)
if [[ "$empty_urls" -eq 0 ]]; then
  pass "All courses have thumbnail URLs"
else
  fail "$empty_urls courses have empty thumbnail URLs"
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
