---
title: "Badges & Credentials Enterprise Integration"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
links:
  related_docs:
    - "docs/runbooks/badges-credentials-runbook.md"
    - "docs/operations/TROUBLESHOOTING.md"
    - "docs/architecture/badges-credentials-overview.md"
  related_specs:
    - "specs/enterprise-microservices_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/auth-sso-enterprise_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/k8s-deployment_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/analytics-pipeline_spec.md"
---

# Human Summary

## What we're building

An enterprise-grade digital badges and credentials system integrated into the existing Mereka Academy Open edX credentials service. The system enables automatic and manual issuance of OpenBadges 2.0/3.0 compliant digital badges when learners complete courses, programs, or specific assessments. Badges are issued through a self-hosted Badgr Server instance that acts as the badge issuer and verification backbone, eliminating ongoing subscription costs.

Each enterprise tenant (represented by an `EnterpriseCustomer` in the multi-tenancy architecture) configures their own badge templates, branding, and issuance rules. Issued badges are verifiable by any OpenBadges-compliant verifier, shareable to LinkedIn and other professional networks, and optionally anchored to a blockchain for tamper-evident long-term verification. Enterprise HR systems can consume badge and credential data via a REST API, enabling automated skill tracking, compliance attestation, and learning ROI reporting.

The system builds on the existing Open edX credentials service (already deployed at `credentials.academyv2.mereka.io` as a K8s Deployment running `overhangio/openedx-credentials:18.0.0`) by adding badge issuance capabilities, a self-hosted Badgr Server, multi-tenant badge template management, external verification infrastructure, and enterprise API integrations. The credentials service continues to handle course certificates (PDF/HTML); the badge system adds a parallel, standards-compliant digital credential layer.

## Why it matters

Enterprise clients purchasing Mereka Academy access for their workforce need measurable proof of learning outcomes. Course completion certificates are useful internally but lack external verifiability, portability, and integration with professional identity platforms. Digital badges compliant with the OpenBadges standard are the industry-accepted solution: they encode issuer identity, criteria, evidence, and recipient in a cryptographically signed JSON-LD assertion that any third party can independently verify.

For enterprise HR departments, badge data flowing into their talent management systems means automatic skill inventory updates, compliance tracking (particularly for regulated industries), and quantifiable training ROI without manual data entry. For learners, shareable LinkedIn badges increase the perceived value of Mereka Academy courses and drive organic discovery by peers. For Mereka Academy, enterprise badge capabilities are a competitive differentiator that directly supports the "many clients" business model, and the self-hosted Badgr Server approach eliminates per-badge SaaS fees that would scale linearly with learner volume.

## Success looks like

- Badge issuance is fully automated: a learner completing a badge-enabled course or program receives a verified OpenBadges 2.0/3.0 assertion within 60 seconds of completion event processing
- Multi-tenant branding: each enterprise tenant's badges display their logo, colors, and issuer identity -- not Mereka Academy's (unless the tenant is Mereka Academy itself)
- Zero cross-tenant badge leakage: tenant A's badge templates, issued badges, and analytics are invisible to tenant B
- External verification works without authentication: any third party with a badge URL can verify the assertion against the Badgr Server public verification endpoint
- LinkedIn sharing: learners can add badges to their LinkedIn profile with a single click from the credential portfolio page
- Enterprise HR API: at least one enterprise client's HR system consumes badge data via the REST API in a pilot integration
- Anti-fraud: revoked badges are immediately reflected in verification responses, and blockchain-anchored badges remain independently verifiable even if the Badgr Server is temporarily unavailable
- Badge analytics: enterprise admins can see badge issuance rates, sharing rates, and verification request counts on their analytics dashboard

---

# Agent Contract

## Scope

- In scope:
  - Self-hosted Badgr Server deployment on GKE (K8s Deployment in `mereka-lms` namespace)
  - OpenBadges 2.0 and 3.0 standard compliance for badge assertion format
  - Integration between Open edX credentials service and Badgr Server for badge issuance
  - Badge issuance workflows: course completion, program completion, manual admin award
  - Multi-tenant badge template management (per-`EnterpriseCustomer` badge classes)
  - Per-tenant issuer profiles with tenant branding (logo, name, URL, description)
  - Badge template designer (admin portal UI for creating/editing badge classes)
  - Learner credential portfolio (MFE page for viewing, managing, and sharing earned badges)
  - Public badge verification endpoint (unauthenticated, standards-compliant)
  - LinkedIn and social media sharing integration
  - Optional blockchain anchoring for tamper-evident verification
  - REST API for enterprise HR system integration (badge data export, webhook notifications)
  - Badge revocation workflow (admin-initiated, with verification propagation)
  - Credential analytics and reporting (per-tenant badge metrics)
  - Anti-fraud measures (cryptographic signing, revocation lists, verification logging)
  - Secrets management for Badgr Server credentials and signing keys
  - Observability (logs, metrics, alerts, dashboards) for badge issuance pipeline

- Out of scope:
  - Replacing the existing credentials service certificate functionality (PDF/HTML certificates continue as-is)
  - Micro-credentials or stackable credential pathways (future enhancement)
  - Badge marketplace or badge discovery across tenants
  - Gamification features (points, leaderboards) beyond badge issuance
  - Custom badge assertion extensions beyond the OpenBadges standard
  - Mobile app badge display (covered by `specs/mobile-apps-enterprise_spec.md`)
  - Badgr Server upstream feature development or forking
  - Payment for badge issuance (badges are included in enterprise subscriptions)
  - GDPR data subject access/deletion for badge data (covered by tenant offboarding in `specs/multi-tenancy-architecture_spec.md`)

## Non-goals

- Building a custom badge issuance engine from scratch (we deploy and integrate with Badgr Server)
- Supporting non-OpenBadges credential standards (e.g., CLR, Europass) in v1
- Providing a public badge directory or badge search engine
- Enabling cross-tenant badge recognition (tenant A cannot validate or accept tenant B's badges as credit)
- Offering a consumer-facing badge wallet separate from the Mereka Academy learner portal
- Implementing a custom blockchain (we use existing public chains or anchoring services)
- Replacing LinkedIn's native certification feature (we complement it with OpenBadges metadata)

## Assumptions

- The existing credentials service (`credentials.academyv2.mereka.io`) is operational and accessible within the cluster at `http://credentials:8000`
- The existing credentials service handles course certificates; badge issuance is an additive capability
- Badgr Server (open-source, Django-based) can be deployed as a separate K8s Deployment sharing the existing Cloud SQL and Redis infrastructure
- The GKE cluster has sufficient resource headroom for the Badgr Server Deployment (estimated: 0.5 vCPU, 1 GB RAM baseline)
- Enterprise customers are already modeled per the multi-tenancy architecture spec (`EnterpriseCustomer` UUID as tenant boundary)
- The Open edX event bus (Redis Streams) is operational and publishes `COURSE_COMPLETION` and `PROGRAM_COMPLETION` events
- The observability stack (Prometheus, Loki, Tempo) can ingest metrics/logs from the Badgr Server
- Enterprise admin portal MFE (`frontend-app-admin-portal`) can be extended with badge management views
- The learner portal or LMS profile page can embed a credential portfolio component
- Cloud SQL (MySQL 8) can accommodate one additional logical database for Badgr Server

---

## Requirements

### Functional

#### Badgr Server Deployment

- The system MUST deploy a self-hosted Badgr Server as a K8s Deployment named `badgr-server` in the `mereka-lms` namespace
- The Badgr Server Deployment MUST use the same label conventions as existing services (`app.kubernetes.io/name: badgr-server`, `app.kubernetes.io/instance: mereka-lms`, `app.kubernetes.io/part-of: mereka-lms`)
- The Badgr Server MUST have a corresponding K8s Service (ClusterIP) for internal routing on port 8000
- The Badgr Server MUST be externally accessible at `https://badges.academyv2.mereka.io` via Caddy reverse proxy or Ingress
- The Badgr Server MUST have its own logical MySQL database (`badgr_server`) within the shared Cloud SQL instance
- The Badgr Server MUST use the shared Redis instance for caching and Celery task processing
- The Badgr Server MUST have a dedicated Celery worker Deployment (`badgr-worker`) for asynchronous badge issuance tasks
- The Badgr Server Docker image MUST be built and pushed to `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/badgr-server`
- The Badgr Server MUST have readiness (`/health/`) and liveness (`/heartbeat/`) probes configured

#### OpenBadges Standard Compliance

- All issued badge assertions MUST comply with the OpenBadges 2.0 specification (IMS Global / 1EdTech)
- The system SHOULD support OpenBadges 3.0 (Verifiable Credentials-based) assertions for new badge classes created after the 3.0 migration date
- Each badge assertion MUST include the following required fields per the OpenBadges 2.0 specification:
  - `@context` (JSON-LD context URL)
  - `type` ("Assertion")
  - `id` (unique assertion URL, publicly resolvable)
  - `recipient` (hashed identity with `type`, `hashed`, `identity`, `salt`)
  - `badge` (URL to the BadgeClass definition)
  - `issuedOn` (ISO 8601 timestamp)
  - `verification` (type: "hosted" with assertion URL, or type: "signed" with JWS)
- Each BadgeClass definition MUST include:
  - `name`, `description`, `image` (PNG/SVG badge artwork URL)
  - `criteria` (URL or narrative describing how to earn the badge)
  - `issuer` (URL to Issuer Profile)
  - `tags` (categorization keywords)
- Each Issuer Profile MUST include:
  - `name`, `url`, `email`, `description`, `image` (issuer logo)
- The system MUST support both hosted verification (assertion available at a stable URL) and signed verification (JWS-signed assertion JSON)
- Badge assertion URLs MUST remain stable and publicly accessible for the lifetime of the credential (minimum 5 years after issuance)
- The system MUST serve assertion JSON with `Content-Type: application/ld+json` for JSON-LD compliance

#### Badge Issuance Workflows

- The system MUST automatically issue a badge when a learner completes a course that has an associated BadgeClass, triggered by the `COURSE_COMPLETION` event from the LMS event bus
- The system MUST automatically issue a badge when a learner completes a program that has an associated BadgeClass, triggered by the `PROGRAM_COMPLETION` event from the LMS event bus
- The system MUST support manual badge issuance by enterprise admins via the admin portal, with the following inputs: learner email or user ID, BadgeClass selection, optional evidence URL, optional narrative
- The system MUST support bulk badge issuance by enterprise admins (CSV upload with columns: `email`, `badge_class_id`, `evidence_url`, `narrative`), processing up to 1000 badges per batch
- Badge issuance MUST be idempotent: issuing the same badge to the same learner for the same course/program MUST NOT create a duplicate assertion; the existing assertion MUST be returned
- The system MUST send an email notification to the learner when a badge is issued, containing: badge name, badge image, issuer name, a link to claim/view the badge, and a link to share on LinkedIn
- The system MUST support badge issuance with evidence: the assertion MAY include one or more evidence objects linking to the learner's work (project URL, assessment result URL, portfolio link)
- The system SHOULD support conditional badge issuance based on assessment score thresholds (e.g., issue "Advanced" badge only if final exam score >= 85%)

#### Multi-Tenant Badge Management

- Each `EnterpriseCustomer` MUST have at least one Issuer Profile in the Badgr Server, identified by the `enterprise_customer_uuid`
- The Issuer Profile MUST use the tenant's branding: tenant logo, tenant name, tenant URL, tenant contact email
- The system MUST support multiple Issuer Profiles per tenant (e.g., separate issuers for different departments or business units)
- BadgeClass templates MUST be scoped to an Issuer Profile (and therefore to a tenant)
- Enterprise admins MUST be able to create, edit, archive, and delete BadgeClass templates for their tenant via the admin portal
- BadgeClass templates MUST support the following configurable fields:
  - Badge name (required, max 128 characters)
  - Badge description (required, max 500 characters)
  - Badge image (required, PNG or SVG, max 1 MB, recommended 400x400px)
  - Criteria narrative (required, rendered as Markdown)
  - Criteria URL (optional, external link to detailed criteria)
  - Tags (optional, for categorization and filtering)
  - Alignment (optional, mapping to competency frameworks, skills ontologies, or regulatory requirements)
  - Expiration policy (optional, duration after issuance in days/months/years)
- The system MUST enforce tenant isolation: an enterprise admin MUST NOT view, edit, or issue badges from BadgeClasses belonging to a different tenant
- The system MUST support a "Mereka Academy" default tenant issuer for non-enterprise (individual) learners
- Badge images uploaded by enterprise admins MUST be stored in a persistent volume or object storage (GCS bucket), not in the database
- The system MUST validate badge images: dimensions MUST be square (tolerance: 10% aspect ratio variance), format MUST be PNG or SVG, file size MUST NOT exceed 1 MB

#### Learner Credential Portfolio

- The system MUST provide a credential portfolio page accessible to authenticated learners at `https://academyv2.mereka.io/credentials/portfolio/` (or as an MFE route)
- The portfolio page MUST display all badges earned by the learner across all their enterprise memberships
- Each badge in the portfolio MUST display: badge image, badge name, issuer name, issuance date, expiration date (if applicable), verification status
- The portfolio MUST allow the learner to download the badge assertion as a JSON file (OpenBadges 2.0 baked assertion)
- The portfolio MUST allow the learner to download the badge image with embedded assertion metadata (baked PNG)
- The portfolio MUST provide a one-click "Add to LinkedIn" button for each badge that pre-populates the LinkedIn certification dialog with: badge name, issuer name (as organization), issuance date, expiration date, and credential URL
- The portfolio MUST provide a shareable public URL for each individual badge assertion (no authentication required to view the badge details)
- The portfolio MUST provide a shareable public profile URL that displays all public (non-revoked) badges for a learner (opt-in, learner controls visibility)
- The portfolio SHOULD support social sharing to Twitter/X, Facebook, and generic "copy link" for each badge
- The portfolio MUST clearly indicate if a badge has been revoked or has expired

#### Public Verification

- The Badgr Server MUST expose a public verification endpoint at `https://badges.academyv2.mereka.io/public/assertions/{assertion_uid}` that returns the full assertion JSON without requiring authentication
- The verification endpoint MUST return HTTP 200 with the assertion JSON for valid, non-revoked assertions
- The verification endpoint MUST return HTTP 404 for assertions that have been revoked, with a response body indicating revocation status and date
- The verification endpoint MUST return HTTP 404 for assertion UIDs that do not exist
- The system MUST support verification of signed assertions (JWS): the Badgr Server MUST expose the public signing key at a stable URL (`https://badges.academyv2.mereka.io/.well-known/badgeclass-signing-key`)
- The system MUST maintain a revocation list endpoint (`https://badges.academyv2.mereka.io/public/revocation-list/{issuer_id}`) that lists all revoked assertion UIDs for a given issuer, for batch verification use cases
- Verification endpoint responses MUST include appropriate caching headers: `Cache-Control: public, max-age=3600` for valid assertions, `Cache-Control: no-cache` for revoked assertions
- The verification endpoint MUST support CORS (Access-Control-Allow-Origin: *) to enable client-side verification from any domain

#### Blockchain Anchoring (Optional)

- The system SHOULD support optional blockchain anchoring of badge assertions for tamper-evident long-term verification
- When blockchain anchoring is enabled for a BadgeClass, the system MUST create a Merkle tree of assertion hashes and anchor the Merkle root to a public blockchain
- The system SHOULD use Ethereum mainnet or a Layer 2 chain (Polygon, Arbitrum) for anchoring, with the chain configurable per tenant
- Blockchain anchoring MUST NOT block badge issuance: anchoring MUST be performed asynchronously after the assertion is created and hosted
- The assertion JSON MUST include an `evidence` object referencing the blockchain transaction hash and chain ID when anchoring is complete
- The system MUST provide a verification path that works even if the Badgr Server is temporarily unavailable: a verifier with the baked badge image can extract the assertion hash, look up the Merkle root on-chain, and verify inclusion
- Blockchain anchoring MUST batch assertions (minimum batch size: 10 or time-window of 24 hours, whichever comes first) to minimize transaction costs
- The system MUST track blockchain anchoring costs per tenant and expose them in the analytics dashboard

#### Enterprise HR API Integration

- The system MUST expose a REST API for enterprise HR systems to consume badge data, scoped by `enterprise_customer_uuid`
- The API MUST support the following endpoints:
  - `GET /api/v1/badges/enterprise/{enterprise_customer_uuid}/assertions/` -- paginated list of all assertions issued to the enterprise's learners
  - `GET /api/v1/badges/enterprise/{enterprise_customer_uuid}/assertions/{assertion_uid}/` -- single assertion detail
  - `GET /api/v1/badges/enterprise/{enterprise_customer_uuid}/badge-classes/` -- list of badge classes available to the enterprise
  - `GET /api/v1/badges/enterprise/{enterprise_customer_uuid}/analytics/` -- aggregate badge metrics (issued count, sharing count, verification count)
  - `GET /api/v1/badges/enterprise/{enterprise_customer_uuid}/learners/{user_id}/badges/` -- all badges for a specific learner
- All enterprise API endpoints MUST require JWT authentication with the `enterprise_admin` role for the specified `enterprise_customer_uuid`
- The API MUST support filtering assertions by: `badge_class_id`, `issued_after`, `issued_before`, `learner_email_hash`, `status` (active, revoked, expired)
- The API MUST support webhook notifications: enterprise admins MUST be able to register webhook URLs that receive `POST` notifications for badge events (`badge_issued`, `badge_revoked`, `badge_expired`, `badge_shared`)
- Webhook payloads MUST include: `event_type`, `assertion_uid`, `badge_class_name`, `learner_email_hash`, `enterprise_customer_uuid`, `timestamp`
- Webhook delivery MUST retry failed deliveries (HTTP non-2xx response) up to 5 times with exponential backoff (base: 30s, max: 30min)
- The system MUST support SCIM-compatible user-to-badge mapping exports for HR systems that use SCIM for identity sync

#### Badge Revocation

- Enterprise admins MUST be able to revoke individual badge assertions via the admin portal
- Badge revocation MUST accept a revocation reason (required, free text, max 500 characters)
- Revoked badges MUST immediately reflect in verification responses: the public assertion URL MUST return HTTP 404 with revocation metadata
- Revoked badges MUST appear as "Revoked" in the learner's credential portfolio with the revocation reason visible
- Badge revocation MUST be logged as an auditable event with: `assertion_uid`, `revoked_by` (admin user ID), `revocation_reason`, `enterprise_customer_uuid`, `timestamp`
- The system MUST support bulk badge revocation (up to 500 assertions per batch) via the admin portal or API
- Revoked badges MUST NOT be re-issuable to the same learner for the same BadgeClass unless the admin explicitly creates a new assertion
- If a badge is blockchain-anchored, revocation MUST update the revocation list but MUST NOT attempt to modify the blockchain record (revocation is an off-chain status update; the on-chain anchor proves the badge was once valid)

#### Credential Analytics and Reporting

- The system MUST provide per-tenant badge analytics accessible via the enterprise admin portal
- Analytics MUST include the following metrics:
  - Total badges issued (by time period, by badge class)
  - Badge acceptance rate (issued vs. claimed by learner)
  - Badge sharing rate (number of badges shared to LinkedIn/social)
  - Verification request count (total third-party verification lookups)
  - Top badge classes by issuance volume
  - Badge expiration forecast (badges expiring in next 30/60/90 days)
  - Learner badge completion rate (badges earned / badges available * 100)
- Analytics data MUST be scoped to the requesting tenant's `enterprise_customer_uuid`
- Analytics MUST be available via both the admin portal dashboard and the enterprise API (`/analytics/` endpoint)
- The system SHOULD support CSV export of badge analytics data for enterprise reporting

#### Anti-Fraud Verification Measures

- All badge assertions MUST be cryptographically signed using the issuer's private key (RSA-2048 or Ed25519)
- Issuer signing keys MUST be stored in K8s Secrets (via ExternalSecrets from Infisical), not in the database or application code
- The system MUST rotate issuer signing keys annually; previously signed assertions MUST remain verifiable using archived public keys
- The system MUST log all verification requests with: `assertion_uid`, `verifier_ip` (hashed), `user_agent`, `timestamp`, `verification_result` (valid, revoked, not_found, invalid_signature)
- The system MUST implement rate limiting on the public verification endpoint: 100 requests per minute per IP address to prevent enumeration attacks
- The system MUST hash learner email addresses in badge assertions using SHA-256 with a per-issuer salt (per OpenBadges spec) to prevent recipient enumeration from public assertions
- The system MUST detect and alert on anomalous verification patterns: more than 1000 verification requests for a single assertion within 1 hour MUST trigger an alert
- The system MUST support CRL (Certificate Revocation List) distribution for signed assertions, published at a stable URL per issuer

### Non-functional (NFRs)

#### Performance

- Badge issuance (from event receipt to assertion creation and email notification) p95 latency MUST be <= 60 seconds
- Public badge verification endpoint p95 latency MUST be <= 200ms
- Enterprise badge API list endpoints p95 latency MUST be <= 500ms for up to 100 items per page
- Badge template creation/update in admin portal p95 latency MUST be <= 2 seconds
- Bulk badge issuance (1000 badges via CSV) MUST complete within 10 minutes
- Credential portfolio page load p95 latency MUST be <= 3 seconds for a learner with up to 50 badges
- Blockchain anchoring batch processing MUST complete within 30 minutes of batch trigger

#### Reliability

- The Badgr Server MUST be available 99.9% of the time (measured monthly, excluding planned maintenance)
- Badge assertion URLs MUST remain accessible for a minimum of 5 years after issuance (data retention commitment)
- The badge issuance pipeline MUST implement at-least-once delivery: if the `COURSE_COMPLETION` event is received but badge issuance fails, the system MUST retry up to 5 times with exponential backoff (base: 10s, max: 5min)
- The system MUST gracefully degrade if the Badgr Server is unavailable: course completion events MUST be queued and processed when the server recovers
- Webhook delivery MUST guarantee at-least-once delivery with deduplication guidance (include `idempotency_key` in payload)

#### Security

- All communication between the credentials service and Badgr Server MUST use internal K8s DNS (`http://badgr-server:8000`), not external URLs
- Badgr Server API endpoints (non-public) MUST enforce JWT-based authentication
- Issuer signing private keys MUST NOT be exposed via any API endpoint or log
- Badge image uploads MUST be scanned for malware/injection (file type validation, no executable content)
- The enterprise badge API MUST enforce tenant isolation at the queryset level (`filter(enterprise_customer_uuid=...)`) on every query
- Webhook URLs MUST be validated: MUST use HTTPS, MUST NOT target private IP ranges (SSRF prevention)
- API rate limiting: 100 requests/minute per enterprise admin user, 1000 requests/minute per service account

#### Privacy

- The system MUST support learner opt-out: a learner MUST be able to make their public credential profile private (badges still exist but public profile URL returns 404)
- Badge assertions MUST hash recipient identities per the OpenBadges specification; raw email addresses MUST NOT appear in public assertion JSON
- The system MUST respect Data Sharing Consent (DSC): badge data for enterprise API endpoints MUST only include learners who have granted DSC to the requesting enterprise
- Badge verification logs MUST NOT store verifier identity beyond a hashed IP; logs MUST be retained for 90 days maximum

---

## Acceptance Criteria

### Badgr Server Deployment

- [ ] AC-001: Given the K8s manifests are applied, when `kubectl get deployment badgr-server -n mereka-lms` is run, then the deployment exists with READY replicas >= 1
- [ ] AC-002: Given the Badgr Server is running, when `curl http://badgr-server:8000/health/` is called from within the cluster, then the response is HTTP 200
- [ ] AC-003: Given the Badgr Server is externally accessible, when `curl https://badges.academyv2.mereka.io/health/` is called, then the response is HTTP 200
- [ ] AC-004: Given the badgr-worker Deployment is running, when `kubectl get deployment badgr-worker -n mereka-lms` is run, then the deployment exists with READY replicas >= 1

### Badge Issuance

- [ ] AC-005: Given a course with an associated BadgeClass and a learner who completes the course, when the `COURSE_COMPLETION` event is processed, then a valid OpenBadges 2.0 assertion is created in Badgr Server and an email notification is sent to the learner within 60 seconds
- [ ] AC-006: Given a program with an associated BadgeClass and a learner who completes all courses in the program, when the `PROGRAM_COMPLETION` event is processed, then a valid OpenBadges 2.0 assertion is created for the program badge
- [ ] AC-007: Given a learner who has already earned a badge for course X, when the same learner completes course X again (re-enrollment), then no duplicate assertion is created and the existing assertion is returned
- [ ] AC-008: Given an enterprise admin in the admin portal, when they submit a manual badge issuance request with a valid learner email and BadgeClass, then the badge is issued and the learner receives a notification email
- [ ] AC-009: Given an enterprise admin uploads a CSV with 1000 badge issuance rows, when the bulk issuance is submitted, then all 1000 badges are issued within 10 minutes and a completion report is available in the admin portal

### Multi-Tenant Isolation

- [ ] AC-010: Given enterprise customer A and enterprise customer B both have BadgeClasses, when admin A calls `GET /api/v1/badges/enterprise/{uuid_A}/badge-classes/`, then only badge classes belonging to tenant A are returned
- [ ] AC-011: Given enterprise customer A has issued badges, when admin B calls `GET /api/v1/badges/enterprise/{uuid_A}/assertions/`, then the response is HTTP 403 Forbidden
- [ ] AC-012: Given enterprise customer A's issuer profile, when the badge assertion JSON is inspected, then the issuer name, logo, and URL reflect tenant A's branding, not Mereka Academy's default branding
- [ ] AC-013: Given a learner belonging to both enterprise customer A and B, when they view their credential portfolio, then they see badges from both tenants clearly labeled by issuer

### Public Verification

- [ ] AC-014: Given a valid, non-revoked badge assertion, when `GET https://badges.academyv2.mereka.io/public/assertions/{uid}` is called without authentication, then the response is HTTP 200 with valid OpenBadges 2.0 assertion JSON and Content-Type `application/ld+json`
- [ ] AC-015: Given a revoked badge assertion, when `GET https://badges.academyv2.mereka.io/public/assertions/{uid}` is called, then the response is HTTP 404 with a body indicating the assertion was revoked and the revocation date
- [ ] AC-016: Given the public verification endpoint, when a request is made with `Origin: https://example.com`, then the response includes `Access-Control-Allow-Origin: *`
- [ ] AC-017: Given the signing public key endpoint, when `GET https://badges.academyv2.mereka.io/.well-known/badgeclass-signing-key` is called, then the response contains the public key in PEM or JWK format

### Badge Revocation

- [ ] AC-018: Given an enterprise admin revokes a badge assertion with reason "Employment terminated", when the revocation is processed, then the public assertion URL returns HTTP 404 with revocation metadata and the learner's portfolio shows "Revoked" status
- [ ] AC-019: Given a bulk revocation of 500 assertions, when the revocation is submitted, then all 500 assertions are revoked within 5 minutes and the revocation list endpoint is updated
- [ ] AC-020: Given a revoked badge that was blockchain-anchored, when the revocation list is checked, then the assertion UID appears in the revocation list but the on-chain anchor transaction is unchanged

### LinkedIn Integration

- [ ] AC-021: Given a learner views a badge in their credential portfolio, when they click "Add to LinkedIn", then they are redirected to LinkedIn's certification add page with badge name, issuer organization, dates, and credential URL pre-populated
- [ ] AC-022: Given a badge with a public assertion URL, when the URL is shared on LinkedIn or social media, then the page renders appropriate Open Graph metadata (title, description, badge image)

### Enterprise HR API

- [ ] AC-023: Given a valid enterprise admin JWT for tenant A, when `GET /api/v1/badges/enterprise/{uuid_A}/assertions/?issued_after=2026-01-01&badge_class_id=xyz` is called, then only matching assertions for tenant A's learners are returned with pagination
- [ ] AC-024: Given an enterprise admin registers a webhook URL, when a badge is issued to one of their learners, then the webhook endpoint receives a POST with `event_type: badge_issued` within 60 seconds
- [ ] AC-025: Given a webhook delivery fails (HTTP 500), when the system retries, then it retries up to 5 times with exponential backoff and logs each failure

### Anti-Fraud

- [ ] AC-026: Given a badge assertion, when the assertion JSON is inspected, then the `recipient.identity` field contains a SHA-256 hash of the email (not the plaintext email)
- [ ] AC-027: Given more than 100 verification requests from a single IP within 1 minute, when the next request arrives, then the response is HTTP 429 with a Retry-After header
- [ ] AC-028: Given more than 1000 verification requests for a single assertion within 1 hour, then an alert is triggered in the observability stack

### Credential Analytics

- [ ] AC-029: Given an enterprise admin accesses the badge analytics dashboard, when the page loads, then it displays total badges issued, sharing rate, verification count, and top badge classes for their tenant only
- [ ] AC-030: Given an enterprise admin calls `GET /api/v1/badges/enterprise/{uuid}/analytics/`, then the response includes aggregate metrics scoped to the requesting tenant

### Observability

- [ ] AC-031: Given the Badgr Server is running, when `/metrics` is scraped by Prometheus, then badge-specific metrics (issuance count, verification latency, queue depth) are present
- [ ] AC-032: Given a badge issuance fails, when the error is logged, then the log entry includes `enterprise_customer_uuid`, `badge_class_id`, `learner_user_id`, `error_type`, and `correlation_id`

---

## Edge Cases

### Badge Issuance Edge Cases

- **Event bus message loss**: If a `COURSE_COMPLETION` event is lost or not delivered, the system MUST support a reconciliation job (Celery periodic task, configurable interval, default: every 6 hours) that queries the LMS for recent completions and issues any missing badges. The reconciliation MUST be idempotent
- **Learner completes course before badge class exists**: If a learner completes a course and a BadgeClass is later created for that course, the system MUST NOT retroactively issue badges unless the enterprise admin explicitly triggers a backfill via the admin portal. This prevents unexpected badge issuance for historical completions
- **Badgr Server unavailable during issuance**: If the Badgr Server is unreachable when a badge issuance is attempted, the Celery task MUST retry with exponential backoff (base: 10s, max: 5min, max retries: 5). If all retries fail, the task MUST be moved to a dead letter queue and an alert triggered
- **Duplicate event processing**: If the event bus delivers the same `COURSE_COMPLETION` event twice (at-least-once delivery), the badge issuance logic MUST deduplicate using the combination of `(learner_user_id, badge_class_id, course_key)` as an idempotency key. No duplicate assertion is created
- **Bulk issuance with invalid rows**: If a CSV bulk issuance contains 1000 rows and row #500 has an invalid email format, the system MUST process all valid rows and return a detailed error report listing failed rows with reasons. This is NOT all-or-nothing (unlike license assignment) because badge issuance rows are independent

### Multi-Tenant Edge Cases

- **Tenant deactivation with active badges**: If an `EnterpriseCustomer` is deactivated, all badges issued under that tenant's issuer profiles MUST remain publicly verifiable. The issuer profile MUST NOT be deleted. New badge issuance for the tenant MUST be blocked
- **Issuer profile branding update**: If a tenant updates their issuer profile (logo, name), existing badge assertions MUST NOT be modified. The issuer profile URL returns the current branding; assertion JSON references the issuer URL, so verifiers always see the latest branding. The system SHOULD maintain an issuer profile version history for audit purposes
- **Admin removed from tenant**: If an enterprise admin is removed from the `EnterpriseCustomer`, all their pending (not yet processed) bulk issuance or revocation tasks MUST continue to completion (tasks are tenant-scoped, not admin-scoped). The admin's access to view/manage badges MUST be immediately revoked

### Verification Edge Cases

- **High-traffic verification attack**: If a single assertion receives more than 10,000 verification requests per hour, the system MUST serve from cache (Redis or CDN) and MUST NOT query the database for each request. Cache invalidation MUST happen within 60 seconds of a revocation
- **Verification of expired badge**: If a badge has an expiration date that has passed, the verification endpoint MUST return HTTP 200 with the assertion JSON but MUST include an `expires` field in the response and a `X-Badge-Status: expired` custom header. The assertion is still valid (it was legitimately earned) but expired
- **Assertion URL domain change**: If the Badgr Server domain changes (e.g., from `badges.academyv2.mereka.io` to a new domain), the old domain MUST continue to serve redirects (HTTP 301) to the new assertion URLs for a minimum of 2 years. This preserves badge verifiability for already-shared badges
- **Concurrent revocation and verification**: If a revocation is being processed while a verification request arrives, the system MUST either return the pre-revocation valid response or the post-revocation 404. It MUST NOT return an inconsistent state (e.g., valid assertion with revocation metadata)

### Blockchain Anchoring Edge Cases

- **Blockchain network congestion**: If the anchoring transaction is not confirmed within 30 minutes, the system MUST retry with a higher gas price (for EVM chains). If the transaction fails after 3 retries, the system MUST log the failure, alert the operator, and mark the batch as "anchoring_failed". The badges remain valid via hosted verification; blockchain anchoring is a supplementary guarantee
- **Chain reorganization**: If a blockchain reorganization invalidates a previously confirmed anchoring transaction, the system MUST detect this via confirmation depth monitoring (wait for 12+ confirmations on Ethereum, 64+ on Polygon) before marking anchoring as complete
- **Cost spike**: If blockchain gas prices exceed a configurable threshold (default: 50 gwei for Ethereum), the system MUST defer anchoring until prices drop below the threshold. Deferred batches MUST be anchored within 7 days or an alert is triggered

### Webhook Edge Cases

- **Webhook endpoint permanently failing**: If all 5 retry attempts fail for a webhook delivery, the event MUST be moved to a dead letter queue. After 10 consecutive failures to a webhook URL, the system MUST mark the webhook as "suspended" and notify the enterprise admin. The admin MUST manually re-enable the webhook after fixing the endpoint
- **Webhook payload size**: Webhook payloads MUST NOT exceed 64 KB. If additional data is needed, the payload MUST include a URL to fetch the full assertion via the enterprise API
- **Webhook SSRF prevention**: The system MUST validate webhook URLs against a deny list of private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.0/8, 169.254.0.0/16, ::1) and MUST reject registration of webhook URLs pointing to these ranges

### Rate Limiting

- Public verification endpoint: 100 requests/minute per IP, HTTP 429 with `Retry-After` header on exceeded
- Enterprise admin API: 100 requests/minute per authenticated user
- Service-to-service calls (credentials service to Badgr Server): 10,000 requests/minute (internal tier)
- Webhook deliveries: the system MUST NOT send more than 10 webhook requests per second to a single endpoint to avoid overwhelming the receiver

---

## Observability

### Logs

- **Badgr Server**: Structured JSON logs to stdout, captured by Promtail and shipped to Loki. Every log line MUST include: `service_name: badgr-server`, `enterprise_customer_uuid` (when in request context), `request_id` (correlation ID), `log_level`, `timestamp`
- **Badge issuance events**: MUST be logged with: `event_type: badge_issued`, `assertion_uid`, `badge_class_id`, `enterprise_customer_uuid`, `learner_user_id`, `issuance_trigger` (course_completion, program_completion, manual, bulk), `processing_duration_ms`
- **Badge revocation events**: MUST be logged with: `event_type: badge_revoked`, `assertion_uid`, `badge_class_id`, `enterprise_customer_uuid`, `revoked_by`, `revocation_reason`, `was_blockchain_anchored`
- **Verification requests**: MUST be logged with: `event_type: verification_request`, `assertion_uid`, `verifier_ip_hash`, `verification_result` (valid, revoked, expired, not_found), `response_time_ms`
- **Webhook deliveries**: MUST be logged with: `event_type: webhook_delivery`, `webhook_url_hash`, `enterprise_customer_uuid`, `badge_event_type`, `delivery_attempt`, `http_status`, `response_time_ms`
- **Blockchain anchoring**: MUST be logged with: `event_type: blockchain_anchor`, `batch_id`, `chain_id`, `transaction_hash`, `assertions_count`, `gas_used`, `cost_usd`, `anchor_status` (pending, confirmed, failed)
- **Sensitive data rule**: MUST NOT log: raw email addresses (use hashed form), signing private keys, webhook URL paths (only hash), full assertion JSON (only UIDs and metadata)

### Metrics

- `badge_issuance_total` (counter, labels: `enterprise_customer_uuid`, `badge_class_id`, `trigger` [course_completion, program_completion, manual, bulk], `outcome` [success, failure, duplicate])
- `badge_issuance_duration_seconds` (histogram, labels: `trigger`, `outcome`) -- time from event receipt to assertion creation
- `badge_revocation_total` (counter, labels: `enterprise_customer_uuid`, `outcome` [success, failure])
- `badge_verification_requests_total` (counter, labels: `result` [valid, revoked, expired, not_found, rate_limited])
- `badge_verification_latency_seconds` (histogram, labels: `result`)
- `badge_sharing_total` (counter, labels: `enterprise_customer_uuid`, `platform` [linkedin, twitter, facebook, copy_link])
- `badge_class_count` (gauge, labels: `enterprise_customer_uuid`, `status` [active, archived])
- `badge_webhook_deliveries_total` (counter, labels: `enterprise_customer_uuid`, `event_type`, `outcome` [success, failure, retry])
- `badge_webhook_delivery_latency_seconds` (histogram, labels: `enterprise_customer_uuid`)
- `badge_blockchain_anchor_total` (counter, labels: `chain_id`, `outcome` [confirmed, failed, deferred])
- `badge_blockchain_anchor_cost_usd` (counter, labels: `chain_id`, `enterprise_customer_uuid`)
- `badge_blockchain_anchor_batch_size` (histogram, labels: `chain_id`)
- `badge_issuance_queue_depth` (gauge) -- number of pending badge issuance tasks in Celery
- `badgr_server_health` (gauge) -- 1 for healthy, 0 for unhealthy
- `badge_assertion_count` (gauge, labels: `enterprise_customer_uuid`, `status` [active, revoked, expired])
- `badge_portfolio_views_total` (counter, labels: `view_type` [own_portfolio, public_profile, individual_badge])

### Alerts

- **Critical**: Badgr Server health check fails for > 3 consecutive checks (1 minute) -- page oncall
- **Critical**: `badge_issuance_queue_depth` exceeds 1000 for more than 10 minutes -- badge pipeline is backed up, page oncall
- **Critical**: `badge_blockchain_anchor_total{outcome=failed}` exceeds 3 in 1 hour -- anchoring infrastructure issue
- **Warning**: `badge_issuance_duration_seconds` p95 exceeds 120 seconds over 15 minutes -- issuance pipeline degraded
- **Warning**: `badge_verification_requests_total{result=rate_limited}` exceeds 100 in 5 minutes -- potential enumeration attack
- **Warning**: `badge_webhook_deliveries_total{outcome=failure}` rate exceeds 20% over 1 hour for any enterprise customer -- webhook endpoint issue
- **Warning**: `badge_blockchain_anchor_cost_usd` daily total exceeds configurable threshold (default: $50) -- cost anomaly
- **Info**: `badge_assertion_count{status=expired}` increases by more than 100 in a day for any enterprise customer -- large batch of badges expiring, may need admin attention
- **Info**: `badge_sharing_total` is zero for an enterprise customer over 30 days -- badges not being shared, may indicate UX issue or disengaged learners

### Dashboards

- **Badge Operations**: Badgr Server health, issuance queue depth, issuance rate (per-minute), verification request rate, p95 latencies for issuance and verification
- **Badge Analytics (per-tenant)**: Total badges issued by badge class, issuance trend over 30 days, sharing rate by platform, verification count trend, top badge classes, expiration forecast
- **Blockchain Anchoring**: Anchor success rate, average cost per batch, pending batches, chain gas price trend, anchor confirmation latency
- **Webhook Health**: Delivery success rate per endpoint, retry rate, suspended webhooks, average delivery latency
- **Anti-Fraud**: Verification requests by IP hash (top 10), anomalous assertion verification spikes, rate limit trigger count

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Infrastructure Preparation (Week 1-2)
1. Provision Badgr Server MySQL database (`badgr_server`) in Cloud SQL with dedicated MySQL user
2. Build Badgr Server Docker image from open-source repository and push to Artifact Registry
3. Provision all badge-related secrets in Infisical at `/k8s/mereka-lms`:
   - `MEREKA_LMS_BADGR_SECRET_KEY` (Django secret key)
   - `MEREKA_LMS_BADGR_MYSQL_PASSWORD` (database password)
   - `MEREKA_LMS_BADGR_SIGNING_KEY_RSA` (RSA-2048 private key for badge signing)
   - `MEREKA_LMS_BADGR_OAUTH2_SECRET` (OAuth2 client secret for LMS integration)
   - `MEREKA_LMS_BADGR_WEBHOOK_SIGNING_SECRET` (HMAC secret for webhook payload signing)
4. Sync secrets to GCP Secret Manager and create ExternalSecret manifest (`badge-secrets`)
5. Create K8s Deployment, Service, and Ingress manifests for Badgr Server and Badgr Worker
6. Register OAuth2 client application in LMS Django admin for Badgr Server
7. Configure Caddy routing for `badges.academyv2.mereka.io`
8. Deploy Badgr Server to GKE and verify health endpoint

#### Phase 1: Core Badge Issuance (Week 3-4)
1. Create the Mereka Academy default issuer profile in Badgr Server
2. Create 3-5 pilot BadgeClasses for existing popular courses
3. Implement credentials-to-Badgr integration service: consume `COURSE_COMPLETION` events, call Badgr API
4. Test badge issuance flow end-to-end with a test learner account
5. Verify OpenBadges 2.0 compliance by validating assertions with an external validator (e.g., IMS Open Badges Validator)
6. Verify public verification endpoint returns valid assertion JSON
7. Deploy badge notification email template

#### Phase 2: Multi-Tenant Support (Week 5-6)
1. Create per-tenant issuer profile creation workflow in admin portal
2. Implement tenant-scoped BadgeClass CRUD in admin portal
3. Implement badge template designer (name, description, image upload, criteria, tags)
4. Test tenant isolation: verify admin A cannot see admin B's badge classes or assertions
5. Create Mereka Academy pilot tenant issuer with branded badge templates
6. Onboard one enterprise client with their branded issuer profile and badge templates

#### Phase 3: Learner Experience (Week 7-8)
1. Build credential portfolio page (MFE or LMS integration)
2. Implement badge display: image, name, issuer, date, status
3. Implement LinkedIn "Add to Certification" integration
4. Implement social sharing (Twitter/X, Facebook, copy link)
5. Implement public badge assertion page (shareable URL)
6. Implement public learner profile (opt-in, privacy controls)
7. Test portfolio with a learner who has badges from multiple tenants

#### Phase 4: Enterprise API and Webhooks (Week 9-10)
1. Implement enterprise badge API endpoints (assertions list, badge classes list, analytics, learner badges)
2. Implement webhook registration and delivery system
3. Test enterprise API with pilot client's HR system integration
4. Implement badge revocation workflow (single and bulk)
5. Implement anti-fraud measures (rate limiting, anomaly detection, verification logging)
6. Security review: verify tenant isolation, SSRF prevention, rate limits

#### Phase 5: Blockchain Anchoring and Production Hardening (Week 11-12)
1. Implement blockchain anchoring service (optional, for interested tenants)
2. Configure anchoring chain (Polygon recommended for lower costs)
3. Test anchoring flow end-to-end with a batch of test assertions
4. Enable all alerts and dashboards
5. Load test: simulate 1000 concurrent badge issuances
6. Load test: simulate 10,000 verification requests per minute
7. Onboard second enterprise client to validate repeatability
8. Document operational runbook (`docs/runbooks/badges-credentials-runbook.md`)
9. Conduct badge reconciliation job test: disable event bus, complete courses, verify reconciliation catches up

### Feature Flags

- `ENABLE_BADGE_ISSUANCE` -- gate badge issuance pipeline (default: off). When off, `COURSE_COMPLETION` events are consumed but no badges are issued
- `ENABLE_BADGE_ADMIN_PORTAL` -- gate badge management views in admin portal (default: off)
- `ENABLE_BADGE_PORTFOLIO` -- gate credential portfolio page for learners (default: off)
- `ENABLE_BADGE_SHARING` -- gate LinkedIn/social sharing buttons (default: off)
- `ENABLE_BADGE_WEBHOOKS` -- gate webhook delivery system (default: off)
- `ENABLE_BLOCKCHAIN_ANCHORING` -- gate blockchain anchoring for badge assertions (default: off)
- `ENABLE_BADGE_ENTERPRISE_API` -- gate enterprise badge API endpoints (default: off)
- All feature flags MUST be configurable per `enterprise_customer_uuid` where applicable (not just globally)
- All feature flags MUST be settable via the LMS Django admin or a configuration API

### Backward Compatibility

- Deploying the badge system MUST NOT affect the existing credentials service certificate functionality (PDF/HTML course certificates continue to work as-is)
- The existing credentials service at `credentials.academyv2.mereka.io` MUST continue to serve certificates independently of the Badgr Server
- Learners who complete courses without associated BadgeClasses MUST see no change in their experience (they receive certificates as before, no badge)
- The `mereka-lms` namespace MUST continue to function if the Badgr Server is scaled to zero (no hard dependency from LMS or credentials service on Badgr Server)
- Existing enterprise service integrations (license manager, catalog, etc.) MUST NOT be affected by the badge system deployment

### Rollback Steps

#### Badgr Server Rollback
1. Disable the `ENABLE_BADGE_ISSUANCE` feature flag in the LMS
2. Scale the `badgr-server` and `badgr-worker` Deployments to 0 replicas: `kubectl scale deployment badgr-server badgr-worker -n mereka-lms --replicas=0`
3. `COURSE_COMPLETION` events continue to flow but badge issuance stops
4. Existing certificates continue to be issued by the credentials service
5. Learner portfolio page shows "Badges temporarily unavailable" message (if `ENABLE_BADGE_PORTFOLIO` is left on) or is hidden entirely (if flag is off)
6. Previously issued badges remain publicly verifiable as long as the assertion URLs (hosted on Badgr Server) were cached or the server is brought back
7. Investigate the issue using logs in Loki and metrics in Grafana
8. Fix and redeploy; scale Deployments back to desired replicas

#### Badge Data Rollback
1. Badge data is stored in the `badgr_server` database, independent of the LMS `openedx` database and the credentials service database
2. If the badge database is corrupted, restore from the latest Cloud SQL backup
3. The LMS and credentials service continue operating normally during badge database restoration
4. After restoration, restart the Badgr Server to reconnect

#### Webhook Rollback
1. Disable `ENABLE_BADGE_WEBHOOKS` feature flag
2. Webhook events accumulate in the dead letter queue
3. Re-enable when webhook infrastructure issues are resolved; queued events are processed

#### Blockchain Anchoring Rollback
1. Disable `ENABLE_BLOCKCHAIN_ANCHORING` feature flag
2. Badges continue to be issued with hosted verification (no blockchain)
3. Previously anchored badges retain their on-chain anchors and remain verifiable via blockchain
4. Re-enable when chain connectivity or cost issues are resolved

---

## Open Questions

1. **Badgr Server version and fork strategy**: Should we use the latest upstream Badgr Server release or a specific stable version? The upstream project has had intermittent maintenance activity. Should we fork to ensure long-term support, or pin a version and patch as needed? Need to assess upstream release cadence and community health.

2. **Badge image storage backend**: Should badge images be stored on a GCS bucket (more scalable, CDN-friendly) or on a PersistentVolume in K8s (simpler but less scalable)? GCS adds a dependency but better aligns with production-grade image serving. Need to evaluate cost and CDN integration.

3. **OpenBadges 3.0 timeline**: The spec marks OpenBadges 3.0 (Verifiable Credentials) as SHOULD. When should 3.0 become the default format for new badge classes? Need to assess client readiness and verifier ecosystem maturity for OB 3.0.

4. **Blockchain chain selection**: The spec suggests Ethereum mainnet or Layer 2 chains. For production, Polygon is recommended for lower costs, but some enterprise clients may require Ethereum mainnet for perceived credibility. Should chain selection be per-tenant configurable? What is the acceptable cost per anchoring batch?

5. **Credential portfolio location**: Should the credential portfolio be a standalone MFE, a page within the existing LMS learner dashboard, or a page within the enterprise learner portal MFE? The choice affects navigation, authentication flow, and development effort. Need UX input.

6. **LinkedIn certification integration method**: LinkedIn supports two integration paths: (a) the "Add to Profile" button with URL parameters (simple, no API key required) and (b) the Learning Content API for organizations (requires LinkedIn partnership). Which path should be the primary integration? The URL parameter method is simpler but less featured.

7. **Assessment-based badge triggers**: The spec mentions conditional badge issuance based on assessment scores as a SHOULD. What assessment score data is currently available via the event bus or API? Can the existing xqueue or ORA2 (open response assessment) integrations provide score data reliably?

8. **Badgr Server resource sizing**: What are the appropriate CPU/memory requests and limits for the Badgr Server and worker Deployments? The spec estimates 0.5 vCPU / 1 GB RAM baseline, but this needs validation with load testing, especially for badge image serving and verification endpoint traffic.

9. **Badge expiration behavior**: When a badge expires, should it still appear in the learner's portfolio? Should expired badges be distinguishable from revoked badges? The spec defines expired badges as still "valid" (they were legitimately earned) but needs UX input on how to present them.

10. **SCIM compatibility scope**: The spec mentions SCIM-compatible user-to-badge mapping exports. What is the minimum SCIM schema extension required for badge data? Need to assess which enterprise HR systems the pilot clients use and their SCIM support level.

11. **Reconciliation job scope**: Should the badge reconciliation job backfill badges for all historical completions or only for completions within a configurable lookback window (e.g., last 7 days)? Full historical backfill could be expensive for large course catalogs. Need to determine expected volume.

12. **Multi-issuer per tenant**: The spec allows multiple issuer profiles per tenant. Is this a v1 requirement or can it be deferred? Multiple issuers add complexity to the admin portal UX and the tenant isolation model.

13. **Badge domain and SSL**: `badges.academyv2.mereka.io` is a multi-level subdomain requiring DNS-only + Let's Encrypt (per CLAUDE.md Cloudflare SSL limitation). Should we use a simpler domain pattern like `badges.mereka.io` to simplify SSL, or is the `academyv2` prefix required for consistency with other services?

14. **Data retention for verification logs**: The spec states 90-day retention for verification logs. Is this sufficient for compliance requirements of enterprise clients? Some regulated industries may require longer retention. Need client input.
