# Analytics Data Retention Policy

> **Owner**: platform-engineering
> **Last Updated**: 2026-02-24
> **Config file**: `infrastructure/tutor/analytics-retention-config.yaml`
> **Verify script**: `scripts/qa/verify-analytics-retention.sh`
> **Compliance**: PDPA (Malaysia), GDPR (where applicable)

---

## Overview

Mereka LMS collects analytics data via the [tutor-contrib-aspects](https://github.com/openedx/tutor-contrib-aspects) plugin.
Aspects uses ClickHouse for raw event storage, dbt for aggregation, and xAPI for the event format.
This document defines what data is collected, how long it is retained, and how retention is enforced.

---

## What Data Is Collected

| Data type | Source | Format | Store |
|-----------|--------|--------|-------|
| Raw learning events | Open edX event bus | xAPI | ClickHouse `tracking.events` |
| PII-containing events | LMS user activity | xAPI | ClickHouse `tracking.pii_events` |
| Debug / trace events | Celery workers, LMS middleware | JSON | ClickHouse `tracking.debug` |
| Aggregated reports | dbt models over raw events | Parquet-like SQL views | ClickHouse (separate schema) |
| xAPI statements | Aspects Ralph ingestion pipeline | xAPI (JSON-LD) | ClickHouse (via Ralph) |

### PII fields present in events

The following fields are considered PII and are isolated in `tracking.pii_events`:

- `actor.account.name` (Open edX username)
- `actor.name` (display name)
- `context.user_id`
- `object.id` containing email addresses
- IP addresses in `context.extensions`

---

## Retention Tiers

### Tier 1 — Raw events (`tracking.events`)

| Property | Value |
|----------|-------|
| Target table | `tracking.events` |
| Retention | **365 days** |
| Enforcement | ClickHouse TTL expression on `event_time` column |
| Rationale | Supports year-over-year learning analytics comparisons |

**TTL expression (applied at table creation or ALTER):**
```sql
ALTER TABLE tracking.events
  MODIFY TTL event_time + INTERVAL 365 DAY;
```

---

### Tier 2 — PII-containing events (`tracking.pii_events`)

| Property | Value |
|----------|-------|
| Target table | `tracking.pii_events` |
| Retention | **90 days** |
| Enforcement | Scheduled anonymization job; PII fields nulled after 90 days |
| Rationale | PDPA requires minimal PII retention; anonymized record preserved for analytics |

**Anonymization job (runs nightly via Celery beat):**
```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py anonymize_analytics_pii --older-than 90
```

After anonymization, the event record remains but `actor.account.name`, `actor.name`,
`context.user_id`, and IP fields are replaced with `[ANONYMIZED]`.

---

### Tier 3 — Debug / trace data (`tracking.debug`)

| Property | Value |
|----------|-------|
| Target table | `tracking.debug` |
| Retention | **30 days** |
| Enforcement | ClickHouse TTL expression on `event_time` column |
| Rationale | Debug traces are high-volume and low analytical value; 30 days covers incident investigation windows |

**TTL expression:**
```sql
ALTER TABLE tracking.debug
  MODIFY TTL event_time + INTERVAL 30 DAY;
```

---

### Tier 4 — Aggregated reports (dbt models)

| Property | Value |
|----------|-------|
| Target | dbt model output tables in ClickHouse |
| Retention | **Indefinite** |
| Enforcement | None required (small footprint; no PII present after aggregation) |
| Rationale | Aggregated metrics (completion rates, enrollment counts, grade distributions) are de-identified and needed for long-term reporting |

dbt models run on a scheduled basis and regenerate from raw events within the retention window.
Once raw events age out of retention, old aggregated snapshots are preserved as the historical record.

---

## How Retention Is Enforced

### ClickHouse TTL (Tiers 1 and 3)

ClickHouse TTL expressions are set at the table level. ClickHouse runs a background merge process
(`MergeTree` engine) that physically deletes expired data parts.

Verify TTL is set:
```sql
SELECT
  name,
  engine_full
FROM system.tables
WHERE database = 'tracking'
  AND name IN ('events', 'debug');
```

The `engine_full` column will include `TTL event_time + INTERVAL N DAY` if set correctly.

Check oldest record per table:
```sql
-- Raw events oldest record
SELECT min(event_time) AS oldest_event FROM tracking.events;

-- Debug oldest record
SELECT min(event_time) AS oldest_event FROM tracking.debug;

-- Should not be older than retention_days from today
```

### Scheduled anonymization job (Tier 2)

The PII anonymization job is a Django management command scheduled via Celery beat.
It runs nightly at 02:00 UTC.

Verify it is scheduled:
```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py shell -c "
from django_celery_beat.models import PeriodicTask
print(PeriodicTask.objects.filter(name__icontains='anonymize').values('name', 'enabled'))
"
```

---

## Compliance Notes

### PDPA (Malaysia)

The Personal Data Protection Act 2010 (PDPA) requires that personal data not be retained longer than
necessary. Key obligations:

- PII in analytics events must not be retained beyond **90 days** unless a legitimate purpose exists.
- Learners may submit a **data erasure request** to privacy@mereka.io. Upon receipt:
  1. Verify identity.
  2. Run: `kubectl exec -n mereka-lms deployment/lms -- python manage.py retire_user --username <user>`
  3. Additionally delete ClickHouse PII events: `DELETE FROM tracking.pii_events WHERE actor_account_name = '<username>'`
  4. Confirm deletion in writing within **30 days**.

See also: `docs/runbooks/operations/PRIVACY_RUNBOOK.md`

### GDPR (where applicable)

For learners accessing via EU-based tenants, GDPR Article 17 (Right to Erasure) applies.
The same erasure procedure as PDPA applies. Erasure must be confirmed within **30 days**.

---

## Policy Review Schedule

This policy must be reviewed at minimum every **180 days**.

The `last_reviewed` field in `infrastructure/tutor/analytics-retention-config.yaml` is
machine-checked by `scripts/qa/verify-analytics-retention.sh`.

If the `last_reviewed` date is older than 180 days, the verification script will fail.

---

## References

- Machine-readable config: `infrastructure/tutor/analytics-retention-config.yaml`
- Verify script: `scripts/qa/verify-analytics-retention.sh`
- Privacy runbook: `docs/runbooks/operations/PRIVACY_RUNBOOK.md`
- Aspects plugin: https://github.com/openedx/tutor-contrib-aspects
- ClickHouse TTL docs: https://clickhouse.com/docs/en/engines/table-engines/mergetree-family/mergetree#table_engine-mergetree-ttl
