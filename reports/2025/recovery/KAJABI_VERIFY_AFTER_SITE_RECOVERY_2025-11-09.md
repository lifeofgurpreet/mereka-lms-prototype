# How to Verify When Open edX Site is Back Up
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-11-09_

## Current Situation

- ✅ Kajabi data exported: 138,585 enrollments
- ⚠️ Open edX site was down during verification
- ⚠️ Need to verify actual enrollments when site is accessible

## When Site is Back Up

### Step 1: Export Current Open edX Enrollments

**Option A: Using Django (if site is accessible)**
```bash
python scripts/analytics/openedx-export-enrollments.py \
  --django-settings lms.envs.tutor.production \
  --output scripts/migrations/kajabi/output/verification/openedx_enrollments_current.csv
```

**Option B: Using Direct Database Connection**
```bash
# Get database connection details from tutor config
tutor config printvalue MYSQL_ROOT_PASSWORD
tutor config printvalue MYSQL_DATABASE

# Export using direct DB connection
python scripts/analytics/openedx-export-enrollments.py \
  --db-url "mysql://root:PASSWORD@localhost:3306/openedx" \
  --output scripts/migrations/kajabi/output/verification/openedx_enrollments_current.csv
```

**Option C: Using Tutor Command**
```bash
source infrastructure/tutor/tutor-env.sh
tutor local run lms ./manage.py lms shell --settings=tutor.production <<EOF
from common.djangoapps.student.models import CourseEnrollment
import csv

with open('/tmp/enrollments.csv', 'w') as f:
    writer = csv.writer(f)
    writer.writerow(['email', 'username', 'course_id', 'enrollment_date', 'is_active'])
    for e in CourseEnrollment.objects.select_related('user').all():
        writer.writerow([
            e.user.email or '',
            e.user.username,
            str(e.course_id),
            e.created.isoformat() if e.created else '',
            'True' if e.is_active else 'False'
        ])

print(f"Exported {CourseEnrollment.objects.count()} enrollments")
EOF

tutor local run lms cat /tmp/enrollments.csv > scripts/migrations/kajabi/output/verification/openedx_enrollments_current.csv
```

### Step 2: Export Current Open edX Certificates

```bash
python scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --prepared-enrollments scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --output-dir scripts/migrations/kajabi/output/verification_current \
  --skip-openedx-export  # Skip if you already exported manually
```

### Step 3: Compare and Generate Fix Scripts

The verification script will:
1. Load Kajabi enrollments (138,585)
2. Load Open edX enrollments (actual count)
3. Compare and identify:
   - Missing enrollments in Open edX
   - Extra enrollments in Open edX (not in Kajabi)
   - Course-by-course breakdown

### Step 4: Review the Comparison

Check the generated reports:
```bash
cat scripts/migrations/kajabi/output/verification_current/summary.txt
cat scripts/migrations/kajabi/output/verification_current/enrollment_comparison_by_course.csv
```

### Step 5: Import Missing Enrollments (If Needed)

If there are missing enrollments:
```bash
cd scripts/migrations/kajabi/output/verification_current
./import_missing_enrollments.sh
```

## Quick Verification Command

Once site is back up, run this single command:

```bash
python scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --prepared-enrollments scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --output-dir scripts/migrations/kajabi/output/verification_final
```

This will:
- ✅ Export current Open edX enrollments
- ✅ Export current Open edX certificates
- ✅ Compare with Kajabi (source of truth)
- ✅ Generate fix scripts for discrepancies
- ✅ Create detailed reports

## Expected Output

After running verification, you'll see:
- **Actual enrollment count** in Open edX
- **Missing enrollments** (Kajabi has, Open edX doesn't)
- **Extra enrollments** (Open edX has, Kajabi doesn't)
- **Course-by-course breakdown**
- **Fix scripts** ready to run

## Notes

- **Kajabi is source of truth** - if someone has enrollment in Kajabi, they should have it in Open edX
- **Rollback tools available** if something goes wrong
- **Always backup first** before importing

