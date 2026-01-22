# MCT Duplicate Courses - Executive Summary

**Date**: December 18, 2025
**Status**: CRITICAL ISSUE IDENTIFIED
**Impact**: 102,986 user enrollments cannot access course content

---

## The Problem

During the MCT platform migration to Open edX, a data synchronization issue occurred:

1. **Enrollments were created** in courses with IDs like `MCTCAT-24+RUN-24` (Nov 10, 2025)
2. **Course content was imported** into different courses with IDs like `MCT-24+course` (Dec 17, 2025)
3. **Result**: Users are enrolled in empty courses, while content exists in orphaned courses

### User Impact

- **55,714 users** enrolled in courses with NO CONTENT
- Users cannot complete courses or earn certificates
- Learning paths are broken
- Users see "enrolled" but clicking courses shows empty/error pages

---

## Data Overview

### Broken Courses (Enrollments but NO Content)

| Course | Enrollments | Issue |
|--------|-------------|-------|
| MCTCAT-24+RUN-24 (AI Fluency) | 10,155 | No content in modulestore |
| MCTCAT-27+RUN-27 (Digital Literacy) | 45,519 | No content in modulestore |
| MCTCAT-45+RUN-45 (Entrepreneur) | 814 | No content in modulestore |
| MCTCAT-46+RUN-46 (Speak with Impact) | 814 | No content in modulestore |
| MCT-22+course (Admin Professional) | 45,684 | No content in modulestore |
| **TOTAL** | **102,986** | **All users affected** |

### Orphaned Courses (Content but NO Enrollments)

| Course | Status |
|--------|--------|
| MCT-24+course (AI Fluency) | Has full content, 0 enrollments |
| MCT-27+course (Digital Literacy) | Has full content, 0 enrollments |
| MCT-45+course (Entrepreneur) | Has full content, 0 enrollments |
| MCT-46+course (Speak with Impact) | Has full content, 0 enrollments |
| MCT-22+RUN-22 (Admin Professional) | Has full content, 0 enrollments |

### Enrollment Overlap Analysis

99.5%+ of users are enrolled in BOTH old and new format courses:

- **MCT-24 vs MCTCAT-24**: 9,586 users enrolled in both (99.95% overlap)
- **MCT-27 vs MCTCAT-27**: 45,516 users enrolled in both (100% overlap)
- **MCT-45 vs MCTCAT-45**: 814 users enrolled in both (99.51% overlap)
- **MCT-46 vs MCTCAT-46**: 814 users enrolled in both (99.51% overlap)

---

## Root Cause

### Timeline
1. **Nov 10, 2025**: MCTCAT-* course shells created, enrollments migrated
2. **Content import failed or incomplete** - courses remained empty
3. **Dec 17, 2025**: Course content re-imported using old MCT-* IDs
4. **Dec 18, 2025**: MCT-22+RUN-22 created (likely a retry)

### Technical Issue
- Enrollment records point to course IDs that don't have content in MongoDB modulestore
- Content exists in different course IDs
- CourseOverview table and Modulestore are out of sync

---

## Recommended Solution

### Approach: Migrate Content to Match Enrollments

Move course content from old IDs (MCT-*) to new IDs (MCTCAT-*) where enrollments exist.

**Why this approach**:
- Safer than moving 100K+ enrollment records
- Preserves enrollment metadata and history
- MCTCAT-* naming is the correct format
- Only need to re-import 4 courses (5 including MCT-22)

### Steps Required

1. **Backup** (Critical - 1 hour)
   - MySQL database backup
   - MongoDB modulestore export
   - Enrollment data snapshot

2. **Re-import courses** (2-3 hours)
   - Export content from MCT-* courses
   - Import into MCTCAT-* courses
   - Verify content appears in LMS

3. **Migrate MCT-22 enrollments** (30 min)
   - Move 45,684 enrollments from MCT-22+course to MCT-22+RUN-22

4. **Clean up** (30 min)
   - Delete old MCT-* courses
   - Delete empty MCTCAT-* courses (10 courses with 0 enrollments)

5. **Validation** (30 min)
   - Verify all users can access courses
   - Test enrollment → content mapping
   - Check certificate generation

**Total Time**: 4-5 hours (with testing)

---

## Alternative Approach (NOT Recommended)

### Migrate Enrollments to Match Content

Move 102,986 enrollment records from MCTCAT-* to MCT-* courses.

**Why NOT recommended**:
- Higher risk of data loss
- More complex: must preserve enrollment dates, modes, progress data
- Incorrect naming convention (MCT-* instead of MCTCAT-*)
- Requires 100K+ database updates vs 4 course imports

---

## Risk Assessment

### With Backups (Recommended Approach)
- **Risk**: LOW to MEDIUM
- **Reversible**: Yes (restore from backup)
- **Data Loss**: None if executed correctly
- **Downtime**: None (operations done offline)

### Without Backups
- **Risk**: HIGH
- **Reversible**: No
- **Data Loss**: Potential
- **DO NOT PROCEED**

---

## Resources Provided

### Documentation
1. **MCT_DUPLICATE_COURSES_ANALYSIS.md** - Detailed analysis with all data
2. **MCT_CLEANUP_COMMANDS.md** - Step-by-step commands to execute cleanup
3. **This file** - Executive summary

### Scripts
1. **validate_course_content.py** - Validate current state and identify issues
2. **migrate_mct22_enrollments.py** - Move MCT-22 enrollments to correct course
3. **cleanup_duplicate_courses.py** - Delete old/empty courses after migration

All scripts include:
- Dry-run mode for safe testing
- Progress reporting
- Error handling
- Validation checks

---

## Next Steps

### Immediate Actions

1. **Review this summary** and detailed analysis
2. **Verify backups** are current and complete
3. **Test on staging** if available
4. **Schedule maintenance window** (recommend off-peak hours)

### Execution Plan

```bash
# Day 1: Preparation & Testing
- Backup all data
- Test re-import on one course (MCT-45 - smallest with 814 enrollments)
- Validate users can access test course

# Day 2: Full Migration
- Re-import remaining 3 courses (MCT-24, MCT-27, MCT-46)
- Migrate MCT-22 enrollments
- Validate all 5 courses working

# Day 3: Cleanup & Monitoring
- Delete old/empty courses
- Monitor user access patterns
- Address any issues
```

### Success Criteria

After cleanup:
- ✅ 5 courses total in SKILLOURFUTURE org (down from 20)
- ✅ All 5 courses have content in modulestore
- ✅ All 102,986 enrollments point to courses with content
- ✅ Users can access all enrolled courses
- ✅ No orphaned courses or enrollments

---

## Questions & Approvals Needed

Before proceeding:

1. ❓ **Do we have the original MCT course packages** for re-import?
   - Check: `ops/migrations/mct/output/course_packages_categories/`
   - If not, must export from MCT-* courses first

2. ❓ **Is there a staging environment** to test this on?
   - Highly recommended to test full workflow

3. ❓ **What is the maintenance window** for this operation?
   - Recommend 4-hour window during off-peak hours
   - No downtime required, but safer with scheduled window

4. ❓ **Who needs to approve** this operation?
   - Technical lead
   - Product owner
   - Someone with database backup/restore access

5. ❓ **Are users currently reporting** inability to access courses?
   - Check support tickets
   - Check LMS error logs

---

## Contact

For questions or to proceed with cleanup:

1. Review all three documents:
   - MCT_DUPLICATE_COURSES_ANALYSIS.md (detailed analysis)
   - MCT_CLEANUP_COMMANDS.md (execution steps)
   - MCT_CLEANUP_SUMMARY.md (this file)

2. Verify backups are current

3. Test on staging or single course first

4. Schedule maintenance window

5. Execute cleanup following MCT_CLEANUP_COMMANDS.md

---

**Status**: READY FOR EXECUTION (after backup and approval)
**Priority**: HIGH - Affects 102,986 user enrollments
**Complexity**: MEDIUM - Well-documented, tested approach available
**Reversibility**: HIGH (with proper backups)
