#!/usr/bin/env python
"""
Programs creation via raw SQL to bypass Celery signals.
"""
import os
import sys
import uuid
from datetime import datetime

sys.path.insert(0, '/openedx/discovery')
os.chdir('/openedx/discovery')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'course_discovery.settings.production')

import django

django.setup()

from django.db import connection

print("=" * 60)
print("MCT Programs Creation - Raw SQL")
print("=" * 60)

cursor = connection.cursor()

# Get partner_id for 'sof'
cursor.execute("SELECT id FROM core_partner WHERE short_code = 'sof'")
row = cursor.fetchone()
if row:
    partner_id = row[0]
    print(f"Partner ID: {partner_id}")
else:
    print("ERROR: Partner 'sof' not found")
    sys.exit(1)

# Check if organization exists
cursor.execute("SELECT id FROM course_metadata_organization WHERE `key` = 'SKILLOURFUTURE' AND partner_id = %s", [partner_id])
row = cursor.fetchone()
if row:
    org_id = row[0]
    print(f"Organization ID: {org_id} (exists)")
else:
    # Create organization
    org_uuid = uuid.uuid4().hex
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute("""
        INSERT INTO course_metadata_organization
        (uuid, created, modified, `key`, name, description, partner_id, logo_image_url, banner_image_url, certificate_logo_image_url)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, [org_uuid, now, now, 'SKILLOURFUTURE', 'Skill Our Future', 'MCT Migration', partner_id, '', '', ''])
    connection.commit()
    cursor.execute("SELECT id FROM course_metadata_organization WHERE `key` = 'SKILLOURFUTURE' AND partner_id = %s", [partner_id])
    org_id = cursor.fetchone()[0]
    print(f"Organization ID: {org_id} (created)")

# Get or create ProgramTypes
def get_or_create_program_type(slug, name):
    cursor.execute("SELECT id FROM course_metadata_programtype WHERE slug = %s", [slug])
    row = cursor.fetchone()
    if row:
        return row[0]
    # Create
    pt_uuid = uuid.uuid4().hex
    now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute("""
        INSERT INTO course_metadata_programtype (uuid, created, modified, slug, logo_image, name, coaching_supported)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, [pt_uuid, now, now, slug, '', name, False])
    connection.commit()
    cursor.execute("SELECT id FROM course_metadata_programtype WHERE slug = %s", [slug])
    pt_id = cursor.fetchone()[0]
    return pt_id

print("\nCreating ProgramTypes...")
type_ids = {}
for slug, name in [('professional-certificate', 'Professional Certificate'), ('xseries', 'XSeries'), ('certificate', 'Certificate')]:
    type_ids[slug] = get_or_create_program_type(slug, name)
    print(f"  ProgramType: {slug} -> ID {type_ids[slug]}")

# Programs data
PROGRAMS = [
    ("Project Manager", "professional-certificate", "project-manager", "active"),
    ("Data Analyst", "professional-certificate", "data-analyst", "active"),
    ("Developer", "professional-certificate", "developer", "active"),
    ("Administrative Professional", "professional-certificate", "administrative-professional", "active"),
    ("Digital Marketer", "professional-certificate", "digital-marketer", "active"),
    ("Mastering Digital Tools", "xseries", "mastering-digital-tools", "active"),
    ("TEST Virtual Assistant", "certificate", "test-virtual-assistant", "unpublished"),
    ("Embark on a Green Jobs Journey", "professional-certificate", "embark-on-a-green-jobs-journey", "active"),
    ("Employability", "xseries", "employability", "active"),
    ("Speak with Impact", "professional-certificate", "speak-with-impact", "active"),
    ("Become An Entrepreneur", "professional-certificate", "become-an-entrepreneur", "active"),
    ("X - Certification QA Testing", "professional-certificate", "x--certification-qa-testing", "unpublished"),
    ("QA Testing Certificate | Common", "professional-certificate", "qa-testing-certificate-common", "unpublished"),
]

print("\n" + "-" * 60)
print("Creating Programs...")
print("-" * 60)

created_count = 0
exists_count = 0

for title, type_slug, marketing_slug, status in PROGRAMS:
    type_id = type_ids[type_slug]

    # Check if exists
    cursor.execute("SELECT id FROM course_metadata_program WHERE marketing_slug = %s", [marketing_slug])
    row = cursor.fetchone()

    if row:
        program_id = row[0]
        exists_count += 1
        print(f"  = Exists: {title} (ID: {program_id})")
    else:
        # Create program
        prog_uuid = uuid.uuid4().hex
        now = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        cursor.execute("""
            INSERT INTO course_metadata_program
            (uuid, created, modified, title, marketing_slug, status, partner_id, type_id,
             subtitle, overview, banner_image_url, card_image_url,
             order_courses_by_start_date, one_click_purchase_enabled, hidden,
             marketing_hook, credit_value, credit_redemption_overview,
             organization_short_code_override, enterprise_subscription_inclusion)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, [prog_uuid, now, now, title, marketing_slug, status, partner_id, type_id,
              '', '', '', '', True, False, False, '', 0, '', '', False])
        connection.commit()
        cursor.execute("SELECT id FROM course_metadata_program WHERE marketing_slug = %s", [marketing_slug])
        program_id = cursor.fetchone()[0]
        created_count += 1
        print(f"  + Created: {title} (ID: {program_id})")

    # Link organization to program (many-to-many)
    cursor.execute("""
        INSERT IGNORE INTO course_metadata_program_authoring_organizations (program_id, organization_id)
        VALUES (%s, %s)
    """, [program_id, org_id])
    connection.commit()

print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"Programs created: {created_count}")
print(f"Programs existed: {exists_count}")

# Count total
cursor.execute("SELECT COUNT(*) FROM course_metadata_program")
total = cursor.fetchone()[0]
print(f"Total programs: {total}")
print("=" * 60)

# List all
print("\nAll Programs:")
cursor.execute("SELECT title, status, marketing_slug FROM course_metadata_program ORDER BY title")
for row in cursor.fetchall():
    print(f"  - {row[0]} ({row[1]})")

cursor.close()
