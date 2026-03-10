# ADR-020: Tracing Scope and Pilot Decision for Mereka LMS

**Status**: Accepted
**Date**: 2026-02-25
**Deciders**: Platform Team

## Context

Mereka LMS observability already has metrics, alerting, and log aggregation coverage, but distributed tracing is not yet in steady production-grade coverage for all flows. We need first-class incident diagnostics while avoiding a high-noise, high-complexity rollout.

A broad tracing rollout across every service and environment at once would increase operational risk through:
- higher telemetry dependencies on OTLP across many services,
- Tempo capacity and retention pressure,
- wider correlation contracts that are still not stabilized,
- increased noise and triage complexity during early maturation.

To reduce risk while advancing value, tracing will start as a **Phase 1 pilot** aligned to highest-impact journeys.

## Decision

### Phase 1 Pilot Scope (non-production first)

1. Scope to **Tier-1 learner and creator flows** in non-production environments only:
   - Login/auth path through Caddy ingress into LMS/CMS authentication surfaces,
   - key authenticated API calls in LMS/CMS core workflows,
   - forum/case-support path where auth and course context are exercised.
2. AC-005 (`Tempo receives traces`) is treated as a **pilot requirement** in this phase:
   - we must demonstrate at least one complete nonprod flow end-to-end rather than universal tracing completeness.
3. OTLP/SDK and trace context changes are restricted to the selected pilot services and routes for now.
4. Tempo is treated as a **shared pilot contract** service; not all pods/services must emit traces on day one.
5. No hard alerts are added for global tracing completeness until pilot stability is proven and ownership signs off.

### Sampling and propagation

1. Trace sampling remains low and deterministic initially (1–5%) with optional per-route overrides for high-value paths.
2. Correlation must be explicit (`traceparent`, request/session identifiers) at ingress-to-app boundaries for pilot routes.
3. Correlation evidence is required before any pilot expansion decision (trace IDs and matching log fields).

### Retention

- Tempo retention for pilot traces is 7 days.
- Pilot retention and sampling can change only by a recorded decision after hardening review.

## Consequences

### Positive

- Faster diagnostics for top-impact operational incidents.
- Lower rollout blast radius while validating OTLP, correlation, and Tempo query contracts.
- Concrete evidence-first decision point before wider rollout.

### Negative

- Trace coverage for non-pilot flows is intentionally incomplete during Phase 1.
- Some cross-service journeys remain log-only until Phase 2.
- Additional rollout work remains after Pilot hardening.

## Expansion criteria

Phase 1 expands only when all are met:

1. Non-production trace collection is stable for selected flows for two weeks or more.
2. Evidence artifacts regularly include:
   - `observability-logging-pipeline-*.txt`
   - `observability-tracing-*.txt`
   - `observability-first-class-*-evidence-index.json`
3. Operators validate bidirectional correlation proof between logs and traces for pilot flows.
4. Runbook owners formally accept noise, retention, and operational overhead for expansion.

## Next step

Create and close implementation handoff for `OBS-025` once nonprod pilot trace evidence bundle is available.
