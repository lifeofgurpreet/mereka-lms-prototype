#!/usr/bin/env python
"""
Create MCT Programs in Discovery Service via Django ORM.
This script bypasses the read-only API and creates programs directly.

Usage (inside Discovery pod):
    python /tmp/create_programs_orm.py

Or via kubectl:
    kubectl cp create_programs_orm.py mereka-lms/discovery-xxx:/tmp/
    kubectl exec -n mereka-lms deploy/discovery -- python /tmp/create_programs_orm.py
"""
import os

import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'course_discovery.settings.production')
django.setup()

from course_discovery.apps.core.models import Partner
from course_discovery.apps.course_metadata.models import Course, Organization, Program, ProgramType
from django.db import transaction

# Programs mapping (embedded for portability)
PROGRAMS_DATA = {
    "13": {
        "program_name": "Project Manager",
        "program_subtitle": "How to manage projects effectively with scheduling, budgeting, and communication, and explore PM tools in Microsoft 365.",
        "program_type": "Professional Certificate",
        "marketing_slug": "project-manager",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+1-NO-NAME+2024",
            "course-v1:SKILLOURFUTURE+2-GETTING-STARTED-WITH-LISTS+2024",
            "course-v1:SKILLOURFUTURE+3-USING-MICROSOFT-PLANNER+2024",
            "course-v1:SKILLOURFUTURE+4-STAYING-ORGANIZED-WITH-MIC+2024"
        ]
    },
    "14": {
        "program_name": "Data Analyst",
        "program_subtitle": "Foundational concepts used in data analysis and practice using software tools for data analytics and data visualization.",
        "program_type": "Professional Certificate",
        "marketing_slug": "data-analyst",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+1--START-A-CAREER-IN-THE-FIE+2024",
            "course-v1:SKILLOURFUTURE+2--STARTING-FORMS+2024",
            "course-v1:SKILLOURFUTURE+3--BUILDING-PROCESSES-WITH-P+2024",
            "course-v1:SKILLOURFUTURE+4--DATA-ANALYSIS-IN-EXCEL+2024",
            "course-v1:SKILLOURFUTURE+5--UTILIZING-POWER-BI-DESKTO+2024"
        ]
    },
    "15": {
        "program_name": "Developer",
        "program_subtitle": "Core concepts and structure of programming languages and learn how they're applied.",
        "program_type": "Professional Certificate",
        "marketing_slug": "developer",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+1--GET-STARTED-WITH-WEB-DEVE+2024",
            "course-v1:SKILLOURFUTURE+2-DESCRIBE-CLOUD-COMPUTING+2024",
            "course-v1:SKILLOURFUTURE+3--BUILD-YOUR-FIRST-HTML-WEB+2024",
            "course-v1:SKILLOURFUTURE+4--USE-CSS-STYLES-IN-A-WEBPA+2024",
            "course-v1:SKILLOURFUTURE+5--JAVASCRIPT-ARRAYS-AND-LOO+2024",
            "course-v1:SKILLOURFUTURE+6--LEARNING-DATA-ENGINEERING+2024",
            "course-v1:SKILLOURFUTURE+7--SQL-PROGRAMMING+2024",
            "course-v1:SKILLOURFUTURE+8--IOS-APP-DEVELOPMENT+2024"
        ]
    },
    "16": {
        "program_name": "Administrative Professional",
        "program_subtitle": "Essential skills needed for administrative roles, including communication, writing, time management, and must-have software skills.",
        "program_type": "Professional Certificate",
        "marketing_slug": "administrative-professional",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+4-STUDI-KASUS+2024",
            "course-v1:SKILLOURFUTURE+1--CAREER-OPPORTUNITIES-IN-T+2024",
            "course-v1:SKILLOURFUTURE+2--BASIC-COMPETENCY-IN-THE-F+2024",
            "course-v1:SKILLOURFUTURE+3--ENHANCE-SKILLS-IN-ADMINIS+2024"
        ]
    },
    "17": {
        "program_name": "Digital Marketer",
        "program_subtitle": "How to utilize marketing channels, content making, and report writing marketing report.",
        "program_type": "Professional Certificate",
        "marketing_slug": "digital-marketer",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+1--RECOGNIZE-THE-IMPORTANCE+2024",
            "course-v1:SKILLOURFUTURE+2--DETERMINING-MARKETING-CHA+2024",
            "course-v1:SKILLOURFUTURE+3--CREATING-A-SIMPLE-DASHBOA+2024",
            "course-v1:SKILLOURFUTURE+QUIZ+2024",
            "course-v1:SKILLOURFUTURE+STUDI-KASUS+2024"
        ]
    },
    "21": {
        "program_name": "Mastering Digital Tools",
        "program_subtitle": "Vietnam-specific program for digital literacy",
        "program_type": "XSeries",
        "marketing_slug": "mastering-digital-tools",
        "status": "active",
        "certificate_enabled": False,
        "courses": [
            "course-v1:SKILLOURFUTURE+1--LÀM-VIỆC-VỚI-MÁY-TÍNH+2024",
            "course-v1:SKILLOURFUTURE+2--TRUY-CẬP-THÔNG-TIN-TRỰC-T+2024",
            "course-v1:SKILLOURFUTURE+3--GIAO-TIẾP-TRỰC-TUYẾN+2024",
            "course-v1:SKILLOURFUTURE+4--THAM-GIA-AN-TOÀN-VÀ-CÓ-TR+2024",
            "course-v1:SKILLOURFUTURE+5--TẠO-NỘI-DUNG-KỸ-THUẬT-SỐ+2024",
            "course-v1:SKILLOURFUTURE+6--CỘNG-TÁC-VÀ-QUẢN-LÝ-NỘI-D+2024",
            "course-v1:SKILLOURFUTURE+KHUNG-ĐÁNH-GIÁ-NĂNG-LỰC-SỐ-CHO+2024",
            "course-v1:SKILLOURFUTURE+TẠO-TRANG-WEB-VỚI-ỨNG-DỤNG-WIX+2024",
            "course-v1:SKILLOURFUTURE+THIẾT-KẾ-HÌNH-ẢNH-VỚI-CÔNG-CỤ+2024"
        ]
    },
    "22": {
        "program_name": "TEST Virtual Assistant",
        "program_subtitle": "Test program for Virtual Assistant pathway",
        "program_type": "Certificate",
        "marketing_slug": "test-virtual-assistant",
        "status": "unpublished",
        "certificate_enabled": False,
        "courses": [
            "course-v1:SKILLOURFUTURE+1-WHAT-IS-VIRTUAL-ASSISTANT?+2024",
            "course-v1:SKILLOURFUTURE+TEST+2024"
        ]
    },
    "23": {
        "program_name": "Embark on a Green Jobs Journey",
        "program_subtitle": "Learn about sustainable careers and green jobs",
        "program_type": "Professional Certificate",
        "marketing_slug": "embark-on-a-green-jobs-journey",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+(CHINESE)-YOUR-FUTURE-IN-GREEN+2024",
            "course-v1:SKILLOURFUTURE+1-SPOT-THE-CHALLENGE+2024",
            "course-v1:SKILLOURFUTURE+2-LISTEN-TO-YOURSELF+2024",
            "course-v1:SKILLOURFUTURE+3-FIND-YOUR-PATH+2024",
            "course-v1:SKILLOURFUTURE+4-CONSIDER-THE-BIGGER-PICTUR+2024",
            "course-v1:SKILLOURFUTURE+5-UNLOCK-YOUR-INNER-ENTREPRE+2024",
            "course-v1:SKILLOURFUTURE+6-BUILD-YOUR-GREEN-CAREER+2024"
        ]
    },
    "24": {
        "program_name": "Employability",
        "program_subtitle": "Skills for job readiness and career development",
        "program_type": "XSeries",
        "marketing_slug": "employability",
        "status": "active",
        "certificate_enabled": False,
        "courses": [
            "course-v1:SKILLOURFUTURE+BUILDING-A-STANDOUT-CV-FOR-CAR+2024",
            "course-v1:SKILLOURFUTURE+DIGITAL-BRANDING-&-EMPLOYABILI+2024",
            "course-v1:SKILLOURFUTURE+GREEN-JOBS-&-SUSTAINABILITY-CA+2024",
            "course-v1:SKILLOURFUTURE+HOW-TO-FIND-YOUR-DREAM-JOB+2024",
            "course-v1:SKILLOURFUTURE+MASTERING-THE-ART-OF-INTERVIEW+2024",
            "course-v1:SKILLOURFUTURE+PERSONAL-BRANDING-THROUGH-LINK+2024",
            "course-v1:SKILLOURFUTURE+XU-HƯỚNG-VIỆC-LÀM-XANH-DÀNH-CH+2024"
        ]
    },
    "25": {
        "program_name": "Speak with Impact",
        "program_subtitle": "Master public speaking and storytelling as your most powerful tools.",
        "program_type": "Professional Certificate",
        "marketing_slug": "speak-with-impact",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+0-WELCOME--THIS-IS-NOT-YOUR+2024",
            "course-v1:SKILLOURFUTURE+1-OVERCOME-YOUR-FEAR-OF-PUBL+2024",
            "course-v1:SKILLOURFUTURE+2-THE-SECRET-TO-IMPACTFUL-CO+2024",
            "course-v1:SKILLOURFUTURE+3-POWERFUL-PRESENTATION-SKIL+2024",
            "course-v1:SKILLOURFUTURE+4-MASTER-THE-ART-OF-STORYTEL+2024",
            "course-v1:SKILLOURFUTURE+5-ELEVATE-YOUR-STAGE-PRESENC+2024",
            "course-v1:SKILLOURFUTURE+6-OWN-YOUR-VOICE-AS-A-WAY-OF+2024",
            "course-v1:SKILLOURFUTURE+7-PUBLIC-SPEAKING-FOR-ADVOCA+2024",
            "course-v1:SKILLOURFUTURE+8-PUBLIC-SPEAKING-FOR-BRANDI+2024",
            "course-v1:SKILLOURFUTURE+9-PUBLIC-SPEAKING-FOR-YOUNG+2024"
        ]
    },
    "26": {
        "program_name": "Become An Entrepreneur",
        "program_subtitle": "Develop entrepreneurial mindset and build your business",
        "program_type": "Professional Certificate",
        "marketing_slug": "become-an-entrepreneur",
        "status": "active",
        "certificate_enabled": True,
        "courses": [
            "course-v1:SKILLOURFUTURE+INTRO-ENTREPRENEURIAL-MYTHS+2024",
            "course-v1:SKILLOURFUTURE+1-START-WITH-WHAT-MATTERS+2024",
            "course-v1:SKILLOURFUTURE+2-FROM-PROBLEMS-TO-POSSIBILI+2024",
            "course-v1:SKILLOURFUTURE+3-MARKET-TESTING-FOR-YOUR-ID+2024",
            "course-v1:SKILLOURFUTURE+4-STORYTELLING-YOUR-PROTOTYP+2024",
            "course-v1:SKILLOURFUTURE+5-BUILDING-A-TEAM-THAT-CAN-B+2024",
            "course-v1:SKILLOURFUTURE+6-FINDING-AVAILABLE-SUPPORT+2024",
            "course-v1:SKILLOURFUTURE+WRAP-UP-CLAIM-YOUR-CERTIFICA+2024"
        ]
    }
}

# Programs with no courses - create as drafts
EMPTY_PROGRAMS = {
    "19": {
        "program_name": "X - Certification QA Testing",
        "program_subtitle": "QA Testing pathway",
        "program_type": "Professional Certificate",
        "marketing_slug": "x--certification-qa-testing",
        "status": "unpublished",
        "certificate_enabled": True,
        "courses": []
    },
    "20": {
        "program_name": "QA Testing Certificate | Common",
        "program_subtitle": "QA Testing common pathway",
        "program_type": "Professional Certificate",
        "marketing_slug": "qa-testing-certificate-common",
        "status": "unpublished",
        "certificate_enabled": True,
        "courses": []
    }
}

# Combine all programs
ALL_PROGRAMS = {**PROGRAMS_DATA, **EMPTY_PROGRAMS}

# Program type mapping
PROGRAM_TYPE_SLUGS = {
    "Professional Certificate": "professional-certificate",
    "XSeries": "xseries",
    "Certificate": "certificate",
    "MicroMasters": "micromasters"
}

# Status mapping
STATUS_MAP = {
    "active": "active",
    "draft": "unpublished",
    "unpublished": "unpublished"
}


def get_or_create_partner():
    """Get or create Skill Our Future partner."""
    partner, created = Partner.objects.get_or_create(
        short_code="sof",
        defaults={
            "name": "Skill Our Future",
            "site_id": 1  # Default site
        }
    )
    if created:
        print(f"✓ Created Partner: {partner.name} (short_code: sof)")
    else:
        print(f"• Partner exists: {partner.name}")
    return partner


def get_or_create_organization(partner):
    """Get or create Skill Our Future organization."""
    org, created = Organization.objects.get_or_create(
        key="SKILLOURFUTURE",
        partner=partner,
        defaults={
            "name": "Skill Our Future",
            "description": "Skill Our Future Learning Platform"
        }
    )
    if created:
        print(f"✓ Created Organization: {org.name}")
    else:
        print(f"• Organization exists: {org.name}")
    return org


def get_program_type(type_name):
    """Get program type by name."""
    slug = PROGRAM_TYPE_SLUGS.get(type_name, "professional-certificate")
    try:
        return ProgramType.objects.get(slug=slug)
    except ProgramType.DoesNotExist:
        print(f"⚠ ProgramType '{slug}' not found, trying translations...")
        # Try finding by translated name
        pt = ProgramType.objects.filter(translations__name_t=type_name).first()
        if pt:
            return pt
        # Create if doesn't exist
        pt = ProgramType.objects.create(slug=slug)
        pt.set_current_language('en')
        pt.name_t = type_name
        pt.save()
        print(f"✓ Created ProgramType: {type_name}")
        return pt


def find_course(course_key):
    """Find course by key in Discovery."""
    try:
        return Course.objects.get(key=course_key)
    except Course.DoesNotExist:
        return None


def create_programs():
    """Create all MCT programs."""
    print("\n" + "="*60)
    print("MCT Programs Creation - Django ORM")
    print("="*60)

    # Setup prerequisites
    partner = get_or_create_partner()
    org = get_or_create_organization(partner)

    programs_created = 0
    programs_updated = 0
    courses_linked = 0
    courses_missing = 0

    print(f"\n--- Creating {len(ALL_PROGRAMS)} Programs ---\n")

    for _mct_id, prog_data in ALL_PROGRAMS.items():
        program_type = get_program_type(prog_data["program_type"])
        slug = prog_data["marketing_slug"]
        status = STATUS_MAP.get(prog_data.get("status", "active"), "active")

        # Check if program exists
        existing = Program.objects.filter(marketing_slug=slug).first()

        if existing:
            print(f"• Program exists: {prog_data['program_name']} ({slug})")
            program = existing
            programs_updated += 1
        else:
            # Create new program
            program = Program.objects.create(
                title=prog_data["program_name"],
                subtitle=prog_data.get("program_subtitle", ""),
                marketing_slug=slug,
                type=program_type,
                partner=partner,
                status=status
            )
            print(f"✓ Created: {prog_data['program_name']} ({slug})")
            programs_created += 1

        # Add organization
        if org not in program.authoring_organizations.all():
            program.authoring_organizations.add(org)

        # Link courses
        for course_key in prog_data.get("courses", []):
            course = find_course(course_key)
            if course:
                if course not in program.courses.all():
                    program.courses.add(course)
                    courses_linked += 1
            else:
                courses_missing += 1
                # print(f"  ⚠ Course not found: {course_key}")

        program.save()

    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"Programs created: {programs_created}")
    print(f"Programs updated: {programs_updated}")
    print(f"Courses linked:   {courses_linked}")
    print(f"Courses missing:  {courses_missing}")
    print("="*60)

    # List all programs
    print("\nAll Programs in Discovery:")
    for p in Program.objects.all():
        print(f"  - {p.title} ({p.marketing_slug}) - {p.courses.count()} courses")


if __name__ == "__main__":
    with transaction.atomic():
        create_programs()
