#!/usr/bin/env bash
# Import MCT courses one by one - simplified version
set -euo pipefail

NAMESPACE="mereka-lms"
POD=$(kubectl get pod -n ${NAMESPACE} -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')
REPO_ROOT="${MEREKA_LMS_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BASE_DIR="${BASE_DIR:-${REPO_ROOT}/var/migrations/mct/course_packages_category}"

echo "🚀 Importing NEW MCT courses to pod: ${POD}"
echo ""

# Array of category_id:slug pairs for NEW courses
declare -a COURSES=(
  "20:developer"
  "19:pursuing-a-career-in-the-field-of-data-analytics"
  "21:digital-marketing-digital-marketing-strategies-for-your-busi"
  "17:pursuing-a-career-in-project-management"
  "4:x-productivity-with-microsoft-365-bahasa"
  "28:vn-mastering-digital-tools-thu-h-p-kho-ng-c-ch-s"
  "29:test-virtual-assistant"
  "34:fow-eng-personal-well-being"
  "36:fow-eng-managing-your-first-client"
  "37:fow-eng-freelancing-101"
  "38:fow-eng-skills-profiling"
  "39:fow-eng-securing-your-first-client"
  "40:fow-eng-securing-your-first-job"
  "41:fow-eng-thriving-in-your-job"
  "47:gaming-garage-with-hp"
)

for course in "${COURSES[@]}"; do
  IFS=':' read -r ID SLUG <<< "$course"
  PACKAGE="${BASE_DIR}/${SLUG}/${SLUG}.tar.gz"

  echo "📦 Importing ID ${ID}: ${SLUG}"

  if [[ ! -f "${PACKAGE}" ]]; then
    echo "   ⚠️  Package not found, skipping"
    continue
  fi

  # Copy and import
  kubectl cp "${PACKAGE}" "${NAMESPACE}/${POD}:/tmp/course.tgz" >/dev/null 2>&1
  kubectl exec -n ${NAMESPACE} ${POD} -- bash -c "
    cd /tmp && rm -rf course_import_base && mkdir -p course_import_base/${SLUG}
    tar -xzf course.tgz -C course_import_base/${SLUG}
    cd /openedx/edx-platform
    python manage.py cms import /tmp/course_import_base ${SLUG} >/dev/null 2>&1
    rm -rf /tmp/course_import_base /tmp/course.tgz
  "

  echo "   ✓ Import command completed"
done

echo ""
echo "✅ All import commands executed. Verifying..."
echo ""

# Verify all courses
kubectl exec -n ${NAMESPACE} ${POD} -- bash -c "cd /openedx/edx-platform && python manage.py cms dump_course_ids 2>/dev/null | grep MCT | sort"
