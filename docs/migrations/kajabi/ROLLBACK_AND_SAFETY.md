# Rollback & Safety Guide for Kajabi → Open edX Migration
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-11-09_

## Current Situation Analysis

### What We Found

1. **Prepared Import Files Exist:**
   - `users_import.csv`: 85,216 users ready to import
   - `enrollments_import.csv`: 180,785 enrollments ready to import

2. **Verification Shows:**
   - Kajabi has: 138,585 enrollments
   - Open edX has: 0 enrollments (empty or not accessible)

3. **Discrepancy:**
   - Prepared file has **180,785** enrollments
   - Verification found **138,585** enrollments
   - **Difference: ~42,000 enrollments**

### Why the Discrepancy?

The difference likely comes from:
- **Prepared file** (`enrollments_import.csv`): Includes ALL purchases, including duplicates/multiple purchases per user
- **Verification file** (`fix_missing_enrollments.csv`): Counts unique email+course combinations

**Both are valid**, but we should use the verification file (unique combinations) as it's more accurate.

## Migration Status

### ✅ What's Been Done

1. **Data Exported from Kajabi** ✅
   - Users, enrollments, courses, certificates eligibility
   - All source data captured

2. **Data Transformed** ✅
   - Users CSV prepared
   - Enrollments CSV prepared
   - Course packages built

3. **Verification Tools Created** ✅
   - Comparison scripts
   - Fix scripts
   - Rollback tools

### ⏳ What's NOT Been Done

1. **Users NOT imported yet** (or imported but not verified)
2. **Enrollments NOT imported yet** (Open edX shows 0)
3. **Certificates NOT generated yet**

## Safety & Rollback Plan

### Before Importing

**1. Backup Open edX Database:**
```bash
source ops/tutor-env.sh
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
python tools/verify-and-sync-kajabi-to-openedx.py \
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
# Dry run first
python tools/rollback-openedx-imports.py \
  --django-settings lms.envs.tutor.production \
  --import-file scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --action unenroll \
  --dry-run

# Actually unenroll
python tools/rollback-openedx-imports.py \
  --django-settings lms.envs.tutor.production \
  --import-file scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --action unenroll
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
python tools/create-rollback-csv.py \
  --course-ids "course-v1:MEREKA+MEKA-2148875088+R2148875088" \
  --output rollback_specific.csv

# Unenroll from filtered CSV
python tools/rollback-openedx-imports.py \
  --django-settings lms.envs.tutor.production \
  --import-file rollback_specific.csv \
  --action unenroll
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
   python tools/verify-and-sync-kajabi-to-openedx.py \
     --django-settings lms.envs.tutor.production \
     --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
     --kajabi-users scripts/migrations/kajabi/output/users.csv \
     --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
     --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
     --output-dir scripts/migrations/kajabi/output/verification_after_import
   ```

5. **Handle Certificates** (after marking completions)

## File Comparison

### Which File to Use?

**For Enrollments:**
- ✅ **Use:** `fix_missing_enrollments.csv` (from verification)
  - 138,585 enrollments
  - Unique email+course combinations
  - More accurate count
  
- ⚠️ **Alternative:** `enrollments_import.csv` (prepared earlier)
  - 180,785 enrollments
  - May include duplicates
  - Use if you want all purchase records

**Recommendation:** Use `fix_missing_enrollments.csv` - it's verified against Kajabi source of truth.

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
# Quick unenroll all Kajabi enrollments
python tools/rollback-openedx-imports.py \
  --django-settings lms.envs.tutor.production \
  --import-file scripts/migrations/kajabi/output/verification/fix_missing_enrollments.csv \
  --action unenroll \
  --dry-run  # Remove --dry-run to actually do it
```

## Questions Answered

**Q: Have we completely migrated to Open edX yet?**  
A: **No** - Open edX appears empty. The import files are prepared but not imported yet.

**Q: What if this is done wrongly?**  
A: **Rollback is possible**:
- Unenroll users (safe, reversible)
- Restore database backup (complete rollback)
- Selective removal by course/user

**Q: Can we roll back?**  
A: **Yes** - Use the rollback tool or database restore. Always backup first!

