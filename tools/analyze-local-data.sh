#!/usr/bin/env bash
# Analyze local database to understand what data exists
set -euo pipefail

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║        Local Database Analysis                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

echo "=== Users ==="
docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "
SELECT 
    COUNT(*) as total_users,
    COUNT(CASE WHEN is_active=1 THEN 1 END) as active_users,
    COUNT(CASE WHEN is_staff=1 THEN 1 END) as staff_users,
    COUNT(CASE WHEN is_superuser=1 THEN 1 END) as superusers
FROM auth_user;
" 2>/dev/null | grep -v "Warning" | tail -5

echo ""
echo "=== Organizations ==="
docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "
SELECT short_name, name, active FROM organizations_organization;
" 2>/dev/null | grep -v "Warning" | tail -10

if [ $? -ne 0 ] || [ -z "$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e 'SELECT COUNT(*) FROM organizations_organization;' 2>/dev/null | grep -v 'Warning' | tail -1 | tr -d ' ')" ] || [ "$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e 'SELECT COUNT(*) FROM organizations_organization;' 2>/dev/null | grep -v 'Warning' | tail -1 | tr -d ' ')" = "0" ]; then
    echo "  ⚠️  No organizations configured!"
fi

echo ""
echo "=== Sites ==="
docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "
SELECT id, domain, name FROM django_site;
" 2>/dev/null | grep -v "Warning" | tail -10

if [ $? -ne 0 ] || [ -z "$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e 'SELECT COUNT(*) FROM django_site;' 2>/dev/null | grep -v 'Warning' | tail -1 | tr -d ' ')" ] || [ "$(docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e 'SELECT COUNT(*) FROM django_site;' 2>/dev/null | grep -v 'Warning' | tail -1 | tr -d ' ')" = "0" ]; then
    echo "  ⚠️  No sites configured!"
fi

echo ""
echo "=== Courses ==="
# Check if course_overviews table exists
if docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -N -e "SHOW TABLES LIKE 'course_overviews_courseoverview';" 2>/dev/null | grep -q "course_overviews_courseoverview"; then
  docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "
  SELECT 
      COUNT(*) as course_overviews
  FROM course_overviews_courseoverview;
  " 2>/dev/null | grep -v "Warning" | tail -2
else
  echo "course_overviews_courseoverview table not found (run course indexing)."
fi

echo ""
echo "=== Enrollments ==="
docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "
SELECT 
    COUNT(*) as total_enrollments,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(DISTINCT course_id) as unique_courses
FROM student_courseenrollment;
" 2>/dev/null | grep -v "Warning" | tail -5

echo ""
echo "=== Top Courses by Enrollment ==="
if docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -N -e "SHOW TABLES LIKE 'student_courseenrollment';" 2>/dev/null | grep -q "student_courseenrollment"; then
  docker exec tutor_local-mysql-1 mysql -uroot -p1EebOQxu openedx -e "
  SELECT 
      course_id,
      COUNT(*) as enrollment_count
  FROM student_courseenrollment
  GROUP BY course_id
  ORDER BY enrollment_count DESC
  LIMIT 10;
  " 2>/dev/null | grep -v "Warning" | tail -10
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
echo "  • Sites: academy.biji-biji.com, skillourfuture.staging.academy.mereka.io"
echo "  • Skill Our Future: ~80,000 users"
echo "  • Mereka (main): 100,000+ users"
echo ""
echo "If organizations/sites are missing, run:"
echo "  python tools/multisite_bootstrap.py --apply"

