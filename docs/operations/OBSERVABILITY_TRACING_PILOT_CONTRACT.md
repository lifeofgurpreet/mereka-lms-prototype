# Observability Tracing Pilot Contract (Non-Prod)

_Last updated: 2026-02-25_

## Scope

Pilot tracing scope for `mereka-lms` is explicitly limited to non-production (`nonprod`) and a
single Tier-1 request class. This is a temporary operational contract to prove trace-log correlation
before broader roll-out.

## Pilot Flow Definition

Contracted request path for initial evidence:

- ingress → Caddy reverse proxy → `lms` (authn/login) → `cms`/`discovery` (session-aware downstream path)

For implementation, the following canonical route is used by the team runbook:

- `POST /api/user/v1/account/login_session/` via apps/auth surfaces

This route must be executable as a synthetic canary and a human can reproduce it in UI flow.

## Trace Backend Contract

- Backend service: Tempo
- Non-production target host: `tempo.mereka.dev` (API endpoint contract)
- OTLP endpoint contract: `https://tempo.mereka.dev:3200` or validated in-cluster `tempo` service endpoint
- OTLP ingest path: `/v1/traces` (HTTP)
- Probe path: `/ready`
- Required headers at ingress boundary: `traceparent`, `tracestate` (optional), `X-Request-ID`

If the endpoint changes, update this document and the following env/command inputs together.

## Sampling and Retention (Pilot)

- Sampling mode: `0.10` (10%) for all pilot-included workloads
- Minimum retention contract: 7 days for pilot traces
- Rollout freeze rule: trace rollout does not expand to additional services until two stable runs
  complete with correlation evidence

## Required Evidence for Pilot Closure (OBS-025)

1. One complete, non-prod flow that emits a single trace ID visible in Tempo UI/API.
2. Matching request correlation evidence with `X-Request-ID` and `traceparent` observed at:
   - ingress layer
   - LMS/CMS app boundary
3. Log proof in matching namespace with equivalent request/trace metadata.
4. Evidence directory and manifest hash present in `docs/evidence/observability/`.

## Operational Inputs (Script-facing)

Set these environment variables when executing observability tracing checks:

- `APP_NS` (default: `mereka-lms`)
- `K8S_CONTEXT` (runtime context)
- `TEMPO_URL` (full HTTP URL to tempo `/ready` endpoint)
- `OBSERVABILITY_EVIDENCE_DIR` (for `run-observability-first-class.sh`)

## Escalation

If Tempo returns missing traces, duplicate context IDs, or header drift, stop expansion and open a
tracking item with explicit findings from:

- `observability-tracing-runtime.txt`
- `observability-correlation-headers-runtime.txt`
- `observability-logging-pipeline-runtime.txt`

