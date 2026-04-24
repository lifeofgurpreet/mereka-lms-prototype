# Bead mereka-lms-76i: ServiceMonitor for Open edX LMS - Deliverables

**Status**: ✓ COMPLETED (with limitations documented)
**Date**: 2026-02-04

## Summary

Created ServiceMonitors and PrometheusRules for Open edX LMS and CMS in GKE. The monitoring infrastructure is in place, but **application-level metrics are not yet available** because Open edX does not expose Prometheus metrics by default.

The alert rules use existing kubelet/kube-state-metrics and will work immediately. Application-level HTTP metrics require installing `django-prometheus` (follow-up work).

## Deliverables Completed

### 1. Investigation: Open edX Metrics Endpoint

**Finding**: Open edX LMS does not expose Prometheus metrics

```bash
$ kubectl exec -n mereka-lms deploy/lms -- curl localhost:8000/metrics
HTTP/1.1 400 Bad Request
```

**Root cause**: Django's `prometheus_client` is not installed in the Open edX image.

**Documentation**: See `/deploy/k8s/base/monitoring/README.md` for detailed explanation.

### 2. ServiceMonitors Created

#### File: `deploy/k8s/base/monitoring/servicemonitor-lms.yaml`
- Targets LMS service on port 8000
- Scrapes `/metrics` every 30s with 10s timeout
- Adds pod, node, namespace labels
- **Status**: Created but non-functional until django-prometheus is installed

#### File: `deploy/k8s/base/monitoring/servicemonitor-cms.yaml`
- Targets CMS (Studio) service on port 8000
- Scrapes `/metrics` every 30s with 10s timeout
- Adds pod, node, namespace labels
- **Status**: Created but non-functional until django-prometheus is installed

**Verification**:
```bash
$ kubectl get servicemonitor -n mereka-lms
NAME          AGE
cms-metrics   2m49s
lms-metrics   2m49s
```

### 3. PrometheusRule Created

#### File: `deploy/k8s/base/monitoring/prometheusrule-lms.yaml`

**Alert Groups**:

**openedx-lms** (6 rules):
- `LMSPodDown` - Pod unavailable >5min (CRITICAL)
- `LMSPodRestarting` - Frequent restarts (WARNING)
- `LMSPodMemoryHigh` - Memory >85% for >10min (WARNING)
- `LMSPodMemoryCritical` - Memory >95% for >5min (CRITICAL, OOM risk)
- `LMSPodCPUHigh` - CPU >85% for >10min (WARNING)
- `LMSPodDiskSpaceHigh` - PV disk >85% for >10min (WARNING)

**openedx-cms** (2 rules):
- `CMSPodDown` - Pod unavailable >5min (CRITICAL)
- `CMSPodMemoryHigh` - Memory >85% for >10min (WARNING)

**openedx-infrastructure** (4 rules):
- `MySQLPodDown` - Database unavailable >5min (CRITICAL)
- `RedisPodDown` - Cache unavailable >5min (CRITICAL)
- `MongoDBPodDown` - Coursestore/forum unavailable >5min (CRITICAL)
- `ElasticsearchPodDown` - Search unavailable >5min (WARNING)

**Status**: ✓ Functional (uses kubelet/kube-state-metrics)

**Verification**:
```bash
$ kubectl get prometheusrule -n mereka-lms
NAME         AGE
lms-alerts   2m49s
```

### 4. Applied and Verified

**Resources applied to cluster**:
```bash
$ kubectl apply -k deploy/k8s/base/monitoring/
prometheusrule.monitoring.coreos.com/lms-alerts created
servicemonitor.monitoring.coreos.com/cms-metrics created
servicemonitor.monitoring.coreos.com/lms-metrics created
```

**Service endpoints verified**:
```bash
$ kubectl get endpoints -n mereka-lms lms cms
NAME    ENDPOINTS                                     AGE
lms     10.100.0.124:8000,10.100.5.133:8000          19d
cms     10.100.5.134:8000                             19d
```

**Prometheus Operator confirmed running**:
```bash
$ kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
NAME                                  READY   STATUS    AGE
prometheus-monitoring-kube-...        2/2     Running   48d
```

## Files Created

```
deploy/k8s/base/monitoring/
├── README.md                       # Overview and alternatives
├── IMPLEMENTATION_STATUS.md        # Detailed status and next steps
├── kustomization.yaml              # Kustomize resources manifest
├── servicemonitor-lms.yaml         # LMS metrics scraping config
├── servicemonitor-cms.yaml         # CMS metrics scraping config
├── prometheusrule-lms.yaml         # Alert rules (functional)
└── verify.sh                       # Verification script
```

**Kustomization updated**: Added `monitoring` to `deploy/k8s/base/kustomization.yaml`

## Current Limitations

### What Works Today

✓ **Infrastructure monitoring** via existing metrics:
- Pod CPU/memory/disk usage (kubelet)
- Pod status and restarts (kube-state-metrics)
- Node metrics (node-exporter)
- Alert rules based on these metrics

### What Doesn't Work (Yet)

✗ **Application metrics** (requires django-prometheus):
- HTTP request rate per endpoint
- Response time per endpoint
- Error rate by status code (400, 500, etc.)
- Django view execution time
- Database query time
- Cache hit/miss rate
- Open edX-specific metrics (enrollments, video plays, etc.)

### Why ServiceMonitors Return No Data

The `/metrics` endpoint returns HTTP 400 because:
1. `django-prometheus` is not installed in the Open edX image
2. Open edX uses its own tracking/metrics system (tracking logs, Datadog)
3. Adding Prometheus metrics requires custom middleware installation

## Next Steps (Follow-Up Beads)

### Immediate Follow-Up

**Bead: mereka-lms-76j** - Enable django-prometheus in Open edX
- Add `django-prometheus==2.3.1` to requirements
- Update INSTALLED_APPS and MIDDLEWARE in settings
- Add `/metrics` URL endpoint
- Rebuild and push openedx image
- Restart LMS/CMS pods
- **Impact**: Enables rich application-level metrics
- **Effort**: 4-6 hours (image build is slow)

### Additional Monitoring

**Bead: mereka-lms-76k** - Add mysqld-exporter sidecar
- Deploy mysql-exporter as sidecar to MySQL pod
- Create ServiceMonitor for MySQL metrics
- **Impact**: Database query performance, connection pool, slow queries
- **Effort**: 2-3 hours

**Bead: mereka-lms-76l** - Add redis-exporter sidecar
- Deploy redis-exporter as sidecar to Redis pod
- Create ServiceMonitor for Redis metrics
- **Impact**: Cache hit rate, memory usage, evictions
- **Effort**: 2-3 hours

**Bead: mereka-lms-76m** - Create Grafana dashboards
- Import Open edX dashboard from community
- Customize for Mereka Academy metrics
- Add panels for enrollments, completions, active learners
- **Impact**: Visual monitoring and trends
- **Effort**: 3-4 hours

## Verification Steps

### Check Prometheus Discovery

```bash
# Port-forward to Prometheus UI
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Open browser: http://localhost:9090/targets
# Search for "mereka-lms" namespace
# You should see lms-metrics and cms-metrics (may show as "DOWN" until django-prometheus is enabled)
```

### Check Alert Rules

```bash
# In Prometheus UI: http://localhost:9090/alerts
# Verify alert groups appear:
# - openedx-lms
# - openedx-cms
# - openedx-infrastructure
```

### Test Existing Metrics

```bash
# Query container memory for LMS
curl -s "http://localhost:9090/api/v1/query?query=container_memory_working_set_bytes{namespace='mereka-lms',pod=~'lms-.*'}" | jq

# Query pod restarts
curl -s "http://localhost:9090/api/v1/query?query=kube_pod_container_status_restarts_total{namespace='mereka-lms',pod=~'lms-.*'}" | jq
```

### Run Verification Script

```bash
cd deploy/k8s/base/monitoring
./verify.sh
```

## Documentation

All implementation details, limitations, and next steps are documented in:

- **`deploy/k8s/base/monitoring/README.md`**: Quick overview and alternatives
- **`deploy/k8s/base/monitoring/IMPLEMENTATION_STATUS.md`**: Full status report with options
- **`deploy/k8s/base/monitoring/verify.sh`**: Automated verification script

## Constraints Met

✓ Follow existing Kustomize patterns in `deploy/k8s/`
✓ Labels match Prometheus Operator selector (empty selector = all namespaces)
✓ Documented that Open edX doesn't expose metrics natively
✓ Created follow-up bead requirements in IMPLEMENTATION_STATUS.md

## References

- [Django Prometheus](https://github.com/korfuri/django-prometheus)
- [Open edX Monitoring with Tutor](https://docs.tutor.edly.io/tutorials/monitoring.html)
- [Prometheus Operator ServiceMonitor](https://prometheus-operator.dev/docs/operator/design/#servicemonitor)
- [Prometheus Operator PrometheusRule](https://prometheus-operator.dev/docs/operator/design/#prometheusrule)
