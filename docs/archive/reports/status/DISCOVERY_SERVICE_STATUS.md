# Discovery Service Configuration Status

**Date**: 2026-02-03
**Status**: ⚠️ Partially Configured (Blocked by MongoDB Permissions)

## Summary

The Discovery service is running and accessible at https://discovery.academyv2.mereka.io, but demo course import is blocked by MongoDB Atlas user permissions. Courses must be created manually via Studio UI until permissions are fixed.

## Current State

### Services Status

| Service | Status | URL |
|---------|--------|-----|
| Discovery | ✓ Running | https://discovery.academyv2.mereka.io |
| Studio (CMS) | ✓ Running | https://studio.academyv2.mereka.io |
| LMS | ✓ Running | https://academyv2.mereka.io |
| MFE Apps | ✓ Running | https://apps.academyv2.mereka.io |

### Data Status

| Resource | Count | Notes |
|----------|-------|-------|
| Courses in LMS | 0 | No courses created yet |
| Courses in Discovery | 0 | Waiting for courses to sync |
| Platform Admins | 2 | gurpreet@biji-biji.com, malasari@mereka.my |

## Blocking Issue: MongoDB Permissions

### Problem

The MongoDB Atlas user `cs_comments_user` lacks write permissions to `openedx.modulestore.structures`, preventing:
- Programmatic course import
- Tutor's `importdemocourse` command
- Bulk course operations

### Error

```
pymongo.errors.OperationFailure: user is not allowed to do action [insert]
on [openedx.modulestore.structures], code: 8000, codeName: AtlasError
```

### Resolution Required

Fix MongoDB Atlas permissions by either:
1. **Grant `readWrite` role to `cs_comments_user` on `openedx` database** (Recommended)
2. **Create dedicated Open edX user with full permissions**

See: [MONGODB_PERMISSIONS_ISSUE.md](../operations/MONGODB_PERMISSIONS_ISSUE.md)

## Workaround: Manual Course Creation

Until MongoDB permissions are fixed, create courses via Studio UI:

### Quick Steps

1. **Access Studio**: https://studio.academyv2.mereka.io
2. **Create Course**: Click "New Course"
   - Organization: `MerekaAcademy`
   - Course Number: `DEMO101`
   - Course Run: `2024_Q1`
   - Course Name: `Mereka Academy Demo Course`
3. **Add Content**: Create sections, subsections, and units
4. **Publish Course**: Click "Publish" button
5. **Sync to Discovery**:
   ```bash
   ./scripts/shared/sync-discovery.sh sync
   ```

### Detailed Instructions

See: [DISCOVERY_DEMO_COURSE_SETUP.md](../operations/DISCOVERY_DEMO_COURSE_SETUP.md)

## Tools Created

### 1. Discovery Sync Script

**Location**: `scripts/shared/sync-discovery.sh`

**Usage**:
```bash
# Check status
./scripts/shared/sync-discovery.sh status

# Full sync (refresh metadata + update index)
./scripts/shared/sync-discovery.sh sync

# Sync all courses (not just changed)
./scripts/shared/sync-discovery.sh sync --all

# Show course counts
./scripts/shared/sync-discovery.sh count

# Clear Discovery cache
./scripts/shared/sync-discovery.sh clear-cache
```

**Features**:
- Checks Discovery service health
- Counts courses in LMS and Discovery
- Refreshes course metadata
- Updates search index
- Clear cache
- Color-coded output

### 2. Demo Course Creation Helper

**Location**: `scripts/shared/create-demo-course.sh`

**Usage**:
```bash
# Check MongoDB permissions and show instructions
./scripts/shared/create-demo-course.sh

# Only check permissions
./scripts/shared/create-demo-course.sh --check-only

# Show manual instructions
./scripts/shared/create-demo-course.sh --manual
```

**Features**:
- Detects MongoDB permission issues
- Shows detailed manual course creation steps
- Attempts automatic import if permissions OK
- Color-coded instructions

### 3. Automated Discovery Sync CronJob

**Location**: `deploy/k8s/base/jobs/discovery-sync-cronjob.yaml`

**Deploy**:
```bash
kubectl apply -f deploy/k8s/base/jobs/discovery-sync-cronjob.yaml
```

**Features**:
- Runs every 6 hours
- Refreshes course metadata automatically
- Updates search index
- Keeps 3 successful job history
- Resource limits: 512Mi-1Gi RAM, 250m-500m CPU

## Documentation Created

| Document | Purpose |
|----------|---------|
| [MONGODB_PERMISSIONS_ISSUE.md](../operations/MONGODB_PERMISSIONS_ISSUE.md) | MongoDB permissions problem and fix |
| [DISCOVERY_DEMO_COURSE_SETUP.md](../operations/DISCOVERY_DEMO_COURSE_SETUP.md) | Full setup guide for Discovery and courses |
| [DISCOVERY_QUICKSTART.md](../operations/DISCOVERY_QUICKSTART.md) | Quick reference for common tasks |
| [DISCOVERY_SERVICE_STATUS.md](DISCOVERY_SERVICE_STATUS.md) | This file - overall status |

## Next Steps

### Immediate (Workaround)

1. **Create demo course via Studio UI**
   ```bash
   # Show instructions
   ./scripts/shared/create-demo-course.sh --manual
   ```

2. **Sync to Discovery**
   ```bash
   ./scripts/shared/sync-discovery.sh sync
   ```

3. **Verify in MFE**
   - Open https://apps.academyv2.mereka.io
   - Check course appears in catalog
   - Verify branding is correct

### Required (Fix Root Cause)

1. **Fix MongoDB Atlas permissions**
   - Access MongoDB Atlas console
   - Grant `readWrite` role to `cs_comments_user` on `openedx` database
   - OR create new dedicated user
   - Update Infisical secrets if needed
   - Test with permission verification script

2. **Import demo courses**
   ```bash
   # After MongoDB fix
   CMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=cms -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n mereka-lms $CMS_POD -- bash -c "
     cd /tmp && \
     git clone --depth 1 https://github.com/openedx/openedx-demo-course && \
     pip install 'pymongo[srv]' && \
     python manage.py cms import /tmp/openedx-demo-course demo-course/course
   "
   ```

3. **Deploy automated sync**
   ```bash
   kubectl apply -f deploy/k8s/base/jobs/discovery-sync-cronjob.yaml
   ```

4. **Update Discovery image to include dnspython**
   - Add `RUN pip install "pymongo[srv]"` to Dockerfile
   - Or add to requirements
   - Rebuild and push image

### Optional (Enhancements)

1. **Configure Discovery search (Elasticsearch/Algolia)**
2. **Set up course recommendations**
3. **Configure marketing site integration**
4. **Add more demo courses**
5. **Configure Discovery branding**

## Testing Checklist

After courses are created and synced:

- [ ] Discovery service accessible at https://discovery.academyv2.mereka.io
- [ ] Discovery API returns courses: `/api/v1/courses/`
- [ ] Course count matches between LMS and Discovery
- [ ] MFE shows courses in catalog at https://apps.academyv2.mereka.io
- [ ] Course cards display proper branding
- [ ] Course search works in MFE
- [ ] Course details page shows correct information
- [ ] Enrollment flow works end-to-end
- [ ] CronJob successfully syncs courses every 6 hours
- [ ] Discovery cache clears properly

## Quick Reference Commands

```bash
# Check everything
./scripts/shared/sync-discovery.sh status

# Create course (manual instructions)
./scripts/shared/create-demo-course.sh --manual

# Sync courses to Discovery
./scripts/shared/sync-discovery.sh sync

# Check MongoDB permissions
./scripts/shared/create-demo-course.sh --check-only

# View Discovery logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=discovery --tail=50

# Restart Discovery
kubectl rollout restart deployment/discovery -n mereka-lms

# Access Discovery shell
DISCOVERY_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n mereka-lms $DISCOVERY_POD -- python manage.py shell
```

## Related Files

### Scripts
- `scripts/shared/sync-discovery.sh`
- `scripts/shared/create-demo-course.sh`

### Kubernetes Manifests
- `deploy/k8s/base/jobs/discovery-sync-cronjob.yaml`

### Documentation
- `docs/operations/MONGODB_PERMISSIONS_ISSUE.md`
- `docs/operations/DISCOVERY_DEMO_COURSE_SETUP.md`
- `docs/operations/DISCOVERY_QUICKSTART.md`

## Support

For issues or questions, refer to:
- MongoDB permissions: [MONGODB_PERMISSIONS_ISSUE.md](../operations/MONGODB_PERMISSIONS_ISSUE.md)
- Discovery setup: [DISCOVERY_DEMO_COURSE_SETUP.md](../operations/DISCOVERY_DEMO_COURSE_SETUP.md)
- General troubleshooting: [TROUBLESHOOTING.md](../operations/TROUBLESHOOTING.md)
