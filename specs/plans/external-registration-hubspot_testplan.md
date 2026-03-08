---
spec: external-registration-hubspot_spec.md
plan: plans/external-registration-hubspot_plan.md
last_updated: "2026-02-10"
---

# Test Plan: External Registration via HubSpot

**Source Spec**: `specs/external-registration-hubspot_spec.md`
**Source Plan**: `specs/plans/external-registration-hubspot_plan.md`

## Test Framework

This spec covers a Node.js microservice deployed to Kubernetes. Testing strategy combines unit tests, integration tests with mocked external APIs, and live verification against deployed service.

| Test Type | Tool | Location Pattern |
|-----------|------|-----------------|
| `unit_test` | Jest or Vitest | `services/hubspot-registration/tests/unit/*.test.js` |
| `integration_test` | Jest or Vitest with mocks | `services/hubspot-registration/tests/integration/*.test.js` |
| `shell_verification` | Bash scripts (`set -euo pipefail`) | `scripts/qa/verify-*.sh`, `scripts/qa/smoke-test-*.sh` |
| `kubectl_check` | kubectl commands (requires cluster access) | Inline commands |
| `manual_verification` | Human-executed checklist | Documented below |

---

## Test Matrix

| AC | Description | Test Type | Test File / Location | Mocks/ Fixtures | Priority |
|----|-------------|-----------|---------------------|------------------|----------|
| AC-HUB-001 | Valid webhook with correct signature returns `200 OK` within 2 seconds | `integration_test` | `tests/integration/test_webhook_receiver.js` | Mock HubSpot signature, timestamp | P1 |
| AC-HUB-002 | Invalid webhook signature returns `401 Unauthorized` and logs failure | `integration_test` + `unit_test` | `tests/integration/test_webhook_receiver.js`, `tests/unit/test_signature.js` | Mock invalid signature | P1 |
| AC-HUB-003 | Unknown form GUID returns `400 Bad Request` and logs unknown form | `integration_test` | `tests/integration/test_webhook_receiver.js` | Mock webhook with unknown form GUID | P1 |
| AC-HUB-004 | Feature flag disabled (`HUBSPOT_REGISTRATION_ENABLED=false`) returns `503 Service Unavailable` | `integration_test` + `shell_verification` | `tests/integration/test_feature_flag.js`, `scripts/qa/smoke-test-hubspot-registration.sh` | Environment variable mock | P1 |
| AC-HUB-005 | Contact profile fetch uses OAuth access token, retries 3 times on 5xx errors | `integration_test` + `unit_test` | `tests/integration/test_hubspot_integration.js`, `tests/unit/test_hubspot_contacts.js` | Mock HubSpot API (5xx responses) | P1 |
| AC-HUB-006 | Expired OAuth token refreshed automatically and request retried | `integration_test` | `tests/integration/test_hubspot_oauth.js` | Mock HubSpot token endpoint | P1 |
| AC-HUB-007 | Multi-select fields (`;` delimited) parsed into arrays | `unit_test` | `tests/unit/test_field_parsing.js` | HubSpot contact fixture with multi-select fields | P1 |
| AC-HUB-008 | Duplicate check calls `GET /api/user/v1/accounts?email={email}` before creation | `integration_test` | `tests/integration/test_user_creation.js` | Mock Open edX API (duplicate response) | P1 |
| AC-HUB-009 | Duplicate email skips creation, logs warning, still sends welcome email | `integration_test` | `tests/integration/test_user_creation.js` | Mock Open edX API (user exists response) | P1 |
| AC-HUB-010 | Username generated with unique format `{email_prefix}_{random_4_digit}` | `unit_test` | `tests/unit/test_username_generation.js` | None (pure function) | P1 |
| AC-HUB-011 | Profile enrichment calls `PATCH /api/user/v1/accounts/{username}` with `hubspot_contact_id` | `integration_test` | `tests/integration/test_profile_enrichment.js` | Mock Open edX profile API | P1 |
| AC-HUB-012 | Welcome email uses correct SendGrid template based on form GUID language | `integration_test` | `tests/integration/test_email_delivery.js` | Mock SendGrid API, form GUID fixture | P1 |
| AC-HUB-013 | Welcome email includes generated password in plaintext | `integration_test` | `tests/integration/test_email_delivery.js` | Mock SendGrid API, verify dynamic data | P1 |
| AC-HUB-014 | Reminder job enqueued with encrypted password, scheduled for 7 days | `integration_test` | `tests/integration/test_reminder_scheduler.js` | Mock Redis, verify AES-256-GCM encryption | P1 |
| AC-HUB-015 | 7-day reminder processor sends email with correct template, marks job completed | `integration_test` | `tests/integration/test_reminder_processor.js` | Mock Redis (due job), mock SendGrid API | P1 |
| AC-HUB-016 | Duplicate webhook (same email within 24h) results in only one user creation | `integration_test` | `tests/integration/test_idempotency.js` | Mock Redis deduplication key | P1 |
| AC-HUB-017 | Deduplication key exists → returns `200 OK` immediately without processing | `integration_test` | `tests/integration/test_idempotency.js` | Mock Redis (key exists) | P1 |
| AC-HUB-018 | User creation failure enqueues webhook to DLQ with full context | `integration_test` | `tests/integration/test_dlq.js` | Mock Open edX API (persistent failure) | P1 |
| AC-HUB-019 | DLQ entry fails 3 retries → error notification email sent to `ops@mereka.dev` | `integration_test` | `tests/integration/test_dlq.js` | Mock Redis DLQ, mock SendGrid API | P1 |
| AC-HUB-020 | Admin API replays DLQ entry successfully and marks completed | `integration_test` | `tests/integration/test_dlq_replay.js` | Mock Redis DLQ, mock Open edX API | P2 |
| AC-HUB-021 | Signature verification failure logs metadata only (no full request body) | `integration_test` + `unit_test` | `tests/integration/test_webhook_receiver.js`, `tests/unit/test_sanitize.js` | Mock invalid signature, verify log output | P1 |
| AC-HUB-022 | Logs never contain plaintext passwords, API keys, or full email addresses | `integration_test` + `shell_verification` | `tests/integration/test_logging.js`, `scripts/qa/verify-hubspot-registration.sh` | Verify log output format | P1 |
| AC-HUB-023 | Container runs as UID 1000, filesystem read-only except `/tmp` | `kubectl_check` + `shell_verification` | `kubectl exec` into pod, `scripts/qa/verify-hubspot-registration.sh` | Requires live K8s pod | P1 |
| AC-HUB-024 | `/metrics` endpoint returns all Prometheus metrics (10 metrics) | `integration_test` + `shell_verification` | `tests/integration/test_metrics.js`, `scripts/qa/smoke-test-hubspot-registration.sh` | Mock prom-client, verify metric names/labels | P1 |
| AC-HUB-025 | Webhook processing emits structured JSON log with all required fields | `integration_test` | `tests/integration/test_logging.js` | Verify log schema: `timestamp`, `level`, `contact_id`, `email_hash`, `duration_ms` | P1 |
| AC-HUB-026 | User creation success rate <95% over 15 min fires critical alert | `manual_verification` | Prometheus Alertmanager UI | Requires Prometheus + Alertmanager deployed | P2 |

---

## Edge Case Tests

| Edge Case | Test Description | Test Type | Location | Priority |
|-----------|-----------------|-----------|----------|----------|
| EC-1: Duplicate Username Collision | Generated username collides with existing user (409 Conflict) → retry with new suffix up to 3 times | `integration_test` | `tests/integration/test_username_collision.js` | P1 |
| EC-2: HubSpot Form Field Schema Changes | HubSpot adds new field or removes field → service handles missing fields with defaults, ignores unknown fields | `unit_test` + `integration_test` | `tests/unit/test_field_parsing.js`, `tests/integration/test_hubspot_integration.js` | P2 |
| EC-3: SendGrid Template Deprecation | SendGrid template ID returns 404 → enqueue to DLQ, send error notification | `integration_test` | `tests/integration/test_email_delivery_failure.js` | P2 |
| EC-4: Redis Unavailability | Redis connection timeout → degrade gracefully (skip deduplication, skip reminder scheduling), log error, emit metric | `integration_test` | `tests/integration/test_redis_failure.js` | P1 |
| EC-5: Open edX API Rate Limiting | Open edX returns 429 Too Many Requests with `Retry-After` header → back off exponentially, retry up to 3 times | `integration_test` | `tests/integration/test_rate_limiting.js` | P1 |
| EC-6: HubSpot Webhook Replay After 24 Hours | HubSpot stops retrying after 24 hours → ops must manually export contacts and replay via admin API | `manual_verification` | Runbook procedure | P3 |
| EC-7: Multi-Language Template Missing | Form submitted in language without template (e.g., Thai) → fall back to English template, log warning | `integration_test` | `tests/integration/test_email_fallback.js` | P2 |
| EC-8: Password Generation Weak Randomness | `crypto.randomBytes()` fails (rare) → retry 3 times, enqueue to DLQ if all retries fail, never fall back to `Math.random()` | `unit_test` | `tests/unit/test_password_generator.js` | P1 |
| EC-9: Consent Field Not "true" | HubSpot contact `consent` field missing or not `"true"` → reject webhook with `400 Bad Request`, log rejection reason | `integration_test` | `tests/integration/test_consent_validation.js` | P1 |
| EC-10: Signature Timestamp Replay Attack | Webhook signature older than 5 minutes → reject with `401 Unauthorized` | `unit_test` + `integration_test` | `tests/unit/test_signature.js`, `tests/integration/test_webhook_receiver.js` | P1 |
| EC-11: Concurrent Secret Updates | No automated test; covered by rotation checklist coordination | `manual_verification` | `docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md` | P3 |
| EC-12: Error Stack Trace Includes Secrets | Stack trace logged after error contains environment variables → sanitize before logging, strip env vars | `unit_test` | `tests/unit/test_sanitize.js` | P1 |

---

## Test Execution Strategy

### Phase 1: Unit Tests (CI-safe, no external dependencies)

These tests run in CI on every push:

```bash
cd services/hubspot-registration
npm test -- --testPathPattern=unit
```

**Coverage target**: >80% for all modules

**Key unit test files**:
- `tests/unit/test_signature.js` -- HubSpot signature verification (constant-time comparison, timestamp validation)
- `tests/unit/test_password_generator.js` -- Password generation (length, complexity, crypto randomness)
- `tests/unit/test_username_generation.js` -- Username uniqueness format
- `tests/unit/test_field_parsing.js` -- HubSpot multi-select field parsing, missing field defaults
- `tests/unit/test_sanitize.js` -- Log sanitization (strip secrets, hash emails)

### Phase 2: Integration Tests (mocked external APIs)

These tests run in CI with mocked external services:

```bash
cd services/hubspot-registration
npm test -- --testPathPattern=integration
```

**Coverage target**: >70% for end-to-end flows

**Key integration test files**:
- `tests/integration/test_webhook_receiver.js` -- Full webhook flow (valid/invalid signature, feature flag, form GUID allowlist)
- `tests/integration/test_hubspot_integration.js` -- HubSpot API calls (contact profile fetch, OAuth refresh, retries)
- `tests/integration/test_user_creation.js` -- Open edX user creation (duplicate check, username generation, retries)
- `tests/integration/test_profile_enrichment.js` -- Open edX profile enrichment (field mapping, graceful failure)
- `tests/integration/test_email_delivery.js` -- SendGrid welcome email (template selection, dynamic data, retries)
- `tests/integration/test_reminder_scheduler.js` -- Redis reminder scheduling (encryption, TTL, job format)
- `tests/integration/test_reminder_processor.js` -- Redis reminder processing (due job detection, email sending, completion marking)
- `tests/integration/test_idempotency.js` -- Redis deduplication (atomic check-and-set, race conditions)
- `tests/integration/test_dlq.js` -- Dead letter queue (enqueue, retry, error notification)
- `tests/integration/test_dlq_replay.js` -- Admin API DLQ replay
- `tests/integration/test_logging.js` -- Structured JSON log format (schema validation, PII redaction)
- `tests/integration/test_metrics.js` -- Prometheus metrics (all 10 metrics present, labels correct)

**Mocking strategy**:
- **HubSpot API**: Mock all endpoints (`/contacts/v1/contact/vid/{id}/profile`, OAuth token endpoint) using `nock` or `msw`
- **Open edX API**: Mock user creation (`POST /api/user/v1/accounts`), duplicate check (`GET /api/user/v1/accounts?email={email}`), profile enrichment (`PATCH /api/user/v1/accounts/{username}`)
- **SendGrid API**: Mock transactional template API (`POST /v3/mail/send`)
- **Redis**: Use `ioredis-mock` or Docker Redis container (prefer real Redis in Docker for integration tests)

### Phase 3: Smoke Tests (live K8s deployment)

These tests run by operators during rollout verification:

```bash
./scripts/qa/smoke-test-hubspot-registration.sh
```

**Test coverage**:
- Health checks: `GET /healthz` returns 200 OK, `GET /readyz` returns 200 OK
- Metrics endpoint: `GET /metrics` returns all 10 Prometheus metrics
- Feature flag disabled: POST webhook returns `503 Service Unavailable`
- Invalid signature: POST webhook with bad signature returns `401 Unauthorized`
- Container security: `kubectl exec` into pod, verify UID 1000, read-only filesystem

**File**: `scripts/qa/smoke-test-hubspot-registration.sh`

### Phase 4: End-to-End Verification (live external services)

These tests run by operators after enabling feature flag:

```bash
./scripts/qa/verify-hubspot-registration.sh
```

**Test coverage**:
- Submit test HubSpot form with known email
- Verify user created in Open edX: `curl https://academyv2.mereka.io/api/user/v1/accounts?email=test@example.com`
- Verify welcome email received (check email inbox or SendGrid dashboard)
- Verify reminder scheduled in Redis: `kubectl exec -n mereka-lms deploy/redis -- redis-cli XLEN "hubspot:reminders"`
- Verify Prometheus metrics updated: `hubspot_user_creation_total{status="success"}` incremented
- Verify no errors in logs: `kubectl logs -n mereka-lms -l app=hubspot-registration-service | jq 'select(.level=="ERROR")'`
- Verify DLQ empty: `kubectl exec -n mereka-lms deploy/redis -- redis-cli XLEN "hubspot:dlq"`

**File**: `scripts/qa/verify-hubspot-registration.sh`

### Phase 5: Manual Verification (human operator)

| Test | Procedure | Frequency |
|------|-----------|-----------|
| AC-HUB-023: Container security | `kubectl exec` into pod, run `id` (verify UID 1000), try to write to `/` (verify read-only), check `/tmp` is writable | Per deployment |
| AC-HUB-026: Alert firing | Simulate high failure rate by disabling Open edX API, wait 15 min, verify Prometheus alert fires and routes to `#ops-alerts` | Once during setup |
| EC-6: HubSpot webhook replay after 24h | Simulate service downtime >24 hours, verify HubSpot stops retrying, manually export contacts from HubSpot, replay via admin API | Once during game day |
| EC-11: Concurrent secret updates | Follow rotation checklist, verify no concurrent rotations cause conflicts | Quarterly during rotation drills |
| End-to-end 7-day reminder | Submit test form, wait 7 days, verify reminder email received with correct template and credentials | Once during initial rollout, then spot-check monthly |

---

## Coverage Summary

| Category | Total ACs | Automated (Unit) | Automated (Integration) | Manual | Coverage |
|----------|-----------|-----------------|----------------------|--------|----------|
| Webhook Receiver | 4 (AC-HUB-001 to 004) | 2 | 4 | 0 | 100% |
| HubSpot Integration | 3 (AC-HUB-005 to 007) | 2 | 3 | 0 | 100% |
| User Creation | 4 (AC-HUB-008 to 011) | 2 | 4 | 0 | 100% |
| Email Delivery | 2 (AC-HUB-012 to 013) | 0 | 2 | 0 | 100% |
| Reminder Scheduling | 2 (AC-HUB-014 to 015) | 0 | 2 | 0 | 100% |
| Idempotency | 2 (AC-HUB-016 to 017) | 0 | 2 | 0 | 100% |
| Dead Letter Queue | 3 (AC-HUB-018 to 020) | 0 | 3 | 0 | 100% |
| Security | 3 (AC-HUB-021 to 023) | 2 | 2 | 1 | 100% |
| Observability | 3 (AC-HUB-024 to 026) | 0 | 2 | 1 | 100% |
| **Total** | **26** | **8** | **24** | **2** | **100%** |
| Edge Cases | 12 | 5 | 6 | 1 | 100% |

All 26 acceptance criteria are covered. 8 have pure unit tests, 24 have integration tests (with mocked external APIs), and 2 require manual verification (container security inspection, alert firing verification).

---

## Test Data Fixtures

### Fixture 1: Valid HubSpot Webhook Payload
```json
{
  "objectId": 12345,
  "subscriptionType": "contact.creation",
  "eventId": "abc123",
  "occurredAt": 1678886400000
}
```

### Fixture 2: HubSpot Contact Profile (EN form)
```json
{
  "vid": 12345,
  "properties": {
    "email": { "value": "test@example.com" },
    "firstname": { "value": "Test" },
    "lastname": { "value": "User" },
    "country_territory": { "value": "Singapore" },
    "consent": { "value": "true" },
    "lnob_type": { "value": "Women;Low-income" },
    "mct_learning_categories_interest": { "value": "Data Analyst;Developer" }
  },
  "form-submissions": [
    {
      "form-id": "1kTBgf9zSQl2J4KhZWBh8Tw5437v",
      "timestamp": 1678886400000
    }
  ]
}
```

### Fixture 3: Open edX User Creation Success Response
```json
{
  "username": "test_1234",
  "email": "test@example.com",
  "name": "Test User",
  "id": 67890
}
```

### Fixture 4: Open edX User Already Exists Response
```json
{
  "username": "test_1234"
}
```

### Fixture 5: SendGrid Email Success Response
```json
{
  "message_id": "<msg-id@sendgrid.net>"
}
```

### Fixture 6: Redis Reminder Job Format
```json
{
  "email": "test@example.com",
  "username": "test_1234",
  "password_encrypted": "base64-encoded-aes-gcm-ciphertext",
  "language": "en",
  "scheduled_at": "2026-02-17T12:00:00Z"
}
```

---

## Test Failure Scenarios

| Failure Scenario | Expected Behavior | Verification |
|------------------|------------------|--------------|
| HubSpot signature invalid | Return `401 Unauthorized`, log signature failure with source IP hash (not full body) | Check HTTP response, verify log contains `email_hash` not plaintext email |
| HubSpot form GUID not in allowlist | Return `400 Bad Request`, log unknown form GUID | Check HTTP response, verify log contains form GUID |
| Feature flag disabled | Return `503 Service Unavailable`, log disabled message | Check HTTP response, verify log contains "DISABLED" |
| Open edX API returns 500 Internal Server Error | Retry 3 times with exponential backoff, enqueue to DLQ if all retries fail | Verify 3 retry attempts, verify DLQ entry created |
| SendGrid API returns 429 Too Many Requests | Retry with backoff respecting `Retry-After` header, enqueue to DLQ if retries exhausted | Verify retry logic, verify DLQ entry created |
| Redis unavailable | Log error, skip deduplication, skip reminder scheduling, user creation still succeeds | Verify user created, verify log contains Redis error, verify `redis_connection_failures_total` metric incremented |
| Duplicate email submitted | Skip user creation, log warning with email hash, still send welcome email | Verify Open edX API called once only, verify email sent |
| Consent field not "true" | Return `400 Bad Request`, log rejection reason, no user created | Check HTTP response, verify no Open edX API call |
| Password generation fails (crypto error) | Retry 3 times, enqueue to DLQ if all retries fail, never fall back to `Math.random()` | Verify retry logic, verify DLQ entry created |
| Username collision (409 Conflict) | Retry with new random suffix up to 3 times, enqueue to DLQ if all retries fail | Verify 3 retry attempts with different suffixes, verify DLQ entry if all fail |

---

## CI Integration

### GitHub Actions Workflow

Add job to `.github/workflows/ci.yml`:

```yaml
hubspot-registration-tests:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
      with:
        node-version: '18'
    - run: |
        cd services/hubspot-registration
        npm ci
        npm run test:unit
        npm run test:integration
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        files: services/hubspot-registration/coverage/lcov.info
```

### Coverage Enforcement

- **Unit tests**: Minimum 80% coverage (statement, branch, function)
- **Integration tests**: Minimum 70% coverage (statement, branch)
- **CI fails if coverage below threshold**

---

## Load Testing (Future)

Not in scope for v1, but future load tests should validate:

- **Throughput**: 50 registrations/min sustained, 500 registrations in 5 min burst
- **Latency**: Webhook returns `200 OK` within 2 seconds for 95% of requests
- **Concurrency**: 100 concurrent webhook requests without degradation
- **Resource limits**: Pod CPU/memory under load (verify HPA scales correctly)

**Tool**: `k6` or `locust` with synthetic HubSpot webhook payloads

**Test file**: `services/hubspot-registration/load-tests/webhook-load-test.js` (future)

---

## Appendix: Test File Structure

```
services/hubspot-registration/
├── tests/
│   ├── unit/
│   │   ├── test_signature.js
│   │   ├── test_password_generator.js
│   │   ├── test_username_generation.js
│   │   ├── test_field_parsing.js
│   │   └── test_sanitize.js
│   ├── integration/
│   │   ├── test_webhook_receiver.js
│   │   ├── test_hubspot_integration.js
│   │   ├── test_hubspot_oauth.js
│   │   ├── test_user_creation.js
│   │   ├── test_username_collision.js
│   │   ├── test_profile_enrichment.js
│   │   ├── test_email_delivery.js
│   │   ├── test_email_delivery_failure.js
│   │   ├── test_email_fallback.js
│   │   ├── test_reminder_scheduler.js
│   │   ├── test_reminder_processor.js
│   │   ├── test_idempotency.js
│   │   ├── test_dlq.js
│   │   ├── test_dlq_replay.js
│   │   ├── test_redis_failure.js
│   │   ├── test_rate_limiting.js
│   │   ├── test_consent_validation.js
│   │   ├── test_feature_flag.js
│   │   ├── test_logging.js
│   │   └── test_metrics.js
│   └── fixtures/
│       ├── hubspot-webhook.json
│       ├── hubspot-contact-profile-en.json
│       ├── hubspot-contact-profile-ms.json
│       ├── openedx-user-response.json
│       ├── sendgrid-email-response.json
│       └── redis-reminder-job.json
├── scripts/
│   └── qa/
│       ├── smoke-test-hubspot-registration.sh
│       └── verify-hubspot-registration.sh
└── package.json
```
