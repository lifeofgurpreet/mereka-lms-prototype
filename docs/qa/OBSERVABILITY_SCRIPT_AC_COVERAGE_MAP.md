# Observability Script AC Coverage Map (Mereka LMS)

Date: 2026-02-25

## Scope

- Purpose: map observability validation scripts and parity tooling to spec-level acceptance criteria (ACs).
- Source contracts:
  - `specs/observability-validation-requirements_spec.md`
  - `docs/operations/OBSERVABILITY_PARITY_MATRIX.md`
  - `docs/operations/OBSERVABILITY_PARITY_WORKFLOW_SETUP.md`

## Script Coverage

| Script | Covered AC IDs | Contract target |
|---|---|---|
| `scripts/qa/validate-observability-compliance.sh` | AC-OVR-024, AC-OVR-025, AC-OVR-026, AC-OVR-027, AC-OVR-030, AC-OVR-031 | Repository/runtime observability compliance checks, local/runtime mode outputs, strict fail-on-missing checks, schema-valid output and alert rule checks |
| `scripts/qa/verify-observability-runtime.sh` | AC-OVR-016, AC-OVR-018, AC-OVR-019, AC-OVR-020, AC-OVR-021, AC-OVR-023, AC-OVR-025, AC-OVR-026, AC-OVR-027, AC-OVR-028, AC-OVR-029, AC-OVR-031 | Live observability validation for endpoints, GCP surface checks, Prometheus/Grafana runtime evidence, and runtime wiring visibility (targets + rules) |
| `scripts/qa/verify-observability-contracts.sh` | AC-001, AC-002, AC-004, AC-005, AC-006, AC-008 | Repository/runtime contract checks for core monitors, alerts, dashboards, and tracing readiness/docs presence |
| `scripts/qa/audit-observability.sh` | AC-OVR-018, AC-OVR-019, AC-OVR-020, AC-OVR-021, AC-005 | Repo + runtime parity for uptime checks, alert policies, log metrics and dashboard declarations |
| `scripts/qa/audit-grafana-dashboard.sh` | AC-OVR-022, AC-OVR-023 | Grafana contract and dashboard coverage |
| `scripts/qa/audit-db-exporter-telemetry.sh` | AC-OVR-002, AC-OVR-006, AC-OVR-012, AC-OVR-013, AC-OVR-014, AC-OVR-015 | DB exporter + ServiceMonitor + recording rule telemetry coverage |
| `scripts/qa/build-observability-parity-delta.sh` | AC-OVR-024, AC-OVR-025, AC-OVR-026 | Generates parity delta artifacts and fails on evidence identity/profile mismatch or missing artifacts |
| `scripts/qa/build-observability-parity-review.sh` | AC-OVR-024, AC-OVR-025 | Generates weekly parity review notes from parity delta JSON and identifies top failed checks |
| `scripts/qa/build-observability-parity-rollup.sh` | AC-OVR-024, AC-OVR-025, AC-OVR-026 | Aggregates all environment parity deltas into release-ready rollup with optional no-skip enforcement |
| `scripts/qa/run-observability-first-class.sh` | AC-005, AC-007, AC-LOG-001, AC-LOG-002, AC-LOG-003, AC-LOG-004, AC-LOG-005, AC-LOG-006, AC-LOG-007, AC-LOG-008, AC-OVR-024, AC-OVR-027, AC-OVR-028, AC-OVR-029 | Produces canonical parity evidence in runtime mode and supports strict enforcement workflows |
| `scripts/qa/verify-observability-tracing.sh` | AC-005, AC-007 | Pilot tracing scope checks, Tempo manifest/runtime presence, readiness probing, and env-level trace context propagation contract checks |
| `scripts/qa/build-observability-tracing-pilot-bundle.sh` | AC-005, AC-007, AC-LOG-001, AC-LOG-002, AC-LOG-004, AC-LOG-005, AC-LOG-007, AC-LOG-008 | Builds trace-pilot evidence bundles in `docs/evidence/observability` with copied run outputs, route capture, and optional tempo query proof |
| `scripts/qa/verify-logging-pipeline.sh` | AC-LOG-001, AC-LOG-002, AC-LOG-003, AC-LOG-004, AC-LOG-005, AC-LOG-006, AC-LOG-007, AC-LOG-008 | Aggregate runbook for logging checks that gates tracing and contract runbook evidence |
| `scripts/qa/verify-observability-evidence-identity.sh` | AC-OVR-005, AC-OVR-006, AC-OVR-026 | Ensures identity fields and evidence hashes remain stable across generated artifacts |
| `scripts/qa/verify-observability-structured-logging.sh` | AC-LOG-004 | LMS/CMS and worker logs must include structured fields (`timestamp`, `level`, `service`, `message`) and include correlation fields on configured severity levels |
| `scripts/qa/verify-correlation-header-propagation.sh` | AC-007 | Caddy ingress forwards `X-Request-ID` and `traceparent` to backends |
| `scripts/qa/test-verify-correlation-header-propagation.sh` | AC-007 | Unit-like script contract tests for positive/negative correlation-header scenarios, including import-order variations |

## Contract Mapping Notes

- Any environment-level evidence artifact must include `identity`-aligned metadata and survive copy into parity review/rollup stages.
- `AC-OVR-028` and `AC-OVR-029` are only enforceable in CI via workflow-level integration.
- New parity contract scripts are treated as mandatory support checks where strict deployment gates are enabled in:
  - `.github/workflows/observability-compliance.yml`
  - `.github/workflows/operations-gates-runtime.yml`

## Evidence Artifacts

- `docs/operations/OBSERVABILITY_ARTIFACT_RETENTION_MATRIX.md`
- `scripts/qa/test-observability-parity-contracts.sh`
- `docs/qa/OBSERVABILITY_CANONICAL_INDEX.md`
