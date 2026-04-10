# Discovery Service Quick Start
_Audience: Platform Operators • Owner: Ops Domain Owner • Last verified: 2026-03-06 • Status: supporting_

Quick reference for working with the Discovery service as it exists today.
Discovery is currently compatibility plumbing, not the canonical learner browse
surface. Production edx-platform course/forum search is now on Meilisearch; do
not use the Discovery root or its Elasticsearch-oriented UI as evidence for the
platform search backend.

## TL;DR

```bash
# Check status
./scripts/shared/sync-discovery.sh status

# Create course (Studio UI)
open https://studio.academyv2.mereka.io

# Sync to Discovery
./scripts/shared/sync-discovery.sh sync

# Verify health
curl -sS https://discovery.academyv2.mereka.io/health/

# Verify the current auth contract for the courses API
curl -i https://discovery.academyv2.mereka.io/api/v1/courses/
```

## Current Runtime Contract

- **Discovery URL**: https://discovery.academyv2.mereka.io
- **Health Check**: https://discovery.academyv2.mereka.io/health/
- **Courses API in production**: do not assume anonymous access; re-prove the current auth contract in the target lane
- **Discovery data population**: treat live counts as evidence-ledger material, not durable quickref truth
- **Discovery sync CronJob**: verify live presence and schedule in the target lane before assuming continuous sync

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
2. Log in as a platform admin with Studio access
3. Click "New Course"
4. Fill in:
   - Organization: your operator-approved org
   - Course Number: a temporary demo identifier
   - Course Run: the intended test run label
   - Course Name: a clearly marked demo course title
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

Deploy the sync CronJob only if you intend to operate Discovery as a live synced
catalog source in that environment:

```bash
kubectl apply -f deploy/k8s/base/jobs/discovery-sync-cronjob.yaml
```

Check CronJob status:
```bash
kubectl get cronjobs -n mereka-lms discovery-sync
kubectl get jobs -n mereka-lms -l app.kubernetes.io/name=discovery-sync
```

## API Access

### Courses API

```bash
curl -i https://discovery.academyv2.mereka.io/api/v1/courses/
```

Do not assume this is anonymous. Re-prove the status code in the target lane.

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
- **General Troubleshooting**: [TROUBLESHOOTING.md](../runbooks/TROUBLESHOOTING.md)

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

1. Re-prove whether Discovery is still needed for the learner browse path in the target lane.
2. If Discovery remains in use, deploy and verify the sync CronJob explicitly.
3. Do not treat Discovery API `200` or non-empty data as assumed defaults; verify them.
4. Prefer the Catalog MFE path for future browse-surface work where viable.
