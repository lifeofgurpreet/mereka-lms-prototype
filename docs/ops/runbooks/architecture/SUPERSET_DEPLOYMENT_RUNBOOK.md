# Superset Deployment Runbook

<!-- @covers AC-SUPRT-001, AC-SUPRT-002 -->
<!-- @spec: analytics-pipeline_spec.md -->

**Status**: DEFERRED (per ADR-017)
**Last updated**: 2026-02-17

## Purpose

This runbook documents the deployment, configuration, and operational procedures for Apache Superset as part of the Aspects analytics stack. **This deployment is currently DEFERRED** — see ADR-017 for decision rationale.

When analytics deployment is approved, this runbook provides the canonical procedures for Superset setup, authentication integration, dashboard configuration, and operational maintenance.

## Prerequisites

Before deploying Superset, ensure:

1. **Core platform stability**: 3+ consecutive months with no critical incidents
2. **Course creator demand**: Explicit requests for learning analytics features
3. **Team capacity**: Bandwidth for ClickHouse/Superset operations
4. **Analytics spec approved**: `specs/analytics-pipeline_spec.md` status changed to "approved"
5. **ADR-017 status updated**: Change from "Deferred" to "Accepted"

## Infrastructure Components

### Stack Overview

| Component | Purpose | Resource Requirements |
|-----------|---------|----------------------|
| **ClickHouse** | Analytics data warehouse | 2Gi-4Gi memory, 500m-2 CPU |
| **Superset** | Visualization & dashboards | 1Gi-2Gi memory, 250m-1 CPU |
| **Superset Worker** | Async query execution | 512Mi-1Gi memory, 200m-500m CPU |
| **Ralph** | xAPI event processing | (embedded in Aspects) |

**Total cluster resources**: ~3.5Gi memory request, 7Gi limit

### Storage Requirements

- **ClickHouse PVC**: 20Gi minimum (recommend 50Gi for 90-day retention)
- **Backup storage**: GCS bucket for ClickHouse exports
- **Estimated costs**: ~$50/month for 90-day retention with compression

## Authentication Integration

### Option 1: OAuth2 via Open edX LMS (Recommended)

**Rationale**: Seamless SSO for staff users, unified user management.

**Configuration**:

```yaml
# In Superset config (configmaps.yml)
AUTH_TYPE = AUTH_OAUTH
OAUTH_PROVIDERS = [
  {
    'name': 'openedx',
    'icon': 'fa-graduation-cap',
    'token_key': 'access_token',
    'remote_app': {
      'client_id': 'superset-oauth-client',
      'client_secret': '{{ SUPERSET_OAUTH_SECRET }}',
      'api_base_url': 'https://academyv2.mereka.io/',
      'access_token_url': 'https://academyv2.mereka.io/oauth2/access_token/',
      'authorize_url': 'https://academyv2.mereka.io/oauth2/authorize/',
      'client_kwargs': {
        'scope': 'read write'
      }
    }
  }
]
```

**Setup steps**:

1. Create OAuth2 application in LMS Django admin:
   - Navigate to `/admin/oauth2_provider/application/`
   - Client type: Confidential
   - Authorization grant type: Authorization code
   - Redirect URIs: `https://analytics.academyv2.mereka.io/oauth-authorized/openedx`
   - Name: "Superset Analytics"

2. Store client secret in GCP Secret Manager:
   ```bash
   printf '%s' 'CLIENT_SECRET_FROM_LMS' | \
     gcloud secrets create MEREKA_LMS_SUPERSET_OAUTH_SECRET \
       --project=bbi-k8 \
       --data-file=-
   ```

3. Add ExternalSecret mapping in `deploy/k8s/base/secrets/external-secrets.yaml`

**User role mapping**:
- **LMS Staff** → Superset Gamma role (view dashboards)
- **LMS Admins** → Superset Admin role (create dashboards)
- **Course instructors** → Filtered dashboards (own courses only)

### Option 2: Standalone Admin Account (Local Dev)

**Use case**: Local development, internal testing.

**Default credentials**:
- Username: `admin`
- Password: Set via `SUPERSET_ADMIN_PASSWORD` secret

**Not recommended for production** — no SSO, requires manual user provisioning.

## Dashboard Templates

### Pre-built Dashboards

When Aspects deploys Superset, the following dashboards are automatically provisioned:

#### 1. Enrollment Dashboard
**Purpose**: Track course enrollment trends over time.

**Metrics**:
- Total enrollments (current week vs previous week)
- Enrollment funnel (viewed course → enrolled)
- Top 10 courses by enrollment
- Enrollment by cohort/country

**ClickHouse query**:
```sql
SELECT
  toStartOfWeek(event_date) AS week,
  course_id,
  count(DISTINCT user_id) AS enrollments
FROM xapi_events_all
WHERE verb = 'enrolled'
  AND event_date >= today() - 90
GROUP BY week, course_id
ORDER BY week DESC, enrollments DESC
```

#### 2. Completion Dashboard
**Purpose**: Monitor course completion rates and identify struggling learners.

**Metrics**:
- Overall completion rate (completed / enrolled)
- Average time to completion (days)
- Completion rate by course section
- Learners at risk (no activity in 7+ days)

**ClickHouse query**:
```sql
SELECT
  course_id,
  countIf(completed = 1) / count(*) AS completion_rate,
  avg(completion_days) AS avg_completion_time
FROM (
  SELECT
    course_id,
    user_id,
    maxIf(event_date, verb = 'completed') AS completed_date,
    minIf(event_date, verb = 'enrolled') AS enrolled_date,
    dateDiff('day', enrolled_date, completed_date) AS completion_days,
    if(completed_date IS NOT NULL, 1, 0) AS completed
  FROM xapi_events_all
  WHERE verb IN ('enrolled', 'completed')
  GROUP BY course_id, user_id
)
GROUP BY course_id
```

#### 3. Engagement Dashboard
**Purpose**: Measure learner engagement and content effectiveness.

**Metrics**:
- Daily/weekly active users
- Average session duration
- Problem attempt success rate
- Video completion rate
- Most/least viewed units

**ClickHance query**:
```sql
SELECT
  toStartOfDay(event_date) AS day,
  countDistinct(user_id) AS daily_active_users,
  count() AS total_events,
  countIf(verb = 'viewed') AS content_views,
  countIf(verb = 'interacted') AS interactions
FROM xapi_events_all
WHERE event_date >= today() - 30
GROUP BY day
ORDER BY day DESC
```

#### 4. Platform Health Dashboard
**Purpose**: Monitor analytics pipeline health and query performance.

**Metrics**:
- Event processing lag (minutes)
- ClickHouse query response time (p50, p95)
- Failed event processing jobs
- Storage utilization

**ClickHouse query**:
```sql
SELECT
  toStartOfHour(event_date) AS hour,
  count() AS events_processed,
  max(event_date) AS latest_event,
  dateDiff('minute', max(event_date), now()) AS lag_minutes
FROM xapi_events_all
WHERE event_date >= today() - 1
GROUP BY hour
ORDER BY hour DESC
```

## Access Control

### Role-Based Access Control (RBAC)

**Superset roles**:

| Role | Permissions | Assigned To |
|------|-------------|-------------|
| **Admin** | Full access (create/edit dashboards, manage users) | LMS administrators |
| **Alpha** | Create/edit own dashboards | Course designers |
| **Gamma** | View dashboards only | Instructors, staff |
| **Public** | No access (analytics is staff-only) | N/A |

### Row-Level Security

For instructors to see only their own courses:

```python
# In Superset (configure via UI or config)
def instructor_course_filter(g):
    """
    Filter ClickHouse queries to show only courses
    where the logged-in user is an instructor.
    """
    user_email = g.user.email
    # Lookup courses from LMS API
    courses = get_instructor_courses(user_email)
    course_ids = [c['id'] for c in courses]
    return f"course_id IN ({','.join(course_ids)})"
```

**Configuration**:
1. Enable row-level security in Superset config: `ROW_LEVEL_SECURITY_ENABLED = True`
2. Configure dataset security in Superset UI:
   - Navigate to dataset → Security → Row-Level Security
   - Add filter: `instructor_course_filter`
   - Apply to role: Gamma

### Dashboard Visibility

**Access matrix**:

| Dashboard | Admin | Alpha | Gamma (All Staff) | Gamma (Instructor) |
|-----------|-------|-------|-------------------|-------------------|
| Enrollment | Full | Full | Full | Filtered (own courses) |
| Completion | Full | Full | Full | Filtered (own courses) |
| Engagement | Full | Full | Full | Filtered (own courses) |
| Platform Health | Full | Read-only | No access | No access |

## Dashboard Embedding

### Embedding in LMS Course Pages

**Use case**: Instructors want to see analytics directly in their course authoring interface.

**Method 1: Superset Embedded SDK (Recommended)**

```javascript
// In course_author_view.html (CMS)
import { embedDashboard } from "@superset-ui/embedded-sdk";

embedDashboard({
  id: "course-analytics-dashboard-uuid",
  supersetDomain: "https://analytics.academyv2.mereka.io",
  mountPoint: document.getElementById("analytics-container"),
  fetchGuestToken: async () => {
    // Fetch guest token from LMS backend
    const response = await fetch("/api/superset-guest-token", {
      method: "POST",
      body: JSON.stringify({ courseId: "{{ course.id }}" }),
    });
    return response.json().token;
  },
  dashboardUiConfig: {
    hideTitle: true,
    hideTab: true,
    hideChartControls: true,
  }
});
```

**Backend endpoint** (LMS):
```python
# In lms/djangoapps/analytics/views.py
from superset import security_manager

@api_view(['POST'])
def superset_guest_token(request):
    """Generate guest token for embedded dashboards."""
    course_id = request.data.get('courseId')
    user = request.user

    # Verify user is instructor for this course
    if not is_instructor(user, course_id):
        return Response(status=403)

    # Generate guest token (row-filtered to this course)
    token = security_manager.get_guest_token(
        user={'username': user.username},
        resources=[{'type': 'dashboard', 'id': 'course-analytics-dashboard-uuid'}],
        rls=[{'clause': f"course_id = '{course_id}'"}]
    )
    return Response({'token': token})
```

**Method 2: Iframe Embed (Simpler, Less Secure)**

```html
<!-- In course_author_view.html -->
<iframe
  src="https://analytics.academyv2.mereka.io/superset/dashboard/course-analytics/?standalone=true&course_id={{ course.id }}"
  width="100%"
  height="600"
  frameborder="0"
></iframe>
```

**Security note**: Iframe method requires CORS configuration and relies on browser cookies. Embedded SDK with guest tokens is more secure.

## Data Sources

### ClickHouse Connection

**Connection string**:
```
clickhousedb+connect://openedx:PASSWORD@clickhouse:8123/openedx
```

**Environment variables**:
- `CLICKHOUSE_HOST`: `clickhouse` (K8s service name)
- `CLICKHOUSE_PORT`: `8123`
- `CLICKHOUSE_DATABASE`: `openedx`
- `CLICKHOUSE_USER`: `openedx`
- `CLICKHOUSE_PASSWORD`: From `aspects-secrets` K8s secret

### xAPI Event Schema

**Primary table**: `xapi_events_all`

**Schema**:
```sql
CREATE TABLE xapi_events_all (
  event_id String,
  event_date Date,
  event_time DateTime,
  verb String,  -- 'registered', 'enrolled', 'completed', 'viewed', etc.
  user_id String,  -- Hashed (not raw LMS user_id)
  course_id String,
  org_id String,
  object_type String,
  object_id String,
  context Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, user_id, course_id)
TTL event_date + INTERVAL 90 DAY;
```

**Key fields**:
- `verb`: xAPI verb (enrolled, completed, viewed, interacted)
- `user_id`: Hashed user identifier (no PII)
- `course_id`: Open edX course ID (e.g., `course-v1:MerekaAcademy+CS101+2024`)
- `object_id`: Content identifier (e.g., unit ID, video ID)

**Retention**: 90 days by default (configurable via ClickHouse TTL)

## Operational Procedures

### 1. Add New Dashboard

**Steps**:

1. Login to Superset: `https://analytics.academyv2.mereka.io`
2. Navigate to **Dashboards** → **+ Dashboard**
3. Add chart:
   - Click **+ Chart**
   - Select dataset: `xapi_events_all`
   - Choose visualization type (line, bar, table)
   - Configure metrics and filters
4. Save chart and add to dashboard
5. Configure dashboard permissions:
   - Click **Dashboard** → **Security**
   - Set roles (Admin, Alpha, Gamma)
6. Test with different user roles

**Best practices**:
- Use date range filters (default: last 30 days)
- Add dashboard description and tags
- Test query performance (<5 seconds p95)

### 2. Refresh Data / Clear Cache

**Use case**: Dashboard shows stale data after ClickHouse schema changes.

**Steps**:

```bash
# Clear Superset metadata cache
kubectl exec -n mereka-lms deploy/superset -- superset fab reset-password --username admin --password newpassword

# Refresh dataset schema
kubectl exec -n mereka-lms deploy/superset -- superset sync-all-databases

# Clear query cache
kubectl exec -n mereka-lms deploy/superset -- superset cache-warmup --dashboard-ids 1,2,3
```

**Alternative** (via UI):
1. Navigate to **Data** → **Datasets**
2. Find `xapi_events_all`
3. Click **⋮** → **Refresh Metadata**

### 3. Fix Broken Queries

**Symptom**: Dashboard shows "Error running query" or timeout.

**Diagnostic steps**:

1. **Check ClickHouse connectivity**:
   ```bash
   kubectl exec -n mereka-lms deploy/superset -- \
     curl -s http://clickhouse:8123/?query=SELECT%201
   # Expected: 1
   ```

2. **Test query in ClickHouse directly**:
   ```bash
   kubectl exec -n mereka-lms deploy/clickhouse -- \
     clickhouse-client --query "SELECT count() FROM xapi_events_all"
   ```

3. **Check Superset logs**:
   ```bash
   kubectl logs -n mereka-lms -l app.kubernetes.io/name=superset --tail=100
   # Look for: sqlalchemy errors, timeout errors
   ```

**Common fixes**:

- **Query timeout**: Increase `SUPERSET_QUERY_TIMEOUT` in configmap (default: 60s)
- **Memory error**: Increase Superset memory limits in deployment.yaml
- **Connection refused**: Verify ClickHouse service is running (`kubectl get pods -l app.kubernetes.io/name=clickhouse`)

### 4. Backup and Restore

**Backup Superset metadata** (dashboards, charts, datasets):

```bash
# Export all dashboards
kubectl exec -n mereka-lms deploy/superset -- \
  superset export-dashboards -f /tmp/dashboards.zip

# Copy to local
kubectl cp mereka-lms/superset-pod:/tmp/dashboards.zip ./dashboards-backup-$(date +%Y%m%d).zip
```

**Restore**:

```bash
# Upload backup
kubectl cp ./dashboards-backup-20260217.zip mereka-lms/superset-pod:/tmp/dashboards.zip

# Import
kubectl exec -n mereka-lms deploy/superset -- \
  superset import-dashboards -p /tmp/dashboards.zip
```

**Backup ClickHouse data**:

```bash
# Daily Parquet export to GCS (automated via CronJob)
kubectl apply -f deploy/k8s/base/plugins/aspects/jobs.yml
```

### 5. Update Superset Version

**Before upgrading**:
1. Backup dashboards (see section 4)
2. Review changelog: https://github.com/apache/superset/releases
3. Test in local environment first

**Steps**:

1. Update image tag in `deploy/k8s/base/plugins/aspects/deployments.yml`:
   ```yaml
   image: apache/superset:3.1.0  # Update version
   ```

2. Apply changes:
   ```bash
   kubectl apply -k deploy/k8s/base/plugins/aspects/
   kubectl rollout status deployment/superset -n mereka-lms
   ```

3. Run database migrations:
   ```bash
   kubectl exec -n mereka-lms deploy/superset -- superset db upgrade
   ```

4. Verify dashboards load correctly

### 6. Monitor Analytics Pipeline Health

**Key metrics** (from Platform Health dashboard):

- **Event processing lag**: Should be ≤10 minutes
- **Query response time**: p95 ≤5 seconds
- **ClickHouse disk usage**: Alert at 75% (warning), 85% (critical)
- **Failed jobs**: Should be 0

**Alert rules** (Prometheus):

```yaml
# In deploy/k8s/base/plugins/aspects/prometheusrule.yml
- alert: AnalyticsEventLagHigh
  expr: |
    (time() - max(xapi_events_all_latest_event_timestamp)) / 60 > 10
  for: 5m
  annotations:
    summary: "Analytics event lag >10 minutes"
```

**Dashboard URLs**:
- Superset: `https://analytics.academyv2.mereka.io`
- ClickHouse admin: `kubectl port-forward svc/clickhouse 8123:8123`

## Troubleshooting

### Common Issues

#### 1. Superset won't start

**Symptom**: Pod in CrashLoopBackOff

**Diagnostic**:
```bash
kubectl logs -n mereka-lms -l app.kubernetes.io/name=superset --tail=50
kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=superset
```

**Common causes**:
- Missing secrets: Verify `aspects-secrets` exists
- Database migration pending: Run `superset db upgrade`
- Redis unavailable: Check `kubectl get pods -l app.kubernetes.io/name=redis`

#### 2. Dashboard shows no data

**Symptom**: Charts load but show "No data available"

**Checks**:
1. Verify events in ClickHouse:
   ```bash
   kubectl exec -n mereka-lms deploy/clickhouse -- \
     clickhouse-client --query "SELECT count() FROM xapi_events_all"
   ```
2. Check date range filter (dashboard may default to last 7 days)
3. Verify row-level security filters aren't too restrictive

#### 3. OAuth login fails

**Symptom**: Redirect loop or "Invalid client" error

**Checks**:
1. Verify OAuth client exists in LMS: `/admin/oauth2_provider/application/`
2. Check redirect URI matches: `https://analytics.academyv2.mereka.io/oauth-authorized/openedx`
3. Verify client secret in K8s secret matches LMS

## Related Documentation

- ADR-017: Analytics Target Decision (deployment deferral rationale)
- `specs/analytics-pipeline_spec.md`: Analytics requirements and acceptance criteria
- `deploy/k8s/base/plugins/aspects/README.md`: Kubernetes deployment quick start
- `docs/concepts/analytics/ASPECTS_INSTALLATION.md`: Step-by-step installation guide
- Open edX Aspects docs: https://docs.openedx.org/projects/openedx-aspects/

---

**Deployment gate**: This runbook becomes active when ADR-017 status changes from "Deferred" to "Accepted" and analytics spec status changes to "approved".
