# Product KPI Framework — North Star Metrics

> **Owner**: platform-engineering
> **Last Updated**: 2026-02-25
> **Status**: DEFINED — instrumentation partially present; pipeline not yet deployed
> **Depends on**: T121 (Aspects analytics manifests), T148 (Aspects kustomization wiring)
> **Verify script**: `scripts/qa/verify-product-kpi.sh`

---

## Purpose

This document defines Mereka Academy's North Star metrics, maps each metric to the underlying
Open edX platform events that feed it, describes the data pipeline from event emission to
ClickHouse storage to Superset dashboard, and audits which instrumentation exists versus
which gaps remain before live measurement is possible.

The goal is to connect the analytics infrastructure (Aspects/ClickHouse/Superset, T121) to
concrete business outcomes: are learners activating, progressing, completing, and returning?

---

## North Star Metrics

Mereka Academy is a talent and upskilling platform. The four North Star dimensions are:

| Dimension | North Star KPI | Target | Measurement Cadence |
|-----------|---------------|--------|---------------------|
| **Activation** | % of registered users who enroll in ≥ 1 course within 7 days | ≥ 60% | Weekly |
| **Completion** | Course completion rate (enrolled → certificate) | ≥ 40% | Monthly |
| **Retention** | 30-day learner return rate (active in month N who are active in month N+1) | ≥ 50% | Monthly |
| **Engagement** | Weekly Active Learners (WAL) — unique learners with ≥ 1 meaningful interaction | Trending up (no fixed target yet) | Weekly |

**North Star definition**: A single headline metric that captures the overall health of the
platform. For Mereka Academy it is **Monthly Active Completions** (MAC) — the count of unique
learners who complete at least one course unit per calendar month. MAC combines activation
(they enrolled), completion (they finished something), and retention (they came back).

---

## KPI Definitions and Event Mapping

### 1. Activation Rate

**Definition**: The proportion of newly registered users who enroll in at least one course
within 7 calendar days of account creation.

```
Activation Rate = (users who enrolled within 7 days of registration) / (total new registrations)
```

**Open edX Events** (openedx-events package, Redis Streams event bus):

| Event signal | Topic (Redis) | Key fields | Status |
|---|---|---|---|
| `org.openedx.learning.student.registration.completed.v1` | `dev-learning` | `user.id`, `user.email`, `user.username`, `created_at` | **CONFIGURED** (Redis Streams producer set in `tutor_env/env/apps/openedx/settings/lms/production.py`) |
| `org.openedx.learning.course.enrollment.changed.v1` | `enterprise-events` | `enrollment.user.id`, `enrollment.course.id`, `enrollment.created`, `enrollment.mode` | **CONFIGURED** (explicitly published in `deploy/k8s/base/apps/openedx/settings/lms/mereka_enterprise_channels.py`) |

**Gap**: Registration events are emitted via Redis Streams (`EVENT_BUS_PRODUCER`) but no consumer
is deployed to route them into ClickHouse. The Aspects pipeline (Ralph → ClickHouse) is not yet
wired (T148). Until Ralph is deployed and subscribed to these topics, events are emitted but
not persisted for analytics.

**Dashboard query (ClickHouse, once pipeline is live)**:
```sql
SELECT
  toStartOfWeek(toDateTime(registration_ts)) AS week,
  countDistinct(user_id) AS registrations,
  countDistinct(enrolled_user_id) AS activated,
  round(activated / registrations * 100, 1) AS activation_rate_pct
FROM (
  SELECT
    r.user_id,
    r.timestamp AS registration_ts,
    e.user_id AS enrolled_user_id
  FROM openedx.xapi_events r
  LEFT JOIN openedx.xapi_events e
    ON r.user_id = e.user_id
    AND e.verb = 'registered'
    AND e.verb_enrolled = 'enrolled'
    AND dateDiff('day', r.timestamp, e.timestamp) BETWEEN 0 AND 7
  WHERE r.verb = 'registered'
)
GROUP BY week
ORDER BY week DESC;
```

---

### 2. Completion Rate

**Definition**: The proportion of active course enrollments that result in a certificate or
course completion within a cohort window.

```
Completion Rate = (unique users who received a passing grade or certificate) / (total active enrollments)
```

**Open edX Events**:

| Event signal | Topic | Key fields | Status |
|---|---|---|---|
| `org.openedx.learning.course.enrollment.changed.v1` | `enterprise-events` | `enrollment.user.id`, `enrollment.course.id`, `enrollment.mode` | **CONFIGURED** |
| `org.openedx.learning.course.passing.status.updated.v1` | `enterprise-events` | `passing_status.user.id`, `passing_status.course.id`, `passing_status.is_passing` | **CONFIGURED** (explicitly in enterprise channels settings) |
| `org.openedx.learning.certificate.created.v1` | not yet configured | `certificate.user.id`, `certificate.course.id`, `certificate.mode` | **GAP — not in EVENT_BUS_PRODUCER_CONFIG** |

**Additional instrumentation (DB-level, via `scripts/analytics/openedx-analytics.py`)**:
The repo includes a Django shell script that queries `CourseEnrollment` and `GeneratedCertificate`
models directly. This provides a manual baseline today but does not feed the event pipeline.

**Gap**: Certificate creation events (`org.openedx.learning.certificate.created.v1`) are emitted
by the LMS internally (via `openedx-events` signals) but are not configured in
`EVENT_BUS_PRODUCER_CONFIG` and therefore not published to the Redis Streams event bus.
Add the following to `deploy/k8s/base/apps/openedx/settings/lms/mereka_enterprise_channels.py`
(or equivalent production patch) to close this gap:

```python
EVENT_BUS_PRODUCER_CONFIG.setdefault(
    "org.openedx.learning.certificate.created.v1", {}
).setdefault("aspects-events", {"event_key_field": "certificate.user.id", "enabled": True})
```

**Dashboard query (ClickHouse)**:
```sql
SELECT
  toStartOfMonth(enrollment_ts) AS cohort_month,
  countDistinct(user_id) AS enrolled,
  countDistinctIf(user_id, is_passing = true) AS completed,
  round(completed / enrolled * 100, 1) AS completion_rate_pct
FROM openedx.enrollments
GROUP BY cohort_month
ORDER BY cohort_month DESC;
```

---

### 3. Retention Rate (30-day)

**Definition**: Of learners who were active in month N (had at least one meaningful interaction),
what proportion returned and were active again in month N+1.

```
Retention Rate = |active(N) ∩ active(N+1)| / |active(N)|
```

A "meaningful interaction" is defined as any of: course unit viewed, problem attempted,
video played, forum post created.

**Open edX Events**:

| Event signal | Topic | Key fields | Status |
|---|---|---|---|
| `org.openedx.learning.sequence.tab.viewed.v1` | not configured | `user.id`, `course.id`, `timestamp` | **GAP** |
| `org.openedx.learning.problem.submitted.v1` | not configured | `user.id`, `course.id`, `problem.id` | **GAP** |
| `org.openedx.learning.video.subsection.viewed.v1` (xAPI: `viewed`) | not configured | `user.id`, `video.id` | **GAP** |
| Forum interactions (openedx-forum v2) | not configured | `user.id`, `course.id` | **GAP** |

**Partial instrumentation (custom app)**:
`infrastructure/tutor/custom-apps/openedx_video_analytics/` captures video playback events
(`played`, `paused`, `seeked`, `completed`, `ended`) in Django's MySQL database via the
`VideoPlaybackEvent` model. These events are NOT routed to the Redis Streams event bus or
ClickHouse. They exist as a standalone analytics silo.

**Gap**: No interaction events are currently published to the event bus for retention
measurement. The video analytics custom app captures video events in MySQL only. Sequence
view events, problem submission events, and forum interactions have no consumer-side
wiring to ClickHouse.

**Dashboard query (ClickHouse — once events are routed)**:
```sql
WITH
  active_n AS (
    SELECT DISTINCT user_id, toStartOfMonth(timestamp) AS month
    FROM openedx.xapi_events
    WHERE verb IN ('viewed', 'interacted', 'progressed')
  ),
  active_np1 AS (
    SELECT DISTINCT user_id, toStartOfMonth(timestamp) AS month
    FROM openedx.xapi_events
    WHERE verb IN ('viewed', 'interacted', 'progressed')
  )
SELECT
  n.month AS cohort_month,
  countDistinct(n.user_id) AS active_in_n,
  countDistinct(np1.user_id) AS returned_in_n1,
  round(returned_in_n1 / active_in_n * 100, 1) AS retention_rate_pct
FROM active_n n
LEFT JOIN active_np1 np1
  ON n.user_id = np1.user_id
  AND np1.month = addMonths(n.month, 1)
GROUP BY cohort_month
ORDER BY cohort_month DESC;
```

---

### 4. Engagement — Weekly Active Learners (WAL)

**Definition**: Count of unique learners who performed at least one meaningful interaction
(course view, problem attempt, video play, forum post) in a 7-day window ending on Sunday.

**Open edX Events** (same signals as retention):

| Event signal | Status |
|---|---|
| `org.openedx.learning.sequence.tab.viewed.v1` | **GAP** |
| `org.openedx.learning.problem.submitted.v1` | **GAP** |
| Video analytics (custom app, MySQL) | **PARTIAL — not in event bus** |
| Forum post/reply signals | **GAP** |

**Dashboard query (ClickHouse)**:
```sql
SELECT
  toStartOfWeek(timestamp) AS week,
  countDistinct(user_id) AS weekly_active_learners
FROM openedx.xapi_events
WHERE verb IN ('viewed', 'interacted', 'progressed', 'played')
GROUP BY week
ORDER BY week DESC
LIMIT 12;
```

---

### 5. North Star — Monthly Active Completions (MAC)

**Definition**: Count of unique learners who complete at least one course unit (grade > 0
recorded against a problem or unit) in a calendar month.

```
MAC = COUNT(DISTINCT user_id WHERE unit_completion_event in calendar month)
```

**Open edX Events**:

| Event signal | Topic | Status |
|---|---|---|
| `org.openedx.learning.course.passing.status.updated.v1` | `enterprise-events` | **CONFIGURED** |
| `org.openedx.learning.unit.completed.v1` (if available) | not configured | **GAP** |

**Note**: The `passing.status.updated` event fires when a learner crosses the passing threshold
for a whole course. It does not fire for individual unit completions. Per-unit completion
tracking requires either the `org.openedx.learning.unit.completed.v1` signal (added in
Open edX Redwood) or a dbt aggregation model over grade events.

**Dashboard query (ClickHouse)**:
```sql
SELECT
  toStartOfMonth(timestamp) AS month,
  countDistinct(user_id) AS mac
FROM openedx.xapi_events
WHERE verb = 'completed'
  AND object_type IN ('course', 'unit', 'module')
GROUP BY month
ORDER BY month DESC;
```

---

## Data Pipeline: Events → ClickHouse → Dashboard

```
┌─────────────────────────────────────────────────────────────────┐
│  Open edX Platform (LMS / CMS / MFEs)                          │
│                                                                  │
│  Django Signal → openedx-events → edx-event-bus-redis producer  │
│                                                                  │
│  Configured topics:                                              │
│    enterprise-events: enrollment.changed, passing.status.updated │
│    (gaps):            registration, certificate, view, problem   │
└─────────────────────┬───────────────────────────────────────────┘
                      │  Redis Streams (DB 0, topic prefix: dev/prod)
                      │
          ┌───────────▼────────────┐
          │   Ralph (xAPI LRS)     │  ← NOT YET DEPLOYED (see T148)
          │   Receives xAPI 1.0.3  │
          │   Writes to ClickHouse │
          └───────────┬────────────┘
                      │  HTTP bulk insert
                      │
          ┌───────────▼────────────┐
          │   ClickHouse           │  ← MANIFESTS EXIST, not wired (T148)
          │   openedx.xapi_events  │
          │   openedx.enrollments  │
          │   openedx.completions  │
          │   TTL: 365 days raw    │
          └───────────┬────────────┘
                      │  SQL (ClickHouse native driver)
                      │
          ┌───────────▼────────────┐
          │   dbt models           │  ← NOT YET DEFINED
          │   KPI aggregations     │
          │   (enrollment_rate,    │
          │    completion_rate,    │
          │    retention_cohort)   │
          └───────────┬────────────┘
                      │
          ┌───────────▼────────────┐
          │   Superset Dashboards  │  ← MANIFESTS EXIST, not wired (T148)
          │   analytics.academyv2  │
          │   .mereka.{io,dev}     │
          │   Auth: Authentik SSO  │
          └────────────────────────┘

Supplementary path (today, not connected to main pipeline):
  openedx_video_analytics (custom app)
    → MySQL VideoPlaybackEvent table
    → Daily Celery aggregation → VideoAnalyticsSummary table
    → (no Superset connection)
```

### Current Pipeline State

| Stage | Status | Location |
|-------|--------|----------|
| Event bus producer (Redis Streams) | **ACTIVE** — partial signals only | `tutor_env/env/apps/openedx/settings/lms/production.py` |
| Ralph (xAPI LRS) | **NOT DEPLOYED** | Planned for T148 |
| ClickHouse | **MANIFESTS EXIST** — not in kustomization | `deploy/k8s/base/plugins/aspects/` |
| Superset | **MANIFESTS EXIST** — not in kustomization | `deploy/k8s/base/plugins/aspects/` |
| dbt models | **NOT CREATED** | Gap |
| Video analytics silo | **ACTIVE** — MySQL only, no pipeline | `infrastructure/tutor/custom-apps/openedx_video_analytics/` |

---

## Instrumentation Audit

### Signals Currently Emitted to Event Bus

| Signal | Published to Redis Streams | Topic | File |
|--------|---------------------------|-------|------|
| `org.openedx.learning.course.enrollment.changed.v1` | YES | `enterprise-events` | `mereka_enterprise_channels.py` |
| `org.openedx.learning.course.passing.status.updated.v1` | YES | `enterprise-events` | `mereka_enterprise_channels.py` |

### Signals With Known Gaps

| Signal | Maps to KPI | Gap Type | Resolution |
|--------|-------------|----------|------------|
| `org.openedx.learning.student.registration.completed.v1` | Activation | Not in `EVENT_BUS_PRODUCER_CONFIG` for any analytics topic | Add to `mereka_enterprise_channels.py` under `aspects-events` topic |
| `org.openedx.learning.certificate.created.v1` | Completion | Not in `EVENT_BUS_PRODUCER_CONFIG` | Add to `mereka_enterprise_channels.py` |
| `org.openedx.learning.sequence.tab.viewed.v1` | Retention, Engagement | Not in `EVENT_BUS_PRODUCER_CONFIG` | Add; note: high-volume, may need sampling |
| `org.openedx.learning.problem.submitted.v1` | Retention, Engagement | Not in `EVENT_BUS_PRODUCER_CONFIG` | Add |
| `org.openedx.learning.unit.completed.v1` | North Star MAC | Not in `EVENT_BUS_PRODUCER_CONFIG`; requires Open edX Redwood+ | Verify available in installed Tutor version |
| Video events (`played`, `completed`) | Engagement, Retention | In MySQL via custom app only — not in event bus | Add Redis Streams producer to `openedx_video_analytics` or migrate to xAPI via Aspects |
| Forum interactions | Engagement, Retention | No signal configured | Depends on Forum v2 (in-process); check `openedx-forum` event signals |

### Custom App Instrumentation Summary

| Custom App | What It Captures | Storage | Event Bus Connected? |
|---|---|---|---|
| `openedx_video_analytics` | `played`, `paused`, `seeked`, `completed`, `ended` with position/duration | MySQL (`VideoPlaybackEvent` + `VideoAnalyticsSummary`) | NO |
| `openedx_notifications` | In-app notification delivery via ACE | Django model | NO |
| `openedx_prometheus` | HTTP request rate, error rate, DB query time | Prometheus (scraped) | N/A — operational, not learning |
| `openedx_email_digests` | Digest delivery events | ACE channel logs | NO |

---

## Superset Dashboard Plan

Once the pipeline is live (T148 + Ralph deployed), the following Superset dashboards should
be created to surface the KPIs defined above:

| Dashboard | Primary KPI | Chart Types | Access |
|---|---|---|---|
| **North Star Overview** | MAC, WAL, Activation Rate | Big-number tiles + trend line (weekly) | Platform Admin |
| **Activation Funnel** | Activation Rate by week/cohort | Funnel chart, bar chart by registration source | Platform Admin |
| **Completion Tracker** | Completion Rate by course and cohort | Heatmap, bar chart ranked by course | Platform Admin + Course Instructors |
| **Retention Cohort** | 30-day retention by signup cohort | Cohort retention table (% by week) | Platform Admin |
| **Engagement — WAL** | Weekly Active Learners | Line chart over 12 weeks | Platform Admin |
| **Video Analytics** | Video completion rate, avg watch time | Bar chart by video, scatter plot | Instructors |

### Dashboard Access

- **URL (dev)**: `https://analytics.academyv2.mereka.dev`
- **URL (prod)**: `https://analytics.academyv2.mereka.io`
- **Auth**: Authentik OAuth2 SSO (`auth0.mereka.io`)
- **Default role on first login**: `Gamma` (read-only)
- **Promoted to Alpha** (can create charts): Platform Admin and Senior Instructors

---

## Instrumentation Gaps — Prioritised

| Priority | Gap | KPIs Affected | Estimated Effort |
|----------|-----|---------------|-----------------|
| P0 | Deploy Ralph + wire Aspects into kustomization (T148) | All KPIs | 8-10 hours (tracked in T148) |
| P1 | Add `certificate.created.v1` to `EVENT_BUS_PRODUCER_CONFIG` | Completion Rate | 30 min code change + test |
| P1 | Add `student.registration.completed.v1` to producer config | Activation Rate | 30 min code change + test |
| P2 | Add `sequence.tab.viewed.v1` and `problem.submitted.v1` | Retention, WAL | 1 hour; review volume impact first |
| P2 | Connect `openedx_video_analytics` to event bus or migrate to xAPI | Video engagement | 2-4 hours + schema migration |
| P3 | Define dbt models for KPI aggregations | All dashboard queries | 4-8 hours |
| P3 | Verify `unit.completed.v1` is available in installed Tutor/LMS version | North Star MAC | 1 hour spike |
| P3 | Import pre-built Superset dashboards (JSON export from Aspects repo) | Dashboard readiness | 2 hours |

---

## Interim Measurement (Before Pipeline Is Live)

Until the Aspects/ClickHouse pipeline is deployed, KPIs can be measured manually:

```bash
# Run against LMS pod
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell < scripts/analytics/openedx-analytics.py

# Or with arguments
kubectl exec -n mereka-lms deployment/lms -- \
  python /path/to/openedx-analytics.py --summary
```

The `openedx-analytics.py` script queries `CourseEnrollment`, `GeneratedCertificate`, and
`CourseOverview` models directly and prints:
- Total enrollments, active enrollments
- Certificates issued
- Per-course breakdown

This covers Activation (partial) and Completion but does not cover Retention or WAL.

---

## References

- Analytics pipeline spec: `specs/analytics-pipeline_spec.md`
- Aspects analytics setup: `docs/operations/ASPECTS_ANALYTICS_SETUP.md`
- Analytics decision gate: `docs/architecture/ANALYTICS_DECISION_GATE.md`
- Data retention policy: `docs/operations/ANALYTICS_DATA_RETENTION.md`
- Enterprise channels settings: `deploy/k8s/base/apps/openedx/settings/lms/mereka_enterprise_channels.py`
- Video analytics custom app: `infrastructure/tutor/custom-apps/openedx_video_analytics/`
- Analytics query tool: `scripts/analytics/openedx-analytics.py`
- Aspects K8s manifests: `deploy/k8s/base/plugins/aspects/`
- T148 (wire Aspects): tracked in `TRACKER.md`
- Open edX event signals: https://docs.openedx.org/projects/openedx-events/en/latest/
- xAPI verb registry: https://registry.tincanapi.com/
