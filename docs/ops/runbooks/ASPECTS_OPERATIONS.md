# Aspects Analytics Operations Runbook

## Architecture

```
LMS → event-routing-backends → Ralph (xAPI LRS) → ClickHouse → dbt → Superset
         ↓ (event sinks)
LMS → platform-plugin-aspects → ClickHouse event_sink (dimensional data)
         ↓ (batch sync)
MySQL → clickhouse-data-sync-daily CronJob → ClickHouse openedx (enrollments/courses)
```

### Components

| Component | Image | Port | Health |
|-----------|-------|------|--------|
| ClickHouse | clickhouse-server:25.8-alpine | 8123 (HTTP), 9000 (native) | `/ping` |
| Superset | edunext/aspects-superset:3.0.3 (Apache Superset 4.1.1) | 8088 | `/health` |
| Superset Worker | edunext/aspects-superset:3.0.3 | — | — |
| Ralph | fundocker/ralph:4.1.0 | 8100 | `/__heartbeat__` |

### ClickHouse Databases

| Database | Purpose | Populated by |
|----------|---------|-------------|
| `xapi` | Raw xAPI events + Alembic schema | Ralph (live), Alembic (schema) |
| `event_sink` | Dimensional data (courses, users, blocks) | platform-plugin-aspects `dump_data_to_clickhouse` |
| `reporting` | dbt materialized views for dashboards | dbt run |
| `openedx` | Batch-synced MySQL data | clickhouse-data-sync-daily CronJob |

### ClickHouse Users

| User | Purpose | Default DB |
|------|---------|-----------|
| `openedx` | Admin, all access | — |
| `ch_report` | Superset read access | xapi |
| `ch_cms` | LMS event sink writes | event_sink |
| `ch_lrs` | Ralph xAPI writes | xapi |
| `ch_vector` | Vector log shipping (unused) | — |

## Environment Init

Use the codified init script:

```bash
# Prerequisites
pip install tutor-contrib-aspects==3.0.3
tutor plugins enable aspects
tutor config save  # renders .aspects-tutor-workspace/

# Init
./scripts/aspects/init-aspects-env.sh --env dev
./scripts/aspects/init-aspects-env.sh --env staging

# Dry-run check
./scripts/aspects/init-aspects-env.sh --env dev --check
```

The init sequence is:
1. Create ClickHouse databases
2. Apply Tutor-rendered ConfigMaps (Alembic migrations, dbt profiles)
3. Run Alembic migrations (41 migrations → event_sink tables, UDFs)
4. Run dbt (37 models → reporting materialized views)
5. Import Superset assets (18 dashboards, 93 datasets, 166 charts)
6. Create ClickHouse users (ch_report, ch_cms, ch_lrs, ch_vector)
7. Backfill event_sink dimensional data

## Data Flow

### Live xAPI events (real-time)
```
User action → LMS tracking middleware → event-routing-backends (Celery) →
Ralph PUT /xAPI/statements → ClickHouse xapi.xapi_events_all →
dbt materialized view → reporting.fact_enrollments (etc.)
```

**Prerequisite**: RouterConfiguration must exist in LMS Django admin:
```python
RouterConfiguration.objects.get_or_create(
    backend_name='xAPI',
    defaults={
        'route_url': 'http://ralph:8100/xAPI',
        'auth_scheme': 'Basic',
        'username': 'lms',
        'password': '<from Infisical MEREKA_LMS_ASPECTS_RALPH_LMS_PASSWORD>',
        'enabled': True,
    }
)
```

### Event sink (dimensional backfill)
```bash
kubectl exec -n <ns> deployment/lms -- python manage.py lms dump_data_to_clickhouse \
  --object course_overviews --force --batch_size 5000 \
  --url http://clickhouse:8123 --username openedx --password <PW> --database event_sink
```

Available objects: `course_overviews`, `course_enrollment`, `user_profile`, `course_blocks`

### Batch sync (daily CronJob)
Runs at 2 AM UTC. Syncs enrollments, completions, courses from MySQL → ClickHouse openedx.

```bash
# Trigger manually
kubectl create job --from=cronjob/clickhouse-data-sync-daily manual-sync -n <ns>
```

## Troubleshooting

### Dashboards show "no data"
1. Check `xapi.xapi_events_all` row count — if 0, xAPI pipeline isn't flowing
2. Check RouterConfiguration exists in LMS
3. Check Ralph health: `kubectl exec deployment/ralph -- wget -qO- http://localhost:8100/__heartbeat__`
4. Check LMS worker logs for ERB errors: `kubectl logs deployment/lms-worker | grep xapi`

### Organization filter fails to load
- Check `event_sink.dim_course_names` has data
- If empty, re-run: `dump_data_to_clickhouse --object course_overviews --force`

### xAPI events not reaching ClickHouse
1. Verify RouterConfiguration: `kubectl exec deployment/lms -- python manage.py lms shell -c "from event_routing_backends.models import RouterConfiguration; [print(r.route_url, r.enabled) for r in RouterConfiguration.objects.all()]"`
2. Verify Ralph receives requests: `kubectl logs deployment/ralph | grep -v heartbeat | tail -10`
3. URL must be `http://ralph:8100/xAPI` (not `http://ralph:8100`)

### dbt models missing
```bash
# Re-run dbt
kubectl run dbt-fix --image=edunext/aspects:3.0.3 -n <ns> --restart=Never --command -- bash -c "
pip install -q dbt-core dbt-clickhouse && mkdir -p /root/.dbt && \
cp /tmp/dbt-profile/profiles.yml /root/.dbt/profiles.yml && \
cd /app/aspects-dbt && dbt run"
```

## Auth

Superset authenticates via Authentik OAuth2:
- Provider: `superset-analytics` (blueprint in `apps/mereka-lms/authentik/`)
- OAuth scope: `openid email profile groups`
- Role mapping: Authentik groups → Superset roles (AUTH_ROLES_MAPPING in superset_config.py)
- Default role: Gamma (read-only)
- Admin groups: `authentik Admins`, `superusers`, `Platform Admins`

## Data Availability

### What dashboards CAN show
- Course structure and metadata (from event_sink backfill)
- Organization-level filters (from dim_course_names)
- Enrollment trends (from xAPI events — only for events since pipeline activation)
- Video/problem/navigation engagement (from xAPI events — only for events since activation)

### What dashboards CANNOT show (without tracking log backfill)
- Historical enrollment trends before pipeline activation
- Historical learner activity before pipeline activation
- Tracking logs are ephemeral (not persisted to PVC) so historical backfill is impossible for past periods

### Tracking log persistence
PVC `lms-tracking-logs` (5Gi, ReadWriteMany) defined in `deploy/k8s/base/plugins/aspects/volumes.yml`.
Must be mounted to LMS + LMS-worker deployments at `/openedx/data/logs/` via overlay patch.

**Backfill procedure** (replay tracking logs into xAPI pipeline):
```bash
kubectl exec -n <ns> <lms-pod> -- python manage.py lms transform_tracking_logs \
  --source_provider LOCAL \
  --source_config '{"key":"/openedx/data/logs","container":".","prefix":"tracking"}' \
  --transformer_type xapi \
  --destination_provider LRS \
  --batch_size 1000 \
  --sleep_between_batches_secs 0.1
```

**Log rotation**: LMS writes to `/openedx/data/logs/tracking.log`. Python logging
rotates via `RotatingFileHandler`. Ensure PVC has enough headroom for accumulated logs
between rotations.

## Environments

| Env | Namespace | Analytics URL | Auth |
|-----|-----------|--------------|------|
| Dev | mereka-lms-dev | analytics.academyv2.mereka.dev | auth0.mereka.dev |
| Staging | stg-mereka-lms | analytics.staging.academyv2.mereka.io | staging.auth0.mereka.io |
| Prod | mereka-lms | analytics.academyv2.mereka.io (dormant) | auth0.mereka.io |

## Version Family

| Component | Version | Constraint |
|-----------|---------|-----------|
| tutor-contrib-aspects | 3.0.3 | Aligned with Tutor 21.x (Ulmo) |
| aspects-dbt | v6.1.1 | Pinned in aspects image |
| Superset | 4.1.1 (EOL) | Waiting for upstream 5.x/6.x compatible release |
| ClickHouse | 25.8 LTS | Requires `check_table_dependencies=0` for Alembic |
| event-routing-backends | 9.3.8 | Must stay <9.4 (10.0+ requires Python 3.12) |
| platform-plugin-aspects | 1.1.2 | Must stay <1.1.3 (requires Python 3.12) |
