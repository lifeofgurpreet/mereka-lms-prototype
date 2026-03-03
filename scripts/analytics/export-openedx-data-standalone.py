#!/usr/bin/env python3
"""
Standalone script to export Open edX enrollments and certificates.
Can be copied into LMS container and run directly.
"""
import csv
import os
import sys

# Set Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lms.envs.tutor.production')

import django

django.setup()

from common.djangoapps.student.models import CourseEnrollment

try:
    from certificates.models import GeneratedCertificate
except ImportError:
    try:
        from lms.djangoapps.certificates.models import GeneratedCertificate
    except ImportError:
        from common.djangoapps.certificates.models import GeneratedCertificate

def export_enrollments(output_path):
    """Export all enrollments to CSV."""
    enrollments = CourseEnrollment.objects.select_related('user').all()
    count = enrollments.count()
    print(f"Exporting {count} enrollments...", file=sys.stderr)

    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['email', 'username', 'course_id', 'enrollment_date', 'is_active'])

        total = 0
        for e in enrollments:
            writer.writerow([
                e.user.email or '',
                e.user.username,
                str(e.course_id),
                e.created.isoformat() if e.created else '',
                'True' if e.is_active else 'False'
            ])
            total += 1
            if total % 10000 == 0:
                print(f"  Exported {total}/{count}...", file=sys.stderr)

    print(f"✓ Exported {total} enrollments to {output_path}", file=sys.stderr)
    return total

def export_certificates(output_path):
    """Export all certificates to CSV."""
    certs = GeneratedCertificate.objects.select_related('user').all()
    count = certs.count()
    print(f"Exporting {count} certificates...", file=sys.stderr)

    with open(output_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['email', 'username', 'course_id', 'status', 'created_date', 'modified_date', 'grade', 'mode'])

        total = 0
        for cert in certs:
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
            total += 1
            if total % 1000 == 0:
                print(f"  Exported {total}/{count}...", file=sys.stderr)

    print(f"✓ Exported {total} certificates to {output_path}", file=sys.stderr)
    return total

if __name__ == '__main__':
    enrollments_path = sys.argv[1] if len(sys.argv) > 1 else '/tmp/openedx_enrollments.csv'
    certificates_path = sys.argv[2] if len(sys.argv) > 2 else '/tmp/openedx_certificates.csv'

    export_enrollments(enrollments_path)
    export_certificates(certificates_path)

    print("\n✓ Export complete!", file=sys.stderr)
    print(f"  Enrollments: {enrollments_path}", file=sys.stderr)
    print(f"  Certificates: {certificates_path}", file=sys.stderr)
