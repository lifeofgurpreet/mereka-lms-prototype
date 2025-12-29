#!/usr/bin/env python
"""
Link Courses to Programs in Discovery

This script:
1. Creates Course records in Discovery for all courses in programs_mapping.json
2. Links those courses to their respective Programs

Run in Discovery pod:
    kubectl cp scripts/migrations/mct/link_courses_to_programs.py mereka-lms/discovery-xxx:/tmp/
    kubectl exec -n mereka-lms discovery-xxx -- python /tmp/link_courses_to_programs.py
"""

import os
import sys
import json
import uuid
from datetime import datetime

# Django setup
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'course_discovery.settings.production')

import django
django.setup()

from django.db import connection, transaction
from course_discovery.apps.course_metadata.models import Course, Program, Organization
from course_discovery.apps.core.models import Partner

# Program to course mapping
PROGRAM_COURSE_MAPPING = {
    "Become An Entrepreneur": [
        "course-v1:SKILLOURFUTURE+INTRO-ENTREPRENEURIAL-MYTHS+2024",
        "course-v1:SKILLOURFUTURE+1-START-WITH-WHAT-MATTERS+2024",
        "course-v1:SKILLOURFUTURE+2-FROM-PROBLEMS-TO-POSSIBILI+2024",
        "course-v1:SKILLOURFUTURE+3-MARKET-TESTING-FOR-YOUR-ID+2024",
        "course-v1:SKILLOURFUTURE+4-STORYTELLING-YOUR-PROTOTYP+2024",
        "course-v1:SKILLOURFUTURE+5-BUILDING-A-TEAM-THAT-CAN-B+2024",
        "course-v1:SKILLOURFUTURE+6-FINDING-AVAILABLE-SUPPORT+2024",
        "course-v1:SKILLOURFUTURE+WRAP-UP-CLAIM-YOUR-CERTIFICA+2024",
    ],
    "Speak with Impact": [
        "course-v1:SKILLOURFUTURE+0-WELCOME--THIS-IS-NOT-YOUR+2024",
        "course-v1:SKILLOURFUTURE+1-OVERCOME-YOUR-FEAR-OF-PUBL+2024",
        "course-v1:SKILLOURFUTURE+2-THE-SECRET-TO-IMPACTFUL-CO+2024",
        "course-v1:SKILLOURFUTURE+3-POWERFUL-PRESENTATION-SKIL+2024",
        "course-v1:SKILLOURFUTURE+4-MASTER-THE-ART-OF-STORYTEL+2024",
        "course-v1:SKILLOURFUTURE+5-ELEVATE-YOUR-STAGE-PRESENC+2024",
        "course-v1:SKILLOURFUTURE+6-OWN-YOUR-VOICE-AS-A-WAY-OF+2024",
        "course-v1:SKILLOURFUTURE+7-PUBLIC-SPEAKING-FOR-ADVOCA+2024",
        "course-v1:SKILLOURFUTURE+8-PUBLIC-SPEAKING-FOR-BRANDI+2024",
        "course-v1:SKILLOURFUTURE+9-PUBLIC-SPEAKING-FOR-YOUNG+2024",
    ],
    "Embark on a Green Jobs Journey": [
        "course-v1:SKILLOURFUTURE+(CHINESE)-YOUR-FUTURE-IN-GREEN+2024",
        "course-v1:SKILLOURFUTURE+1-SPOT-THE-CHALLENGE+2024",
        "course-v1:SKILLOURFUTURE+2-LISTEN-TO-YOURSELF+2024",
        "course-v1:SKILLOURFUTURE+3-FIND-YOUR-PATH+2024",
        "course-v1:SKILLOURFUTURE+4-CONSIDER-THE-BIGGER-PICTUR+2024",
        "course-v1:SKILLOURFUTURE+5-UNLOCK-YOUR-INNER-ENTREPRE+2024",
        "course-v1:SKILLOURFUTURE+6-BUILD-YOUR-GREEN-CAREER+2024",
    ],
    "Developer": [
        "course-v1:SKILLOURFUTURE+1--GET-STARTED-WITH-WEB-DEVE+2024",
        "course-v1:SKILLOURFUTURE+2-DESCRIBE-CLOUD-COMPUTING+2024",
        "course-v1:SKILLOURFUTURE+3--BUILD-YOUR-FIRST-HTML-WEB+2024",
        "course-v1:SKILLOURFUTURE+4--USE-CSS-STYLES-IN-A-WEBPA+2024",
        "course-v1:SKILLOURFUTURE+5--JAVASCRIPT-ARRAYS-AND-LOO+2024",
        "course-v1:SKILLOURFUTURE+6--LEARNING-DATA-ENGINEERING+2024",
        "course-v1:SKILLOURFUTURE+7--SQL-PROGRAMMING+2024",
        "course-v1:SKILLOURFUTURE+8--IOS-APP-DEVELOPMENT+2024",
    ],
    "Data Analyst": [
        "course-v1:SKILLOURFUTURE+1--START-A-CAREER-IN-THE-FIE+2024",
        "course-v1:SKILLOURFUTURE+2--STARTING-FORMS+2024",
        "course-v1:SKILLOURFUTURE+3--BUILDING-PROCESSES-WITH-P+2024",
        "course-v1:SKILLOURFUTURE+4--DATA-ANALYSIS-IN-EXCEL+2024",
        "course-v1:SKILLOURFUTURE+5--UTILIZING-POWER-BI-DESKTO+2024",
    ],
    "Project Manager": [
        "course-v1:SKILLOURFUTURE+1-NO-NAME+2024",
        "course-v1:SKILLOURFUTURE+2-GETTING-STARTED-WITH-LISTS+2024",
        "course-v1:SKILLOURFUTURE+3-USING-MICROSOFT-PLANNER+2024",
        "course-v1:SKILLOURFUTURE+4-STAYING-ORGANIZED-WITH-MIC+2024",
    ],
    "Digital Marketer": [
        "course-v1:SKILLOURFUTURE+1--RECOGNIZE-THE-IMPORTANCE+2024",
        "course-v1:SKILLOURFUTURE+2--DETERMINING-MARKETING-CHA+2024",
        "course-v1:SKILLOURFUTURE+3--CREATING-A-SIMPLE-DASHBOA+2024",
        "course-v1:SKILLOURFUTURE+QUIZ+2024",
        "course-v1:SKILLOURFUTURE+STUDI-KASUS+2024",
    ],
    "Administrative Professional": [
        "course-v1:SKILLOURFUTURE+4-STUDI-KASUS+2024",
        "course-v1:SKILLOURFUTURE+1--CAREER-OPPORTUNITIES-IN-T+2024",
        "course-v1:SKILLOURFUTURE+2--BASIC-COMPETENCY-IN-THE-F+2024",
        "course-v1:SKILLOURFUTURE+3--ENHANCE-SKILLS-IN-ADMINIS+2024",
    ],
    "Employability": [
        "course-v1:SKILLOURFUTURE+BUILDING-A-STANDOUT-CV-FOR-CAR+2024",
        "course-v1:SKILLOURFUTURE+DIGITAL-BRANDING-&-EMPLOYABILI+2024",
        "course-v1:SKILLOURFUTURE+GREEN-JOBS-&-SUSTAINABILITY-CA+2024",
        "course-v1:SKILLOURFUTURE+HOW-TO-FIND-YOUR-DREAM-JOB+2024",
        "course-v1:SKILLOURFUTURE+MASTERING-THE-ART-OF-INTERVIEW+2024",
        "course-v1:SKILLOURFUTURE+PERSONAL-BRANDING-THROUGH-LINK+2024",
        "course-v1:SKILLOURFUTURE+XU-HƯỚNG-VIỆC-LÀM-XANH-DÀNH-CH+2024",
    ],
    "Mastering Digital Tools": [
        "course-v1:SKILLOURFUTURE+1--LÀM-VIỆC-VỚI-MÁY-TÍNH+2024",
        "course-v1:SKILLOURFUTURE+2--TRUY-CẬP-THÔNG-TIN-TRỰC-T+2024",
        "course-v1:SKILLOURFUTURE+3--GIAO-TIẾP-TRỰC-TUYẾN+2024",
        "course-v1:SKILLOURFUTURE+4--THAM-GIA-AN-TOÀN-VÀ-CÓ-TR+2024",
        "course-v1:SKILLOURFUTURE+5--TẠO-NỘI-DUNG-KỸ-THUẬT-SỐ+2024",
        "course-v1:SKILLOURFUTURE+6--CỘNG-TÁC-VÀ-QUẢN-LÝ-NỘI-D+2024",
        "course-v1:SKILLOURFUTURE+KHUNG-ĐÁNH-GIÁ-NĂNG-LỰC-SỐ-CHO+2024",
        "course-v1:SKILLOURFUTURE+TẠO-TRANG-WEB-VỚI-ỨNG-DỤNG-WIX+2024",
        "course-v1:SKILLOURFUTURE+THIẾT-KẾ-HÌNH-ẢNH-VỚI-CÔNG-CỤ+2024",
    ],
    "TEST Virtual Assistant": [
        "course-v1:SKILLOURFUTURE+1-WHAT-IS-VIRTUAL-ASSISTANT?+2024",
        "course-v1:SKILLOURFUTURE+TEST+2024",
    ],
}


def get_course_title_from_key(course_key):
    """Extract a readable title from course key."""
    # course-v1:SKILLOURFUTURE+COURSE-CODE+2024 -> COURSE-CODE
    parts = course_key.split('+')
    if len(parts) >= 2:
        code = parts[1]
        # Convert COURSE-CODE to Course Code
        return code.replace('-', ' ').replace('--', ' - ').title()
    return course_key


def create_course_raw_sql(cursor, partner_id, course_key, org_id):
    """Create course using raw SQL to bypass Celery signals."""
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
    course_uuid = uuid.uuid4().hex  # 32 char hex without dashes
    title = get_course_title_from_key(course_key)

    # Check if course exists
    cursor.execute("SELECT id FROM course_metadata_course WHERE `key` = %s", [course_key])
    row = cursor.fetchone()

    if row:
        return row[0], False  # course_id, created=False

    # Insert course
    cursor.execute("""
        INSERT INTO course_metadata_course
        (created, modified, uuid, `key`, title, partner_id, draft, enterprise_subscription_inclusion)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """, [now, now, course_uuid, course_key, title, partner_id, 0, 1])

    course_id = cursor.lastrowid

    # Link course to organization
    cursor.execute("""
        INSERT IGNORE INTO course_metadata_course_authoring_organizations (course_id, organization_id)
        VALUES (%s, %s)
    """, [course_id, org_id])

    return course_id, True


def link_course_to_program_sql(cursor, program_id, course_id):
    """Link course to program using raw SQL."""
    cursor.execute("""
        INSERT IGNORE INTO course_metadata_program_courses (program_id, course_id)
        VALUES (%s, %s)
    """, [program_id, course_id])
    return cursor.rowcount > 0


def main():
    print("=" * 60)
    print("MCT Migration: Link Courses to Programs")
    print("=" * 60)

    cursor = connection.cursor()

    # Get partner
    try:
        partner = Partner.objects.get(short_code='sof')
        print(f"\nPartner: {partner.name} (id={partner.id})")
    except Partner.DoesNotExist:
        print("ERROR: Partner 'sof' not found!")
        sys.exit(1)

    # Get or create organization
    try:
        org = Organization.objects.get(key='SKILLOURFUTURE')
        print(f"Organization: {org.name} (id={org.id})")
    except Organization.DoesNotExist:
        print("Creating organization SKILLOURFUTURE...")
        cursor.execute("""
            INSERT INTO course_metadata_organization
            (created, modified, uuid, `key`, name, partner_id)
            VALUES (NOW(), NOW(), %s, 'SKILLOURFUTURE', 'Skill Our Future', %s)
        """, [uuid.uuid4().hex, partner.id])
        connection.commit()
        org = Organization.objects.get(key='SKILLOURFUTURE')
        print(f"Created organization: {org.name} (id={org.id})")

    # Get all programs
    programs = {p.title: p for p in Program.objects.all()}
    print(f"\nFound {len(programs)} programs in Discovery")

    # Statistics
    stats = {
        'courses_created': 0,
        'courses_existing': 0,
        'links_created': 0,
        'links_existing': 0,
        'programs_updated': 0,
        'errors': []
    }

    # Process each program
    print("\n" + "-" * 60)
    print("Processing programs...")
    print("-" * 60)

    for program_name, course_keys in PROGRAM_COURSE_MAPPING.items():
        print(f"\n[{program_name}]")

        if program_name not in programs:
            print(f"  WARNING: Program not found in Discovery, skipping")
            stats['errors'].append(f"Program not found: {program_name}")
            continue

        program = programs[program_name]
        program_updated = False

        for course_key in course_keys:
            try:
                # Create course if not exists
                course_id, created = create_course_raw_sql(
                    cursor, partner.id, course_key, org.id
                )

                if created:
                    stats['courses_created'] += 1
                    print(f"  + Created course: {course_key[:50]}...")
                else:
                    stats['courses_existing'] += 1

                # Link course to program
                linked = link_course_to_program_sql(cursor, program.id, course_id)
                if linked:
                    stats['links_created'] += 1
                    program_updated = True
                    print(f"  -> Linked to program")
                else:
                    stats['links_existing'] += 1

            except Exception as e:
                error_msg = f"Error with {course_key}: {str(e)}"
                print(f"  ERROR: {error_msg}")
                stats['errors'].append(error_msg)

        if program_updated:
            stats['programs_updated'] += 1

    # Commit all changes
    connection.commit()

    # Print summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Courses created:     {stats['courses_created']}")
    print(f"Courses existing:    {stats['courses_existing']}")
    print(f"Links created:       {stats['links_created']}")
    print(f"Links existing:      {stats['links_existing']}")
    print(f"Programs updated:    {stats['programs_updated']}")
    print(f"Errors:              {len(stats['errors'])}")

    if stats['errors']:
        print("\nErrors:")
        for e in stats['errors'][:10]:
            print(f"  - {e}")

    # Verify
    print("\n" + "-" * 60)
    print("Verification - Programs with course counts:")
    print("-" * 60)

    cursor.execute("""
        SELECT p.title, COUNT(pc.course_id) as num_courses
        FROM course_metadata_program p
        LEFT JOIN course_metadata_program_courses pc ON p.id = pc.program_id
        GROUP BY p.id, p.title
        ORDER BY p.title
    """)

    for row in cursor.fetchall():
        print(f"  {row[0]}: {row[1]} courses")

    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)


if __name__ == '__main__':
    main()
