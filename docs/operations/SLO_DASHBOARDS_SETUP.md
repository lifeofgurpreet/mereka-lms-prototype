# Mereka LMS SLO Dashboards Setup

**Date:** 2026-02-06
**Status:** Updated

## Overview

This document describes the SLO monitoring setup for Mereka LMS (Open edX) platform running on GKE.

## Monitoring Architecture

Mereka LMS uses a hybrid monitoring approach:

### 1. GCP Cloud Monitoring (Native GKE)

Located in: `infrastructure/monitoring/`

| Type | File | Description |
|------|------|-------------|
| Uptime Check | `uptime/prod-*.json` | HTTPS checks for academyv2 + microsites + APIs |
| Dashboard | `dashboards/public-endpoints.json` | Uptime SLO view for public endpoints |
| Dashboard | `dashboards/operations-signals.json` | Stateful storage, DB/cache connection, Velero drill signals |
| Alert | `alerts/lb-5xx-ratio.json` | 5xx error rate spike detection |
| Alert | `alerts/pod-restarts.json` | Pod restart threshold alerts |
| Alert | `alerts/log-stateful-storage-errors.json` | ENOSPC/read-only filesystem failures |
| Alert | `alerts/log-mysql-connection-errors.json` | MySQL connection failures from app logs |
| Alert | `alerts/log-redis-connection-errors.json` | Redis connection failures from app logs |
| Alert | `alerts/log-velero-backup-verification-failures.json` | Velero verification job failures |
| Alert | `alerts/log-velero-restore-test-failures.json` | Velero restore drill failures |
| Alert | `alerts/https-cert-expiry.json` | SSL certificate expiry |
| Alert | `alerts/log-5xx-spike.json` | Log-based 5xx spikes |
| Alert | `alerts/log-auth-failures.json` | Log-based auth failures |

### 2. Centralized Grafana Dashboard (VPS Observability Stack)

Located in: `/home/gurpreet/projects/observability/`

**Dashboard:** `dashboards/03-applications/bbi-mereka-lms.json`
- UID: `bbi-app-mereka-lms`
- Folder: Applications
- URL: https://grafana.mereka.dev/d/bbi-app-mereka-lms

**Panels:**
- Service Health (LMS, CMS, Caddy, MFE, Workers)
- Data Services (MySQL, MongoDB, Redis, Elasticsearch, Forum, Discovery, SMTP)
- Resource Usage (CPU, Memory by pod)
- External Availability (SLO: 99.5%)
- Response Time tracking
- SSL Certificate expiry
- Log volume by level
- Recent errors

**Alerts:** Added to `alerts/applications.yaml`
- `MerekaLMSDown` - LMS pods not running (critical)
- `MerekaCMSDown` - CMS pods not running (critical)
- `MerekaCaddyDown` - Caddy proxy not running (critical)
- `MerekaMySQLDown` - MySQL not running (critical)
- `MerekaLMSHighRestarts` - High restart count (warning)
- `MerekaLMSAvailabilityLow` - Below 99.5% SLO (warning)

## SLO Targets

Based on STANDARDS.md Tier 2 classification:

| SLI | Target | Window |
|-----|--------|--------|
| Availability | 99.5% | Monthly |
| Error Budget | 3.6 hours | Monthly |
| Response Time | <2s p95 | 5 min |

## Deployment

### VPS Grafana Stack

```bash
cd /home/gurpreet/projects/observability
kubectl apply -k deploy/overlays/vps
```

### GCP Cloud Monitoring

Use Terraform or gcloud CLI to apply alert policies:

```bash
gcloud monitoring uptime create \
  --config-from-file=infrastructure/monitoring/uptime/prod-lms-https.json \
  --project=mereka-lms

# Apply all production checks + alerts
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply

gcloud monitoring policies create \
  --policy-from-file=infrastructure/monitoring/alerts/lb-5xx-ratio.json \
  --project=mereka-lms

# Audit coverage (local/repo only)
./scripts/qa/audit-observability.sh --mode local

# Audit runtime deployment state (requires cluster + gcloud auth)
./scripts/qa/audit-observability.sh --mode runtime
```

## Telemetry Path & Datasource Connectivity

### Architecture Overview

The Grafana dashboard on the VPS (`grafana.mereka.dev`) connects to two separate Prometheus instances:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Grafana (VPS - K8s monitoring namespace)          │
│                   https://grafana.mereka.dev                         │
│                   Namespace: monitoring                              │
└────────────┬────────────────────────────────────────┬────────────────┘
             │                                        │
             │ Datasource: prometheus                 │ Datasource: prometheus-vps
             │ (default, UID: prometheus)             │ (UID: prometheus-vps)
             │                                        │
             v                                        v
┌─────────────────────────────────┐    ┌──────────────────────────────┐
│  GKE Prometheus (in-cluster)    │    │  VPS Prometheus (Docker)     │
│  monitoring-kube-prometheus-    │    │  https://prometheus.mereka.  │
│  prometheus.monitoring:9090     │    │  dev                         │
│                                 │    │                              │
│  • kube-state-metrics           │    │  • Blackbox exporter         │
│  • node-exporter                │    │  • PM2 metrics               │
│  • cadvisor                     │    │  • External URL probes       │
│  • ServiceMonitors              │    │  • VPS system metrics        │
└─────────────────────────────────┘    └──────────────────────────────┘
             │                                        │
             │ Scrapes                                │ Scrapes
             v                                        v
┌─────────────────────────────────┐    ┌──────────────────────────────┐
│  Mereka LMS GKE Cluster         │    │  External Endpoints          │
│  Namespace: mereka-lms          │    │                              │
│                                 │    │  • academyv2.mereka.io       │
│  • LMS pods (kube_pod_*)        │    │  • academyv2.mereka.io       │
│  • CMS pods                     │    │  • studio.academyv2.mereka.io│
│  • Caddy proxy                  │    │  • academy.biji-biji.com     │
│  • MySQL, Redis, Workers        │    │  • apps.academyv2.mereka.io  │
│                                 │    │  • Auth endpoints            │
└─────────────────────────────────┘    └──────────────────────────────┘
```

### Datasource Configuration

#### 1. GKE Prometheus (Primary - Default)
**ConfigMap:** `monitoring-kube-prometheus-grafana-datasource`
**Datasource UID:** `prometheus`
**URL:** `http://monitoring-kube-prometheus-prometheus.monitoring:9090/`
**Access:** Proxy (in-cluster)
**Purpose:** Kubernetes metrics for GKE workloads (pods, nodes, services)

#### 2. VPS Prometheus (External URL Monitoring)
**ConfigMap:** `grafana-datasource-vps-prometheus`
**Datasource UID:** `prometheus-vps`
**URL:** `https://prometheus.mereka.dev`
**Access:** Proxy (HTTPS)
**Purpose:** External endpoint probes, VPS standalone apps

### Dashboard Metric Sources

The `bbi-app-mereka-lms` dashboard uses the **default GKE Prometheus** (`prometheus` UID) for:
- Pod status (`kube_pod_status_phase`)
- Resource usage (`container_cpu_usage_seconds_total`, `container_memory_working_set_bytes`)
- Service availability
- Node metrics

The VPS Prometheus (`prometheus-vps` UID) provides:
- External URL uptime via Blackbox exporter
- SSL certificate expiry monitoring
- Public endpoint response times
- SLO breach detection

### Verifying Datasource Connectivity

#### Automated Validation Script

Run the automated connectivity validation script to test all datasource connections:

```bash
./scripts/infra/validate-telemetry-connectivity.sh
```

**Expected output:**
```
==========================================
Mereka LMS Telemetry Connectivity Validator
==========================================

[1/8] Testing VPS Prometheus (prometheus.mereka.dev)...
✓ PASS: VPS Prometheus HTTPS endpoint
[2/8] Testing VPS Prometheus external URL monitoring...
✓ PASS: VPS Prometheus external-urls job
[3/8] Testing GKE Prometheus service...
✓ PASS: GKE Prometheus service exists
[4/8] Testing GKE Prometheus pod status...
✓ PASS: GKE Prometheus pod running
[5/8] Testing GKE Prometheus in-cluster query...
✓ PASS: GKE Prometheus query from Grafana
[6/8] Testing Mereka LMS namespace metrics availability...
✓ PASS: Mereka LMS pod metrics
[7/8] Testing Grafana datasource configuration...
✓ PASS: Grafana datasource ConfigMaps
[8/8] Testing specific datasource configs...
✓ PASS: Required datasource ConfigMaps

==========================================
Summary
==========================================
Passed: 8
Failed: 0

✓ All telemetry connectivity tests passed!
```

#### Manual Validation Steps

#### Check Datasource Configuration
```bash
# List all Grafana datasource ConfigMaps
kubectl get configmap -n monitoring -l grafana_datasource=1

# View GKE Prometheus datasource config
kubectl get configmap -n monitoring \
  monitoring-kube-prometheus-grafana-datasource -o yaml

# View VPS Prometheus datasource config
kubectl get configmap -n monitoring \
  grafana-datasource-vps-prometheus -o yaml
```

#### Test GKE Prometheus Connectivity (from Grafana pod)
```bash
# Query Mereka LMS pod metrics
kubectl exec -n monitoring deployment/monitoring-grafana -- \
  wget -qO- --timeout=5 \
  'http://monitoring-kube-prometheus-prometheus.monitoring:9090/api/v1/query?query=kube_pod_status_phase{namespace="mereka-lms"}' \
  | python3 -m json.tool

# Expected: JSON response with pod metrics
```

#### Test VPS Prometheus Connectivity (from VPS host)
```bash
# Query external URL uptime
curl -sS 'https://prometheus.mereka.dev/api/v1/query?query=up{job="external-urls"}' \
  | python3 -m json.tool

# Expected: JSON response with Mereka LMS URL probe results
```

#### Verify Grafana Can Query Both Datasources
```bash
# Get Grafana pod
GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o name | head -1)

# Test GKE Prometheus (in-cluster)
kubectl exec -n monitoring $GRAFANA_POD -- \
  wget -qO- 'http://monitoring-kube-prometheus-prometheus.monitoring:9090/api/v1/query?query=up' \
  | head -50

# Test VPS Prometheus (external)
kubectl exec -n monitoring $GRAFANA_POD -- \
  wget -qO- 'https://prometheus.mereka.dev/api/v1/query?query=up' \
  | head -50
```

### Troubleshooting Datasource Connectivity

#### Issue: Dashboard Shows "No Data"

**Check 1: Verify Prometheus is running**
```bash
# GKE Prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus

# VPS Prometheus (Docker)
docker ps --filter "name=prometheus"
```

**Check 2: Test queries manually**
```bash
# From GKE Prometheus web UI (port-forward if needed)
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090

# Visit http://localhost:9090 and run query:
# kube_pod_status_phase{namespace="mereka-lms"}
```

**Check 3: Verify Grafana datasource health**
- Open Grafana: https://grafana.mereka.dev
- Go to **Configuration** → **Data Sources**
- Click **Prometheus** → **Test** button
- Click **Prometheus-VPS** → **Test** button
- Both should show "Data source is working"

#### Issue: GKE Metrics Missing

**Possible causes:**
1. **Prometheus Operator not scraping** - Check ServiceMonitor configuration
2. **Namespace not monitored** - Prometheus `serviceMonitorNamespaceSelector: {}` allows all namespaces
3. **Label selectors mismatch** - Prometheus `serviceMonitorSelector: {}` allows all ServiceMonitors

**Diagnostic commands:**
```bash
# Check if Prometheus is scraping mereka-lms namespace
kubectl exec -n monitoring monitoring-kube-prometheus-prometheus-0 -- \
  wget -qO- 'http://localhost:9090/api/v1/targets' | grep mereka-lms

# Check kube-state-metrics is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=kube-state-metrics

# Verify kube-state-metrics is exposing mereka-lms metrics
kubectl port-forward -n monitoring svc/monitoring-kube-state-metrics 8080:8080
curl -sS http://localhost:8080/metrics | grep 'namespace="mereka-lms"' | head
```

#### Issue: VPS Prometheus Unreachable

**Possible causes:**
1. **Cloudflare tunnel down** - Check `cloudflared` status
2. **Docker container stopped** - Check `docker ps`
3. **Network policy blocking** - Check K8s NetworkPolicies

**Diagnostic commands:**
```bash
# Check VPS Prometheus is accessible from internet
curl -sI https://prometheus.mereka.dev/api/v1/query

# Check from within GKE cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -sI https://prometheus.mereka.dev/api/v1/query

# Check Cloudflare tunnel status (on VPS)
systemctl status cloudflared
```

### ServiceMonitor Creation (Future Enhancement)

Currently, Mereka LMS pods do not expose Prometheus metrics endpoints. To enable application-level metrics:

1. **Add metrics endpoint to Open edX** (requires custom middleware)
2. **Create ServiceMonitor** to scrape metrics:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: lms-metrics
  namespace: mereka-lms
  labels:
    app.kubernetes.io/name: lms
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: lms
  endpoints:
  - port: metrics  # Assumes service has 'metrics' port
    path: /metrics
    interval: 30s
```

3. **Verify Prometheus discovers the ServiceMonitor**:
```bash
kubectl get servicemonitor -n mereka-lms
kubectl logs -n monitoring prometheus-monitoring-kube-prometheus-prometheus-0 \
  | grep "ServiceMonitor"
```

### Validation Checklist

- [x] VPS Prometheus accessible via HTTPS (`https://prometheus.mereka.dev`)
- [x] GKE Prometheus accessible in-cluster (`monitoring-kube-prometheus-prometheus.monitoring:9090`)
- [x] Grafana datasource `prometheus` (default) configured
- [x] Grafana datasource `prometheus-vps` configured
- [x] Dashboard panels query correct datasource UIDs
- [x] External URL probes returning data (`external-urls` job)
- [x] GKE pod metrics returning data (`kube_pod_status_phase{namespace="mereka-lms"}`)
- [ ] ServiceMonitors created for LMS application metrics (future)
- [ ] Alert rules firing correctly to Alertmanager

## Next Steps

1. [x] Add uptime configs for all public endpoints (LMS, Studio, MFE, Discovery, Ecommerce, Notes, microsites)
2. [x] Slack webhook integration (already configured via SLACK_ALERTMANAGER_WEBHOOK_URL in Infisical)
3. [x] Add log-based alerts for 5xx spikes and auth failures
4. [x] Verify cross-env datasource connectivity (VPS → GKE)
5. [ ] Confirm academyv2.mereka.io probes stay green after DNS/cert validation
6. [ ] Add ServiceMonitors for application-level metrics (LMS, CMS, Caddy)

## Known Issues

### academyv2.mereka.io Certificate

If academyv2.mereka.io shows the fake Kubernetes ingress certificate, verify DNS is pointing to the
Caddy LoadBalancer and run `./scripts/infra/check-cert-sans.sh`. Caddy manages TLS for
`academyv2.mereka.io`, `studio.academyv2.mereka.io`, and `apps.academyv2.mereka.io`.

## Files Modified

- `/home/gurpreet/projects/observability/dashboards/03-applications/bbi-mereka-lms.json` (created)
- `/home/gurpreet/projects/observability/alerts/applications.yaml` (updated)
- `/home/gurpreet/projects/observability/deploy/base/kustomization.yaml` (updated)
- `/home/gurpreet/infrastructure/prometheus/prometheus.yml` (updated - added external-urls job)
- `/home/gurpreet/infrastructure/prometheus/blackbox.yml` (updated - added https_2xx module)
