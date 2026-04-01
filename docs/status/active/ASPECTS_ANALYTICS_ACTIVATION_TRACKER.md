# Aspects Analytics — Operational Activation Tracker

**Date**: 2026-04-01
**Status**: DEV + STAGING OPERATIONAL. Reporting layer built. Dashboards imported. Live pipeline proven. Prod dormant (0 replicas).
**Owner**: Platform team

---

## Current Runtime State

### Dev (mereka-lms-dev, rke2-nonprod)

| Layer | Status | Evidence |
|-------|--------|----------|
| ClickHouse 25.8 | RUNNING | 4 databases, 41 Alembic migrations, 37 dbt models |
| Superset 4.1.1 | RUNNING | 18 dashboards, 89 datasets, OAuth login works |
| Ralph 4.1.0 | RUNNING | Healthy, ClickHouse connected |
| Worker + Beat | RUNNING | Celery beat scheduling async tasks |
| xAPI pipeline | PROVEN | 15 events flowing (raw → parsed → reporting) |
| Event sinks | PROVEN | 352K enrollments, 110K users, 37 courses, 2.9K blocks |
| RouterConfiguration | ACTIVE | id=2, xAPI, http://ralph:8100/xAPI, enabled=True |

### Staging (stg-mereka-lms, rke2-nonprod)

| Layer | Status | Evidence |
|-------|--------|----------|
| ClickHouse 25.8 | RUNNING | 4 databases, full schema |
| Superset 4.1.1 | RUNNING | 18 dashboards, OAuth login works |
| Ralph 4.1.0 | RUNNING | Healthy |
| Worker | RUNNING | — |
| xAPI pipeline | WIRED | RouterConfiguration active, 0 events (low staging traffic) |
| Event sinks | PROVEN | 146K enrollments, 94K users, 327 courses |

### Prod (mereka-lms, rke2-nonprod)

| Layer | Status | Notes |
|-------|--------|-------|
| All Aspects pods | DORMANT (0 replicas) | `aspects-replicas-zero.yaml` patch active |
| Init sequence | NOT RUN | Needs: remove zero-replica patch, run init script |

---

## Completed Work

- [x] ClickHouse 25.8 + Superset 4.1.1 + Ralph 4.1.0 deployed (dev + staging)
- [x] Alembic migrations (41/41) on both environments
- [x] dbt models (37/37) on both environments
- [x] Superset dashboards imported (18 dashboards, 166 charts, 93 datasets)
- [x] Event sink backfill (course_overviews, course_enrollment, user_profile, course_blocks)
- [x] RouterConfiguration for xAPI pipeline
- [x] OAuth login via Authentik (OIDC provider + application)
- [x] Auth groups scope mapping (PR #2309 merged — enables AUTH_ROLES_MAPPING)
- [x] Init script codified (`scripts/aspects/init-aspects-env.sh`)
- [x] Operations runbook (`docs/ops/runbooks/ASPECTS_OPERATIONS.md`)
- [x] Monitoring rules (PrometheusRule for ClickHouse, Superset, Ralph)
- [x] ExternalSecret entries for CH user passwords
- [x] Tracking log PVC manifest + backfill documentation

## Remaining Work

### Immediate (no blockers)

- [ ] **Create GCP SM secrets** for CH users: `MEREKA_LMS_ASPECTS_CH_REPORT_PASSWORD`, `MEREKA_LMS_ASPECTS_CH_CMS_PASSWORD`, `MEREKA_LMS_ASPECTS_CH_LRS_PASSWORD`, `MEREKA_LMS_ASPECTS_RALPH_LMS_PASSWORD`
- [ ] **Wire tracking-logs PVC** to LMS deployment via bbi-infrastructure overlay patch
- [ ] **Prod activation**: Remove `aspects-replicas-zero.yaml` from prod overlay, run init sequence

### Operational (ongoing)

- [ ] **Retention policy**: Decide `ASPECTS_DATA_TTL_EXPRESSION` before data accumulates
- [ ] **ClickHouse user passwords**: Run `ALTER USER` with secrets from Infisical (currently plaintext `password`)
- [ ] **Staging worker CPU**: Unblock new LMS worker pod for better xAPI throughput

### Future

- [ ] **Superset 5.x/6.x upgrade**: Waiting for upstream tutor-contrib-aspects compatibility
- [ ] **Historical xAPI backfill**: Only possible after tracking log PVC is active and logs accumulate
- [ ] **ClickHouse backup**: Add Velero schedule or ClickHouse native backup for CH data PVC

---

## Version Family

| Component | Version | Constraint |
|-----------|---------|-----------|
| tutor-contrib-aspects | 3.0.3 | Aligned with Tutor 21.x (Ulmo) |
| aspects-dbt | v6.1.1 | Pinned in aspects image |
| Superset | 4.1.1 | edunext/aspects-superset:3.0.3 |
| ClickHouse | 25.8 LTS | Requires `check_table_dependencies=0` for Alembic |
| event-routing-backends | 9.3.8 | Must stay <9.4 (10.0+ requires Python 3.12) |
| platform-plugin-aspects | 1.1.2 | Must stay <1.1.3 (requires Python 3.12) |
| Ralph | 4.1.0 | fundocker/ralph:4.1.0 |
