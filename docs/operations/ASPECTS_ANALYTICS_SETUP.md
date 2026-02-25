# Aspects Analytics Setup

> **Owner**: platform-engineering
> **Last Updated**: 2026-02-25
> **Status**: MANIFESTS EXIST — NOT DEPLOYED (see Current State below)
> **Deployment target**: Dev cluster (rke2-nonprod / *.mereka.dev) first; prod after stakeholder approval

---

## What Aspects Is

[tutor-contrib-aspects](https://github.com/openedx/tutor-contrib-aspects) is the official Open edX analytics plugin. It replaces the legacy Event Routing Backends approach with a modern pipeline:

- **Event collection**: Open edX emits xAPI 1.0.3 events via the platform event bus
- **Ingestion**: Ralph (xAPI LRS) receives events and writes them to ClickHouse
- **Storage**: ClickHouse (columnar data warehouse) stores raw xAPI events, partitioned by date
- **Aggregation**: dbt models transform raw events into reporting-ready views
- **Visualization**: Apache Superset renders dashboards backed by ClickHouse queries

Aspects is distinct from the `team-analytics` Next.js dashboard, which is a separate custom reporting surface. Aspects is the Open edX native analytics plugin; `team-analytics` is a bespoke Mereka product.

---

## Current State

### Manifests exist but are not wired into the active kustomization graph

```
deploy/k8s/base/plugins/aspects/
  kustomization.yaml    # Aspects-specific kustomization (self-contained)
  configmaps.yml        # ClickHouse server config + Superset config.py
  secrets.yml           # aspects-secrets placeholder (empty values, NOT production-ready)
  volumes.yml           # clickhouse-data PVC (10Gi, storageClassName: standard-rwo)
  services.yml          # clickhouse (8123/9000) + superset (8088) ClusterIP services
  deployments.yml       # clickhouse, superset, superset-worker Deployments
  jobs.yml              # superset-init + clickhouse-init Jobs
  ingress.yml           # Superset ingress (hardcoded to analytics.academyv2.mereka.io)
```

**Confirmed**: `deploy/k8s/base/kustomization.yaml` does NOT include `plugins/aspects/` in its `resources` list. This is intentional — wiring is tracked as task T148.

### What is NOT yet done (gaps before dev deployment)

| Gap | Notes |
|-----|-------|
| Secrets not in Infisical | `clickhouse-password`, `superset-secret-key`, `superset-db-password` need to be provisioned |
| ExternalSecret not created | `aspects-secrets` K8s Secret has placeholder values; needs ESO ExternalSecret wired to GCP SM |
| Ingress points to prod domain | `ingress.yml` uses `analytics.academyv2.mereka.io`; dev overlay must override to `analytics.academyv2.mereka.dev` |
| `oauth-client-secret` not provisioned | Superset Authentik OAuth2 app not created; secret is `optional: true` so startup will proceed, but login will fail |
| Superset MySQL database not created | `superset` DB and user must exist in MySQL before `superset-init` Job runs |
| No dev overlay | No `deploy/k8s/overlays/local/` patch for Aspects; T148 must create one |
| `storageClassName: standard-rwo` | This is the GKE storage class; rke2-nonprod may need a different class |

---

## Deployment Plan

### Phase 1 — Dev (rke2-nonprod / *.mereka.dev)

Prerequisite: T148 wires Aspects into the local/dev kustomization with a proper overlay.

Steps (to be executed during T148):

1. Provision secrets in Infisical:
   ```bash
   # From /home/gurpreet/projects/k8s/reka-slackbot (has .infisical.json)
   openssl rand -hex 32  # use output as MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY
   openssl rand -base64 24  # use output as MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD
   openssl rand -base64 24  # use output as MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD
   ```

2. Create GCP Secret Manager entries in `bbi-k8` project (same project used by all ESO secrets):
   ```bash
   printf '%s' 'VALUE' | gcloud secrets create MEREKA_LMS_ASPECTS_CLICKHOUSE_PASSWORD \
     --project=bbi-k8 --data-file=-
   printf '%s' 'VALUE' | gcloud secrets create MEREKA_LMS_ASPECTS_SUPERSET_SECRET_KEY \
     --project=bbi-k8 --data-file=-
   printf '%s' 'VALUE' | gcloud secrets create MEREKA_LMS_ASPECTS_SUPERSET_DB_PASSWORD \
     --project=bbi-k8 --data-file=-
   ```

3. Add ExternalSecret to `deploy/k8s/base/secrets/external-secrets.yaml` mapping the three keys to `aspects-secrets`.

4. Create Superset MySQL database (run once after ESO syncs secrets):
   ```bash
   kubectl exec -n mereka-lms deploy/mysql -- mysql -u root -p"${ROOT_PASS}" -e "
     CREATE DATABASE IF NOT EXISTS superset;
     CREATE USER IF NOT EXISTS 'superset'@'%' IDENTIFIED BY '${SUPERSET_DB_PASSWORD}';
     GRANT ALL PRIVILEGES ON superset.* TO 'superset'@'%';
     FLUSH PRIVILEGES;
   "
   ```

5. Create dev overlay in `deploy/k8s/overlays/local/` (or equivalent dev target) that patches:
   - Ingress hostname to `analytics.academyv2.mereka.dev`
   - `storageClassName` to whatever the rke2-nonprod cluster uses

6. Wire `plugins/aspects/` into the kustomization (T148 owns this step).

7. Apply and run init Jobs:
   ```bash
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=aspects \
     -n mereka-lms --timeout=300s
   kubectl apply -f deploy/k8s/base/plugins/aspects/jobs.yml
   ```

8. Verify (see Verification section below).

### Phase 2 — Production (GKE / *.mereka.io)

Only after:
- [ ] Dev deployment is stable for >= 2 weeks
- [ ] Stakeholder sign-off (confirm with CTO before proceeding)
- [ ] Superset ingress tested at `analytics.academyv2.mereka.dev`
- [ ] ClickHouse disk usage is within budget projections

Production-specific changes needed:
- `ingress.yml` host must be `analytics.academyv2.mereka.io`
- `storageClassName: standard-rwo` is correct for GKE (already set)
- Authentik OAuth2 application must be created in production Authentik

---

## Components

### ClickHouse (Data Warehouse)

| Property | Value |
|----------|-------|
| Image | `clickhouse/clickhouse-server:24.3-alpine` |
| HTTP port | 8123 |
| Native port | 9000 |
| Storage | 10Gi PVC (`clickhouse-data`) |
| Memory request/limit | 2Gi / 4Gi |
| CPU request/limit | 500m / 2 |
| Database | `openedx` |
| User | `openedx` |

ClickHouse stores xAPI events in three initial tables (created by `clickhouse-init` Job):
- `openedx.xapi_events` — raw xAPI events partitioned by `toYYYYMM(timestamp)`
- `openedx.enrollments` — enrollment records with ReplacingMergeTree deduplication
- `openedx.completions` — unit completion records

### Superset (Dashboard Visualization)

| Property | Value |
|----------|-------|
| Image | `apache/superset:3.1.0` |
| Port | 8088 |
| Memory request/limit | 1Gi / 2Gi |
| Auth | OAuth2 via Authentik (`auth0.mereka.io`) |
| Metadata store | MySQL (`superset` database) |
| Cache backend | Redis DB 2 |
| Celery broker | Redis DB 3 |
| Celery result backend | Redis DB 4 |

Additional packages installed at runtime via init container:
- `clickhouse-connect==0.7.19` — ClickHouse SQLAlchemy driver
- `authlib==1.3.0` — OAuth2 support for Authentik SSO

### Superset Worker

Runs Celery in prefork mode with 2 concurrent workers. Handles async chart rendering and scheduled reports.

### Event Bus (Data Pipeline)

The current manifests do not include an event routing sidecar. The full Aspects event pipeline (using Ralph as the xAPI LRS) requires additional LMS configuration:

- `tutor plugins enable aspects` sets `EVENT_TRACKING_BACKENDS` in LMS settings to route events to Ralph
- Ralph is the HTTP endpoint that receives xAPI statements and writes to ClickHouse
- Ralph is NOT included in the current manifests — this is a known gap

Until Ralph is deployed and wired to the LMS event bus, ClickHouse will only receive data through manual imports or direct writes.

---

## Data Pipeline

```
LMS / CMS / MFEs
       |
       | Open edX event bus (Django signals → xAPI transformer)
       |
       v
   Ralph (xAPI LRS)        <-- NOT YET IN MANIFESTS
       |
       | HTTP bulk insert
       |
       v
   ClickHouse
   openedx.xapi_events
       |
       | SQL queries
       |
       v
   Superset Dashboards
   (instructor / staff access)
```

Until Ralph is added to the manifests, the pipeline is:

```
Manual import / clickhouse-init Job
       |
       v
   ClickHouse
       |
       v
   Superset Dashboards
```

---

## Retention Policy

Data retention is governed by `docs/operations/ANALYTICS_DATA_RETENTION.md`.

Summary:
- Raw events (`tracking.events`): 365-day TTL
- PII-containing events (`tracking.pii_events`): 90-day anonymization schedule
- Debug/trace events (`tracking.debug`): 30-day TTL
- Aggregated dbt model outputs: indefinite (no PII after aggregation)

The current `clickhouse-init` Job does NOT set TTL on the tables it creates. TTL must be added when the full Aspects schema is deployed. Reference:

```sql
ALTER TABLE openedx.xapi_events
  MODIFY TTL toDate(timestamp) + INTERVAL 365 DAY;
```

---

## Instructor Visibility

Once deployed and connected to the LMS:

- Instructors with Staff role can access Superset at `https://analytics.academyv2.mereka.dev` (dev) or `https://analytics.academyv2.mereka.io` (prod)
- Authentication is via Authentik OAuth2; new users receive the `Gamma` Superset role by default (read-only)
- Dashboard embedding in LMS course pages requires the `ENABLE_XBLOCK_EMBEDDING` feature flag and LMS-side Aspects plugin configuration (not yet implemented)

Pre-built dashboards to be imported (planned, not yet created):
- Learner engagement (daily/weekly active users per course)
- Course completion rates
- Problem-level analytics (average attempts, success rate)
- Content popularity (most-viewed units)

---

## Monitoring

### Alerts to Set Up

| Alert | Condition | Severity |
|-------|-----------|----------|
| ClickHouse disk pressure | PVC usage > 75% | warning |
| ClickHouse disk critical | PVC usage > 85% | critical |
| Event processing lag | Events older than 10 minutes not stored | warning |
| Superset unavailable | `superset` pod not ready for > 5 min | warning |
| ClickHouse unavailable | `/ping` returns non-200 for > 2 min | critical |

Add PrometheusRule resources to `deploy/k8s/base/monitoring/` when Aspects is deployed. Reference `deploy/k8s/base/monitoring/` for existing alert patterns.

### Key Metrics

ClickHouse:
- `ClickHouseAsyncInsertQuery` — async insert queue depth
- Disk usage via `system.disks` table
- Query latency via `system.query_log`

Superset:
- Pod readiness (standard K8s)
- Response time via Nginx Ingress metrics

---

## Verification

Run the verification script to assess readiness:

```bash
./scripts/qa/verify-aspects-analytics.sh
```

The script checks:
1. Manifests exist in `deploy/k8s/base/plugins/aspects/`
2. Expected resources are present in the manifests
3. Aspects is NOT in the active base kustomization (by design until T148)
4. Analytics spec exists and has acceptance criteria

---

## References

- Analytics spec: `specs/analytics-pipeline_spec.md`
- Data retention policy: `docs/operations/ANALYTICS_DATA_RETENTION.md`
- Aspects plugin source: https://github.com/openedx/tutor-contrib-aspects
- ClickHouse docs: https://clickhouse.com/docs/
- Apache Superset docs: https://superset.apache.org/docs/
- Ralph (xAPI LRS): https://github.com/openfun/ralph
- T148 (wire Aspects into kustomization): depends on this task
