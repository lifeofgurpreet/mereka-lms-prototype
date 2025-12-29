#!/usr/bin/env python3
"""
Export certificates from Open edX.

Usage:
    python scripts/analytics/openedx-export-certificates.py \
        --django-settings lms.envs.tutor.production \
        --output exports/openedx/certificates.csv
    
    OR with database:
    python scripts/analytics/openedx-export-certificates.py \
        --db-url "mysql://user:pass@host/db" \
        --output exports/openedx/certificates.csv
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
            # Minimal Django setup
            django.setup()
        
        from django.contrib.auth.models import User
        try:
            from certificates.models import GeneratedCertificate
        except ImportError:
            try:
                from lms.djangoapps.certificates.models import GeneratedCertificate
            except ImportError:
                print("Certificate models not found. Trying alternative import...")
                from common.djangoapps.certificates.models import GeneratedCertificate
        
        with output_path.open('w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                'email', 'username', 'course_id', 'status', 
                'created_date', 'modified_date', 'grade', 'mode'
            ])
            
            for cert in GeneratedCertificate.objects.select_related('user').all():
                writer.writerow([
                    cert.user.email if cert.user else '',
                    cert.user.username if cert.user else '',
                    str(cert.course_id) if cert.course_id else '',
                    cert.status or '',
                    cert.created_date.isoformat() if cert.created_date else '',
                    cert.modified_date.isoformat() if cert.modified_date else '',
                    str(cert.grade) if cert.grade is not None else '',
                    cert.mode or '',
                ])
        
        print(f"✓ Exported certificates via Django")
    except ImportError as e:
        print(f"Django/certificate models not available: {e}")
        print("Trying database export...")
        raise
    except Exception as e:
        print(f"Error exporting via Django: {e}")
        raise


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
            # Try different table names
            table_name = None
            for table in ['certificates_generatedcertificate', 'certificates_generatedcertificates']:
                cursor.execute(f"SHOW TABLES LIKE '{table}'")
                if cursor.fetchone():
                    table_name = table
                    break
            
            if not table_name:
                print("Certificate table not found. Available tables:")
                cursor.execute("SHOW TABLES")
                for row in cursor.fetchall():
                    if 'cert' in row[0].lower():
                        print(f"  - {row[0]}")
                conn.close()
                sys.exit(1)
            
            cursor.execute(f"""
                SELECT 
                    u.email,
                    u.username,
                    c.course_id,
                    c.status,
                    c.created_date,
                    c.modified_date,
                    c.grade,
                    c.mode
                FROM {table_name} c
                LEFT JOIN auth_user u ON c.user_id = u.id
                ORDER BY c.created_date DESC
            """)
            
            with output_path.open('w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow([
                    'email', 'username', 'course_id', 'status',
                    'created_date', 'modified_date', 'grade', 'mode'
                ])
                
                for row in cursor.fetchall():
                    writer.writerow([
                        row[0] or '',
                        row[1] or '',
                        row[2] or '',
                        row[3] or '',
                        row[4].isoformat() if row[4] else '',
                        row[5].isoformat() if row[5] else '',
                        str(row[6]) if row[6] is not None else '',
                        row[7] or '',
                    ])
        
        conn.close()
        print(f"✓ Exported certificates from database")
    except ImportError:
        print("pymysql not available. Install with: pip install pymysql")
        sys.exit(1)
    except Exception as e:
        print(f"Error exporting from database: {e}")
        raise


def main() -> None:
    parser = argparse.ArgumentParser(description="Export Open edX certificates")
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
        sys.exit(1)
    
    count = sum(1 for _ in output_path.open()) - 1  # Subtract header
    print(f"✓ Exported {count} certificates to {output_path}")


if __name__ == "__main__":
    main()




