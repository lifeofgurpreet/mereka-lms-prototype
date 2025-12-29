# Execution Plan: Verify & Sync Kajabi → Open edX
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-11-09_

## Current Status

✅ **Kajabi Data Exported**:
- 138,585 enrollments across 73 courses
- 138,584 certificate-eligible users
- All data ready for comparison

⚠️ **Open edX Status**:
- Currently empty (no enrollments/certificates found)
- This is expected if migration hasn't been completed yet

## Step-by-Step Execution Plan

### STEP 1: Review Current Discrepancies ✅ DONE

**Reports Generated:**
- `enrollment_comparison.csv` - Shows all 73 courses with missing enrollments
- `certificate_comparison.csv` - Shows all courses with missing certificates
- `summary.txt` - Summary statistics

**Key Findings:**
- **138,585 enrollments** need to be imported
- **138,584 certificates** need to be generated
- Top course: "Azure AI Fundamentals" has **52,783 missing enrollments**

### STEP 2: Import Missing Enrollments

**File Ready:** `fix_missing_enrollments.csv` (11 MB, 138,585 rows)

**Import Command:**
```bash
cd ops/migrations/kajabi/output/verification
./import_missing_enrollments.sh
```

**Or Manual Import:**
```bash
source ops/tutor-env.sh

# Copy CSV into container
tutor local run lms bash -c 'cat > /tmp/missing-enrollments.csv' \
  < ops/migrations/kajabi/output/verification/fix_missing_enrollments.csv

# Import enrollments
tutor local run lms ./manage.py lms bulk_enroll \
  --csv /tmp/missing-enrollments.csv \
  --settings=tutor.production \
  --email-students False \
  --auto-enroll True
```

**Expected Output:**
- Enrollments created for all 138,585 users
- Users enrolled in their respective courses
- Progress logged to console

**Verification After Import:**
```bash
# Re-run verification to confirm
python tools/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
  --kajabi-users ops/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir ops/migrations/kajabi/output/verification_after_import
```

### STEP 3: Handle Certificates

**Important:** Certificates can only be generated for users who have **completed** courses. Since we're migrating from Kajabi, we need to:

**Option A: Mark Courses Complete (if users completed in Kajabi)**

Create a script to mark courses complete for migrated users:

```bash
# For each course, mark users as complete if they were eligible in Kajabi
python tools/mark-courses-complete-from-kajabi.py \
  --certificate-eligibility exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv
```

**Option B: Generate Certificates Per Course**

After marking completions, generate certificates:

```bash
source ops/tutor-env.sh

# For each course with certificates
tutor local run lms ./manage.py lms generate_certificates \
  --course-id course-v1:MEREKA+MEKA-2148875088+R2148875088 \
  --settings=tutor.production
```

**File Ready:** `fix_missing_certificates.csv` (9.4 MB, 138,584 rows)

### STEP 4: Final Verification

After importing enrollments and generating certificates:

```bash
# Run full verification again
python tools/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
  --kajabi-users ops/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir ops/migrations/kajabi/output/verification_final
```

**Success Criteria:**
- Enrollment discrepancy: < 1% (allowing for edge cases)
- Certificate discrepancy: < 5% (some users may not have completed)
- All courses mapped correctly

## Quick Reference

### Files Generated

| File | Purpose | Size |
|------|---------|------|
| `fix_missing_enrollments.csv` | Import these enrollments | 11 MB |
| `fix_missing_certificates.csv` | Users needing certificates | 9.4 MB |
| `enrollment_comparison.csv` | Per-course enrollment comparison | 5 KB |
| `certificate_comparison.csv` | Per-course certificate comparison | 4.8 KB |
| `import_missing_enrollments.sh` | Ready-to-run import script | - |
| `generate_missing_certificates.sh` | Certificate generation guide | - |

### Commands

**Import Enrollments:**
```bash
./ops/migrations/kajabi/output/verification/import_missing_enrollments.sh
```

**Verify Again:**
```bash
python tools/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments ops/migrations/kajabi/output/enrollments.csv \
  --kajabi-users ops/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest ops/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir ops/migrations/kajabi/output/verification_final
```

## Troubleshooting

### Import Fails

If enrollment import fails:
1. Check that users exist in Open edX (import users first if needed)
2. Verify course IDs are correct
3. Check Tutor is running: `tutor local dc ps`

### Certificate Generation Fails

If certificates can't be generated:
1. Verify users have completed courses
2. Check course completion settings
3. May need to mark courses complete first

### Large Import

For 138k enrollments, import may take time:
- Process in batches if needed
- Monitor progress
- Check logs for errors

