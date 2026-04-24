# OBS-PILOT-TRACING-01: Non-Prod Tracing Pilot Handoff

**Owner:** Observability team  
**Status:** ready_for_implementation  
**Target date:** 2026-03-04  
**Depends on:** `OBS-024` (`docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`)

## Purpose

Close the non-production tracing pilot gap for `AC-005`/`AC-007` by producing repeatable evidence for one canonical Tier-1 flow with explicit trace-log correlation.

## Scope

- Scope is Phase 1 pilot only (non-production lane and explicit Tier-1 flows).
- No global tracing completeness assumptions.
- Do not alter production service monitoring contracts unless explicitly approved in handoff review.

## Acceptance Criteria

- [ ] `docs/programs/observability/TRACING_PILOT_DECISION.md` is the accepted tracing scope contract.
- [ ] `build-observability-tracing-pilot-bundle.sh` writes a nonprod tracing bundle under `docs/archive/evidence/observability/` each run.
- [ ] Nonprod pilot run verifies:
  - Tempo manifests/runtime presence check passes.
  - At least one end-to-end Tier-1 flow emits a valid trace ID.
  - `X-Request-ID`/`traceparent` propagation exists at ingress-to-app boundaries for that flow.
- [ ] `docs/archive/evidence/observability/` contains one pilot evidence bundle with:
  - correlation header proof (`request-id`, `trace-id`, timestamp)
  - a trace path showing ingress → LMS/CMS → downstream service
  - Loki proof using the corresponding request-id/trace-id
- [ ] `AC-LOG-001` through `AC-LOG-008` are recorded as enforced in `observability-logging-pipeline-runtime.txt`.

## Execution steps

1. Finalize `nonprod` pilot route and OTLP sink details in the runbook.
2. Execute:
   - `./scripts/qa/build-observability-tracing-pilot-bundle.sh --env nonprod --mode runtime --require-flow-capture --strict`
3. Store artifacts under `docs/archive/evidence/observability/` and link to tracker row.
4. If pilot fails:
   - open follow-up implementation ticket for missing runtime labels, missing OTEL env vars, or Tempo ingress path.
5. If pilot succeeds twice within 7 days with stable traces:
   - request expansion review for `AC-005` in broader nonprod coverage.

## Ownership split

- **Implementation:** observability/platform engineer
- **Runbook updates:** platform docs owner
- **Validation:** SRE/ops reviewer

## Definition of done

- Pilot evidence passes strict run for nonprod.
- Correlation proof bundle is attached to tracker and reviewed.
- `OBS-025` is moved to done in `docs/qa/OBSERVABILITY_NEXT50_TRACKER_MEREKA_LMS.md`.
