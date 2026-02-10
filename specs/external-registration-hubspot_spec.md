---
title: "External Registration via HubSpot"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "services/hubspot-webhook/README.md"
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/runbooks/external-registration-runbook.md"
  related_specs:
    - "specs/secrets-management_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/email-notifications-pipeline_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A Kubernetes-based external registration service that replaces the existing Firebase Cloud Function for creating Open edX users from HubSpot form submissions. When prospective learners fill out a registration form on the Mereka Academy marketing website (managed in HubSpot), HubSpot sends a webhook POST to this service, which then:

1. Verifies the webhook signature (HubSpot v3 signature)
2. Fetches the full contact profile from HubSpot using OAuth
3. Creates the user in Open edX via the LMS registration API
4. Enriches the user profile with additional fields (country, learning pathways, gender, etc.)
5. Sends a multi-language welcome email via SendGrid with login credentials
6. Schedules a 7-day reminder email via Redis-backed job queue

The current implementation (`services/hubspot-webhook/functions/index.js`) creates users in MCT (Microsoft Community Training) + Azure AD B2C. This spec defines the replacement that creates users in **Open edX** instead, deployed as a standalone K8s service in the `mereka-lms` namespace. The service is feature-flagged (`HUBSPOT_REGISTRATION_ENABLED=false` by default) to allow for gradual rollout and immediate rollback if issues arise.

## Why it matters

The migration from MCT to Open edX is complete, but the registration flow still points to the old infrastructure. Without this service:

- New learners register via HubSpot but never get Open edX accounts, causing confusion and support overhead
- The team must manually create accounts, which doesn't scale beyond a few dozen registrations per day
- The existing Firebase function is coupled to Azure AD B2C, which is being deprecated
- The registration flow lacks proper observability (no metrics, minimal logging, no error alerting)
- There is no idempotency guarantee, leading to duplicate account creation attempts when HubSpot retries webhooks

## Success looks like

- HubSpot webhook receives are acknowledged within 2 seconds (200 OK) to prevent HubSpot retries
- User creation in Open edX completes within 10 seconds end-to-end (webhook to welcome email sent)
- >= 99.5% of valid webhook requests result in successful user creation
- Duplicate submissions (same email) are handled idempotently without creating duplicate accounts
- Welcome emails arrive within 30 seconds of form submission in the correct language (EN/MS/ZH/VN/PH)
- 7-day reminder emails are sent with >= 99% reliability via Redis-backed job queue
- Invalid or malicious webhook requests are rejected with signature verification failures logged
- The service can handle bursts of 100+ registrations within 5 minutes (conference booth scenario)
- Prometheus metrics show webhook receive rate, success rate, failure reasons, and processing latency
- A critical alert fires if user creation success rate drops below 95% over a 15-minute window

---

# Agent Contract

## Scope

- In scope:
  - Kubernetes Deployment in `mereka-lms` namespace with HPA (horizontal pod autoscaling)
  - HubSpot webhook receiver endpoint (`POST /api/hubspot/webhook/registration`)
  - HubSpot signature verification (v3 signature using HMAC-SHA256)
  - HubSpot Contacts API integration via OAuth (NOT hardcoded PAT)
  - Contact profile fetching and field mapping to Open edX schema
  - Open edX user creation via LMS registration API (`POST /api/user/v1/accounts`)
  - Open edX user profile enrichment via profile API (`PATCH /api/user/v1/accounts/{username}`)
  - Password generation with cryptographic randomness (bcrypt-compatible strength)
  - SendGrid welcome email delivery with multi-language template support (EN, MS, ZH, VN, PH)
  - 7-day reminder email scheduling via Redis-backed job queue (NOT Firestore)
  - Idempotency layer: check if user exists before creation, deduplicate by email
  - Dead letter queue for failed webhook processing
  - Error notification emails to ops team via SendGrid
  - Feature flag: `HUBSPOT_REGISTRATION_ENABLED` (default: false)
  - ExternalSecrets integration for all credentials (HubSpot OAuth, SendGrid API key, Open edX service account)
  - Prometheus metrics endpoint (`/metrics`)
  - Health check endpoints (`/healthz`, `/readyz`)
  - Structured JSON logging to stdout (scraped by Promtail)
  - Docker image build and push to Artifact Registry
  - Kustomize overlay for production deployment

- Out of scope:
  - HubSpot form UI implementation (forms live in HubSpot portal)
  - HubSpot OAuth flow UI for credential generation (manual one-time setup by ops)
  - Open edX user deletion or account management beyond initial creation
  - Course enrollment automation (future: auto-enroll in onboarding course)
  - Custom field mapping for enterprise tenants (uses shared field schema)
  - Rate limiting HubSpot webhook calls (HubSpot enforces its own rate limits)
  - Multi-tenant support (all users created under the default `EnterpriseCustomer`)
  - Integration with Azure AD B2C or MCT (replaced functionality)
  - Webhook replay for failed events older than 24 hours (HubSpot retries for 24 hours, then stops)

## Non-goals

- Replacing HubSpot as the CRM (HubSpot remains the source of truth for marketing contacts)
- Building a custom form builder (forms are managed in HubSpot)
- Providing a UI for viewing registration status (admin uses HubSpot + Open edX Django admin)
- Supporting non-HubSpot registration sources (Google Forms, Typeform, etc.) in this service
- Real-time webhook retry (relies on HubSpot's retry mechanism + dead letter queue for manual replay)
- Email deliverability management (handled by SendGrid + `specs/email-notifications-pipeline_spec.md`)

## Assumptions

- HubSpot account is configured with webhook subscriptions for `contact.creation` and `contact.propertyChange` events
- HubSpot OAuth app is created with scopes: `crm.objects.contacts.read`, `crm.schemas.contacts.read`
- SendGrid is configured with verified sender identity (`noreply@academyv2.mereka.io`) and has 5 language-specific templates (EN, MS, ZH, VN, PH)
- Open edX LMS is reachable at `https://academyv2.mereka.io` from within the K8s cluster
- Redis is deployed in the `mereka-lms` namespace and accessible at `redis.mereka-lms.svc.cluster.local:6379`
- Infisical is the secrets source of truth (per `specs/secrets-management_spec.md`)
- The service runs as a non-root user with read-only root filesystem
- The K8s cluster has Prometheus Operator installed for metric scraping
- The service uses Node.js 18+ (same version as existing Firebase function for easier migration)

---

## Requirements

### Functional

#### Webhook Receiver Endpoint

- The system MUST expose an HTTP endpoint `POST /api/hubspot/webhook/registration` on port 3000
- The endpoint MUST accept JSON payloads with `Content-Type: application/json`
- The endpoint MUST return `200 OK` within 2 seconds of receiving a valid webhook to prevent HubSpot retries
- The endpoint MUST return `401 Unauthorized` if the HubSpot signature verification fails
- The endpoint MUST return `400 Bad Request` if the payload is malformed or missing required fields (`objectId`, `subscriptionType`)
- The endpoint MUST return `500 Internal Server Error` if user creation fails for reasons other than duplicate email
- The endpoint MUST log the full request payload at DEBUG level (including headers for signature verification)
- The endpoint MUST NOT block on long-running operations (user creation, email sending) -- these MUST be processed asynchronously after returning 200 OK
- The endpoint MUST extract the `objectId` (contactId) from the webhook payload
- The endpoint MUST validate that the webhook event is from one of the approved HubSpot forms (allowlist of form GUIDs)

#### HubSpot Signature Verification

- The system MUST verify the HubSpot webhook signature using the v3 signature method
- The system MUST read the signature from the `X-HubSpot-Signature-v3` header
- The system MUST read the timestamp from the `X-HubSpot-Request-Timestamp` header
- The system MUST concatenate `method + uri + body + timestamp` and compute `HMAC-SHA256(concat_string, client_secret)`
- The system MUST compare the computed signature with the header signature using constant-time comparison to prevent timing attacks
- The system MUST reject requests with signatures older than 5 minutes to prevent replay attacks
- The HubSpot client secret MUST be stored in Infisical as `MEREKA_LMS_HUBSPOT_CLIENT_SECRET` and synced to K8s via ExternalSecrets
- The system MUST log signature verification failures with the request timestamp and source IP (hashed)

#### HubSpot Contact Profile Fetching

- The system MUST fetch the full contact profile from HubSpot using the Contacts API: `GET https://api.hubapi.com/contacts/v1/contact/vid/{contactId}/profile`
- The system MUST authenticate using OAuth access token (NOT hardcoded PAT)
- The HubSpot OAuth access token MUST be refreshed automatically when it expires (uses refresh token flow)
- The HubSpot OAuth credentials MUST be stored in Infisical:
  - `MEREKA_LMS_HUBSPOT_CLIENT_ID`
  - `MEREKA_LMS_HUBSPOT_CLIENT_SECRET`
  - `MEREKA_LMS_HUBSPOT_REFRESH_TOKEN`
  - `MEREKA_LMS_HUBSPOT_ACCESS_TOKEN` (optional; can be generated at runtime)
- The system MUST extract the following fields from the contact profile:
  - `email` (required)
  - `firstname` (required)
  - `lastname` (required)
  - `nickname` (optional)
  - `country_territory` (optional, defaults to "Unknown")
  - `ip_city` (optional)
  - `gender_new` (optional)
  - `birth_date` (optional, timestamp in milliseconds)
  - `lnob_type` (multi-select: learner needs or barriers)
  - `mct_learning_categories_interest` (multi-select: learning pathways)
  - `linkedin` (optional)
  - `mct_channels` (multi-select: referral source)
  - `consent` (required: "true")
  - `university_philippines`, `university_indonesia`, `university_vietnam`, `school_or_university_openended` (optional)
  - `sof_partners_philippines`, `sof_partners_indonesia`, `sof_partners_vietnam`, `sof_partners_regional` (optional)
- The system MUST parse multi-select HubSpot fields (`;` delimited) into arrays
- The system MUST handle missing optional fields gracefully (default to empty string or empty array)
- The system MUST validate that `email` is a valid email address (RFC 5322 basic validation)
- The system MUST validate that `consent` is `"true"` (reject registrations without consent)
- The system MUST retry HubSpot API calls up to 3 times with exponential backoff (1s, 2s, 4s) on 5xx errors or network failures
- The system MUST fail fast (no retries) on 4xx errors from HubSpot (invalid contactId, permission denied)

#### Open edX User Creation

- The system MUST check if a user with the given email already exists by calling `GET /api/user/v1/accounts?email={email}`
- If the user exists, the system MUST skip user creation and log a warning with `email_hash` (SHA-256 of email) for deduplication tracking
- If the user exists, the system MUST still send the welcome email (idempotent behavior: user receives credentials even if they registered twice)
- If the user does not exist, the system MUST create the user by calling `POST /api/user/v1/accounts` with the following payload:
  ```json
  {
    "email": "<email>",
    "username": "<email_prefix>_<random_4_digit>",
    "name": "<firstname> <lastname>",
    "password": "<generated_password>",
    "honor_code": true,
    "terms_of_service": true,
    "marketing_emails_opt_in": true
  }
  ```
- The username MUST be unique: `<email_prefix>` is the part before `@`, followed by `_` and a random 4-digit suffix to avoid collisions
- The password MUST be generated using cryptographic randomness (Node.js `crypto.randomBytes()` or equivalent) and be at least 12 characters with uppercase, lowercase, digits, and special characters
- The password MUST NOT be stored in plaintext anywhere (only stored in Open edX hashed via Django's password hashers)
- The system MUST authenticate the Open edX API call using a service account token (OAuth or JWT)
- The Open edX service account credentials MUST be stored in Infisical:
  - `MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_USERNAME`
  - `MEREKA_LMS_OPENEDX_SERVICE_ACCOUNT_PASSWORD`
- The system MUST retry user creation up to 3 times on 5xx errors from Open edX
- The system MUST fail and enqueue to dead letter queue on 4xx errors from Open edX (invalid payload, duplicate username despite uniqueness check)
- The system MUST log the Open edX response (success or error) with `user_id` or `username` (not email) for privacy

#### Open edX User Profile Enrichment

- After user creation succeeds, the system MUST enrich the user profile by calling `PATCH /api/user/v1/accounts/{username}` with extended profile fields:
  - `country`: mapped from `country_territory`
  - `city`: mapped from `ip_city`
  - `gender`: mapped from `gender_new` (values: "m", "f", "o", "p" for prefer not to say)
  - `year_of_birth`: extracted from `birth_date` timestamp
  - `bio`: constructed from `lnob_type` and `mct_learning_categories_interest` arrays (e.g., "Interested in: Data Analyst, Developer. Background: Women, Low-income")
  - `profile_image_uploaded_at`: null (no image upload via API)
  - `extended_profile`: JSON field containing:
    - `linkedin`: LinkedIn URL
    - `learning_pathways`: array of `mct_learning_categories_interest` values
    - `learner_needs`: array of `lnob_type` values
    - `referral_channels`: array of `mct_channels` values
    - `university`: first non-empty value from university fields
    - `referral_partner`: first non-empty value from partner fields
    - `hubspot_contact_id`: the original contactId for traceability
    - `created_via`: "hubspot_webhook"
    - `registration_date`: ISO 8601 timestamp of webhook receipt
- The system MUST handle profile enrichment failures gracefully: if the profile update fails, the user account still exists (log error but do not fail the entire flow)
- The system MUST NOT retry profile enrichment on failure (fire-and-forget after user creation succeeds)

#### Welcome Email Delivery

- After user creation succeeds, the system MUST send a welcome email via SendGrid using the appropriate language template
- The system MUST determine the email language based on the HubSpot form GUID:
  - `1kTBgf9zSQl2J4KhZWBh8Tw5437v` → English (template: `d-54113e54930f49a59d0c898cb2cf7cd7`)
  - `1DQqCAAJfSzCDlK_rPCReEg5437v` → Indonesian (template: `d-b47fdecdfaff497eba49b2089da06917`)
  - `1UkBP9VPoRgymtkMFCPmHtg5437v` → Filipino (template: `d-acc754366ab54e6194a4d0b5cd62c2ad`)
  - `1MWgao74AS-mixdrxJm46XA5437v` → Vietnamese (template: `d-f3d06a9f4eb54205852a89372767e84c`)
  - `1eASlzPOxQCK5yddvT2P0jg5437v` → Chinese (template: `d-35b735b3c1e74f5ebe2e3ea45d7bcd86`)
- The form GUID MUST be extracted from `data['form-submissions'][0]['form-id']` in the HubSpot contact profile
- If the form GUID is not in the allowlist, the system MUST reject the webhook with `400 Bad Request` and log the unknown form GUID
- The email MUST use SendGrid's transactional template API with dynamic data:
  - `nickname`: `firstname` or `nickname` from HubSpot
  - `username`: generated Open edX username
  - `password`: the generated plaintext password (sent once, never stored)
- The email MUST be sent from `noreply@academyv2.mereka.io` (verified sender in SendGrid)
- The email MUST include a link to the LMS login page: `https://academyv2.mereka.io/login`
- The SendGrid API key MUST be stored in Infisical as `MEREKA_LMS_SENDGRID_API_KEY`
- The system MUST retry email sending up to 3 times on 5xx errors from SendGrid
- The system MUST log email sending success or failure with `email_hash` (not plaintext email) for privacy
- If email sending fails after retries, the system MUST enqueue an error notification email to `ops@mereka.dev` with the contactId and error message
- The system MUST track email delivery status via SendGrid webhooks (coordinates with `specs/email-notifications-pipeline_spec.md`)

#### Reminder Email Scheduling

- After the welcome email is sent, the system MUST schedule a 7-day reminder email
- The reminder email MUST be scheduled using a Redis-backed job queue (NOT Firestore)
- The system MUST use Redis Streams (per `specs/cross-cutting-requirements_spec.md` event bus decision) or a Redis-backed queue library (e.g., BullMQ, Bee-Queue)
- The reminder job MUST include the following data:
  - `email`: recipient email
  - `username`: Open edX username
  - `password`: the generated password (stored encrypted in Redis with AES-256-GCM)
  - `language`: the form language for template selection
  - `scheduled_at`: timestamp 7 days from now
- The reminder email template IDs MUST be:
  - English: `d-94ab74b048d7469ca7e71d7edce66e9a`
  - Indonesian: `d-0ccb77f1fe4f4924b293328a6ea77158`
  - Filipino: `d-7c0c729177e249748ad13e585c468d87`
  - Vietnamese: `d-5bb3cde391744cab984ed64ed3a024e2`
  - Chinese: `d-90269d4b9ae140758307806e331fe5e9`
- The system MUST run a periodic job (every 1 hour) that processes due reminder emails from the Redis queue
- The system MUST mark processed reminder jobs as completed to prevent duplicate sends
- The system MUST purge completed reminder jobs from Redis after 30 days
- The system MUST handle Redis connection failures gracefully: if Redis is unavailable, log an error and retry scheduling on the next webhook event (fire-and-forget, no user-facing failure)

#### Idempotency and Deduplication

- The system MUST deduplicate webhook events by email address: if the same email is submitted twice within 24 hours, only one user creation attempt MUST occur
- The system MUST use Redis as the deduplication store with a key format: `hubspot:registration:{email_hash}` and TTL of 24 hours
- On receiving a webhook, the system MUST:
  1. Check if the deduplication key exists in Redis
  2. If exists, return `200 OK` immediately (already processed)
  3. If not exists, set the key with TTL 24 hours and proceed with user creation
- The system MUST handle race conditions: use Redis `SET NX EX` (set if not exists with expiry) to atomically check-and-set the deduplication key
- If user creation fails after deduplication key is set, the system MUST delete the key to allow retry on next webhook delivery

#### Dead Letter Queue

- The system MUST enqueue failed webhook processing attempts to a Redis-backed dead letter queue (DLQ)
- The DLQ MUST store the following data for each failed event:
  - `webhook_payload`: original HubSpot webhook JSON
  - `contact_id`: extracted contactId
  - `email_hash`: SHA-256 hash of the email
  - `error_message`: the error that caused the failure
  - `error_stack`: stack trace for debugging
  - `retry_count`: number of retries attempted
  - `failed_at`: timestamp of failure
- The system MUST retry DLQ events automatically up to 3 times with exponential backoff (5 min, 15 min, 45 min)
- After 3 retries, the system MUST send an error notification email to `ops@mereka.dev` with the DLQ entry details
- The system MUST expose an admin API for manual DLQ replay: `POST /api/admin/v1/dlq/replay/{dlq_entry_id}`
- The system MUST purge DLQ entries older than 7 days

#### Error Notification Emails

- The system MUST send error notification emails to `ops@mereka.dev` for the following failures:
  - User creation fails after 3 retries
  - Welcome email fails after 3 retries
  - HubSpot contact profile fetch fails with 4xx error (invalid contactId)
  - Signature verification fails more than 10 times in 5 minutes (possible attack)
  - Dead letter queue entry fails 3 retries
- Error emails MUST include:
  - `contactId` (or email hash if contactId unavailable)
  - `error_message`
  - `error_stack` (truncated to 1000 chars)
  - `timestamp`
  - `service_name`: "hubspot-registration-service"
- Error emails MUST be sent via SendGrid using a plain-text template (no dynamic template)
- Error emails MUST NOT include PII (email addresses, passwords) -- use email hash or contactId only

#### Feature Flag

- The system MUST respect the `HUBSPOT_REGISTRATION_ENABLED` environment variable (default: `"false"`)
- If `HUBSPOT_REGISTRATION_ENABLED=false`, the webhook endpoint MUST return `503 Service Unavailable` with body `{"message": "Registration service is disabled"}`
- The feature flag MUST be toggled by updating the Deployment environment variable and rolling restart (no runtime configuration reload)
- The system MUST log a warning on startup if the feature flag is disabled: "HubSpot registration service is DISABLED by feature flag"

#### Security

- The system MUST run as a non-root user (UID 1000) in the container
- The container filesystem MUST be read-only except for `/tmp` (mounted as tmpfs)
- The system MUST NOT log plaintext passwords, API keys, or tokens at any log level
- The system MUST sanitize error messages before logging: stack traces MUST NOT include environment variables or secrets
- The system MUST hash email addresses using SHA-256 before logging for privacy
- The system MUST use constant-time comparison for signature verification to prevent timing attacks
- The system MUST enforce TLS 1.2+ for all outbound API calls (HubSpot, Open edX, SendGrid)
- The system MUST NOT store passwords in environment variables or configuration files (only passed transiently from generation to API call to email)

### Non-Functional Requirements

#### Availability

- The service MUST achieve >= 99.5% uptime over a 30-day window
- The service MUST handle graceful shutdown: on SIGTERM, the service MUST stop accepting new webhooks, finish processing in-flight requests (up to 30 seconds), and then exit
- The service MUST have liveness probe (`GET /healthz`) and readiness probe (`GET /readyz`)
- The liveness probe MUST return `200 OK` if the Node.js process is running
- The readiness probe MUST return `200 OK` if the service can connect to Redis and the Open edX API is reachable
- The service MUST be deployed with at least 2 replicas for high availability
- The service MUST use Horizontal Pod Autoscaler (HPA) to scale from 2 to 10 replicas based on CPU utilization (target: 70%)

#### Latency

- The webhook endpoint MUST return `200 OK` within 2 seconds for 95% of requests
- End-to-end user creation (webhook receipt to welcome email sent) MUST complete within 10 seconds for 95% of requests
- HubSpot contact profile fetch MUST complete within 3 seconds for 95% of requests
- Open edX user creation API call MUST complete within 5 seconds for 95% of requests

#### Throughput

- The service MUST handle at least 100 concurrent webhook requests without degradation
- The service MUST process at least 50 user registrations per minute sustained
- The service MUST handle burst traffic of 500 registrations in 5 minutes (conference booth scenario)

#### Security

- All secrets MUST follow the secrets management pattern: Infisical → GCP SM → ExternalSecrets → K8s Secrets → env vars (per `specs/secrets-management_spec.md`)
- Webhook signature verification MUST reject 100% of requests with invalid signatures
- The service MUST NOT accept webhooks from unknown form GUIDs (allowlist enforcement)
- The service MUST log failed signature verifications with rate limiting (max 10 logs per minute to prevent log spam)
- The service MUST NOT expose internal error details to HubSpot (return generic error messages)

#### Observability

- The service MUST emit structured JSON logs to stdout with fields: `timestamp`, `level`, `service`, `message`, `contact_id`, `email_hash`, `error`, `duration_ms`
- The service MUST expose Prometheus metrics at `GET /metrics`:
  - `hubspot_webhook_requests_total` (counter, labels: `status_code`, `form_guid`)
  - `hubspot_webhook_processing_duration_seconds` (histogram, labels: `status`, `form_guid`)
  - `hubspot_user_creation_total` (counter, labels: `status`, `reason`) -- status: success/failure/duplicate, reason: api_error/network_error/duplicate_email
  - `hubspot_email_sent_total` (counter, labels: `status`, `language`, `email_type`) -- email_type: welcome/reminder
  - `hubspot_dlq_entries_total` (counter, labels: `reason`)
  - `hubspot_signature_verification_failures_total` (counter)
- The service MUST log all API calls (HubSpot, Open edX, SendGrid) with request/response status codes and durations
- The service MUST integrate with the observability stack (Prometheus, Loki, Grafana) per `specs/observability-stack_spec.md`

#### Resilience

- The service MUST implement circuit breakers for external API calls (HubSpot, Open edX, SendGrid) with failure threshold of 5 consecutive failures and half-open retry after 60 seconds
- The service MUST handle Redis connection failures gracefully: if Redis is unavailable, log an error but do not crash (degrade to no deduplication, no reminder scheduling)
- The service MUST handle Open edX API unavailability gracefully: enqueue to DLQ for retry, do not return 500 to HubSpot
- The service MUST use connection pooling for HTTP clients (max 100 connections, 10 seconds timeout)

---

## Acceptance Criteria

### Webhook Receiver

- [ ] AC-HUB-001: Given a valid HubSpot webhook POST with correct signature, when the endpoint receives the request, then it MUST return `200 OK` within 2 seconds
- [ ] AC-HUB-002: Given a HubSpot webhook with an invalid signature, when the endpoint receives the request, then it MUST return `401 Unauthorized` and log the failure
- [ ] AC-HUB-003: Given a webhook from an unknown form GUID (not in allowlist), when the endpoint receives the request, then it MUST return `400 Bad Request` and log the unknown form
- [ ] AC-HUB-004: Given the feature flag `HUBSPOT_REGISTRATION_ENABLED=false`, when the endpoint receives any request, then it MUST return `503 Service Unavailable`

### HubSpot Integration

- [ ] AC-HUB-005: Given a valid contactId, when the service fetches the contact profile from HubSpot, then it MUST use OAuth access token (not hardcoded PAT) and retry up to 3 times on 5xx errors
- [ ] AC-HUB-006: Given the OAuth access token is expired, when the service attempts to fetch a contact profile, then it MUST refresh the token using the refresh token and retry the request
- [ ] AC-HUB-007: Given a HubSpot contact with multi-select fields (`;` delimited), when the service parses the fields, then it MUST split them into arrays correctly

### User Creation

- [ ] AC-HUB-008: Given a new email address, when user creation is triggered, then the service MUST call `GET /api/user/v1/accounts?email={email}` to check for duplicates before creating
- [ ] AC-HUB-009: Given a duplicate email, when user creation is triggered, then the service MUST skip creation, log a warning with email hash, and still send the welcome email
- [ ] AC-HUB-010: Given a new user, when the service creates the account, then the username MUST be unique (format: `{email_prefix}_{random_4_digit}`)
- [ ] AC-HUB-011: Given user creation succeeds, when the service enriches the profile, then it MUST call `PATCH /api/user/v1/accounts/{username}` with extended profile fields including `hubspot_contact_id`

### Email Delivery

- [ ] AC-HUB-012: Given a successful user creation, when the welcome email is sent, then it MUST use the correct SendGrid template based on the form GUID language
- [ ] AC-HUB-013: Given a welcome email send, when the email is delivered, then it MUST include the generated password in plaintext (sent once, never stored)
- [ ] AC-HUB-014: Given a successful welcome email, when the service schedules the reminder, then it MUST create a Redis job with the password encrypted (AES-256-GCM) and scheduled for 7 days later
- [ ] AC-HUB-015: Given a 7-day reminder job is due, when the periodic processor runs, then it MUST send the reminder email using the correct language template and mark the job completed

### Idempotency

- [ ] AC-HUB-016: Given the same email is submitted twice within 24 hours, when both webhooks are received, then only one user creation MUST occur (deduplication via Redis)
- [ ] AC-HUB-017: Given a deduplication key exists in Redis, when a webhook is received, then the service MUST return `200 OK` immediately without processing

### Dead Letter Queue

- [ ] AC-HUB-018: Given user creation fails after 3 retries, when the failure is logged, then the webhook MUST be enqueued to the DLQ with full context (payload, error, timestamp)
- [ ] AC-HUB-019: Given a DLQ entry fails 3 retries, when the final retry fails, then an error notification email MUST be sent to `ops@mereka.dev` with the entry details
- [ ] AC-HUB-020: Given an admin replays a DLQ entry via the admin API, when the replay succeeds, then the entry MUST be marked as completed and removed from the DLQ

### Security

- [ ] AC-HUB-021: Given a signature verification failure, when the failure is logged, then the log MUST NOT include the full request body (only metadata: timestamp, source IP hash)
- [ ] AC-HUB-022: Given any log entry, when it is written, then it MUST NOT contain plaintext passwords, API keys, or full email addresses (use email hash)
- [ ] AC-HUB-023: Given the container is deployed, when inspected, then the filesystem MUST be read-only except for `/tmp` and the process MUST run as UID 1000 (non-root)

### Observability

- [ ] AC-HUB-024: Given the service is running, when the `/metrics` endpoint is queried, then it MUST return Prometheus metrics including `hubspot_webhook_requests_total`, `hubspot_user_creation_total`, `hubspot_email_sent_total`
- [ ] AC-HUB-025: Given a webhook is processed, when the request completes, then a structured JSON log entry MUST be emitted with `timestamp`, `level`, `contact_id`, `email_hash`, `duration_ms`
- [ ] AC-HUB-026: Given user creation success rate drops below 95% over 15 minutes, when the alert condition is met, then a critical alert MUST fire and route to `#ops-alerts` Slack channel

---

## Edge Cases

### Duplicate Username Collision

If the generated username (email prefix + random 4 digits) collides with an existing username (rare but possible), the Open edX API will return `409 Conflict`. The service must detect this, regenerate the username with a new random suffix, and retry up to 3 times. If all retries fail, enqueue to DLQ.

### HubSpot Form Field Schema Changes

If HubSpot adds or removes fields from the form, the service must handle missing fields gracefully (default to empty string) and ignore unknown fields. Admins must update the field mapping in the service code and redeploy.

### SendGrid Template Deprecation

If SendGrid deprecates a template ID, the welcome or reminder emails will fail. The service must detect the failure (4xx error from SendGrid), enqueue to DLQ, and send an error notification to ops. Ops must update the template IDs in the service configuration and redeploy.

### Redis Unavailability

If Redis is unavailable (connection timeout, authentication failure), the service degrades gracefully: deduplication is skipped (risk of duplicate user creation), reminder scheduling is skipped (users do not receive 7-day reminder), but user creation and welcome email still succeed. The service must log errors and emit a metric `redis_connection_failures_total`.

### Open edX API Rate Limiting

If the Open edX API rate-limits the service account (429 Too Many Requests), the service must back off exponentially and retry after the `Retry-After` header value. If the rate limit persists beyond 3 retries, enqueue to DLQ.

### HubSpot Webhook Replay After 24 Hours

HubSpot retries failed webhooks for 24 hours, then stops. If the service is down for >24 hours, some registrations will be lost. Ops must manually export contacts from HubSpot and replay via the admin API or Django management command.

### Multi-Language Template Missing Language

If a contact submits a form in a language for which no SendGrid template exists (e.g., a new Thai form is added), the service must fall back to the English template and log a warning. Ops must create the Thai template and update the service configuration.

### Password Generation Weak Randomness

If `crypto.randomBytes()` fails (extremely rare), the service must catch the exception and retry password generation up to 3 times. If all retries fail, enqueue to DLQ and send error notification. Do not fall back to weak randomness (Math.random).

### Consent Field Not "true"

If the HubSpot contact's `consent` field is missing or not `"true"` (user did not check the consent checkbox), the service must reject the webhook with `400 Bad Request` and log the rejection reason. No user account is created.

---

## Observability

### Logs

- All logs MUST be structured JSON written to stdout with the following fields:
  - `timestamp` (ISO 8601)
  - `level` (DEBUG, INFO, WARN, ERROR)
  - `service` (`"hubspot-registration-service"`)
  - `message` (human-readable string)
  - `contact_id` (HubSpot contactId or null)
  - `email_hash` (SHA-256 hash of email or null)
  - `form_guid` (HubSpot form GUID or null)
  - `duration_ms` (request processing time)
  - `error` (error message if applicable)
  - `stack` (stack trace if applicable, truncated to 1000 chars)
- Logs MUST be scraped by Promtail and forwarded to Loki with labels `namespace=mereka-lms`, `app=hubspot-registration-service`
- The service MUST log at INFO level for normal operations: webhook received, user created, email sent, reminder scheduled
- The service MUST log at WARN level for recoverable failures: HubSpot API retry, duplicate email, profile enrichment failure
- The service MUST log at ERROR level for unrecoverable failures: signature verification failure, DLQ enqueue, error notification sent

### Metrics

- The service MUST expose the following Prometheus metrics at `GET /metrics`:
  - `hubspot_webhook_requests_total` (counter, labels: `status_code`, `form_guid`) -- total webhook requests received
  - `hubspot_webhook_processing_duration_seconds` (histogram, labels: `status`, `form_guid`, buckets: 0.1, 0.5, 1, 2, 5, 10, 30) -- webhook processing latency
  - `hubspot_user_creation_total` (counter, labels: `status`, `reason`) -- total user creation attempts (status: success/failure/duplicate)
  - `hubspot_email_sent_total` (counter, labels: `status`, `language`, `email_type`) -- total emails sent (email_type: welcome/reminder)
  - `hubspot_dlq_entries_total` (counter, labels: `reason`) -- total DLQ entries created
  - `hubspot_signature_verification_failures_total` (counter) -- total signature verification failures
  - `hubspot_api_calls_total` (counter, labels: `api`, `status_code`) -- total external API calls (api: hubspot/openedx/sendgrid)
  - `hubspot_redis_operations_total` (counter, labels: `operation`, `status`) -- total Redis operations (operation: dedup_check/dedup_set/reminder_enqueue/reminder_process)
  - `nodejs_heap_size_bytes` (gauge) -- Node.js heap size
  - `nodejs_event_loop_lag_seconds` (gauge) -- Event loop lag
- Metrics MUST be scraped by Prometheus every 15 seconds via ServiceMonitor

### Alerts

- The service MUST define the following Prometheus alerts:
  - `HubSpotRegistrationHighFailureRate`: Fires if `rate(hubspot_user_creation_total{status="failure"}[15m]) > 0.05 * rate(hubspot_user_creation_total[15m])` (more than 5% failures over 15 min) → severity: critical, route to `#ops-alerts`
  - `HubSpotRegistrationServiceDown`: Fires if `up{job="hubspot-registration-service"} == 0` for 5 minutes → severity: critical, route to `#ops-alerts`
  - `HubSpotSignatureVerificationSpike`: Fires if `rate(hubspot_signature_verification_failures_total[5m]) > 10` (more than 10 failures in 5 min) → severity: warning, route to `#ops-warnings` (possible attack)
  - `HubSpotDLQBacklog`: Fires if `hubspot_dlq_entries_total > 50` → severity: warning, route to `#ops-warnings` (manual intervention needed)
  - `HubSpotEmailFailureRate`: Fires if `rate(hubspot_email_sent_total{status="failure"}[15m]) > 0.1 * rate(hubspot_email_sent_total[15m])` (more than 10% email failures over 15 min) → severity: warning, route to `#ops-warnings`

### Dashboards

- The service MUST have a Grafana dashboard with the following panels:
  - Webhook request rate (req/s) by status code and form GUID
  - User creation success vs. failure rate over time
  - Email delivery success vs. failure rate by language
  - Webhook processing latency (p50, p95, p99)
  - DLQ backlog count over time
  - External API call latency breakdown (HubSpot, Open edX, SendGrid)
  - Redis operation success rate
  - Node.js heap usage and event loop lag
  - Pod CPU and memory utilization

---

## Rollout & Rollback

### Rollout Plan

1. **Phase 0: Development (Week 1)**
   - Implement the service in Node.js with Express
   - Set up local testing with mock HubSpot webhooks and mock Open edX API
   - Add unit tests (>80% coverage) and integration tests

2. **Phase 1: Staging Deployment (Week 2)**
   - Build Docker image and push to Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx/hubspot-registration-service:staging`)
   - Deploy to staging K8s namespace with `HUBSPOT_REGISTRATION_ENABLED=false`
   - Configure ExternalSecrets for staging credentials (dev HubSpot app, staging SendGrid)
   - Test webhook signature verification with real HubSpot webhooks (use test form)
   - Test end-to-end flow: HubSpot form submission → user in staging Open edX → welcome email received

3. **Phase 2: Production Deployment (Week 3)**
   - Deploy to production K8s namespace with `HUBSPOT_REGISTRATION_ENABLED=false` (dark launch)
   - Configure ExternalSecrets for production credentials (prod HubSpot app, prod SendGrid)
   - Set up Prometheus alerts and Grafana dashboard
   - Run smoke tests: submit test form, verify user creation, verify email delivery

4. **Phase 3: Gradual Rollout (Week 4)**
   - Set `HUBSPOT_REGISTRATION_ENABLED=true` and restart pods
   - Monitor metrics for 24 hours: success rate, latency, DLQ backlog
   - If success rate >= 99.5% and no critical alerts, proceed
   - Update HubSpot webhook subscription to point to production endpoint
   - Monitor for 7 days, tracking reminder email delivery

5. **Phase 4: Deprecate Firebase Function (Week 5)**
   - After 7 days of stable operation, disable the Firebase Cloud Function
   - Archive the Firebase function code to Git for reference
   - Remove Azure AD B2C and MCT dependencies from the codebase

### Feature Flags

- `HUBSPOT_REGISTRATION_ENABLED` (env var, default: `"false"`)
  - `"false"`: Service returns `503 Service Unavailable` for all webhook requests
  - `"true"`: Service processes webhooks normally
- Feature flag toggling requires Deployment update and rolling restart (no runtime reload)

### Backward Compatibility

- The service replaces the Firebase function, which created users in MCT + Azure AD B2C
- The new service creates users in Open edX, which is a **breaking change** (different user database)
- Existing MCT users MUST be migrated to Open edX before enabling the service (covered by `specs/data-migrations-kajabi-mct_spec.md`)
- HubSpot form fields MUST remain compatible with the field mapping defined in this spec
- If HubSpot changes form fields, the service MUST be updated and redeployed (no auto-migration)

### Rollback Steps

1. If the service causes issues (user creation failures, email delivery failures, high error rate):
   - Set `HUBSPOT_REGISTRATION_ENABLED=false` via Deployment update and restart pods
   - Update HubSpot webhook subscription to point back to Firebase function (if still available)
   - Investigate errors via Grafana dashboard and Loki logs
   - Fix the issue in code, redeploy to staging, test, then retry production rollout

2. If the rollback must be immediate (service is completely non-functional):
   - Delete the K8s Deployment: `kubectl delete deployment hubspot-registration-service -n mereka-lms`
   - Update HubSpot webhook subscription to point back to Firebase function
   - File a post-mortem incident report

### Emergency Procedures

- **High failure rate (>5% user creation failures)**: Set feature flag to false, rollback webhook subscription, investigate via logs
- **Signature verification attack (>100 failures in 5 min)**: Service auto-rate-limits logging, but ops must investigate source IPs and potentially block at Cloudflare level
- **SendGrid account suspended (bounced rate too high)**: Disable the service, investigate bounce sources (invalid Kajabi emails?), clean up suppression list, request SendGrid account review
- **Redis data loss (reminder jobs lost)**: Acceptable degradation (reminder emails are nice-to-have, not critical). Ops can manually resend reminders via Django management command if needed

---

## Verification

```bash
# 1. Service is running with feature flag disabled (dark launch)
kubectl get deployment hubspot-registration-service -n mereka-lms  # READY: 2/2
kubectl get pods -n mereka-lms -l app=hubspot-registration-service  # STATUS: Running
kubectl logs -n mereka-lms -l app=hubspot-registration-service --tail=10 | grep "DISABLED"
# Output: "HubSpot registration service is DISABLED by feature flag"

# 2. ExternalSecrets are synced
kubectl get externalsecret hubspot-registration-secrets -n mereka-lms  # STATUS: SecretSynced
kubectl get secret hubspot-registration-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys'
# Output: ["HUBSPOT_CLIENT_ID", "HUBSPOT_CLIENT_SECRET", "HUBSPOT_REFRESH_TOKEN", "SENDGRID_API_KEY", "OPENEDX_SERVICE_ACCOUNT_USERNAME", "OPENEDX_SERVICE_ACCOUNT_PASSWORD"]

# 3. Health checks pass
kubectl exec -n mereka-lms deploy/hubspot-registration-service -- curl -s http://localhost:3000/healthz  # 200 OK
kubectl exec -n mereka-lms deploy/hubspot-registration-service -- curl -s http://localhost:3000/readyz  # 200 OK

# 4. Metrics endpoint is reachable
kubectl exec -n mereka-lms deploy/hubspot-registration-service -- curl -s http://localhost:3000/metrics | grep hubspot_webhook_requests_total
# Output: hubspot_webhook_requests_total{status_code="503",form_guid=""} 0

# 5. Enable feature flag and test webhook
kubectl set env deployment/hubspot-registration-service HUBSPOT_REGISTRATION_ENABLED=true -n mereka-lms
kubectl rollout status deployment/hubspot-registration-service -n mereka-lms  # READY
# Submit test HubSpot form with known email

# 6. Verify user created in Open edX
curl -s https://academyv2.mereka.io/api/user/v1/accounts?email=test@example.com | jq '.username'
# Output: "test_1234"

# 7. Verify welcome email sent (check SendGrid dashboard or email inbox)
# Expected: Email received with correct template, contains username and password

# 8. Verify reminder scheduled in Redis
kubectl exec -n mereka-lms deploy/redis -- redis-cli XLEN "hubspot:reminders"
# Output: 1

# 9. Verify Prometheus metrics updated
curl -s http://prometheus.mereka.dev/api/v1/query?query=hubspot_user_creation_total | jq '.data.result[0].value[1]'
# Output: "1" (one successful user creation)

# 10. Verify no errors in logs
kubectl logs -n mereka-lms -l app=hubspot-registration-service --tail=50 | jq 'select(.level=="ERROR")'
# Output: (empty)

# 11. Verify dead letter queue is empty
kubectl exec -n mereka-lms deploy/redis -- redis-cli XLEN "hubspot:dlq"
# Output: 0

# 12. Verify signature verification works (test with invalid signature)
curl -X POST https://academyv2.mereka.io/api/hubspot/webhook/registration \
  -H "Content-Type: application/json" \
  -H "X-HubSpot-Signature-v3: invalid" \
  -H "X-HubSpot-Request-Timestamp: $(date +%s)000" \
  -d '{"objectId": 123}'
# Output: 401 Unauthorized

# 13. Verify alert rules are loaded in Prometheus
curl -s http://prometheus.mereka.dev/api/v1/rules | jq '.data.groups[].rules[] | select(.alert=="HubSpotRegistrationHighFailureRate")'
# Output: (rule definition)

# 14. Verify Grafana dashboard exists
curl -s http://grafana.mereka.dev/api/search?query=HubSpot | jq '.[] | select(.title=="HubSpot Registration Service")'
# Output: (dashboard metadata)
```

---

## Open Questions

1. **Should reminder emails include a "Getting Started" guide link or video?** (Currently just credentials)
2. **Should the service auto-enroll users in an onboarding course?** (Future enhancement, not in v1 scope)
3. **What is the acceptable duplicate user creation rate?** (Target: <0.1% due to race conditions in Redis deduplication)
4. **Should we send error notifications for every failure or only after DLQ retries exhaust?** (Recommend: only after DLQ exhaustion to reduce noise)
5. **What is the maximum acceptable reminder email delay?** (Target: within 1 hour of scheduled time, acceptable: within 6 hours)
6. **Should the service support webhook replay for events older than 24 hours?** (Recommend: manual CSV import for bulk recovery, not automated replay)
7. **Should we expose a public API for HubSpot form submission status?** (Out of scope for v1; use HubSpot + Open edX admin UIs)
8. **What is the encryption algorithm for password storage in Redis reminder jobs?** (Recommend: AES-256-GCM with key from secrets)
