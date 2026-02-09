# Monitoring & Alerting Guide
_Audience: Platform Eng + SRE • Owner: Infra Team • Last verified: 2026-02-08_

This checklist focuses on the production **GKE Autopilot** cluster that runs the `academyv2.mereka.io` stack (dev is `academyv2.mereka.dev` on VPS kind).

Reality-first (as of 2026-02-06):
- **MySQL** and **Redis** are **in-cluster** and PVC-backed (`kubectl get pvc -n mereka-lms`).
- Some older docs/templates reference **Cloud SQL** / **Memorystore**; treat those as **legacy** unless explicitly reintroduced.
- Backups are driven by **Velero** (see `docs/operations/VELERO_BACKUP_AUDIT.md`).

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

Coverage governance:
- Contract: `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`
- Audit script: `./scripts/qa/audit-grafana-dashboard.sh --strict-required`
- Strict recommendation gate: `./scripts/qa/audit-grafana-dashboard.sh --strict-required --strict-recommended`

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

2. **MySQL (in-cluster)**
   - Track deployment health: `kubernetes.io/container/restart_count`, CPU/memory utilization, and readiness.
   - Track **storage** via PVC volume used/capacity metrics (preferred) and alert before disks fill.
   - Saturation baseline is now live via CPU/memory request utilization on `mysql*` pods (`operations-signals` dashboard + `mysql-saturation-high` alert).
   - Exporter-level telemetry is now wired via `mysqld-exporter` sidecar + `mysql-metrics` ServiceMonitor.
   - Deep alert coverage in PrometheusRule: `MySQLExporterDown`, `MySQLHighConnectionUtilization`, `MySQLSlowQueriesSpike`.

3. **Redis (in-cluster)**
   - Saturation baseline is now live via CPU/memory request utilization on `redis*` pods (`operations-signals` dashboard + `redis-saturation-high` alert).
   - Exporter-level telemetry is now wired via `redis-exporter` sidecar + `redis-metrics` ServiceMonitor.
   - Deep alert coverage in PrometheusRule: `RedisExporterDown`, `RedisRejectedConnectionsSpike`, `RedisEvictionsSpike`.

> JSON templates live under `infrastructure/monitoring/dashboards/` (`gke.json`, `public-endpoints.json`, `auth.json`, `operations-signals.json`, plus legacy `cloudsql.json`, `redis.json`). Apply them with
> `./scripts/infra/apply-monitoring-configs.sh apply`

## Alerting Policies

Minimum recommended policies (edit thresholds as desired):

| Alert | JSON template | Notes |
|-------|---------------|-------|
| GKE pod restarts | `infrastructure/monitoring/alerts/pod-restarts.json` | Threshold: >5 restarts / pod within 10 min. |
| Ingress 5xx spike | `infrastructure/monitoring/alerts/lb-5xx-ratio.json` | Update the `url_map_name` if GKE creates a different LB. |
| (Legacy) Cloud SQL disk utilization | `infrastructure/monitoring/alerts/cloudsql-disk.json` | Legacy template. Replace with PVC disk utilization alerting for in-cluster MySQL/Redis/Elasticsearch. |
| PVC utilization high | `infrastructure/monitoring/alerts/pvc-utilization-high.json` | Uses `kubernetes.io/pod/volume/utilization` in namespace `mereka-lms`. |
| TLS certificate expiry | `infrastructure/monitoring/alerts/https-cert-expiry.json` | Requires the uptime checks below; fires when `time_until_ssl_cert_expires < 14 days`. |
| Log-based 5xx spike | `infrastructure/monitoring/alerts/log-5xx-spike.json` | Requires log metric `http-5xx`. |
| Log-based auth failures | `infrastructure/monitoring/alerts/log-auth-failures.json` | Requires log metric `auth-failures`. |
| Credentials auth failures | `infrastructure/monitoring/alerts/log-auth-failures-credentials.json` | Requires log metric `auth-failures-credentials`. |
| Forum auth failures | `infrastructure/monitoring/alerts/log-auth-failures-forum.json` | Requires log metric `auth-failures-forum`. |
| Authentik redirect_uri mismatch / authorize 4xx | `infrastructure/monitoring/alerts/log-authentik-authorize-4xx-mereka-lms.json` | Requires log metric `authentik-authorize-4xx-mereka-lms`. |
| LMS OIDC provider disabled | `infrastructure/monitoring/alerts/log-lms-oidc-provider-disabled.json` | Requires log metric `lms-oidc-provider-disabled` (catches "disabled backend/provider"). |
| LMS CSRF failures | `infrastructure/monitoring/alerts/log-lms-csrf-failures.json` | Requires log metric `lms-csrf-failures`. |
| In-cluster auth verify CronJob failures | `infrastructure/monitoring/alerts/log-auth-verify-cronjob-failures.json` | Requires log metric `auth-verify-cronjob-failures` (only applies after CronJob is deployed). |
| In-cluster TLS cert verify CronJob failures | `infrastructure/monitoring/alerts/log-cert-verify-cronjob-failures.json` | Requires log metric `cert-verify-cronjob-failures` (catches SAN mismatch + fake ingress cert). |
| Stateful storage errors | `infrastructure/monitoring/alerts/log-stateful-storage-errors.json` | Detects ENOSPC/read-only filesystem style failures in stateful services. |
| MySQL connection errors | `infrastructure/monitoring/alerts/log-mysql-connection-errors.json` | Detects DB connectivity/operational failures from app logs. |
| Redis connection errors | `infrastructure/monitoring/alerts/log-redis-connection-errors.json` | Detects cache connection/timeout failures from app logs. |
| Velero backup verification failures | `infrastructure/monitoring/alerts/log-velero-backup-verification-failures.json` | Detects failed daily backup-verification job runs. |
| Velero restore-test failures | `infrastructure/monitoring/alerts/log-velero-restore-test-failures.json` | Detects failed restore drill runs. |
| MySQL saturation high | `infrastructure/monitoring/alerts/mysql-saturation-high.json` | Warns on sustained high CPU/memory request utilization for MySQL pods. |
| Redis saturation high | `infrastructure/monitoring/alerts/redis-saturation-high.json` | Warns on sustained high CPU/memory request utilization for Redis pods. |
| Velero backup verification stale | `infrastructure/monitoring/alerts/velero-backup-verification-stale.json` | Critical stale approximation for daily verification cadence (implemented as `< 1 success over 24h for 6h`). |
| Velero restore-test stale (runtime audit) | Runtime checks (`audit-observability`, `audit-velero-alert-pipeline`) | Enforced by CronJob freshness audits; long-window 45d stale cannot be expressed as a standard Cloud Monitoring threshold/absence alert condition. |

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

By default, legacy Cloud SQL templates are skipped. Include them only if you intentionally run Cloud SQL again:

```bash
INCLUDE_LEGACY_MONITORING=1 ./scripts/infra/apply-monitoring-configs.sh apply
```

`apply-monitoring-configs.sh` also skips
`infrastructure/monitoring/alerts/velero-restore-test-stale.json` for the same 45-day
window limitation above.

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

gcloud logging metrics create auth-verify-cronjob-failures \
  --config-from-file=infrastructure/monitoring/logging-metrics/auth-verify-cronjob-failures.json \
  --project=mereka-lms

gcloud logging metrics create cert-verify-cronjob-failures \
  --config-from-file=infrastructure/monitoring/logging-metrics/cert-verify-cronjob-failures.json \
  --project=mereka-lms

gcloud logging metrics create stateful-storage-errors \
  --config-from-file=infrastructure/monitoring/logging-metrics/stateful-storage-errors.json \
  --project=mereka-lms

gcloud logging metrics create mysql-connection-errors \
  --config-from-file=infrastructure/monitoring/logging-metrics/mysql-connection-errors.json \
  --project=mereka-lms

gcloud logging metrics create redis-connection-errors \
  --config-from-file=infrastructure/monitoring/logging-metrics/redis-connection-errors.json \
  --project=mereka-lms

gcloud logging metrics create velero-backup-verification-failures \
  --config-from-file=infrastructure/monitoring/logging-metrics/velero-backup-verification-failures.json \
  --project=mereka-lms

gcloud logging metrics create velero-restore-test-failures \
  --config-from-file=infrastructure/monitoring/logging-metrics/velero-restore-test-failures.json \
  --project=mereka-lms

gcloud logging metrics create velero-backup-verification-success \
  --config-from-file=infrastructure/monitoring/logging-metrics/velero-backup-verification-success.json \
  --project=mereka-lms

gcloud logging metrics create velero-restore-test-success \
  --config-from-file=infrastructure/monitoring/logging-metrics/velero-restore-test-success.json \
  --project=mereka-lms
```

Create via Console (Monitoring → Alerting) or `gcloud monitoring policies create --policy-from-file alert.json`. When using `gcloud`, populate `notification_channels` with email/SMS/webhook IDs.

## Logging & Tracing

- Enable Cloud Logging sinks to BigQuery if long-term retention is required (`gcloud logging sinks create …`).
- For SMTP delivery issues, monitor AWS SES dashboards (CloudWatch) and set SNS notifications on bounces/complaints.
- Open edX log pipeline:
  - app logs (`all.log`, `tracking.log`) under `/openedx/data/logs`
  - Promtail -> Loki forwarding (`deploy/k8s/base/logging/`)
  - GCP log-based metrics in `infrastructure/monitoring/logging-metrics/`
- Sentry wiring contract: `./scripts/qa/verify-sentry-wiring.sh --mode local`
  (runtime enforcement: `STRICT_RUNTIME=1 ./scripts/qa/verify-sentry-wiring.sh --mode runtime`).
- Canonical logging + Sentry runbook: `docs/operations/LOGGING_AND_SENTRY.md`.
- Fast operator flow: `docs/operations/OBSERVABILITY_QUICKSTART.md`.
- Ownership model: `docs/operations/OBSERVABILITY_OWNERSHIP.md`.
- Severity policy: `docs/operations/ALERT_SEVERITY_MATRIX.md`.
- On-call runbook: `docs/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md`.

## Operational Runbook Tips

1. **On-call checks** – use `./scripts/qa/public-health-check.sh prod` (or `CHECK_BRANDING=1`) for public endpoints and `./scripts/qa/smoke-test.sh` for deeper verification.
2. **Pod deep dive** – `kubectl logs -n mereka-lms deployment/<service>` for each microservice noted in alerts.
3. **Data plane recovery** – for in-cluster state (MySQL/Redis PVs), recovery depends on Velero snapshot+restore drills. See `docs/operations/DISASTER_RECOVERY.md`.
4. **CI health checks** – `.github/workflows/public-health-check.yml` runs scheduled public checks + TLS SAN validation.
5. **Optional VPS cron** – use `scripts/infra/setup-vps-health-cron.sh` (installs `cron-public-health-check.sh`) only if you want local log files; CI remains the source of truth.
6. **Auth alert remediation** – see `docs/operations/AUTH_ALERT_RUNBOOK.md` for a mapping from each auth alert to the exact verification and fix commands.
7. **Observability posture audit** – run `./scripts/qa/audit-observability.sh --mode all` (or `--mode local` when offline) to verify coverage and deployment state.
8. **Velero alert pipeline audit** – run `./scripts/qa/audit-velero-alert-pipeline.sh` to validate log metrics/policies plus runtime CronJob freshness and hourly backup recency.
9. **Grafana coverage audit** – run `./scripts/qa/audit-grafana-dashboard.sh --strict-required` before rollout; use `--strict-recommended` when hardening dashboards.
10. **Atlas allowlist monitor audit (VPS)** – run `./scripts/qa/audit-atlas-allowlist-monitor.sh`; use `STRICT_WEBHOOK=1` for production-ready routing enforcement.
11. **Alert routing verification** – run `./scripts/qa/verify-alert-routing.sh` for runtime policy/channel checks plus optional VPS webhook routing validation.
12. **DB exporter telemetry audit** – run `./scripts/qa/audit-db-exporter-telemetry.sh --mode local`; after rollout enforce runtime presence with `STRICT_RUNTIME=1 ./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime`.
13. **Atlas modulestore guard** – run `./scripts/qa/verify-atlas-modulestore-path.sh --mode all` before rollout to prevent accidental fallback to in-cluster MongoDB.
14. **DR evidence bundle** – run `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar` (or use `.github/workflows/dr-evidence-bundle.yml`) for audit-ready artifacts.
15. **Single-command release gate** – run `./scripts/qa/run-operations-gates.sh --env both` before declaring platform health green.
16. **Automated runtime gate** – `.github/workflows/operations-gates-runtime.yml` runs every 6h (and manually) with CI-safe settings (`ALERT_ROUTING_RUN_ATLAS_VPS_AUDIT=0`).

## Certificate/SAN verification

Use the TLS checker before domain cutovers or after cert renewals:

```bash
./scripts/infra/check-cert-sans.sh
```

> Update this file as you add dashboards/alerts so the next engineer knows which policies exist and where they live.
