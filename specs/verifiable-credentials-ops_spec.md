---
title: 'CRED-050: Ops & Reliability'
type: feature_spec
status: approved
owner: engineering
vehicle: talent_platform
last_updated: '2026-02-14'
version: 1.0.0
depends_on:
- specs/verifiable-credentials-types_spec.md
- specs/verifiable-credentials-issuer_spec.md
- specs/verifiable-credentials-issuance_spec.md
- specs/verifiable-credentials-verification_spec.md
links:
  related_specs:
  - specs/cross-cutting-requirements_spec.md
  - specs/slo-sla-service-level-management_spec.md
  - specs/observability-stack_spec.md
id: SPEC-VC-OPS-001
spec_class: integration
created: '2026-02-10'
last_reviewed: '2026-03-09'
review_due: '2026-06-09'
domain: auth
normativity: normative
supersedes: []
superseded_by: null
verification_sources: []
interfaces:
- ops:credentials
- runbook:credentialing
tags:
- auth.verifiable-credentials
- auth.operations
- platform.credentials
summary: Defines the normative operational contract for running, monitoring, troubleshooting,
  and recovering the verifiable credentials subsystem.
---

## What we're building

The operational layer that keeps the Verifiable Credentials system
observable, reliable, and recoverable. This covers Prometheus metrics,
alerting rules, SLOs, operational runbooks, and the credential
backfill and repair tooling.

## Scope

Prometheus metrics export, `PrometheusRule` alerting, SLO definitions,
Grafana dashboards, operational runbooks, backfill management commands,
health checks, logging, and credential data retention policy.

## Non-goals

- Real-time streaming analytics (deferred)
- Multi-region credential replication
- External SIEM integration (out of scope for v1)
- Automated credential audit trails beyond standard logging

## Requirements

### Prometheus Metrics

The Credentials Service MUST expose the following metrics at `/metrics`
via `django-prometheus`:

- `credentials_vc_issued_total`
  - Type: Counter
  - Labels: `type`, `tenant`
  - Description: Total VCs issued
- `credentials_vc_issuance_duration_seconds`
  - Type: Histogram
  - Labels: `type`
  - Description: Time from event to stored VC
- `credentials_vc_claim_tokens_generated_total`
  - Type: Counter
  - Labels: `tenant`
  - Description: Claim tokens created
- `credentials_vc_claim_tokens_redeemed_total`
  - Type: Counter
  - Labels: `tenant`
  - Description: Claim tokens successfully used
- `credentials_vc_claim_tokens_expired_total`
  - Type: Counter
  - Labels: `tenant`
  - Description: Claim tokens expired unused
- `credentials_vc_verification_requests_total`
  - Type: Counter
  - Labels: `result`
  - Description: Verification requests, pass or fail
- `credentials_vc_verification_duration_seconds`
  - Type: Histogram
  - Labels: none
  - Description: Verification latency
- `credentials_vc_signing_errors_total`
  - Type: Counter
  - Labels: `error_type`
  - Description: Signing failures
- `credentials_did_document_requests_total`
  - Type: Counter
  - Labels: `status`
  - Description: DID Document fetch results
- `credentials_vc_linkedin_shares_total`
  - Type: Counter
  - Labels: `tenant`
  - Description: LinkedIn share clicks

### Alerting Rules (PrometheusRule)

The following alerts MUST be configured:

- `VCIssuanceLatencyHigh`
  - Condition: `credentials_vc_issuance_duration_seconds` p95 > 30s
  - Severity: warning
  - For: 5m
- `VCIssuanceFailureSpike`
  - Condition: `credentials_vc_signing_errors_total` rate > 0.1/s
  - Severity: critical
  - For: 2m
- `VCClaimTokenExpiryHigh`
  - Condition: expired to generated ratio > 50% over 1h
  - Severity: warning
  - For: 15m
- `VCVerificationEndpointDown`
  - Condition: Verification endpoint returns 5xx for more than 2m
  - Severity: critical
  - For: 2m
- `VCDIDDocumentUnavailable`
  - Condition: DID Document endpoint returns non-200 for more than 5m
  - Severity: critical
  - For: 5m
- `VCSigningKeyExpiringSoon`
  - Condition: Signing key age > 350 days, manual rotation reminder
  - Severity: warning
  - For: 1h

### SLOs

| SLO | Target | Window |
| --- | ------ | ------ |
| VC issuance success rate | 99.5% | 30 days |
| VC issuance p95 latency | <= 30 seconds | 30 days |
| Verification endpoint availability | 99.9% | 30 days |
| Verification p95 latency | <= 2 seconds | 30 days |
| DID Document endpoint availability | 99.9% | 30 days |
| Claim token redemption success rate | 95% (of generated tokens) | 30 days |

### Grafana Dashboard

A Grafana dashboard MUST be created with the following panels:

1. **Issuance Overview**: VCs issued over time by type and tenant
2. **Issuance Latency**: p50, p95, p99 issuance duration
3. **Claim Flow**: Token generation vs redemption vs expiry rates
4. **Verification**: Request rate, pass/fail ratio, latency
5. **DID Document**: Request rate, cache hit ratio
6. **Signing Health**: Error rate, key age indicator
7. **LinkedIn Shares**: Share click rate by tenant

### Operational Runbooks

The following runbooks MUST be created in `docs/operations/`:

- `credential-key-rotation-runbook.md`
  - Name: Key Rotation
  - Covers: Generate a new keypair, update the DID Document, update the
    K8s secret, and verify old credentials still validate
- `credential-issuance-failure-runbook.md`
  - Name: Issuance Failure
  - Covers: Diagnose signing errors, check key availability, and verify the
    event pipeline
- `credential-backfill-runbook.md`
  - Name: Backfill Credentials
  - Covers: Issue VCs for learners who completed before the VC feature was
    enabled
- `credential-verification-failure-runbook.md`
  - Name: Verification Failure
  - Covers: Diagnose DID Document issues, cache problems, and key lookup
    failures

### Backfill Management Command

- A Django management command `backfill_credentials` MUST exist in the
  Credentials Service
- It MUST accept `--course-id`, `--program-uuid`, `--tenant-uuid`, and
  `--dry-run`
- It MUST skip learners who already have a VC for the same achievement
  so the command remains idempotent
- It MUST log each credential created with the learner ID and credential
  UUID
- It MUST respect rate limits, configurable and defaulting to
  10 credentials per second

### Health Checks

- The Credentials Service MUST expose a `/health/` endpoint that already
  exists
- The health check MUST verify database connectivity, Redis
  connectivity, and signing key availability
- If the signing key is missing, health MUST return `503` with
  `"signing_key": "unavailable"`
- The Kubernetes liveness probe MUST use `/health/`
- The Kubernetes readiness probe MUST verify signing key availability

### Logging

- All VC issuance events MUST be logged with credential UUID, learner ID
  anonymized, tenant UUID, event type, and timestamp
- All verification requests MUST be logged with credential UUID, result,
  client IP hashed, and checks performed
- All signing errors MUST be logged at ERROR level with full stack trace
- Log format MUST be structured JSON, consistent with the platform-wide
  logging spec

### Credential Data Retention

- Signed VCs MUST be retained in the database indefinitely because they
  are the learner's proof
- Claim tokens MUST be cleaned up after 24 hours regardless of use
- Verification request logs MUST be retained for 90 days
- A periodic cleanup job MUST remove expired claim tokens daily

---

## Acceptance Criteria

- [ ] AC-CRED-040: Given the Credentials Service is running, when
      `/metrics` is scraped, then all 10 VC-related metrics are present
      with correct types
- [ ] AC-CRED-041: Given VC issuance p95 latency exceeds 30 seconds for
      five minutes, when Prometheus evaluates rules, then
      `VCIssuanceLatencyHigh` fires
- [ ] AC-CRED-042: Given the signing key is missing from the
      environment, when the health endpoint is called, then HTTP 503 is
      returned with `"signing_key": "unavailable"`
- [ ] AC-CRED-043: Given learners completed a course before VC was
      enabled, when `backfill_credentials --course-id=... --dry-run` is
      run, then it reports how many VCs would be created without
      creating any
- [ ] AC-CRED-044: Given the backfill command is run twice for the same
      course, when the second run executes, then zero new VCs are
      created and the command remains idempotent
- [ ] AC-CRED-045: Given a VC is issued, when the application log is
      inspected, then a structured JSON entry exists with credential
      UUID, learner ID, tenant UUID, and timestamp
- [ ] AC-CRED-046: Given expired claim tokens exist in the database,
      when the daily cleanup job runs, then tokens older than 24 hours
      are deleted
- [ ] AC-CRED-047: Given the Grafana dashboard is loaded, then seven
      panels are visible covering issuance, latency, claims,
      verification, DID, signing health, and LinkedIn shares
- [ ] AC-CRED-048: Given key rotation runbook
      `docs/ops/runbooks/credential-key-rotation-runbook.md`, when
      followed step by step, then old credentials verify successfully
      and new credentials use the new key

---

## Edge Cases

- **Metrics endpoint adds latency to requests**: Use
  `django-prometheus` middleware, already integrated. Metrics are
  collected passively, not per request.
- **Backfill during peak hours**: The `--rate-limit` flag prevents
  overwhelming the signing service. The default of 10 per second is
  conservative.
- **Signing key rotated but old key removed from DID Document**:
  CRED-020 requires old keys to remain for five years.
  `VCSigningKeyExpiringSoon` is a reminder, not an automatic rotation
  trigger.
- **Claim token cleanup removes tokens mid-redemption**: The 24-hour
  window is generous because tokens expire after 10 minutes, so no race
  condition should exist.
- **Health check passes but signing fails**: The health check verifies
  key presence, not signing capability. If signing fails,
  `VCIssuanceFailureSpike` catches it.

---

## Monorepo Location

- PrometheusRule:
  `deploy/k8s/base/monitoring/prometheusrule-credentials.yaml`
- Grafana dashboard:
  `deploy/k8s/base/monitoring/dashboards/credentials-vc.json`
- Backfill command:
  Credentials Service (Django management command)
- Runbooks:
  `docs/operations/credential-*-runbook.md`
- Cleanup job:
  Credentials Service (Django management command or Celery beat)
