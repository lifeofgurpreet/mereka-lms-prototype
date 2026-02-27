#!/usr/bin/env bash
# @covers AC-019, AC-020
# @spec: data-migrations-kajabi-mct_spec.md
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
  ENROLLMENTS_CSV="scripts/migrations/kajabi/output/openedx/enrollments_import.csv"
  if [[ ! -f "$ENROLLMENTS_CSV" ]]; then
    ENROLLMENTS_CSV="scripts/migrations/kajabi/output/enrollments.csv"
  fi
  MIN_ROWS=140000
  MAX_ROWS=155000
  EXPECTED="~147K"
elif [[ "$SOURCE" == "mct" ]]; then
  ENROLLMENTS_CSV="exports/mct/enrollments_deduped.csv"
  COURSES_NDJSON="exports/mct/courses.ndjson"
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

  if [[ "$SOURCE" == "kajabi" ]]; then
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
    pass "Kajabi unique (email, course_id) pairs: $unique_pairs"
    row_count="$unique_pairs"
  else
    # Check for deduplication on MCT prepared CSV.
    total_lines=$(tail -n +2 "$ENROLLMENTS_CSV" | wc -l | tr -d ' ')
    unique_lines=$(tail -n +2 "$ENROLLMENTS_CSV" | sort -u | wc -l | tr -d ' ')

    if [[ "$total_lines" -eq "$unique_lines" ]]; then
      pass "Enrollments CSV is deduplicated"
    else
      fail "Enrollments CSV has $((total_lines - unique_lines)) duplicate rows"
    fi
  fi

elif [[ "$ENROLLMENTS_CSV" =~ \.ndjson$ ]]; then
  # For MCT NDJSON fallback, compute unique (user, category) pairs by joining
  # enrollments.courseId -> courses.CategoryId to reflect transform semantics.
  echo "[INFO] Counting unique (user, category) pairs from NDJSON (this may take a moment)..."
  if [[ "$SOURCE" != "mct" ]]; then
    fail "NDJSON fallback is only supported for MCT in this verifier"
    exit 1
  fi
  if [[ ! -f "$COURSES_NDJSON" ]]; then
    fail "MCT courses file missing for category join: $COURSES_NDJSON"
    exit 1
  fi
  row_count=$(python3 - "$ENROLLMENTS_CSV" "$COURSES_NDJSON" <<'PY'
import json
import sys

enrollments_path = sys.argv[1]
courses_path = sys.argv[2]

course_to_category = {}
with open(courses_path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        course_id = row.get("Id")
        category_id = row.get("CategoryId")
        if course_id is None or category_id is None:
            continue
        course_to_category[str(course_id)] = str(category_id)

pairs = set()
with open(enrollments_path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        row = json.loads(line)
        email = (row.get("Contact") or row.get("email") or "").strip().lower()
        course_id = row.get("courseId") or row.get("course_id")
        if not email or course_id is None:
            continue
        category_id = course_to_category.get(str(course_id))
        if not category_id:
            continue
        pairs.add((email, category_id))

print(len(pairs))
PY
)
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
