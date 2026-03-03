# Observability GA Readiness Gate

Last updated: 2026-03-03

## Purpose

This document defines the hard release gate for promoting observability to GA-level confidence for Mereka LMS.

## Scope

- Observability controls for local/dev parity, `rke2-nonprod`, and production
- Runtime telemetry coverage (Prometheus/Alerting/ Grafana/Velero/Synthetics)
- Incident response readiness for monitoring misses

## Gate Decision

Decision options are based on objective evidence only:

- `GO` — all criteria pass and evidence links are complete.
- `NO-GO` — one or more mandatory criteria fail.

## Current Decision Snapshot (2026-03-03)

- Decision: `NO-GO`
- Reviewer: Codex execution lane (automated + manual artifact review)
- Evidence root:
  - `var/ci/parity-dev`
  - `var/ci/parity-nonprod`
  - `var/ci/parity-prod`
  - `docs/evidence/observability/pilot-nonprod-20260303-040914`

### Lane results

| Lane | Result | Primary blockers |
|---|---|---|
| `dev` (`rke2-staging`) | FAIL | `AC-OVR-016` (`LMS/CMS /metrics` return `404`), coverage/runtime/logging strict failures |
| `nonprod` (`rke2-nonprod`) | FAIL | `AC-OVR-016` (`LMS/CMS /metrics` return `404`), coverage/runtime/logging strict failures |
| `prod` (`gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`) | PASS | all six strict runtime first-class steps pass (`observability-compliance`, `coverage`, `runtime`, `correlation`, `logging`, `tracing`) |

### Current blockers summary

- Cross-lane parity gate remains blocked by nonprod/dev runtime conditions:
  - `LMS/CMS /metrics` return `404` in both lanes.
  - `openedx-settings-lms-patched` in both lanes lacks expected prometheus wiring markers at runtime.
  - logging strict mode fails on `AC-LOG-002` because Loki service is absent in both lanes (`SKIP Loki service not found ...` followed by strict fail).
- Production strict lane is green and no longer blocks GA on its own.

### Tracing pilot status

- Strict nonprod tracing pilot command timed out with exit `124`:
  - `./scripts/qa/build-observability-tracing-pilot-bundle.sh --env nonprod --mode runtime --require-flow-capture --strict`
- Bundle path exists but does not close pilot acceptance:
  - `docs/evidence/observability/pilot-nonprod-20260303-040914`
- `OBS-025` remains open until one end-to-end trace proof is captured with log/header correlation.

## Mandatory Criteria (all required)

### 1) Compliance and identity integrity

- `run-observability-first-class.sh --mode runtime --strict` passes for target env(s), invoked with lane-safe profile/context variables:
  - Nonprod: `OBSERVABILITY_ENV_LABEL=nonprod OBSERVABILITY_DISPATCH_PROFILE=nonprod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_NONPROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
  - Prod: `OBSERVABILITY_ENV_LABEL=prod OBSERVABILITY_DISPATCH_PROFILE=prod OBSERVABILITY_K8S_CONTEXT=$OBS_PARITY_PROD_K8S_CONTEXT ./scripts/qa/run-observability-first-class.sh --mode runtime --strict`
- `verify-observability-evidence-identity.sh` passes for `var/ci`, `var/ci/parity-dev`, `var/ci/parity-nonprod`, and `var/ci/parity-prod`.
- `test-observability-parity-contracts.sh` passes.

### 2) Parity continuity

- `observability-parity-rollup.json` shows `PAR-001` and `PAR-002` in closed state.
- No new `PAR-*` failures introduced without corresponding assigned owner in `docs/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md`.

### 3) Alert and monitoring readiness

- Required PrometheusRule, ServiceMonitor, dashboard and synthetic checks from readiness scripts are loaded and non-stale.
- `verify-alert-routing.sh` and `audit-observability.sh --mode runtime` pass.
- `audit-grafana-dashboard.sh --strict-required` passes for required dashboard contracts.

### 4) Coverage and retention governance

- `build-observability-coverage-matrix.sh --mode runtime` is complete and stored in release evidence.
- Retention artifacts are compliant with `docs/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`.

### 5) Human process readiness

- `docs/operations/ONCALL_OBSERVABILITY_PLAYBOOK.md` drill runbook remains current.
- Monthly operator drill completed (within last 30 days) with attendance artifact in `docs/operations/evidence/observability-drills/`.
- No high-severity alerting change since last review without service-owner ack recorded in PR/evidence.

## Evidence bundle

Minimum release evidence required for `GO`:

- `var/ci/observability-compliance-runtime.json`
- `var/ci/observability-compliance-runtime.md`
- `var/ci/observability-correlation-headers-runtime.txt`
- `var/ci/observability-parity-rollup.json`
- `var/ci/observability-parity-rollup.md`
- `docs/operations/OBSERVABILITY_GA_READINESS_GATE.md` (filled with dates, env list, and reviewer)
- latest operator drill artifact (month window)

## Review artifacts format

Gate reviewers must record:

- reviewer name
- env checked
- timestamp (UTC)
- `GO`/`NO-GO` decision and reason code if blocked
- open items with owners and due dates

## Exit criteria for GA readiness

GA readiness is true only if:

- 2 consecutive release cycles are `GO` with no unresolved observations.
- no unresolved `P1`/`P2` observability issue remains open in `OBSERVABILITY_NEXT50` with status `planned` or `in_progress`.
- runbook and ownership docs are unchanged for 30 days except policy corrections.
