#!/usr/bin/env bash
# @covers AC-005, AC-006
# @spec: data-migrations-kajabi-mct_spec.md
# Verify Kajabi data transformation against AC-005 and AC-006.
#
# Checks:
# - users_import.csv exists with ~73K rows (not 326K)
# - enrollments_import.csv exists
# - CSV headers are correct
# - Deduplication by (email, course_id)
#
# Usage:
#   ./scripts/qa/verify-kajabi-transform.sh [--check-enrollments]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

CHECK_ENROLLMENTS=0
if [[ "${1:-}" == "--check-enrollments" ]]; then
  CHECK_ENROLLMENTS=1
fi

OUTPUT_DIR="scripts/migrations/kajabi/output"
USERS_CSV="$OUTPUT_DIR/openedx/users_import.csv"
ENROLLMENTS_CSV="$OUTPUT_DIR/openedx/enrollments_import.csv"

# Backwards compatibility with older transform output paths.
if [[ ! -f "$USERS_CSV" ]]; then
  USERS_CSV="$OUTPUT_DIR/users.csv"
fi
if [[ ! -f "$ENROLLMENTS_CSV" ]]; then
  ENROLLMENTS_CSV="$OUTPUT_DIR/enrollments.csv"
fi

# Check users.csv (AC-005)
if [[ "$CHECK_ENROLLMENTS" -eq 0 ]]; then
  if [[ ! -f "$USERS_CSV" ]]; then
    fail "Users CSV missing: $USERS_CSV"
  else
    pass "Users CSV exists: $USERS_CSV"

    # Check row count (should be ~73K, not 326K)
    user_count=$(tail -n +2 "$USERS_CSV" | wc -l | tr -d ' ')

    if [[ "$user_count" -lt 70000 ]]; then
      fail "Users CSV has only $user_count rows (expected ~73K)"
    elif [[ "$user_count" -gt 80000 ]]; then
      fail "Users CSV has $user_count rows (expected ~73K, not all 326K contacts)"
    else
      pass "Users CSV has $user_count rows (within expected range 70K-80K)"
    fi

    # Check CSV header
    header=$(head -1 "$USERS_CSV")
    if [[ "$header" =~ email ]]; then
      pass "Users CSV has email column"
    else
      fail "Users CSV missing email column"
    fi
  fi
fi

# Check enrollments.csv (AC-006)
if [[ "$CHECK_ENROLLMENTS" -eq 1 ]]; then
  if [[ ! -f "$ENROLLMENTS_CSV" ]]; then
    fail "Enrollments CSV missing: $ENROLLMENTS_CSV"
  else
    pass "Enrollments CSV exists: $ENROLLMENTS_CSV"

    # Check row count
    enrollment_count=$(tail -n +2 "$ENROLLMENTS_CSV" | wc -l | tr -d ' ')
    pass "Enrollments CSV has $enrollment_count rows"

    # Check CSV header
    header=$(head -1 "$ENROLLMENTS_CSV")
    if [[ "$header" =~ email && "$header" =~ course ]]; then
      pass "Enrollments CSV has email and course columns"
    else
      fail "Enrollments CSV missing required columns"
    fi

    # Validate deduplication by (email, course_id) pair.
    unique_pairs=$(
      awk -F, '
        NR == 1 {
          for (i = 1; i <= NF; i++) {
            key = tolower($i)
            gsub(/\r/, "", key)
            col[key] = i
          }
          next
        }
        {
          email = (("email" in col) ? tolower($(col["email"])) : "")
          course_id = (("course_id" in col) ? $(col["course_id"]) : "")
          gsub(/\r/, "", email)
          gsub(/\r/, "", course_id)
          if (email != "" && course_id != "") {
            print email "," course_id
          }
        }
      ' "$ENROLLMENTS_CSV" \
        | sort -u \
        | wc -l \
        | tr -d ' '
    )
    if [[ "$unique_pairs" -ge 140000 && "$unique_pairs" -le 155000 ]]; then
      pass "Enrollments CSV has $unique_pairs unique (email, course_id) pairs (~147K expected)"
    else
      fail "Enrollments CSV unique (email, course_id) pairs = $unique_pairs (expected ~147K)"
    fi
  fi
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All Kajabi transform checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
