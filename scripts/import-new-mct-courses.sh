#!/usr/bin/env bash
set -euo pipefail

# Import 15 NEW MCT courses to K8s
# NEW courses: 4, 17, 19, 20, 21, 28, 29, 34, 36, 37, 38, 39, 40, 41, 47
# Existing courses (skip): 1, 14, 15, 16, 22, 24, 27, 30, 31, 32, 33, 35, 44, 45, 46

NAMESPACE="mereka-lms"
POD=$(kubectl get pod -n ${NAMESPACE} -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')
BASE_DIR="/home/dev/code/mereka-lms/var/migrations/mct/course_packages_category"

echo "🚀 Importing NEW MCT courses to CMS pod: ${POD}"
echo ""

# Define NEW courses to import (category_id:slug:title)
declare -a COURSES=(
  "20:developer:Developer"
  "19:pursuing-a-career-in-the-field-of-data-analytics:Pursuing a career in Data Analytics"
  "21:digital-marketing-digital-marketing-strategies-for-your-busi:Digital Marketing"
  "17:pursuing-a-career-in-project-management:Pursuing a career in PM"
  "4:x-productivity-with-microsoft-365-bahasa:Productivity with Microsoft 365 (Bahasa)"
  "28:vn-mastering-digital-tools-thu-h-p-kho-ng-c-ch-s:VN Mastering Digital Tools"
  "29:test-virtual-assistant:TEST Virtual Assistant"
  "34:fow-eng-personal-well-being:FOW Personal Well-being"
  "36:fow-eng-managing-your-first-client:FOW Managing First Client"
  "37:fow-eng-freelancing-101:FOW Freelancing 101"
  "38:fow-eng-skills-profiling:FOW Skills Profiling"
  "39:fow-eng-securing-your-first-client:FOW Securing First Client"
  "40:fow-eng-securing-your-first-job:FOW Securing First Job"
  "41:fow-eng-thriving-in-your-job:FOW Thriving in Job"
  "47:gaming-garage-with-hp:Gaming Garage with HP"
)

SUCCESS=0
FAILED=0
TOTAL=${#COURSES[@]}

for i in "${!COURSES[@]}"; do
  IFS=':' read -r CATEGORY_ID SLUG TITLE <<< "${COURSES[$i]}"
  COURSE_NUM=$((i + 1))

  PACKAGE_PATH="${BASE_DIR}/${SLUG}/${SLUG}.tar.gz"

  if [[ ! -f "${PACKAGE_PATH}" ]]; then
    echo "⚠️  [$COURSE_NUM/$TOTAL] SKIP: ${TITLE} (ID: ${CATEGORY_ID}) - Package not found"
    ((FAILED++))
    continue
  fi

  echo "📦 [$COURSE_NUM/$TOTAL] Importing ${TITLE} (ID: ${CATEGORY_ID})"

  # Copy tarball to pod
  if ! kubectl cp "${PACKAGE_PATH}" "${NAMESPACE}/${POD}:/tmp/course.tgz" >/dev/null 2>&1; then
    echo "   ❌ Failed to copy tarball"
    ((FAILED++))
    continue
  fi

  # Extract and import
  IMPORT_OUTPUT=$(kubectl exec -n ${NAMESPACE} ${POD} -- bash -c "
    set -euo pipefail
    cd /tmp
    rm -rf course_import_base
    mkdir -p course_import_base/${SLUG}
    tar -xzf course.tgz -C course_import_base/${SLUG}
    cd /openedx/edx-platform
    python manage.py cms import /tmp/course_import_base ${SLUG} 2>&1
    rm -rf /tmp/course_import_base /tmp/course.tgz
  " 2>&1 || true)

  # Check if import succeeded (look for "Seeding forum roles" which appears at the end)
  if echo "${IMPORT_OUTPUT}" | grep -q "Seeding forum roles"; then
    echo "   ✅ Successfully imported course-v1:SKILLOURFUTURE+MCT-${CATEGORY_ID}+course"
    ((SUCCESS++))
  elif echo "${IMPORT_OUTPUT}" | grep -q "created successfully"; then
    echo "   ✅ Successfully imported course-v1:SKILLOURFUTURE+MCT-${CATEGORY_ID}+course"
    ((SUCCESS++))
  else
    echo "   ❌ Import failed"
    # Show last few lines of output for debugging
    echo "${IMPORT_OUTPUT}" | tail -10 | sed 's/^/      /'
    ((FAILED++))
  fi

  echo ""
done

echo "================================================================================"
echo "✅ Import complete! Success: ${SUCCESS}/${TOTAL}, Failed: ${FAILED}/${TOTAL}"
echo "================================================================================"

# Verify courses exist
echo ""
echo "Verifying imported courses..."
kubectl exec -n ${NAMESPACE} ${POD} -- bash -c "cd /openedx/edx-platform && python manage.py cms dump_course_ids 2>/dev/null | grep MCT" || echo "  (Error checking course list)"
