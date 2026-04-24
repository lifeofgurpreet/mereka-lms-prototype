# MCT Course Import - COMPLETE

**Date**: 2025-12-18
**Task**: Import 15 NEW MCT category courses to Open edX
**Status**: ✅ SUCCESSFUL - All 15 courses imported

---

## Summary

Successfully imported 15 NEW MCT courses to the Open edX platform running in Kubernetes (namespace: `mereka-lms`). The system now has **30 total MCT courses** (15 existing + 15 new).

---

## NEW Courses Imported (15)

### High-Enrollment Priority Courses
1. **MCT-20**: Developer (278K enrollments)
2. **MCT-19**: Pursuing a career in Data Analytics (207K enrollments)
3. **MCT-21**: Digital Marketing (183K enrollments)
4. **MCT-17**: Pursuing a career in Project Management (170K enrollments)

### Other NEW Courses
5. **MCT-4**: Productivity with Microsoft 365 (Bahasa)
6. **MCT-28**: VN Mastering Digital Tools - Thu hẹp khoảng cách số
7. **MCT-29**: TEST Virtual Assistant
8. **MCT-34**: FOW (ENG) | Personal Well-being
9. **MCT-36**: FOW (ENG) | Managing Your First Client
10. **MCT-37**: FOW (ENG) | Freelancing 101
11. **MCT-38**: FOW (ENG) | Skills Profiling
12. **MCT-39**: FOW (ENG) | Securing Your First Client
13. **MCT-40**: FOW (ENG) | Securing Your First Job
14. **MCT-41**: FOW (ENG) | Thriving In Your Job
15. **MCT-47**: Gaming Garage with HP

---

## Existing Courses (NOT Reimported)

Category IDs: 1, 14, 15, 16, 22, 24, 27, 30, 31, 32, 33, 35, 44, 45, 46

These 15 courses already existed in the system and were intentionally skipped.

---

## Import Details

### Package Information
- **Base Directory**: `/var/migrations/mct/course_packages_category/`
- **Manifest**: `course_packages_manifest.csv`
- **Package Format**: `{slug}/{slug}.tar.gz`

### Course Key Format
```
course-v1:SKILLOURFUTURE+MCT-{CategoryId}+course
```

### Import Location
- **Namespace**: `mereka-lms`
- **CMS Pod**: `cms-c59dd9667-7vg4h`

### Import Method
Used `python manage.py cms import` command within the CMS pod:
```bash
python manage.py cms import /tmp/course_import_base {slug}
```

---

## Infrastructure Fixes Applied

During the import process, discovered and fixed critical service selector mismatches that were preventing database connectivity:

### Service Selector Fixes
1. **MySQL**: Fixed selector from `openedx-LgWN9sbtTjHHjIJifx3l0YkY` to `mereka-lms`
   - Endpoints: `10.100.2.6:3306` ✅
2. **MongoDB**: Fixed selector from `openedx-LgWN9sbtTjHHjIJifx3l0YkY` to `mereka-lms`
   - Endpoints: `10.100.3.6:27017` ✅
3. **Redis**: Fixed selector from `openedx-LgWN9sbtTjHHjIJifx3l0YkY` to `mereka-lms`
   - Endpoints: `10.100.3.5:6379` ✅
4. **Elasticsearch**: Fixed selector from `openedx-LgWN9sbtTjHHjIJifx3l0YkY` to `mereka-lms`
   - Endpoints: `10.100.2.5:9200` ✅

### Fix Commands Used
```bash
kubectl patch svc mysql -n mereka-lms -p '{"spec":{"selector":{"app.kubernetes.io/instance":"mereka-lms","app.kubernetes.io/name":"mysql","app.kubernetes.io/part-of":"mereka-lms"}}}'
kubectl patch svc mongodb -n mereka-lms -p '{"spec":{"selector":{"app.kubernetes.io/instance":"mereka-lms","app.kubernetes.io/name":"mongodb","app.kubernetes.io/part-of":"mereka-lms"}}}'
kubectl patch svc redis -n mereka-lms -p '{"spec":{"selector":{"app.kubernetes.io/instance":"mereka-lms","app.kubernetes.io/name":"redis","app.kubernetes.io/part-of":"mereka-lms"}}}'
kubectl patch svc elasticsearch -n mereka-lms -p '{"spec":{"selector":{"app.kubernetes.io/instance":"mereka-lms","app.kubernetes.io/name":"elasticsearch","app.kubernetes.io/part-of":"mereka-lms"}}}'
```

---

## Scripts Created

### `/home/dev/code/mereka-lms/scripts/import-mct-batch.sh`
Final working script that successfully imported all 15 courses. Key features:
- Copies course tar.gz to CMS pod
- Extracts and imports using Django management command
- Suppresses verbose output for cleaner execution
- Verifies all courses at the end

### Other Scripts Attempted
- `/home/dev/code/mereka-lms/scripts/import-new-mct-courses.py` - Python version (had output capture issues)
- `/home/dev/code/mereka-lms/scripts/import-new-mct-courses.sh` - Bash version with verbose logging

---

## Verification

### Total Course Count
```bash
kubectl exec -n mereka-lms cms-c59dd9667-7vg4h -- bash -c \
  "cd /openedx/edx-platform && python manage.py cms dump_course_ids 2>/dev/null" | grep -c MCT
# Output: 30
```

### All MCT Courses in System
```
course-v1:SKILLOURFUTURE+MCT-1+course
course-v1:SKILLOURFUTURE+MCT-4+course
course-v1:SKILLOURFUTURE+MCT-14+course
course-v1:SKILLOURFUTURE+MCT-15+course
course-v1:SKILLOURFUTURE+MCT-16+course
course-v1:SKILLOURFUTURE+MCT-17+course
course-v1:SKILLOURFUTURE+MCT-19+course
course-v1:SKILLOURFUTURE+MCT-20+course
course-v1:SKILLOURFUTURE+MCT-21+course
course-v1:SKILLOURFUTURE+MCT-22+RUN-22
course-v1:SKILLOURFUTURE+MCT-24+course
course-v1:SKILLOURFUTURE+MCT-27+course
course-v1:SKILLOURFUTURE+MCT-28+course
course-v1:SKILLOURFUTURE+MCT-29+course
course-v1:SKILLOURFUTURE+MCT-30+course
course-v1:SKILLOURFUTURE+MCT-31+course
course-v1:SKILLOURFUTURE+MCT-32+course
course-v1:SKILLOURFUTURE+MCT-33+course
course-v1:SKILLOURFUTURE+MCT-34+course
course-v1:SKILLOURFUTURE+MCT-35+course
course-v1:SKILLOURFUTURE+MCT-36+course
course-v1:SKILLOURFUTURE+MCT-37+course
course-v1:SKILLOURFUTURE+MCT-38+course
course-v1:SKILLOURFUTURE+MCT-39+course
course-v1:SKILLOURFUTURE+MCT-40+course
course-v1:SKILLOURFUTURE+MCT-41+course
course-v1:SKILLOURFUTURE+MCT-44+course
course-v1:SKILLOURFUTURE+MCT-45+course
course-v1:SKILLOURFUTURE+MCT-46+course
course-v1:SKILLOURFUTURE+MCT-47+course
```

---

## Errors Encountered and Resolved

### 1. Service Selector Mismatches
**Error**: `Can't connect to MySQL server on 'mysql:3306' (111)`
**Cause**: Kubernetes service selectors were using old instance ID `openedx-LgWN9sbtTjHHjIJifx3l0YkY` instead of `mereka-lms`
**Resolution**: Patched all database services with correct selectors

### 2. Empty Endpoints
**Error**: Services showed `<none>` for endpoints
**Cause**: Service selector mismatch prevented routing to pods
**Resolution**: Fixed via `kubectl patch svc` commands

### 3. Output Capture in Scripts
**Issue**: Python and initial bash scripts couldn't capture full output from kubectl exec
**Resolution**: Created simplified script that focuses on execution rather than detailed logging

---

## Next Steps

All 15 NEW courses are now available in Open edX. Recommended next actions:

1. **Verify Course Content**: Check that courses display correctly in Studio
2. **Test Enrollment**: Create test enrollments for high-priority courses
3. **Enable Courses**: Update course settings to make them visible to students
4. **Configure Certificates**: Set up certificate generation for completed courses
5. **Monitor Performance**: Watch resource usage with 30 total courses

---

## Related Documentation

- **MCT Migration Guide**: `/home/dev/code/mereka-lms/docs/migrations/mct/`
- **Course Package Manifest**: `/home/dev/code/mereka-lms/var/migrations/mct/course_packages_category/course_packages_manifest.csv`
- **Troubleshooting Guide**: `/home/dev/code/mereka-lms/docs/ops/runbooks/TROUBLESHOOTING.md`
- **Service Selector Fix Script**: `/home/dev/code/mereka-lms/scripts/infra/fix-service-selectors.sh`

---

**Import Completed**: 2025-12-18 08:16 UTC
**Final Status**: ✅ All 15 NEW courses successfully imported and verified
