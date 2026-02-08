# Mereka LMS Observability Enhancement Plan

**Project**: mereka-lms  
**Version**: 2.8
**Date**: 2026-02-07  
**Status**: Active  
**Owner**: SRE/Infra  

---

## Scope

This plan improves **production GKE monitoring** and the **VPS Grafana view**.  
Dev (kind) health checks remain script-based (`scripts/qa/public-health-check.sh`).

There is **no staging environment**.

Reality-first:
- Production MySQL/Redis are **in-cluster** and PVC-backed (not Cloud SQL/Memorystore).
- Any Cloud SQL references are legacy unless explicitly reintroduced.

---

## Shipped This Cycle (2026-02-06)

- Added `operations-signals` dashboard template:
  - `infrastructure/monitoring/dashboards/operations-signals.json`
- Added new log metrics + alerts for:
  - stateful storage errors
  - MySQL connection errors
  - Redis connection errors
  - Velero backup-verification failures
  - Velero restore-test failures
- Added MySQL/Redis saturation alerts:
  - `infrastructure/monitoring/alerts/mysql-saturation-high.json`
  - `infrastructure/monitoring/alerts/redis-saturation-high.json`
- Added Velero freshness/success signals:
  - `infrastructure/monitoring/logging-metrics/velero-backup-verification-success.json`
  - `infrastructure/monitoring/logging-metrics/velero-restore-test-success.json`
  - `infrastructure/monitoring/alerts/velero-backup-verification-stale.json`
  - `infrastructure/monitoring/alerts/velero-restore-test-stale.json`
- Added PVC utilization alert template:
  - `infrastructure/monitoring/alerts/pvc-utilization-high.json`
- Added local/runtime audit command:
  - `scripts/qa/audit-observability.sh`
- Added consolidated operator gate:
  - `scripts/qa/run-operations-gates.sh`
  - Alert-routing verification is enabled by default (opt-out only)
- Added Atlas modulestore path guard:
  - `scripts/qa/verify-atlas-modulestore-path.sh`
- Added one-command alert routing verifier:
  - `scripts/qa/verify-alert-routing.sh`
- Added explicit multisite governance gate runner:
  - `scripts/qa/run-multisite-governance-gates.sh`
- Added deep data-store exporter telemetry baseline:
  - MySQL sidecar `mysqld-exporter` + ServiceMonitor `mysql-metrics`
  - Redis sidecar `redis-exporter` + ServiceMonitor `redis-metrics`
  - Deep telemetry alerts in `prometheusrule-lms.yaml`:
    - `MySQLExporterDown`, `MySQLHighConnectionUtilization`, `MySQLSlowQueriesSpike`
    - `RedisExporterDown`, `RedisRejectedConnectionsSpike`, `RedisEvictionsSpike`
- Added deterministic exporter telemetry audit:
  - `scripts/qa/audit-db-exporter-telemetry.sh` (`--mode local|runtime|all`)
- Consolidated gate now includes DB exporter telemetry audit in local mode by default:
  - `scripts/qa/run-operations-gates.sh` (`RUN_DB_EXPORTER_TELEMETRY_AUDIT=1`)
  - Runtime workflow `.github/workflows/operations-gates-runtime.yml` enforces `DB_EXPORTER_AUDIT_MODE=runtime`.
  - Gate artifacts now include `summary.md` and `summary.json` for fast triage.
- Added DR evidence bundle builder:
  - `scripts/qa/build-dr-evidence-bundle.sh`
- Added VPS Atlas allowlist monitor posture audit:
  - `scripts/qa/audit-atlas-allowlist-monitor.sh`
- Added Grafana coverage contract + audit gate:
  - `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`
  - `scripts/qa/audit-grafana-dashboard.sh`
- Added CI automation:
  - `.github/workflows/observability-audit.yml`
  - PR guardrails in `.github/workflows/ci.yml`

---

## What’s Already in Place (Baseline)

**Uptime checks (GCP Monitoring)**  
Defined in `infrastructure/monitoring/uptime/` and applied via  
`scripts/infra/apply-monitoring-configs.sh`:

- `prod-lms-https.json`
- `prod-studio-https.json`
- `prod-apps-https.json`
- `prod-discovery-https.json`
- `prod-ecommerce-https.json`
- `prod-credentials-https.json`
- `prod-notes-https.json`
- `prod-forum-https.json`
- `prod-skillourfuture-https.json`
- `prod-biji-https.json`

**Alerts (GCP Monitoring)**  
`infrastructure/monitoring/alerts/`:

- `lb-5xx-ratio.json`
- `log-5xx-spike.json`
- `log-auth-failures.json`
- `log-auth-failures-credentials.json`
- `log-auth-failures-forum.json`
- `log-authentik-authorize-4xx-mereka-lms.json`
- `log-lms-oidc-provider-disabled.json`
- `log-lms-csrf-failures.json`
- `https-cert-expiry.json`
- `pod-restarts.json`
- `cloudsql-disk.json` *(legacy; replace with PVC disk utilization alerting)*
- `log-stateful-storage-errors.json`
- `log-mysql-connection-errors.json`
- `log-redis-connection-errors.json`
- `log-velero-backup-verification-failures.json`
- `log-velero-restore-test-failures.json`
- `mysql-saturation-high.json`
- `redis-saturation-high.json`
- `velero-backup-verification-stale.json`
- `velero-restore-test-stale.json`

**Log-based metrics**  
`infrastructure/monitoring/logging-metrics/`:

- `http-5xx.json`
- `auth-failures.json`
- `auth-failures-credentials.json`
- `auth-failures-forum.json`
- `authentik-authorize-4xx-mereka-lms.json`
- `lms-oidc-provider-disabled.json`
- `lms-csrf-failures.json`
- `stateful-storage-errors.json`
- `mysql-connection-errors.json`
- `redis-connection-errors.json`
- `velero-backup-verification-failures.json`
- `velero-restore-test-failures.json`
- `velero-backup-verification-success.json`
- `velero-restore-test-success.json`

**Dashboards**
- GCP dashboard JSON: `infrastructure/monitoring/dashboards/`  
- Auth-focused: `infrastructure/monitoring/dashboards/auth.json`
- Ops-focused: `infrastructure/monitoring/dashboards/operations-signals.json`
- VPS Grafana dashboard: `/home/gurpreet/projects/observability/dashboards/03-applications/bbi-mereka-lms.json`  
  UID: `bbi-app-mereka-lms`

**Public health checks + TLS SAN validation**
- `scripts/qa/public-health-check.sh` (prod + dev)
- `scripts/infra/check-cert-sans.sh`
- GitHub Action: `.github/workflows/public-health-check.yml`

---

## Remaining Work (Actual Gaps)

### 1) MFE user‑journey checks (prod)
**Status:** Done (uptime configs exist: `prod-mfe-login.json`, `prod-mfe-account.json`, `prod-mfe-dashboard.json`).

### 2) Service‑specific auth failure visibility (forum + credentials)
**Status:** Done (log metrics + alerts exist for credentials/forum).

### 3) Validate Grafana ↔ GKE telemetry path
**Why:** The VPS Grafana dashboard exists, but datasource connectivity to GKE
metrics needs explicit validation and documentation.

**Deliverables**
- Confirm datasource config and connectivity.
- Document steps in `docs/operations/SLO_DASHBOARDS_SETUP.md`.

### 4) SLO burn‑rate alerts (optional / if required)
**Why:** Useful for proactive incident response.  
Only implement if the team wants formal burn‑rate enforcement.

### 5) Wire notification channels for log-based alerts
**Status:** Done for GCP alert policies. End-to-end validation is now one command:
- `./scripts/qa/verify-alert-routing.sh`
- CI runtime audit: `.github/workflows/alert-routing-audit.yml`
- Atlas allowlist webhook routing is enforced via `STRICT_WEBHOOK=1 ./scripts/qa/audit-atlas-allowlist-monitor.sh` (latest strict audit pass: 2026-02-08).
- High-severity routing contract now enforces both `ERROR` and `CRITICAL` policy/channel validation.

### 6) PVC disk utilization alerting (P0 for in-cluster MySQL/Redis/Elasticsearch)
**Why:** Disk-full is a top outage cause for PVC-backed stateful services.

**Deliverables**
- Add a GCP Monitoring alert policy for PVC volume usage (or equivalent metric pipeline).
- Runbook section: what to do when MySQL/Redis/Elasticsearch PVC is near full.

**Status:** Done (alert + dashboard panel shipped).

### 7) In-cluster data service saturation signals (MySQL + Redis)
**Why:** Today we mostly infer DB/cache pain via app symptoms (timeouts/499s). We need direct saturation signals.

**Deliverables**
- Add saturation coverage based on currently available GKE metrics.
- Add dashboards + alerts for MySQL/Redis pressure.
- Keep exporter-level telemetry as next-level hardening.

**Status:** Baseline + exporter telemetry contract shipped. Runtime rollout verification remains environment-dependent (run `STRICT_RUNTIME=1 ./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime` post-GitOps apply).

### 8) Backup posture in observability (Velero)
**Why:** Backups that exist but are silently failing are worse than no backups.

**Deliverables**
- Dashboard panels for: last successful backup per schedule, last restore drill, restore drill pass/fail.
- Alerts when restore drills fail or schedules stop producing recent backups.

**Status:** In progress (failures + success metrics + stale-success alerts + dashboard status panels shipped; restore-test CronJob now enforces PV-aware validation). Monthly evidence pipeline is now scripted (`build-dr-evidence-bundle.sh`) and automated in `.github/workflows/dr-evidence-bundle.yml`.

### 9) Deterministic observability audit command
**Why:** Operators need one command that says what is missing in repo vs runtime.

**Deliverables**
- `scripts/qa/audit-observability.sh`
- JSON output for incident tickets
- Local/offline mode and runtime mode

**Status:** Done.

---

## Execution Checklist

```bash
# Apply monitoring configs
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply

# Validate public endpoints + certificates
CHECK_CERTS=1 ./scripts/qa/public-health-check.sh prod
```

Verify in:
- **GCP Monitoring** (uptime checks + alert policies)
- **Grafana** dashboard `bbi-app-mereka-lms`

---

## References

- `docs/operations/SLO_DASHBOARDS_SETUP.md`
- `docs/operations/MONITORING.md`
- `docs/operations/OBSERVABILITY_QUICKSTART.md`
- `scripts/infra/apply-monitoring-configs.sh`
- `scripts/qa/public-health-check.sh`
- `scripts/qa/audit-observability.sh`
