# Verify and Sync Kajabi → Open edX
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-09-15_

Complete end-to-end verification and synchronization tool to ensure enrollments and certificates match Kajabi (source of truth).

## Quick Start

```bash
python tools/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
  --kajabi-users ops/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir ops/migrations/kajabi/output/verification
```

## What It Does

1. **Exports from Open edX**:
   - Enrollments (all users enrolled in courses)
   - Certificates (all certificates issued)

2. **Loads Kajabi Data** (source of truth):
   - Enrollments from purchase data
   - Certificate eligibility from enrollment data

3. **Compares**:
   - Enrollments: Kajabi vs Open edX per course
   - Certificates: Kajabi eligibility vs Open edX certificates per course

4. **Generates Fix Scripts**:
   - `fix_missing_enrollments.csv` - Users to enroll
   - `fix_missing_certificates.csv` - Users who need certificates
   - `import_missing_enrollments.sh` - Shell script to import enrollments
   - `generate_missing_certificates.sh` - Script to generate certificates

5. **Creates Reports**:
   - `enrollment_comparison.csv` - Detailed enrollment comparison
   - `certificate_comparison.csv` - Detailed certificate comparison
   - `summary.txt` - Summary statistics

## Output Files

### Reports

- **`enrollment_comparison.csv`**: Per-course enrollment comparison
  - `kajabi_count`: Enrollments in Kajabi
  - `openedx_count`: Enrollments in Open edX
  - `missing_count`: Missing in Open edX
  - `extra_count`: Extra in Open edX (not in Kajabi)

- **`certificate_comparison.csv`**: Per-course certificate comparison
  - `kajabi_eligible`: Certificate-eligible users in Kajabi
  - `openedx_certificates`: Actual certificates in Open edX
  - `missing_count`: Missing certificates

### Fix Scripts

- **`fix_missing_enrollments.csv`**: CSV ready for bulk enrollment import
- **`fix_missing_certificates.csv`**: CSV listing users who need certificates
- **`import_missing_enrollments.sh`**: Executable script to import enrollments
- **`generate_missing_certificates.sh`**: Script to generate certificates

## Applying Fixes

### 1. Import Missing Enrollments

```bash
cd ops/migrations/kajabi/output/verification
./import_missing_enrollments.sh
```

Or manually:
```bash
source ops/tutor-env.sh
tutor local run lms bash -c 'cat > /tmp/missing-enrollments.csv' \
  < ops/migrations/kajabi/output/verification/fix_missing_enrollments.csv
tutor local run lms ./manage.py lms bulk_enroll \
  --csv /tmp/missing-enrollments.csv \
  --settings=tutor.production \
  --email-students False \
  --auto-enroll True
```

### 2. Generate Missing Certificates

Certificates can only be generated for users who have completed courses. The script identifies users who are eligible but don't have certificates.

For each course with missing certificates:

```bash
source ops/tutor-env.sh
tutor local run lms ./manage.py lms generate_certificates \
  --course-id course-v1:ORG+NUMBER+RUN \
  --settings=tutor.production
```

**Note**: Certificate generation requires course completion. If users haven't completed courses in Open edX, you may need to:
1. Mark courses as complete for migrated users
2. Or manually verify completion status

## Verification Workflow

1. **Run verification**:
   ```bash
   python tools/verify-and-sync-kajabi-to-openedx.py \
     --django-settings lms.envs.tutor.production \
     --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
     --kajabi-users ops/migrations/kajabi/output/users.csv \
     --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
     --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
     --output-dir ops/migrations/kajabi/output/verification
   ```

2. **Review summary**:
   ```bash
   cat ops/migrations/kajabi/output/verification/summary.txt
   ```

3. **Check discrepancies**:
   ```bash
   # View enrollment discrepancies
   head -20 ops/migrations/kajabi/output/verification/enrollment_comparison.csv
   
   # View certificate discrepancies
   head -20 ops/migrations/kajabi/output/verification/certificate_comparison.csv
   ```

4. **Apply fixes**:
   ```bash
   # Import missing enrollments
   ./ops/migrations/kajabi/output/verification/import_missing_enrollments.sh
   
   # Generate certificates (per course)
   # See generate_missing_certificates.sh for instructions
   ```

5. **Re-verify**:
   ```bash
   # Run verification again to confirm fixes
   python tools/verify-and-sync-kajabi-to-openedx.py \
     --skip-openedx-export \
     --django-settings lms.envs.tutor.production \
     ...
   ```

## Troubleshooting

### Open edX Export Fails

If Django export fails, you can export manually:

```bash
# Export enrollments
tutor local run lms ./manage.py lms shell --settings=tutor.production <<'PYTHON'
import csv
from django.contrib.auth.models import User
from student.models import CourseEnrollment

with open('/tmp/enrollments.csv', 'w') as f:
    writer = csv.writer(f)
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

tutor local run lms cat /tmp/enrollments.csv > ops/migrations/kajabi/output/verification/openedx_enrollments.csv
```

### Certificate Generation Requires Completion

If certificates can't be generated because courses aren't marked complete:

1. **Check completion status**:
   ```bash
   tutor local run lms ./manage.py lms shell --settings=tutor.production
   >>> from student.models import CourseEnrollment
   >>> enrollment = CourseEnrollment.objects.get(user__email='user@example.com', course_id='course-v1:...')
   >>> # Check if course is complete
   ```

2. **Mark courses complete** (if needed):
   - Use Open edX completion API
   - Or manually mark via Django admin
   - Or use course completion management commands

## Regular Monitoring

Run verification monthly to catch new discrepancies:

```bash
# Add to cron or scheduled task
python tools/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
  --kajabi-users ops/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir ops/migrations/kajabi/output/verification/$(date +%Y%m%d)
```

