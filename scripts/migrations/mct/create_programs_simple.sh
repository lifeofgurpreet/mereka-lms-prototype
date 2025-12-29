#!/bin/bash
set -euo pipefail

# Simple script to create programs one by one using kubectl exec

DISCOVERY_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery -o jsonpath='{.items[0].metadata.name}')

echo "Using Discovery pod: $DISCOVERY_POD"

# First, create the necessary program types
echo "Creating ProgramTypes..."
kubectl exec -n mereka-lms "$DISCOVERY_POD" -- python manage.py shell -c "
from course_discovery.apps.course_metadata.models import ProgramType
import json

types = [
    ('professional-certificate', 'Professional Certificate', ['verified', 'professional']),
    ('xseries', 'XSeries', ['verified']),
    ('certificate', 'Certificate', ['verified']),
]

for slug, name, seat_types in types:
    pt, created = ProgramType.objects.get_or_create(
        slug=slug,
        defaults={
            'name': name,
            'applicable_seat_types': json.dumps(seat_types),
        }
    )
    print(f\"{'Created' if created else 'Found'} ProgramType: {name}\")
" 2>&1 | grep -v "UserWarning\|django-fsm"

# Create Partner and Organizations
echo "Creating Partner and Organizations..."
kubectl exec -n mereka-lms "$DISCOVERY_POD" -- python manage.py shell -c "
from course_discovery.apps.course_metadata.models import Partner, Organization

# Create partner
partner, created = Partner.objects.get_or_create(
    short_code='skillourfuture',
    defaults={'name': 'Skill Our Future'}
)
print(f\"{'Created' if created else 'Found'} Partner: {partner.name}\")

# Create organizations
for org_name in ['Default', 'Indonesia', 'Vietnam', 'Philippines']:
    org_key = org_name.upper().replace(' ', '')
    org, created = Organization.objects.get_or_create(
        key=org_key,
        defaults={'name': org_name, 'auto_create_in_studio': True}
    )
    print(f\"{'Created' if created else 'Found'} Organization: {org.name}\")
" 2>&1 | grep -v "UserWarning\|django-fsm"

echo ""
echo "Setup prerequisites complete!"
echo ""
echo "Now you can create individual programs using the create_program function."
echo "See the programs_mapping.json for the 13 programs to create."
