#!/usr/bin/env bash
# Export enrollments from Open edX via Tutor
#
# Usage:
#   ./tools/openedx-export-enrollments.sh [output_file.csv]
#
# Output: CSV with columns: email,username,course_id,enrollment_date,is_active

set -euo pipefail

OUTPUT_FILE="${1:-exports/openedx/enrollments.csv}"
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

echo "Exporting enrollments from Open edX..."

# Export enrollments via Django management command
tutor local run lms ./manage.py lms dump_enrollments --output "$OUTPUT_FILE" \
  --settings=tutor.production 2>/dev/null || {
  # Fallback: Use SQL query if dump_enrollments doesn't exist
  echo "Using SQL query fallback..."
  tutor local run lms ./manage.py lms shell --settings=tutor.production <<'PYTHON' > "$OUTPUT_FILE"
import csv
import sys
from django.contrib.auth.models import User
from student.models import CourseEnrollment

writer = csv.writer(sys.stdout)
writer.writerow(['email', 'username', 'course_id', 'enrollment_date', 'is_active'])

for enrollment in CourseEnrollment.objects.select_related('user').all():
    writer.writerow([
        enrollment.user.email,
        enrollment.user.username,
        str(enrollment.course_id),
        enrollment.created.isoformat() if enrollment.created else '',
        'True' if enrollment.is_active else 'False'
    ])
PYTHON
}

echo "✓ Enrollments exported to: $OUTPUT_FILE"
wc -l "$OUTPUT_FILE"



