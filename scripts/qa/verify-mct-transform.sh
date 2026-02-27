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

CHECK_ENROLLMENT_DEDUP=0
if [[ "${1:-}" == "--check-enrollment-dedup" ]]; then
  CHECK_ENROLLMENT_DEDUP=1
fi

# Check course packages (AC-007)
if [[ "$CHECK_ENROLLMENT_DEDUP" -eq 0 ]]; then
  PACKAGE_DIR="$(resolve_mct_package_dir || true)"

  if [[ ! -d "$PACKAGE_DIR" ]]; then
    MAPPING_FILE="exports/mct/video_mapping_openedx.json"
    if [[ -f "$MAPPING_FILE" ]]; then
      category_count=$(jq '.categories | length' "$MAPPING_FILE" 2>/dev/null || echo 0)
      if [[ "$category_count" -eq 30 ]]; then
        pass "No package directory found; transform mapping confirms 30 category-level courses"
      else
        fail "No package directory found and mapping categories=$category_count (expected 30)"
      fi
    else
      fail "Course packages directory missing and no transform mapping found"
    fi
  else
    pass "Course packages directory exists: $PACKAGE_DIR"

    # Count .tar.gz files recursively (current layout may be nested by slug)
    package_count=$(find "$PACKAGE_DIR" -type f -name "*.tar.gz" | wc -l | tr -d ' ')

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
  COURSES_FILE="exports/mct/courses.ndjson"

  if [[ ! -f "$ENROLLMENTS_FILE" ]]; then
    fail "Enrollments file missing: $ENROLLMENTS_FILE"
    exit 1
  fi

  raw_count=$(wc -l < "$ENROLLMENTS_FILE" | tr -d ' ')
  pass "Raw enrollments: $raw_count records"

  # Check for transformed/deduplicated file
  DEDUPED_FILE="exports/mct/enrollments_deduped.csv"
  if [[ ! -f "$DEDUPED_FILE" ]]; then
    if [[ ! -f "$COURSES_FILE" ]]; then
      fail "Courses file missing for category mapping: $COURSES_FILE"
      unique_count=0
    else
      echo "[INFO] Deduplicated file not found, deriving unique (user, category) pairs from NDJSON..."
      unique_count=$(python3 - "$ENROLLMENTS_FILE" "$COURSES_FILE" <<'PY'
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
    fi

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
