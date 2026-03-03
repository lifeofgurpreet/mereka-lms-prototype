#!/usr/bin/env python
"""
Programs creation script for Discovery - v2.
Must be run from /openedx/discovery directory.
"""
import os
import sys

# Add discovery to path
sys.path.insert(0, '/openedx/discovery')
os.chdir('/openedx/discovery')

# Set Celery to eager mode before Django loads
os.environ['CELERY_TASK_ALWAYS_EAGER'] = 'true'
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'course_discovery.settings.production')

import django

django.setup()

# Now patch celery
from celery import current_app

current_app.conf.task_always_eager = True

from course_discovery.apps.core.models import Partner
from course_discovery.apps.course_metadata.models import Organization, Program, ProgramType
from django.contrib.sites.models import Site

print("=" * 60)
print("MCT Programs Creation - v2")
print("=" * 60)

# Get partner
partner = Partner.objects.filter(short_code='sof').first()
if partner:
    print(f"Partner: {partner.name} (exists)")
else:
    site = Site.objects.first()
    partner = Partner.objects.create(short_code='sof', name='Skill Our Future', site=site)
    print(f"Partner: {partner.name} (created)")

# Create organization
try:
    org = Organization.objects.get(key='SKILLOURFUTURE', partner=partner)
    print(f"Organization: {org.name} (exists)")
except Organization.DoesNotExist:
    org = Organization(
        key='SKILLOURFUTURE',
        partner=partner,
        name='Skill Our Future',
        description='MCT Migration'
    )
    # Save without triggering signals
    org.save(update_fields=None)
    print(f"Organization: {org.name} (created)")

# Create ProgramTypes
types_data = [
    ('professional-certificate', 'Professional Certificate'),
    ('xseries', 'XSeries'),
    ('certificate', 'Certificate')
]

for slug, name in types_data:
    pt, created = ProgramType.objects.get_or_create(slug=slug)
    if created:
        pt.set_current_language('en')
        pt.name_t = name
        pt.save()
    print(f"ProgramType: {slug} ({'created' if created else 'exists'})")

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
    program_type = ProgramType.objects.get(slug=type_slug)

    try:
        prog = Program.objects.get(marketing_slug=marketing_slug)
        exists_count += 1
        print(f"  = Exists: {title}")
    except Program.DoesNotExist:
        prog = Program(
            title=title,
            marketing_slug=marketing_slug,
            partner=partner,
            type=program_type,
            status=status
        )
        prog.save()
        created_count += 1
        print(f"  + Created: {title}")

    # Add organization
    if org not in prog.authoring_organizations.all():
        prog.authoring_organizations.add(org)

print("\n" + "=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"Programs created: {created_count}")
print(f"Programs existed: {exists_count}")
print(f"Total programs: {Program.objects.count()}")
print("=" * 60)

# List all
print("\nAll Programs:")
for p in Program.objects.all():
    print(f"  - {p.title} ({p.status})")
