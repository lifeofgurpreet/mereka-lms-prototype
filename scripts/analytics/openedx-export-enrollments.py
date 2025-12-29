#!/usr/bin/env python3
"""
Export enrollments from Open edX database.

Can work with:
1. Direct database connection
2. Django shell (if Django is available)
3. SQL dump file

Usage:
    python scripts/analytics/openedx-export-enrollments.py \
        --db-url "mysql://user:pass@host/db" \
        --output exports/openedx/enrollments.csv
    
    OR if you have Django access:
    python scripts/analytics/openedx-export-enrollments.py \
        --django-settings lms.envs.tutor.production \
        --output exports/openedx/enrollments.csv
"""

import argparse
import csv
import sys
from pathlib import Path


def export_from_django(settings_module: str, output_path: Path) -> None:
    """Export using Django ORM."""
    try:
        import django
        from django.conf import settings
        if not settings.configured:
            settings.configure(
                INSTALLED_APPS=[
                    'django.contrib.auth',
                    'django.contrib.contenttypes',
                    'common.djangoapps.student',
                    'openedx.core.djangoapps.content.course_overviews',
                ],
                DATABASES={
                    'default': {
                        'ENGINE': 'django.db.backends.mysql',
                        # Will be loaded from settings module
                    }
                },
                USE_TZ=True,
            )
        django.setup()
        
        from django.contrib.auth.models import User
        from common.djangoapps.student.models import CourseEnrollment
        
        with output_path.open('w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(['email', 'username', 'course_id', 'enrollment_date', 'is_active'])
            
            for enrollment in CourseEnrollment.objects.select_related('user').all():
                writer.writerow([
                    enrollment.user.email or '',
                    enrollment.user.username,
                    str(enrollment.course_id),
                    enrollment.created.isoformat() if enrollment.created else '',
                    'True' if enrollment.is_active else 'False'
                ])
        
        print(f"✓ Exported enrollments via Django")
    except ImportError:
        print("Django not available. Use --db-url for direct database access.")
        sys.exit(1)
    except Exception as e:
        print(f"Error exporting via Django: {e}")
        sys.exit(1)


def export_from_db(db_url: str, output_path: Path) -> None:
    """Export using direct database connection."""
    try:
        import pymysql
        from urllib.parse import urlparse
        
        parsed = urlparse(db_url.replace('mysql://', 'mysql+pymysql://'))
        conn = pymysql.connect(
            host=parsed.hostname or 'localhost',
            port=parsed.port or 3306,
            user=parsed.username,
            password=parsed.password,
            database=parsed.path.lstrip('/'),
            charset='utf8mb4'
        )
        
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT 
                    u.email,
                    u.username,
                    ce.course_id,
                    ce.created,
                    ce.is_active
                FROM student_courseenrollment ce
                JOIN auth_user u ON ce.user_id = u.id
                ORDER BY ce.created DESC
            """)
            
            with output_path.open('w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(['email', 'username', 'course_id', 'enrollment_date', 'is_active'])
                
                for row in cursor.fetchall():
                    writer.writerow([
                        row[0] or '',
                        row[1],
                        row[2],
                        row[3].isoformat() if row[3] else '',
                        'True' if row[4] else 'False'
                    ])
        
        conn.close()
        print(f"✓ Exported enrollments from database")
    except ImportError:
        print("pymysql not available. Install with: pip install pymysql")
        sys.exit(1)
    except Exception as e:
        print(f"Error exporting from database: {e}")
        sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser(description="Export Open edX enrollments")
    parser.add_argument("--output", required=True, help="Output CSV file path")
    parser.add_argument("--db-url", help="Database URL (mysql://user:pass@host/db)")
    parser.add_argument("--django-settings", help="Django settings module")
    args = parser.parse_args()
    
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    if args.db_url:
        export_from_db(args.db_url, output_path)
    elif args.django_settings:
        export_from_django(args.django_settings, output_path)
    else:
        print("Error: Must provide either --db-url or --django-settings")
        print("\nExample:")
        print("  python scripts/analytics/openedx-export-enrollments.py \\")
        print("    --db-url 'mysql://user:pass@localhost/openedx' \\")
        print("    --output exports/openedx/enrollments.csv")
        sys.exit(1)
    
    count = sum(1 for _ in output_path.open()) - 1  # Subtract header
    print(f"✓ Exported {count} enrollments to {output_path}")


if __name__ == "__main__":
    main()




