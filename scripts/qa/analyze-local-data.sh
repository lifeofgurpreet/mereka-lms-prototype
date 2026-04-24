#!/usr/bin/env bash
# Analyze local database to understand what data exists.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
export TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
export TUTOR_PLUGINS_ROOT="${TUTOR_PLUGINS_ROOT:-${TUTOR_PLUGINS_DIR:-$TUTOR_ROOT/plugins}}"
export TUTOR_PLUGINS_DIR="$TUTOR_PLUGINS_ROOT"
if [[ -f .venv/bin/activate ]]; then
  # shellcheck source=/dev/null
  source .venv/bin/activate
fi

mysql_openedx() {
  local sql="$1"
  tutor local exec mysql env MYSQL_QUERY="$sql" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" openedx -e "$MYSQL_QUERY"' 2>/dev/null | sed '/Warning/d'
}

mysql_openedx_scalar() {
  local sql="$1"
  tutor local exec mysql env MYSQL_QUERY="$sql" sh -lc 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" openedx -N -e "$MYSQL_QUERY"' 2>/dev/null | sed '/Warning/d'
}

table_count() {
  local table="$1"
  mysql_openedx_scalar "SELECT COUNT(*) FROM ${table};" | tail -1 | tr -d ' ' || true
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Local Database Analysis                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if ! tutor local dc ps --services --filter status=running 2>/dev/null | grep -qx 'mysql'; then
  echo "Local MySQL service is not running. Run: make tutor-start"
  exit 1
fi

echo "=== Users ==="
mysql_openedx "
SELECT
    COUNT(*) as total_users,
    COUNT(CASE WHEN is_active=1 THEN 1 END) as active_users,
    COUNT(CASE WHEN is_staff=1 THEN 1 END) as staff_users,
    COUNT(CASE WHEN is_superuser=1 THEN 1 END) as superusers
FROM auth_user;
" | tail -5

echo ""
echo "=== Organizations ==="
mysql_openedx "
SELECT short_name, name, active FROM organizations_organization;
" | tail -10 || true

ORG_COUNT="$(table_count organizations_organization)"
if [[ -z "${ORG_COUNT:-}" || "$ORG_COUNT" == "0" ]]; then
  echo "  ⚠️  No organizations configured!"
fi

echo ""
echo "=== Sites ==="
mysql_openedx "
SELECT id, domain, name FROM django_site;
" | tail -10 || true

SITE_COUNT="$(table_count django_site)"
if [[ -z "${SITE_COUNT:-}" || "$SITE_COUNT" == "0" ]]; then
  echo "  ⚠️  No sites configured!"
fi

echo ""
echo "=== Courses ==="
if mysql_openedx_scalar "SHOW TABLES LIKE 'course_overviews_courseoverview';" | grep -q "course_overviews_courseoverview"; then
  mysql_openedx "
  SELECT
      COUNT(*) as course_overviews
  FROM course_overviews_courseoverview;
  " | tail -2
else
  echo "course_overviews_courseoverview table not found (run course indexing)."
fi

echo ""
echo "=== Enrollments ==="
mysql_openedx "
SELECT
    COUNT(*) as total_enrollments,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT course_id) as unique_courses
FROM student_courseenrollment;
" | tail -5 || true

echo ""
echo "=== Top Courses by Enrollment ==="
if mysql_openedx_scalar "SHOW TABLES LIKE 'student_courseenrollment';" | grep -q "student_courseenrollment"; then
  mysql_openedx "
  SELECT
      course_id,
      COUNT(*) as enrollment_count
  FROM student_courseenrollment
  GROUP BY course_id
  ORDER BY enrollment_count DESC
  LIMIT 10;
  " | tail -10
else
  echo "student_courseenrollment table not found."
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Analysis Complete                                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Expected Setup:"
echo "  • Organizations: BIJIBIJI, SKILLOURFUTURE"
echo "  • Sites: academy.biji-biji.com, skillourfuture.academy.mereka.io"
echo "  • Skill Our Future: ~80,000 users"
echo "  • Mereka (main): 100,000+ users"
echo ""
echo "If organizations/sites are missing, run:"
echo "  python tools/multisite_bootstrap.py --apply"
