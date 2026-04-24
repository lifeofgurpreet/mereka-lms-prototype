---
title: "Badges & Credentials Enterprise Integration - Implementation Plan"
source_spec: "specs/badges-credentials-enterprise_spec.md"
created: "2026-02-10"
status: "draft"
---

# Implementation Tasks: Badges & Credentials Enterprise Integration

**Source Spec**: `specs/badges-credentials-enterprise_spec.md`

**Acceptance Criteria Count**: 32 ACs
**Requirements Count**: 50+ functional requirements across 8major categories

---

## Task Breakdown by Category

### Build

#### Phase 0: Infrastructure Preparation (Badgr Server Deployment)

- [ ] **[M]** Provision Badgr Server MySQL database in CloudSQL (`infrastructure/terraform/cloudsql.tf`) | AC: #1 | Depends: None
  - Create logical database `badgr_server` in shared Cloud SQL instance
  - Create dedicated MySQL user `badgr_user` with appropriategrants
  - Configure connection pooling for Badgr Server workload
  - Document credentials storage in Infisical

- [ ] **[L]** Build Badgr Server Docker image from upstream (`infrastructure/badgr/Dockerfile`) | AC: #1 | Depends: None
  - Clone badgr-server repository (pin stable version)
  - Create multi-stage Dockerfile: build + runtime
  - Install dependencies: xmlsec1, python-saml, celery, redisclient
  - Configure Django settings for K8s environment
  - Push image to `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/badgr-server`

- [ ] **[M]** Create Badgr Server K8s Deployment manifest (`deploy/k8s/base/apps/badgr-server/deployment.yaml`) | AC: #1,#2 | Depends: Docker image
  - Deployment with labels: `app.kubernetes.io/name: badgr-server`, `app.kubernetes.io/part-of: mereka-lms`
  - Resource requests/limits: 0.5 vCPU / 1 GB RAM baseline, adjust after load testing
  - Environment variables from ConfigMap and Secret
  - Readiness probe: `GET /health/` (200 OK)
  - Liveness probe: `GET /heartbeat/` (200 OK)
  - Mount badge-secrets volume for signing keys

- [ ] **[S]** Create Badgr Server K8s Service (`deploy/k8s/base/apps/badgr-server/service.yaml`) | AC: #1 | Depends: Deployment
  - ClusterIP service on port 8000
  - Selector matches Deployment labels
  - Service name: `badgr-server`

- [ ] **[M]** Create Badgr Worker Celery Deployment (`deploy/k8s/base/apps/badgr-worker/deployment.yaml`) | AC: #1 | Depends: Badgr Server image
  - Separate Deployment for async badge issuance tasks
  - Command: `celery -A badgr worker`
  - Same secrets/config as Badgr Server
  - Resource requests: 0.25 vCPU / 512 MB RAM
  - No service (worker does not listen on ports)

- [ ] **[M]** Configure Caddy reverse proxy for `badges.academyv2.mereka.io` (`deploy/k8s/base/apps/caddy/Caddyfile`) | AC: #3 | Depends: Badgr Service
  - Add route: `badges.academyv2.mereka.io` → `http://badgr-server:8000`
  - Automatic Let's Encrypt certificate (DNS-only mode for multi-level subdomain)
  - Headers: CORS for verification endpoint, security headers

- [ ] **[S]** Provision Badgr Server secrets in Infisical (`infrastructure/secrets/badge-secrets.txt`) | AC: #1 | Depends:None
  - `MEREKA_LMS_BADGR_SECRET_KEY` (Django secret key, generate with `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`)
  - `MEREKA_LMS_BADGR_MYSQL_PASSWORD` (database password)
  - `MEREKA_LMS_BADGR_SIGNING_KEY_RSA` (RSA-2048 private keyfor badge signing, generate with `openssl genrsa 2048`)
  - `MEREKA_LMS_BADGR_OAUTH2_SECRET` (OAuth2 client secret for LMS integration)
  - `MEREKA_LMS_BADGR_WEBHOOK_SIGNING_SECRET` (HMAC secret for webhook payload signing)

- [ ] **[M]** Create ExternalSecret manifest for Badgr secrets (`deploy/k8s/base/secrets/badge-secrets.yaml`) | Depends: Infisical secrets
  - Sync from Infisical → GCP Secret Manager → K8s Secret `badge-secrets`
  - Follow existing ExternalSecrets pattern from `deploy/k8s/base/secrets/`

#### OpenBadges Compliance

- [ ] **[M]** Implement OpenBadges 2.0 assertion format (`infrastructure/badgr/badges/assertion.py`) | AC: #5 | Depends: Badgr Server deployment
  - Assertion model with required fields: `@context`, `type`,`id`, `recipient`, `badge`, `issuedOn`, `verification`
  - Recipient identity hashing: SHA-256 with per-issuer salt
  - Hosted verification type: assertion URL publicly resolvable
  - Signed verification type: JWS-signed assertion JSON

- [ ] **[M]** Implement BadgeClass definition model (`infrastructure/badgr/badges/badge_class.py`) | AC: #5 | Depends: Assertion format
  - BadgeClass with: `name`, `description`, `image`, `criteria`, `issuer`, `tags`
  - Support alignment to competency frameworks (optional)
  - Support expiration policy (duration in days/months/years)

- [ ] **[M]** Implement Issuer Profile model (`infrastructure/badgr/badges/issuer.py`) | AC: #5 | Depends: BadgeClass model
  - Issuer with: `name`, `url`, `email`, `description`, `image`
  - Link to `EnterpriseCustomer` via `enterprise_customer_uuid` field

- [ ] **[S]** Implement JSON-LD context serving (`infrastructure/badgr/badges/jsonld.py`) | AC: #5 | Depends: Assertion format
  - Serve assertion JSON with `Content-Type: application/ld+json`
  - Include OpenBadges context URL

- [ ] **[M]** Implement OpenBadges 3.0 support (future-proofing) (`infrastructure/badgr/badges/ob3.py`) | Req: OB-3.0 | Depends: OB 2.0 implementation
  - Verifiable Credentials-based assertions
  - Feature flag: `ENABLE_OPENBADGES_3_0` (default: false)
  - Backward compatible with OB 2.0 verifiers

#### Badge Issuance Workflows

- [ ] **[L]** Implement automatic badge issuance from COURSE_COMPLETION event (`infrastructure/badgr/issuance/course_completion.py`) | AC: #5, #7 | Depends: OB 2.0 implementation
  - Consume `COURSE_COMPLETION` events from Redis Streams event bus
  - Lookup BadgeClass associated with course key
  - Check idempotency: (`learner_user_id`, `badge_class_id`,`course_key`) tuple
  - If badge not already issued, create assertion via Badgr API
  - Send email notification to learner
  - Log badge issuance event
  - Celery task with retry logic (5 retries, exponential backoff)

- [ ] **[L]** Implement automatic badge issuance from PROGRAM_COMPLETION event (`infrastructure/badgr/issuance/program_completion.py`) | AC: #6 | Depends: Course completion implementation
  - Consume `PROGRAM_COMPLETION` events from event bus
  - Lookup BadgeClass associated with program UUID
  - Same idempotency and retry logic as course badges

- [ ] **[M]** Implement manual badge issuance API endpoint (`infrastructure/badgr/api/manual_issue.py`) | AC: #8 | Depends: Badgr API
  - Admin portal calls `POST /api/v1/badges/issue/` with: `learner_email`, `badge_class_id`, `evidence_url` (optional), `narrative` (optional)
  - Validate admin has permissions for tenant
  - Issue badge via Badgr API
  - Send email notification

- [ ] **[M]** Implement bulk badge issuance from CSV (`infrastructure/badgr/api/bulk_issue.py`) | AC: #9 | Depends: Manualissuance API
  - Admin uploads CSV: `email`, `badge_class_id`, `evidence_url`, `narrative`
  - Process up to 1000 rows per batch
  - Celery task for async processing
  - Generate completion report with success/failure details
  - Target: complete within 10 minutes for 1000 badges

- [ ] **[M]** Implement badge notification email template (`infrastructure/badgr/templates/badge_issued.html`) | AC: #5 |Depends: Issuance implementation
  - Email includes: badge name, badge image, issuer name, claim link, LinkedIn share link
  - Responsive HTML template with tenant branding
  - Plain text fallback

- [ ] **[M]** Implement conditional badge issuance based on assessment scores (optional) (`infrastructure/badgr/issuance/assessment_conditions.py`) | Req: Assessment-based | Depends:Course completion
  - Feature flag: `ENABLE_ASSESSMENT_BASED_BADGES`
  - Configure score thresholds per BadgeClass (e.g., "Advanced" badge only if score >= 85%)
  - Query LMS grades API for assessment score
  - Issue badge only if threshold met

#### Multi-Tenant Badge Management

- [ ] **[M]** Implement per-tenant Issuer Profile creation (`infrastructure/badgr/admin/issuer_profile.py`) | AC: #10, #12| Depends: Issuer model
  - Django admin or admin portal API endpoint
  - Create Issuer linked to `EnterpriseCustomer` UUID
  - Populate issuer fields from tenant branding: logo, name,URL, contact email
  - Support multiple Issuer Profiles per tenant (optional, defer to Phase 2)

- [ ] **[L]** Implement BadgeClass CRUD in admin portal (`infrastructure/badgr/admin/badge_class_crud.py`) | AC: #10, #11| Depends: BadgeClass model
  - Admin portal views/API for: create, read, update, archive, delete BadgeClass
  - Badge template designer UI fields: name, description, image upload, criteria, tags, alignment, expiration
  - Tenant isolation: filter queryset by `issuer__enterprise_customer_uuid`

- [ ] **[M]** Implement badge image upload and validation (`infrastructure/badgr/storage/image_upload.py`) | AC: #10, #11| Depends: BadgeClass CRUD
  - Upload to GCS bucket or PersistentVolume
  - Validate: square aspect ratio (tolerance: 10%), PNG or SVG, max 1 MB
  - Generate thumbnail for display
  - Serve via CDN or Caddy

- [ ] **[M]** Implement Mereka Academy default issuer for non-enterprise learners (`infrastructure/badgr/issuance/default_issuer.py`) | AC: #10 | Depends: Issuer Profile creation
  - Create "Mereka Academy" Issuer Profile at deployment
  - Badge classes for public courses use default issuer

#### Learner Credential Portfolio

- [ ] **[L]** Implement credential portfolio page (`services/credential-portfolio/`) | AC: #13 | Depends: Badgr API
  - MFE route or LMS integration at `/credentials/portfolio/`
  - Display all badges earned by authenticated learner
  - Badge card: image, name, issuer, issuance date, expiration date, verification status
  - Filter by tenant if learner belongs to multiple enterprises

- [ ] **[M]** Implement badge assertion JSON download (`services/credential-portfolio/downloads.py`) | AC: #13 | Depends:Portfolio page
  - Button: "Download Badge JSON" → OpenBadges 2.0 baked assertion
  - Button: "Download Badge Image" → PNG with embedded assertion metadata (baked PNG)

- [ ] **[M]** Implement LinkedIn "Add to Profile" integration(`services/credential-portfolio/linkedin.py`) | AC: #14 | Depends: Portfolio page
  - One-click button redirects to LinkedIn certification addpage
  - Pre-populate: badge name (as certification name), issuername (as organization), issuance date, expiration date, credential URL
  - Use LinkedIn URL parameters method (no API key required)

- [ ] **[M]** Implement social sharing buttons (`services/credential-portfolio/social_sharing.py`) | AC: #14 | Depends: Portfolio page
  - Share to: Twitter/X, Facebook, copy link
  - Open Graph metadata for badge assertion URL

- [ ] **[S]** Implement public badge assertion page (`infrastructure/badgr/public/assertion_view.py`) | AC: #13 | Depends:Badgr Server
  - Public URL: `https://badges.academyv2.mereka.io/public/assertions/{uid}`
  - No authentication required
  - Display badge details with verification status

- [ ] **[M]** Implement public learner profile (opt-in) (`infrastructure/badgr/public/learner_profile.py`) | AC: #13 | Depends: Portfolio
  - Public URL: `https://badges.academyv2.mereka.io/public/profile/{learner_id}`
  - Learner controls visibility (privacy setting)
  - Display all non-revoked badges for learner

- [ ] **[S]** Implement revoked/expired badge UI indicators (`services/credential-portfolio/status_indicators.py`) | AC: #| Depends: Portfolio page
  - Badge card shows "Revoked" or "Expired" badge with reason

#### Public Verification

- [ ] **[M]** Implement public verification endpoint (`infrastructure/badgr/api/verification.py`) | AC: #14, #15, #16, #17| Depends: Badgr Server
  - `GET /public/assertions/{uid}` returns assertion JSON (HTTP 200 for valid, HTTP 404 for revoked/not found)
  - No authentication required
  - CORS headers: `Access-Control-Allow-Origin: *`
  - Caching headers: `Cache-Control: public, max-age=3600` for valid, `no-cache` for revoked

- [ ] **[S]** Implement signing public key endpoint (`infrastructure/badgr/api/signing_key.py`) | AC: #17 | Depends: BadgrServer
  - `GET /.well-known/badgeclass-signing-key` returns RSA public key (PEM or JWK format)
  - Used to verify JWS-signed assertions

- [ ] **[S]** Implement revocation list endpoint (`infrastructure/badgr/api/revocation_list.py`) | AC: #16 | Depends: Badgr Server
  - `GET /public/revocation-list/{issuer_id}` returns list ofrevoked assertion UIDs
  - For batch verification use cases

#### Blockchain Anchoring (Optional)

- [ ] **[L]** Implement blockchain anchoring service (`infrastructure/badgr/blockchain/anchor.py`) | Req: Blockchain | Depends: Badge issuance
  - Feature flag: `ENABLE_BLOCKCHAIN_ANCHORING` (per-tenant configurable)
  - Create Merkle tree of assertion hashes
  - Anchor Merkle root to public blockchain (Polygon recommended)
  - Asynchronous: do not block badge issuance
  - Batch assertions: min 10 or 24-hour window
  - Add `evidence` object to assertion JSON with tx hash andchain ID

- [ ] **[M]** Implement blockchain anchoring cost tracking (`infrastructure/badgr/blockchain/cost_tracking.py`) | Req: Blockchain | Depends: Anchoring service
  - Track gas costs per batch
  - Expose costs in analytics dashboard per tenant

- [ ] **[M]** Implement chain congestion handling (`infrastructure/badgr/blockchain/congestion.py`) | Edge Case: Blockchain | Depends: Anchoring service
  - Defer anchoring if gas price exceeds threshold (default:gwei for Ethereum)
  - Retry with higher gas price if tx not confirmed within 30minutes
  - Alert if deferred > 7 days

#### Enterprise HR API Integration

- [ ] **[L]** Implement enterprise badge API endpoints (`infrastructure/badgr/api/enterprise.py`) | AC: #23, #24 | Depends: Badgr API
  - `GET /api/v1/badges/enterprise/{uuid}/assertions/` -- paginated list, filter by `badge_class_id`, `issued_after`, `issued_before`, `status`
  - `GET /api/v1/badges/enterprise/{uuid}/assertions/{uid}/`-- single assertion detail
  - `GET /api/v1/badges/enterprise/{uuid}/badge-classes/` --list of badge classes
  - `GET /api/v1/badges/enterprise/{uuid}/analytics/` -- aggregate metrics
  - `GET /api/v1/badges/enterprise/{uuid}/learners/{user_id}/badges/` -- badges for specific learner
  - JWT authentication: `enterprise_admin` role required
  - Tenant isolation: filter by `enterprise_customer_uuid`

- [ ] **[M]** Implement webhook registration and delivery (`infrastructure/badgr/webhooks/webhook_delivery.py`) | AC: #24,#25 | Depends: Enterprise API
  - Admin registers webhook URLs via admin portal
  - Webhook events: `badge_issued`, `badge_revoked`, `badge_expired`, `badge_shared`
  - Payload: `event_type`, `assertion_uid`, `badge_class_name`, `learner_email_hash`, `enterprise_customer_uuid`, `timestamp`, `idempotency_key`
  - Retry failed deliveries: up to 5 times, exponential backoff (30s base, 30min max)
  - Suspend webhook after 10 consecutive failures, notify admin

- [ ] **[S]** Implement SCIM user-to-badge mapping export (`infrastructure/badgr/api/scim_export.py`) | Req: SCIM | Depends: Enterprise API
  - SCIM-compatible export format for HR systems using SCIM identity sync
  - Map badge data to SCIM schema extension

- [ ] **[M]** Implement webhook SSRF prevention (`infrastructure/badgr/webhooks/ssrf_prevention.py`) | Edge Case: Webhooks| Depends: Webhook delivery
  - Validate webhook URLs: HTTPS required, deny private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8,169.254.0.0/16, ::1)
  - Reject registration of invalid URLs

#### Badge Revocation

- [ ] **[M]** Implement badge revocation workflow (`infrastructure/badgr/api/revocation.py`) | AC: #18, #19, #20 | Depends: Badgr API
  - Admin revokes badge via admin portal: `POST /api/v1/badges/revoke/` with `assertion_uid`, `revocation_reason` (required, max 500 chars)
  - Update assertion status to revoked
  - Invalidate verification cache
  - Update learner portfolio to show "Revoked" status
  - Log revocation event: `assertion_uid`, `revoked_by`, `revocation_reason`, `enterprise_customer_uuid`, `timestamp`

- [ ] **[M]** Implement bulk badge revocation (`infrastructure/badgr/api/bulk_revocation.py`) | AC: #19 | Depends: Revocation workflow
  - Admin submits up to 500 assertion UIDs for revocation
  - Celery task for async processing
  - Target: complete within 5 minutes for 500 assertions

- [ ] **[S]** Handle blockchain-anchored badge revocation (`infrastructure/badgr/blockchain/revocation.py`) | AC: #20 | Depends: Revocation + Blockchain
  - Revocation updates revocation list (off-chain)
  - On-chain anchor remains unchanged (proves badge was oncevalid)

#### Credential Analytics and Reporting

- [ ] **[M]** Implement per-tenant badge analytics dashboard(`infrastructure/badgr/analytics/dashboard.py`) | AC: #29, #3| Depends: Enterprise API
  - Metrics: total badges issued, badge acceptance rate, sharing rate, verification count, top badge classes, expiration forecast, completion rate
  - Scoped to requesting tenant's `enterprise_customer_uuid`
  - Available via admin portal dashboard and API

- [ ] **[S]** Implement CSV export of badge analytics (`infrastructure/badgr/analytics/csv_export.py`) | Req: Analytics |Depends: Analytics dashboard
  - Export button in admin portal
  - CSV format for enterprise reporting

#### Anti-Fraud Measures

- [ ] **[M]** Implement cryptographic signing for assertions(`infrastructure/badgr/crypto/signing.py`) | AC: #26 | Depends: Badgr Server
  - Sign assertions with issuer private key (RSA-2048 or Ed25519)
  - JWS-signed assertion JSON
  - Store signing keys in K8s Secrets (via ExternalSecrets)

- [ ] **[M]** Implement verification request logging (`infrastructure/badgr/logging/verification_log.py`) | AC: #26, #28 |Depends: Verification endpoint
  - Log all verification requests: `assertion_uid`, `verifier_ip_hash`, `user_agent`, `timestamp`, `verification_result`
  - Retention: 90 days

- [ ] **[M]** Implement rate limiting on verification endpoint (`infrastructure/badgr/api/rate_limiting.py`) | AC: #27 | Depends: Verification endpoint
  - 100 requests per minute per IP address
  - HTTP 429 on exceeded, `Retry-After` header

- [ ] **[S]** Implement anomalous verification pattern detection (`infrastructure/badgr/security/anomaly_detection.py`) |AC: #28 | Depends: Verification logging
  - Alert if > 1000 verification requests for single assertion within 1 hour

- [ ] **[S]** Implement issuer signing key rotation (`infrastructure/badgr/crypto/key_rotation.py`) | Req: Anti-fraud | Depends: Signing
  - Annual key rotation workflow
  - Archive old public keys for verifying historical assertions

- [ ] **[S]** Implement CRL distribution for signed assertions (`infrastructure/badgr/crypto/crl.py`) | Req: Anti-fraud |Depends: Signing
  - Certificate Revocation List per issuer
  - Stable URL per issuer

### Test

#### Unit Tests

- [ ] **[M]** OpenBadges 2.0 assertion format unit tests (`tests/unit/test_badge_assertion_format.py`) | AC: #5 | Depends:Assertion implementation
  - Test all required fields present
  - Test recipient identity hashing
  - Test JSON-LD context

- [ ] **[M]** Badge issuance idempotency unit tests (`tests/unit/test_badge_issuance_idempotency.py`) | AC: #7 | Depends:Issuance implementation
  - Test duplicate issuance returns existing assertion
  - Test idempotency key generation

- [ ] **[M]** Badge image validation unit tests (`tests/unit/test_badge_image_validation.py`) | AC: #11 | Depends: Image upload
  - Test aspect ratio validation
  - Test file size validation
  - Test format validation (PNG/SVG)

- [ ] **[M]** Tenant isolation unit tests (`tests/unit/test_badge_tenant_isolation.py`) | AC: #10, #11 | Depends: BadgeClass CRUD
  - Test queryset filtering by tenant UUID
  - Test cross-tenant access prevention

- [ ] **[M]** Webhook SSRF prevention unit tests (`tests/unit/test_webhook_ssrf_prevention.py`) | Edge Case: Webhooks | Depends: SSRF prevention
  - Test private IP rejection
  - Test HTTPS enforcement

#### Integration Tests

- [ ] **[L]** Badgr Server deployment integration tests (`tests/integration/test_badgr_deployment.py`) | AC: #1, #2, #3, #| Depends: Badgr deployment
  - Test Badgr Server Deployment is running
  - Test health endpoint returns 200
  - Test external accessibility via Caddy
  - Test Celery worker Deployment is running

- [ ] **[L]** Badge issuance from COURSE_COMPLETION event integration tests (`tests/integration/test_course_completion_badge.py`) | AC: #5, #7 | Depends: Course completion issuance
  - Test event consumption creates badge
  - Test email notification sent
  - Test duplicate event does not create duplicate badge

- [ ] **[L]** Badge issuance from PROGRAM_COMPLETION event integration tests (`tests/integration/test_program_completion_badge.py`) | AC: #6 | Depends: Program completion issuance
  - Test program badge issued after all courses complete
  - Test idempotency

- [ ] **[M]** Manual badge issuance integration tests (`tests/integration/test_manual_badge_issuance.py`) | AC: #8 | Depends: Manual issuance API
  - Test admin issues badge via API
  - Test learner receives email
  - Test admin permissions enforced

- [ ] **[M]** Bulk badge issuance integration tests (`tests/integration/test_bulk_badge_issuance.py`) | AC: #9 | Depends:Bulk issuance API
  - Test CSV with 1000 rows processes successfully
  - Test completion report generated
  - Test invalid rows handled gracefully

- [ ] **[L]** Multi-tenant badge isolation integration tests(`tests/integration/test_multi_tenant_badge_isolation.py`) |AC: #10, #11 | Depends: Multi-tenant implementation
  - Test admin A cannot view admin B's badge classes
  - Test tenant A badges show tenant A branding
  - Test cross-tenant assertion access denied

- [ ] **[M]** Credential portfolio integration tests (`tests/integration/test_credential_portfolio.py`) | AC: #13 | Depends: Portfolio page
  - Test learner views all their badges
  - Test multi-tenant membership displays badges from all tenants
  - Test revoked/expired badges displayed correctly

- [ ] **[M]** LinkedIn integration tests (`tests/integration/test_linkedin_integration.py`) | AC: #14 | Depends: LinkedInintegration
  - Test "Add to LinkedIn" redirect
  - Test Open Graph metadata rendered

- [ ] **[M]** Public verification endpoint integration tests(`tests/integration/test_public_verification.py`) | AC: #14,#15, #16, #17 | Depends: Verification endpoint
  - Test valid assertion returns 200 with JSON
  - Test revoked assertion returns 404
  - Test CORS headers present
  - Test rate limiting enforced

- [ ] **[M]** Badge revocation integration tests (`tests/integration/test_badge_revocation.py`) | AC: #18, #19, #20 | Depends: Revocation workflow
  - Test single revocation updates assertion status
  - Test bulk revocation processes 500 assertions
  - Test blockchain-anchored badge revocation

- [ ] **[M]** Enterprise API integration tests (`tests/integration/test_enterprise_badge_api.py`) | AC: #23, #24 | Depends: Enterprise API
  - Test assertions list endpoint with filters
  - Test JWT authentication enforced
  - Test tenant isolation in API responses

- [ ] **[M]** Webhook delivery integration tests (`tests/integration/test_webhook_delivery.py`) | AC: #24, #25 | Depends:Webhook delivery
  - Test webhook triggered on badge issuance
  - Test webhook retry logic on failure
  - Test webhook suspended after 10 failures

- [ ] **[M]** Badge analytics integration tests (`tests/integration/test_badge_analytics.py`) | AC: #29, #30 | Depends: Analytics
  - Test metrics scoped to tenant
  - Test CSV export

#### End-to-End Tests

- [ ] **[L]** Full badge issuance E2E test (`tests/e2e/test_badge_issuance_flow.py`) | AC: #5-9 | Depends: All issuance implementations
  - Test: learner completes course → badge issued → email received → badge appears in portfolio
  - Test: learner downloads badge JSON and image
  - Test: learner shares badge to LinkedIn

- [ ] **[M]** Badge revocation E2E test (`tests/e2e/test_badge_revocation_flow.py`) | AC: #18-20 | Depends: Revocation implementation
  - Test: admin revokes badge → verification endpoint returns→ portfolio shows "Revoked"

- [ ] **[M]** Enterprise HR API E2E test (`tests/e2e/test_enterprise_hr_api_flow.py`) | AC: #23-25 | Depends: Enterprise API + webhooks
  - Test: enterprise admin queries API → receives badge data→ webhook delivers notification

#### Performance Tests

- [ ] **[M]** Badge issuance latency test (`tests/performance/test_badge_issuance_latency.py`) | NFR: Performance | Depends: Issuance implementation
  - Target: p95 <= 60 seconds from event to assertion + email
  - Load test: 1000 concurrent badge issuances

- [ ] **[M]** Verification endpoint latency test (`tests/performance/test_verification_latency.py`) | NFR: Performance | Depends: Verification endpoint
  - Target: p95 <= 200ms
  - Load test: 10,000 requests/minute

- [ ] **[M]** Bulk issuance performance test (`tests/performance/test_bulk_issuance_performance.py`) | NFR: Performance |Depends: Bulk issuance
  - Target: 1000 badges within 10 minutes

#### Security Tests

- [ ] **[M]** Badge cryptographic signing tests (`tests/security/test_badge_signing.py`) | AC: #26 | Depends: Signing implementation
  - Test JWS signature verification
  - Test signing key security (not exposed in logs/API)

- [ ] **[M]** Tenant isolation security tests (`tests/security/test_badge_tenant_isolation.py`) | AC: #10-12 | Depends: Multi-tenant implementation
  - Test queryset injection attempts
  - Test direct ID access across tenants

- [ ] **[M]** SSRF prevention security tests (`tests/security/test_webhook_ssrf.py`) | Edge Case: Webhooks | Depends: SSRFprevention
  - Test webhook URL validation blocks private IPs
  - Test malicious URL patterns rejected

### Observability

- [ ] **[M]** Implement badge-specific structured logging (`infrastructure/badgr/logging/logger.py`) | Req: Observability| Depends: All implementations
  - Structured JSON logs to stdout
  - Fields: `service_name: badgr-server`, `enterprise_customer_uuid`, `request_id`, `log_level`, `timestamp`
  - Badge issuance events: `event_type: badge_issued`, `assertion_uid`, `badge_class_id`, `enterprise_customer_uuid`, `learner_user_id`, `issuance_trigger`, `processing_duration_ms`
  - Badge revocation events: `event_type: badge_revoked`, `assertion_uid`, `badge_class_id`, `revoked_by`, `revocation_reason`, `was_blockchain_anchored`
  - Verification requests: `event_type: verification_request`, `assertion_uid`, `verifier_ip_hash`, `verification_result`,`response_time_ms`
  - Webhook deliveries: `event_type: webhook_delivery`, `webhook_url_hash`, `badge_event_type`, `delivery_attempt`, `http_status`, `response_time_ms`
  - Blockchain anchoring: `event_type: blockchain_anchor`, `batch_id`, `chain_id`, `transaction_hash`, `assertions_count`,`gas_used`, `cost_usd`, `anchor_status`
  - NO logging: raw email addresses, signing private keys, webhook URL paths, full assertion JSON

- [ ] **[M]** Implement Prometheus metrics for badges (`infrastructure/badgr/metrics/prometheus.py`) | Req: Observability| Depends: All implementations
  - `badge_issuance_total` (counter, labels: `enterprise_customer_uuid`, `badge_class_id`, `trigger`, `outcome`)
  - `badge_issuance_duration_seconds` (histogram, labels: `trigger`, `outcome`)
  - `badge_revocation_total` (counter, labels: `enterprise_customer_uuid`, `outcome`)
  - `badge_verification_requests_total` (counter, labels: `result`)
  - `badge_verification_latency_seconds` (histogram, labels:`result`)
  - `badge_sharing_total` (counter, labels: `enterprise_customer_uuid`, `platform`)
  - `badge_class_count` (gauge, labels: `enterprise_customer_uuid`, `status`)
  - `badge_webhook_deliveries_total` (counter, labels: `enterprise_customer_uuid`, `event_type`, `outcome`)
  - `badge_webhook_delivery_latency_seconds` (histogram)
  - `badge_blockchain_anchor_total` (counter, labels: `chain_id`, `outcome`)
  - `badge_blockchain_anchor_cost_usd` (counter, labels: `chain_id`, `enterprise_customer_uuid`)
  - `badge_blockchain_anchor_batch_size` (histogram)
  - `badge_issuance_queue_depth` (gauge)
  - `badgr_server_health` (gauge)
  - `badge_assertion_count` (gauge, labels: `enterprise_customer_uuid`, `status`)
  - `badge_portfolio_views_total` (counter, labels: `view_type`)

- [ ] **[M]** Configure Alertmanager alerts for badges (`infrastructure/observability/alerts/badges-credentials-alerts.yml`) | Req: Observability | Depends: Metrics
  - Critical: `badgr_server_health == 0` for > 3 consecutivechecks
  - Critical: `badge_issuance_queue_depth > 1000` for > 10 minutes
  - Critical: `badge_blockchain_anchor_total{outcome="failed"} > 3` in 1 hour
  - Warning: `badge_issuance_duration_seconds` p95 > 120 seconds over 15 minutes
  - Warning: `badge_verification_requests_total{result="rate_limited"} > 100` in 5 minutes
  - Warning: `badge_webhook_deliveries_total{outcome="failure"}` rate > 20% over 1 hour
  - Warning: `badge_blockchain_anchor_cost_usd` daily total >$50 (configurable)
  - Info: `badge_assertion_count{status="expired"}` increasesby > 100 in a day
  - Info: `badge_sharing_total == 0` for any enterprise overdays

- [ ] **[M]** Create Grafana dashboards for badges (`infrastructure/observability/dashboards/badges-credentials-dashboard.json`) | Req: Observability | Depends: Metrics
  - Badge Operations: Badgr Server health, issuance queue depth, issuance rate, verification rate, p95 latencies
  - Badge Analytics (per-tenant): Total badges issued by class, issuance trend, sharing rate, verification count, top classes, expiration forecast
  - Blockchain Anchoring: Anchor success rate, cost per batch, pending batches, gas price trend
  - Webhook Health: Delivery success rate per endpoint, retryrate, suspended webhooks, latency
  - Anti-Fraud: Verification requests by IP (top 10), anomalous spikes, rate limit triggers

### Docs

- [ ] **[L]** Write badges & credentials runbook (`docs/runbooks/badges-credentials-runbook.md`) | Depends: All implementations
  - Onboarding enterprise badge issuance
  - Creating and managing BadgeClasses
  - Troubleshooting badge issuance failures
  - Troubleshooting verification endpoint issues
  - Badge revocation procedure
  - Blockchain anchoring troubleshooting
  - Webhook delivery failures
  - Break-glass: manual badge issuance
  - Rollback procedures

- [ ] **[M]** Write badges & credentials architecture overview (`docs/architecture/badges-credentials-overview.md`) | Depends: All implementations
  - System architecture diagram
  - Data flow: course completion → badge issuance → verification
  - Multi-tenant isolation model
  - OpenBadges compliance
  - Blockchain anchoring architecture

- [ ] **[S]** Update troubleshooting guide (`docs/ops/runbooks/TROUBLESHOOTING.md`) | Depends: All implementations
  - Add badges section: common issues + fixes
  - Badge not issued after course completion
  - Verification endpoint returns 404
  - Webhook delivery failing

### Rollout

- [ ] **[S]** Create feature flags for badges (`infrastructure/tutor/config.yml`) | Depends: None
  - `ENABLE_BADGE_ISSUANCE` (global gate)
  - `ENABLE_BADGE_ADMIN_PORTAL` (badge management UI)
  - `ENABLE_BADGE_PORTFOLIO` (learner portfolio page)
  - `ENABLE_BADGE_SHARING` (LinkedIn/social sharing)
  - `ENABLE_BADGE_WEBHOOKS` (webhook delivery)
  - `ENABLE_BLOCKCHAIN_ANCHORING` (blockchain anchoring)
  - `ENABLE_BADGE_ENTERPRISE_API` (enterprise API endpoints)
  - All flags configurable per `enterprise_customer_uuid` where applicable

- [ ] **[M]** Phase 0: Deploy Badgr Server infrastructure todev | AC: #1-4 | Depends: Infrastructure tasks
  - Deploy Badgr Server and worker to GKE dev
  - Configure Caddy for `badges.academyv2.mereka.io`
  - Verify health endpoints
  - Run `kubectl get pods -n mereka-lms | grep badgr`
  - Monitor for 1 week

- [ ] **[M]** Phase 1: Deploy core badge issuance to dev | AC: #5-9 | Depends: Badge issuance implementations
  - Enable `ENABLE_BADGE_ISSUANCE`
  - Create pilot BadgeClasses for 3-5 courses
  - Test course completion → badge issuance
  - Verify OpenBadges 2.0 compliance (IMS validator)
  - Monitor for 1 week

- [ ] **[M]** Phase 2: Deploy multi-tenant support to dev | AC: #10-13 | Depends: Multi-tenant + portfolio implementations
  - Enable `ENABLE_BADGE_ADMIN_PORTAL` and `ENABLE_BADGE_PORTFOLIO`
  - Onboard one enterprise client with branded BadgeClasses
  - Test tenant isolation
  - Test learner portfolio
  - Monitor for 1 week

- [ ] **[M]** Phase 3: Deploy to production (pilot enterprise) | AC: All | Depends: Phase 2 success
  - Deploy Badgr Server to production GKE
  - Enable all feature flags for pilot tenant
  - Onboard pilot enterprise with 3-5 BadgeClasses
  - Run end-to-end verification
  - User acceptance testing with pilot client
  - Monitor badge metrics and alerts
  - Collect feedback

- [ ] **[M]** Phase 4: Deploy enterprise API and webhooks toproduction | AC: #23-25 | Depends: Phase 3 success
  - Enable `ENABLE_BADGE_WEBHOOKS` and `ENABLE_BADGE_ENTERPRISE_API`
  - Configure pilot client's HR system integration
  - Test webhook delivery
  - Monitor webhook metrics

- [ ] **[L]** Phase 5: Scale to 2-3 additional enterprise clients | AC: All | Depends: Phase 4 success
  - Onboard additional tenants
  - Load test: simulate 1000 concurrent badge issuances
  - Load test: 10,000 verification requests/minute
  - Run badge reconciliation job test
  - Remove per-tenant feature flags for stable integrations

- [ ] **[M]** Phase 6 (Optional): Deploy blockchain anchoring| Req: Blockchain | Depends: Phase 5 success
  - Enable `ENABLE_BLOCKCHAIN_ANCHORING` for interested tenants
  - Configure Polygon chain
  - Test anchoring flow end-to-end
  - Monitor anchoring costs and success rate

### Verification Scripts

- [ ] **[M]** Create badge verification script (`scripts/qa/verify-badges.sh`) | AC: #1-4 | Depends: Badgr deployment
  - Verify Badgr Server Deployment running
  - Verify health endpoints reachable
  - Verify external accessibility via `badges.academyv2.mereka.io`
  - Verify Badgr Worker Deployment running

- [ ] **[M]** Create badge issuance verification script (`scripts/qa/verify-badge-issuance.sh`) | AC: #5-9 | Depends: Issuance implementations
  - Simulate COURSE_COMPLETION event
  - Verify badge created in Badgr
  - Verify email notification sent
  - Verify assertion JSON is valid OpenBadges 2.0

- [ ] **[S]** Extend smoke tests with badge checks (`scripts/qa/smoke-test.sh`) | Depends: All implementations
  - Add badge portfolio page smoke test
  - Add verification endpoint smoke test

---

## Dependencies Summary

### Critical Path
1. Infrastructure (Badgr deployment) → OpenBadges compliance→ Badge issuance → Multi-tenant → Learner portfolio → Enterprise API → Tests → Rollout

### Parallel Tracks
- Blockchain anchoring (optional, can proceed after core badge issuance)
- Credential analytics (can proceed alongside enterprise API)
- Observability (can proceed alongside all implementations)
- Documentation (can proceed alongside implementations)

### Gating Tasks for Each Phase
- **Phase 0 (Infrastructure)**: Badgr Server deployed, healthchecks passing
- **Phase 1 (Core Issuance - Dev)**: Badge issuance from events working, OB 2.0 compliance validated, unit + integration tests passing
- **Phase 2 (Multi-tenant - Dev)**: Tenant isolation verified, portfolio page working, E2E tests passing
- **Phase 3 (Prod Pilot)**: All dev tests passing, pilot tenant onboarded, runbook complete, UAT passed
- **Phase 4 (Enterprise API)**: API tests passing, webhook delivery working, HR integration pilot complete
- **Phase 5 (Scale)**: Load tests passing, cross-tenant isolation verified, all observability operational

---

## Complexity Estimates

- **S (Small)**: <2 hours - Configuration, simple scripts, single-model CRUD
- **M (Medium)**: 2-8 hours - API endpoints, integration tests, middleware, UI components
- **L (Large)**: >8 hours - Complex pipelines (badge issuance, multi-tenant CRUD), E2E tests, multi-service coordination,blockchain integration

---

## Risk Mitigation

1. **Risk**: Badgr Server upstream maintenance stalled
   - **Mitigation**: Pin stable version, fork if necessary, upstream monitoring
   - **Task**: Document fork strategy in runbook

2. **Risk**: OpenBadges verifier ecosystem incompatibility
   - **Mitigation**: Validate with IMS validator + real verifiers (LinkedIn, Credly)
   - **Task**: OpenBadges compliance integration tests

3. **Risk**: Badge image storage scalability
   - **Mitigation**: Use GCS bucket with CDN, not PersistentVolume
   - **Task**: Badge image upload uses GCS

4. **Risk**: Blockchain gas cost spikes
   - **Mitigation**: Cost threshold alerts, defer anchoring if gas > threshold
   - **Task**: Blockchain congestion handling implementation

5. **Risk**: Cross-tenant badge data leakage
   - **Mitigation**: Queryset filtering at every API/admin layer, security tests
   - **Task**: Tenant isolation security tests

6. **Risk**: Webhook delivery overwhelming receiver
   - **Mitigation**: Rate limit: max 10 webhooks/second per endpoint
   - **Task**: Webhook delivery rate limiting

---

## Open Questions to Resolve Before Implementation

1. **Badgr Server version**: Use latest upstream release or pin specific version? Need upstream health assessment.
2. **Badge image storage**: GCS bucket vs PersistentVolume? GCS recommended but adds dependency.
3. **OpenBadges 3.0 timeline**: When should OB 3.0 become default? Need verifier ecosystem maturity assessment.
4. **Blockchain chain**: Polygon vs Ethereum mainnet? Per-tenant configurable? Need cost-benefit analysis.
5. **Credential portfolio location**: Standalone MFE vs LMS dashboard vs enterprise portal? Need UX input.
6. **LinkedIn integration method**: URL parameters (simple) vs Learning Content API (requires partnership)? URL method recommended.
7. **Assessment-based badges**: What assessment score data isavailable via event bus? Need LMS API investigation.
8. **Badgr Server resource sizing**: 0.5 vCPU / 1 GB RAM baseline needs validation with load testing.
9. **Badge expiration UX**: Should expired badges still showin portfolio? How to distinguish from revoked? Need UX input.
10. **SCIM schema extension**: What minimum SCIM fields for badge data? Need pilot client HR system assessment.
11. **Reconciliation job scope**: Backfill all historical completions or lookback window only? Need volume estimate.
12. **Multi-issuer per tenant**: v1 requirement or defer to Phase 2? Adds admin UX complexity.
13. **Badge domain**: `badges.academyv2.mereka.io` requires DNS-only + Let's Encrypt. Use simpler domain like `badges.mereka.io`?
14. **Verification log retention**: 90 days sufficient for compliance? Some industries may require longer.

---

## Self-Check (Before Implementation Begins)

- [ ] Every acceptance criterion (1-32) has at least one build task
- [ ] Every acceptance criterion has at least one test task (unit/integration/e2e)
- [ ] Edge cases from spec have negative test tasks
- [ ] File paths specified for each implementation task
- [ ] Dependencies identified (or marked "None")
- [ ] Complexity estimated (S/M/L) for each task
- [ ] Observability tasks cover logs, metrics, alerts, dashboards
- [ ] Rollout tasks include feature flags, phased deployment,verification
- [ ] Docs tasks include runbook, architecture overview, troubleshooting updates
- [ ] Source spec linked: `specs/badges-credentials-enterprise_spec.md`
