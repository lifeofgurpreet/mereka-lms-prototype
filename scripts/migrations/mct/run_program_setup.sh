#!/usr/bin/env bash
set -euo pipefail

# Script to setup Discovery Programs for MCT migration
# This script copies the Django script to the Discovery pod and executes it

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRAMS_FILE="${SCRIPT_DIR}/../../../var/migrations/mct/programs_mapping.json"
DJANGO_SCRIPT="${SCRIPT_DIR}/setup_programs_django.py"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================"
echo "Discovery Programs Setup"
echo "================================${NC}"

# Check if programs file exists
if [ ! -f "$PROGRAMS_FILE" ]; then
  echo -e "${RED}Error: Programs file not found: $PROGRAMS_FILE${NC}"
  exit 1
fi

# Check if Django script exists
if [ ! -f "$DJANGO_SCRIPT" ]; then
  echo -e "${RED}Error: Django script not found: $DJANGO_SCRIPT${NC}"
  exit 1
fi

# Find Discovery pod
echo "Finding Discovery pod..."
DISCOVERY_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery \
  -o jsonpath='{.items[0].metadata.name}')

if [ -z "$DISCOVERY_POD" ]; then
  echo -e "${RED}Error: Could not find Discovery pod${NC}"
  exit 1
fi

echo -e "${GREEN}Using Discovery pod: $DISCOVERY_POD${NC}"

# Copy Django script and JSON data to pod
echo "Copying Django script to Discovery pod..."
kubectl cp "$DJANGO_SCRIPT" \
  "mereka-lms/$DISCOVERY_POD:/tmp/setup_programs.py"

echo "Copying programs data to Discovery pod..."
kubectl cp "$PROGRAMS_FILE" \
  "mereka-lms/$DISCOVERY_POD:/tmp/programs.json"

# Execute the script
echo -e "${GREEN}Executing program setup...${NC}"
echo "========================================"

# Create a wrapper script that reads from stdin and passes to the main script
kubectl exec -i -n mereka-lms "$DISCOVERY_POD" -- bash -c "
python manage.py shell << 'EOFPYTHON'
import sys
# Read JSON from /tmp/programs.json
with open('/tmp/programs.json', 'r') as f:
    programs_json = f.read()

sys.stdin = type('obj', (object,), {'read': lambda: programs_json})()

exec(open('/tmp/setup_programs.py').read())
EOFPYTHON
"

RESULT=$?

# Cleanup
echo ""
echo "Cleaning up temporary files..."
kubectl exec -n mereka-lms "$DISCOVERY_POD" -- rm -f /tmp/setup_programs.py /tmp/programs.json

if [ $RESULT -eq 0 ]; then
  echo -e "${GREEN}================================"
  echo "Program setup completed successfully!"
  echo "================================${NC}"

  echo ""
  echo "Verifying programs..."
  kubectl exec -n mereka-lms "$DISCOVERY_POD" -- python manage.py shell -c "
from course_discovery.apps.course_metadata.models import Program
print('\nCreated Programs:')
for p in Program.objects.all().order_by('title'):
    print(f'  - {p.title} ({p.marketing_slug}): {p.courses.count()} courses, Status: {p.status}')
print(f'\nTotal: {Program.objects.count()} programs')
" 2>&1 | grep -A 50 "Created Programs"

else
  echo -e "${RED}================================"
  echo "Program setup failed!"
  echo "================================${NC}"
  exit 1
fi
