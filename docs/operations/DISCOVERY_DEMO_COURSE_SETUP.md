# Discovery Service Demo Course Setup

## Overview

This guide explains how to create demo courses and configure the Discovery service to index and display them in the course catalog.

## Prerequisites

- Admin access to Studio (https://studio.academyv2.mereka.io)
- Platform admin access (e.g., `gurpreet@biji-biji.com` or `malasari@mereka.my`)
- Discovery service running at https://discovery.academyv2.mereka.io

## Method 1: Create Course via Studio UI (Current Workaround)

Due to MongoDB permissions (see `MONGODB_PERMISSIONS_ISSUE.md`), courses must be created through the Studio UI.

### Step 1: Access Studio

1. Navigate to https://studio.academyv2.mereka.io
2. Log in with admin credentials
3. Click "New Course" button

### Step 2: Create Demo Course

Fill in course details:

```
Organization: MerekaAcademy
Course Number: DEMO101
Course Run: 2024_Q1
Course Name: Mereka Academy Demo Course
```

### Step 3: Add Course Content

Minimum content for a functional demo:

1. **Course Outline**:
   - Section 1: "Getting Started"
     - Subsection 1.1: "Welcome"
       - Unit: "Introduction" (HTML block with welcome text)

2. **About Page** (Settings > Schedule & Details):
   ```
   Title: Mereka Academy Demo Course

   Subtitle: Learn the Basics

   Description:
   This is a demonstration course showcasing the Mereka Academy platform.
   Explore our interactive learning environment and experience the future of education.

   Key Features:
   - Interactive video content
   - Self-paced learning
   - Mobile-friendly interface
   - Progress tracking
   ```

3. **Course Image**: Upload a course card image (1080x608px recommended)

4. **Course Settings**:
   - Enrollment Start: Current date
   - Enrollment End: 1 year from now
   - Course Start: Current date
   - Course End: 1 year from now
   - Visibility: "Public"

### Step 4: Publish Course

1. In Studio, go to Settings > Schedule & Details
2. Click "Publish" button
3. Verify course is published (green checkmark)

## Method 2: Import Demo Course (After MongoDB Fix)

Once MongoDB permissions are fixed (see `MONGODB_PERMISSIONS_ISSUE.md`):

### Step 1: Get CMS Pod Name

```bash
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=cms | grep Running | awk '{print $1}'
```

### Step 2: Clone Demo Course Repo

```bash
CMS_POD=<cms-pod-name>
kubectl exec -n mereka-lms $CMS_POD -- bash -c "
  cd /tmp && \
  rm -rf openedx-demo-course && \
  git clone --depth 1 https://github.com/openedx/openedx-demo-course
"
```

### Step 3: Import Course

```bash
kubectl exec -n mereka-lms $CMS_POD -- \
  python manage.py cms import /tmp/openedx-demo-course demo-course/course
```

### Step 4: Verify Import

```bash
kubectl exec -n mereka-lms $CMS_POD -- python manage.py cms shell -c "
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
print(f'Total courses: {CourseOverview.objects.count()}')
for course in CourseOverview.objects.all():
    print(f'  - {course.display_name} ({course.id})')
"
```

## Configure Discovery Service

### Step 1: Verify Discovery Service Status

```bash
# Check pod status
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery

# Check service health
curl https://discovery.academyv2.mereka.io/health/
```

### Step 2: Refresh Discovery Index

The Discovery service needs to sync course data from LMS/CMS:

```bash
DISCOVERY_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=discovery -o jsonpath='{.items[0].metadata.name}')

# Refresh course metadata
kubectl exec -n mereka-lms $DISCOVERY_POD -- \
  python manage.py refresh_course_metadata

# Rebuild Elasticsearch index (if using Elasticsearch)
kubectl exec -n mereka-lms $DISCOVERY_POD -- \
  python manage.py update_index --disable-change-limit
```

### Step 3: Verify Courses in Discovery

```bash
# Get OAuth2 token first (requires LMS access)
TOKEN=$(curl -X POST https://academyv2.mereka.io/oauth2/access_token/ \
  -d "grant_type=client_credentials" \
  -d "client_id=<discovery-oauth-client-id>" \
  -d "client_secret=<discovery-oauth-client-secret>" | jq -r '.access_token')

# Query Discovery API
curl -H "Authorization: Bearer $TOKEN" \
  https://discovery.academyv2.mereka.io/api/v1/courses/ | jq .
```

Or check via browser (if public catalog enabled):
```
https://discovery.academyv2.mereka.io/api/v1/catalogs/1/courses/
```

## Verify Course Display in MFE

### Test Course Catalog

1. Navigate to https://apps.academyv2.mereka.io/
2. Check if courses appear in the catalog
3. Verify course cards show proper branding
4. Click on a course to view details

### Test Course Discovery

1. Use search functionality
2. Filter by subject/organization
3. Verify all metadata displays correctly

## Automated Discovery Sync

Set up a CronJob to periodically sync courses to Discovery:

```yaml
# deploy/k8s/base/jobs/discovery-sync-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: discovery-sync
  namespace: mereka-lms
spec:
  schedule: "0 */6 * * *"  # Every 6 hours
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: discovery
          containers:
          - name: sync
            image: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:20260204-dnspython
            command:
            - /bin/bash
            - -c
            - |
              python manage.py refresh_course_metadata
              python manage.py update_index --disable-change-limit
            envFrom:
            - secretRef:
                name: openedx-secrets
            - configMapRef:
                name: discovery-config
          restartPolicy: OnFailure
```

Apply the CronJob:
```bash
kubectl apply -f deploy/k8s/base/jobs/discovery-sync-cronjob.yaml
```

## Troubleshooting

### Discovery shows no courses

1. **Check LMS has courses**:
   ```bash
   LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}')
   kubectl exec -n mereka-lms $LMS_POD -- python manage.py lms shell -c "
   from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
   print(f'Total courses: {CourseOverview.objects.count()}')
   "
   ```

2. **Check Discovery database connection**:
   ```bash
   kubectl exec -n mereka-lms $DISCOVERY_POD -- python manage.py dbshell
   ```

3. **Check Discovery logs**:
   ```bash
   kubectl logs -n mereka-lms $DISCOVERY_POD --tail=100
   ```

4. **Manually trigger sync**:
   ```bash
   kubectl exec -n mereka-lms $DISCOVERY_POD -- \
     python manage.py refresh_course_metadata --all
   ```

### Course metadata not updating

- Discovery caches course data. Clear cache:
  ```bash
  kubectl exec -n mereka-lms $DISCOVERY_POD -- \
    python manage.py shell -c "from django.core.cache import cache; cache.clear()"
  ```

### Authentication errors accessing Discovery API

- Verify OAuth2 client credentials are correct
- Check Discovery service JWT configuration matches LMS
- Verify `DISCOVERY_BACKEND_OAUTH2_SECRET` in secrets

## Related Documentation

- [MongoDB Permissions Issue](./MONGODB_PERMISSIONS_ISSUE.md)
- [Discovery Service Configuration](../architecture/DISCOVERY_SERVICE.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

## Next Steps

1. Create demo course via Studio UI
2. Configure Discovery sync
3. Verify course catalog displays correctly
4. Test MFE course browsing experience
5. Apply Mereka branding to course content
6. Set up automated sync CronJob
