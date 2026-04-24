# Observability First-Class Evidence Index Hardening (2026-02-27)

## Objective

Ensure runtime first-class runs persist and validate the full set of per-component wiring artifacts in the evidence index, so closure checks can verify that all expected targets/rules evidence artifacts exist in one deterministic payload.

## Scope and changes

- Updated `scripts/qa/run-observability-first-class.sh` to include all runtime wiring evidence artifacts in `observability-first-class-*-evidence-index.json`:
  - `observability-lms-prometheus-wiring-runtime.md`
  - `observability-cms-prometheus-wiring-runtime.md`
  - `observability-caddy-prometheus-wiring-runtime.md`
  - `observability-mfe-prometheus-wiring-runtime.md`
  - `observability-forum-prometheus-wiring-runtime.md`
  - `observability-discovery-prometheus-wiring-runtime.md`
  - `observability-ecommerce-prometheus-wiring-runtime.md`
  - `observability-credentials-prometheus-wiring-runtime.md`
  - `observability-purchase-gateway-prometheus-wiring-runtime.md`
  - `observability-slo-rules-prometheus-wiring-runtime.md`
  - `observability-video-rules-prometheus-wiring-runtime.md`
  - `observability-ora2-rules-prometheus-wiring-runtime.md`
  - `observability-dev-xqueue-prometheus-wiring-runtime.md`
  - `observability-dev-mux-prometheus-wiring-runtime.md` (lane-gated for dev/kind lanes)

## Evidence produced

- `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md` execution state updated by this lane to reflect first-class index hardening as part of `OBS-EXT-069` execution.
- Script syntax check: `bash -n scripts/qa/run-observability-first-class.sh`

## Closure criteria

- The script executes without shell syntax errors.
- `var/ci/observability-first-class-runtime-evidence-index.json` includes the full per-component runtime wiring artifact set.
- `scripts/qa/observability` runtime gate consumers (e.g., `.github/workflows/observability-compliance.yml`) can validate indexed file presence without additional manual file-list maintenance.
