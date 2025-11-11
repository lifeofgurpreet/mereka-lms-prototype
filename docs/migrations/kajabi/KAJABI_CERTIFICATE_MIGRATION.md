# Kajabi Certificate Migration & Enrollment Comparison
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-09-20_

This guide explains how to ensure certificates from Kajabi are migrated to Open edX and how to compare enrollments between the two platforms.

## Overview

**Challenge**: Kajabi's Public API doesn't expose certificate issuance data directly. However, we can:
1. Build certificate eligibility from enrollment/purchase data
2. Compare enrollments between Kajabi and Open edX
3. Identify discrepancies and missing certificates

## Step 1: Export Certificate Eligibility from Kajabi

Since Kajabi's API doesn't expose certificates, we build eligibility from purchase/enrollment data:

```bash
export KAJABI_CLIENT_ID="your_client_id"
export KAJABI_CLIENT_SECRET="your_client_secret"
node tools/kajabi-export-certificates.mjs
```

**Output**: `exports/kajabi/certificate_eligibility.ndjson`

This file contains:
- Users who purchased/enrolled in courses (certificate eligible)
- Course IDs and enrollment dates
- Email addresses for matching

**Note**: This represents *eligibility*, not actual certificate issuance. To get actual certificates:
1. Log into Kajabi dashboard
2. Go to Analytics → Certificates
3. Export certificate data manually
4. Match with eligibility list using email/course_id

## Step 2: Export Enrollments from Open edX

Export current enrollments from your Open edX instance:

```bash
# Option 1: Using the script (if dump_enrollments command exists)
./tools/openedx-export-enrollments.sh exports/openedx/enrollments.csv

# Option 2: Manual SQL export via Tutor
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

tutor local run lms cat /tmp/enrollments.csv > exports/openedx/enrollments.csv
```

**Output**: `exports/openedx/enrollments.csv`

## Step 3: Compare Enrollments

Generate a comparison report:

```bash
python tools/compare-enrollments-kajabi-openedx.py \
  --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
  --kajabi-users ops/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --openedx-enrollments exports/openedx/enrollments.csv \
  --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir ops/migrations/kajabi/output/comparison
```

**Outputs**:
- `enrollment_comparison.csv` - Detailed comparison per course
- `summary.txt` - Summary statistics

### Comparison Report Columns

| Column | Description |
|--------|-------------|
| `kajabi_course_id` | Kajabi course ID |
| `openedx_course_id` | Open edX course key (course-v1:ORG+NUMBER+RUN) |
| `kajabi_enrollments` | Number of enrollments in Kajabi |
| `openedx_enrollments` | Number of enrollments in Open edX |
| `discrepancy` | Difference (Kajabi - Open edX) |
| `missing_in_openedx` | Count of enrollments in Kajabi but not Open edX |
| `extra_in_openedx` | Count of enrollments in Open edX but not Kajabi |
| `certificate_eligible` | Number of certificate-eligible users in Kajabi |
| `missing_emails` | Sample emails missing in Open edX (first 10) |
| `extra_emails` | Sample emails extra in Open edX (first 10) |

## Step 4: Certificate Migration Strategy

### Option A: Manual Certificate Export from Kajabi

1. **Export certificates from Kajabi UI**:
   - Log into Kajabi dashboard
   - Navigate to Analytics → Certificates
   - Export certificate data (CSV or JSON)
   - Match with `certificate_eligibility.ndjson` using email + course_id

2. **Import certificates into Open edX**:
   ```bash
   # Create certificate import CSV
   # Format: email,course_id,certificate_type,created_date
   
   # Use Open edX certificate generation API or management command
   tutor local run lms ./manage.py lms generate_certificates \
     --course-id course-v1:ORG+NUMBER+RUN \
     --settings=tutor.production
   ```

### Option B: Generate Certificates Based on Completion

If you have completion data:

1. **Identify completed courses**:
   - Use enrollment comparison report
   - Filter for users who completed courses in Kajabi
   - Match with Open edX course completions

2. **Generate certificates**:
   ```bash
   # For each course with completions
   tutor local run lms ./manage.py lms generate_certificates \
     --course-id course-v1:ORG+NUMBER+RUN \
     --settings=tutor.production
   ```

### Option C: Certificate API Integration

If using third-party certificate services (Accredible, SimpleCert):

1. Export certificates from the third-party platform
2. Match with Open edX users using email
3. Import certificate URLs/metadata into Open edX

## Troubleshooting Enrollment Discrepancies

### Common Issues

1. **Email mismatches**:
   - Users may have different emails in Kajabi vs Open edX
   - Check `missing_emails` column in comparison report
   - Manually match users by name or username

2. **Course mapping issues**:
   - Some Kajabi courses may not be imported to Open edX
   - Check `openedx_course_id` column for "NOT_MAPPED"
   - Verify course manifest includes all courses

3. **Active vs inactive enrollments**:
   - Kajabi may have deactivated enrollments
   - Open edX may have inactive enrollments
   - Filter by `is_active` flag when comparing

### Fixing Missing Enrollments

If enrollments are missing in Open edX:

```bash
# Re-import enrollments from Kajabi
python ops/migrations/kajabi/scripts/prepare_openedx_imports.py \
  --output-root ops/migrations/kajabi/output \
  --manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv

# Import missing enrollments
tutor local run lms bash -c "cat > /tmp/kajabi-enrollments.csv" \
  < ops/migrations/kajabi/output/openedx/enrollments_import.csv
tutor local run lms ./manage.py lms bulk_enroll \
  --csv /tmp/kajabi-enrollments.csv \
  --settings=tutor.production \
  --email-students False \
  --auto-enroll True
```

## Verification Checklist

- [ ] Certificate eligibility exported from Kajabi
- [ ] Enrollments exported from Open edX
- [ ] Comparison report generated
- [ ] Discrepancies identified and documented
- [ ] Missing enrollments re-imported
- [ ] Certificates generated for eligible users
- [ ] Final comparison shows < 5% discrepancy

## Next Steps

1. **Regular monitoring**: Run comparison monthly to catch new discrepancies
2. **Automated certificate generation**: Set up automated certificate generation for course completions
3. **Certificate verification**: Provide users with a way to verify their certificates migrated correctly

