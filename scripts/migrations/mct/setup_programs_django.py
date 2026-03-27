#!/usr/bin/env python
"""
Django script to create Programs in Discovery.
This script runs inside the Discovery pod.
"""

import json
import sys


def main():
    from course_discovery.apps.course_metadata.models import (
        Course,
        Organization,
        Partner,
        Program,
        ProgramType,
    )

    # Load programs data from stdin or file
    programs_json = sys.stdin.read()
    programs_data = json.loads(programs_json)

    programs = programs_data.get('programs', {})
    print(f"Found {len(programs)} programs to process\n")

    # Step 1: Setup ProgramTypes
    print("Step 1: Setting up ProgramTypes...")
    types_to_create = {
        'professional-certificate': {
            'name': 'Professional Certificate',
            'applicable_seat_types': json.dumps(['verified', 'professional']),
            'slug': 'professional-certificate',
        },
        'xseries': {
            'name': 'XSeries',
            'applicable_seat_types': json.dumps(['verified']),
            'slug': 'xseries',
        },
        'certificate': {
            'name': 'Certificate',
            'applicable_seat_types': json.dumps(['verified']),
            'slug': 'certificate',
        },
    }

    program_types = {}
    for slug, data in types_to_create.items():
        prog_type, created = ProgramType.objects.get_or_create(
            slug=slug,
            defaults=data
        )
        program_types[slug] = prog_type
        print(f"  {'Created' if created else 'Found'} ProgramType: {prog_type.name}")

    # Step 2: Setup Partner and Organizations
    print("\nStep 2: Setting up Partner and Organizations...")
    partner, created = Partner.objects.get_or_create(
        short_code='skillourfuture',
        defaults={'name': 'Skill Our Future'}
    )
    print(f"  {'Created' if created else 'Found'} Partner: {partner.name}")

    orgs = {}
    for org_name in ['Default', 'Indonesia', 'Vietnam', 'Philippines']:
        org_key = org_name.upper().replace(' ', '')
        org, created = Organization.objects.get_or_create(
            key=org_key,
            defaults={'name': org_name, 'auto_create_in_studio': True}
        )
        orgs[org_name] = org
        print(f"  {'Created' if created else 'Found'} Organization: {org.name}")

    # Step 3: Create Programs
    print("\nStep 3: Creating Programs...")
    print("="*80)

    type_map = {
        'Professional Certificate': 'professional-certificate',
        'XSeries': 'xseries',
        'Certificate': 'certificate',
    }

    sorted_programs = sorted(
        programs.items(),
        key=lambda x: x[1].get('priority', 999)
    )

    created_count = 0
    updated_count = 0
    skipped_count = 0

    for _program_id, program_data in sorted_programs:
        # Skip programs with no courses or test programs
        if program_data.get('total_courses', 0) == 0:
            print(f"\nSkipping {program_data['program_name']} - no courses")
            skipped_count += 1
            continue

        if 'TEST' in program_data['program_name'].upper():
            print(f"\nSkipping test program: {program_data['program_name']}")
            skipped_count += 1
            continue

        print(f"\n{'-'*80}")
        print(f"Program {program_data.get('priority', '?')}: {program_data['program_name']}")
        print(f"{'-'*80}")

        type_slug = type_map.get(program_data['program_type'], 'xseries')
        program_type = program_types[type_slug]

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
            program.authoring_organizations.add(organization)
            print(f"✓ Created Program: {program.title}")
            print(f"  UUID: {program.uuid}")
            print(f"  Slug: {program.marketing_slug}")
            print(f"  Type: {program.type.name}")
            created_count += 1
        else:
            print(f"Program exists: {program.title}")
            updated_count += 1

        # Add courses
        added = 0
        missing = []
        for course_data in program_data.get('courses', []):
            course_key = course_data['openedx_course_key']
            try:
                courses = Course.objects.filter(key=course_key)
                if courses.exists():
                    course = courses.first()
                    if course not in program.courses.all():
                        program.courses.add(course)
                        added += 1
                        print(f"  + Added course: {course_key}")
                else:
                    missing.append(course_key)
                    print(f"  ? Not found: {course_key}")
            except Exception as e:
                print(f"  ! Error: {course_key}: {e}")
                missing.append(course_key)

        if added > 0:
            program.save()
            print(f"  Added {added} courses")

        if missing:
            print(f"  WARNING: {len(missing)} courses not in Discovery")

    # Summary
    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    print(f"Programs created: {created_count}")
    print(f"Programs updated: {updated_count}")
    print(f"Programs skipped: {skipped_count}")
    print("="*80)

if __name__ == '__main__':
    main()
