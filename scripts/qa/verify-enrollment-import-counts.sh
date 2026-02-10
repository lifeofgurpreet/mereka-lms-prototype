#!/usr/bin/env bash
# Verify enrollment import CSV files against AC-019 and AC-020.
#
# Checks:
# - Kajabi enrollments: ~147K unique pairs
# - MCT enrollments: ~441K unique pairs
# - CSV format and deduplication
#
# Note: This only checks CSV files, not database state.
# For database verification, use scripts/migrations/run-verification-pipeline.sh
#
# Usage:
#   ./scripts/qa/verify-enrollment-import-counts.sh --source kajabi|mct
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
  ENROLLMENTS_CSV="scripts/migrations/kajabi/output/enrollments.csv"
  MIN_ROWS=140000
  MAX_ROWS=155000
  EXPECTED="~147K"
elif [[ "$SOURCE" == "mct" ]]; then
  ENROLLMENTS_CSV="exports/mct/enrollments_deduped.csv"
  # Fallback to checking NDJSON directly
  if [[ ! -f "$ENROLLMENTS_CSV" ]]; then
    ENROLLMENTS_CSV="exports/mct/enrollments.ndjson"
  fi
  MIN_ROWS=430000
  MAX_ROWS=450000
  EXPECTED="~441K"
else
  fail "Invalid source: $SOURCE"
  exit 1
fi

# Check file exists
if [[ ! -f "$ENROLLMENTS_CSV" ]]; then
  fail "Enrollments file missing: $ENROLLMENTS_CSV"
  exit 1
fi

pass "Enrollments file exists: $ENROLLMENTS_CSV"

# Count rows
if [[ "$ENROLLMENTS_CSV" =~ \.csv$ ]]; then
  row_count=$(tail -n +2 "$ENROLLMENTS_CSV" | wc -l | tr -d ' ')

  # Check CSV header
  header=$(head -1 "$ENROLLMENTS_CSV")
  if [[ "$header" =~ email && "$header" =~ course ]]; then
    pass "Enrollments CSV has email and course columns"
  else
    fail "Enrollments CSV missing required columns"
  fi

  # Check for deduplication
  total_lines=$(tail -n +2 "$ENROLLMENTS_CSV" | wc -l | tr -d ' ')
  unique_lines=$(tail -n +2 "$ENROLLMENTS_CSV" | sort -u | wc -l | tr -d ' ')

  if [[ "$total_lines" -eq "$unique_lines" ]]; then
    pass "Enrollments CSV is deduplicated"
  else
    fail "Enrollments CSV has $((total_lines - unique_lines)) duplicate rows"
  fi

elif [[ "$ENROLLMENTS_CSV" =~ \.ndjson$ ]]; then
  # For NDJSON, estimate unique pairs
  echo "[INFO] Counting unique (user, course) pairs from NDJSON (this may take a moment)..."
  row_count=$(jq -r '[.user_id // .email, .course_id // .category_id] | @csv' "$ENROLLMENTS_CSV" 2>/dev/null | sort -u | wc -l | tr -d ' ')
else
  fail "Unknown file format: $ENROLLMENTS_CSV"
  exit 1
fi

# Check row count
if [[ "$row_count" -lt "$MIN_ROWS" ]]; then
  fail "$SOURCE enrollments: $row_count rows (expected $EXPECTED)"
elif [[ "$row_count" -gt "$MAX_ROWS" ]]; then
  fail "$SOURCE enrollments: $row_count rows (expected $EXPECTED)"
else
  pass "$SOURCE enrollments: $row_count unique pairs (within expected range)"
fi

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All enrollment import count checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
