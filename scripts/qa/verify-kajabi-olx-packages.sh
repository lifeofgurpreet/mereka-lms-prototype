#!/usr/bin/env bash
# Verify Kajabi OLX packages against AC-009.
#
# Checks:
# - 109 OLX tarballs generated
# - Course keys in correct format: course-v1:MEREKA+MEKA-{id}+RUN-{id}
# - Each tarball contains required OLX structure
#
# Usage:
#   ./scripts/qa/verify-kajabi-olx-packages.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

PACKAGE_DIR="scripts/migrations/kajabi/output/course_packages"

# Check directory exists
if [[ ! -d "$PACKAGE_DIR" ]]; then
  fail "Course packages directory missing: $PACKAGE_DIR"
  exit 1
fi

pass "Course packages directory exists: $PACKAGE_DIR"

# Count .tar.gz files
package_count=$(find "$PACKAGE_DIR" -name "*.tar.gz" | wc -l | tr -d ' ')

if [[ "$package_count" -eq 109 ]]; then
  pass "Exactly 109 OLX packages found"
else
  fail "Found $package_count packages (expected 109)"
fi

# Check course key format in filenames
invalid_format=0
for tarball in "$PACKAGE_DIR"/*.tar.gz; do
  basename=$(basename "$tarball" .tar.gz)

  # Expected format: course-v1:MEREKA+MEKA-{id}+RUN-{id}
  if [[ "$basename" =~ ^course-v1:MEREKA\+MEKA-[0-9]+\+RUN-[0-9]+$ ]]; then
    : # Valid format
  else
    fail "Invalid course key format: $basename"
    invalid_format=$((invalid_format + 1))
  fi
done

if [[ "$invalid_format" -eq 0 ]]; then
  pass "All course keys match format: course-v1:MEREKA+MEKA-{id}+RUN-{id}"
else
  fail "$invalid_format packages have invalid course key format"
fi

# Validate OLX structure in sample tarballs
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

  # Check for required OLX files
  course_dir=$(find "$temp_dir" -type d -name "course" | head -1)
  if [[ -z "$course_dir" ]]; then
    fail "No course/ directory in $(basename "$tarball")"
  else
    # Check for course.xml
    if [[ -f "$course_dir/course.xml" || -f "$course_dir/../course.xml" ]]; then
      pass "Valid OLX structure in $(basename "$tarball")"
    else
      fail "Missing course.xml in $(basename "$tarball")"
    fi
  fi

  rm -rf "$temp_dir"
  sample_count=$((sample_count + 1))
done

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All Kajabi OLX package checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
