#!/usr/bin/env python3
"""
Validate MCT Course Content and Enrollments

Checks that all SKILLOURFUTURE courses have:
1. Content in modulestore (MongoDB)
2. Enrollments that can access that content
3. No orphaned courses or enrollments

Usage:
    kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < validate_course_content.py
"""

from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from common.djangoapps.student.models import CourseEnrollment
from opaque_keys.edx.keys import CourseKey
from xmodule.modulestore.django import modulestore
import json

def validate_courses():
    """Validate all SKILLOURFUTURE courses"""
    courses = CourseOverview.objects.filter(org='SKILLOURFUTURE').order_by('id')
    store = modulestore()

    results = {
        'summary': {
            'total_courses': 0,
            'courses_with_content': 0,
            'courses_with_enrollments': 0,
            'broken_courses': 0,
            'orphaned_courses': 0,
        },
        'courses': []
    }

    print("=" * 100)
    print("MCT COURSE VALIDATION REPORT")
    print("=" * 100)
    print()

    for course_overview in courses:
        results['summary']['total_courses'] += 1
        course_id_str = str(course_overview.id)

        # Check content in modulestore
        try:
            course_key = CourseKey.from_string(course_id_str)
            course = store.get_course(course_key)
            has_content = course is not None

            if has_content:
                chapter_count = len(list(course.get_children())) if hasattr(course, 'get_children') else 0
            else:
                chapter_count = 0
        except Exception as e:
            has_content = False
            chapter_count = 0

        # Check enrollments
        enrollment_count = CourseEnrollment.objects.filter(
            course_id=course_id_str,
            is_active=True
        ).count()

        # Determine status
        if has_content:
            results['summary']['courses_with_content'] += 1
        if enrollment_count > 0:
            results['summary']['courses_with_enrollments'] += 1

        # Broken: has enrollments but no content
        is_broken = enrollment_count > 0 and not has_content

        # Orphaned: has content but no enrollments
        is_orphaned = has_content and enrollment_count == 0

        if is_broken:
            results['summary']['broken_courses'] += 1
            status = "❌ BROKEN"
        elif is_orphaned:
            results['summary']['orphaned_courses'] += 1
            status = "⚠️  ORPHANED"
        elif has_content and enrollment_count > 0:
            status = "✅ OK"
        else:
            status = "🗑️  EMPTY"

        course_data = {
            'course_id': course_id_str,
            'display_name': course_overview.display_name,
            'has_content': has_content,
            'chapter_count': chapter_count,
            'enrollment_count': enrollment_count,
            'status': status,
            'created': str(course_overview.created),
        }

        results['courses'].append(course_data)

        # Print course details
        print(f"{status} {course_id_str}")
        print(f"   Display Name: {course_overview.display_name}")
        print(f"   Has Content: {has_content} ({chapter_count} chapters)")
        print(f"   Enrollments: {enrollment_count:,}")
        print(f"   Created: {course_overview.created}")
        print()

    # Print summary
    print("=" * 100)
    print("SUMMARY")
    print("=" * 100)
    print(f"Total Courses: {results['summary']['total_courses']}")
    print(f"Courses with Content: {results['summary']['courses_with_content']}")
    print(f"Courses with Enrollments: {results['summary']['courses_with_enrollments']}")
    print(f"❌ BROKEN Courses (enrollments but no content): {results['summary']['broken_courses']}")
    print(f"⚠️  ORPHANED Courses (content but no enrollments): {results['summary']['orphaned_courses']}")
    print()

    # Print recommendations
    print("=" * 100)
    print("RECOMMENDATIONS")
    print("=" * 100)

    broken = [c for c in results['courses'] if '❌' in c['status']]
    orphaned = [c for c in results['courses'] if '⚠️' in c['status']]
    empty = [c for c in results['courses'] if '🗑️' in c['status']]

    if broken:
        print("\n🚨 CRITICAL: Broken Courses (users cannot access content)")
        print("-" * 100)
        for course in broken:
            print(f"   {course['course_id']}: {course['enrollment_count']:,} enrollments with NO content")
        print("\n   ACTION REQUIRED: Re-import content for these courses ASAP")

    if orphaned:
        print("\n⚠️  WARNING: Orphaned Courses (content exists but no users)")
        print("-" * 100)
        for course in orphaned:
            print(f"   {course['course_id']}: {course['chapter_count']} chapters with 0 enrollments")
        print("\n   ACTION: Consider moving enrollments to these courses or deleting them")

    if empty:
        print("\n🗑️  INFO: Empty Courses (no content, no enrollments)")
        print("-" * 100)
        for course in empty:
            print(f"   {course['course_id']}")
        print("\n   ACTION: Safe to delete these courses")

    print("\n" + "=" * 100)
    print("END OF REPORT")
    print("=" * 100)

    return results

# Run validation
if __name__ == '__main__':
    validate_courses()
