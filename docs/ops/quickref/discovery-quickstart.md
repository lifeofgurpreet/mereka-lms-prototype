# Discovery Service Quick Start
_Audience: Platform Operators • Owner: Ops Domain Owner • Last verified: 2026-03-06 • Status: supporting_

Quick reference for working with the Discovery service (course catalog).

## TL;DR

```bash
# Check status
./scripts/shared/sync-discovery.sh status

# Create course (Studio UI)
open https://studio.academyv2.mereka.io

# Sync to Discovery
./scripts/shared/sync-discovery.sh sync

# View courses
open https://discovery.academyv2.mereka.io/api/v1/courses/
```

## Current Status

- **Discovery URL**: https://discovery.academyv2.mereka.io
- **Health Check**: https://discovery.academyv2.mereka.io/health/
- **Courses in LMS**: 0 (as of 2026-02-03)
- **Courses in Discovery**: 0 (as of 2026-02-03)

## Known Issues

### MongoDB Permissions

**Issue**: Cannot import demo courses programmatically due to MongoDB Atlas user permissions.

**Error**:
```
pymongo.errors.OperationFailure: user is not allowed to do action [insert]
on [openedx.modulestore.structures]
```

**Workaround**: Create courses via Studio UI at https://studio.academyv2.mereka.io

**Details**: See [MONGODB_PERMISSIONS_ISSUE.md](../../ops/runbooks/MONGODB_PERMISSIONS_ISSUE.md)

## Quick Tasks

### Create a Demo Course

1. Navigate to https://studio.academyv2.mereka.io
2. Log in as a platform admin (e.g., `gurpreet@biji-biji.com` or `malasari@mereka.my`)
3. Click "New Course"
4. Fill in:
   - Organization: `MerekaAcademy`
   - Course Number: `DEMO101`
   - Course Run: `2024_Q1`
   - Course Name: `Mereka Academy Demo Course`
5. Add content (minimum):
   - Section: "Getting Started"
   - Subsection: "Welcome"
   - Unit: "Introduction"
6. Publish course

### Sync Course to Discovery

```bash
# After creating course in Studio
./scripts/shared/sync-discovery.sh sync
```

### Check Course Counts

```bash
./scripts/shared/sync-discovery.sh count
```

Output:
```
Total courses in LMS: 1
Total courses in Discovery: 1
```

### Clear Discovery Cache

```bash
./scripts/shared/sync-discovery.sh clear-cache
```

## Automated Sync

Deploy CronJob for automatic syncing every 6 hours:

```bash
kubectl apply -f deploy/k8s/base/jobs/discovery-sync-cronjob.yaml
```

Check CronJob status:
```bash
kubectl get cronjobs -n mereka-lms discovery-sync
kubectl get jobs -n mereka-lms -l app.kubernetes.io/name=discovery-sync
```

## API Access

### Public Catalog (No Auth)

```bash
curl https://discovery.academyv2.mereka.io/api/v1/courses/ | jq .
```

### Authenticated Access

1. Get OAuth2 token from LMS
2. Use token in Authorization header

```bash
# Get token (requires OAuth2 client credentials)
TOKEN=$(curl -X POST https://academyv2.mereka.io/oauth2/access_token/ \
  -d "grant_type=client_credentials" \
  -d "client_id=<client-id>" \
  -d "client_secret=<client-secret>" | jq -r '.access_token')

# Query Discovery
curl -H "Authorization: Bearer $TOKEN" \
  https://discovery.academyv2.mereka.io/api/v1/courses/ | jq .
```

## Troubleshooting

### No courses showing in Discovery

```bash
# 1. Check LMS has courses
./scripts/shared/sync-discovery.sh count

# 2. Refresh metadata
./scripts/shared/sync-discovery.sh refresh --all

# 3. Update index
./scripts/shared/sync-discovery.sh index

# 4. Clear cache
./scripts/shared/sync-discovery.sh clear-cache

# 5. Full sync
./scripts/shared/sync-discovery.sh sync --all
```

### Discovery pod not running

```bash
# Check pod status
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery

# Check logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=discovery --tail=100

# Restart pod
kubectl rollout restart deployment/discovery -n mereka-lms
```

### Database connection errors

```bash
# Check database secrets
kubectl get secret -n mereka-lms database-secrets -o jsonpath='{.data}' | jq .

# Test Discovery database connection
DISCOVERY_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n mereka-lms $DISCOVERY_POD -- python manage.py dbshell
```

## Related Documentation

- **Full Setup Guide**: [DISCOVERY_DEMO_COURSE_SETUP.md](../../ops/runbooks/DISCOVERY_DEMO_COURSE_SETUP.md)
- **MongoDB Issue**: [MONGODB_PERMISSIONS_ISSUE.md](../../ops/runbooks/MONGODB_PERMISSIONS_ISSUE.md)
- **General Troubleshooting**: [TROUBLESHOOTING.md](../../operations/TROUBLESHOOTING.md)

## Manual Commands

If the script doesn't work, use these direct kubectl commands:

```bash
# Get pod name
DISCOVERY_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery -o jsonpath='{.items[0].metadata.name}')

# Refresh metadata
kubectl exec -n mereka-lms $DISCOVERY_POD -- \
  python manage.py refresh_course_metadata

# Update index
kubectl exec -n mereka-lms $DISCOVERY_POD -- \
  python manage.py update_index --disable-change-limit

# Check course count
kubectl exec -n mereka-lms $DISCOVERY_POD -- \
  python manage.py shell -c \
  "from course_discovery.apps.course_metadata.models import Course; print(Course.objects.count())"
```

## Next Steps

1. **Fix MongoDB permissions** - See [MONGODB_PERMISSIONS_ISSUE.md](../../ops/runbooks/MONGODB_PERMISSIONS_ISSUE.md)
2. **Create demo courses** - Use Studio UI or import after MongoDB fix
3. **Deploy CronJob** - Automate Discovery syncing
4. **Test MFE integration** - Verify course catalog displays correctly
5. **Configure branding** - Apply Mereka branding to course pages
