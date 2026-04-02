#!/usr/bin/env bash
# =============================================================================
# verify-import-dedup.sh — Check for data duplication from content migration
#
# Verifies that no duplicate users, enrollments, certificates, or courses
# were created by import runs. Safe to run repeatedly (read-only queries).
#
# Usage:
#   ./scripts/qa/verify-import-dedup.sh [--namespace NS] [--context CTX]
#
# Examples:
#   ./scripts/qa/verify-import-dedup.sh                          # dev (default)
#   ./scripts/qa/verify-import-dedup.sh --namespace stg-mereka-lms  # staging
# =============================================================================

set -euo pipefail

NAMESPACE="${NAMESPACE:-mereka-lms-dev}"
CONTEXT=""
ERRORS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --context)   CONTEXT="--context $2"; shift 2 ;;
    *)           echo "Unknown flag: $1"; exit 1 ;;
  esac
done

# Colour codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }

echo -e "${BOLD}=== Import Dedup Verification — $NAMESPACE ===${NC}"
echo ""

# Find LMS pod
LMS_POD=$(kubectl $CONTEXT get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms \
  --no-headers 2>/dev/null | grep -v worker | head -1 | awk '{print $1}')

if [[ -z "$LMS_POD" ]]; then
  # Fallback: try grep
  LMS_POD=$(kubectl $CONTEXT get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
    | grep "^lms-" | grep -v worker | head -1 | awk '{print $1}')
fi

if [[ -z "$LMS_POD" ]]; then
  echo "ERROR: No LMS pod found in namespace $NAMESPACE"
  exit 1
fi
echo "LMS pod: $LMS_POD"
echo ""

run_query() {
  local label="$1"
  local query="$2"
  kubectl $CONTEXT exec -n "$NAMESPACE" "$LMS_POD" -c lms -- \
    bash -c "cd /openedx/edx-platform && python manage.py lms shell -c \"$query\"" 2>&1 \
    | grep -v "^$\|WARNING\|DeprecationWarning\|ImportWarning\|RemovedInDjango\|RuntimeError\|casbin\|BLOCK_STRUCTURES\|imghdr\|SwaggerJSON\|drf_yasg\|openedx_tenant\|frozen import\|SixMeta\|embargo\|objects imported\|objects could\|form_class\|Historical\|openassessment\|common\.djangoapps\|lms\.djangoapps\|openedx\.\|return form"
}

# --- 1. Duplicate emails ---
echo -e "${BOLD}1. Duplicate user emails${NC}"
result=$(run_query "dup emails" "
from django.contrib.auth.models import User
from django.db.models import Count
dupes = User.objects.values('email').annotate(count=Count('id')).filter(count__gt=1).order_by('-count')
n = dupes.count()
if n == 0:
    print('PASS: 0 duplicate emails')
else:
    print(f'FAIL: {n} duplicate email groups')
    for d in dupes[:5]:
        print(f'  {d[\"email\"]}: {d[\"count\"]} accounts')
")
if echo "$result" | grep -q "PASS"; then
  ok "$result"
else
  fail "$result"
fi

# --- 2. Duplicate enrollments ---
echo -e "${BOLD}2. Duplicate enrollments (same user+course)${NC}"
result=$(run_query "dup enrollments" "
from student.models import CourseEnrollment
from django.db.models import Count
dupes = CourseEnrollment.objects.values('user_id', 'course_id').annotate(count=Count('id')).filter(count__gt=1)
n = dupes.count()
if n == 0:
    print('PASS: 0 duplicate enrollments')
else:
    print(f'FAIL: {n} duplicate enrollment pairs')
    for d in dupes[:5]:
        print(f'  user_id={d[\"user_id\"]} course={d[\"course_id\"]}: {d[\"count\"]}x')
")
if echo "$result" | grep -q "PASS"; then
  ok "$result"
else
  fail "$result"
fi

# --- 3. Duplicate certificates ---
echo -e "${BOLD}3. Duplicate certificates (same user+course)${NC}"
result=$(run_query "dup certs" "
from lms.djangoapps.certificates.models import GeneratedCertificate
from django.db.models import Count
dupes = GeneratedCertificate.objects.values('user_id', 'course_id').annotate(count=Count('id')).filter(count__gt=1)
n = dupes.count()
if n == 0:
    print('PASS: 0 duplicate certificates')
else:
    print(f'FAIL: {n} duplicate certificate pairs')
    for d in dupes[:5]:
        print(f'  user_id={d[\"user_id\"]} course={d[\"course_id\"]}: {d[\"count\"]}x')
")
if echo "$result" | grep -q "PASS"; then
  ok "$result"
else
  fail "$result"
fi

# --- 4. Summary counts ---
echo ""
echo -e "${BOLD}4. Summary counts${NC}"
run_query "counts" "
from django.contrib.auth.models import User
from student.models import CourseEnrollment
from lms.djangoapps.certificates.models import GeneratedCertificate
print(f'Users:       {User.objects.count():>8}')
print(f'Active:      {User.objects.filter(is_active=True).count():>8}')
print(f'Enrollments: {CourseEnrollment.objects.count():>8}')
print(f'Certificates:{GeneratedCertificate.objects.count():>8}')
"

echo ""
if [[ $ERRORS -eq 0 ]]; then
  ok "All dedup checks passed"
  exit 0
else
  fail "$ERRORS dedup check(s) FAILED"
  exit 1
fi
