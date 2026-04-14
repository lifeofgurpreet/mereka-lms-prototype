# Observability Operations Guide
_Audience: Operations & SREs • Owner: Infra Team • Last updated: 2026-04-09_

**Purpose**: Monitor, alert, and troubleshoot the Mereka LMS observability stack (Prometheus, Loki, Tempo, Grafana).

**TL;DR**: Prometheus scrapes metrics, Loki aggregates logs, Tempo collects traces, Grafana visualizes. All deployed via kube-prometheus-stack. Alerts route to Slack. 30-day retention. ServiceMonitors auto-discover pods.

**Scope note (2026-04-09):** This guide remains useful for stack shape and common checks, but some
examples still reflect legacy public monitoring hostnames and older access assumptions. For current
environment and runtime authority, confirm against `docs/reference/operations/MONITORING.md`,
`docs/reference/operations/PRODUCTION_INFRASTRUCTURE_PLAN.md`, and
`docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`.

---

## Stack Overview

### Components

| Component | Purpose | Port | Storage |
|-----------|---------|------|---------|
| **Prometheus** | Metrics collection + alerting | 9090 | 30 days (20GB PVC) |
| **Loki** | Log aggregation | 3100 | 7 days (10GB PVC) |
| **Promtail** | Log shipper (DaemonSet) | 9080 | N/A (stateless) |
| **Tempo** | Distributed tracing | 3200 | 7 days (5GB PVC) |
| **Grafana** | Visualization + dashboards | 3000 | N/A (stateless) |
| **Alertmanager** | Alert routing | 9093 | N/A (stateless) |

**Namespace**: `monitoring` (separate from `mereka-lms`)

### Access URLs

**Local (Tutor/local)**:
- Prometheus: http://prometheus.localhost
- Grafana: http://grafana.localhost (admin/admin)
- Alertmanager: http://alertmanager.localhost

**Production / nonprod public surfaces**:
- Prometheus: https://prometheus.mereka.dev
- Grafana: https://grafana.mereka.dev
- Alertmanager: https://alertmanager.mereka.dev
- Loki: https://loki.mereka.dev (API only)
- Tempo: https://tempo.mereka.dev (API only)

---

## Metrics Collection

### ServiceMonitors

**What**: Kubernetes resources that tell Prometheus what to scrape.

**Current ServiceMonitors** (in `mereka-lms` namespace):
- `servicemonitor-lms` → LMS pods (`/metrics`, port 8000)
- `servicemonitor-cms` → CMS pods (`/metrics`, port 8000)
- `servicemonitor-mysql` → MySQL exporter sidecar (port 9104)
- `servicemonitor-redis` → Redis exporter sidecar (port 9121)

**List ServiceMonitors**:
```bash
kubectl get servicemonitors -n mereka-lms
```

**Verify scrape targets**:
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Open http://localhost:9090/targets
# Look for mereka-lms/servicemonitor-* with status "UP"
```

### Application Metrics

**django-prometheus** installed in LMS/CMS exposes:

| Metric | Type | Description |
|--------|------|-------------|
| `django_http_requests_total_by_view_transport_method_total` | Counter | Requests by endpoint/method |
| `django_http_requests_latency_seconds` | Histogram | Request duration |
| `django_db_query_duration_seconds` | Histogram | Database query time |
| `django_cache_operations_total` | Counter | Cache hits/misses |

**Query examples** (Prometheus UI):
```promql
# 95th percentile latency for /courses endpoint
histogram_quantile(0.95, rate(django_http_requests_latency_seconds_bucket{view=~".*courses.*"}[5m]))

# Requests per second by status code
sum(rate(django_http_requests_total_by_view_transport_method_total[5m])) by (status)

# Cache hit rate
sum(rate(django_cache_operations_total{result="hit"}[5m])) /
sum(rate(django_cache_operations_total[5m]))
```

### Middleware and custom-app boundary

The middleware/custom-app lane currently relies primarily on:

- middleware verification scripts
- django-prometheus baseline exposure
- route-/host-specific proof for `/metrics`

Do not claim the custom middleware metrics lane is complete unless the specific
middleware counters have actually been implemented. Until then, treat
middleware observability as a bounded companion lane, not a fully expanded
custom-metric surface.

---

## Logging

### Loki

**Architecture**: Promtail DaemonSet → Loki → Grafana

**Log sources**:
- All pods in `mereka-lms` namespace (scraped by Promtail)
- K8s system logs (kube-apiserver, kubelet)

**Query logs in Grafana**:
```logql
# All LMS logs
{namespace="mereka-lms", app_kubernetes_io_name="lms"}

# Errors only
{namespace="mereka-lms"} |= "ERROR"

# Specific error pattern
{namespace="mereka-lms"} |~ "500|Internal Server Error"

# Count errors per minute
sum(count_over_time({namespace="mereka-lms"} |= "ERROR" [1m]))
```

**CLI query**:
```bash
# Install LogCLI
go install github.com/grafana/loki/cmd/logcli@latest

# Query Loki
export LOKI_ADDR=https://loki.mereka.dev
logcli query '{namespace="mereka-lms"}' --limit=100 --since=1h
```

**Log retention**: 7 days (configurable in Loki config)

---

## Alerting

### PrometheusRules

**Location**: `deploy/k8s/base/monitoring/prometheusrule-services.yaml`

**Current alerts**:

| Alert | Severity | Condition | Action |
|-------|----------|-----------|--------|
| `OpenEdxPodCrashLooping` | Critical | Pod in CrashLoopBackOff >5min | Slack + PagerDuty |
| `OpenEdxHighMemoryUsage` | Warning | Memory >90% for 5min | Slack |
| `OpenEdxHighCPU` | Warning | CPU >80% for 10min | Slack |
| `OpenEdxServiceDown` | Critical | Service endpoints = 0 | Slack + PagerDuty |
| `OpenEdxSyntheticJobFailure` | Critical | CronJob failed | Slack + PagerDuty |

**View active alerts**:
```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/alerts
```

**View Alertmanager**:
```bash
kubectl port-forward -n monitoring svc/alertmanager-operated 9093:9093
# Open http://localhost:9093
```

### Alert Routing

**Alertmanager config** (simplified):
```yaml
route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'slack-notifications'
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: '<webhook-url>'
        channel: '#alerts'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: '<integration-key>'
```

**Silence alert** (maintenance):
```bash
# Silence via UI
# Open http://localhost:9093/#/silences → New Silence

# Or via CLI
amtool silence add alertname=OpenEdxHighMemoryUsage --duration=2h \
  --comment="Planned maintenance"
```

---

## Dashboards

### Grafana Dashboards

**Pre-configured dashboards**:
- **Open edX Overview** - Key platform metrics (requests/sec, latency, errors)
- **Kubernetes Pods** - Pod CPU/memory/network
- **MySQL Performance** - Queries, connections, slow queries
- **Redis Performance** - Hit rate, memory, connections
- **Nginx Ingress** - Request rate, latency, status codes

**Access**: use the current Grafana URL from `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
→ Dashboards

**Create custom dashboard**:
1. Login to Grafana
2. Click "+" → Dashboard
3. Add panel → Select Prometheus datasource
4. Query: e.g., `rate(django_http_requests_total[5m])`
5. Save dashboard

**Export/import**:
```bash
# Export dashboard JSON
curl -H "Authorization: Bearer <api-key>" \
  https://grafana.mereka.dev/api/dashboards/uid/<dashboard-uid> > dashboard.json

# Import
curl -X POST -H "Authorization: Bearer <api-key>" \
  -H "Content-Type: application/json" \
  -d @dashboard.json \
  https://grafana.mereka.dev/api/dashboards/db
```

---

## Common Operations

### Check Observability Stack Health

```bash
# All components running?
kubectl get pods -n monitoring

# Prometheus healthy?
curl -s https://prometheus.mereka.dev/-/healthy
# Should return: Prometheus is Healthy.

# Loki healthy?
curl -s https://loki.mereka.dev/ready
# Should return: ready

# Scrape targets healthy?
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets → All should be "UP"
```

### Increase Prometheus Retention

**Current**: 30 days

**Increase to 90 days**:
```bash
# Edit Prometheus StatefulSet
kubectl edit statefulset prometheus-kube-prometheus-prometheus -n monitoring

# Update: --storage.tsdb.retention.time=90d
# Restart: kubectl rollout restart statefulset/prometheus-kube-prometheus-prometheus -n monitoring
```

**Note**: Requires larger PVC (3x storage).

### Add New Alert

1. **Create PrometheusRule**:
   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: PrometheusRule
   metadata:
     name: my-custom-alerts
     namespace: monitoring
   spec:
     groups:
       - name: custom
         interval: 30s
         rules:
           - alert: MyCustomAlert
             expr: my_metric > 100
             for: 5m
             labels:
               severity: warning
             annotations:
               summary: "Custom alert fired"
   ```

2. **Apply**:
   ```bash
   kubectl apply -f my-custom-alerts.yaml
   ```

3. **Verify**:
   ```bash
   # Check Prometheus Rules
   kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
   # Open http://localhost:9090/rules → Look for "custom" group
   ```

---

## Grafana OIDC Secret Recovery

If Grafana pod is stuck in `CreateContainerConfigError` with message like `secret "grafana-oidc-client-secret" not found`, run:

```bash
./scripts/qa/verify-grafana-runtime-readiness.sh
```

To restore the missing secret through the current Secret Manager bridge:

```bash
PROJECT_ID=bbi-k8 \
K8S_CONTEXT=rke2-prod \
GCP_SECRET_NAME=mereka-lms-oidc-client-secret \
./scripts/infra/sync-grafana-oidc-secret.sh
```

Then verify telemetry path:

```bash
./scripts/infra/validate-telemetry-connectivity.sh --json --strict
```

## Troubleshooting

### Velero `backup-verification` Stale / `PartiallyFailed` Backups

**Symptom**: `audit-observability` fails on stale `backup-verification` and recent Velero backups are `PartiallyFailed`.

**Debug**:
```bash
./scripts/qa/audit-observability.sh --mode runtime --strict-runtime

kubectl --context rke2-prod -n velero \
  get backup.velero.io --sort-by=.metadata.creationTimestamp | tail -n 12

kubectl --context rke2-prod -n velero \
  logs deploy/velero-local --since=3h \
  | rg 'snapshots quota on Google Cloud Platform has been reached'
```

**Quota check**:
```bash
gcloud compute project-info describe --project bbi-k8 --format=json \
  | jq '.quotas[] | select(.metric=="SNAPSHOTS") | {metric, limit, usage}'
```

For controlled cleanup of over-retention snapshots (dry-run first):

```bash
./scripts/infra/prune-gcp-snapshots.sh
CONFIRM_PRUNE_GCP_SNAPSHOTS=PRUNE_GCP_SNAPSHOTS ALLOW_PROD_APPLY=1 \
  ./scripts/infra/prune-gcp-snapshots.sh --apply --max-delete 300
```

If `usage >= limit`, backup snapshots will fail until quota headroom is restored.

### Velero `signBlob` DownloadRequest Errors

**Symptom**: Velero backups complete, but `DownloadRequest` reconciliation logs show:
`Permission 'iam.serviceAccounts.signBlob' denied`.

**Verify**:
```bash
kubectl --context rke2-prod -n velero \
  logs deploy/velero-local --since=15m \
  | rg 'iam.serviceAccounts.signBlob|IAM_PERMISSION_DENIED'

# Runtime gate also checks this automatically:
./scripts/qa/audit-observability.sh --mode runtime --strict-runtime
```

**Fix IAM on Velero GSA** (`velero@bbi-k8.iam.gserviceaccount.com`):
```bash
gcloud iam service-accounts add-iam-policy-binding \
  velero@bbi-k8.iam.gserviceaccount.com \
  --project bbi-k8 \
  --member='serviceAccount:bbi-k8.svc.id.goog[velero/velero]' \
  --role='roles/iam.serviceAccountTokenCreator'
```

Optional self-binding (also safe):
```bash
gcloud iam service-accounts add-iam-policy-binding \
  velero@bbi-k8.iam.gserviceaccount.com \
  --project bbi-k8 \
  --member='serviceAccount:velero@bbi-k8.iam.gserviceaccount.com' \
  --role='roles/iam.serviceAccountTokenCreator'
```

### Prometheus Not Scraping Pods

**Symptom**: No metrics for LMS/CMS in Prometheus.

**Debug**:
```bash
# 1. ServiceMonitor exists?
kubectl get servicemonitor -n mereka-lms

# 2. Service has correct labels?
kubectl get svc lms -n mereka-lms -o yaml | grep -A5 "labels:"

# 3. ServiceMonitor selector matches Service labels?
kubectl get servicemonitor servicemonitor-lms -n mereka-lms -o yaml | grep -A5 "selector:"

# 4. Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=100 | grep lms
```

### Loki Not Receiving Logs

**Symptom**: Logs not appearing in Grafana.

**Debug**:
```bash
# 1. Promtail running?
kubectl get daemonset promtail -n monitoring

# 2. Promtail can reach Loki?
kubectl logs -n monitoring daemonset/promtail --tail=50 | grep -i error

# 3. Test Loki directly
curl -G https://loki.mereka.dev/loki/api/v1/query \
  --data-urlencode 'query={namespace="mereka-lms"}' \
  --data-urlencode 'limit=1'
```

### High Prometheus Memory Usage

**Symptom**: Prometheus pod OOMKilled.

**Causes**: Too many metrics, high cardinality.

**Fix**:
```bash
# Increase memory limit
kubectl edit statefulset prometheus-kube-prometheus-prometheus -n monitoring
# Update: resources.limits.memory = 4Gi (from 2Gi)

# Reduce metric retention
# Update: --storage.tsdb.retention.time=15d (from 30d)
```

---

## Verification

### Observability Stack Health Check

```bash
./scripts/qa/verify-observability-stack.sh
```

Checks:
- ✅ All monitoring pods running
- ✅ Prometheus scraping all ServiceMonitors
- ✅ Loki receiving logs from Promtail
- ✅ Grafana datasources configured
- ✅ No critical alerts firing

---

## Related Resources

**Spec**: `specs/observability-stack_spec.md` (8 ACs, 100% complete)

**Operations Docs**:
- `docs/ops/runbooks/OBSERVABILITY_QUICKSTART.md` - Quick setup guide
- `docs/ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md` - On-call runbook
- `docs/reference/operations/MONITORING.md` - Monitoring strategy
- `docs/ops/runbooks/ALERT_TUNING_SOP.md` - Alert tuning procedures

**Scripts**:
- `scripts/qa/verify-observability-stack.sh` - Health check
- `scripts/infra/apply-monitoring-configs.sh` - Apply monitoring configs
- `scripts/qa/audit-observability.sh` - Audit observability coverage

**Configuration**:
- `infrastructure/monitoring/` - Prometheus rules and configs
- `infrastructure/monitoring/grafana/` - Grafana dashboards
- `deploy/k8s/base/monitoring/` - ServiceMonitors, PrometheusRules

**External**:
- Prometheus docs: https://prometheus.io/docs/
- Loki docs: https://grafana.com/docs/loki/
- Grafana docs: https://grafana.com/docs/grafana/
