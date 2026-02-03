# Mereka LMS SLO Dashboards Setup

**Date:** 2026-02-03
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
| Alert | `alerts/lb-5xx-ratio.json` | 5xx error rate spike detection |
| Alert | `alerts/pod-restarts.json` | Pod restart threshold alerts |
| Alert | `alerts/cloudsql-disk.json` | Cloud SQL disk usage |
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
gcloud alpha monitoring uptime create \
  --config-from-file=infrastructure/monitoring/uptime/prod-lms-https.json \
  --project=mereka-lms

# Apply all production checks + alerts
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply

gcloud alpha monitoring policies create \
  --policy-from-file=infrastructure/monitoring/alerts/lb-5xx-ratio.json \
  --project=mereka-lms
```

## Next Steps

1. [x] Add uptime configs for all public endpoints (LMS, Studio, MFE, Discovery, Ecommerce, Notes, microsites)
2. [x] Slack webhook integration (already configured via SLACK_ALERTMANAGER_WEBHOOK_URL in Infisical)
3. [x] Add log-based alerts for 5xx spikes and auth failures
4. [ ] Verify cross-env datasource connectivity (VPS → GKE)
5. [ ] Confirm academyv2.mereka.io probes stay green after DNS/cert validation

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
