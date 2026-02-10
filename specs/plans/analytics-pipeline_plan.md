---
spec: analytics-pipeline_spec.md
tier: 2
status: draft
estimated_effort: "6-8 weeks (1 engineer)"
owner: engineering
last_updated: "2026-02-10"
depends_on:
  - repository-structure_spec.md
  - secrets-management_spec.md
  - tutor-configuration_spec.md
  - k8s-deployment_spec.md
---

# Analytics Pipeline (Aspects/Panorama) -- Implementation Plan

**Source Spec**: `specs/analytics-pipeline_spec.md`

## Summary

This plan implements a learning analytics data pipeline using Open edX Aspects to collect xAPI events from LMS/CMS/MFEs, store them in ClickHouse, and visualize them in Apache Superset dashboards. Significant infrastructure already exists: K8s manifests for ClickHouse, Superset, and data sync jobs are in `deploy/k8s/base/plugins/aspects/`. The remaining work is to wire up Aspects event routing in Open edX, harden the existing manifests (secrets via ExternalSecrets, retention policies, PII scrubbing), build pre-built dashboards, enable instructor embedding, and add observability and verification scripts.

## Prerequisites

| Prerequisite | Source | Status |
|--------------|--------|--------|
| K8s cluster in `mereka-lms` namespace | `specs/k8s-deployment_spec.md` | Existing |
| Secrets pipeline (Infisical -> GCP SM -> ExternalSecrets) | `specs/secrets-management_spec.md` | Existing |
| MySQL (Cloud SQL) accessible from cluster | `specs/k8s-deployment_spec.md` | Existing |
| Redis in-cluster | `deploy/k8s/base/` | Existing |
| Observability stack (Prometheus, Grafana) | `specs/observability-stack_spec.md` | Tier 2 (parallel) |
| ClickHouse + Superset K8s manifests | `deploy/k8s/base/plugins/aspects/` | Existing (needs hardening) |

## Existing Infrastructure Audit

The following artifacts already exist and will be hardened rather than built from scratch:

| Artifact | Path | Status |
|----------|------|--------|
| ClickHouse deployment | `deploy/k8s/base/plugins/aspects/deployments.yml` | Deployed, needs retention policy |
| Superset deployment | `deploy/k8s/base/plugins/aspects/deployments.yml` | Deployed, needs RBAC |
| Superset worker | `deploy/k8s/base/plugins/aspects/deployments.yml` | Deployed |
| Services (ClusterIP) | `deploy/k8s/base/plugins/aspects/services.yml` | Deployed |
| PVC (10Gi) | `deploy/k8s/base/plugins/aspects/volumes.yml` | Deployed |
| Init jobs (schema + admin) | `deploy/k8s/base/plugins/aspects/jobs.yml` | Deployed |
| Data sync (MySQL -> CH) | `deploy/k8s/base/plugins/aspects/sync-job.yml` | Deployed, daily CronJob |
| ConfigMaps (CH config, Superset config) | `deploy/k8s/base/plugins/aspects/configmaps.yml` | Deployed |
| Secrets (placeholder) | `deploy/k8s/base/plugins/aspects/secrets.yml` | Placeholder -- needs ExternalSecrets |
| Ingress (analytics.academyv2.mereka.io) | `deploy/k8s/base/plugins/aspects/ingress.yml` | Deployed |
| Kustomization | `deploy/k8s/base/plugins/aspects/kustomization.yaml` | Deployed |
| Legacy analytics scripts | `scripts/analytics/*.py` | Exist (enrollment/certificate exports) |

---

## Task Breakdown

### Phase 1: Secrets and Foundation Hardening

- [ ] **[M] Task 1.1**: Migrate Aspects secrets to ExternalSecrets (`deploy/k8s/base/secrets/external-secrets.yaml`) | AC: N/A (prerequisite) | Depends: None
  - Add `MEREKA_LMS_CLICKHOUSE_PASSWORD`, `MEREKA_LMS_SUPERSET_SECRET_KEY`, `MEREKA_LMS_SUPERSET_DB_PASSWORD`, `MEREKA_LMS_SUPERSET_OAUTH_CLIENT_SECRET` to Infisical
  - Create ExternalSecret resource referencing `aspects-secrets`
  - Remove placeholder `secrets.yml` from kustomization
  - **Done**: `kubectl get externalsecret aspects-secrets -n mereka-lms` shows `SecretSynced`

- [ ] **[S] Task 1.2**: Add ClickHouse retention policy -- TTL on `xapi_events` table (`deploy/k8s/base/plugins/aspects/jobs.yml`) | AC: #3 | Depends: None
  - Add `ALTER TABLE openedx.xapi_events MODIFY TTL timestamp + INTERVAL 90 DAY DELETE` to the init job
  - Add TTL to enrollments and completions tables as well
  - **Done**: `clickhouse-client --query "SHOW CREATE TABLE openedx.xapi_events"` contains `TTL timestamp + toIntervalDay(90)`

- [ ] **[S] Task 1.3**: Enable ClickHouse compression for data older than 7 days (`deploy/k8s/base/plugins/aspects/configmaps.yml`) | AC: N/A (SHOULD) | Depends: None
  - Add `<merge_tree>` config with `min_bytes_to_recompress_to_codecs` and ZSTD codec
  - **Done**: `system.parts` shows compressed partitions for data >7 days old

### Phase 2: Aspects Event Routing (Core Pipeline)

- [ ] **[L] Task 2.1**: Enable Aspects plugin in Tutor and configure event routing (`infrastructure/tutor/apply-patches.sh`, `tutor_env/config.yml`) | AC: #1, #2 | Depends: 1.1
  - Run `tutor plugins enable aspects` and `tutor config save`
  - Configure `ASPECTS_EVENT_ROUTING_BACKENDS` to point to ClickHouse
  - Set `ASPECTS_EVENT_BATCH_SIZE=500` for batch writes
  - Apply patches via `apply-patches.sh`
  - Build openedx image with Aspects: `tutor images build openedx`
  - **Done**: `tutor plugins list | grep aspects` shows enabled; events appear in ClickHouse within 10 minutes of LMS activity

- [ ] **[M] Task 2.2**: Configure xAPI event transformation and PII scrubbing (`infrastructure/tutor/apply-patches.sh`) | AC: #6 | Depends: 2.1
  - Ensure Aspects `event_routing_backends` config anonymizes actor fields
  - Hash `actor.mbox` with SHA-256 before writing to ClickHouse
  - Strip email, IP address, and full name from event payloads
  - Add Tutor patch to configure PII exclusion list
  - **Done**: `clickhouse-client --query "SELECT actor_id FROM openedx.xapi_events LIMIT 10"` shows only hashed identifiers, no emails

- [ ] **[M] Task 2.3**: Add xAPI events table schema update for all required verb types (`deploy/k8s/base/plugins/aspects/jobs.yml`) | AC: #2 | Depends: 2.1
  - Verify `xapi_events` table schema supports all 6 verb types (registered, enrolled, completed, viewed, interacted, progressed)
  - Add materialized view for common aggregations (daily active users, completion rates)
  - **Done**: `clickhouse-client --query "SELECT DISTINCT verb_id FROM openedx.xapi_events"` returns at least 3 verb types after test activity

### Phase 3: Superset Dashboards and Access Control

- [ ] **[L] Task 3.1**: Create pre-built Superset dashboards (`deploy/k8s/base/plugins/aspects/dashboards/`) | AC: #5 | Depends: 2.1
  - Create JSON dashboard exports for:
    - Learner engagement (DAU/WAU)
    - Course completion rates
    - Problem-level analytics (avg attempts, success rate)
    - Content popularity (most viewed units)
    - Platform health (error rates, slow queries)
  - Create Superset import job to load dashboards on init
  - **Done**: Superset UI shows 5 pre-built dashboards after init job runs

- [ ] **[M] Task 3.2**: Configure RBAC for Superset dashboards (`deploy/k8s/base/plugins/aspects/configmaps.yml`) | AC: #4, #5 | Depends: 3.1
  - Configure Authentik OAuth roles to map to Superset roles (Admin, Alpha, Gamma)
  - Restrict dashboard access to `staff` users only (via Authentik group membership)
  - Verify non-staff users cannot access Superset
  - **Done**: Non-staff OAuth login to Superset is denied; staff users see all dashboards

- [ ] **[M] Task 3.3**: Enable dashboard embedding in LMS (`infrastructure/tutor/apply-patches.sh`) | AC: #7 | Depends: 3.1
  - Configure Superset `EMBEDDED_SUPERSET` feature flag
  - Add `TALISMAN_ENABLED = False` or configure CSP to allow iframe embedding from LMS domain
  - Create Tutor patch to add Superset embedding JavaScript to LMS templates
  - Configure CORS to allow LMS origin (`academyv2.mereka.io`)
  - **Done**: Instructor can view embedded Superset dashboard within an LMS course page

### Phase 4: Data Deletion and GDPR

- [ ] **[M] Task 4.1**: Implement GDPR data deletion pipeline (`scripts/analytics/delete-user-events.sh`) | AC: #8 | Depends: 2.2
  - Create script that accepts hashed user ID and deletes all events from ClickHouse
  - Handle deletion across all tables: `xapi_events`, `enrollments`, `completions`
  - Log deletion operations for audit trail
  - **Done**: Running script with a hashed user ID results in zero rows for that user across all tables

- [ ] **[S] Task 4.2**: Add deletion verification query (`scripts/analytics/verify-user-deletion.sh`) | AC: #8 | Depends: 4.1
  - Script that queries all ClickHouse tables for a given user hash and returns count
  - Returns exit code 0 only if count is 0 across all tables
  - **Done**: Script returns exit 0 after deletion, exit 1 if user data still exists

### Phase 5: Observability

- [ ] **[M] Task 5.1**: Add Prometheus metrics for Aspects event pipeline (`deploy/k8s/base/monitoring/servicemonitor-clickhouse.yaml`) | AC: N/A (OBS) | Depends: 2.1
  - Deploy ClickHouse Prometheus exporter sidecar or configure native metrics endpoint
  - Create ServiceMonitor for ClickHouse (disk usage, query latency, write throughput, active connections)
  - Create ServiceMonitor for Superset (dashboard load time, query success/failure rate)
  - **Done**: `kubectl get servicemonitor -n mereka-lms | grep -E "clickhouse|superset"` shows both monitors

- [ ] **[M] Task 5.2**: Create Grafana dashboard for analytics pipeline health (`infrastructure/monitoring/dashboards/analytics-pipeline.json`) | AC: N/A (OBS) | Depends: 5.1
  - Panels: event processing lag, ClickHouse disk usage, write throughput, query latency p50/p95/p99, Superset active users
  - Include event processing lag as primary SLI (target: <=10 min)
  - **Done**: Grafana dashboard loads and shows live data from ClickHouse metrics

- [ ] **[S] Task 5.3**: Add PrometheusRule alerts for analytics pipeline (`deploy/k8s/base/monitoring/prometheusrule-analytics.yaml`) | AC: N/A (OBS) | Depends: 5.1
  - MUST alert: event processing lag >10 minutes
  - MUST alert: ClickHouse disk usage >80%
  - SHOULD alert: write throughput drops >50%
  - SHOULD alert: Superset query failure rate >5%
  - **Done**: `kubectl get prometheusrule -n mereka-lms | grep analytics` shows rule; Alertmanager test fires correctly

### Phase 6: Verification and QA

- [ ] **[M] Task 6.1**: Create analytics pipeline verification script (`scripts/qa/verify-analytics-pipeline.sh`) | AC: #1, #2, #3, #4, #5, #6 | Depends: 2.1, 3.1
  - Verify Aspects plugin enabled
  - Verify ClickHouse pod running and healthy
  - Verify Superset pod running and healthy
  - Verify events exist in ClickHouse
  - Verify retention TTL configured
  - Verify no PII in sample events
  - Verify dashboards exist in Superset
  - **Done**: Script exits 0 with all checks passing

- [ ] **[S] Task 6.2**: Create PII audit script (`scripts/qa/audit-analytics-pii.sh`) | AC: #6 | Depends: 2.2
  - Query ClickHouse for patterns matching email addresses, IP addresses, or names
  - Use regex to detect `@` in actor fields, IPv4/IPv6 patterns, common name patterns
  - **Done**: Script exits 0 when no PII found, exits 1 with details if PII detected

- [ ] **[S] Task 6.3**: Create smoke test for analytics endpoints (`scripts/qa/smoke-test-analytics.sh`) | AC: #4 | Depends: 3.2
  - Verify Superset health endpoint returns 200
  - Verify ClickHouse ping endpoint returns 200
  - Verify ingress route (analytics.academyv2.mereka.io) returns 200
  - **Done**: Script exits 0 with all health checks passing

### Phase 7: Rollout

- [ ] **[S] Task 7.1**: Create gradual rollout configuration (`infrastructure/tutor/aspects-rollout.sh`) | AC: N/A (rollout) | Depends: 2.1
  - Phase 1: CMS events only (low volume, 1 week)
  - Phase 2: Add LMS events (monitor ClickHouse load, 1 week)
  - Phase 3: Add MFE events (full pipeline active)
  - Script to toggle event sources per rollout phase
  - **Done**: Script accepts phase number and configures event routing accordingly

- [ ] **[S] Task 7.2**: Document rollback procedure (`docs/operations/analytics-rollback.md`) | AC: N/A (rollout) | Depends: 2.1
  - Step-by-step rollback for event routing (disable without losing data)
  - Step-by-step rollback for Superset (keep running for analysis)
  - Full removal procedure
  - **Done**: Document reviewed and tested manually

### Phase 8: Documentation

- [ ] **[S] Task 8.1**: Update operations documentation (`docs/operations/ANALYTICS_RUNBOOK.md`) | AC: N/A (docs) | Depends: All build tasks
  - Runbook for analytics pipeline: event backpressure, disk space, query timeout
  - Symptom-to-fix troubleshooting table
  - Superset admin operations (reset password, import dashboards)
  - ClickHouse admin operations (drop partition, check disk)
  - **Done**: Document exists and covers all edge cases from spec

- [ ] **[S] Task 8.2**: Update CLAUDE.md with analytics section (`CLAUDE.md`) | AC: N/A (docs) | Depends: All build tasks
  - Add analytics URLs to running apps table
  - Add Aspects/ClickHouse/Superset to diagnostics section
  - **Done**: CLAUDE.md includes analytics pipeline reference

---

## Milestones

| Milestone | Phases | Target | Gate |
|-----------|--------|--------|------|
| **M1: Secrets + Retention** | 1 | Week 1 | ExternalSecrets synced, TTL active |
| **M2: Event Pipeline Live** | 2 | Week 2-3 | xAPI events flowing to ClickHouse |
| **M3: Dashboards Ready** | 3 | Week 4-5 | 5 dashboards visible, RBAC enforced |
| **M4: GDPR Deletion** | 4 | Week 5 | Deletion script works end-to-end |
| **M5: Observable** | 5 | Week 6 | Grafana dashboard + alerts firing |
| **M6: Verified** | 6, 7, 8 | Week 6-8 | All QA scripts pass, docs complete |

---

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Aspects plugin incompatible with Tutor v21/Ulmo | High | Medium | Test in local environment first; check tutor-contrib-aspects version compatibility |
| ClickHouse disk fills during peak usage | Medium | Medium | TTL configured (90d), alerts at 80%, PVC can be resized |
| PII leaks through event transformation edge cases | High | Low | Automated PII audit script runs daily; block fields at source |
| Superset OAuth integration fails with Authentik | Medium | Medium | Fallback to local admin login; OAuth config already exists in configmap |
| Event processing lag exceeds 10min SLA | Medium | Medium | Batch size tunable; ClickHouse horizontally scalable |
| MFE events flood ClickHouse (higher volume than LMS) | Medium | Medium | Gradual rollout (CMS -> LMS -> MFE); batch size increase |
| Historical data backfill corrupts existing data | Medium | Low | Backfill uses INSERT not REPLACE; test on staging first |

---

## Task Summary

| Category | Count | Effort |
|----------|-------|--------|
| Build (Phases 1-4) | 10 | ~70% |
| Observability (Phase 5) | 3 | ~10% |
| Verification/QA (Phase 6) | 3 | ~10% |
| Rollout (Phase 7) | 2 | ~5% |
| Docs (Phase 8) | 2 | ~5% |
| **Total** | **20** | **6-8 weeks** |

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-008) has at least one build task
- [x] Every acceptance criterion has at least one test/verification task
- [x] Every edge case from the spec has mitigation in the plan or verification scripts
- [x] Test tasks cover both happy path and failure modes
- [x] File paths specified for each task
- [x] Dependencies identified for all tasks
- [x] Complexity estimated (S/M/L) for each task
- [x] Observability tasks cover metrics, dashboards, and alerts
- [x] Rollout plan includes gradual phases and rollback
- [x] Source spec linked in header
