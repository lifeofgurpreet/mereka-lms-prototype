# Mereka LMS Observability Enhancement Plan

**Project**: mereka-lms  
**Version**: 2.2  
**Date**: 2026-02-06  
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

**Log-based metrics**  
`infrastructure/monitoring/logging-metrics/`:

- `http-5xx.json`
- `auth-failures.json`
- `auth-failures-credentials.json`
- `auth-failures-forum.json`
- `authentik-authorize-4xx-mereka-lms.json`
- `lms-oidc-provider-disabled.json`
- `lms-csrf-failures.json`

**Dashboards**
- GCP dashboard JSON: `infrastructure/monitoring/dashboards/`  
- Auth-focused: `infrastructure/monitoring/dashboards/auth.json`
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
**Status:** Done (alert templates include the canonical notification channel IDs for the `mereka-lms` project).

### 6) PVC disk utilization alerting (P0 for in-cluster MySQL/Redis/Elasticsearch)
**Why:** Disk-full is a top outage cause for PVC-backed stateful services.

**Deliverables**
- Add a GCP Monitoring alert policy for PVC volume usage (or equivalent metric pipeline).
- Runbook section: what to do when MySQL/Redis/Elasticsearch PVC is near full.

### 7) In-cluster data service saturation signals (MySQL + Redis)
**Why:** Today we mostly infer DB/cache pain via app symptoms (timeouts/499s). We need direct saturation signals.

**Deliverables**
- Add exporters (or managed-equivalent telemetry) for:
  - MySQL: connections, slow queries, QPS/latency, innodb buffer pool pressure
  - Redis: memory usage, evictions, hit rate, latency
- Add dashboards + alerts for the above.

### 8) Backup posture in observability (Velero)
**Why:** Backups that exist but are silently failing are worse than no backups.

**Deliverables**
- Dashboard panels for: last successful backup per schedule, last restore drill, restore drill pass/fail.
- Alerts when restore drills fail or schedules stop producing recent backups.

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
- `scripts/infra/apply-monitoring-configs.sh`
- `scripts/qa/public-health-check.sh`
