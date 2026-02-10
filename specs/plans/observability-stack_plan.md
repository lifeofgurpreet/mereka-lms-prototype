---
spec: observability-stack_spec.md
tier: 2
status: draft
estimated_effort: "6-8 weeks (1 engineer)"
owner: engineering
last_updated: "2026-02-10"
prerequisites:
  - "Tier 0: repository-structure_spec.md (APPROVED)"
  - "Tier 0: secrets-management_spec.md (IN_REVIEW)"
  - "Tier 0: tutor-configuration_spec.md (DRAFT)"
  - "Tier 0: cross-cutting-requirements_spec.md (IN_REVIEW)"
  - "Tier 1: k8s-deployment_spec.md (DRAFT)"
---

# Implementation Plan: Observability Stack (Prometheus/Tempo/Loki)

**Source Spec**: `specs/observability-stack_spec.md`

## Summary

This plan implements a production-grade observability stack for Mereka Academy's Open edX deployment on GKE. Significant infrastructure already exists: Prometheus Operator is deployedvia kube-prometheus-stack, ServiceMonitors for LMS/CMS/MySQL/Redis are in place, PrometheusRules with 20+ alert rules areoperational, Promtail DaemonSet forwards logs to Loki on theVPS, and GCP Cloud Monitoring alerting is configured as codein `infrastructure/monitoring/`. The major remaining gaps are: (1) enabling application-level metrics via django-prometheus in the Open edX image, (2) deploying Tempo for distributedtracing, (3) provisioning Grafana datasources and dashboardsfor the K8s-native stack, (4) wiring Alertmanager to Slack,and (5) meta-monitoring of the observability stack itself.

## Current State Assessment

| Component | Status | Gap |
|-----------|--------|-----|
| Prometheus | Deployed (kube-prometheus-stack) | Applicationmetrics not scraped (django-prometheus not installed) |
| ServiceMonitors | Created for LMS, CMS, MySQL, Redis | LMS/CMS monitors return 400 (no /metrics endpoint yet) |
| PrometheusRules | 20+ alert rules operational | Missing 5xxrate alert, DB connection pool exhaustion alert |
| Promtail | DaemonSet deployed, forwarding to VPS Loki | Working -- needs validation of label quality |
| Loki | Running on VPS (Docker Compose) | Not deployed in GKE; current setup uses Cloudflare tunnel |
| Tempo | Not deployed | Full gap |
| Grafana | Not deployed in GKE (using GCP Cloud Monitoring)| Full gap for K8s-native Grafana |
| Alertmanager | Deployed (part of kube-prometheus-stack) | Slack/email routing not configured |
| GCP Cloud Monitoring | Alerting-as-code in infrastructure/monitoring/ | Parallel path -- will continue as fallback |
| openedx_prometheus app | Custom app scaffolded but not active | django-prometheus dependency missing from image |

## Task Breakdown

### Phase 1: Application Metrics Instrumentation

#### Build

- [ ] **[M] Task 1.1**: Install django-prometheus in Open edXDocker image | AC: #3 | Depends: None
  - **Description**: Add `django-prometheus==2.3.1` and `prometheus_client` to the Open edX image requirements. Update `infrastructure/tutor/apply-patches.sh` to inject django-prometheus middleware and INSTALLED_APPS entries. The `openedx_prometheus` custom app already exists at `infrastructure/tutor/custom-apps/openedx_prometheus/` with URL routing -- it just needs the dependency installed.
  - **Files**:
    - `infrastructure/tutor/apply-patches.sh` (modify: add django-prometheus middleware injection)
    - `infrastructure/tutor/custom-apps/openedx_prometheus/apps.py` (modify: register custom metrics in `ready()`)
  - **Done**: `curl localhost:8000/metrics` inside LMS pod returns Prometheus text format with `http_requests_total` counter

- [ ] **[M] Task 1.2**: Add custom Open edX metrics | AC: #3| Depends: Task 1.1
  - **Description**: Instrument LMS/CMS with custom application metrics defined in the spec: `http_request_duration_seconds`, `django_db_query_duration_seconds`, `django_cache_hit_ratio`, `celery_task_duration_seconds`, `lms_enrollment_total`,`lms_active_users`. Use django-prometheus's built-in metricswhere possible; add custom collectors for Open edX-specific metrics.
  - **Files**:
    - `infrastructure/tutor/custom-apps/openedx_prometheus/__init__.py` (modify: register custom collectors)
    - `infrastructure/tutor/custom-apps/openedx_prometheus/collectors.py` (create: custom metric collectors)
    - `infrastructure/tutor/custom-apps/openedx_prometheus/middleware.py` (create: latency tracking middleware)
  - **Done**: `/metrics` endpoint reports all 7 custom metrics listed in the spec's Application Metrics table

- [ ] **[L] Task 1.3**: Rebuild and deploy Open edX image with metrics | AC: #3 | Depends: Task 1.2
  - **Description**: Build the updated Open edX Docker imagewith django-prometheus, push to Artifact Registry, update image tags in `deploy/k8s/overlays/production/kustomization.yaml`, and roll out to GKE.
  - **Files**:
    - `deploy/k8s/overlays/production/kustomization.yaml` (modify: update image tag)
  - **Done**: LMS and CMS pods in GKE expose `/metrics` withHTTP 200, ServiceMonitors show targets as UP in Prometheus

### Phase 2: Alerting Completion

#### Build

- [ ] **[M] Task 2.1**: Add missing alert rules to PrometheusRule | AC: #6 | Depends: None
  - **Description**: The existing `prometheusrule-lms.yaml` covers pod-level and infra alerts but is missing the spec-required rules: (a) crash loop >3 restarts in 5 minutes (currently uses 15m window), (b) high 5xx error rate >5%, (c) DB connection pool exhaustion, (d) disk usage >80% (currently uses 85%). Update thresholds and add new rules.
  - **Files**:
    - `deploy/k8s/base/monitoring/prometheusrule-lms.yaml` (modify: add/update alert rules)
  - **Done**: `kubectl get prometheusrule lms-alerts -n mereka-lms -o yaml` shows all 5 critical alert conditions from thespec

- [ ] **[M] Task 2.2**: Configure Alertmanager Slack/email routing | AC: #6 | Depends: None
  - **Description**: Configure Alertmanager to route criticalalerts to the team Slack channel and fallback to email. Store webhook URL in Infisical, sync to K8s secret via ExternalSecrets.
  - **Files**:
    - `infrastructure/monitoring/alertmanager-config.yaml` (create: Alertmanager routing config)
    - `deploy/k8s/base/secrets/external-secrets.yaml` (modify: add ALERTMANAGER_SLACK_WEBHOOK_URL)
    - `deploy/k8s/base/monitoring/alertmanager-secret.yaml` (create: K8s Secret reference for webhook)
  - **Done**: Send test alert via `amtool alert add test severity=critical` and verify it appears in Slack

- [ ] **[S] Task 2.3**: Add meta-monitoring alerts for observability stack | AC: #6 | Depends: None
  - **Description**: Add PrometheusRules for observability stack self-monitoring: Prometheus scrape failure >10%, Loki ingestion stopped >5min, Grafana query timeouts, Alertmanager notification failures.
  - **Files**:
    - `deploy/k8s/base/monitoring/prometheusrule-meta.yaml` (create: meta-monitoring alerts)
    - `deploy/k8s/base/monitoring/kustomization.yaml` (modify: add new resource)
  - **Done**: `kubectl get prometheusrule -n mereka-lms` lists `meta-monitoring-alerts` with 4+ rules

### Phase 3: Distributed Tracing (Tempo)

#### Build

- [ ] **[M] Task 3.1**: Deploy Tempo via Helm | AC: #5 | Depends: None
  - **Description**: Install Grafana Tempo in the GKE clusterusing the Grafana Helm chart. Configure OTLP gRPC (4317) andHTTP (4318) receivers. Use persistent volume for trace storage. Create Helm values file.
  - **Files**:
    - `infrastructure/monitoring/tempo-values.yaml` (create:Tempo Helm values)
    - `scripts/infra/deploy-tempo.sh` (create: deployment script)
  - **Done**: `kubectl get pods -n mereka-lms -l app.kubernetes.io/name=tempo` shows running pod; `kubectl port-forward svc/tempo 3200` returns health OK

- [ ] **[L] Task 3.2**: Instrument LMS/CMS with OpenTelemetrySDK | AC: #5, #7 | Depends: Task 1.1, Task 3.1
  - **Description**: Add `opentelemetry-sdk`, `opentelemetry-exporter-otlp`, and `opentelemetry-instrumentation-django` tothe Open edX image. Configure trace export to Tempo via OTLP. Enable trace ID injection into logs for Loki correlation.
  - **Files**:
    - `infrastructure/tutor/custom-apps/openedx_prometheus/tracing.py` (create: OTel SDK setup)
    - `infrastructure/tutor/apply-patches.sh` (modify: add OTel middleware and env vars)
  - **Done**: Traces visible in Tempo query API; log entriesinclude `trace_id` field

- [ ] **[S] Task 3.3**: Configure trace sampling | AC: #5 | Depends: Task 3.2
  - **Description**: Implement head-based sampling at 10% fornormal requests, 100% for errors (status >= 500). Configurevia environment variable so it can be adjusted without rebuild.
  - **Files**:
    - `infrastructure/tutor/custom-apps/openedx_prometheus/tracing.py` (modify: add sampler config)
  - **Done**: Trace count in Tempo is roughly 10% of total requests; error traces are always captured

### Phase 4: Grafana Deployment and Dashboards

#### Build

- [ ] **[M] Task 4.1**: Deploy Grafana on GKE (or formalize VPS Grafana) | AC: #2 | Depends: None
  - **Description**: Either deploy Grafana in GKE via kube-prometheus-stack's built-in Grafana or formalize the VPS Grafana instance at grafana.mereka.dev with proper datasource wiring. Decision depends on whether GKE-native or VPS-hosted is preferred. Create Helm values overlay or docker-compose update.
  - **Files**:
    - `infrastructure/monitoring/grafana-values.yaml` (create: Grafana Helm values if GKE)
    - `infrastructure/monitoring/grafana-datasources.yaml` (create: datasource provisioning)
  - **Done**: Grafana accessible at `https://grafana.mereka.io` (or `.dev`) with authentication required

- [ ] **[M] Task 4.2**: Configure Grafana datasources (Prometheus, Loki, Tempo) | AC: #2, #7 | Depends: Task 4.1
  - **Description**: Provision Prometheus, Loki, and Tempo asdatasources in Grafana via ConfigMap or provisioning API. Enable derived fields on Loki for trace-to-logs correlation (trace ID link to Tempo).
  - **Files**:
    - `infrastructure/monitoring/grafana-datasources.yaml` (modify: add all 3 datasources with correlation)
  - **Done**: Grafana Settings > Datasources shows all 3 datasources with "Data source is working" status

- [ ] **[L] Task 4.3**: Provision dashboards (Kubernetes, LMS/CMS, Database, Redis) | AC: #2 | Depends: Task 4.2
  - **Description**: Create or import Grafana dashboards for:(a) K8s cluster overview, (b) pod CPU/memory, (c) Open edX LMS/CMS health, (d) MySQL performance, (e) Redis cache metrics. Use ConfigMap-based provisioning or Grafana API. Align withexisting contract in `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`.
  - **Files**:
    - `infrastructure/monitoring/grafana-dashboards/k8s-overview.json` (create)
    - `infrastructure/monitoring/grafana-dashboards/openedx-health.json` (create)
    - `infrastructure/monitoring/grafana-dashboards/mysql-performance.json` (create)
    - `infrastructure/monitoring/grafana-dashboards/redis-cache.json` (create)
    - `infrastructure/monitoring/grafana-dashboards/pod-resources.json` (create)
    - `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json` (modify: add new required panels)
  - **Done**: All 5 dashboards load in under 3 seconds for a24h query window; `scripts/qa/audit-grafana-dashboard.sh --strict-required` passes

- [ ] **[S] Task 4.4**: Restrict Grafana access to authorizedstaff | AC: #2 | Depends: Task 4.1
  - **Description**: Configure Grafana authentication (OAuthvia Authentik or basic auth). Ensure anonymous access is disabled. All observability endpoints require auth per NFR.
  - **Files**:
    - `infrastructure/monitoring/grafana-values.yaml` (modify: auth configuration)
  - **Done**: Accessing `https://grafana.mereka.io` without credentials redirects to login page

### Phase 5: Log Aggregation Validation

#### Build

- [ ] **[S] Task 5.1**: Validate Promtail log labeling and retention | AC: #4 | Depends: None
  - **Description**: The Promtail DaemonSet is already deployed and forwarding to Loki. Validate that logs are labeled with namespace, pod, container metadata. Verify 7-day retentionpolicy in Loki config. Fix any labeling gaps.
  - **Files**:
    - `deploy/k8s/base/logging/promtail-configmap.yaml` (verify/modify if needed)
    - `~/infrastructure/observability/loki/config.yaml` (verify: retention_period)
  - **Done**: `logcli query '{namespace="mereka-lms"}' --limit 10` returns labeled log entries

- [ ] **[S] Task 5.2**: Validate LogQL queries work in Grafana | AC: #4 | Depends: Task 4.2
  - **Description**: Verify that LogQL queries can be executed from the Grafana Loki datasource. Test namespace, pod, andlevel-based filtering. Verify query response time is under 5seconds for 1-hour window.
  - **Files**: None (validation only)
  - **Done**: LogQL query `{namespace="mereka-lms",app="lms"}|= "error"` returns results in under 5 seconds

### Phase 6: Metrics Retention and NFRs

#### Build

- [ ] **[S] Task 6.1**: Configure Prometheus 30-day retention| AC: #8 | Depends: None
  - **Description**: Verify and configure Prometheus retention to 30 days. Ensure persistent volume is sized appropriately(estimate: 50k time series * 30 days * 2 bytes/sample * 1 sample/30s = ~8.6 GB). Update Helm values if needed.
  - **Files**:
    - `infrastructure/monitoring/prometheus-values.yaml` (create/modify: retention and storage config)
  - **Done**: `kubectl exec prometheus-pod -- prometheus --version` confirms retention flag; querying 30-day-old metrics returns data

- [ ] **[S] Task 6.2**: Validate scrape interval <= 30 seconds | AC: #1 | Depends: None
  - **Description**: Verify all ServiceMonitors use `interval: 30s` or less. The existing configs already use 30s. Document in monitoring README.
  - **Files**:
    - `deploy/k8s/base/monitoring/README.md` (modify: document scrape intervals)
  - **Done**: All ServiceMonitor resources show `interval: 30s` in their specs

- [ ] **[S] Task 6.3**: Set resource limits on observabilitystack | AC: N/A (NFR) | Depends: None
  - **Description**: Ensure the observability stack does notexceed 20% cluster CPU or 25% cluster memory per the NFR. Setresource requests/limits on Prometheus, Loki, Tempo, and Grafana pods.
  - **Files**:
    - `infrastructure/monitoring/prometheus-values.yaml` (modify: resource limits)
    - `infrastructure/monitoring/tempo-values.yaml` (modify:resource limits)
    - `infrastructure/monitoring/grafana-values.yaml` (modify: resource limits)
  - **Done**: `kubectl top pods -n monitoring` + `kubectl toppods -n mereka-lms -l component=log-forwarder` total is under 20% CPU and 25% memory of cluster capacity

### Test

- [ ] **[M] Task T.1**: Create observability verification script | AC: #1-#8 | Depends: Phase 1-5
  - **Description**: Extend the existing `deploy/k8s/base/monitoring/verify.sh` to cover all 8 acceptance criteria. Add checks for: ServiceMonitor count, /metrics HTTP 200, Promtail pod status, Tempo health, Grafana datasource status, alert rule count, log query success, metrics retention query.
  - **Files**:
    - `scripts/qa/verify-observability-stack.sh` (create: comprehensive verification)
    - `deploy/k8s/base/monitoring/verify.sh` (modify: updateexpectations from 400 to 200)
  - **Done**: Script exits 0 with all checks passing

- [ ] **[S] Task T.2**: Create Grafana dashboard audit extension | AC: #2 | Depends: Task 4.3
  - **Description**: Update `scripts/qa/audit-grafana-dashboard.sh` to verify the new dashboards exist and contain the expected panels per the updated dashboard contract.
  - **Files**:
    - `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json` (modify: add new panel requirements)
    - `scripts/qa/audit-grafana-dashboard.sh` (modify if needed)
  - **Done**: `./scripts/qa/audit-grafana-dashboard.sh --strict-required` returns PASS

- [ ] **[S] Task T.3**: Create alert routing verification | AC: #6 | Depends: Task 2.2
  - **Description**: Create a test script that sends a test alert through Alertmanager and verifies it reaches the configured webhook (Slack).
  - **Files**:
    - `scripts/qa/verify-alert-routing.sh` (modify: add Alertmanager webhook test)
  - **Done**: Test alert sent, Slack notification confirmed (manual or webhook log check)

### Observability (Meta-Monitoring)

- [ ] **[S] Task O.1**: Add observability stack to GCP monitoring-as-code | AC: N/A (meta) | Depends: Phase 1-4
  - **Description**: Add alert policies and uptime checks forthe observability stack endpoints (Prometheus, Grafana, Loki) to `infrastructure/monitoring/`. This ensures the observability stack is monitored even if it partially fails.
  - **Files**:
    - `infrastructure/monitoring/uptime/prod-grafana-https.json` (create)
    - `infrastructure/monitoring/uptime/prod-prometheus-https.json` (create)
    - `infrastructure/monitoring/alerts/prometheus-scrape-failures.json` (create)
    - `infrastructure/monitoring/alerts/loki-ingestion-stopped.json` (create)
  - **Done**: `./scripts/infra/apply-monitoring-configs.sh plan` shows new resources; uptime checks are green

### Docs

- [ ] **[M] Task D.1**: Update observability documentation |AC: N/A | Depends: Phase 1-5
  - **Description**: Update existing operational docs to reflect the full stack deployment. Update MONITORING.md, create Grafana quickstart, update TROUBLESHOOTING.md with observability-specific sections.
  - **Files**:
    - `docs/operations/MONITORING.md` (modify: update with current stack)
    - `docs/operations/OBSERVABILITY_QUICKSTART.md` (modify:update access instructions)
    - `docs/operations/TROUBLESHOOTING.md` (modify: add observability troubleshooting section)
    - `deploy/k8s/base/monitoring/IMPLEMENTATION_STATUS.md` (modify: update status)
    - `deploy/k8s/base/monitoring/README.md` (modify: add dashboard and retention info)
  - **Done**: All docs reference current stack state; IMPLEMENTATION_STATUS.md shows "COMPLETE" for all components

### Rollout

- [ ] **[S] Task R.1**: Create rollback script | AC: N/A | Depends: None
  - **Description**: Create a rollback script that can disable the observability stack without affecting LMS/CMS operations. Follow the rollback procedure defined in the spec.
  - **Files**:
    - `scripts/infra/rollback-observability.sh` (create: scale-to-zero and uninstall commands)
  - **Done**: Running the script scales Prometheus/Loki/Tempoto 0 without affecting LMS uptime

## Milestones

| Milestone | Tasks | Target | Deliverable |
|-----------|-------|--------|-------------|
| **M1: Application Metrics** | 1.1, 1.2, 1.3 | Week 2 | `/metrics` returns prometheus data on LMS/CMS pods |
| **M2: Alerting Complete** | 2.1, 2.2, 2.3 | Week 3 | All critical alerts fire and reach Slack |
| **M3: Distributed Tracing** | 3.1, 3.2, 3.3 | Week 5 | Traces visible in Tempo, correlated with logs |
| **M4: Dashboards Live** | 4.1, 4.2, 4.3, 4.4 | Week 6 | 5 dashboards loading in Grafana |
| **M5: Full Validation** | 5.1, 5.2, 6.1, 6.2, 6.3, T.1-T.3| Week 7 | All 8 ACs verified, verification scripts pass |
| **M6: Docs and Rollout** | D.1, O.1, R.1 | Week 8 | Documentation updated, rollback tested |

## Dependency Graph

```
Task 1.1 (django-prometheus)
  ├── Task 1.2 (custom metrics) ──> Task 1.3 (image rebuild)
  └── Task 3.2 (OTel instrumentation)

Task 2.1 (alert rules)        ── independent
Task 2.2 (Slack routing)      ── independent ──> Task T.3
Task 2.3 (meta-monitoring)    ── independent

Task 3.1 (Tempo deploy)
  └── Task 3.2 (OTel SDK) ──> Task 3.3 (sampling)

Task 4.1 (Grafana deploy)
  ├── Task 4.2 (datasources) ──> Task 4.3 (dashboards) ──> Task T.2
  ├── Task 4.4 (auth)
  └── Task 5.2 (LogQL validation)

Task 5.1 (Promtail validation) ── independent
Task 6.1-6.3 (NFR validation) ── independent

Task T.1 (verification script) ── depends on Phases 1-5
Task D.1 (docs)                ── depends on Phases 1-5
Task O.1 (meta-monitoring GCP) ── depends on Phases 1-4
Task R.1 (rollback script)     ── independent
```

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Open edX image rebuild takes >2 hours and breaks existing functionality | Medium | High | Build in staging first; test with `tutor local` before GKE; use `PIP_COMMAND=pip` flag foruv compatibility |
| django-prometheus middleware causes request latency increase | Low | Medium | Benchmark before/after; middleware overhead is typically <1ms; disable path if p95 degrades >10% |
| Tempo trace volume exceeds storage (no sampling initially)| Medium | Medium | Start with 10% sampling; use GCS backendfor Tempo if local PV fills up |
| Loki log volume spikes due to debug logging | Medium | Low| Promtail already has pipeline stages for level filtering; add drop stage for DEBUG if needed |
| High-cardinality metrics from django-prometheus blow up Prometheus TSDB | Medium | High | Configure `metric_relabel_configs` to drop high-cardinality labels (user_id, session_id); set series limits |
| Cluster resource exhaustion from observability stack | Low| Critical | Set strict resource limits per NFR (20% CPU, 25%memory); monitor with meta-monitoring alerts |
| Alertmanager Slack webhook rate limited by Slack API | Low| Medium | Use Slack incoming webhook (not bot); batch alertswith `group_wait: 30s`; add email fallback |
| GKE node pool too small for additional observability pods |Medium | Medium | Check current node utilization before deploying; scale pool if needed; Tempo can start with minimal resources |
