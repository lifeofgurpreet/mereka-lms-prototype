# MCT Duplicate Courses Analysis and Cleanup Strategy

**Generated**: 2025-12-18
**Status**: CRITICAL - Users cannot access enrolled courses
**Impact**: 101,428 enrollments in courses with NO CONTENT

---

## Executive Summary

There is a **CRITICAL data integrity issue** with the MCT course migration:

1. **Old format courses (MCT-*+course)** have real content in modulestore but were created on 2025-12-17
2. **New format courses (MCTCAT-*+RUN-*)** have NO content in modulestore but were created on 2025-11-10
3. **99.5%+ of users are enrolled in BOTH** old and new format courses
4. **New courses have 55,714 enrollments but NO CONTENT** - users cannot access anything

### The Problem

| Course Pair | Old (has content) | New (NO content) | Overlap % |
|-------------|------------------|------------------|-----------|
| MCT-24 → MCTCAT-24 | 9,591 enrollments | 10,155 enrollments | 99.95% |
| MCT-27 → MCTCAT-27 | 45,517 enrollments | 45,519 enrollments | 100% |
| MCT-45 → MCTCAT-45 | 818 enrollments | 814 enrollments | 99.51% |
| MCT-46 → MCTCAT-46 | 818 enrollments | 814 enrollments | 99.51% |
| MCT-22 (special) | 45,684 enrollments | 0 (no new version) | N/A |

**TOTAL AFFECTED**: 102,428 enrollments across all courses

---

## Detailed Analysis

### 1. Content Status

#### Old Format Courses (MCT-*+course) - Created Dec 17, 2025
- ✅ **Have content** in MongoDB modulestore
- ✅ **Have actual chapters and sections**
- ✅ **Users CAN access** course material
- ❌ **Created AFTER** the new format courses (suspicious)

Example structure (MCT-27):
```
- 5 chapters (A podcast series, Computer Security, Digital Literacy, etc.)
- 86 sections total
- Real content with videos, assessments, etc.
```

#### New Format Courses (MCTCAT-*+RUN-*) - Created Nov 10, 2025
- ❌ **NO content** in MongoDB modulestore
- ❌ **Course structure does not exist**
- ❌ **Users enrolled but cannot access anything**
- ✅ **Correct naming convention** (MCTCAT-XX+RUN-XX)

### 2. Enrollment Overlap

Almost **100% of users are enrolled in BOTH** old and new courses:

#### AI Fluency (MCT-24 vs MCTCAT-24)
- Old: 9,591 enrollments
- New: 10,155 enrollments
- **Overlap: 9,586 users (99.95%)**
- Only in old: 5 users
- Only in new: 569 users

#### Digital Literacy (MCT-27 vs MCTCAT-27)
- Old: 45,517 enrollments
- New: 45,519 enrollments
- **Overlap: 45,516 users (100%)**
- Only in old: 1 user
- Only in new: 3 users

### 3. The MCT-22 Anomaly

`MCT-22+course` (Careering as an Administrative Professional):
- ❌ **45,684 enrollments but NO CONTENT**
- ✅ **Has a new version**: `MCT-22+RUN-22` with content (created TODAY - Dec 18, 2025)
- ⚠️ **Zero enrollments** in the new version
- 🚨 **This is the reverse problem**: enrollments in wrong course

---

## Root Cause Analysis

### Timeline of Events

1. **Nov 10, 2025**: MCTCAT-* courses created (enrollment records only, no content)
2. **Dec 17, 2025**: MCT-* courses imported with actual content from MCT platform
3. **Dec 18, 2025**: MCT-22+RUN-22 created with content (likely a retry)

### What Went Wrong

1. **First migration (Nov 10)**: Enrollments were migrated to MCTCAT-* courses, but course content import failed or was incomplete
2. **Second migration (Dec 17)**: Course content was re-imported using old MCT-* IDs instead of MCTCAT-* IDs
3. **Result**: Content and enrollments are in different courses

---

## Impact Assessment

### Severity: CRITICAL

#### Broken User Experience
- **55,714 users enrolled in MCTCAT-24 and MCTCAT-27** cannot access course content
- Users see "enrolled" status but clicking the course shows empty/error pages
- No way for users to complete courses or earn certificates

#### Business Impact
- All MCT course enrollments are effectively broken
- Users migrated from MCT platform have degraded experience
- Certificate generation impossible (no content = no completion)

#### Data Integrity
- Duplicate enrollment records consuming database space
- Confusing analytics (which course enrollment counts are real?)
- Course catalog shows 19 courses when only 4 have real content

---

## Cleanup Strategy

### Recommended Approach: MIGRATE CONTENT TO MATCH ENROLLMENTS

**Why**: The MCTCAT-* naming is the correct format, and enrollments are already there. Moving content is safer than moving 100K+ enrollments.

### Implementation Plan

#### Phase 1: Backup (CRITICAL - Do this first!)

```bash
# 1. Export MongoDB collections
kubectl exec -n mereka-lms mongodb-0 -- mongodump \
  --db=openedx \
  --collection=modulestore \
  --out=/tmp/backup-before-cleanup

# 2. Backup CourseOverview table
kubectl exec -n mereka-lms lms-pod -- python manage.py lms dumpdata \
  course_overviews.CourseOverview \
  --indent 2 > backup-course-overviews.json

# 3. Backup enrollment data
kubectl exec -n mereka-lms lms-pod -- python manage.py lms dumpdata \
  student.CourseEnrollment \
  --indent 2 > backup-enrollments.json
```

#### Phase 2: Re-import Content with Correct Course IDs

The MCT courses need to be re-imported using the MCTCAT-* course IDs:

```bash
# Re-import with correct course IDs (requires course packages)
# This assumes you have the original MCT course packages

# Option A: Via Studio UI (SAFEST)
# 1. Log into Studio
# 2. Create course with ID: SKILLOURFUTURE+MCTCAT-24+RUN-24
# 3. Import the MCT-24 course tarball
# 4. Repeat for each course

# Option B: Via management command
kubectl exec -n mereka-lms cms-pod -- python manage.py cms import \
  /path/to/MCTCAT-24-course-export.tar.gz \
  course-v1:SKILLOURFUTURE+MCTCAT-24+RUN-24
```

#### Phase 3: Migrate MCT-22 Enrollments

```python
# migrate_mct22_enrollments.py
from common.djangoapps.student.models import CourseEnrollment
from opaque_keys.edx.keys import CourseKey

old_course = CourseKey.from_string('course-v1:SKILLOURFUTURE+MCT-22+course')
new_course = CourseKey.from_string('course-v1:SKILLOURFUTURE+MCT-22+RUN-22')

# Move enrollments from MCT-22+course to MCT-22+RUN-22
enrollments = CourseEnrollment.objects.filter(course_id=old_course, is_active=True)
count = 0

for enrollment in enrollments:
    # Check if already enrolled in new course
    exists = CourseEnrollment.objects.filter(
        user=enrollment.user,
        course_id=new_course
    ).exists()

    if not exists:
        enrollment.course_id = new_course
        enrollment.save()
        count += 1

print(f"Migrated {count} enrollments from MCT-22+course to MCT-22+RUN-22")
```

#### Phase 4: Clean Up Old Courses

**After confirming content is in MCTCAT-* courses:**

```python
# cleanup_old_mct_courses.py
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from common.djangoapps.student.models import CourseEnrollment
from opaque_keys.edx.keys import CourseKey
from xmodule.modulestore.django import modulestore

# Courses to delete
old_courses = [
    'course-v1:SKILLOURFUTURE+MCT-22+course',
    'course-v1:SKILLOURFUTURE+MCT-24+course',
    'course-v1:SKILLOURFUTURE+MCT-27+course',
    'course-v1:SKILLOURFUTURE+MCT-45+course',
    'course-v1:SKILLOURFUTURE+MCT-46+course',
]

store = modulestore()

for course_id_str in old_courses:
    # Verify no active enrollments remain
    enrollment_count = CourseEnrollment.objects.filter(
        course_id=course_id_str,
        is_active=True
    ).count()

    if enrollment_count > 0:
        print(f"WARNING: {course_id_str} still has {enrollment_count} enrollments!")
        continue

    # Delete from modulestore
    course_key = CourseKey.from_string(course_id_str)
    store.delete_course(course_key, user_id=-1)

    # Delete CourseOverview
    CourseOverview.objects.filter(id=course_id_str).delete()

    print(f"Deleted {course_id_str}")
```

#### Phase 5: Clean Up Empty MCTCAT Courses

```python
# cleanup_empty_mctcat_courses.py
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from common.djangoapps.student.models import CourseEnrollment

# Empty courses to delete (no enrollments)
empty_courses = [
    'course-v1:SKILLOURFUTURE+MCTCAT-1+RUN-1',
    'course-v1:SKILLOURFUTURE+MCTCAT-14+RUN-14',
    'course-v1:SKILLOURFUTURE+MCTCAT-15+RUN-15',
    'course-v1:SKILLOURFUTURE+MCTCAT-16+RUN-16',
    'course-v1:SKILLOURFUTURE+MCTCAT-30+RUN-30',
    'course-v1:SKILLOURFUTURE+MCTCAT-31+RUN-31',
    'course-v1:SKILLOURFUTURE+MCTCAT-32+RUN-32',
    'course-v1:SKILLOURFUTURE+MCTCAT-33+RUN-33',
    'course-v1:SKILLOURFUTURE+MCTCAT-35+RUN-35',
    'course-v1:SKILLOURFUTURE+MCTCAT-44+RUN-44',
]

for course_id_str in empty_courses:
    enrollment_count = CourseEnrollment.objects.filter(
        course_id=course_id_str,
        is_active=True
    ).count()

    if enrollment_count == 0:
        CourseOverview.objects.filter(id=course_id_str).delete()
        print(f"Deleted empty course: {course_id_str}")
    else:
        print(f"SKIPPED {course_id_str}: has {enrollment_count} enrollments")
```

---

## Alternative Approach: MIGRATE ENROLLMENTS TO MATCH CONTENT

**Why NOT recommended**: Moving 100K+ enrollments is riskier than re-importing 4 courses

Would require:
1. Deactivate all enrollments in MCTCAT-* courses
2. Re-enroll users in MCT-* courses
3. Transfer progress data, grades, certificates (if any)
4. High risk of data loss

---

## Validation Steps

After cleanup:

```python
# validate_cleanup.py
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from common.djangoapps.student.models import CourseEnrollment
from opaque_keys.edx.keys import CourseKey
from xmodule.modulestore.django import modulestore

courses = CourseOverview.objects.filter(org='SKILLOURFUTURE')
store = modulestore()

print("Course Validation Report")
print("=" * 80)

for course_overview in courses:
    course_id_str = str(course_overview.id)

    # Check content
    course_key = CourseKey.from_string(course_id_str)
    course = store.get_course(course_key)
    has_content = course is not None

    # Check enrollments
    enrollment_count = CourseEnrollment.objects.filter(
        course_id=course_id_str,
        is_active=True
    ).count()

    status = "✅ OK" if (has_content and enrollment_count > 0) or enrollment_count == 0 else "❌ BROKEN"

    print(f"{status} {course_id_str}")
    print(f"   Display Name: {course_overview.display_name}")
    print(f"   Has Content: {has_content}")
    print(f"   Enrollments: {enrollment_count}")
    print()

print("=" * 80)
print("Expected result: All courses should be ✅ OK")
print("✅ OK means: (has content AND has enrollments) OR (no enrollments)")
```

---

## Execution Commands

### 1. Run Analysis Script

```bash
# Save validation script
cat > /tmp/validate_mct_courses.py << 'EOF'
# ... (validation script from above)
EOF

# Execute
kubectl cp /tmp/validate_mct_courses.py mereka-lms/lms-pod:/tmp/
kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < /tmp/validate_mct_courses.py
```

### 2. Backup Everything

```bash
# Backup script
./scripts/infra/backup-db.sh
```

### 3. Re-import Courses

```bash
# Identify original course packages
ls scripts/migrations/mct/output/course_packages_categories/

# Re-import via Studio or management command
```

### 4. Migrate MCT-22 Enrollments

```bash
# Save migration script
cat > /tmp/migrate_mct22.py << 'EOF'
# ... (migration script from above)
EOF

kubectl cp /tmp/migrate_mct22.py mereka-lms/lms-pod:/tmp/
kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < /tmp/migrate_mct22.py
```

### 5. Clean Up

```bash
# Only after validation!
kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < cleanup_old_mct_courses.py
kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < cleanup_empty_mctcat_courses.py
```

### 6. Final Validation

```bash
kubectl exec -n mereka-lms lms-pod -- python manage.py lms shell < /tmp/validate_mct_courses.py
```

---

## Risk Assessment

### High Risk Actions
- ❌ Deleting courses with active enrollments
- ❌ Modifying enrollment records without backup
- ❌ Deleting MongoDB collections

### Medium Risk Actions
- ⚠️ Re-importing courses (may overwrite settings)
- ⚠️ Moving enrollments between courses (progress data)

### Low Risk Actions
- ✅ Deleting empty courses (no enrollments)
- ✅ Deleting CourseOverview records (can regenerate)
- ✅ Database backups

---

## Success Criteria

After cleanup, the system should have:

1. ✅ **5 courses total** in SKILLOURFUTURE org (down from 20):
   - `MCTCAT-24+RUN-24` - AI Fluency (10,155 enrollments, HAS content)
   - `MCTCAT-27+RUN-27` - Digital Literacy (45,519 enrollments, HAS content)
   - `MCTCAT-45+RUN-45` - Become an Entrepreneur (814 enrollments, HAS content)
   - `MCTCAT-46+RUN-46` - Speak with Impact (814 enrollments, HAS content)
   - `MCT-22+RUN-22` - Careering as Admin Professional (45,684 enrollments, HAS content)

2. ✅ **All courses have content** in modulestore
3. ✅ **All enrollments point to courses with content**
4. ✅ **Zero orphaned courses** (content but no enrollments, or enrollments but no content)
5. ✅ **Users can access all enrolled courses**

---

## Recommended Timeline

1. **Day 1 Morning**: Backup and analysis
2. **Day 1 Afternoon**: Re-import first course (MCTCAT-24) and validate
3. **Day 2**: Re-import remaining 3 courses (MCTCAT-27, 45, 46)
4. **Day 3**: Migrate MCT-22 enrollments, validate all
5. **Day 4**: Cleanup old courses
6. **Day 5**: Final validation and monitoring

---

## Questions to Answer Before Proceeding

1. ❓ **Do we have the original MCT course packages** for re-import?
   - Check: `scripts/migrations/mct/output/course_packages_categories/`

2. ❓ **Why were courses imported twice** (Nov 10 and Dec 17)?
   - Need to understand to prevent recurrence

3. ❓ **Are users currently trying to access these courses?**
   - Check LMS logs for 404/error rates on course pages

4. ❓ **Should MCT-22 use MCTCAT-22+RUN-22 instead of MCT-22+RUN-22?**
   - For consistency with other courses

---

## Contact

For questions or approval to proceed:
- Review this document
- Approve backup strategy
- Approve cleanup approach
- Schedule maintenance window

**CRITICAL**: Do NOT delete any courses until content re-import is verified successful.
