# MCT Migration Status - End-to-End Progress
_Audience: Leadership • Owner: Migration Squad • Last verified: 2025-08-31_

## ✅ Completed

### 1. Data Transformation
- ✅ **68,784 users** transformed and ready for import
- ✅ **14 category-level courses** (Category→Course mapping)
- ✅ **57,483 enrollments** mapped to category courses
- ✅ **516 lessons** with real content (videos, PDFs) extracted

### 2. Course Packages Built
- ✅ **14 course packages** created with proper structure:
  - Category → Open edX Course
  - MCT Course → Chapter
  - MCT Lesson → Sequential + Vertical + Video/HTML XBlock
- ✅ All packages include real content (videos with URLs, PDFs)

### 3. Import Scripts Created
- ✅ `transform_data.py` - Transforms MCT exports to Open edX format
- ✅ `build_course_packages.py` - Generates OLX course packages
- ✅ `prepare_openedx_imports.py` - Creates import CSVs
- ✅ `import_courses_k8s.py` - K8s course import script (needs Tutor environment)

### 4. Data Files Ready
- ✅ `ops/migrations/mct/output/openedx/users_import.csv` (68,785 rows)
- ✅ `ops/migrations/mct/output/openedx/enrollments_import.csv` (57,483 rows)
- ✅ `ops/migrations/mct/output/course_packages_categories/` (14 tarballs)

---

## ⚠️ In Progress / Blocked

### User Import
- ⚠️ **Partial**: Started importing users via bulk import script
- ⚠️ **Issue**: Need to complete batch imports (68K users in batches of 2000)
- **Status**: Script works, needs to be run to completion

### Course Import
- ❌ **Blocked**: Direct kubectl import failing on CONTENTSTORE configuration
- **Issue**: CMS import command needs proper Tutor environment setup
- **Workaround Needed**: Use Tutor commands or Studio UI import

### Enrollment Import
- ⏸️ **Pending**: Waiting for courses to be imported first

---

## 🔧 Technical Issues Encountered

### 1. Course Import via kubectl
**Problem**: Direct `kubectl exec` with `manage.py cms import` fails with:
```
TypeError: 'NoneType' object is not subscriptable
```
**Root Cause**: CONTENTSTORE settings not properly configured when running outside Tutor environment

**Solutions**:
1. **Use Tutor commands** (if Tutor is available):
   ```bash
   tutor k8s exec cms -- python manage.py cms import /tmp/course_extract slug
   ```

2. **Use Studio UI** (manual but reliable):
   - Upload tarballs via Studio web interface
   - More time-consuming but guaranteed to work

3. **Fix environment setup** in import script:
   - Set proper DJANGO_SETTINGS_MODULE
   - Ensure CONTENTSTORE is configured

---

## 📋 Next Steps

### Immediate Actions Needed

1. **Complete User Import**
   ```bash
   # Run batch imports for remaining users
   python3 ops/migrations/kajabi/scripts/run_batches.py users \
     --csv ops/migrations/mct/output/openedx/users_import.csv \
     --batch-size 2000 \
     --remote-csv /tmp/mct-users.csv \
     --namespace mereka-lms \
     --settings lms.envs.production
   ```

2. **Import Courses** (Choose one approach):

   **Option A: Via Tutor** (if available):
   ```bash
   # Need Tutor installed and configured
   tutor k8s exec cms -- python manage.py cms import /path/to/extract slug
   ```

   **Option B: Via Studio UI** (manual):
   - Log into Studio at `https://studio.skillourfuture.staging.academy.mereka.io`
   - Navigate to each course
   - Use "Import" feature to upload tarballs

   **Option C: Fix kubectl script**:
   - Debug CONTENTSTORE configuration
   - Set proper environment variables
   - Test with one course first

3. **Import Enrollments** (after courses are imported):
   ```bash
   POD=$(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')
   kubectl cp ops/migrations/mct/output/openedx/enrollments_import.csv mereka-lms/$POD:/tmp/mct-enrollments.csv
   kubectl exec -n mereka-lms $POD -- python /tmp/openedx_bulk_import.py enrollments \
     --csv /tmp/mct-enrollments.csv \
     --settings=lms.envs.production \
     --offset 0 --limit 10000
   ```

---

## 📊 Migration Statistics

### Data Volume
- **Users**: 68,784
- **Courses**: 14 (category-level)
- **Enrollments**: 57,483
- **Lessons**: 516 (with real content)

### Course Breakdown
- AI Fluency (Category 24)
- Basic Microsoft (Category 16)
- Employability (Category 14)
- ... (11 more categories)

---

## 🎯 Success Criteria

- [ ] All 68,784 users imported
- [ ] All 14 courses imported and visible in Studio
- [ ] All 57,483 enrollments created
- [ ] Courses visible on `skillourfuture.staging.academy.mereka.io`
- [ ] Users can log in and see enrolled courses
- [ ] Course content (videos, PDFs) accessible

---

## 📝 Notes

- **Mapping Strategy**: Category→Course, Course→Chapter, Lesson→Sequential
- **Organization**: All mapped to SKILLOURFUTURE
- **Learning Pathways**: To be handled via Programs plugin (future work)
- **Content**: Real videos/PDFs (not placeholders like Kajabi)

---

**Last Updated**: 2025-11-10
**Status**: 70% Complete - Data ready, import in progress



