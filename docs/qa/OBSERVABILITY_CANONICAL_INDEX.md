# Observability Canonical Index (Mereka LMS)

Date: 2026-02-25

## Metadata

- last_updated: 2026-02-25
- owner: Mereka LMS platform team
- canonical_workflow: `.github/workflows/observability-compliance.yml`
- canonical_readiness_report: `docs/qa/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md`
- observability_ga_gate: `docs/operations/OBSERVABILITY_GA_READINESS_GATE.md`
- canonical_roadmap: `docs/operations/OBSERVABILITY_ROADMAP_MEREKA_LMS.md`

## Canonical Sources (active)

- Runtime/readiness source of truth:
  - `docs/qa/OBSERVABILITY_FIRST_CLASS_READINESS_REPORT.md`
- Strategy/phase planning source of truth:
  - `docs/operations/OBSERVABILITY_ROADMAP_MEREKA_LMS.md`
  - `docs/operations/OBSERVABILITY_PARITY_MATRIX.md`
  - `docs/qa/OBSERVABILITY_SCRIPT_AC_COVERAGE_MAP.md`
  - `docs/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`
  - `docs/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md`
  - `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`
  - `docs/operations/OBSERVABILITY_GA_READINESS_GATE.md`
  - `docs/qa/OBS-PILOT-TRACING-01.md`
- Execution/gating source of truth:
  - `.github/workflows/observability-compliance.yml`
  - `.github/workflows/daily-infrastructure-audit.yml` (env parity lane; previously `observability-parity-runtime.yml` — merged in Phase 6.4)
- Runtime/local verification scripts:
  - `scripts/qa/validate-observability-compliance.sh`
  - `scripts/qa/build-observability-tracing-pilot-bundle.sh`
  - `scripts/qa/verify-observability-runtime.sh`
  - `scripts/qa/verify-observability-validation.sh`
  - `scripts/qa/run-observability-first-class.sh`
  - `scripts/qa/build-observability-parity-delta.sh`
  - `scripts/qa/build-observability-parity-review.sh`
  - `scripts/qa/build-observability-parity-rollup.sh`
  - `scripts/qa/verify-correlation-header-propagation.sh`
  - `scripts/qa/test-observability-parity-contracts.sh`
  - `scripts/qa/audit-alert-noise-baseline.sh`
  - `scripts/qa/build-alert-noise-runtime-sample.sh`
  - `scripts/qa/verify-observability-evidence-identity.sh`
- Run-time noise operations contract:
  - `docs/operations/ALERT_NOISE_CLASSIFICATION_FEED.md`

## Superseded/Context Docs (historical reference only)

- `docs/qa/OBSERVABILITY_REVIEW_AND_FIRST_CLASS_WORKPLAN_2026-02-25.md`
- `docs/qa/OBSERVABILITY_IMPLEMENTATION_BLUEPRINT_MEREKA_LMS_2026-02-25.md`
- `docs/qa/OBSERVABILITY_TRACKER_ISSUE_SETS_2026-02-25.md`

Use these only for historical context; do not treat them as current execution contract.
