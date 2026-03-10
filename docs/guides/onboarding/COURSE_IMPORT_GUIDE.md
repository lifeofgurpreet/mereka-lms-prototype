# Course Import Guide
_Audience: Platform Eng + Operations • Owner: Docs Team • Last verified: 2026-03-06 • Status: canonical_

## 🎯 Problem

Local environment has:
- ✅ 84,379 users from MCT
- ✅ 137,468 enrollments across 74 courses
- ❌ **No actual course content** (empty skeletons only)

## 📦 Solution: Import Course Tarballs

### Step 1: Export Courses from Production

```bash
# Connect to production
kubectl config use-context <production-context>

# Export top 5 MCT courses by enrollment
kubectl exec -n mereka-lms deploy/cms -- bash -c '
for course_id in \
  "course-v1:MEREKA+MEKA-2148875088+RUN-2148875088" \
  "course-v1:MEREKA+MEKA-2148861785+RUN-2148861785" \
  "course-v1:MEREKA+MEKA-2148864393+RUN-2148864393" \
  "course-v1:MEREKA+MEKA-2148864407+RUN-2148864407" \
  "course-v1:MEREKA+MEKA-2148864416+RUN-2148864416"; do
  
  echo "Exporting $course_id..."
  python manage.py cms export /tmp/exports "$course_id"
  
  # Create tarball
  SAFE_NAME=$(echo "$course_id" | sed "s/[:\\/+]/_/g")
  tar -czf "/tmp/${SAFE_NAME}.tar.gz" -C /tmp/exports .
  echo "Created /tmp/${SAFE_NAME}.tar.gz"
done
'
```

### Step 2: Download Tarballs

```bash
# Create local directory
mkdir -p course_tarballs

# Get CMS pod name
CMS_POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')

# Download each tarball
for course in \
  "course-v1_MEREKA_MEKA-2148875088_RUN-2148875088" \
  "course-v1_MEREKA_MEKA-2148861785_RUN-2148861785" \
  "course-v1_MEREKA_MEKA-2148864393_RUN-2148864393" \
  "course-v1_MEREKA_MEKA-2148864407_RUN-2148864407" \
  "course-v1_MEREKA_MEKA-2148864416_RUN-2148864416"; do
  
  kubectl cp "mereka-lms/${CMS_POD}:/tmp/${course}.tar.gz" "course_tarballs/${course}.tar.gz"
  echo "Downloaded ${course}.tar.gz"
done
```

### Step 3: Import to Local

```bash
# Run import script
./scripts/migrations/import-production-courses.sh course_tarballs

# Or manually import one course
tutor local exec cms -- python manage.py cms import /tmp /path/to/course
```

## 🔍 Verify Import

```bash
# Check course count in modulestore
docker exec tutor_local-mongodb-1 mongosh openedx --quiet --eval \
  "db['modulestore.structures'].countDocuments({})"

# Check course overviews
docker exec -it tutor_local-mysql-1 mysql -uroot -p openedx -e \
  "SELECT id, display_name FROM course_overviews_courseoverview;"

# View in browser
open http://studio.localhost
# Log in with the local admin account created during setup
```

## 📊 Top 5 MCT Courses to Import

Based on enrollment data:

| Course ID | Enrollments | Purpose |
|-----------|-------------|---------|
| `course-v1:MEREKA+MEKA-2148875088+RUN-2148875088` | 52,099 | Most popular |
| `course-v1:MEREKA+MEKA-2148861785+RUN-2148861785` | 10,421 | 2nd most |
| `course-v1:MEREKA+MEKA-2148864393+RUN-2148864393` | 9,708 | 3rd most |
| `course-v1:MEREKA+MEKA-2148864407+RUN-2148864407` | 9,686 | 4th most |
| `course-v1:MEREKA+MEKA-2148864416+RUN-2148864416` | 9,682 | 5th most |

## 🚨 Troubleshooting

### "Course already exists"
```bash
# Delete skeleton course first
docker exec tutor_local-lms-1 python manage.py lms shell -c \
  "from xmodule.modulestore.django import modulestore; \
   from opaque_keys.edx.keys import CourseKey; \
   key = CourseKey.from_string('course-v1:MEREKA+MEKA-2148875088+RUN-2148875088'); \
   modulestore().delete_course(key, 42045)"
```

### "Import failed"
Check CMS logs:
```bash
tutor local logs --tail=100 cms
```

### "No content showing"
Republish course:
1. Go to Studio: http://studio.localhost
2. Open course
3. Click "Publish" button

## 📝 What Gets Imported

From tarball:
- ✅ Course structure (chapters, sections, units)
- ✅ XBlock content (videos, problems, HTML, discussions)
- ✅ Course assets (images, documents)
- ✅ Course settings
- ✅ Grading policy

**NOT imported** (already in MySQL):
- User enrollments (already there)
- User progress (would need separate migration)
- Certificates (would need separate migration)

## 🎓 Alternative: Create Test Course

If you can't access production:

```bash
# Create demo course
docker exec tutor_local-cms-1 python manage.py cms create_course \
  split 42045 edX DemoX Demo_2024 "Demo Course" 2024-01-01

# Access Studio and add content manually
open http://studio.localhost
```

---

**Once imported:** Courses will have full content, videos, assessments, and can be tested end-to-end locally!



