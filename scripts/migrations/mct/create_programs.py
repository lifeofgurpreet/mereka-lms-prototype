#!/usr/bin/env python3
"""
Create 13 Programs (Learning Pathways) in Open edX Discovery service for MCT migration.

This script creates programs by directly using Django management commands executed
in the LMS pod, which has proper database connectivity to the shared MySQL database.
"""

import json
import subprocess
import sys
from pathlib import Path

# Load the programs mapping
PROGRAMS_FILE = Path(__file__).parent.parent.parent.parent / "var/migrations/mct/programs_mapping.json"

def run_kubectl_exec(command: str) -> tuple[int, str, str]:
    """Execute a command in the LMS pod."""
    full_cmd = f'kubectl exec -n mereka-lms lms-75c446d865-c77cn -- {command}'
    print(f"Executing: {full_cmd}")

    result = subprocess.run(
        full_cmd,
        shell=True,
        capture_output=True,
        text=True
    )
    return result.returncode, result.stdout, result.stderr


def create_program_via_shell(program_data: dict) -> bool:
    """Create a program using Django shell in LMS pod."""

    # Build Python code to execute
    python_code = f'''
import sys
import django
django.setup()

# Import required models - accessing Discovery models from LMS
from course_discovery.apps.course_metadata.models import Program, ProgramType, Partner, Organization, Course
from opaque_keys.edx.keys import CourseKey

try:
    # Get or create partner
    partner, _ = Partner.objects.get_or_create(
        short_code="{program_data['partner_code']}",
        defaults={{"name": "Skill Our Future"}}
    )

    # Get or create program type
    program_type_map = {{
        "Professional Certificate": "professional-certificate",
        "XSeries": "xseries",
        "Certificate": "certificate"
    }}

    type_slug = program_type_map.get("{program_data['program_type']}", "xseries")
    program_type, _ = ProgramType.objects.get_or_create(
        slug=type_slug,
        defaults={{
            "name": "{program_data['program_type']}",
            "applicable_seat_types": ["verified"]
        }}
    )

    # Get or create organization
    org_name = "{program_data['organization']}"
    organization, _ = Organization.objects.get_or_create(
        key=org_name.upper().replace(" ", ""),
        defaults={{"name": org_name}}
    )

    # Create the program
    program, created = Program.objects.get_or_create(
        marketing_slug="{program_data['marketing_slug']}",
        defaults={{
            "title": "{program_data['program_name']}",
            "subtitle": """{program_data.get('program_subtitle', '')}""",
            "overview": """{program_data.get('description', '')}""",
            "type": program_type,
            "partner": partner,
            "status": "{program_data['status']}",
            "hidden": False
        }}
    )

    if created:
        # Add authoring organization
        program.authoring_organizations.add(organization)

        # Add courses to the program
        course_keys = {json.dumps([course['openedx_course_key'] for course in program_data.get('courses', [])])}
        for course_key_str in course_keys:
            try:
                course_key = CourseKey.from_string(course_key_str)
                # Find the course in Discovery
                courses = Course.objects.filter(key=str(course_key))
                if courses.exists():
                    program.courses.add(courses.first())
                    print(f"Added course: {{course_key_str}}")
                else:
                    print(f"Course not found in Discovery: {{course_key_str}}")
            except Exception as e:
                print(f"Error adding course {{course_key_str}}: {{e}}")

        program.save()
        print(f"✓ Created program: {program_data['program_name']} ({{program.uuid}})")
    else:
        print(f"Program already exists: {program_data['program_name']}")

    sys.exit(0)

except Exception as e:
    print(f"Error: {{e}}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
'''

    # Execute in LMS pod
    code, stdout, stderr = run_kubectl_exec(
        f'python manage.py lms shell -c {repr(python_code)}'
    )

    print(stdout)
    if stderr and 'WARNING' not in stderr:
        print(f"STDERR: {stderr}", file=sys.stderr)

    return code == 0


def main():
    """Main function to create all programs."""

    # Load programs data
    if not PROGRAMS_FILE.exists():
        print(f"Error: Programs file not found: {PROGRAMS_FILE}")
        return 1

    with open(PROGRAMS_FILE) as f:
        programs_data = json.load(f)

    programs = programs_data.get('programs', {})

    print(f"Found {len(programs)} programs to create\n")

    # Create programs in priority order
    sorted_programs = sorted(
        programs.items(),
        key=lambda x: x[1].get('priority', 999)
    )

    success_count = 0
    failed_count = 0

    for _program_id, program_data in sorted_programs:
        # Skip test programs and empty programs
        if program_data.get('total_courses', 0) == 0:
            print(f"Skipping {program_data['program_name']} - no courses")
            continue

        if 'TEST' in program_data['program_name'].upper() or 'QA TESTING' in program_data['program_name'].upper():
            print(f"Skipping test program: {program_data['program_name']}")
            continue

        print(f"\n{'='*80}")
        print(f"Creating Program {program_data['priority']}: {program_data['program_name']}")
        print(f"  Slug: {program_data['marketing_slug']}")
        print(f"  Type: {program_data['program_type']}")
        print(f"  Courses: {program_data['total_courses']}")
        print(f"{'='*80}")

        if create_program_via_shell(program_data):
            success_count += 1
        else:
            failed_count += 1
            print(f"✗ Failed to create: {program_data['program_name']}")

    print(f"\n{'='*80}")
    print("Summary:")
    print(f"  Successfully created: {success_count}")
    print(f"  Failed: {failed_count}")
    print(f"{'='*80}")

    return 0 if failed_count == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
