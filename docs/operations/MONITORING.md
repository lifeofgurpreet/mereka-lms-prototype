# Monitoring & Alerting Guide
_Audience: Platform Eng + SRE • Owner: Infra Team • Last verified: 2026-02-06_

This checklist focuses on the GKE Autopilot cluster, Cloud SQL, and Memorystore that run the production `academyv2.mereka.io` stack (dev is `academyv2.mereka.dev` on VPS kind).

## Dashboards

### BBI Observability Stack (Grafana)

The primary monitoring dashboard is hosted at https://grafana.mereka.io/d/bbi-app-mereka-lms

**Dashboard Sections**:
1. **Service Health**: LMS, CMS, Caddy, MFE, Workers status
2. **Data Services**: MySQL, MongoDB Atlas, Redis, Elasticsearch, Forum
3. **Resource Usage**: CPU and memory by pod
4. **External Availability (SLO)**: 24h availability, response time, SSL cert expiry
5. **Authentication & Security**: Auth failures by service
6. **Logs**: Error volumes and recent errors

### MongoDB Atlas Monitoring

**CRITICAL**: MongoDB Atlas is monitored via TCP connectivity probe (blackbox exporter).

- **Probe**: Checks TCP connection to `cluster-mereka-lms.2pjex4s.mongodb.net:27017` every 60s
- **Metric**: `probe_success{job="mongodb-atlas"}`
- **Dashboard Panel**: Shows as "MongoDB Atlas" in Data Services row
- **Alert**: `MongoDBAtlasDown` fires after 2min of failed probes (severity: critical)

**Why TCP probe?**:
- MongoDB Atlas is managed externally (no direct metrics export)
- TCP connectivity check ensures cluster is reachable from GKE
- Detects network issues, IP whitelist problems, or cluster outages

**If MongoDB Atlas is down**:
1. Check https://cloud.mongodb.com/ for cluster status
2. Verify IP whitelist includes GKE NAT IPs
3. Check billing/payment status
4. Review LMS/Forum pod logs for connection errors

### GCP Native Monitoring

1. **GKE Autopilot**
   - Metrics: `kubernetes.io/container/cpu/request_utilization`, `kubernetes.io/container/memory/request_utilization`, `kubernetes.io/container/restart_count`, `ingress.googleapis.com/https/request_count`.
   - Filter by namespace `mereka-lms`.
   - Add a log panel for `k8s_container` severity `ERROR` (namespace `mereka-lms`).

2. **Cloud SQL (MySQL)**
   - Metrics: `cloudsql.googleapis.com/database/cpu/utilization`, `cloudsql.googleapis.com/database/memory/utilization`, `cloudsql.googleapis.com/database/disk/utilization`, `cloudsql.googleapis.com/database/replication/lag`.
   - Enable "Query Insights" in the Cloud SQL console for slow-query heatmaps.

3. **Memorystore (Redis)**
   - Metrics: `redis.googleapis.com/stats/memory/used_bytes` vs `maxmemory`, `redis.googleapis.com/stats/commands/ops`, `redis.googleapis.com/stats/network/bytes`.

> JSON templates live under `infrastructure/monitoring/dashboards/` (`gke.json`, `cloudsql.json`, `redis.json`, `public-endpoints.json`, `auth.json`). Apply them with
> `./scripts/infra/apply-monitoring-configs.sh apply`

## Alerting Policies

Minimum recommended policies (edit thresholds as desired):

| Alert | JSON template | Notes |
|-------|---------------|-------|
| GKE pod restarts | `infrastructure/monitoring/alerts/pod-restarts.json` | Threshold: >5 restarts / pod within 10 min. |
| Ingress 5xx spike | `infrastructure/monitoring/alerts/lb-5xx-ratio.json` | Update the `url_map_name` if GKE creates a different LB. |
| Cloud SQL disk utilization | `infrastructure/monitoring/alerts/cloudsql-disk.json` | Fires when disk usage >80% for 5 min. |
| TLS certificate expiry | `infrastructure/monitoring/alerts/https-cert-expiry.json` | Requires the uptime checks below; fires when `time_until_ssl_cert_expires < 14 days`. |
| Log-based 5xx spike | `infrastructure/monitoring/alerts/log-5xx-spike.json` | Requires log metric `http-5xx`. |
| Log-based auth failures | `infrastructure/monitoring/alerts/log-auth-failures.json` | Requires log metric `auth-failures`. |
| Credentials auth failures | `infrastructure/monitoring/alerts/log-auth-failures-credentials.json` | Requires log metric `auth-failures-credentials`. |
| Forum auth failures | `infrastructure/monitoring/alerts/log-auth-failures-forum.json` | Requires log metric `auth-failures-forum`. |
| Authentik redirect_uri mismatch / authorize 4xx | `infrastructure/monitoring/alerts/log-authentik-authorize-4xx-mereka-lms.json` | Requires log metric `authentik-authorize-4xx-mereka-lms`. |
| LMS OIDC provider disabled | `infrastructure/monitoring/alerts/log-lms-oidc-provider-disabled.json` | Requires log metric `lms-oidc-provider-disabled` (catches "disabled backend/provider"). |
| LMS CSRF failures | `infrastructure/monitoring/alerts/log-lms-csrf-failures.json` | Requires log metric `lms-csrf-failures`. |

Apply an alert with:
`gcloud monitoring policies create --policy-from-file infrastructure/monitoring/alerts/https-cert-expiry.json --notification-channels=<channel-id>`

## Uptime & HTTPS checks

Create HTTPS uptime checks to drive availability metrics and the TLS-expiry alert:

```bash
gcloud monitoring uptime configs create \
  --config-from-file=infrastructure/monitoring/uptime/prod-lms-https.json \
  --project=mereka-lms
```

Apply all production uptime checks at once:

```bash
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply
```

Each config hits the endpoint every five minutes from Asia-Pacific probe sites and validates TLS. The production set now includes LMS, Studio, MFE, Discovery, Ecommerce, Notes, Credentials, Forum, and microsites. After creating uptime checks, re-run the alert creation command so the policy can reference the new metric series.

Apply an alert with:
`gcloud monitoring policies create --policy-from-file infrastructure/monitoring/alerts/pod-restarts.json`

Log-based metrics (required for auth/5xx alerts):

```bash
gcloud logging metrics create http-5xx \
  --config-from-file=infrastructure/monitoring/logging-metrics/http-5xx.json \
  --project=mereka-lms

gcloud logging metrics create auth-failures \
  --config-from-file=infrastructure/monitoring/logging-metrics/auth-failures.json \
  --project=mereka-lms

gcloud logging metrics create auth-failures-credentials \
  --config-from-file=infrastructure/monitoring/logging-metrics/auth-failures-credentials.json \
  --project=mereka-lms

gcloud logging metrics create auth-failures-forum \
  --config-from-file=infrastructure/monitoring/logging-metrics/auth-failures-forum.json \
  --project=mereka-lms

gcloud logging metrics create authentik-authorize-4xx-mereka-lms \
  --config-from-file=infrastructure/monitoring/logging-metrics/authentik-authorize-4xx-mereka-lms.json \
  --project=mereka-lms

gcloud logging metrics create lms-oidc-provider-disabled \
  --config-from-file=infrastructure/monitoring/logging-metrics/lms-oidc-provider-disabled.json \
  --project=mereka-lms

gcloud logging metrics create lms-csrf-failures \
  --config-from-file=infrastructure/monitoring/logging-metrics/lms-csrf-failures.json \
  --project=mereka-lms
```

Create via Console (Monitoring → Alerting) or `gcloud monitoring policies create --policy-from-file alert.json`. When using `gcloud`, populate `notification_channels` with email/SMS/webhook IDs.

## Logging & Tracing

- Enable Cloud Logging sinks to BigQuery if long-term retention is required (`gcloud logging sinks create …`).
- For SMTP delivery issues, monitor AWS SES dashboards (CloudWatch) and set SNS notifications on bounces/complaints.

## Operational Runbook Tips

1. **On-call checks** – use `./scripts/qa/public-health-check.sh prod` (or `CHECK_BRANDING=1`) for public endpoints and `./scripts/qa/smoke-test.sh` for deeper verification.
2. **Pod deep dive** – `kubectl logs -n mereka-lms deployment/<service>` for each microservice noted in alerts.
3. **Cloud SQL failover** – confirm automatic backups are successful (Cloud SQL → Backups). Manual export script lives in `scripts/infra/backup-db.sh`.
4. **CI health checks** – `.github/workflows/public-health-check.yml` runs scheduled public checks + TLS SAN validation.
5. **Optional VPS cron** – use `scripts/infra/setup-vps-health-cron.sh` (installs `cron-public-health-check.sh`) only if you want local log files; CI remains the source of truth.

## Certificate/SAN verification

Use the TLS checker before domain cutovers or after cert renewals:

```bash
./scripts/infra/check-cert-sans.sh
```

> Update this file as you add dashboards/alerts so the next engineer knows which policies exist and where they live.
