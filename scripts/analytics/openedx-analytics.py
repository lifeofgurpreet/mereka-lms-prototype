#!/usr/bin/env python
"""
OpenEdX Analytics Query Tool

Provides command-line access to course analytics including enrollments,
completions, and certificates.

Usage:
    tutor local run lms python /path/to/openedx-analytics.py --summary
    tutor local run lms python /path/to/openedx-analytics.py --course "course-v1:org+course+run" --enrollments
    tutor local run lms python /path/to/openedx-analytics.py --export-csv /tmp/analytics.csv
"""

import argparse
import csv
import sys
from datetime import timedelta

import django
from django.db.models import Count
from django.utils import timezone

# Django setup
django.setup()

from common.djangoapps.student.models import CourseEnrollment
from lms.djangoapps.certificates.models import GeneratedCertificate
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview


def get_summary_stats():
    """Get overall platform statistics."""
    total_enrollments = CourseEnrollment.objects.count()
    active_enrollments = CourseEnrollment.objects.filter(is_active=True).count()
    total_certificates = GeneratedCertificate.objects.filter(status='downloadable').count()
    total_courses = CourseOverview.objects.count()

    print("=" * 60)
    print("OpenEdX Platform Summary")
    print("=" * 60)
    print(f"Total Courses: {total_courses}")
    print(f"Total Enrollments: {total_enrollments}")
    print(f"Active Enrollments: {active_enrollments}")
    print(f"Certificates Issued: {total_certificates}")
    print("=" * 60)


def get_course_enrollments(course_id):
    """Get enrollment statistics for a specific course."""
    try:
        course = CourseOverview.get_from_id(course_id)
        course_name = course.display_name
    except Exception:
        course_name = course_id

    enrollments = CourseEnrollment.objects.filter(course_id=course_id)
    total = enrollments.count()
    active = enrollments.filter(is_active=True).count()
    inactive = total - active

    # Enrollment by mode
    modes = enrollments.values('mode').annotate(count=Count('id'))
    mode_breakdown = {m['mode']: m['count'] for m in modes}

    print(f"\nCourse: {course_name}")
    print(f"Course ID: {course_id}")
    print("-" * 60)
    print(f"Total Enrollments: {total}")
    print(f"Active: {active}")
    print(f"Inactive: {inactive}")
    if mode_breakdown:
        print("\nEnrollments by Mode:")
        for mode, count in sorted(mode_breakdown.items(), key=lambda x: -x[1]):
            print(f"  {mode}: {count}")


def get_course_completions(course_id):
    """Get completion statistics for a specific course."""
    try:
        course = CourseOverview.get_from_id(course_id)
        course_name = course.display_name
    except Exception:
        course_name = course_id

    enrollments = CourseEnrollment.objects.filter(
        course_id=course_id,
        is_active=True
    )
    total_enrolled = enrollments.count()

    certificates = GeneratedCertificate.objects.filter(
        course_id=course_id,
        status='downloadable'
    )
    completed = certificates.count()

    completion_rate = (completed / total_enrolled * 100) if total_enrolled > 0 else 0

    print(f"\nCourse: {course_name}")
    print(f"Course ID: {course_id}")
    print("-" * 60)
    print(f"Total Enrolled: {total_enrolled}")
    print(f"Completed: {completed}")
    print(f"Completion Rate: {completion_rate:.1f}%")


def get_all_courses_analytics():
    """Get analytics for all courses."""
    courses = CourseOverview.objects.all()
    results = []

    for course in courses:
        enrollments = CourseEnrollment.objects.filter(
            course_id=course.id,
            is_active=True
        )
        total_enrolled = enrollments.count()

        certificates = GeneratedCertificate.objects.filter(
            course_id=course.id,
            status='downloadable'
        )
        completed = certificates.count()

        completion_rate = (completed / total_enrolled * 100) if total_enrolled > 0 else 0

        results.append({
            'course_id': str(course.id),
            'course_name': course.display_name,
            'enrollments': total_enrolled,
            'completed': completed,
            'completion_rate': f"{completion_rate:.1f}%",
        })

    return sorted(results, key=lambda x: -x['enrollments'])


def print_courses_analytics(results, limit=20):
    """Print course analytics in a formatted table."""
    print("\n" + "=" * 100)
    print(f"{'Course Name':<50} {'Enrollments':<15} {'Completed':<15} {'Rate':<10}")
    print("=" * 100)

    for course in results[:limit]:
        print(
            f"{course['course_name'][:48]:<50} "
            f"{course['enrollments']:<15} "
            f"{course['completed']:<15} "
            f"{course['completion_rate']:<10}"
        )

    if len(results) > limit:
        print(f"\n... and {len(results) - limit} more courses")


def export_to_csv(results, filename):
    """Export analytics to CSV file."""
    with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
        fieldnames = ['course_id', 'course_name', 'enrollments', 'completed', 'completion_rate']
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for course in results:
            writer.writerow({
                'course_id': course['course_id'],
                'course_name': course['course_name'],
                'enrollments': course['enrollments'],
                'completed': course['completed'],
                'completion_rate': course['completion_rate'],
            })

    print(f"\nAnalytics exported to {filename}")


def get_enrollment_trends(days=30):
    """Get enrollment trends over time."""
    cutoff_date = timezone.now() - timedelta(days=days)
    enrollments = CourseEnrollment.objects.filter(
        created__gte=cutoff_date
    ).extra(
        select={'day': 'DATE(created)'}
    ).values('day').annotate(
        count=Count('id')
    ).order_by('day')

    print(f"\nEnrollment Trends (Last {days} days)")
    print("-" * 40)
    print(f"{'Date':<15} {'Enrollments':<15}")
    print("-" * 40)

    for item in enrollments:
        print(f"{item['day']:<15} {item['count']:<15}")


def main():
    parser = argparse.ArgumentParser(
        description='Query OpenEdX course analytics',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument(
        '--summary',
        action='store_true',
        help='Show overall platform statistics'
    )

    parser.add_argument(
        '--course',
        type=str,
        help='Course ID (e.g., course-v1:org+course+run)'
    )

    parser.add_argument(
        '--enrollments',
        action='store_true',
        help='Show enrollment statistics (requires --course)'
    )

    parser.add_argument(
        '--completions',
        action='store_true',
        help='Show completion statistics (requires --course)'
    )

    parser.add_argument(
        '--all-courses',
        action='store_true',
        help='Show analytics for all courses'
    )

    parser.add_argument(
        '--export-csv',
        type=str,
        metavar='FILENAME',
        help='Export all course analytics to CSV file'
    )

    parser.add_argument(
        '--trends',
        type=int,
        metavar='DAYS',
        default=30,
        help='Show enrollment trends for last N days (default: 30)'
    )

    parser.add_argument(
        '--limit',
        type=int,
        default=20,
        help='Limit number of courses shown (default: 20)'
    )

    args = parser.parse_args()

    # If no arguments, show summary
    if not any([
        args.summary,
        args.course,
        args.all_courses,
        args.export_csv,
        args.trends
    ]):
        args.summary = True

    try:
        if args.summary:
            get_summary_stats()

        if args.course:
            if args.enrollments:
                get_course_enrollments(args.course)
            elif args.completions:
                get_course_completions(args.course)
            else:
                # Show both if neither specified
                get_course_enrollments(args.course)
                get_course_completions(args.course)

        if args.all_courses:
            results = get_all_courses_analytics()
            print_courses_analytics(results, limit=args.limit)

        if args.export_csv:
            results = get_all_courses_analytics()
            export_to_csv(results, args.export_csv)

        if args.trends:
            get_enrollment_trends(days=args.trends)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()






