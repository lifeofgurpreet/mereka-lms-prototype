# Observability Ownership and Sync Model
_Audience: SRE + Platform + Contributors • Last updated: 2026-02-07_

This document defines who owns each observability layer and how changes are synchronized.

## Source of Truth

| Layer | Source of truth | Owner |
|------|------------------|-------|
| GCP Monitoring templates (dashboards, alerts, uptime, log metrics) | `infrastructure/monitoring/` in this repo | Mereka LMS platform team |
| Apply logic | `scripts/infra/apply-monitoring-configs.sh` | Mereka LMS platform team |
| Audit logic | `scripts/qa/audit-observability.sh` | Mereka LMS platform team |
| Velero alert pipeline audit | `scripts/qa/audit-velero-alert-pipeline.sh` | Mereka LMS platform team |
| Alert routing verifier | `scripts/qa/verify-alert-routing.sh` | Mereka LMS platform team |
| Atlas modulestore guard | `scripts/qa/verify-atlas-modulestore-path.sh` | Mereka LMS platform team |
| DR evidence bundle builder | `scripts/qa/build-dr-evidence-bundle.sh` | Mereka LMS platform team |
| Atlas allowlist monitor audit (VPS drift routing) | `scripts/qa/audit-atlas-allowlist-monitor.sh` | Mereka LMS platform team |
| Unified operator gate | `scripts/qa/run-operations-gates.sh` | Mereka LMS platform team |
| VPS Grafana dashboard (`bbi-app-mereka-lms`) | observability repo (`/home/gurpreet/projects/observability`) | Observability platform team |

## Change Process

1. Update monitoring templates in this repo (`infrastructure/monitoring/`).
2. Run local guardrails:
   - `./scripts/qa/audit-observability.sh --mode local`
   - `OFFLINE_PLAN=1 ./scripts/infra/apply-monitoring-configs.sh plan`
3. Merge to `main`.
4. Apply to GCP Monitoring:
   - `./scripts/infra/apply-monitoring-configs.sh apply`
5. Verify deployed coverage:
   - `./scripts/qa/audit-observability.sh --mode runtime`
   - For release gates / deep audits: `STRICT_RUNTIME=1 ./scripts/qa/audit-observability.sh --mode runtime`
   - For Velero pipeline gate: `STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh --json`
   - For routing gate: `./scripts/qa/verify-alert-routing.sh`
   - For Atlas modulestore path gate: `./scripts/qa/verify-atlas-modulestore-path.sh --mode all`
   - For Atlas monitor posture (VPS): `./scripts/qa/audit-atlas-allowlist-monitor.sh` (and `STRICT_WEBHOOK=1` for production-ready routing)
6. Run consolidated release gate:
   - `./scripts/qa/run-operations-gates.sh --env both`
7. Build DR evidence artifact (monthly / major changes):
   - `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
8. If panel parity is needed in VPS Grafana, open/update PR in observability repo and link both PRs.

## Drift Rules

- Do not edit GCP Monitoring objects manually and leave templates stale.
- Do not add panel-only fixes in VPS Grafana for metrics that should exist in `infrastructure/monitoring/`.
- Keep legacy Cloud SQL templates opt-in only:
  - `INCLUDE_LEGACY_MONITORING=1` for intentional legacy operations.

## Review Checklist (PR)

- New metric has:
  - logging metric JSON
  - alert JSON (if actionable)
  - dashboard panel (if operator-facing)
- `audit-observability --mode local` passes.
- Offline plan is generated and attached (CI artifact).
- If change touches Velero coverage, run strict runtime audit and confirm freshness status for `backup-verification` and `restore-test`.
- Docs updated (`MONITORING.md`, quickstart/runbooks as needed).
