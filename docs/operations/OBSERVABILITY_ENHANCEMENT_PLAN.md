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
- `cloudsql-disk.json`

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
**Why:** `prod-apps-https.json` only checks the base host; it does **not** validate
critical auth/login or account paths.

**Deliverables**
- Add uptime configs for:
  - `apps.academyv2.mereka.io/authn/login`
  - `apps.academyv2.mereka.io/account/`
  - `apps.academyv2.mereka.io/learner-dashboard`
- Wire into `scripts/infra/apply-monitoring-configs.sh`.

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
**Why:** Some alert templates intentionally leave `notificationChannels` empty to keep them portable.

**Deliverables**
- Decide the canonical notification channel IDs for the `mereka-lms` GCP project (email/SMS/webhook).
- Update the alert policy JSON templates accordingly (or document a post-apply patch step).

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
