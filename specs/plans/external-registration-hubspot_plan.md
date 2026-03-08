---
spec: external-registration-hubspot_spec.md
tier: 2
status: draft
estimated_effort: L
last_updated: "2026-02-10"
---

# Implementation Plan: External Registration via HubSpot

**Source Spec**: `specs/external-registration-hubspot_spec.md`
**Tier**: 2 -- Services (depends on secrets-management, k8s-deployment)
**Estimated Total Effort**: L (large, 8-12 days -- new K8s service with complex integrations)

## Summary

This plan implements a Node.js 18+ service deployed to K8s that replaces the existing Firebase Cloud Function for user registration. The service receives HubSpot webhooks, verifies signatures, fetches contact profiles, creates Open edX users, sends welcome emails via SendGrid, and schedules 7-day reminder emails via Redis. The service is feature-flagged for gradual rollout and includes comprehensive observability (Prometheus metrics, structured JSON logs, Grafana dashboard, Prometheus alerts).

## Prerequisites

Before starting implementation:

1. **HubSpot OAuth app configured** -- Client ID, Client Secret, Refresh Token stored in Infisical
2. **SendGrid templates created** -- 5 welcome email templates + 5 reminder templates (EN/MS/ZH/VN/PH)
3. **Open edX service account created** -- Username/password with API access stored in Infisical
4. **Redis deployed in K8s** -- Accessible at `redis.mereka-lms.svc.cluster.local:6379`
5. **ExternalSecrets infrastructure working** -- Per `specs/secrets-management_spec.md`
6. **GKE cluster access** -- `kubectl` configured for `mereka-lms` namespace
7. **Artifact Registry access** -- Push permissions to `ghcr.io/biji-biji-initiative/mereka-lms`

## Task Breakdown

### Build

#### B1. Set up Node.js service scaffolding
- [ ] **[M]** Create directory structure: `services/hubspot-registration/src/`, `services/hubspot-registration/tests/`, `services/hubspot-registration/Dockerfile`
- [ ] **[M]** Initialize `package.json` with dependencies: Express, axios, bcrypt, redis, prom-client, winston, dotenv
- [ ] **[M]** Create `src/server.js` with Express app, health checks (`/healthz`, `/readyz`), metrics endpoint (`/metrics`)
- [ ] **[M]** Configure structured JSON logging with Winston (stdout, fields: timestamp, level, service, message, contact_id, email_hash, error, duration_ms)
- **Files**: `services/hubspot-registration/package.json`, `services/hubspot-registration/src/server.js`, `services/hubspot-registration/src/logger.js`
- **AC**: AC-HUB-024, AC-HUB-025, Observability/Logs
- **Depends**: None
- **Done**: `npm start` runs without error, `/healthz` returns 200 OK, logs are structured JSON

#### B2. Implement webhook receiver endpoint
- [ ] **[M]** Create route `POST /api/hubspot/webhook/registration` in `src/routes/webhook.js`
- [ ] **[M]** Implement signature verification (v3 HMAC-SHA256, constant-time comparison, 5-minute timestamp tolerance)
- [ ] **[M]** Implement feature flag check (`HUBSPOT_REGISTRATION_ENABLED` env var, default: false)
- [ ] **[M]** Extract `objectId` from webhook payload and validate required fields (`objectId`, `subscriptionType`)
- [ ] **[M]** Return `200 OK` within 2 seconds, queue processing asynchronously
- [ ] **[M]** Return `401 Unauthorized` for invalid signature, `400 Bad Request` for malformed payload, `503 Service Unavailable` for disabled feature flag
- **Files**: `services/hubspot-registration/src/routes/webhook.js`, `services/hubspot-registration/src/utils/signature.js`
- **AC**: AC-HUB-001, AC-HUB-002, AC-HUB-003, AC-HUB-004, AC-HUB-021
- **Depends**: B1
- **Done**: POST request with valid signature returns 200 OK within 2 seconds; invalid signature returns 401

#### B3. Implement HubSpot OAuth token management
- [ ] **[M]** Create `src/integrations/hubspot-auth.js` with OAuth token refresh logic
- [ ] **[M]** Implement automatic token refresh when access token expires (use refresh token)
- [ ] **[M]** Cache access token in memory with expiration tracking
- [ ] **[M]** Load OAuth credentials from environment variables (synced from ExternalSecrets)
- **Files**: `services/hubspot-registration/src/integrations/hubspot-auth.js`
- **AC**: AC-HUB-005, AC-HUB-006
- **Depends**: B1
- **Done**: Token refresh succeeds when access token expired; retries API call with fresh token

#### B4. Implement HubSpot contact profile fetching
- [ ] **[L]** Create `src/integrations/hubspot-contacts.js` with `GET /contacts/v1/contact/vid/{contactId}/profile` call
- [ ] **[L]** Parse all required and optional fields from HubSpot contact profile (20+ fields, see spec Requirements/HubSpot Contact Profile Fetching)
- [ ] **[M]** Parse multi-select fields (`;` delimited) into arrays
- [ ] **[M]** Implement retry logic: 3 retries with exponential backoff (1s, 2s, 4s) on 5xx errors
- [ ] **[M]** Fail fast on 4xx errors (no retries)
- [ ] **[M]** Validate `email` format (RFC 5322 basic), validate `consent` is `"true"`
- [ ] **[M]** Extract form GUID from `data['form-submissions'][0]['form-id']` and validate against allowlist (5 GUIDs)
- **Files**: `services/hubspot-registration/src/integrations/hubspot-contacts.js`, `services/hubspot-registration/src/utils/validators.js`
- **AC**: AC-HUB-005, AC-HUB-006, AC-HUB-007
- **Depends**: B3
- **Done**: Contact profile fetch succeeds, multi-select fields are arrays, consent validation works

#### B5. Implement Open edX user creation with duplicate check
- [ ] **[L]** Create `src/integrations/openedx-users.js` with duplicate check (`GET /api/user/v1/accounts?email={email}`)
- [ ] **[L]** If user exists, skip creation, log warning with email hash, still send welcome email
- [ ] **[L]** If user does not exist, call `POST /api/user/v1/accounts` with username generation (`{email_prefix}_{random_4_digit}`)
- [ ] **[M]** Generate secure password: `crypto.randomBytes(16)`, mix uppercase/lowercase/digits/special chars, min 12 chars
- [ ] **[M]** Handle username collision: retry with new random suffix up to 3 times
- [ ] **[M]** Implement Open edX service account authentication (OAuth or basic auth)
- [ ] **[M]** Retry user creation 3 times on 5xx errors, enqueue to DLQ on 4xx errors or retry exhaustion
- **Files**: `services/hubspot-registration/src/integrations/openedx-users.js`, `services/hubspot-registration/src/utils/password-generator.js`
- **AC**: AC-HUB-008, AC-HUB-009, AC-HUB-010, Edge Case: Duplicate Username Collision
- **Depends**: B1
- **Done**: User creation succeeds, duplicate email is handled idempotently, username uniqueness enforced

#### B6. Implement Open edX profile enrichment
- [ ] **[M]** Create `src/integrations/openedx-profiles.js` with `PATCH /api/user/v1/accounts/{username}` call
- [ ] **[M]** Map HubSpot fields to Open edX extended profile (country, city, gender, year_of_birth, bio, extended_profile JSON)
- [ ] **[M]** Include `hubspot_contact_id`, `created_via: "hubspot_webhook"`, `registration_date` in extended_profile
- [ ] **[S]** Handle profile enrichment failure gracefully: log error but do not fail entire flow (fire-and-forget)
- **Files**: `services/hubspot-registration/src/integrations/openedx-profiles.js`, `services/hubspot-registration/src/utils/field-mapping.js`
- **AC**: AC-HUB-011
- **Depends**: B5
- **Done**: Profile enrichment succeeds with all mapped fields; failure logged but does not block user creation

#### B7. Implement SendGrid welcome email delivery
- [ ] **[M]** Create `src/integrations/sendgrid-email.js` with transactional template API call
- [ ] **[M]** Map form GUID to language template ID (5 languages: EN/MS/ZH/VN/PH)
- [ ] **[M]** Reject webhook with `400 Bad Request` if form GUID not in allowlist
- [ ] **[M]** Send email with dynamic data: `nickname`, `username`, `password`, login link
- [ ] **[M]** Retry email sending 3 times on 5xx errors from SendGrid
- [ ] **[M]** Enqueue error notification to `ops@mereka.dev` if email fails after retries
- **Files**: `services/hubspot-registration/src/integrations/sendgrid-email.js`, `services/hubspot-registration/src/config/email-templates.js`
- **AC**: AC-HUB-012, AC-HUB-013
- **Depends**: B1
- **Done**: Welcome email sent with correct template and dynamic data; failure sends error notification

#### B8. Implement Redis-backed reminder email scheduling
- [ ] **[L]** Create `src/jobs/reminder-scheduler.js` with Redis Streams or BullMQ integration
- [ ] **[L]** Enqueue reminder job with encrypted password (AES-256-GCM), scheduled for 7 days later
- [ ] **[M]** Create periodic processor `src/jobs/reminder-processor.js` (runs every 1 hour) to process due reminders
- [ ] **[M]** Map language to reminder template ID (5 languages)
- [ ] **[M]** Mark processed jobs as completed, purge completed jobs after 30 days
- [ ] **[M]** Handle Redis connection failures gracefully: log error, do not crash, degrade to no reminder scheduling
- **Files**: `services/hubspot-registration/src/jobs/reminder-scheduler.js`, `services/hubspot-registration/src/jobs/reminder-processor.js`, `services/hubspot-registration/src/utils/encryption.js`
- **AC**: AC-HUB-014, AC-HUB-015, Edge Case: Redis Unavailability
- **Depends**: B7
- **Done**: Reminder job enqueued with encrypted password; processor sends reminder after 7 days; Redis failure graceful

#### B9. Implement Redis-based idempotency layer
- [ ] **[M]** Create `src/utils/deduplication.js` with Redis `SET NX EX` atomic check-and-set
- [ ] **[M]** Key format: `hubspot:registration:{email_hash}`, TTL: 24 hours
- [ ] **[M]** On duplicate webhook (key exists), return `200 OK` immediately without processing
- [ ] **[M]** Delete deduplication key if user creation fails (allow retry)
- [ ] **[M]** Handle race conditions: atomicity ensured by `SET NX EX` (set if not exists with expiry)
- **Files**: `services/hubspot-registration/src/utils/deduplication.js`
- **AC**: AC-HUB-016, AC-HUB-017
- **Depends**: B1
- **Done**: Duplicate webhook returns 200 OK without processing; race condition handled atomically

#### B10. Implement dead letter queue (DLQ)
- [ ] **[M]** Create `src/dlq/dlq-manager.js` with Redis-backed DLQ (Redis Streams or sorted set)
- [ ] **[M]** Enqueue failed webhook events with full context (payload, error, timestamp, retry count)
- [ ] **[M]** Implement automatic retry: 3 retries with exponential backoff (5 min, 15 min, 45 min)
- [ ] **[M]** Send error notification email to `ops@mereka.dev` after 3 retries fail
- [ ] **[M]** Create admin API `POST /api/admin/v1/dlq/replay/{dlq_entry_id}` for manual replay
- [ ] **[S]** Purge DLQ entries older than 7 days
- **Files**: `services/hubspot-registration/src/dlq/dlq-manager.js`, `services/hubspot-registration/src/routes/admin.js`
- **AC**: AC-HUB-018, AC-HUB-019, AC-HUB-020
- **Depends**: B1
- **Done**: Failed webhooks enqueued to DLQ; automatic retry works; manual replay API functional

#### B11. Implement error notification emails
- [ ] **[M]** Create `src/notifications/error-notifier.js` to send plain-text error emails to `ops@mereka.dev`
- [ ] **[M]** Include `contactId` or `email_hash`, `error_message`, `error_stack` (truncated to 1000 chars), `timestamp`, `service_name`
- [ ] **[M]** Do NOT include PII (email addresses, passwords) in error notifications
- [ ] **[M]** Trigger error notifications for: user creation failure (3 retries), welcome email failure (3 retries), HubSpot 4xx errors, signature verification attack (>10 failures in 5 min), DLQ exhaustion (3 retries)
- **Files**: `services/hubspot-registration/src/notifications/error-notifier.js`
- **AC**: Error Notification Emails (Requirements)
- **Depends**: B7
- **Done**: Error notifications sent for all specified failure scenarios; no PII in emails

#### B12. Implement Prometheus metrics
- [ ] **[M]** Create `src/metrics/metrics.js` with prom-client counters, histograms, gauges
- [ ] **[M]** Expose metrics at `GET /metrics`: `hubspot_webhook_requests_total`, `hubspot_webhook_processing_duration_seconds`, `hubspot_user_creation_total`, `hubspot_email_sent_total`, `hubspot_dlq_entries_total`, `hubspot_signature_verification_failures_total`, `hubspot_api_calls_total`, `hubspot_redis_operations_total`, `nodejs_heap_size_bytes`, `nodejs_event_loop_lag_seconds`
- [ ] **[M]** Instrument all critical paths: webhook receive, user creation, email sending, DLQ enqueue, Redis operations
- **Files**: `services/hubspot-registration/src/metrics/metrics.js`
- **AC**: AC-HUB-024, Observability/Metrics
- **Depends**: B1
- **Done**: `/metrics` endpoint returns all specified Prometheus metrics; labels match spec

#### B13. Implement security hardening
- [ ] **[M]** Configure container to run as UID 1000 (non-root)
- [ ] **[M]** Configure read-only root filesystem except `/tmp` (tmpfs)
- [ ] **[M]** Sanitize error messages before logging: strip environment variables and secrets from stack traces
- [ ] **[M]** Hash email addresses with SHA-256 before logging (`email_hash`)
- [ ] **[M]** Enforce TLS 1.2+ for all outbound API calls (axios config)
- [ ] **[M]** Never log plaintext passwords, API keys, or tokens at any log level
- **Files**: `services/hubspot-registration/Dockerfile`, `services/hubspot-registration/src/utils/sanitize.js`
- **AC**: AC-HUB-021, AC-HUB-022, AC-HUB-023, Security (Requirements)
- **Depends**: B1
- **Done**: Container runs as non-root, filesystem read-only, logs sanitized, email hashing works

#### B14. Build Dockerfile and push to Artifact Registry
- [ ] **[M]** Create multi-stage Dockerfile: build stage (install deps) + production stage (minimal image, non-root user)
- [ ] **[S]** Use Node.js 18 Alpine base image for smaller size
- [ ] **[S]** Configure tmpfs mount for `/tmp` in Dockerfile
- [ ] **[M]** Build image: `docker build -t ghcr.io/biji-biji-initiative/mereka-lms/hubspot-registration-service:latest .`
- [ ] **[M]** Push image to Artifact Registry: `docker push ghcr.io/biji-biji-initiative/mereka-lms/hubspot-registration-service:latest`
- **Files**: `services/hubspot-registration/Dockerfile`, `services/hubspot-registration/.dockerignore`
- **AC**: Docker Image (Scope)
- **Depends**: All build tasks
- **Done**: Image builds successfully, pushed to Artifact Registry

### Test

#### T1. Write unit tests for signature verification
- [ ] **[M]** Test valid signature returns true, invalid signature returns false
- [ ] **[M]** Test timestamp older than 5 minutes rejected
- [ ] **[M]** Test constant-time comparison (no timing attacks)
- **Files**: `services/hubspot-registration/tests/unit/signature.test.js`
- **AC**: AC-HUB-002, AC-HUB-021
- **Depends**: B2
- **Done**: All signature tests pass; coverage >80%

#### T2. Write unit tests for password generation
- [ ] **[M]** Test password length >= 12 characters
- [ ] **[M]** Test password contains uppercase, lowercase, digits, special chars
- [ ] **[M]** Test cryptographic randomness (`crypto.randomBytes()` used, not `Math.random()`)
- **Files**: `services/hubspot-registration/tests/unit/password-generator.test.js`
- **AC**: AC-HUB-010, Edge Case: Password Generation Weak Randomness
- **Depends**: B5
- **Done**: All password generation tests pass; coverage >80%

#### T3. Write unit tests for field mapping (HubSpot → Open edX)
- [ ] **[M]** Test all required and optional fields mapped correctly
- [ ] **[M]** Test multi-select fields (`;` delimited) parsed into arrays
- [ ] **[M]** Test missing optional fields default to empty string or empty array
- **Files**: `services/hubspot-registration/tests/unit/field-mapping.test.js`
- **AC**: AC-HUB-007, AC-HUB-011
- **Depends**: B4, B6
- **Done**: All field mapping tests pass; coverage >80%

#### T4. Write integration tests for end-to-end flow (mock external APIs)
- [ ] **[L]** Mock HubSpot webhook POST with valid payload
- [ ] **[L]** Mock HubSpot Contacts API response
- [ ] **[L]** Mock Open edX user creation API (success, duplicate email, 409 Conflict)
- [ ] **[L]** Mock SendGrid email API (success, failure)
- [ ] **[L]** Mock Redis operations (deduplication, reminder scheduling)
- [ ] **[L]** Test full happy path: webhook → user created → email sent → reminder scheduled
- [ ] **[M]** Test error paths: invalid signature → 401, duplicate email → skip creation, SendGrid failure → error notification
- **Files**: `services/hubspot-registration/tests/integration/webhook-flow.test.js`
- **AC**: AC-HUB-001 through AC-HUB-020
- **Depends**: All build tasks
- **Done**: All integration tests pass; coverage >70%

#### T5. Write smoke tests for deployed service (live K8s)
- [ ] **[M]** Create `scripts/qa/smoke-test-hubspot-registration.sh` that tests: `/healthz` returns 200, `/readyz` returns 200, `/metrics` contains expected metrics, feature flag disabled returns 503, invalid signature returns 401
- **Files**: `scripts/qa/smoke-test-hubspot-registration.sh`
- **AC**: AC-HUB-001, AC-HUB-002, AC-HUB-004, AC-HUB-024
- **Depends**: B14, K1
- **Done**: Smoke tests pass against deployed service

#### T6. Create verification script for acceptance criteria
- [ ] **[M]** Create `scripts/qa/verify-hubspot-registration.sh` that runs all automated checks: signature verification, idempotency, DLQ, metrics, logs, security (non-root, read-only filesystem)
- **Files**: `scripts/qa/verify-hubspot-registration.sh`
- **AC**: All acceptance criteria
- **Depends**: All build tasks
- **Done**: Verification script exits 0 when all checks pass

### Kubernetes Deployment

#### K1. Create K8s manifests (Deployment, Service, HPA)
- [ ] **[M]** Create `deploy/k8s/base/apps/hubspot-registration/deployment.yaml` with 2 replicas, resource requests/limits, liveness/readiness probes, security context (runAsUser: 1000, readOnlyRootFilesystem: true), `envFrom` for ExternalSecrets
- [ ] **[M]** Create `deploy/k8s/base/apps/hubspot-registration/service.yaml` (ClusterIP, port 3000)
- [ ] **[M]** Create `deploy/k8s/base/apps/hubspot-registration/hpa.yaml` (min 2, max 10, target CPU 70%)
- [ ] **[M]** Add `HUBSPOT_REGISTRATION_ENABLED=false` to ConfigMap (feature flag disabled by default)
- **Files**: `deploy/k8s/base/apps/hubspot-registration/deployment.yaml`, `deploy/k8s/base/apps/hubspot-registration/service.yaml`, `deploy/k8s/base/apps/hubspot-registration/hpa.yaml`, `deploy/k8s/base/apps/hubspot-registration/configmap.yaml`
- **AC**: Availability (Non-Functional Requirements)
- **Depends**: B14
- **Done**: `kubectl apply --dry-run=client` succeeds; manifests validate

#### K2. Create ExternalSecrets manifest for HubSpot registration secrets
- [ ] **[M]** Create `deploy/k8s/base/secrets/hubspot-registration-secrets.yaml` with mappings: `MEREKA_LMS_HUBSPOT_CLIENT_ID`, `MEREKA_LMS_HUBSPOT_CLIENT_SECRET`, `MEREKA_LMS_HUBSPOT_REFRESH_TOKEN`, `MEREKA_LMS_SENDGRID_API_KEY`, `MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_USERNAME`, `MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_PASSWORD`
- [ ] **[M]** Configure `refreshInterval: 1h`, `deletionPolicy: Retain`, `creationPolicy: Owner`, `secretStoreRef: gcp-secret-manager`
- [ ] **[M]** Add to production Kustomization
- **Files**: `deploy/k8s/base/secrets/hubspot-registration-secrets.yaml`, `deploy/k8s/overlays/production/kustomization.yaml`
- **AC**: ExternalSecrets Integration (Scope)
- **Depends**: None (requires secrets populated in Infisical + GCP SM)
- **Done**: ExternalSecret synced (`kubectl get externalsecret hubspot-registration-secrets -n mereka-lms` shows SecretSynced)

#### K3. Create production Kustomize overlay with image tag
- [ ] **[M]** Add image tag to `deploy/k8s/overlays/production/kustomization.yaml`: `newTag: <git-sha>`
- [ ] **[S]** Verify Kustomize build: `kubectl kustomize deploy/k8s/overlays/production/`
- **Files**: `deploy/k8s/overlays/production/kustomization.yaml`
- **AC**: Kustomize Overlay (Scope)
- **Depends**: K1
- **Done**: Kustomize build succeeds, image tag correct

#### K4. Create Ingress or Caddy route for webhook endpoint
- [ ] **[M]** Add route to Caddy configuration: `https://academyv2.mereka.io/api/hubspot/webhook/registration` → `http://hubspot-registration-service.mereka-lms.svc.cluster.local:3000/api/hubspot/webhook/registration`
- [ ] **[M]** Ensure HubSpot webhook subscription points to `https://academyv2.mereka.io/api/hubspot/webhook/registration` (operator task, not code change)
- **Files**: Caddy configuration (location TBD based on existing Caddy setup)
- **AC**: Webhook Receiver Endpoint (Functional Requirements)
- **Depends**: K1
- **Done**: Webhook endpoint reachable from public internet; HubSpot can POST to it

### Observability

#### O1. Create PrometheusRule for alerts
- [ ] **[M]** Create `infrastructure/monitoring/prometheus-rules/hubspot-registration-alerts.yaml` with 5 alerts: `HubSpotRegistrationHighFailureRate`, `HubSpotRegistrationServiceDown`, `HubSpotSignatureVerificationSpike`, `HubSpotDLQBacklog`, `HubSpotEmailFailureRate`
- [ ] **[M]** Configure alert routing: critical → `#ops-alerts`, warning → `#ops-warnings`
- [ ] **[M]** Apply PrometheusRule to cluster
- **Files**: `infrastructure/monitoring/prometheus-rules/hubspot-registration-alerts.yaml`
- **AC**: AC-HUB-026, Observability/Alerts
- **Depends**: B12
- **Done**: Prometheus rules loaded; test alert fires in dev environment

#### O2. Create ServiceMonitor for Prometheus scraping
- [ ] **[M]** Create `deploy/k8s/base/apps/hubspot-registration/servicemonitor.yaml` to scrape `/metrics` endpoint every 15 seconds
- **Files**: `deploy/k8s/base/apps/hubspot-registration/servicemonitor.yaml`
- **AC**: Observability/Metrics
- **Depends**: B12, K1
- **Done**: Prometheus scrapes metrics; metrics visible in Prometheus UI

#### O3. Create Grafana dashboard
- [ ] **[L]** Create `infrastructure/monitoring/dashboards/hubspot-registration-dashboard.json` with 9 panels: webhook request rate, user creation success/failure rate, email delivery rate, webhook latency, DLQ backlog, API call latency, Redis operation rate, Node.js heap usage, pod CPU/memory
- [ ] **[M]** Import dashboard to Grafana
- **Files**: `infrastructure/monitoring/dashboards/hubspot-registration-dashboard.json`
- **AC**: Observability/Dashboards
- **Depends**: B12, O2
- **Done**: Dashboard visible in Grafana, all panels render data

#### O4. Verify logs collected by Promtail/Loki
- [ ] **[S]** Confirm Promtail config includes `mereka-lms` namespace (likely already configured)
- [ ] **[S]** Query Loki for service logs: `{namespace="mereka-lms", app="hubspot-registration-service"}`
- **Files**: `infrastructure/observability/` (verification only)
- **AC**: Observability/Logs
- **Depends**: K1
- **Done**: Loki query returns structured JSON logs from service

### Docs

#### D1. Create service README
- [ ] **[M]** Create `services/hubspot-registration/README.md` documenting: architecture overview, API endpoints, environment variables, local development setup, deployment instructions, troubleshooting
- **Files**: `services/hubspot-registration/README.md`
- **AC**: Documentation (implicit)
- **Depends**: None
- **Done**: README comprehensive and accurate

#### D2. Create operational runbook
- [ ] **[M]** Create `docs/runbooks/external-registration-runbook.md` with procedures: enable/disable feature flag, view logs/metrics, replay DLQ entries, rotate secrets, handle high failure rate, handle SendGrid account suspension
- **Files**: `docs/runbooks/external-registration-runbook.md`
- **AC**: Documentation (implicit)
- **Depends**: K1, O1
- **Done**: Runbook covers all operational scenarios

#### D3. Update TROUBLESHOOTING.md with HubSpot registration section
- [ ] **[S]** Add HubSpot registration troubleshooting section to `docs/runbooks/operations/TROUBLESHOOTING.md`: common errors, how to check logs, how to verify ExternalSecrets, how to test signature verification
- **Files**: `docs/runbooks/operations/TROUBLESHOOTING.md`
- **AC**: Documentation (implicit)
- **Depends**: K1
- **Done**: Troubleshooting section added

### Rollout

#### R1. Populate secrets in Infisical and GCP Secret Manager
- [ ] **[M]** Operator task: Add HubSpot OAuth credentials to Infisical at `/k8s/mereka-lms`: `MEREKA_LMS_HUBSPOT_CLIENT_ID`, `MEREKA_LMS_HUBSPOT_CLIENT_SECRET`, `MEREKA_LMS_HUBSPOT_REFRESH_TOKEN`
- [ ] **[M]** Operator task: Add SendGrid API key to Infisical: `MEREKA_LMS_SENDGRID_API_KEY`
- [ ] **[M]** Operator task: Add Open edX service account credentials to Infisical: `MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_USERNAME`, `MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_PASSWORD`
- [ ] **[M]** Sync secrets to GCP Secret Manager: `./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh`
- **Files**: None (operator task)
- **AC**: ExternalSecrets Integration (Scope)
- **Depends**: None
- **Done**: All secrets exist in Infisical and GCP SM; ExternalSecret syncs to K8s Secret

#### R2. Deploy to production with feature flag disabled (dark launch)
- [ ] **[M]** Build image with production tag: `docker build -t ghcr.io/biji-biji-initiative/mereka-lms/hubspot-registration-service:$(git rev-parse --short HEAD) .`
- [ ] **[M]** Push image to Artifact Registry
- [ ] **[M]** Update production Kustomization with image tag
- [ ] **[M]** Apply manifests: `kubectl apply -k deploy/k8s/overlays/production/`
- [ ] **[M]** Verify pods running: `kubectl get pods -n mereka-lms -l app=hubspot-registration-service`
- [ ] **[M]** Verify feature flag disabled: `kubectl logs -n mereka-lms -l app=hubspot-registration-service --tail=10 | grep "DISABLED"`
- **Files**: None (operator task)
- **AC**: Rollout Plan/Phase 3
- **Depends**: K1, K2, K3, R1
- **Done**: Service running in production with feature flag disabled

#### R3. Run smoke tests against production deployment
- [ ] **[M]** Run `scripts/qa/smoke-test-hubspot-registration.sh` against production
- [ ] **[M]** Verify health checks pass, metrics endpoint works, feature flag disabled returns 503
- [ ] **[M]** Submit test HubSpot form, verify webhook rejected with 503 (feature flag disabled)
- **Files**: `scripts/qa/smoke-test-hubspot-registration.sh`
- **AC**: Rollout Plan/Phase 3
- **Depends**: T5, R2
- **Done**: All smoke tests pass

#### R4. Enable feature flag and test end-to-end flow
- [ ] **[M]** Update ConfigMap: `HUBSPOT_REGISTRATION_ENABLED=true`
- [ ] **[M]** Restart deployment: `kubectl rollout restart deployment/hubspot-registration-service -n mereka-lms`
- [ ] **[M]** Submit test HubSpot form with known email
- [ ] **[M]** Verify user created in Open edX: `curl -s https://academyv2.mereka.io/api/user/v1/accounts?email=test@example.com | jq '.username'`
- [ ] **[M]** Verify welcome email received (check email inbox or SendGrid dashboard)
- [ ] **[M]** Verify reminder scheduled in Redis: `kubectl exec -n mereka-lms deploy/redis -- redis-cli XLEN "hubspot:reminders"`
- [ ] **[M]** Monitor metrics for 24 hours: success rate, latency, DLQ backlog
- **Files**: None (operator task)
- **AC**: Rollout Plan/Phase 4, Verification (spec)
- **Depends**: R3
- **Done**: User created, welcome email sent, reminder scheduled, metrics healthy

#### R5. Update HubSpot webhook subscription to production endpoint
- [ ] **[M]** Operator task: Update HubSpot webhook subscription URL to `https://academyv2.mereka.io/api/hubspot/webhook/registration`
- [ ] **[M]** Monitor metrics for 7 days: webhook receive rate, success rate, DLQ backlog
- [ ] **[M]** Verify reminder emails sent after 7 days
- **Files**: None (operator task)
- **AC**: Rollout Plan/Phase 4
- **Depends**: R4
- **Done**: HubSpot webhooks routed to production service, 7-day monitoring complete

#### R6. Deprecate Firebase Cloud Function
- [ ] **[S]** After 7 days of stable operation (success rate >= 99.5%, no critical alerts), disable Firebase Cloud Function
- [ ] **[S]** Archive Firebase function code to Git for reference
- [ ] **[S]** Remove Azure AD B2C and MCT dependencies from codebase (if any remain)
- **Files**: None (operator task)
- **AC**: Rollout Plan/Phase 5
- **Depends**: R5
- **Done**: Firebase function disabled, code archived

---

## Milestone Checkpoints

### Milestone 1: Service Scaffolding (Day 1-2)
- B1, B2, B3, B12, B13 complete (server running, webhook endpoint, signature verification, metrics, security hardening)
- T1 unit tests passing
- Service runs locally, health checks pass

### Milestone 2: External Integrations (Day 3-5)
- B4, B5, B6, B7, B8 complete (HubSpot contacts, Open edX users/profiles, SendGrid emails, reminder scheduling)
- T2, T3 unit tests passing
- Integration tests (T4) passing with mocked APIs

### Milestone 3: Resilience & Error Handling (Day 6-7)
- B9, B10, B11 complete (idempotency, DLQ, error notifications)
- T4 integration tests include error paths
- B14 Dockerfile built and image pushed

### Milestone 4: K8s Deployment & Observability (Day 8-9)
- K1, K2, K3, K4 complete (K8s manifests, ExternalSecrets, Kustomize overlay, Caddy route)
- O1, O2, O3, O4 complete (alerts, ServiceMonitor, Grafana dashboard, Loki logs)
- T5, T6 smoke tests and verification scripts passing

### Milestone 5: Documentation & Testing (Day 10)
- D1, D2, D3 complete (README, runbook, troubleshooting)
- All unit tests (T1, T2, T3) passing with >80% coverage
- All integration tests (T4) passing with >70% coverage

### Milestone 6: Production Rollout (Day 11-12)
- R1 secrets populated
- R2 dark launch complete
- R3 smoke tests passing
- R4 feature flag enabled, end-to-end test passing
- R5 HubSpot webhook subscription updated, 7-day monitoring underway

### Milestone 7: Deprecation (Week 5)
- R6 Firebase function disabled after 7 days stable operation

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| HubSpot OAuth token refresh fails | Medium | High | B3 implements retry logic; alert fires if refresh fails >3 times |
| SendGrid account rate-limited or suspended | Low | High | B7 retries; error notification sent; runbook documents recovery procedure |
| Redis unavailable during launch | Medium | Medium | B8, B9 handle gracefully (degrade to no deduplication, no reminders); alert fires if Redis down >5 min |
| Open edX API rate-limits service account | Medium | Medium | B5 implements exponential backoff; DLQ enqueues on persistent rate limit |
| HubSpot form schema changes break field mapping | Medium | Medium | B4 handles missing fields gracefully; alert fires if many webhooks fail with parse errors |
| Username collision despite random suffix | Low | Low | B5 retries with new suffix up to 3 times; DLQ captures if all retries fail |
| Weak password generation due to crypto failure | Very Low | High | B5 retries password generation 3 times; no fallback to weak randomness; DLQ enqueues on failure |
| Feature flag accidentally enabled before testing | Medium | Medium | R2 deploys with feature flag disabled by default; R3 smoke tests verify disabled state |
| HubSpot webhooks lost during >24h downtime | Low | High | Rollout plan documents manual CSV export/replay procedure; DLQ captures all failures |
| CI/CD secrets not populated | Medium | Medium | K2 depends on R1 (operator task); ExternalSecret status checked in R2 |

---

## Dependencies on Other Specs

| Spec | Dependency Type |
|------|----------------|
| `secrets-management_spec.md` | REQUIRED: ExternalSecrets pattern, Infisical → GCP SM → K8s Secret |
| `k8s-deployment_spec.md` | REQUIRED: Namespace, Deployment, Service, HPA patterns |
| `observability-stack_spec.md` | REQUIRED: Prometheus, Loki, Grafana infrastructure |
| `email-notifications-pipeline_spec.md` | COORDINATION: SendGrid webhook integration for email delivery status |
| `multi-tenancy-architecture_spec.md` | FUTURE: All users created under default `EnterpriseCustomer` (multi-tenant support out of scope for v1) |
| `cross-cutting-requirements_spec.md` | INHERITS: Tenant isolation, observability, secrets management, Redis Streams event bus |
