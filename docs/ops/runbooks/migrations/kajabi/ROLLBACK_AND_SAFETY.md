# Rollback & Safety Guide for Kajabi → Open edX Migration
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2026-03-10_

Use this runbook before re-running Kajabi imports or when you need a safe rollback path for a failed or partial import. It focuses on durable safety steps, not dated migration-status snapshots.

## Safety Principles

- backup before importing or re-importing
- test with a small batch before bulk enrollment changes
- prefer verified import inputs over older prepared snapshots
- keep rollback commands/script selection explicit and reviewable
- re-run verification after every material import step

## Safety & Rollback Plan

### Before Importing

**1. Backup Open edX Database:**
```bash
source infrastructure/tutor/tutor-env.sh
tutor local do backup-db
# Or manually:
tutor local run lms ./manage.py lms dumpdata --settings=tutor.production > backup_before_import.json
```

**2. Test with Small Batch First:**
```bash
# Test with first 100 enrollments
head -101 scripts/migrations/kajabi/output/verification/fix_missing_enrollments.csv > /tmp/test_enrollments.csv
tutor local run lms ./manage.py lms bulk_enroll \
  --csv /tmp/test_enrollments.csv \
  --settings=tutor.production \
  --email-students False \
  --auto-enroll True
```

**3. Verify Test Import:**
```bash
# Re-run verification to see if test worked
python scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir scripts/migrations/kajabi/output/verification_test
```

### Rollback Options

#### Option 1: Unenroll Users (Safe)

Remove enrollments imported from Kajabi:

```bash
# Dry run first (replace with your rollback helper command)
tutor local run lms ./manage.py lms shell -c "print('dry-run unenroll plan')"

# Actually unenroll (replace with your rollback helper command)
tutor local run lms ./manage.py lms shell -c "print('execute unenroll plan')"
```

#### Option 2: Database Restore (Complete Rollback)

If you have a backup:

```bash
# Restore from backup
tutor local do restore-db backup_file.sql

# Or restore from JSON dump
tutor local run lms ./manage.py lms loaddata backup_before_import.json \
  --settings=tutor.production
```

#### Option 3: Selective Rollback

Remove only specific courses/users:

```bash
# Create a filtered CSV with enrollments to remove
python scripts/migrations/kajabi/prepare_openedx_imports.py \
  --source scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --output scripts/migrations/kajabi/output/openedx/rollback_specific.csv

# Unenroll from filtered CSV (replace with your rollback helper command)
tutor local run lms ./manage.py lms shell -c "print('unenroll from rollback_specific.csv')"
```

### Safe Import Process

**Recommended Order:**

1. **Backup First** ✅
   ```bash
   tutor local do backup-db
   ```

2. **Import Users** (if not done)
   ```bash
   tutor local run lms bash -c 'cat > /tmp/kajabi-users.csv' \
     < scripts/migrations/kajabi/output/openedx/users_import.csv
   tutor local run lms ./manage.py lms importusers \
     /tmp/kajabi-users.csv --settings=tutor.production --send-email False
   ```

3. **Import Enrollments** (use verification file - more accurate)
   ```bash
   # Use the verification file (unique combinations)
   tutor local run lms bash -c 'cat > /tmp/missing-enrollments.csv' \
     < scripts/migrations/kajabi/output/verification/fix_missing_enrollments.csv
   tutor local run lms ./manage.py lms bulk_enroll \
     --csv /tmp/missing-enrollments.csv \
     --settings=tutor.production \
     --email-students False \
     --auto-enroll True
   ```

4. **Verify After Import**
   ```bash
   python scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py \
     --django-settings lms.envs.tutor.production \
     --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
     --kajabi-users scripts/migrations/kajabi/output/users.csv \
     --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
     --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
     --output-dir scripts/migrations/kajabi/output/verification_after_import
   ```

5. **Handle Certificates** (after marking completions)

## Verification Checklist

Before importing:
- [ ] Database backed up
- [ ] Test import done with small batch
- [ ] Test verified successfully
- [ ] Rollback plan ready
- [ ] Using correct import file (verification file)

After importing:
- [ ] Verification run shows < 1% discrepancy
- [ ] Spot-checked a few courses manually
- [ ] Users can access their courses
- [ ] No errors in logs

## Emergency Rollback

If something goes wrong:

```bash
# Quick unenroll all Kajabi enrollments (replace with your rollback helper command)
tutor local run lms ./manage.py lms shell -c "print('dry-run full Kajabi unenroll rollback')"
```

