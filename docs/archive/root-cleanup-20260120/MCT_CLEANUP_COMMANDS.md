# MCT Duplicate Courses - Cleanup Commands

**Quick Reference**: Commands to fix the MCT course duplication issue

## Current Status (Confirmed Dec 18, 2025)

### BROKEN Courses (Users cannot access - CRITICAL)
| Course ID | Enrollments | Status |
|-----------|-------------|--------|
| `course-v1:SKILLOURFUTURE+MCTCAT-24+RUN-24` | 10,155 | ❌ NO CONTENT |
| `course-v1:SKILLOURFUTURE+MCTCAT-27+RUN-27` | 45,519 | ❌ NO CONTENT |
| `course-v1:SKILLOURFUTURE+MCTCAT-45+RUN-45` | 814 | ❌ NO CONTENT |
| `course-v1:SKILLOURFUTURE+MCTCAT-46+RUN-46` | 814 | ❌ NO CONTENT |
| `course-v1:SKILLOURFUTURE+MCT-22+course` | 45,684 | ❌ NO CONTENT |

**Total affected**: 102,986 enrollments

### ORPHANED Courses (Content exists but no users)
| Course ID | Status |
|-----------|--------|
| `course-v1:SKILLOURFUTURE+MCT-24+course` | ✅ HAS CONTENT |
| `course-v1:SKILLOURFUTURE+MCT-27+course` | ✅ HAS CONTENT |
| `course-v1:SKILLOURFUTURE+MCT-45+course` | ✅ HAS CONTENT |
| `course-v1:SKILLOURFUTURE+MCT-46+course` | ✅ HAS CONTENT |
| `course-v1:SKILLOURFUTURE+MCT-22+RUN-22` | ✅ HAS CONTENT (created Dec 18, 2025) |

### EMPTY Courses (No content, no enrollments - safe to delete)
- `course-v1:SKILLOURFUTURE+MCTCAT-1+RUN-1`
- `course-v1:SKILLOURFUTURE+MCTCAT-14+RUN-14`
- `course-v1:SKILLOURFUTURE+MCTCAT-15+RUN-15`
- `course-v1:SKILLOURFUTURE+MCTCAT-16+RUN-16`
- `course-v1:SKILLOURFUTURE+MCTCAT-30+RUN-30`
- `course-v1:SKILLOURFUTURE+MCTCAT-31+RUN-31`
- `course-v1:SKILLOURFUTURE+MCTCAT-32+RUN-32`
- `course-v1:SKILLOURFUTURE+MCTCAT-33+RUN-33`
- `course-v1:SKILLOURFUTURE+MCTCAT-35+RUN-35`
- `course-v1:SKILLOURFUTURE+MCTCAT-44+RUN-44`

---

## Step-by-Step Cleanup

### Step 1: BACKUP (CRITICAL - Do this first!)

```bash
# 1. Backup database
./scripts/infra/backup-db.sh

# 2. Backup MongoDB modulestore
kubectl exec -n mereka-lms mongodb-0 -- mongodump \
  --db=openedx \
  --collection=modulestore \
  --out=/tmp/backup-$(date +%Y%m%d)

# 3. Download backup locally
kubectl cp mereka-lms/mongodb-0:/tmp/backup-$(date +%Y%m%d) \
  ./backups/mongodb-$(date +%Y%m%d)
```

### Step 2: Validation

```bash
# Run validation to confirm current state
LMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

kubectl cp scripts/migrations/mct/validate_course_content.py \
  mereka-lms/$LMS_POD:/tmp/validate.py

kubectl exec -n mereka-lms $LMS_POD -- \
  python manage.py lms shell < /tmp/validate.py
```

### Step 3: Migrate MCT-22 Enrollments

MCT-22 has a special situation - enrollments are in `MCT-22+course` but content is in `MCT-22+RUN-22`.

```bash
LMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

# Copy migration script
kubectl cp scripts/migrations/mct/migrate_mct22_enrollments.py \
  mereka-lms/$LMS_POD:/tmp/migrate_mct22.py

# Run DRY RUN first
kubectl exec -n mereka-lms $LMS_POD -- \
  python manage.py lms shell < /tmp/migrate_mct22.py

# If dry run looks good, execute actual migration
kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell -c "
exec(open('/tmp/migrate_mct22.py').read())
migrate_enrollments(dry_run=False)
"
```

### Step 4: Delete Empty MCTCAT Courses (Safe)

These have no enrollments and no content - safe to delete immediately.

```bash
LMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell -c "
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview

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

for course_id in empty_courses:
    try:
        CourseOverview.objects.filter(id=course_id).delete()
        print(f'Deleted: {course_id}')
    except Exception as e:
        print(f'Error deleting {course_id}: {e}')
"
```

### Step 5: Fix the Critical Issue - Import Content to MCTCAT Courses

**Option A: Re-import via Studio UI (RECOMMENDED - Safest)**

1. Access Studio at `https://studio.staging.academy.mereka.io`
2. For each course that needs content:
   - Create course with correct ID (e.g., `SKILLOURFUTURE+MCTCAT-24+RUN-24`)
   - Import the course tarball from `scripts/migrations/mct/output/course_packages_categories/`
3. Validate content appears in LMS

**Option B: Re-import via Management Command**

```bash
# Check if original course packages exist
ls -lh scripts/migrations/mct/output/course_packages_categories/

# You need the original MCT course exports
# If they exist, re-import them with the correct course IDs

CMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')

# Example for MCT-24 (AI Fluency)
kubectl cp scripts/migrations/mct/output/course_packages_categories/MCT-24.tar.gz \
  mereka-lms/$CMS_POD:/tmp/

kubectl exec -n mereka-lms $CMS_POD -- python manage.py cms import \
  /tmp /tmp/MCT-24.tar.gz \
  --course-id course-v1:SKILLOURFUTURE+MCTCAT-24+RUN-24
```

**Option C: Copy Content from Old Courses to New Courses (Advanced)**

This requires exporting from old course IDs and re-importing to new course IDs:

```bash
CMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')

# Export MCT-24+course
kubectl exec -n mereka-lms $CMS_POD -- python manage.py cms export \
  /tmp \
  course-v1:SKILLOURFUTURE+MCT-24+course

# Re-import as MCTCAT-24+RUN-24
kubectl exec -n mereka-lms $CMS_POD -- python manage.py cms import \
  /tmp /tmp/course-v1_SKILLOURFUTURE_MCT-24_course.tar.gz \
  --course-id course-v1:SKILLOURFUTURE+MCTCAT-24+RUN-24

# Repeat for MCT-27, MCT-45, MCT-46
```

### Step 6: Verify Content Import

After importing content, verify users can access courses:

```bash
LMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell -c "
from opaque_keys.edx.keys import CourseKey
from xmodule.modulestore.django import modulestore

courses_to_check = [
    'course-v1:SKILLOURFUTURE+MCTCAT-24+RUN-24',
    'course-v1:SKILLOURFUTURE+MCTCAT-27+RUN-27',
    'course-v1:SKILLOURFUTURE+MCTCAT-45+RUN-45',
    'course-v1:SKILLOURFUTURE+MCTCAT-46+RUN-46',
]

store = modulestore()

for course_id_str in courses_to_check:
    course_key = CourseKey.from_string(course_id_str)
    course = store.get_course(course_key)

    if course:
        chapter_count = len(list(course.get_children()))
        print(f'✅ {course_id_str}: {chapter_count} chapters')
    else:
        print(f'❌ {course_id_str}: NO CONTENT')
"
```

### Step 7: Delete Old Format Courses (After content import confirmed)

**ONLY DO THIS AFTER** confirming content is in MCTCAT courses!

```bash
LMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

kubectl cp scripts/migrations/mct/cleanup_duplicate_courses.py \
  mereka-lms/$LMS_POD:/tmp/cleanup.py

# Dry run first
kubectl exec -n mereka-lms $LMS_POD -- \
  python manage.py lms shell < /tmp/cleanup.py

# If dry run looks good, execute
kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell -c "
exec(open('/tmp/cleanup.py').read())
cleanup_courses(dry_run=False)
"
```

### Step 8: Final Validation

```bash
LMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell -c "
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
from common.djangoapps.student.models import CourseEnrollment
from opaque_keys.edx.keys import CourseKey
from xmodule.modulestore.django import modulestore

courses = CourseOverview.objects.filter(org='SKILLOURFUTURE')
store = modulestore()

print('FINAL STATE:')
print('=' * 80)

for course_overview in courses:
    course_id_str = str(course_overview.id)

    try:
        course_key = CourseKey.from_string(course_id_str)
        course = store.get_course(course_key)
        has_content = course is not None
    except:
        has_content = False

    enrollment_count = CourseEnrollment.objects.filter(
        course_id=course_id_str,
        is_active=True
    ).count()

    status = '✅' if (has_content and enrollment_count > 0) else '❌'

    print(f'{status} {course_id_str}')
    print(f'   {course_overview.display_name}')
    print(f'   Content: {has_content}, Enrollments: {enrollment_count:,}')
    print()
"
```

---

## Expected Final State

After cleanup, you should have:

```
✅ course-v1:SKILLOURFUTURE+MCTCAT-24+RUN-24
   AI Fluency
   Content: True, Enrollments: 10,155

✅ course-v1:SKILLOURFUTURE+MCTCAT-27+RUN-27
   Digital Literacy
   Content: True, Enrollments: 45,519

✅ course-v1:SKILLOURFUTURE+MCTCAT-45+RUN-45
   Become an Entrepreneur
   Content: True, Enrollments: 814

✅ course-v1:SKILLOURFUTURE+MCTCAT-46+RUN-46
   Speak with Impact
   Content: True, Enrollments: 814

✅ course-v1:SKILLOURFUTURE+MCT-22+RUN-22
   Careering as an Administrative Professional
   Content: True, Enrollments: 45,684
```

**Total**: 5 courses, 102,986 active enrollments

---

## Troubleshooting

### "Course import failed"
- Check CMS logs: `kubectl logs -n mereka-lms -l app.kubernetes.io/name=cms`
- Verify tarball exists and is valid
- Try importing via Studio UI instead

### "Users still can't access course"
- Clear course overview cache: `python manage.py lms update_course_overviews --all`
- Check modulestore directly for course content
- Verify enrollment course_id matches course with content

### "Enrollments disappeared"
- Check if they're inactive: `CourseEnrollment.objects.filter(is_active=False)`
- Restore from backup if needed

---

## Quick Commands Reference

```bash
# Get LMS pod
LMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')

# Get CMS pod
CMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')

# Run Python shell
kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell

# Copy file to pod
kubectl cp local-file.py mereka-lms/$LMS_POD:/tmp/

# Run script from file
kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell < /tmp/script.py

# Export course
kubectl exec -n mereka-lms $CMS_POD -- python manage.py cms export \
  /tmp course-v1:ORG+COURSE+RUN

# Import course
kubectl exec -n mereka-lms $CMS_POD -- python manage.py cms import \
  /tmp /tmp/course.tar.gz
```

---

## Contact & Approval

Before proceeding with cleanup:
1. ✅ Review MCT_DUPLICATE_COURSES_ANALYSIS.md
2. ✅ Verify backup completed successfully
3. ✅ Test on one course first (recommend MCT-45 - smallest with 814 enrollments)
4. ✅ Get approval for production cleanup

**Estimated Time**: 2-4 hours for full cleanup
**Risk Level**: Medium (with backups) to High (without backups)
**Impact**: 102,986 enrollments will be fixed
