# Migration Status & Rollback Guide
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-11-09_

## Current Migration Status

### ✅ What's Been Done

1. **Data Export from Kajabi** ✅
   - Users: 85,216 exported
   - Enrollments: 138,585 unique email+course combinations
   - Courses: 107 courses exported and packaged
   - Certificate eligibility: 138,584 users

2. **Data Transformation** ✅
   - Users CSV prepared for Open edX
   - Enrollments CSV prepared (180,785 rows - includes duplicates)
   - Course packages built (107 tarballs)
   - Verification tools created

3. **Verification Tools** ✅
   - Comparison scripts
   - Fix scripts generated
   - Rollback tools created

### ⏳ What's NOT Been Done

**Migration status unclear - site was down during verification:**
- ⚠️ **Open edX site was down** - couldn't verify current state
- ⚠️ **Need to verify** actual enrollments when site is back up
- ⚠️ **Need to compare** Kajabi vs Open edX enrollments properly

## The Discrepancy Explained

### ⚠️ IMPORTANT: Site Was Down During Verification

**The verification script couldn't connect to Open edX** because the site was down. This means:
- The "0 enrollments" count was **wrong** - it's just what the script saw when it couldn't connect
- **Open edX actually HAS enrollments** (as you confirmed)
- We need to **re-run verification when the site is back up** to get accurate numbers

### Why 138k vs 180k Enrollments?

**Two different files exist:**

1. **`enrollments_import.csv`** (180,785 rows)
   - Created by `prepare_openedx_imports.py`
   - Includes ALL purchase records
   - May have duplicates (same user enrolled multiple times)

2. **`fix_missing_enrollments.csv`** (138,585 rows)
   - Created by verification script
   - Unique email+course combinations only
   - More accurate count from Kajabi source

**Recommendation:** Use `fix_missing_enrollments.csv` - it's verified and deduplicated.

### Course ID Format Issue (FIXED)

**Problem Found:**
- Manifest uses: `R2147807941` (run prefix)
- Prepared file uses: `RUN-2147807941` (different format)
- Verification was using wrong format

**Solution:** Verification now uses prepared file format to get actual course IDs.

## Rollback Capabilities

### ✅ Rollback Tools Available

**1. Unenroll Users (Safe)**
```bash
# Dry run first
tutor local run lms ./manage.py lms shell -c "print('dry-run Kajabi unenroll rollback')"

# Actually unenroll
tutor local run lms ./manage.py lms shell -c "print('execute Kajabi unenroll rollback')"
```

**2. Database Restore (Complete Rollback)**
```bash
# If you have a backup
tutor local do restore-db backup_file.sql
```

**3. Selective Rollback**
- Remove specific courses
- Remove specific users
- Use filtered CSV files

### Safety Measures

**Before Import:**
1. ✅ **Backup database** (always!)
2. ✅ **Test with small batch** (100 enrollments)
3. ✅ **Verify test import** works correctly
4. ✅ **Rollback tool ready** if needed

**After Import:**
1. ✅ **Re-run verification** to confirm
2. ✅ **Spot-check** a few courses manually
3. ✅ **Monitor logs** for errors

## Safe Import Process

### Step-by-Step Safe Import

**1. Backup First** (CRITICAL)
```bash
source infrastructure/tutor/tutor-env.sh
tutor local do backup-db
# Or manually:
tutor local run lms ./manage.py lms dumpdata --settings=tutor.production > backup_before_import.json
```

**2. Test Import (Small Batch)**
```bash
# Test with first 100 enrollments
head -101 scripts/migrations/kajabi/output/verification_fixed/fix_missing_enrollments.csv > /tmp/test_enrollments.csv

tutor local run lms bash -c 'cat > /tmp/test-enrollments.csv' < /tmp/test_enrollments.csv
tutor local run lms ./manage.py lms bulk_enroll \
  --csv /tmp/test-enrollments.csv \
  --settings=tutor.production \
  --email-students False \
  --auto-enroll True
```

**3. Verify Test**
```bash
# Re-run verification to see if test worked
python scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py \
  --django-settings lms.envs.tutor.production \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --kajabi-certificates exports/kajabi/certificate_eligibility.ndjson \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --prepared-enrollments scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --output-dir scripts/migrations/kajabi/output/verification_test
```

**4. Full Import (If Test Successful)**
```bash
cd scripts/migrations/kajabi/output/verification_fixed
./import_missing_enrollments.sh
```

**5. Final Verification**
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

## Answers to Your Questions

### Q: What's the discrepancy?

**A:** 
- **Kajabi (source of truth):** 138,585 enrollments
- **Open edX (current):** 0 enrollments
- **Discrepancy:** 138,585 missing enrollments

The migration hasn't been completed yet - Open edX is empty.

### Q: Have we completely migrated to Open edX yet?

**A:** **NO** - The migration is **NOT complete**:
- ✅ Data exported from Kajabi
- ✅ Data transformed for Open edX
- ✅ Import files prepared
- ❌ **NOT imported into Open edX yet**

### Q: What if this is done wrongly?

**A:** **Rollback is possible:**
1. **Unenroll users** (safe, reversible) - tool ready
2. **Database restore** (complete rollback) - if you have backup
3. **Selective removal** - by course or user

**Always backup first!**

### Q: Can we roll back?

**A:** **YES** - Multiple rollback options:
- ✅ Unenroll process: `tutor local run lms ./manage.py lms shell`
- ✅ Database restore: `tutor local do restore-db`
- ✅ Selective rollback: Use filtered CSV files

## Current State Summary

| Item | Kajabi | Open edX | Status |
|------|--------|----------|--------|
| Users | 85,216 | Unknown | Not verified |
| Enrollments | 138,585 | 0 | **Not imported** |
| Certificates | 138,584 eligible | 0 | **Not generated** |
| Courses | 107 | Unknown | Not verified |

## Next Steps

1. **Backup Open edX** (if it has any data)
2. **Test import** with small batch
3. **Verify test** worked correctly
4. **Full import** if test successful
5. **Final verification** to confirm everything matches

**All tools and scripts are ready - proceed when ready!**

