---
title: "Observability Stack (Prometheus/Tempo/Loki)"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "docs/operations/OBSERVABILITY_QUICKSTART.md"
    - "docs/operations/OBSERVABILITY_ENHANCEMENT_PLAN.md"
    - "docs/operations/OBSERVABILITY_OWNERSHIP.md"
    - "docs/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md"
    - "docs/operations/MONITORING.md"
    - "docs/operations/SLO_DASHBOARDS_SETUP.md"
    - "docs/operations/ALERT_SEVERITY_MATRIX.md"
    - "docs/operations/ALERT_TUNING_SOP.md"
    - "docs/operations/LOGGING_AND_SENTRY.md"
    - "docs/operations/GKE_LOKI_FORWARDING.md"
    - "docs/operations/TROUBLESHOOTING.md"
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

## Observability

### Logs

- Prometheus scrape logs: `kubectl logs -n mereka-lms -l app=prometheus`
- Loki ingestion logs: `kubectl logs -n mereka-lms -l app=loki`
- Tempo trace writes: `kubectl logs -n mereka-lms -l app=tempo`

### Metrics (Meta-Monitoring)

Monitor the observability stack itself:
- Prometheus query latency
- Loki ingestion rate
- Tempo trace ingestion rate
- Grafana dashboard load time
- Alert delivery success rate

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

1. Should we use Thanos for long-term metrics storage (>30 days)?
2. What's the optimal trace sampling rate (10%, 50%, 100%)?
3. Should we enable Tempo's distributed tracing for cross-service calls (LMS -> Forum)?
4. Do we need separate Prometheus for staging vs production?
5. Should we export metrics to Google Cloud Monitoring for unified view?
6. What's the alert escalation policy (Slack -> PagerDuty -> SMS)?
7. Should we implement SLI/SLO dashboards (uptime, latency targets)?
8. Do we need anomaly detection (e.g., sudden spike in error rate)?
