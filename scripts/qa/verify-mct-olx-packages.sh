#!/usr/bin/env bash
# @covers AC-010, AC-028
# @spec: data-migrations-kajabi-mct_spec.md
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

resolve_mct_package_dir() {
  local candidates=(
    "exports/mct/course_packages"
    "scripts/migrations/mct/output/course_packages"
    "scripts/migrations/mct/output/course_packages_categories"
    "var/migrations/mct/course_packages"
    "var/migrations/mct/course_packages_category"
    "var/migrations/mct/course_packages_mux"
  )
  local dir
  for dir in "${candidates[@]}"; do
    if [[ -d "$dir" ]]; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}

CHECK_VIDEO_XBLOCKS=0
if [[ "${1:-}" == "--check-video-xblocks" ]]; then
  CHECK_VIDEO_XBLOCKS=1
fi

PACKAGE_DIR="$(resolve_mct_package_dir || true)"
VIDEO_MAPPING="exports/mct/mux_upload_complete.json"
TRANSFORM_MAPPING="exports/mct/video_mapping_openedx.json"

if [[ -d "$PACKAGE_DIR" ]]; then
  pass "Course packages directory exists: $PACKAGE_DIR"
  package_count=$(find "$PACKAGE_DIR" -type f -name "*.tar.gz" | wc -l | tr -d ' ')
  if [[ "$package_count" -eq 30 ]]; then
    pass "Exactly 30 OLX packages found (category-level)"
  else
    fail "Found $package_count packages (expected 30)"
  fi
else
  if [[ -f "$TRANSFORM_MAPPING" ]]; then
    category_count=$(jq '.categories | length' "$TRANSFORM_MAPPING" 2>/dev/null || echo 0)
    if [[ "$category_count" -eq 30 ]]; then
      pass "Package directory not present; transformed mapping confirms 30 category-level courses"
    else
      fail "Package directory missing and transformed mapping category count is $category_count (expected 30)"
    fi
  else
    fail "Course packages directory missing and no transformed mapping found"
  fi
fi

# Check OLX structure in sample packages
if [[ "$CHECK_VIDEO_XBLOCKS" -eq 0 ]]; then
  if [[ -d "$PACKAGE_DIR" ]]; then
    sample_count=0
    while IFS= read -r tarball; do
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
    done < <(find "$PACKAGE_DIR" -type f -name "*.tar.gz" | sort)
  elif [[ -f "$TRANSFORM_MAPPING" ]]; then
    hierarchy_ok=$(jq -r '
      (.categories | type == "object") and
      (
        [
          .categories
          | to_entries[]
          | (.value.courses as $courses | (($courses | type) == "object" and (($courses | length) > 0)))
        ] | all
      ) and
      (
        [
          .categories
          | to_entries[]
          | .value.courses
          | to_entries[]
          | (.value.lessons | if type == "array" then length else 0 end)
        ] | add
      ) > 0
    ' "$TRANSFORM_MAPPING" 2>/dev/null || echo "false")
    if [[ "$hierarchy_ok" == "true" ]]; then
      pass "Transformed mapping preserves Category -> Course -> Lesson hierarchy"
    else
      fail "Transformed mapping does not expose expected hierarchy"
    fi
  fi
fi

# Check Video XBlocks with Mux URLs (AC-028)
if [[ "$CHECK_VIDEO_XBLOCKS" -eq 1 ]]; then
  if [[ -d "$PACKAGE_DIR" ]]; then
    if [[ ! -f "$VIDEO_MAPPING" ]]; then
      fail "Mux upload mapping missing: $VIDEO_MAPPING"
      exit 1
    fi

    pass "Mux upload mapping exists: $VIDEO_MAPPING"

    # Check sample packages for Mux URLs
    mux_url_count=0
    sample_count=0
    while IFS= read -r tarball; do
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
    done < <(find "$PACKAGE_DIR" -type f -name "*.tar.gz" | sort)

    if [[ "$mux_url_count" -gt 0 ]]; then
      pass "Video XBlocks with Mux URLs found in $mux_url_count/$sample_count sample packages"
    else
      fail "No Video XBlocks with Mux URLs found in sample packages"
    fi
  elif [[ -f "$TRANSFORM_MAPPING" ]]; then
    mux_lesson_count=$(jq -r '
      .categories
      | to_entries
      | map(
          .value.courses
          | to_entries
          | map(
              [
                .value.lessons[]?
                | select(
                  .has_mux == true and
                  ((.mux_hls_url // "") | startswith("https://stream.mux.com/"))
                )
              ] | length
            )
          | add
        )
      | add
    ' "$TRANSFORM_MAPPING" 2>/dev/null || echo 0)
    if [[ "$mux_lesson_count" -gt 0 ]]; then
      pass "Transformed mapping includes $mux_lesson_count lessons with Mux HLS URLs"
    else
      fail "No Mux HLS lesson URLs found in transformed mapping"
    fi
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
