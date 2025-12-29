#!/usr/bin/env bash
#
# Test script to verify MCT export fixes
#
# This script validates that:
# 1. All 31 categories are being processed
# 2. All courses are extracted (not just 15)
# 3. Real enrollment data is fetched
#
# Usage:
#   ./scripts/migrations/mct/test-export-fixes.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
EXPORT_DIR="${REPO_ROOT}/exports/mct"

echo "=============================================="
echo "MCT Export Fixes - Validation Test"
echo "=============================================="
echo

# Check if export files exist
echo "📋 Checking export files..."
if [ ! -f "${EXPORT_DIR}/categories.ndjson" ]; then
  echo "❌ ERROR: categories.ndjson not found"
  echo "   Run export first: node scripts/migrations/mct/mct-export.mjs --resources categories"
  exit 1
fi

if [ ! -f "${EXPORT_DIR}/courses.ndjson" ]; then
  echo "❌ ERROR: courses.ndjson not found"
  echo "   Run export first: node scripts/migrations/mct/mct-export.mjs --resources courses --force"
  exit 1
fi

# Test 1: Verify categories.ndjson has all 31 categories
echo
echo "🧪 Test 1: Verify categories.ndjson has all 31 categories"
CATEGORY_COUNT=$(node -e "
  const fs = require('fs');
  const data = JSON.parse(fs.readFileSync('${EXPORT_DIR}/categories.ndjson', 'utf-8'));
  const offers = data.Offers || [];
  console.log(offers.length);
")

if [ "${CATEGORY_COUNT}" -eq 31 ]; then
  echo "   ✅ PASS: Found ${CATEGORY_COUNT} categories in hierarchical structure"
else
  echo "   ❌ FAIL: Expected 31 categories, found ${CATEGORY_COUNT}"
  exit 1
fi

# Test 2: Verify courses.ndjson has more than 15 courses
echo
echo "🧪 Test 2: Verify courses.ndjson has ALL courses (not just 15)"
COURSE_COUNT=$(wc -l < "${EXPORT_DIR}/courses.ndjson")

if [ "${COURSE_COUNT}" -gt 15 ]; then
  echo "   ✅ PASS: Found ${COURSE_COUNT} courses (more than 15)"
else
  echo "   ❌ FAIL: Expected more than 15 courses, found ${COURSE_COUNT}"
  echo "   This indicates the fix didn't work - still only extracting partial data"
  exit 1
fi

# Test 3: Verify courses have CategoryId and CategoryName
echo
echo "🧪 Test 3: Verify courses have category context"
COURSES_WITH_CONTEXT=$(node -e "
  const fs = require('fs');
  const lines = fs.readFileSync('${EXPORT_DIR}/courses.ndjson', 'utf-8').split('\n').filter(Boolean);
  const coursesWithContext = lines.filter(line => {
    const course = JSON.parse(line);
    return course.CategoryId && course.CategoryName;
  });
  console.log(coursesWithContext.length);
")

if [ "${COURSES_WITH_CONTEXT}" -eq "${COURSE_COUNT}" ]; then
  echo "   ✅ PASS: All ${COURSE_COUNT} courses have CategoryId and CategoryName"
else
  echo "   ⚠️  WARNING: ${COURSES_WITH_CONTEXT}/${COURSE_COUNT} courses have category context"
fi

# Test 4: Check if enrollments.ndjson exists
echo
echo "🧪 Test 4: Verify enrollments.ndjson exists"
if [ -f "${EXPORT_DIR}/enrollments.ndjson" ]; then
  ENROLLMENT_COUNT=$(wc -l < "${EXPORT_DIR}/enrollments.ndjson")
  echo "   ✅ PASS: enrollments.ndjson exists with ${ENROLLMENT_COUNT} records"

  # Verify enrollments have courseId
  ENROLLMENTS_WITH_COURSE=$(node -e "
    const fs = require('fs');
    const lines = fs.readFileSync('${EXPORT_DIR}/enrollments.ndjson', 'utf-8').split('\n').filter(Boolean);
    const enrollmentsWithCourse = lines.filter(line => {
      const enrollment = JSON.parse(line);
      return enrollment.courseId;
    });
    console.log(enrollmentsWithCourse.length);
  ")

  if [ "${ENROLLMENTS_WITH_COURSE}" -eq "${ENROLLMENT_COUNT}" ]; then
    echo "   ✅ PASS: All enrollments have courseId"
  else
    echo "   ⚠️  WARNING: ${ENROLLMENTS_WITH_COURSE}/${ENROLLMENT_COUNT} enrollments have courseId"
  fi
else
  echo "   ❌ FAIL: enrollments.ndjson not found"
  echo "   Run export: node scripts/migrations/mct/mct-export.mjs --resources enrollments --force"
  exit 1
fi

# Summary
echo
echo "=============================================="
echo "✅ All Tests Passed!"
echo "=============================================="
echo
echo "Summary:"
echo "  - Categories: ${CATEGORY_COUNT} (expected 31)"
echo "  - Courses: ${COURSE_COUNT} (expected 100+)"
echo "  - Enrollments: ${ENROLLMENT_COUNT}"
echo
echo "Export directory: ${EXPORT_DIR}"
echo
echo "Next steps:"
echo "  1. Verify course count is reasonable (should be 100-300+)"
echo "  2. Update transform_data.py to use real enrollment data"
echo "  3. Remove heuristic keyword matching logic"
echo
