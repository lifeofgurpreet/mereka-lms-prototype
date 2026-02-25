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
| `scripts/qa/audit-observability.sh` | AC-OVR-018, AC-OVR-019, AC-OVR-020, AC-OVR-021 | Repo + runtime parity for uptime checks, alert policies, log metrics and dashboard declarations |
| `scripts/qa/audit-grafana-dashboard.sh` | AC-OVR-022, AC-OVR-023 | Grafana contract and dashboard coverage |
| `scripts/qa/audit-db-exporter-telemetry.sh` | AC-OVR-002, AC-OVR-006, AC-OVR-012, AC-OVR-013, AC-OVR-014, AC-OVR-015 | DB exporter + ServiceMonitor + recording rule telemetry coverage |
| `scripts/qa/build-observability-parity-delta.sh` | AC-OVR-024, AC-OVR-025, AC-OVR-026 | Generates parity delta artifacts and fails on evidence identity/profile mismatch or missing artifacts |
| `scripts/qa/build-observability-parity-review.sh` | AC-OVR-024, AC-OVR-025 | Generates weekly parity review notes from parity delta JSON and identifies top failed checks |
| `scripts/qa/build-observability-parity-rollup.sh` | AC-OVR-024, AC-OVR-025, AC-OVR-026 | Aggregates all environment parity deltas into release-ready rollup with optional no-skip enforcement |
| `scripts/qa/run-observability-first-class.sh` | AC-OVR-024, AC-OVR-027, AC-OVR-028, AC-OVR-029 | Produces canonical parity evidence in runtime mode and supports strict enforcement workflows |
| `scripts/qa/verify-observability-evidence-identity.sh` | AC-OVR-005, AC-OVR-006, AC-OVR-026 | Ensures identity fields and evidence hashes remain stable across generated artifacts |
| `scripts/qa/verify-observability-structured-logging.sh` | AC-LOG-004 | LMS/CMS logs must include required structured fields (`timestamp`, `level`, `service`, `message`) |
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
