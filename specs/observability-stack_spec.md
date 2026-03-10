---
title: "Observability Stack (Prometheus/Tempo/Loki)"
type: "feature_spec"
id: "SPEC-OBSERVABILITY-STACK"
status: "approved"
spec_class: "integration"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "runtime"
normativity: "normative"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/k8s-deployment_spec.md"
  - "specs/tutor-configuration_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/audit-observability.sh"
  - "scripts/qa/audit-grafana-dashboard.sh"
  - "scripts/qa/verify-alert-routing.sh"
interfaces:
  - "prometheus"
  - "tempo"
  - "loki"
  - "grafana"
tags:
  - "docs.evidence"
  - "docs.status"
  - "runtime.async-task"
summary: "Normative integration contract for metrics, logs, traces, alerting, and dashboarding across the Mereka LMS runtime."
links:
  related_docs:
    - "docs/ops/runbooks/OBSERVABILITY_QUICKSTART.md"
    - "docs/ops/monitoring/OBSERVABILITY_ENHANCEMENT_PLAN.md"
    - "docs/policies/operations/OBSERVABILITY_OWNERSHIP.md"
    - "docs/ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md"
    - "docs/reference/operations/MONITORING.md"
    - "docs/ops/runbooks/SLO_DASHBOARDS_SETUP.md"
    - "docs/reference/operations/ALERT_SEVERITY_MATRIX.md"
    - "docs/ops/runbooks/ALERT_TUNING_SOP.md"
    - "docs/reference/operations/LOGGING_AND_SENTRY.md"
    - "docs/ops/runbooks/GKE_LOKI_FORWARDING.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
  related_specs:
    - "specs/slo-sla-service-level-management_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/analytics-pipeline_spec.md"
    - "specs/ci-cd-pipeline_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A production-grade observability stack for the Mereka Academy Open edX deployment on GKE. The stack comprises Prometheus for metrics collection, Tempo for distributed tracing, Loki for centralized log aggregation, Alertmanager for alert routing, and Grafana for unified visualization. Together these tools give the engineering team full visibility into platform health, request latency, error rates, and resource consumption -- enabling fast incident detection and diagnosis.

## Why it matters

Open edX is a complex, multi-service platform (LMS, CMS, workers, forum, discovery, MFEs) running on Kubernetes. Without structured observability, failures are discovered by users instead of engineers, root-cause analysis takes hours instead of minutes, and capacity planning is guesswork. This stack transforms operations from reactive to proactive, directly protecting learner experience and platform reliability.

## Success looks like

- Every pod in `mereka-lms` is scraped for metrics with zero gaps
- An on-call engineer can go from alert to root cause in under 15 minutes using correlated metrics, logs, and traces in Grafana
- Critical alerts (OOM, crash loops, 5xx spikes) fire within 2 minutes and reach the team via Slack
- Dashboards load in under 3 seconds and display 30 days of historical metrics

# Agent Contract

## Scope

- In scope:
  - Prometheus deployment, ServiceMonitor configuration, and metrics scraping
  - Application-level metrics instrumentation via django-prometheus
  - Loki deployment, Promtail DaemonSet, and log forwarding
  - Tempo deployment and OpenTelemetry trace collection
  - Alertmanager deployment and critical alert rule configuration
  - Grafana deployment, datasource configuration, and dashboard provisioning
  - Meta-monitoring (observability of the observability stack itself)
- Out of scope:
  - Application-level bug fixes or feature work
  - Network-level monitoring beyond K8s pod metrics
  - Third-party SaaS integration (Datadog, New Relic, PagerDuty)
  - Grafana user/team/org management beyond basic access control

## Non-goals

- Application Performance Monitoring (APM) like Datadog/New Relic (too expensive)
- Business metrics/analytics (covered in analytics-pipeline_spec.md)
- Cost optimization monitoring (separate FinOps spec)
- Security event monitoring (SIEM, separate security spec)

## Requirements

### Metrics Collection (Prometheus)

- The system MUST deploy Prometheus to scrape metrics from all K8s workloads
- The system MUST configure ServiceMonitors for automatic pod discovery
- The system MUST collect pod-level metrics (CPU, memory, network, disk)
- The system MUST collect application metrics via `/metrics` endpoint (django-prometheus)
- The system MUST store metrics for 30 days (default retention)
- The system SHOULD use remote write to long-term storage (GCS or Thanos) for >30 days

### Application Metrics

The system MUST expose the following custom metrics from LMS/CMS:

| Metric | Type | Description |
|--------|------|-------------|
| `http_request_duration_seconds` | Histogram | Request latency by endpoint |
| `http_requests_total` | Counter | Total requests by status code |
| `django_db_query_duration_seconds` | Histogram | Database query latency |
| `django_cache_hit_ratio` | Gauge | Redis cache hit rate |
| `celery_task_duration_seconds` | Histogram | Background task duration |
| `lms_enrollment_total` | Counter | Total course enrollments |
| `lms_active_users` | Gauge | Currently authenticated users |

### Distributed Tracing (Tempo)

- The system SHOULD deploy Tempo for trace collection
- The system SHOULD instrument LMS/CMS with OpenTelemetry SDK
- The system SHOULD export traces via OTLP (OpenTelemetry Protocol)
- The system SHOULD correlate traces with logs via trace ID
- The system MAY enable trace sampling (10% of requests) to reduce volume

### Log Aggregation (Loki)

- The system MUST deploy Loki for centralized log storage
- The system MUST ship pod logs via Promtail DaemonSet
- The system MUST label logs with namespace, pod, container metadata
- The system MUST store logs for 7 days (default retention)
- The system SHOULD support log queries via LogQL in Grafana

### Alerting (Alertmanager)

- The system MUST deploy Alertmanager for alert routing
- The system MUST configure alert rules for critical conditions:
  - Pod crash loop (>3 restarts in 5 minutes)
  - OOM kills (container evicted due to memory)
  - High error rate (>5% of requests return 5xx)
  - Database connection pool exhaustion
  - Disk usage >80%
- The system SHOULD route alerts to Slack/email (configurable)

### Dashboards (Grafana)

- The system MUST deploy Grafana for visualization
- The system MUST configure datasources: Prometheus, Loki, Tempo
- The system SHOULD import pre-built dashboards:
  - Kubernetes cluster overview
  - Pod resource usage (CPU, memory)
  - Open edX LMS/CMS health
  - Database performance (MySQL, MongoDB)
  - Redis cache metrics
- The system MUST restrict dashboard access to authorized staff

### Non-Functional Requirements

- Prometheus scrape interval MUST be <= 30 seconds for all targets
- Alert firing-to-notification latency MUST be <= 2 minutes
- Grafana dashboard load time SHOULD be <= 3 seconds for standard queries (24h window)
- Loki log query response SHOULD be <= 5 seconds for queries spanning 1 hour
- Prometheus MUST handle at least 50,000 active time series without degradation
- Loki MUST ingest at least 500 KB/s of log volume without dropping entries
- The observability stack MUST NOT consume more than 20% of cluster CPU or 25% of cluster memory
- Prometheus MUST survive single-node failure without data loss (via persistent volume)
- Grafana MUST support at least 10 concurrent dashboard viewers without degradation
- All observability endpoints (Grafana, Prometheus UI) MUST require authentication

## Acceptance Criteria

- [ ] AC-001: Prometheus scrapes all pods: `kubectl get servicemonitor -n mereka-lms`
- [ ] AC-002: Grafana shows pod CPU/memory: Dashboard visible at `https://grafana.mereka.io`
- [ ] AC-003: LMS `/metrics` endpoint returns Prometheus metrics: `curl https://academyv2.mereka.io/metrics`
- [ ] AC-004: Loki receives logs: `logcli query '{namespace="mereka-lms"}' --limit 10`
- [ ] AC-005: Tempo receives traces: `tempo-cli query-trace <trace-id>`
- [ ] AC-006: Alerts fire on OOM: Simulate OOM and verify alert in Slack
- [ ] AC-007: Log correlation works: Click trace ID in Grafana, jumps to Loki logs
- [ ] AC-008: Metrics retention 30 days: Query old metrics: `rate(http_requests_total[30d])`

## Edge Cases

### High Cardinality Metrics

**Symptom**: Prometheus memory usage spikes, queries slow

**Cause**: Too many unique label combinations (e.g., endpoint, user_id)

**Mitigation**:
- Drop high-cardinality labels: `metric_relabel_configs` in Prometheus config
- Use recording rules to pre-aggregate metrics
- Limit label values to top N (e.g., top 100 endpoints)

### Log Volume Spikes

**Symptom**: Loki disk full, queries timeout

**Cause**: Debug logging enabled, error storm

**Recovery**:
```bash
# Reduce log retention
kubectl edit configmap loki -n mereka-lms
# Set retention_period: 3d (instead of 7d)

# Drop logs from noisy pod
logcli delete '{pod="noisy-pod"}' --start=2h
```

### Trace Sampling Decisions

**Symptom**: Can't find trace for failed request

**Cause**: 10% sampling missed the error case

**Mitigation**:
- Use head-based sampling (always trace errors)
- Increase sampling to 50% temporarily for debugging
- Implement tail-based sampling (Tempo feature)

### Alertmanager Notification Failure

**Symptom**: Critical alerts not reaching Slack

**Cause**: Webhook URL wrong, rate limiting, or silenced alerts

**Recovery**:
```bash
# Check Alertmanager status
kubectl logs -n mereka-lms -l app=alertmanager

# Test notification
curl -X POST https://alertmanager.mereka.io/api/v1/alerts \
  -d '[{"labels":{"alertname":"test","severity":"critical"}}]'
```

### Prometheus Scrape Failures

**Symptom**: Gaps in metrics, "target down" alerts

**Cause**: Pod not exposing /metrics, network policy block, or pod churn

**Recovery**:
```bash
# Check scrape targets
kubectl port-forward -n mereka-lms svc/prometheus 9090
# Visit http://localhost:9090/targets

# Verify pod exposes metrics
kubectl exec -n mereka-lms lms-pod -- curl localhost:8000/metrics
```

### Prometheus Self-Monitoring Blind Spot

**Symptom**: Prometheus goes down and nobody is alerted because Prometheus IS the alerting system.

**Cause**: Single Prometheus instance with no external watchdog. If Prometheus crashes, OOMs, or loses its storage volume, all alerting stops silently.

**Mitigation**:
- Deploy an external watchdog: GCP Cloud Monitoring uptime check on `https://prometheus.mereka.dev/-/healthy` (HTTP 200 expected)
- Configure GCP alert policy to notify Slack `#ops-alerts` if Prometheus health check fails for > 2 minutes
- Prometheus MUST expose `prometheus_tsdb_head_series` and `process_resident_memory_bytes` metrics; Grafana dashboard MUST show these
- Set Prometheus memory limit to 80% of available pod memory to prevent node-level OOM
- Use `--storage.tsdb.retention.size=15GB` (in addition to time-based retention) to prevent disk exhaustion

**Recovery**:
```bash
# If Prometheus pod is in CrashLoopBackOff:
kubectl -n mereka-lms delete pod -l app=prometheus  # Let K8s recreate
# If WAL is corrupted:
kubectl -n mereka-lms exec prometheus-pod -- promtool tsdb clean /prometheus
```

## Logging Pipeline Contract

### Canonical Log Sources

The system MUST collect logs from the following Open edX services:

| Service | Component Type | Log Volume | Priority |
|---------|---------------|-----------|----------|
| LMS | Application | High | Critical |
| CMS | Application | High | Critical |
| Workers (Celery) | Background Jobs | High | Critical |
| MFE | Frontend | Medium | Important |
| Discovery | API | Medium | Important |
| Ecommerce | API | Medium | Important |
| Credentials | API | Low | Important |
| Forum | API | Medium | Important |
| Notes | API | Low | Optional |

### Required Loki Label Schema

The system MUST apply the following labels to all logs ingested into Loki:

| Label | Type | Description | Examples |
|-------|------|-------------|----------|
| `service` | Required | Service name (lowercase, hyphenated) | `lms`, `cms`, `forum`, `discovery` |
| `env` | Required | Environment identifier | `prod`, `dev`, `staging` |
| `cluster` | Required | Kubernetes cluster identifier | `gke-mereka-lms-prod`, `kind-local` |
| `namespace` | Required | Kubernetes namespace | `mereka-lms` |
| `hostname` | Required | Pod hostname or node name | `lms-6f8c9d7b-xkz4p` |
| `severity` | Required | Log level | `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL` |

**Label Cardinality Limits**:
- Total unique label combinations MUST NOT exceed 10,000 per service
- `hostname` label SHOULD be dropped after 7 days for historical queries (use Loki aggregation)

### Log Format Requirements

The system MUST output structured JSON logs with the following mandatory fields:

```json
{
  "timestamp": "2026-02-13T18:30:00.123456Z",
  "level": "ERROR",
  "service": "lms",
  "message": "Database connection pool exhausted",
  "trace_id": "abc123def456",
  "user_id": "redacted",
  "request_id": "req-789",
  "module": "django.db.backends.mysql"
}
```

**Required Fields**:
- `timestamp` (ISO8601 with microseconds, UTC timezone)
- `level` (one of: DEBUG, INFO, WARNING, ERROR, CRITICAL)
- `service` (matches Loki `service` label)
- `message` (human-readable log message)

**Optional Fields**:
- `trace_id` (distributed tracing correlation ID)
- `request_id` (HTTP request correlation ID)
- `user_id` (anonymized user identifier, NOT email)
- `module` (source code module/file)
- `stack_trace` (only for ERROR/CRITICAL levels)

### PII Filtering Requirements

The system MUST filter the following PII from all logs before ingestion into Loki:

**Prohibited Data**:
- Email addresses (must be redacted or anonymized)
- Passwords (must NEVER appear in logs)
- Session tokens (must NEVER appear in logs)
- OAuth access tokens (must NEVER appear in logs)
- Credit card numbers
- Social security numbers
- API keys and secrets

**Anonymization Strategy**:
- User identifiers MUST use hashed/anonymized IDs, NOT email addresses
- Request bodies MUST be sanitized before logging (remove sensitive fields)
- Error messages MUST NOT include user-supplied credentials

**Implementation**:
- Django logging MUST use custom formatters that redact sensitive fields
- Promtail MUST use pipeline stages to drop/redact sensitive patterns
- Loki queries MUST NOT expose raw user data in dashboards

### Retention Requirements

The system MUST implement the following retention policies:

| Data Type | Retention Period | Storage Backend |
|-----------|-----------------|-----------------|
| Loki logs (all services) | 30 days | Loki object storage (GCS) |
| Tempo traces | 7 days | Tempo object storage (GCS) |
| Prometheus metrics | 30 days (local), 90 days (remote) | Prometheus TSDB, Thanos/GCS |

**Compliance**:
- Logs older than 30 days MUST be automatically deleted
- No manual deletion override (to prevent compliance gaps)
- Retention policy MUST be enforced via Loki compactor configuration

### Acceptance Criteria (Logging Pipeline)

- [ ] AC-LOG-001: Promtail DaemonSet is deployed and scraping logs from all pods in `mereka-lms` namespace
- [ ] AC-LOG-002: Loki query `{namespace="mereka-lms"}` returns logs from all canonical log sources (LMS, CMS, workers, MFE, discovery, ecommerce, credentials, forum, notes)
- [ ] AC-LOG-003: All logs have required labels: `service`, `env`, `cluster`, `namespace`, `hostname`, `severity`
- [ ] AC-LOG-004: LMS and CMS logs are structured JSON with `timestamp`, `level`, `service`, `message` fields
- [ ] AC-LOG-005: No email addresses are visible in Loki query results: `{namespace="mereka-lms"} |~ "@.*\\.com"` returns zero results
- [ ] AC-LOG-006: No passwords are visible in Loki query results: `{namespace="mereka-lms"} |~ "(?i)password.*=.*[^*]"` returns zero results
- [ ] AC-LOG-007: Logs older than 30 days are automatically deleted: query `{namespace="mereka-lms"}` with time range `now-31d to now-30d` returns no results
- [ ] AC-LOG-008: Tempo traces are retained for 7 days: traces older than 8 days are not retrievable

## Observability

### Logs

- Prometheus scrape logs: `kubectl logs -n mereka-lms -l app=prometheus`
- Loki ingestion logs: `kubectl logs -n mereka-lms -l app=loki`
- Tempo trace writes: `kubectl logs -n mereka-lms -l app=tempo`

### Metrics (Meta-Monitoring)

Monitor the observability stack itself:
- `prometheus_tsdb_head_series` gauge: number of active time series (alert if > 500K)
- `prometheus_engine_query_duration_seconds` histogram: query latency (alert if p95 > 10s)
- `loki_ingester_streams_created_total` counter: Loki ingestion rate (alert if drops to 0 for 5 min)
- `tempo_ingester_traces_created_total` counter: Tempo trace ingestion rate
- Grafana dashboard load time: measured via Blackbox Exporter synthetic probe
- `alertmanager_notifications_total{integration="slack"}` counter: alert delivery success rate (alert if `alertmanager_notifications_failed_total` > 0)

### Alerts

- MUST alert if Prometheus scrape failure rate >10%
- MUST alert if Loki ingestion stops for >5 minutes
- SHOULD alert if Grafana dashboard queries timeout
- SHOULD alert if Alertmanager notification fails

## Rollout & Rollback

### Initial Deployment

```bash
# 1. Add prometheus-community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. Install kube-prometheus-stack (Prometheus, Grafana, Alertmanager)
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n mereka-lms \
  -f infrastructure/monitoring/prometheus-values.yaml

# 3. Install Loki
helm install loki grafana/loki-stack \
  -n mereka-lms \
  -f infrastructure/monitoring/loki-values.yaml

# 4. Install Tempo (optional)
helm install tempo grafana/tempo \
  -n mereka-lms \
  -f infrastructure/monitoring/tempo-values.yaml

# 5. Configure Grafana datasources
kubectl apply -f infrastructure/monitoring/grafana-datasources.yaml

# 6. Import dashboards
kubectl apply -f infrastructure/monitoring/grafana-dashboards.yaml
```

### Application Instrumentation

```bash
# 1. Ensure django-prometheus installed (done in Dockerfile)
# RUN pip install django-prometheus==2.3.1

# 2. Add Prometheus middleware to settings (done in apply-patches.sh)
# INSTALLED_APPS.insert(0, 'django_prometheus')
# MIDDLEWARE.insert(0, 'django_prometheus.middleware.PrometheusBeforeMiddleware')
# MIDDLEWARE.append('django_prometheus.middleware.PrometheusAfterMiddleware')

# 3. Add openedx_prometheus app with /metrics endpoint
# INSTALLED_APPS.append('openedx_prometheus')

# 4. Rebuild and deploy
tutor images build openedx
tutor k8s restart lms cms

# 5. Verify metrics endpoint
curl https://academyv2.mereka.io/metrics
```

### Rollback Procedure

If observability stack breaks production:

```bash
# 1. Observability is non-critical, can be disabled without affecting LMS
# Only disable if causing resource exhaustion

# 2. Disable Prometheus scraping
kubectl scale deployment prometheus -n mereka-lms --replicas=0

# 3. Disable Loki ingestion
kubectl scale daemonset promtail -n mereka-lms --replicas=0

# 4. LMS/CMS continue running normally (metrics endpoint ignored)

# 5. To fully remove
helm uninstall monitoring -n mereka-lms
helm uninstall loki -n mereka-lms
helm uninstall tempo -n mereka-lms
```

## Open Questions

1. ~~Should we use Thanos for long-term metrics storage (>30 days)?~~ **RESOLVED**: No. 30-day Prometheus retention is sufficient for operational use. Export aggregated daily metrics to GCS Parquet for trend analysis. Thanos adds operational complexity not justified at current scale (<50 tenants).
2. ~~What's the optimal trace sampling rate (10%, 50%, 100%)?~~ **RESOLVED**: 10% for normal traffic, 100% for error responses. Defined in cross-cutting-requirements_spec.md Section 2 (Traces). Revisit sampling rate when trace storage exceeds 50GB/month.
3. ~~Should we enable Tempo's distributed tracing for cross-service calls (LMS -> Forum)?~~ **RESOLVED**: Yes. Tempo is deployed on VPS (port 3201 API, 4317 OTLP gRPC, 4318 OTLP HTTP). Enable trace propagation via `traceparent` header across LMS, Forum, Ecommerce, and XQueue.
4. ~~Do we need separate Prometheus for staging vs production?~~ **RESOLVED**: No. Single Prometheus instance with environment label (`env=prod`, `env=dev`). Staging is not a separate environment; dev (Kind cluster) uses the same VPS observability stack.
5. ~~Should we export metrics to Google Cloud Monitoring for unified view?~~ **RESOLVED**: No. Grafana is the single pane of glass. GCP Cloud Monitoring used only for GKE node-level alerts (already configured). No metric duplication needed.
6. ~~What's the alert escalation policy (Slack -> PagerDuty -> SMS)?~~ **RESOLVED**: Critical alerts route to PagerDuty + Slack `#ops-alerts`. Warning alerts route to Slack `#ops-warnings`. No SMS tier. Defined in cross-cutting-requirements_spec.md Section 2 (Alerts).
7. ~~Should we implement SLI/SLO dashboards (uptime, latency targets)?~~ **RESOLVED**: Yes. Covered by slo-sla-service-level-management_spec.md. SLO dashboard pack tracked in bead mereka-lms-8dbr.
8. ~~Do we need anomaly detection (e.g., sudden spike in error rate)?~~ **RESOLVED**: No dedicated anomaly detection for v1. Prometheus alerting rules with threshold-based alerts are sufficient. Evaluate Grafana ML anomaly detection post-v1 when baseline traffic patterns are established.
