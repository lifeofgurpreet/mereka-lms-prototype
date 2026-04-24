#!/usr/bin/env python3
"""
Set up 13 Programs (Learning Pathways) in Open edX Discovery service for MCT migration.

This script:
1. Creates necessary ProgramTypes, Partners, and Organizations
2. Creates 13 Programs based on the programs_mapping.json
3. Links courses to programs
4. Configures program settings (status, certificates, etc.)

Usage:
    python setup_discovery_programs.py
"""

import json
from pathlib import Path

# This script is designed to be executed inside the Discovery pod using kubectl exec

DJANGO_SHELL_SCRIPT = """
import sys
from course_discovery.apps.course_metadata.models import (
    Program, ProgramType, Partner, Organization, Course
)
from opaque_keys.edx.keys import CourseKey

def setup_program_types():
    '''Create required program types.'''
    types_to_create = {
        'professional-certificate': {
            'name': 'Professional Certificate',
            'applicable_seat_types': ['verified', 'professional'],
            'slug': 'professional-certificate',
        },
        'xseries': {
            'name': 'XSeries',
            'applicable_seat_types': ['verified'],
            'slug': 'xseries',
        },
        'certificate': {
            'name': 'Certificate',
            'applicable_seat_types': ['verified'],
            'slug': 'certificate',
        },
    }

    created_types = {}
    for slug, data in types_to_create.items():
        prog_type, created = ProgramType.objects.get_or_create(
            slug=slug,
            defaults=data
        )
        created_types[slug] = prog_type
        print(f"{'Created' if created else 'Found'} ProgramType: {prog_type.name}")

    return created_types

def setup_partner_and_orgs():
    '''Create partner and organizations.'''
    # Create partner
    partner, created = Partner.objects.get_or_create(
        short_code='skillourfuture',
        defaults={
            'name': 'Skill Our Future',
            'site_id': 1,  # Default site
        }
    )
    print(f"{'Created' if created else 'Found'} Partner: {partner.name}")

    # Create organizations
    orgs = {}
    org_names = ['Default', 'Indonesia', 'Vietnam', 'Philippines']

    for org_name in org_names:
        org_key = org_name.upper().replace(' ', '')
        org, created = Organization.objects.get_or_create(
            key=org_key,
            defaults={
                'name': org_name,
                'auto_create_in_studio': True,
            }
        )
        orgs[org_name] = org
        print(f"{'Created' if created else 'Found'} Organization: {org.name} ({org.key})")

    return partner, orgs

def create_program(program_data, partner, orgs, program_types):
    '''Create a single program.'''

    # Map program type name to slug
    type_map = {
        'Professional Certificate': 'professional-certificate',
        'XSeries': 'xseries',
        'Certificate': 'certificate',
    }

    type_slug = type_map.get(program_data['program_type'], 'xseries')
    program_type = program_types[type_slug]

    # Get organization
    org_name = program_data.get('organization', 'Default')
    organization = orgs.get(org_name, orgs['Default'])

    # Create program
    program, created = Program.objects.get_or_create(
        marketing_slug=program_data['marketing_slug'],
        defaults={
            'title': program_data['program_name'],
            'subtitle': program_data.get('program_subtitle', ''),
            'overview': program_data.get('description', '') or program_data.get('program_subtitle', ''),
            'type': program_type,
            'partner': partner,
            'status': program_data.get('status', 'active'),
            'hidden': program_data.get('status') != 'active',
        }
    )

    if created:
        # Add authoring organization
        program.authoring_organizations.add(organization)
        print(f"✓ Created Program: {program.title}")
        print(f"  UUID: {program.uuid}")
        print(f"  Slug: {program.marketing_slug}")
        print(f"  Type: {program.type.name}")
        print(f"  Status: {program.status}")
    else:
        print(f"Program already exists: {program.title}")
        # Update if needed
        updated = False
        if program.title != program_data['program_name']:
            program.title = program_data['program_name']
            updated = True
        if program.subtitle != program_data.get('program_subtitle', ''):
            program.subtitle = program_data.get('program_subtitle', '')
            updated = True
        if updated:
            program.save()
            print(f"  Updated program details")

    # Add courses to program
    added_courses = 0
    not_found_courses = []

    for course_data in program_data.get('courses', []):
        course_key_str = course_data['openedx_course_key']
        try:
            # Find course in Discovery by course key
            # Note: Discovery stores courses with their full course ID
            courses = Course.objects.filter(key=course_key_str)

            if courses.exists():
                course = courses.first()
                if course not in program.courses.all():
                    program.courses.add(course)
                    added_courses += 1
                    print(f"  + Added course: {course_key_str}")
            else:
                not_found_courses.append(course_key_str)
                print(f"  ? Course not found: {course_key_str}")
        except Exception as e:
            print(f"  ! Error adding course {course_key_str}: {e}")
            not_found_courses.append(course_key_str)

    if added_courses > 0:
        program.save()
        print(f"  Added {added_courses} courses to program")

    if not_found_courses:
        print(f"  WARNING: {len(not_found_courses)} courses not found in Discovery")

    return program, created, not_found_courses

def main():
    '''Main setup function.'''

    print("="*80)
    print("Setting up Discovery Programs for MCT Migration")
    print("="*80)

    # Load programs data from the JSON passed as argument
    import os
    programs_json = os.environ.get('PROGRAMS_JSON', '{}')
    programs_data = json.loads(programs_json)

    if not programs_data:
        print("ERROR: No programs data provided")
        sys.exit(1)

    programs = programs_data.get('programs', {})
    print(f"\\nFound {len(programs)} programs to process\\n")

    # Setup prerequisites
    print("Step 1: Setting up ProgramTypes...")
    program_types = setup_program_types()

    print("\\nStep 2: Setting up Partner and Organizations...")
    partner, orgs = setup_partner_and_orgs()

    print("\\nStep 3: Creating Programs...")
    print("="*80)

    # Sort programs by priority
    sorted_programs = sorted(
        programs.items(),
        key=lambda x: x[1].get('priority', 999)
    )

    created_count = 0
    updated_count = 0
    skipped_count = 0
    all_missing_courses = []

    for program_id, program_data in sorted_programs:
        # Skip programs with no courses
        if program_data.get('total_courses', 0) == 0:
            print(f"\\nSkipping {program_data['program_name']} - no courses")
            skipped_count += 1
            continue

        # Skip test programs
        if 'TEST' in program_data['program_name'].upper() or 'QA TESTING' in program_data['program_name'].upper():
            print(f"\\nSkipping test program: {program_data['program_name']}")
            skipped_count += 1
            continue

        print(f"\\n{'-'*80}")
        print(f"Processing Program {program_data.get('priority', '?')}: {program_data['program_name']}")
        print(f"{'-'*80}")

        program, created, missing_courses = create_program(
            program_data, partner, orgs, program_types
        )

        if created:
            created_count += 1
        else:
            updated_count += 1

        if missing_courses:
            all_missing_courses.extend([
                (program_data['program_name'], course)
                for course in missing_courses
            ])

    # Print summary
    print("\\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    print(f"Programs created: {created_count}")
    print(f"Programs updated: {updated_count}")
    print(f"Programs skipped: {skipped_count}")
    print(f"Total missing courses: {len(all_missing_courses)}")

    if all_missing_courses:
        print("\\nMissing courses by program:")
        current_program = None
        for program_name, course in all_missing_courses:
            if program_name != current_program:
                print(f"\\n  {program_name}:")
                current_program = program_name
            print(f"    - {course}")

    print("\\n" + "="*80)
    print("Setup complete!")
    print("="*80)

    # Print verification query
    print("\\nTo verify programs, run:")
    print("  kubectl exec -n mereka-lms discovery-POD -- python manage.py shell")
    print("  >>> from course_discovery.apps.course_metadata.models import Program")
    print("  >>> for p in Program.objects.all():")
    print("  ...     print(f'{p.title}: {p.courses.count()} courses')")

if __name__ == '__main__':
    main()
"""

def main():
    """Execute the setup script in the Discovery pod."""
    import subprocess

    # Load programs data
    programs_file = Path(__file__).parent.parent.parent.parent / "var/migrations/mct/programs_mapping.json"

    if not programs_file.exists():
        print(f"Error: Programs file not found: {programs_file}")
        return 1

    with open(programs_file) as f:
        programs_data = json.load(f)

    # Escape the JSON for shell
    programs_json = json.dumps(programs_data).replace('"', '\\"').replace("'", "'\\''")

    # Find Discovery pod
    result = subprocess.run(
        ['kubectl', 'get', 'pods', '-n', 'mereka-lms', '-l', 'app.kubernetes.io/name=discovery',
         '-o', 'jsonpath={.items[0].metadata.name}'],
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print("Error: Could not find Discovery pod")
        return 1

    discovery_pod = result.stdout.strip()
    print(f"Using Discovery pod: {discovery_pod}")

    # Execute the Django shell script in the Discovery pod
    cmd = [
        'kubectl', 'exec', '-n', 'mereka-lms', discovery_pod, '--',
        'bash', '-c',
        f'PROGRAMS_JSON="{programs_json}" python manage.py shell -c "{DJANGO_SHELL_SCRIPT}"'
    ]

    print("\nExecuting program setup in Discovery pod...")
    print("="*80)

    result = subprocess.run(cmd, capture_output=False, text=True)

    return result.returncode

if __name__ == '__main__':
    import sys
    sys.exit(main())
