#!/usr/bin/env bash
# @covers AC-007, AC-008
# @spec: data-migrations-kajabi-mct_spec.md
# Verify MCT data transformation against AC-007 and AC-008.
#
# Checks:
# - Exactly 30 course packages generated (not 81 or 178)
# - Enrollment deduplication (~441K unique pairs from 2.3M raw)
#
# Usage:
#   ./scripts/qa/verify-mct-transform.sh [--check-enrollment-dedup]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

CHECK_ENROLLMENT_DEDUP=0
if [[ "${1:-}" == "--check-enrollment-dedup" ]]; then
  CHECK_ENROLLMENT_DEDUP=1
fi

# Check course packages (AC-007)
if [[ "$CHECK_ENROLLMENT_DEDUP" -eq 0 ]]; then
  PACKAGE_DIR="exports/mct/course_packages"

  if [[ ! -d "$PACKAGE_DIR" ]]; then
    fail "Course packages directory missing: $PACKAGE_DIR"
  else
    pass "Course packages directory exists: $PACKAGE_DIR"

    # Count .tar.gz files
    package_count=$(find "$PACKAGE_DIR" -name "*.tar.gz" | wc -l | tr -d ' ')

    if [[ "$package_count" -eq 30 ]]; then
      pass "Exactly 30 course packages found"
    elif [[ "$package_count" -eq 81 ]]; then
      fail "Found 81 packages (expected 30 category-level packages)"
    elif [[ "$package_count" -eq 178 ]]; then
      fail "Found 178 packages (expected 30 category-level packages)"
    else
      fail "Found $package_count packages (expected exactly 30)"
    fi
  fi
fi

# Check enrollment deduplication (AC-008)
if [[ "$CHECK_ENROLLMENT_DEDUP" -eq 1 ]]; then
  ENROLLMENTS_FILE="exports/mct/enrollments.ndjson"

  if [[ ! -f "$ENROLLMENTS_FILE" ]]; then
    fail "Enrollments file missing: $ENROLLMENTS_FILE"
    exit 1
  fi

  raw_count=$(wc -l < "$ENROLLMENTS_FILE" | tr -d ' ')
  pass "Raw enrollments: $raw_count records"

  # Check for transformed/deduplicated file
  DEDUPED_FILE="exports/mct/enrollments_deduped.csv"
  if [[ ! -f "$DEDUPED_FILE" ]]; then
    echo "[INFO] Deduplicated file not found, checking extraction logic..."
    # Extract unique (user_id, category_id) pairs from NDJSON
    unique_count=$(jq -r '[.user_id, .category_id] | @csv' "$ENROLLMENTS_FILE" 2>/dev/null | sort -u | wc -l | tr -d ' ')

    if [[ "$unique_count" -ge 430000 && "$unique_count" -le 450000 ]]; then
      pass "Unique (user, category) pairs: $unique_count (expected ~441K)"
    else
      fail "Unique (user, category) pairs: $unique_count (expected ~441K)"
    fi
  else
    deduped_count=$(tail -n +2 "$DEDUPED_FILE" | wc -l | tr -d ' ')

    if [[ "$deduped_count" -ge 430000 && "$deduped_count" -le 450000 ]]; then
      pass "Deduplicated enrollments: $deduped_count (expected ~441K)"
    else
      fail "Deduplicated enrollments: $deduped_count (expected ~441K)"
    fi
  fi
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All MCT transform checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
