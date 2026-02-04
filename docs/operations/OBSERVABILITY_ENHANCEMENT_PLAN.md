# Mereka LMS Observability Enhancement Plan

**Project**: mereka-lms (SLO & Monitoring Improvements)  
**Version**: 2.0  
**Date**: 2026-02-04  
**Status**: Active plan  
**Owner**: SRE/Infra  

---

## Scope

This plan improves **production GKE monitoring** and the **VPS Grafana view**.  
Dev (kind) health checks remain script-based (`scripts/qa/public-health-check.sh`).

There is **no staging environment**.

---

## Current State (Verified)

**GCP Cloud Monitoring**
- Configs in `infrastructure/monitoring/` (uptime checks, dashboards, alerts).
- Apply via `scripts/infra/apply-monitoring-configs.sh`.

**Public Health + Certs**
- `scripts/qa/public-health-check.sh` (prod + dev).
- `scripts/infra/check-cert-sans.sh` for TLS SAN validation.
- GitHub Action: `.github/workflows/public-health-check.yml`.

**Grafana (VPS)**
- Dashboard exists in `/home/gurpreet/projects/observability/`:
  - `dashboards/03-applications/bbi-mereka-lms.json`
  - UID: `bbi-app-mereka-lms`

**SLO Baseline**
- Target availability: **99.5%** (Tier 2).
- Documented in `docs/operations/SLO_DASHBOARDS_SETUP.md`.

---

## Gaps / Opportunities

1. **MFE user-journey checks** (authn/login, account, dashboard).  
2. **Cross-env datasource validation** (VPS Grafana ↔ GKE telemetry).  
3. **Alert clarity / dedupe** between GCP and Grafana alerts.  
4. **Forum/Credentials auth failures**: ensure log-based panels + alerts cover these explicitly.  
5. **SLO burn-rate alerting** if required for incident response.

---

## Plan (Deliverables)

### 1) Synthetic Checks for MFEs (Prod)
**Goal:** Add uptime checks for core user flows.

**Deliverables**
- New uptime configs for:
  - `apps.academyv2.mereka.io/authn/login`
  - `apps.academyv2.mereka.io/account/`
  - `apps.academyv2.mereka.io/learner-dashboard`
- Wire into `scripts/infra/apply-monitoring-configs.sh`.

**Verify**
```bash
./scripts/infra/apply-monitoring-configs.sh plan
./scripts/infra/apply-monitoring-configs.sh apply
./scripts/qa/public-health-check.sh prod
```

### 2) Dashboard & Alert Coverage (Forum/Credentials)
**Goal:** Ensure auth and service failures are visible and actionable.

**Deliverables**
- Log-based panels for forum + credentials auth failures.
- Alert thresholds aligned with 5xx/auth failure policies.
- Update Grafana dashboard in `/home/gurpreet/projects/observability/`.

### 3) Cross-Environment Telemetry Validation
**Goal:** Confirm VPS Grafana can read GKE metrics.

**Deliverables**
- Validate datasource connectivity and document the path.
- Record any required firewall/network steps in `docs/operations/SLO_DASHBOARDS_SETUP.md`.

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
