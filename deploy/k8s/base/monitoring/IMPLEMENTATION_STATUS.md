# Open edX Monitoring Implementation Status

**Date**: 2026-02-08
**Bead**: mereka-lms-76i

## Summary

ServiceMonitors and PrometheusRules are in place for Open edX LMS/CMS and include
MySQL/Redis exporter telemetry wiring. Open edX app-level `/metrics` integration is
present in repo and must be validated as `HTTP 200` at runtime for each rollout.

## What Was Implemented

### 1. ServiceMonitors Created

- **`servicemonitor-lms.yaml`**: Targets LMS service on port 8000
- **`servicemonitor-cms.yaml`**: Targets CMS service on port 8000
- **`servicemonitor-mysql.yaml`**: Targets MySQL exporter sidecar on port 9104
- **`servicemonitor-redis.yaml`**: Targets Redis exporter sidecar on port 9121

Both ServiceMonitors are configured to:
- Scrape `/metrics` endpoint every 30s
- Add pod, node, and namespace labels
- Target the `mereka-lms` namespace

### 2. PrometheusRule Created

**`prometheusrule-lms.yaml`** includes alert rules for:

#### LMS Alerts
- `LMSPodDown`: Pod is down for >5 minutes
- `LMSPodRestarting`: Frequent pod restarts (>0 in 15 minutes)
- `LMSPodMemoryHigh`: Memory usage >85% for >10 minutes
- `LMSPodMemoryCritical`: Memory usage >95% for >5 minutes (OOM risk)
- `LMSPodCPUHigh`: CPU usage >85% for >10 minutes
- `LMSPodDiskSpaceHigh`: PV disk usage >85% for >10 minutes

#### CMS Alerts
- `CMSPodDown`: Pod is down for >5 minutes
- `CMSPodMemoryHigh`: Memory usage >85% for >10 minutes

#### Infrastructure Alerts
- `MySQLPodDown`: MySQL database unavailable
- `RedisPodDown`: Redis cache unavailable
- `MongoDBPodDown`: MongoDB unavailable (coursestore/forum)
- `ElasticsearchPodDown`: Elasticsearch unavailable (search)

### 3. Service Updates

Updated `services.yml` to add named ports:
- LMS service: port `8000` named `http`
- CMS service: port `8000` named `http`

## Current Limitations

### Runtime parity can still drift if image/config rollout is stale

When runtime image or settings drift occurs, `/metrics` can regress and break SLI
recording even though manifests remain present.

Current contract:
- LMS `/metrics` MUST return `HTTP 200`
- CMS `/metrics` MUST return `HTTP 200`
- ServiceMonitors MUST remain `UP` in Prometheus targets for `lms-metrics` and `cms-metrics`

### What Metrics Are Available Today

Even without application metrics, Prometheus **already collects**:

1. **Pod metrics** (from kubelet):
   - CPU usage: `container_cpu_usage_seconds_total`
   - Memory usage: `container_memory_working_set_bytes`
   - Memory limits: `container_spec_memory_limit_bytes`
   - Disk I/O: `container_fs_*`

2. **Kubernetes metrics** (from kube-state-metrics):
   - Pod status: `kube_pod_status_phase`
   - Pod restarts: `kube_pod_container_status_restarts_total`
   - Resource requests/limits: `kube_pod_container_resource_*`

3. **Node metrics** (from node-exporter):
   - Node CPU, memory, disk, network

**The alerts in `prometheusrule-lms.yaml` use these existing metrics**, so they will work immediately.

### What Metrics Are Missing

Application-level metrics that require Django instrumentation:

1. **HTTP metrics**:
   - Request rate by endpoint
   - Response time by endpoint
   - Error rate by status code (400, 500, etc.)
   - Request size/response size

2. **Django metrics**:
   - View execution time
   - Template rendering time
   - Database query time
   - Cache hit/miss rate

3. **Open edX-specific metrics**:
   - Course enrollments
   - Video playback events
   - Problem submission rate
   - Active learners

## Next Steps

### Option 1: Enable Django Prometheus (Recommended)

**Benefits**: Rich application metrics with minimal overhead

**Implementation**:

1. Add to Open edX image `requirements.txt`:
   ```
   django-prometheus==2.3.1
   ```

2. Update `deploy/k8s/base/apps/openedx/settings/lms/production.py`:
   ```python
   INSTALLED_APPS = [
       'django_prometheus',
       # ... existing apps
   ]

   MIDDLEWARE = [
       'django_prometheus.middleware.PrometheusBeforeMiddleware',
       # ... existing middleware
       'django_prometheus.middleware.PrometheusAfterMiddleware',
   ]
   ```

3. Add metrics endpoint to URL config (edx-platform code):
   ```python
   # In lms/urls.py
   from django.urls import path
   from django_prometheus import exports as prometheus_exports

   urlpatterns += [
       path('metrics', prometheus_exports.ExportToDjangoView, name='metrics'),
   ]
   ```

4. Rebuild Open edX image:
   ```bash
   tutor images build openedx
   docker tag ... ghcr.io/biji-biji-initiative/mereka-lms/openedx:latest
   docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:latest
   ```

5. Restart LMS/CMS pods:
   ```bash
   kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
   ```

**Estimated effort**: 4-6 hours (image build is slow)

### Option 2: Use uWSGI Stats Server

**Benefits**: Quick win, no code changes, but limited metrics

**Implementation**:

1. Enable uWSGI stats in `deploy/k8s/base/apps/openedx/uwsgi.ini`:
   ```ini
   [uwsgi]
   stats = 127.0.0.1:1717
   stats-http = true
   ```

2. Add prometheus-uwsgi-exporter sidecar to LMS/CMS deployments

3. Update ServiceMonitors to scrape sidecar

**Metrics available**: Request rate, workers, memory, response time (no per-endpoint breakdown)

**Estimated effort**: 2-3 hours

### Option 3: Deploy exporters for infrastructure

**Status**: Implemented in base manifests (2026-02-08).

**Benefits**: Better visibility into MySQL, Redis, MongoDB

**Implementation**:

1. **MySQL**: `mysqld-exporter` sidecar + `mysql-metrics` ServiceMonitor
2. **Redis**: `redis-exporter` sidecar + `redis-metrics` ServiceMonitor
3. **MongoDB**: Atlas remains external; monitored via connectivity checks and app symptoms

**Estimated effort**: Completed (runtime rollout still requires GitOps/apply).

## Verification Steps

Once application metrics are enabled, verify with:

```bash
# 1. Check metrics endpoint returns data
kubectl exec -n mereka-lms deploy/lms -- curl -s localhost:8000/metrics | head -20

# 2. Check Prometheus is scraping
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets
# Look for "lms-metrics" and "cms-metrics" jobs

# 3. Check alerts are loaded
# In Prometheus UI, go to Alerts
# Verify "openedx-lms", "openedx-cms", "openedx-infrastructure" alert groups exist

# 4. Test an alert fires
# Scale LMS to 0 replicas, wait 5 minutes, check if LMSPodDown fires
kubectl scale deployment/lms -n mereka-lms --replicas=0
```

## Resources Created

```
deploy/k8s/base/monitoring/
├── README.md                       # Overview and next steps
├── IMPLEMENTATION_STATUS.md        # This file
├── kustomization.yaml              # Kustomize resources
├── servicemonitor-lms.yaml         # LMS metrics scraping
├── servicemonitor-cms.yaml         # CMS metrics scraping
├── servicemonitor-mysql.yaml       # MySQL exporter metrics scraping
├── servicemonitor-redis.yaml       # Redis exporter metrics scraping
└── prometheusrule-lms.yaml         # Alert rules (functional, uses kubelet metrics)
```

## Follow-Up Beads

Create these beads for next steps:

1. **mereka-lms-76j**: Keep django-prometheus and openedx_prometheus integration healthy in runtime rollouts
2. **mereka-lms-76m**: Create Grafana dashboards for Open edX metrics
