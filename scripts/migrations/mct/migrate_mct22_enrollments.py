#!/usr/bin/env python3
"""
Migrate MCT-22 Enrollments

Moves enrollments from:
  course-v1:SKILLOURFUTURE+MCT-22+course (no content, 45,684 enrollments)
To:
  course-v1:SKILLOURFUTURE+MCT-22+RUN-22 (has content, 0 enrollments)

This script:
1. Validates both courses exist
2. Checks content availability
3. Migrates enrollments one by one
4. Preserves enrollment metadata (created date, mode, etc.)
5. Reports progress

Usage:
    kubectl cp migrate_mct22_enrollments.py mereka-lms/lms-pod:/tmp/
    kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < /tmp/migrate_mct22_enrollments.py
"""

from common.djangoapps.student.models import CourseEnrollment
from opaque_keys.edx.keys import CourseKey
from xmodule.modulestore.django import modulestore
from django.db import transaction
import sys

OLD_COURSE_ID = 'course-v1:SKILLOURFUTURE+MCT-22+course'
NEW_COURSE_ID = 'course-v1:SKILLOURFUTURE+MCT-22+RUN-22'

def validate_courses():
    """Validate that courses exist and have expected states"""
    store = modulestore()

    print("Validating courses...")
    print("=" * 80)

    # Check old course
    old_key = CourseKey.from_string(OLD_COURSE_ID)
    old_course = store.get_course(old_key)
    old_has_content = old_course is not None

    old_enrollments = CourseEnrollment.objects.filter(
        course_id=OLD_COURSE_ID,
        is_active=True
    ).count()

    print(f"Old Course: {OLD_COURSE_ID}")
    print(f"  Has Content: {old_has_content}")
    print(f"  Enrollments: {old_enrollments:,}")

    # Check new course
    new_key = CourseKey.from_string(NEW_COURSE_ID)
    new_course = store.get_course(new_key)
    new_has_content = new_course is not None

    new_enrollments = CourseEnrollment.objects.filter(
        course_id=NEW_COURSE_ID,
        is_active=True
    ).count()

    print(f"\nNew Course: {NEW_COURSE_ID}")
    print(f"  Has Content: {new_has_content}")
    print(f"  Enrollments: {new_enrollments:,}")
    print("=" * 80)

    # Validate expected state
    if not new_has_content:
        print("\n❌ ERROR: New course has no content!")
        print("Cannot migrate enrollments to a course without content.")
        return False

    if old_enrollments == 0:
        print("\n⚠️  WARNING: No enrollments to migrate!")
        return False

    print(f"\n✅ Validation passed. Ready to migrate {old_enrollments:,} enrollments.")
    return True

def migrate_enrollments(dry_run=True, batch_size=1000):
    """
    Migrate enrollments from old course to new course

    Args:
        dry_run: If True, only report what would be done
        batch_size: Number of enrollments to process at once
    """
    old_key = CourseKey.from_string(OLD_COURSE_ID)
    new_key = CourseKey.from_string(NEW_COURSE_ID)

    # Get all enrollments to migrate
    enrollments = CourseEnrollment.objects.filter(
        course_id=old_key,
        is_active=True
    )

    total = enrollments.count()
    print(f"\n{'DRY RUN: ' if dry_run else ''}Migrating {total:,} enrollments...")
    print("=" * 80)

    migrated = 0
    skipped = 0
    errors = 0

    for i, enrollment in enumerate(enrollments.iterator(chunk_size=batch_size)):
        try:
            # Check if user already enrolled in new course
            existing = CourseEnrollment.objects.filter(
                user=enrollment.user,
                course_id=new_key
            ).first()

            if existing:
                # User already enrolled in new course, deactivate old enrollment
                if not dry_run:
                    enrollment.is_active = False
                    enrollment.save()
                skipped += 1
                action = "Would skip (already enrolled)" if dry_run else "Deactivated old enrollment"
            else:
                # Migrate enrollment to new course
                if not dry_run:
                    with transaction.atomic():
                        enrollment.course_id = new_key
                        enrollment.save()
                migrated += 1
                action = "Would migrate" if dry_run else "Migrated"

            # Progress report every 1000 enrollments
            if (i + 1) % 1000 == 0:
                print(f"Progress: {i + 1:,} / {total:,} processed "
                      f"({migrated:,} migrated, {skipped:,} skipped)")

        except Exception as e:
            errors += 1
            print(f"ERROR migrating enrollment for user {enrollment.user_id}: {e}")

    # Final report
    print("=" * 80)
    print(f"{'DRY RUN ' if dry_run else ''}MIGRATION COMPLETE")
    print("=" * 80)
    print(f"Total Enrollments: {total:,}")
    print(f"Migrated: {migrated:,}")
    print(f"Skipped (already enrolled): {skipped:,}")
    print(f"Errors: {errors:,}")
    print("=" * 80)

    if dry_run:
        print("\n⚠️  This was a DRY RUN. No changes were made.")
        print("To execute the migration, run: migrate_enrollments(dry_run=False)")

    return {
        'total': total,
        'migrated': migrated,
        'skipped': skipped,
        'errors': errors
    }

def verify_migration():
    """Verify the migration was successful"""
    old_enrollments = CourseEnrollment.objects.filter(
        course_id=OLD_COURSE_ID,
        is_active=True
    ).count()

    new_enrollments = CourseEnrollment.objects.filter(
        course_id=NEW_COURSE_ID,
        is_active=True
    ).count()

    print("\nVERIFICATION")
    print("=" * 80)
    print(f"Old Course Active Enrollments: {old_enrollments:,}")
    print(f"New Course Active Enrollments: {new_enrollments:,}")

    if old_enrollments == 0:
        print("✅ SUCCESS: All enrollments migrated from old course")
    else:
        print(f"⚠️  WARNING: {old_enrollments:,} enrollments still in old course")

    print("=" * 80)

# Main execution
if __name__ == '__main__':
    print("\n" + "=" * 80)
    print("MCT-22 ENROLLMENT MIGRATION SCRIPT")
    print("=" * 80)

    # Step 1: Validate
    if not validate_courses():
        print("\n❌ Validation failed. Aborting.")
        sys.exit(1)

    # Step 2: Dry run
    print("\n\nSTEP 1: DRY RUN")
    print("-" * 80)
    migrate_enrollments(dry_run=True)

    # Step 3: Confirm before actual migration
    print("\n\n" + "=" * 80)
    print("⚠️  READY TO EXECUTE ACTUAL MIGRATION")
    print("=" * 80)
    print("\nTo proceed with the actual migration, manually run:")
    print("    migrate_enrollments(dry_run=False)")
    print("\nTo verify after migration:")
    print("    verify_migration()")
    print("=" * 80)
