#!/bin/bash
# Complete verification and sync pipeline for Kajabi → Open edX
# Run this script step by step or all at once

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

OUTPUT_DIR="scripts/migrations/kajabi/output/verification"
VERIFICATION_SCRIPT="scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py"

echo "============================================================"
echo "Kajabi → Open edX Verification & Sync Pipeline"
echo "============================================================"
echo

# Step 1: Export from Open edX
echo "STEP 1: Exporting from Open edX..."
echo "-----------------------------------"

if command -v tutor &> /dev/null || [ -f "ops/tutor-env.sh" ]; then
    echo "Attempting to export via Tutor/Django..."
    
    if [ -f "ops/tutor-env.sh" ]; then
        source infrastructure/tutor/tutor-env.sh
    fi
    
    # Try to export enrollments
    if command -v tutor &> /dev/null; then
        echo "Exporting enrollments via Tutor..."
        tutor local run lms ./manage.py lms shell --settings=tutor.production <<'PYTHON' > "$OUTPUT_DIR/openedx_enrollments.csv" 2>/dev/null || true
import csv
import sys
from django.contrib.auth.models import User
from student.models import CourseEnrollment

writer = csv.writer(sys.stdout)
writer.writerow(['email', 'username', 'course_id', 'enrollment_date', 'is_active'])

for enrollment in CourseEnrollment.objects.select_related('user').all():
    writer.writerow([
        enrollment.user.email or '',
        enrollment.user.username,
        str(enrollment.course_id),
        enrollment.created.isoformat() if enrollment.created else '',
        'True' if enrollment.is_active else 'False'
    ])
PYTHON
        
        echo "Exporting certificates via Tutor..."
        tutor local run lms ./manage.py lms shell --settings=tutor.production <<'PYTHON' > "$OUTPUT_DIR/openedx_certificates.csv" 2>/dev/null || true
import csv
import sys
from django.contrib.auth.models import User
try:
    from certificates.models import GeneratedCertificate
except ImportError:
    try:
        from lms.djangoapps.certificates.models import GeneratedCertificate
    except ImportError:
        from common.djangoapps.certificates.models import GeneratedCertificate

writer = csv.writer(sys.stdout)
writer.writerow(['email', 'username', 'course_id', 'status', 'created_date', 'modified_date', 'grade', 'mode'])

for cert in GeneratedCertificate.objects.select_related('user').all():
    writer.writerow([
        cert.user.email if cert.user else '',
        cert.user.username if cert.user else '',
        str(cert.course_id) if cert.course_id else '',
        cert.status or '',
        cert.created_date.isoformat() if cert.created_date else '',
        cert.modified_date.isoformat() if cert.modified_date else '',
        str(cert.grade) if cert.grade is not None else '',
        cert.mode or '',
    ])
PYTHON
        
        if [ -f "$OUTPUT_DIR/openedx_enrollments.csv" ] && [ -s "$OUTPUT_DIR/openedx_enrollments.csv" ]; then
            echo "✓ Exported enrollments: $(wc -l < "$OUTPUT_DIR/openedx_enrollments.csv" | tr -d ' ') lines"
        fi
        
        if [ -f "$OUTPUT_DIR/openedx_certificates.csv" ] && [ -s "$OUTPUT_DIR/openedx_certificates.csv" ]; then
            echo "✓ Exported certificates: $(wc -l < "$OUTPUT_DIR/openedx_certificates.csv" | tr -d ' ') lines"
        fi
    else
        echo "⚠ Tutor command not found - skipping Open edX export"
        echo "  You can export manually or provide database credentials"
    fi
else
    echo "⚠ Tutor not available - skipping Open edX export"
    echo "  To export manually, see: docs/VERIFY_AND_SYNC_KAJABI.md"
fi

echo

# Step 2: Run verification
echo "STEP 2: Running verification..."
echo "--------------------------------"

python3 "$VERIFICATION_SCRIPT" \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir "$OUTPUT_DIR" \
  --skip-openedx-export

echo

# Step 3: Show summary
echo "STEP 3: Summary Report"
echo "--------------------------------"
if [ -f "$OUTPUT_DIR/summary.txt" ]; then
    cat "$OUTPUT_DIR/summary.txt"
fi

echo
echo "============================================================"
echo "✓ Verification complete!"
echo "============================================================"
echo
echo "Next steps:"
echo "1. Review reports in: $OUTPUT_DIR"
echo "2. Import missing enrollments: $OUTPUT_DIR/import_missing_enrollments.sh"
echo "3. Generate certificates: See $OUTPUT_DIR/generate_missing_certificates.sh"
echo




