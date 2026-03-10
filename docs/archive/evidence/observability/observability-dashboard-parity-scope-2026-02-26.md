# Observability Dashboard Parity Scope Evidence

Date: 2026-02-26
Lane: planning + non-prod/runtime parity hardening
Owner: mereka-lms observability

## Scope executed
- Hardened parity model to distinguish GCP-native dashboard drift from Grafana-only exports.
- Added explicit opt-in flag for Grafana-only dashboard parity participation.
- Updated parity workflow docs and matrix with dashboard scope semantics.
- Updated monitoring directory guidance to document mixed dashboard artifact responsibilities.

## Artifact changes
- `scripts/qa/audit-observability.sh`
  - Added `OBSERVABILITY_INCLUDE_GRAFANA_DASHBOARDS` guard.
  - Added `is_grafana_only_dashboard_artifact()` with explicit exclusions for:
    - `video-cost.json`
    - `video-operations.json`
  - Dashboard required set now skips these by default during parity checks.
- `docs/ops/runbooks/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md`
  - Added dashboard parity scope behavior + remediation command block (`apply-monitoring-configs.sh plan/apply`).
- `docs/reference/operations/OBSERVABILITY_PARITY_MATRIX.md`
  - Added dashboard scope requirement entry.
- `infrastructure/monitoring/README.md`
  - Documented mixed folder semantics and explicit GCP-vs-Grafana split.
- `docs/ops/runbooks/OBSERVABILITY_QUICKSTART.md`
  - Added dashboard-remediation quick command and temporary Grafana-only opt-in guidance.
- `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`
  - Marked `OBS-052` done after classification documentation.

## Execution notes
- Local script behavior changed only by explicit exclusions and does not mutate runtime object state.
- No deployment action executed in this iteration.
- `OBS-051` is now closed by observed runtime check behavior (script false-positive resolved and
  parity check green in non-strict runtime).
- Remaining open dependency: lane-by-lane verification still pending for all non-local environments and should be validated by the standard parity runbook.

## Next action
- Execute remediation from parity lane when missing dashboard is confirmed:
  - `./scripts/infra/apply-monitoring-configs.sh plan`
  - `./scripts/infra/apply-monitoring-configs.sh apply`
