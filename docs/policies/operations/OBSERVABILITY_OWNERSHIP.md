# Observability Ownership and Sync Model
_Audience: SRE + Platform + Contributors • Last updated: 2026-02-07_

This document defines who owns each observability layer and how changes are synchronized.

## Boundary Summary

- `mereka-lms` repository owns observability contracts, templates, audits, and gates for LMS application-level monitoring posture.
- `infrastructure` repository is the GitOps source of truth for deployed monitoring stack/runtime overlays in Kubernetes.
- `vps/infrastructure` owns VPS-specific observability runtime assets.
- `/home/gurpreet/projects/observability` is deprecated and must not be treated as active source of truth.

## Source of Truth

| Layer | Source of truth | Owner |
|------|------------------|-------|
| GCP Monitoring templates (dashboards, alerts, uptime, log metrics) | `infrastructure/monitoring/` in this repo | Mereka LMS platform team |
| Apply logic | `scripts/infra/apply-monitoring-configs.sh` | Mereka LMS platform team |
| Audit logic | `scripts/qa/audit-observability.sh` | Mereka LMS platform team |
| Velero alert pipeline audit | `scripts/qa/audit-velero-alert-pipeline.sh` | Mereka LMS platform team |
| Alert routing verifier | `scripts/qa/verify-alert-routing.sh` | Mereka LMS platform team |
| DB exporter telemetry audit | `scripts/qa/audit-db-exporter-telemetry.sh` | Mereka LMS platform team |
| Atlas modulestore guard | `scripts/qa/verify-atlas-modulestore-path.sh` | Mereka LMS platform team |
| DR evidence bundle builder | `scripts/qa/build-dr-evidence-bundle.sh` | Mereka LMS platform team |
| Runtime consolidated operations gate | `.github/workflows/operations-gates-runtime.yml` | Mereka LMS platform team |
| Atlas allowlist monitor audit (VPS drift routing) | `scripts/qa/audit-atlas-allowlist-monitor.sh` | Mereka LMS platform team |
| Unified operator gate | `scripts/qa/run-operations-gates.sh` | Mereka LMS platform team |
| Platform monitoring stack (Prometheus/Grafana/Alertmanager/Loki/Tempo) | `infrastructure/monitoring/` | Platform observability team |
| Mereka LMS runtime overlays (ServiceMonitors/PrometheusRules/image pins) | `https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/apps/mereka-lms/overlays/prod/` (+ nonprod overlays) | Platform observability + LMS platform team |
| VPS-only observability runtime | `vps/infrastructure/observability/` | VPS infrastructure team |
| Legacy observability workspace | `/home/gurpreet/projects/observability` (deprecated; historical reference only) | n/a |

## Change Process

1. Update monitoring templates in this repo (`infrastructure/monitoring/`).
2. Run local guardrails:
   - `./scripts/qa/audit-observability.sh --mode local`
   - `OFFLINE_PLAN=1 ./scripts/infra/apply-monitoring-configs.sh plan`
3. Merge to `main`.
4. Apply to GCP Monitoring:
   - `./scripts/infra/apply-monitoring-configs.sh apply`
5. Verify deployed coverage:
  - `OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_NONPROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
   - `./scripts/qa/audit-db-exporter-telemetry.sh --mode local`
   - Post-rollout deep validation: `STRICT_RUNTIME=1 ./scripts/qa/audit-db-exporter-telemetry.sh --mode runtime`
  - For release gates / deep audits: `OBSERVABILITY_ENV_LABEL=prod OBSERVABILITY_DISPATCH_PROFILE=prod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_PROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
   - For Velero pipeline gate: `STRICT_RUNTIME=1 ./scripts/qa/audit-velero-alert-pipeline.sh --json`
   - For routing gate: `./scripts/qa/verify-alert-routing.sh`
   - For Atlas modulestore path gate: `./scripts/qa/verify-atlas-modulestore-path.sh --mode all`
   - For Atlas monitor posture (VPS): `./scripts/qa/audit-atlas-allowlist-monitor.sh` (and `STRICT_WEBHOOK=1` for production-ready routing)
6. Run consolidated release gate:
   - `./scripts/qa/run-operations-gates.sh --env both`
   - After exporter rollout, enforce runtime exporter checks in the same gate:
     `DB_EXPORTER_AUDIT_MODE=runtime CHECK_TIMEOUT_SECONDS=1200 ./scripts/qa/run-operations-gates.sh --env prod`
7. Build DR evidence artifact (monthly / major changes):
   - `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
8. If panel parity is needed in platform Grafana or runtime overlays, update `infrastructure` in the same change window and link both PRs.
9. If a change is VPS-only (non-GKE), update `vps/infrastructure/observability/` and include a scope note in evidence.

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

## Alert Rule Ownership and Change Control

- For any change to critical or high-severity alert rules, the owning service lead must acknowledge planned behavior in review before merge.
- A release cannot close if a critical alert rule change lacks:
  - owner name
  - expected impact summary
  - rollback condition
  - validation command and evidence result
- If multiple services share the same alert rule file, each affected service owner must add a comment with acceptance in the PR.
- Use `docs/policies/operations/OBSERVABILITY_OWNERSHIP.md` as the canonical owner source and keep owners aligned with `ALERT_TUNING_SOP.md` runtime priorities.

Minimum approval evidence for each high-severity rule change:
- PR comment with explicit owner consent in the change ticket/issue.
- `./scripts/qa/verify-alert-routing.sh` result proving route still lands in the correct channel.
- Update log in release evidence bundle and include in incident postmortem if the change causes detection behavior change.
