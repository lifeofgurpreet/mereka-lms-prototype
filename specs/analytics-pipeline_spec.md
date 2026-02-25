---
title: "Analytics Pipeline (Aspects/Panorama)"
type: "data_pipeline_spec"
status: "approved"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-25"
version: "1.0.0"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/k8s-deployment_spec.md"
  - "specs/mongodb-atlas-integration_spec.md"
links:
  related_docs:
    - "docs/operations/OBSERVABILITY_QUICKSTART.md"
    - "docs/operations/SLO_DASHBOARDS_SETUP.md"
    - "docs/operations/MONITORING.md"
  related_specs:
    - "specs/observability-stack_spec.md"
    - "specs/data-privacy-gdpr-compliance_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---
# Analytics Pipeline (Aspects/Panorama)

## Human Summary

### What we're building
A learning analytics data pipeline that captures learner behavior from Open edX (LMS, CMS, and MFEs), transforms events into xAPI format, stores them in ClickHouse, and visualizes them through Superset dashboards. This gives instructors and administrators quantitative insight into course engagement, completion rates, and content effectiveness.

### Why it matters
Without analytics, instructors have no visibility into how learners interact with course content. This pipeline turns raw platform events into actionable dashboards -- enabling data-driven course design, early identification of struggling learners, and evidence-based decisions about content investment. It also supports institutional reporting requirements.

### Success looks like
- xAPI events flow from all platform surfaces (LMS, CMS, MFEs) to ClickHouse within 10 minutes of occurrence
- Superset dashboards load in under 5 seconds for staff users
- Zero PII leakage in the analytics data store (verified by automated audit)
- Instructors embed dashboards directly in their course pages

## Scope

This spec covers the learning analytics data pipeline using Open edX Aspects (formerly Event Routing Backends) to collect xAPI events, store them in ClickHouse, and visualize them via Superset dashboards.

The pipeline provides insights into learner behavior, course engagement, and platform health without exposing personally identifiable information (PII).

## Non-goals

- Operational monitoring (covered in observability-stack_spec.md)
- Business intelligence for non-learning data (revenue, marketing)
- Real-time alerting (Aspects is batch-oriented, not streaming)
- GDPR/privacy compliance implementation (separate compliance spec)

## Requirements

### Event Collection (Aspects)

> **DEPLOYMENT STATUS**: NOT DEPLOYED - Aspects is available in Tutor but not yet enabled in production
>
> **To deploy**:
> 1. Enable plugin: `tutor plugins enable aspects`
> 2. Build images: `tutor images build aspects aspects-superset`
> 3. Initialize: `tutor k8s init`
> 4. Start services: `tutor k8s start`
>
> **Verification**: `kubectl get pods -n mereka-lms | grep aspects`
>
> <!-- Last deployment status check: 2026-02-13 (docs audit) -->

- The system MUST install Aspects plugin via Tutor: `tutor plugins enable aspects`
- The system MUST collect xAPI events from LMS, CMS, and MFEs
- The system MUST transform Open edX tracking events to xAPI 1.0.3 format
- The system SHOULD batch events before sending to reduce ClickHouse write load
- The system MUST NOT collect PII fields (email, IP address, full name) in analytics events

### Event Types

The system SHOULD collect the following xAPI verbs:

| Verb | Triggered By | Example |
|------|--------------|---------|
| `registered` | New user signup | User creates account |
| `enrolled` | Course enrollment | User enrolls in course |
| `completed` | Course/unit completion | User completes unit |
| `viewed` | Page view | User views course content |
| `interacted` | Quiz/problem attempt | User submits answer |
| `progressed` | Progress update | User advances in course |

### Data Storage (ClickHouse)

- The system MUST use ClickHouse for event storage (columnar database optimized for analytics)
- The system MUST configure ClickHouse with appropriate retention policies (default: 90 days)
- The system MUST partition events by date for efficient querying
- The system SHOULD configure compression for historical data (>7 days old)
- The system MUST replicate ClickHouse data if running multi-node cluster

### Data Visualization (Superset)

- The system MUST deploy Superset for dashboard creation
- The system SHOULD provide pre-built dashboards:
  - Learner engagement (daily/weekly active users)
  - Course completion rates
  - Problem-level analytics (average attempts, success rate)
  - Content popularity (most viewed units)
  - Platform health (error rates, slow queries)
- The system MUST restrict dashboard access to authorized staff only
- The system SHOULD enable dashboard embedding in LMS for instructors

### Privacy & Compliance

- The system MUST anonymize or hash user identifiers in events
- The system MUST NOT store email addresses in ClickHouse
- The system MUST NOT store IP addresses in events
- The system MUST provide data deletion mechanism for GDPR right-to-be-forgotten
- The system SHOULD implement role-based access control (RBAC) for dashboards

### Non-Functional Requirements

- Event processing lag (generation to storage) MUST be <= 10 minutes under normal load
- Event processing lag SHOULD be <= 2 minutes at p50
- ClickHouse query response time for dashboard queries MUST be <= 5 seconds at p95
- ClickHouse query response time for dashboard queries SHOULD be <= 2 seconds at p50
- The analytics pipeline MUST sustain >= 500 events/second write throughput without backpressure
- Superset dashboard availability SHOULD be >= 99.5% during business hours (08:00-22:00 MYT)
- ClickHouse storage cost SHOULD be <= $50/month for 90-day retention with compression
- Data deletion requests (GDPR) MUST complete within 7 days of receipt

## Acceptance Criteria

- [ ] AC-001: Aspects plugin enabled: `tutor plugins list | grep aspects` shows enabled
- [ ] AC-002: xAPI events flow to ClickHouse: `clickhouse-client --query "SELECT count() FROM xapi_events_all"`
- [ ] AC-003: ClickHouse retention policy active: Events older than 90 days are deleted
- [ ] AC-004: Superset accessible at configured URL (e.g., `https://analytics.mereka.io`)
- [ ] AC-005: Pre-built dashboards visible in Superset for staff users
- [ ] AC-006: No PII in events: `clickhouse-client --query "SELECT * FROM xapi_events_all LIMIT 10"` shows hashed IDs
- [ ] AC-007: Instructor dashboard embeds in LMS course pages
- [ ] AC-008: Data deletion works: Deleting user removes their events from ClickHouse

## Edge Cases

### Event Backpressure

**Symptom**: ClickHouse write lag, events delayed by minutes/hours

**Cause**: High event volume during peak usage (e.g., exam period)

**Mitigation**:
- Increase batch size: `ASPECTS_EVENT_BATCH_SIZE=1000` (default: 100)
- Increase ClickHouse write buffer: `max_insert_block_size=100000`
- Scale ClickHouse horizontally (add replicas)

### ClickHouse Disk Space

**Symptom**: ClickHouse rejects writes with "No space left on device"

**Cause**: Event retention too long, compression not enabled

**Recovery**:
```sql
-- Check disk usage
SELECT formatReadableSize(sum(bytes)) AS size
FROM system.parts
WHERE table = 'xapi_events_all';

-- Drop old partitions
ALTER TABLE xapi_events_all DROP PARTITION '2023-01-01';
```

### ClickHouse Disk Quota Exhaustion

**Symptom**: ClickHouse silently stops accepting writes before disk is physically full

**Cause**: ClickHouse's `max_bytes_to_merge_at_max_space_in_pool` and merge operations consume temporary disk beyond the data partition size. A 90% full disk can block merges and effectively halt writes.

**Mitigation**:
- Alert at 75% disk usage (warning) and 85% (critical) on the ClickHouse data volume
- Configure `min_free_disk_space_bytes` to reserve 10GB for merge operations
- Implement TTL-based partition dropping: `ALTER TABLE xapi_events_all MODIFY TTL event_date + INTERVAL 90 DAY`
- Monitor `system.disks` table in Prometheus for proactive alerting

### Superset Query Timeout

**Symptom**: Dashboard queries fail with timeout error

**Cause**: Unoptimized query, missing indexes, or large date range

**Recovery**:
- Increase query timeout: `SUPERSET_WEBSERVER_TIMEOUT=300` (default: 60s)
- Add materialized views for common aggregations
- Limit default date range in dashboard filters

### PII Leakage

**Symptom**: Email addresses visible in ClickHouse query results

**Cause**: Event transformation not anonymizing PII fields

**Recovery**:
```python
# Update Aspects event processor to hash PII
import hashlib

def anonymize_actor(actor):
    actor['mbox'] = hashlib.sha256(actor['mbox'].encode()).hexdigest()
    return actor
```

### Data Deletion Compliance

**Symptom**: User requests data deletion but events persist

**Cause**: No GDPR deletion pipeline implemented

**Recovery**:
```sql
-- Delete user events by hashed ID
ALTER TABLE xapi_events_all DELETE WHERE actor_id = '<hashed_user_id>';
```

## Observability

### Logs

- Event collection: `tutor local logs lms | grep aspects`
- ClickHouse writes: `tutor local logs clickhouse | grep INSERT`
- Superset queries: `tutor local logs superset | grep "Query returned"`

### Metrics

Aspects should expose:
- Events collected per minute
- Event processing lag (time from generation to storage)
- ClickHouse write throughput (rows/sec)
- Failed event transformations

ClickHouse metrics:
- Disk usage by partition
- Query execution time p50, p95, p99
- Active connections

Superset metrics:
- Dashboard load time
- Query success/failure rate
- Active dashboard users

### Alerts

- MUST alert if event processing lag exceeds 10 minutes
- MUST alert if ClickHouse disk usage exceeds 80%
- SHOULD alert if ClickHouse write throughput drops >50%
- SHOULD alert if Superset query failure rate exceeds 5%

## Rollout & Rollback

### Initial Deployment

```bash
# 1. Enable Aspects plugin
tutor plugins enable aspects
tutor config save

# 2. Build images (includes Aspects, ClickHouse, Superset)
tutor images build openedx aspects clickhouse superset

# 3. Deploy services
tutor k8s start

# 4. Initialize ClickHouse schema
tutor k8s exec aspects ./manage.py initialize_clickhouse

# 5. Create Superset admin user
tutor k8s exec superset superset fab create-admin

# 6. Import pre-built dashboards
tutor k8s exec superset superset import_dashboards -p /app/dashboards/
```

### Gradual Rollout

1. Start with CMS events only (low volume)
2. Add LMS events after 1 week (monitor ClickHouse load)
3. Add MFE events after 2 weeks (full pipeline active)

### Rollback Procedure

If analytics pipeline breaks production:

```bash
# 1. Disable event collection
tutor config save --set ASPECTS_ENABLE_EVENT_ROUTING=false

# 2. Restart LMS/CMS (stops sending events)
tutor k8s restart lms cms

# 3. Keep ClickHouse/Superset running for analysis

# 4. To fully remove:
tutor plugins disable aspects
tutor k8s stop clickhouse superset
```

### Backfill Historical Events

If ClickHouse is empty after deployment:

```bash
# 1. Export tracking logs from MySQL (if using legacy tracking)
tutor k8s exec mysql mysqldump tracking_logs > tracking_logs.sql

# 2. Transform to xAPI format
python scripts/analytics/transform_tracking_to_xapi.py tracking_logs.sql > xapi_events.jsonl

# 3. Import to ClickHouse
cat xapi_events.jsonl | tutor k8s exec -i clickhouse clickhouse-client --query "INSERT INTO xapi_events_all FORMAT JSONEachRow"
```

## Open Questions

1. ~~What's the optimal event retention period (90 days vs 1 year)?~~ **RESOLVED**: 90 days hot (ClickHouse), 1 year cold (GCS archive with Parquet export). Aligns with cross-cutting log retention pattern (30d hot / 90d cold) but extended for analytics value.
2. ~~Should we replicate ClickHouse across regions for disaster recovery?~~ **RESOLVED**: No. Single-node ClickHouse is sufficient for current scale (<50 tenants). Daily GCS backup provides DR. Revisit when event volume exceeds 100M events/month.
3. ~~How do we handle schema evolution (new event fields)?~~ **RESOLVED**: Use ClickHouse materialized views with schema versioning. New fields added as nullable columns; breaking changes via new table + materialized view migration. Document in ADR.
4. ~~Should we export aggregated metrics to Prometheus for alerting?~~ **RESOLVED**: Yes. Grafana ClickHouse data source for dashboards; Prometheus recording rules for alerting on pre-aggregated metrics (e.g., enrollment_rate, completion_rate per tenant).
5. ~~Do we need real-time dashboards or is daily batch acceptable?~~ **RESOLVED**: Daily batch for analytics dashboards. Real-time metrics for operational alerts only (via Prometheus, not ClickHouse).
6. ~~Should we anonymize user IDs completely or use reversible hashing for support?~~ **RESOLVED**: Reversible hashing (HMAC-SHA256 with rotatable key stored in Infisical). Support team can de-anonymize with key access. Aligns with GDPR data-privacy spec pseudonymization requirements.
7. ~~What's the SLA for data deletion requests (24h, 7 days, 30 days)?~~ **RESOLVED**: 30 days, consistent with cross-cutting tenant offboarding timeline and GDPR compliance spec.
