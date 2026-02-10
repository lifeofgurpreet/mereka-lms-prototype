#!/usr/bin/env bash
# Verify course import package counts against AC-015 and AC-016.
#
# Checks:
# - Kajabi: 109 OLX packages
# - MCT: 30 OLX packages
# - Package structure and format
#
# Note: This only checks package files, not database state.
# For database verification, use scripts/migrations/run-verification-pipeline.sh
#
# Usage:
#   ./scripts/qa/verify-course-import-counts.sh --source kajabi|mct
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

SOURCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$SOURCE" ]]; then
  echo "Usage: $0 --source kajabi|mct"
  exit 1
fi

if [[ "$SOURCE" == "kajabi" ]]; then
  PACKAGE_DIR="scripts/migrations/kajabi/output/course_packages"
  EXPECTED_COUNT=109
elif [[ "$SOURCE" == "mct" ]]; then
  PACKAGE_DIR="exports/mct/course_packages"
  EXPECTED_COUNT=30
else
  fail "Invalid source: $SOURCE (must be kajabi or mct)"
  exit 1
fi

# Check directory exists
if [[ ! -d "$PACKAGE_DIR" ]]; then
  fail "Course packages directory missing: $PACKAGE_DIR"
  exit 1
fi

pass "Course packages directory exists: $PACKAGE_DIR"

# Count .tar.gz files
package_count=$(find "$PACKAGE_DIR" -name "*.tar.gz" | wc -l | tr -d ' ')

if [[ "$package_count" -eq "$EXPECTED_COUNT" ]]; then
  pass "Exactly $EXPECTED_COUNT course packages found for $SOURCE"
else
  fail "Found $package_count packages for $SOURCE (expected $EXPECTED_COUNT)"
fi

# Validate package format (sample check)
sample_count=0
for tarball in "$PACKAGE_DIR"/*.tar.gz; do
  if [[ "$sample_count" -ge 3 ]]; then
    break
  fi

  # Check if tarball is valid
  if tar -tzf "$tarball" >/dev/null 2>&1; then
    pass "Valid tarball: $(basename "$tarball")"
  else
    fail "Invalid tarball: $(basename "$tarball")"
  fi

  sample_count=$((sample_count + 1))
done

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All course import count checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
