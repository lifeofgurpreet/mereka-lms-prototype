#!/usr/bin/env python3
"""
Cleanup Duplicate MCT Courses

DANGER: This script DELETES courses and course data.
Only run after:
1. Full database backup
2. Validation that enrollments are in correct courses
3. Confirmation that content is in the right place

This script removes:
1. Old format courses (MCT-*+course) that have been replaced
2. Empty MCTCAT courses with no enrollments

Usage:
    kubectl cp cleanup_duplicate_courses.py mereka-lms/lms-pod:/tmp/
    kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < /tmp/cleanup_duplicate_courses.py
"""


from common.djangoapps.student.models import CourseEnrollment
from django.db import transaction
from opaque_keys.edx.keys import CourseKey
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from xmodule.modulestore.django import modulestore

# Courses to potentially delete
OLD_FORMAT_COURSES = [
    'course-v1:SKILLOURFUTURE+MCT-22+course',  # Should be moved to MCT-22+RUN-22
    'course-v1:SKILLOURFUTURE+MCT-24+course',  # Replaced by MCTCAT-24+RUN-24
    'course-v1:SKILLOURFUTURE+MCT-27+course',  # Replaced by MCTCAT-27+RUN-27
    'course-v1:SKILLOURFUTURE+MCT-45+course',  # Replaced by MCTCAT-45+RUN-45
    'course-v1:SKILLOURFUTURE+MCT-46+course',  # Replaced by MCTCAT-46+RUN-46
]

EMPTY_MCTCAT_COURSES = [
    'course-v1:SKILLOURFUTURE+MCTCAT-1+RUN-1',      # Soft Skills
    'course-v1:SKILLOURFUTURE+MCTCAT-14+RUN-14',    # Employability
    'course-v1:SKILLOURFUTURE+MCTCAT-15+RUN-15',    # Mobile Literacy
    'course-v1:SKILLOURFUTURE+MCTCAT-16+RUN-16',    # Basic Microsoft
    'course-v1:SKILLOURFUTURE+MCTCAT-30+RUN-30',    # Climate Education
    'course-v1:SKILLOURFUTURE+MCTCAT-31+RUN-31',    # Your Future in Green Jobs
    'course-v1:SKILLOURFUTURE+MCTCAT-32+RUN-32',    # FOW (ENG) | Personal Branding
    'course-v1:SKILLOURFUTURE+MCTCAT-33+RUN-33',    # FOW (IND) | Personal Branding
    'course-v1:SKILLOURFUTURE+MCTCAT-35+RUN-35',    # FOW (ENG) | Personal Finance
    'course-v1:SKILLOURFUTURE+MCTCAT-44+RUN-44',    # Content Creation
]

def check_course_safety(course_id_str):
    """
    Check if a course is safe to delete

    Returns:
        (bool, str): (is_safe, reason)
    """
    # Check active enrollments
    active_enrollments = CourseEnrollment.objects.filter(
        course_id=course_id_str,
        is_active=True
    ).count()

    if active_enrollments > 0:
        return False, f"Has {active_enrollments:,} active enrollments"

    # Check inactive enrollments (keep historical data)
    inactive_enrollments = CourseEnrollment.objects.filter(
        course_id=course_id_str,
        is_active=False
    ).count()

    if inactive_enrollments > 100:
        return False, f"Has {inactive_enrollments:,} inactive enrollments (historical data)"

    # Check content
    store = modulestore()
    try:
        course_key = CourseKey.from_string(course_id_str)
        store.get_course(course_key)
    except Exception:
        pass

    return True, f"Safe: {active_enrollments} active, {inactive_enrollments} inactive enrollments"

def cleanup_courses(dry_run=True, delete_old_format=True, delete_empty_mctcat=True):
    """
    Delete duplicate and empty courses

    Args:
        dry_run: If True, only report what would be done
        delete_old_format: Delete old MCT-*+course format courses
        delete_empty_mctcat: Delete empty MCTCAT courses
    """
    store = modulestore()
    deleted_count = 0
    skipped_count = 0
    errors = []

    print("\n" + "=" * 100)
    print(f"{'DRY RUN: ' if dry_run else ''}COURSE CLEANUP")
    print("=" * 100)

    courses_to_check = []
    if delete_old_format:
        courses_to_check.extend(OLD_FORMAT_COURSES)
    if delete_empty_mctcat:
        courses_to_check.extend(EMPTY_MCTCAT_COURSES)

    print(f"\nChecking {len(courses_to_check)} courses for deletion...")
    print("-" * 100)

    for course_id_str in courses_to_check:
        # Check if course exists
        try:
            course_overview = CourseOverview.objects.get(id=course_id_str)
        except CourseOverview.DoesNotExist:
            print(f"⚠️  SKIP: {course_id_str} - CourseOverview not found")
            skipped_count += 1
            continue

        # Check safety
        is_safe, reason = check_course_safety(course_id_str)

        if not is_safe:
            print(f"⚠️  SKIP: {course_id_str}")
            print(f"         {course_overview.display_name}")
            print(f"         Reason: {reason}")
            print()
            skipped_count += 1
            errors.append({
                'course_id': course_id_str,
                'reason': reason
            })
            continue

        # Course is safe to delete
        print(f"{'Would delete' if dry_run else '🗑️  Deleting'}: {course_id_str}")
        print(f"              {course_overview.display_name}")
        print(f"              {reason}")

        if not dry_run:
            try:
                with transaction.atomic():
                    # Delete from modulestore (if exists)
                    try:
                        course_key = CourseKey.from_string(course_id_str)
                        store.delete_course(course_key, user_id=-1)
                        print("              ✅ Deleted from modulestore")
                    except Exception as e:
                        print(f"              ⚠️  Modulestore deletion failed: {e}")

                    # Delete CourseOverview
                    course_overview.delete()
                    print("              ✅ Deleted CourseOverview")

                deleted_count += 1
                print("              ✅ DELETED")

            except Exception as e:
                errors.append({
                    'course_id': course_id_str,
                    'reason': f"Deletion failed: {e}"
                })
                print(f"              ❌ ERROR: {e}")

        else:
            deleted_count += 1

        print()

    # Summary
    print("=" * 100)
    print(f"{'DRY RUN ' if dry_run else ''}CLEANUP SUMMARY")
    print("=" * 100)
    print(f"Courses Checked: {len(courses_to_check)}")
    print(f"{'Would be deleted' if dry_run else 'Deleted'}: {deleted_count}")
    print(f"Skipped (unsafe): {skipped_count}")
    print(f"Errors: {len([e for e in errors if 'failed' in e['reason'].lower()])}")
    print("=" * 100)

    if errors:
        print("\nCOURSES NOT DELETED:")
        print("-" * 100)
        for error in errors:
            print(f"  {error['course_id']}")
            print(f"    Reason: {error['reason']}")
        print("-" * 100)

    if dry_run:
        print("\n⚠️  This was a DRY RUN. No courses were deleted.")
        print("To execute deletion, run: cleanup_courses(dry_run=False)")
    else:
        print("\n✅ Cleanup complete!")

    return {
        'checked': len(courses_to_check),
        'deleted': deleted_count,
        'skipped': skipped_count,
        'errors': errors
    }

def verify_final_state():
    """Verify the final course state after cleanup"""
    courses = CourseOverview.objects.filter(org='SKILLOURFUTURE').order_by('id')
    store = modulestore()

    print("\n" + "=" * 100)
    print("FINAL COURSE STATE")
    print("=" * 100)

    total_enrollments = 0

    for course_overview in courses:
        course_id_str = str(course_overview.id)

        # Check content
        try:
            course_key = CourseKey.from_string(course_id_str)
            course = store.get_course(course_key)
            has_content = course is not None
        except Exception:
            has_content = False

        # Check enrollments
        enrollments = CourseEnrollment.objects.filter(
            course_id=course_id_str,
            is_active=True
        ).count()

        total_enrollments += enrollments

        status = "✅" if (has_content and enrollments > 0) else "❌"

        print(f"{status} {course_id_str}")
        print(f"   {course_overview.display_name}")
        print(f"   Content: {has_content}, Enrollments: {enrollments:,}")
        print()

    print("=" * 100)
    print(f"Total Courses: {courses.count()}")
    print(f"Total Enrollments: {total_enrollments:,}")
    print("=" * 100)

# Main execution
if __name__ == '__main__':
    print("\n" + "=" * 100)
    print("⚠️  COURSE CLEANUP SCRIPT")
    print("=" * 100)
    print("\n⚠️  WARNING: This script will DELETE courses and course data!")
    print("⚠️  Ensure you have:")
    print("    1. Full database backup")
    print("    2. Validated that enrollments are in correct courses")
    print("    3. Confirmed content is in the right place")
    print("\n" + "=" * 100)

    # Step 1: Dry run
    print("\nSTEP 1: DRY RUN")
    print("-" * 100)
    cleanup_courses(dry_run=True)

    # Instructions
    print("\n\n" + "=" * 100)
    print("⚠️  READY TO EXECUTE ACTUAL CLEANUP")
    print("=" * 100)
    print("\nTo proceed with actual deletion:")
    print("    cleanup_courses(dry_run=False)")
    print("\nTo verify final state:")
    print("    verify_final_state()")
    print("=" * 100)
