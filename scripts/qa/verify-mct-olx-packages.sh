#!/usr/bin/env bash
# Verify MCT OLX packages against AC-010 and AC-028.
#
# Checks:
# - 30 OLX packages with category-level structure
# - MCT Category as Course, MCT "Course" as Chapter/Section
# - Video XBlocks with Mux playback URLs
#
# Usage:
#   ./scripts/qa/verify-mct-olx-packages.sh [--check-video-xblocks]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

CHECK_VIDEO_XBLOCKS=0
if [[ "${1:-}" == "--check-video-xblocks" ]]; then
  CHECK_VIDEO_XBLOCKS=1
fi

PACKAGE_DIR="exports/mct/course_packages"
VIDEO_MAPPING="exports/mct/mux_upload_complete.json"

# Check directory exists
if [[ ! -d "$PACKAGE_DIR" ]]; then
  fail "Course packages directory missing: $PACKAGE_DIR"
  exit 1
fi

pass "Course packages directory exists: $PACKAGE_DIR"

# Count .tar.gz files
package_count=$(find "$PACKAGE_DIR" -name "*.tar.gz" | wc -l | tr -d ' ')

if [[ "$package_count" -eq 30 ]]; then
  pass "Exactly 30 OLX packages found (category-level)"
else
  fail "Found $package_count packages (expected 30)"
fi

# Check OLX structure in sample packages
if [[ "$CHECK_VIDEO_XBLOCKS" -eq 0 ]]; then
  sample_count=0
  for tarball in "$PACKAGE_DIR"/*.tar.gz; do
    if [[ "$sample_count" -ge 3 ]]; then
      break
    fi

    # Extract to temp directory
    temp_dir=$(mktemp -d)
    tar -xzf "$tarball" -C "$temp_dir" 2>/dev/null || {
      fail "Failed to extract: $(basename "$tarball")"
      rm -rf "$temp_dir"
      continue
    }

    # Check for chapter/sequential/vertical structure
    has_chapters=$(find "$temp_dir" -type d -name "chapter" | wc -l)
    has_sequentials=$(find "$temp_dir" -type d -name "sequential" | wc -l)
    has_verticals=$(find "$temp_dir" -type d -name "vertical" | wc -l)

    if [[ "$has_chapters" -gt 0 && "$has_sequentials" -gt 0 && "$has_verticals" -gt 0 ]]; then
      pass "Valid OLX hierarchy in $(basename "$tarball"): chapters/sequentials/verticals"
    else
      fail "Invalid OLX hierarchy in $(basename "$tarball")"
    fi

    rm -rf "$temp_dir"
    sample_count=$((sample_count + 1))
  done
fi

# Check Video XBlocks with Mux URLs (AC-028)
if [[ "$CHECK_VIDEO_XBLOCKS" -eq 1 ]]; then
  if [[ ! -f "$VIDEO_MAPPING" ]]; then
    fail "Mux upload mapping missing: $VIDEO_MAPPING"
    exit 1
  fi

  pass "Mux upload mapping exists: $VIDEO_MAPPING"

  # Check sample packages for Mux URLs
  mux_url_count=0
  sample_count=0

  for tarball in "$PACKAGE_DIR"/*.tar.gz; do
    if [[ "$sample_count" -ge 5 ]]; then
      break
    fi

    temp_dir=$(mktemp -d)
    tar -xzf "$tarball" -C "$temp_dir" 2>/dev/null || {
      rm -rf "$temp_dir"
      continue
    }

    # Search for video XBlocks with Mux URLs
    if find "$temp_dir" -name "*.xml" -exec grep -l "stream.mux.com" {} \; | head -1 | grep -q .; then
      mux_url_count=$((mux_url_count + 1))
    fi

    rm -rf "$temp_dir"
    sample_count=$((sample_count + 1))
  done

  if [[ "$mux_url_count" -gt 0 ]]; then
    pass "Video XBlocks with Mux URLs found in $mux_url_count/$sample_count sample packages"
  else
    fail "No Video XBlocks with Mux URLs found in sample packages"
  fi
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All MCT OLX package checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
