---
title: Cross-Cutting Requirements Test Plan
spec: cross-cutting-requirements_spec.md
last_updated: '2026-02-13'
plan: cross-cutting-requirements_plan.md
status: draft
---

# Cross-Cutting Requirements Test Plan

## Test Strategy

This test plan covers platform-wide requirements that apply to all services: tenant isolation, observability (metrics, logs, traces, dashboards, alerts), secrets management, common NFR thresholds, error handling, and feature flag management. Tests are organized to verify compliance across the entire Mereka Academy platform.

## Test Matrix

| AC ID | Description | Method | Priority | Automation |
|-------|-------------|--------|----------|------------|
| AC-CCR-001 | Tenant A API response contains zero tenant B records | integration | P0 | automated |
| AC-CCR-002 | All services expose /metrics endpoint | integration | P0 | automated |
| AC-CCR-003 | All service logs are structured JSON with required fields | integration | P0 | automated |
| AC-CCR-004 | All secrets read from environment variables (not hardcoded) | unit | P0 | automated |
| AC-CCR-005 | Pre-commit hook rejects hardcoded secret patterns | manual | P0 | manual |
| AC-CCR-006 | API p95 latency < 500ms, availability >= 99.9% over 30 days | monitoring | P0 | automated |
| AC-CCR-007 | Tenant offboarding produces cryptographic deletion certificate | manual | P1 | manual |
| AC-CCR-008 | All external traffic uses TLS 1.2+ | integration | P0 | automated |
| AC-CCR-009 | All K8s manifests include resource requests, limits, probes | manual | P0 | manual |
| AC-CCR-010 | Financial write operations are idempotent | integration | P0 | automated |
| AC-CCR-011 | Background job failures logged with full context | integration | P0 | automated |
| AC-CCR-012 | Redis Streams event consumers implement deduplication | integration | P0 | automated |

## Unit Tests

- Tenant-scoped queryset filter application (Django ORM .filter(enterprise_customer_uuid=...))
- Tenant context extraction from JWT token
- Structured log entry construction (timestamp, level, service, request_id, tenant_id)
- Secret access via os.environ.get() pattern (Python)
- Environment variable fallback behavior (required vs optional secrets)
- TLS version negotiation logic (reject TLS < 1.2)
- Resource request/limit validation (K8s manifest schema)
- Idempotency key generation (UUID, timestamp, content hash)
- Deduplication cache lookup (Redis GET by event ID)
- Error response construction (machine-readable error code + human message)
- PII scrubbing in log messages (email → hash, name → redacted)
- Prometheus metric label validation (service, tenant_id, environment)
- Feature flag evaluation (Waffle flag override logic)
- CORS header generation (Access-Control-Allow-Origin)

## Integration Tests

- Tenant isolation verification: tenant A admin calls API → only tenant A data returned
- Cross-tenant access denial: tenant B admin calls tenant A API → HTTP 403
- Prometheus metrics scraping: /metrics endpoint returns Prometheus-format metrics
- Structured log ingestion: logs contain timestamp, level, service, request_id, tenant_id fields
- Secret injection: K8s pod env vars populated from ExternalSecrets
- ExternalSecrets sync: Infisical → GCP SM → K8s Secret → pod env vars
- TLS handshake: external traffic negotiates TLS 1.2 or higher
- Health check endpoints: /healthz (liveness), /readyz (readiness) return HTTP 200
- Graceful shutdown: SIGTERM → 30-second drain period → clean termination
- Database connection pooling: verify pool size configuration, connection reuse
- Circuit breaker activation: external dependency fails → circuit opens → fallback logic
- Rate limiting: per-IP bucket (100 req/min), per-account bucket (1000 req/min)
- Idempotent write operations: duplicate payment processed → same result (no double charge)
- Background job retry: job fails → logged → retried with exponential backoff
- Redis Streams event deduplication: duplicate event ID → skipped (no double processing)
- Audit trail generation: all auth events logged with correlation ID
- Tenant offboarding data export: all tenant data exported to GCS
- Tenant offboarding deletion: all tenant data deleted from all data stores
- Feature flag hot toggle: Waffle flag changed → takes effect immediately (no restart)
- Feature flag rolling update: mixed flag states during deployment → no errors

## E2E Tests

- End-to-end tenant isolation: tenant A admin creates resource → tenant B admin cannot access → tenant A learner sees resource
- Observability stack: service emits metrics → Prometheus scrapes → Grafana dashboard displays → alert fires on threshold breach
- Secrets rotation: secret rotated in Infisical → ExternalSecrets syncs → pod env vars updated → service continues operating
- Tenant offboarding: offboarding initiated → data exported → deletion certificate generated → all data verifiable deleted
- Multi-service error propagation: service A fails → circuit breaker opens → service B returns fallback response (not 500)
- Background job lifecycle: job enqueued → processed → fails → logged → retried → succeeds
- Feature flag gradual rollout: flag enabled for tenant A → only tenant A sees feature → flag enabled globally → all tenants see feature

## Manual Verification

- Pre-commit hook installation verification (git config --local include.path ../.gitconfig)
- Pre-commit hook secret scanning test (attempt to commit hardcoded secret → blocked)
- K8s manifest resource requests/limits audit (all deployments have requests, limits)
- K8s manifest probe audit (all deployments have liveness, readiness probes)
- TLS certificate validity (Let's Encrypt, not Cloudflare Universal SSL)
- Grafana dashboard rendering (all platform dashboards load without errors)
- Alert routing configuration (critical → PagerDuty, warning → Slack #ops-warnings)
- Tenant offboarding deletion certificate inspection (cryptographic signature, data store list)
- Feature flag registry completeness (all specs document their flags)
- Technology decision registry (Event bus = Redis Streams, Relational DB = MySQL 8, etc.)
- OWASP Top 10 compliance checklist (for each new service)
- Session cookie flags (Secure, HttpOnly, SameSite)
- CSRF protection (all state-changing endpoints)
- Input validation (API boundary validation for all user input)

## Monitoring Verification

- Alert fires when any service lacks /metrics endpoint for >1 hour
- Alert fires when tenant isolation test suite reports failure
- Alert fires when secret scanning CI check fails on main branch
- Alert fires when service availability drops below 99.9% over 30 days
- Alert fires when API p95 latency exceeds 500ms for 10 minutes
- Alert fires when pod restart count exceeds 3 in 15 minutes
- Alert fires when error rate exceeds 5% for 5 minutes
- Grafana dashboard "Platform Compliance" displays per-service adherence to cross-cutting requirements
- Grafana dashboard "Tenant Isolation Test Results" displays test success/failure rate
- Prometheus metric cross_cutting_compliance_score = 100% (all services compliant)
- Prometheus metric tenant_isolation_test_failures = 0 (no failures)
- Prometheus metric secret_scan_violations = 0 (no hardcoded secrets detected in CI)
- Loki log retention: 30 days hot, 90 days cold (GCS archive)
- Tempo trace retention: 7 days
- Prometheus metric retention: 15 days
- Alert routing: critical alerts to #ops-alerts Slack channel
- Alert routing: warning alerts to #ops-warnings Slack channel
- PagerDuty integration for critical alerts (oncall escalation)
- Grafana dashboard access control (tenant-filtered views for enterprise admins)
