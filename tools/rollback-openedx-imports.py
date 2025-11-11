#!/usr/bin/env python3
"""
Rollback tool for Open edX imports.

Can remove:
- Enrollments imported from Kajabi
- Users imported from Kajabi (optional, dangerous)
- Certificates generated from Kajabi

Usage:
    # Dry run (see what would be removed)
    python tools/rollback-openedx-imports.py \
        --django-settings lms.envs.tutor.production \
        --import-file ops/migrations/kajabi/output/openedx/enrollments_import.csv \
        --dry-run
    
    # Actually remove enrollments
    python tools/rollback-openedx-imports.py \
        --django-settings lms.envs.tutor.production \
        --import-file ops/migrations/kajabi/output/openedx/enrollments_import.csv \
        --action unenroll
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path
from typing import List, Set


def bootstrap_django(settings_module: str) -> None:
    """Bootstrap Django environment."""
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
            USE_TZ=True,
        )
    django.setup()


def read_import_file(csv_path: Path) -> List[dict]:
    """Read import CSV file."""
    rows = []
    with csv_path.open("r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows


def unenroll_from_import_file(csv_path: Path, settings_module: str, dry_run: bool = False) -> dict:
    """Unenroll users based on import file."""
    bootstrap_django(settings_module)
    
    from django.contrib.auth.models import User
    from opaque_keys.edx.keys import CourseKey
    from common.djangoapps.student.models import CourseEnrollment
    
    rows = read_import_file(csv_path)
    stats = {
        "total": len(rows),
        "unenrolled": 0,
        "not_found": 0,
        "errors": [],
    }
    
    for row in rows:
        email = (row.get("email") or "").strip().lower()
        course_id = (row.get("course_id") or "").strip()
        
        if not email or not course_id:
            continue
        
        try:
            user = User.objects.get(email=email)
            course_key = CourseKey.from_string(course_id)
            
            if not dry_run:
                enrollment = CourseEnrollment.get_enrollment(user, course_key)
                if enrollment:
                    CourseEnrollment.unenroll(user, course_key, skip_refund=True)
                    stats["unenrolled"] += 1
                else:
                    stats["not_found"] += 1
            else:
                # Dry run - just check if enrollment exists
                enrollment = CourseEnrollment.get_enrollment(user, course_key)
                if enrollment:
                    stats["unenrolled"] += 1
                else:
                    stats["not_found"] += 1
                    
        except User.DoesNotExist:
            stats["not_found"] += 1
        except Exception as e:
            stats["errors"].append(f"{email} {course_id}: {e}")
    
    return stats


def remove_users_from_import_file(csv_path: Path, settings_module: str, dry_run: bool = False) -> dict:
    """Remove users based on import file (DANGEROUS - use with caution)."""
    bootstrap_django(settings_module)
    
    from django.contrib.auth.models import User
    
    rows = read_import_file(csv_path)
    emails = set(row.get("email", "").strip().lower() for row in rows if row.get("email"))
    
    stats = {
        "total": len(emails),
        "removed": 0,
        "not_found": 0,
        "errors": [],
    }
    
    for email in emails:
        try:
            user = User.objects.get(email=email)
            if not dry_run:
                user.delete()
                stats["removed"] += 1
            else:
                stats["removed"] += 1
        except User.DoesNotExist:
            stats["not_found"] += 1
        except Exception as e:
            stats["errors"].append(f"{email}: {e}")
    
    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description="Rollback Open edX imports")
    parser.add_argument("--django-settings", required=True, help="Django settings module")
    parser.add_argument("--import-file", required=True, help="CSV file used for import")
    parser.add_argument("--action", choices=["unenroll", "remove-users"], default="unenroll",
                       help="Action to take")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without doing it")
    args = parser.parse_args()
    
    print("=" * 60)
    print("Open edX Import Rollback")
    print("=" * 60)
    print()
    
    if args.dry_run:
        print("⚠️  DRY RUN MODE - No changes will be made")
        print()
    
    import_file = Path(args.import_file)
    if not import_file.exists():
        print(f"Error: Import file not found: {import_file}")
        sys.exit(1)
    
    rows = read_import_file(import_file)
    print(f"Import file: {import_file}")
    print(f"Rows in file: {len(rows)}")
    print()
    
    if args.action == "unenroll":
        print("Action: Unenroll users from courses")
        stats = unenroll_from_import_file(import_file, args.django_settings, args.dry_run)
    elif args.action == "remove-users":
        print("⚠️  WARNING: This will DELETE users!")
        response = input("Type 'DELETE' to confirm: ")
        if response != "DELETE":
            print("Cancelled.")
            sys.exit(0)
        stats = remove_users_from_import_file(import_file, args.django_settings, args.dry_run)
    
    print()
    print("Results:")
    print(f"  Total rows: {stats['total']}")
    print(f"  {'Would unenroll' if args.dry_run else 'Unenrolled'}: {stats['unenrolled']}")
    print(f"  Not found: {stats['not_found']}")
    if stats['errors']:
        print(f"  Errors: {len(stats['errors'])}")
        for error in stats['errors'][:10]:
            print(f"    {error}")
    
    if args.dry_run:
        print()
        print("Run without --dry-run to actually perform the rollback")


if __name__ == "__main__":
    main()



