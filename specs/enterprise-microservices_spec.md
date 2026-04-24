---
title: "Enterprise Microservices Deployment"
type: "feature_spec"
id: "SPEC-ENTERPRISE-MICROSERVICES"
status: "approved"
owner: "engineering"
vehicle: "talent_platform"
spec_class: "integration"
created: "2026-02-10"
last_updated: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
version: "1.0.0"
deployment_date: "2026-02-10"
deployment_status: "production"
domain: "tenancy"
normativity: "normative"
depends_on:
  - "specs/multi-tenancy-architecture_spec.md"
  - "specs/auth-sso-enterprise_spec.md"
  - "specs/k8s-deployment_spec.md"
  - "specs/observability-stack_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/run-spec-integrity-gates.sh"
  - "scripts/qa/spec-tools/spec_coverage_report.py"
interfaces:
  - "enterprise-catalog"
  - "license-manager"
  - "enterprise-access"
  - "enterprise-subsidy"
  - "enterprise-integrated-channels"
tags:
  - "tenant.isolation"
  - "auth.oidc"
  - "platform.control-plane"
  - "commerce.reconciliation"
summary: "Defines the deployed enterprise microservices boundary, required platform integrations, and runtime expectations for catalog, access, subsidy, and integrated-channel services."
links:
  related_docs:
    - "docs/reference/architecture/ENTERPRISE_SERVICES_OVERVIEW.md"
    - "docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
  related_specs:
    - "specs/k8s-deployment_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/multi-site-domains_spec.md"
    - "specs/proposals/mobile-apps-enterprise_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A production-grade suite of Open edX enterprise microservices deployed on GKE alongside the existing Mereka Academy platform. The suite consists of five services -- enterprise-catalog, license-manager, enterprise-access, enterprise-subsidy, and enterprise-integrated-channels -- that collectively enable "many clients" enterprise functionality: organizations purchase license pools, provision learner access to curated catalog subsets, manage SSO/SAML authentication, and sync learning data with third-party HR/LMS platforms.

These services are maintained by the Open edX community as independent Django applications. Each runs as its own K8s Deployment in the `mereka-lms` namespace, shares the existing MySQL (Cloud SQL) and Redis infrastructure, communicates with the LMS via internal HTTP and the Open edX event bus (Redis Streams), and exposes REST APIs consumed by the enterprise admin MFE (`frontend-app-admin-portal`) and the learner MFE (`frontend-app-learner-portal-enterprise`).

The system supports multi-tenant operation where each enterprise client organization is an `EnterpriseCustomer` record in the LMS database with a unique UUID. All enterprise services route requests using this UUID. There are no separate databases per tenant; isolation is achieved through application-level queryset filtering, API-level permission enforcement, and the Open edX enterprise consent framework.

## Why it matters

Mereka Academy's growth strategy depends on onboarding corporate clients who need more than individual course enrollment. Enterprise clients require: (1) license pools they can allocate to employees, (2) curated catalogs restricted to approved content, (3) SAML/SSO integration with their corporate identity providers, (4) automated learner provisioning when employees join/leave, (5) analytics and completion data routed to their HR systems. Without formal enterprise services, each client onboarding is ad-hoc Django admin work, license tracking is manual, and catalog curation is fragile. This spec establishes the architecture for scalable, secure, multi-tenant enterprise deployment.

## Success looks like

- All five enterprise microservices are running in the `mereka-lms` GKE namespace with automated deployment
- A new enterprise client can be fully onboarded (customer record, catalog, license pool, SSO) within 4 hours of admin work, zero code changes
- License allocation and revocation propagate to the learner within 60 seconds
- Enterprise catalog queries respond within 300ms at p95
- Zero cross-tenant data leakage: a client admin sees only their own learners, licenses, and catalog
- SSO/SAML login for enterprise learners completes in under 5 seconds end-to-end
- At least 2 integrated channel connectors (Degreed, Cornerstone) are operational for pilot clients
- Enterprise reporting dashboards show per-client enrollment, completion, and license utilization

---

# Agent Contract

## Scope

- In scope:
  - Kubernetes deployment architecture for all five enterprise microservices
  - Service-to-service communication patterns (internal HTTP, event bus)
  - Database schema architecture (shared MySQL with per-service logical databases)
  - Enterprise customer (tenant) data model and isolation strategy
  - Enterprise catalog service: content curation, catalog queries, content metadata sync
  - License manager service: license pool CRUD, seat allocation/revocation, renewal
  - Enterprise access service: access policy evaluation, subsidy-based enrollment
  - Enterprise subsidy service: subsidy ledger, transaction tracking, balance management
  - Enterprise integrated channels service: data sync with Degreed, Cornerstone, SAP SuccessFactors, Canvas, Blackboard, Moodle
  - SSO/SAML integration architecture for corporate identity providers
  - Enterprise admin portal MFE deployment
  - Enterprise learner portal MFE deployment
  - Secrets management for enterprise service credentials
  - ExternalSecrets configuration for enterprise service secrets
  - Observability (logs, metrics, alerts, dashboards) for all enterprise services
  - Rollout plan from zero to production
  - Feature flag strategy for gradual enterprise feature enablement

- Out of scope:
  - Open edX platform (LMS/CMS) core changes beyond configuration (the platform is consumed as-is)
  - Mobile app enterprise features (covered by `specs/proposals/mobile-apps-enterprise_spec.md`)
  - Individual course content creation or curriculum design
  - Custom enterprise MFE development beyond Open edX upstream
  - Payment gateway integration (Stripe already operational via ecommerce service)
  - Cloud SQL provisioning and management (existing infrastructure)
  - GKE cluster management (existing infrastructure)
  - DNS and SSL certificate management (existing infrastructure)

## Non-goals

- Building custom enterprise services from scratch (we deploy Open edX upstream services)
- Supporting non-Open edX enterprise LMS clients (these services are Open edX-specific)
- Implementing a multi-database-per-tenant architecture (we use shared database with application-level isolation)
- Replacing the existing ecommerce service with enterprise subsidy (they coexist)
- Supporting real-time bidirectional sync with integrated channels (batch sync is the standard pattern)
- Building a custom enterprise admin UI (we deploy the Open edX enterprise admin portal MFE)
- Implementing a custom SAML IdP (we integrate with client-provided IdPs)

## Assumptions

- The existing GKE cluster in `mereka-lms` namespace has sufficient resource headroom for 5 additional Deployments (estimated: 2.5 vCPU, 5 GB RAM total at baseline)
- Cloud SQL (MySQL 8) can handle the additional databases (5 new logical databases) within its current tier, or can be scaled up
- The Open edX LMS is running Tutor 21.0.0 (Ulmo) with the `openedx-enterprise` package already included in the base image (it ships with the standard Tutor build)
- The existing Caddy reverse proxy can route to additional internal services
- Redis (existing) is available for Celery task queues and caching for all enterprise services
- Infisical is the secrets source of truth (per `specs/secrets-management_spec.md`)
- The Open edX OAuth2 provider is operational and can issue service-to-service credentials for enterprise services
- Artifact Registry (`asia-southeast1-docker.pkg.dev/mereka-lms/openedx`) can host enterprise service images
- The existing observability stack (Prometheus, Loki, Tempo) can ingest metrics/logs from additional services

---

## Requirements

### Domain and SSL

| Property | Value |
|----------|-------|
| External URL | `https://admin.academyv2.mereka.io` |
| Cloudflare mode | DNS-only (gray cloud) |
| SSL provider | Let's Encrypt via cert-manager |
| Reason | Multi-level subdomain (`*.*.mereka.io`) not covered by Cloudflare Free SSL |

**Note**: Multi-level subdomains (*.academyv2.mereka.io) require DNS-only mode + Let's Encrypt certificates. Cloudflare Free SSL does not cover *.*.mereka.io.

See `specs/cross-cutting-requirements_spec.md` for platform-wide TLS requirements.

### Functional

#### Service Deployment Architecture

- The system MUST deploy the following five microservices as separate K8s Deployments in the `mereka-lms` namespace:
  - `enterprise-catalog` (source: `edx/enterprise-catalog`)
  - `license-manager` (source: `edx/license-manager`)
  - `enterprise-access` (source: `edx/enterprise-access`)
  - `enterprise-subsidy` (source: `edx/enterprise-subsidy`)
  - `enterprise-integrated-channels` (bundled with LMS as `integrated_channels` Django app)
- Each microservice Deployment MUST have a corresponding K8s Service (ClusterIP) for internal routing
- Each microservice MUST have a dedicated Celery worker Deployment for asynchronous task processing
- The system MUST deploy the following MFEs as part of the enterprise frontend layer:
  - `frontend-app-admin-portal` (enterprise admin dashboard)
  - `frontend-app-learner-portal-enterprise` (enterprise learner experience)
- All enterprise service Docker images MUST be built and pushed to `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/`
- All enterprise service Deployments MUST use the same label conventions as existing services (`app.kubernetes.io/name`, `app.kubernetes.io/instance: mereka-lms`, `app.kubernetes.io/part-of: mereka-lms`)

#### Service-to-Service Communication

- Enterprise services MUST authenticate to the LMS using OAuth2 client credentials (backend service accounts)
- Each enterprise service MUST have a unique OAuth2 client registered in the LMS Django admin (`DOT Application`)
- Enterprise services MUST communicate with the LMS via internal K8s DNS (`http://lms:8000`) for backend API calls, not via external URLs
- Enterprise services MUST use the Open edX JWT authentication backend to validate incoming requests from the LMS, admin portal, and learner portal
- The system MUST support an event bus for asynchronous communication between the LMS and enterprise services
- The event bus MUST use Redis Streams (already deployed) as the transport layer — this is a platform-wide decision (see `specs/cross-cutting-requirements_spec.md`, Section 5: Technology Decisions)
- The system MAY support migration to an alternative event bus transport if Redis Streams proves insufficient at scale, but this is not a near-term requirement
- The following events MUST be published by the LMS and consumed by enterprise services:
  - `ENROLLMENT_CREATED` -- consumed by enterprise-access, enterprise-subsidy
  - `ENROLLMENT_REVOKED` -- consumed by enterprise-access, enterprise-subsidy, license-manager
  - `COURSE_COMPLETION` -- consumed by enterprise-integrated-channels
  - `LEARNER_CREDIT_REDEEMED` -- consumed by enterprise-subsidy
  - `LICENSE_ASSIGNED` -- consumed by enterprise-access
  - `LICENSE_REVOKED` -- consumed by enterprise-access, enterprise-subsidy

#### Enterprise Customer (Tenant) Data Model

- Each enterprise client MUST be represented as an `EnterpriseCustomer` record in the LMS database with a globally unique UUID (`enterprise_customer_uuid`)
- The `EnterpriseCustomer` record MUST include: `uuid`, `name`, `slug`, `active` (boolean), `site_id` (FK to Django Site), `enable_data_sharing_consent`, `enforce_data_sharing_consent`, `enable_audit_enrollment`, `enable_audit_data_reporting`, `country`, `hide_course_original_price`, `enable_portal_code_management_screen`, `enable_learner_portal`, `enable_integrated_customer_learner_portal_search`, `enable_analytics_screen`, `sender_alias`, `enable_slug_login`; enterprise IdP linkage MUST be available via `EnterpriseCustomerIdentityProvider` (preferred) or legacy `identity_provider` compatibility
- Enterprise customer membership MUST be tracked via `EnterpriseCustomerUser` records linking `enterprise_customer_uuid` to `user_id` (LMS auth_user.id)
- The system MUST support a user belonging to multiple enterprise customers (multi-org learners)
- The system MUST support `PendingEnterpriseCustomerUser` records for learners invited but not yet registered
- The system MUST enforce the data sharing consent (DSC) framework: learners MUST explicitly consent to sharing course data with their enterprise before enrollment completion data is visible to the enterprise admin

#### Enterprise Catalog Service

- The enterprise-catalog service MUST maintain a local copy of the LMS course catalog metadata, synced periodically
- The catalog sync MUST run as a Celery periodic task at a configurable interval (default: every 6 hours)
- The system MUST support multiple `EnterpriseCatalog` records per `EnterpriseCustomer`, each with distinct content filter rules
- Content filter rules MUST support filtering by: course key, course run key, program UUID, content type (course, program, pathway), course partner, course subject, course skill, course level
- The enterprise-catalog service MUST expose the following REST API endpoints:
  - `GET /api/v1/enterprise-catalogs/` -- list catalogs for an enterprise customer
  - `GET /api/v1/enterprise-catalogs/{uuid}/` -- catalog detail
  - `GET /api/v1/enterprise-catalogs/{uuid}/get_content_metadata/` -- paginated content in a catalog
  - `GET /api/v1/enterprise-catalogs/{uuid}/contains_content_items/` -- check if specific content is in the catalog
  - `POST /api/v1/enterprise-catalogs/` -- create a new catalog (admin only)
  - `PATCH /api/v1/enterprise-catalogs/{uuid}/` -- update catalog filters (admin only)
  - `DELETE /api/v1/enterprise-catalogs/{uuid}/` -- soft-delete a catalog (admin only)
- Content metadata responses MUST include: `content_key`, `content_type`, `title`, `short_description`, `full_description`, `organizations`, `subjects`, `skills`, `image_url`, `enroll_by_date`, `advertised_course_run`
- Catalog content metadata MUST be searchable via Algolia (or Elasticsearch if Algolia is not configured) with enterprise-scoped search indices
- The enterprise-catalog service MUST NOT serve content from catalogs belonging to a different enterprise customer (tenant isolation)
- Catalog query results MUST be cached in Redis with a TTL of 5 minutes for read-heavy admin portal views

#### License Manager Service

- The license-manager service MUST manage license pools (called `SubscriptionPlan` records) for enterprise customers
- Each `SubscriptionPlan` MUST include: `uuid`, `title`, `enterprise_customer_uuid`, `enterprise_catalog_uuid`, `start_date`, `expiration_date`, `num_licenses` (total seats), `is_active`, `is_revocation_cap_enabled`, `revoke_max_percentage`, `should_auto_apply_licenses`
- The system MUST track individual license assignments via `License` records with states: `unassigned`, `assigned`, `activated`, `revoked`
- License state transitions MUST follow this machine:
  - `unassigned` -> `assigned` (admin assigns to a user email)
  - `assigned` -> `activated` (learner accepts and activates)
  - `activated` -> `revoked` (admin revokes or auto-revoke on offboarding)
  - `assigned` -> `revoked` (admin revokes before activation)
  - `revoked` -> `unassigned` (if revocation cap allows, seat is recycled)
- The license-manager service MUST expose the following REST API endpoints:
  - `GET /api/v1/subscriptions/` -- list subscription plans for an enterprise customer
  - `GET /api/v1/subscriptions/{uuid}/` -- subscription plan detail with license summary
  - `GET /api/v1/subscriptions/{uuid}/licenses/` -- paginated list of licenses
  - `POST /api/v1/subscriptions/{uuid}/licenses/assign/` -- assign licenses to user emails (batch, up to 500)
  - `POST /api/v1/subscriptions/{uuid}/licenses/revoke/` -- revoke licenses (batch, up to 500)
  - `POST /api/v1/subscriptions/{uuid}/licenses/remind/` -- send reminder emails for unactivated licenses
  - `GET /api/v1/subscriptions/{uuid}/licenses/overview/` -- license utilization summary (assigned, activated, revoked counts)
  - `POST /api/v1/subscriptions/{uuid}/licenses/auto-apply/` -- auto-assign a license to a requesting learner (self-service)
- License assignment MUST be idempotent: assigning a license to an already-assigned email MUST NOT create a duplicate license
- License assignment MUST send an activation email to the assignee via the LMS email pipeline
- License revocation MUST trigger enrollment revocation for the affected learner (via event bus or direct API call to enterprise-access)
- The system MUST enforce the revocation cap: if `is_revocation_cap_enabled`, revocations MUST NOT exceed `revoke_max_percentage` of `num_licenses`
- The system MUST enforce license pool limits: the total number of assigned + activated licenses MUST NOT exceed `num_licenses`
- License auto-apply (self-service) MUST be gated by the `should_auto_apply_licenses` flag on the subscription plan
- The license-manager service MUST support subscription renewal: extending `expiration_date` and optionally adjusting `num_licenses` without revoking existing activated licenses

#### Enterprise Access Service

- The enterprise-access service MUST evaluate access policies to determine whether a learner can enroll in a specific course through an enterprise subsidy
- The system MUST support the following subsidy access policy types:
  - `PerLearnerEnrollmentCreditAccessPolicy` -- limits number of enrollments per learner
  - `PerLearnerSpendCreditAccessPolicy` -- limits total spend per learner
  - `SubscriptionAccessPolicy` -- access granted if learner has an activated license
- Each access policy MUST be linked to: `enterprise_customer_uuid`, `catalog_uuid`, `subsidy_uuid` (or `subscription_uuid`), and policy-type-specific limits
- The enterprise-access service MUST expose:
  - `GET /api/v1/policy-allocation/{enterprise_customer_uuid}/allocate/` -- allocate access for a learner to a content key
  - `POST /api/v1/policy-redemption/{enterprise_customer_uuid}/redeem/` -- redeem access (trigger enrollment)
  - `GET /api/v1/policy-allocation/{enterprise_customer_uuid}/can-redeem/` -- check if a learner can redeem for a given content key
  - `GET /api/v1/subsidy-access-policies/` -- list policies for an enterprise customer
- Access policy evaluation MUST check in order: (1) content is in the linked catalog, (2) learner is a member of the enterprise customer, (3) subsidy/subscription has available balance/seats, (4) per-learner limits are not exceeded
- The enterprise-access service MUST NOT allow enrollment in content not included in the enterprise catalog linked to the access policy

#### Enterprise Subsidy Service

- The enterprise-subsidy service MUST maintain a financial ledger of enterprise subsidies (learner credit budgets)
- Each `Subsidy` record MUST include: `uuid`, `enterprise_customer_uuid`, `title`, `starting_balance`, `current_balance`, `unit` (USD cents or seats), `reference_id` (external billing reference), `expiration_date`, `is_active`
- Every subsidy balance change MUST be recorded as a `Transaction` with: `uuid`, `subsidy_uuid`, `lms_user_id`, `content_key`, `quantity` (negative for redemptions, positive for reversals), `reference_id`, `created`, `state` (pending, committed, failed)
- The enterprise-subsidy service MUST expose:
  - `GET /api/v1/subsidies/` -- list subsidies for an enterprise customer
  - `GET /api/v1/subsidies/{uuid}/` -- subsidy detail with balance
  - `GET /api/v1/transactions/` -- list transactions for a subsidy
  - `POST /api/v1/transactions/` -- create a transaction (typically called by enterprise-access, not directly by admin)
  - `POST /api/v1/transactions/{uuid}/reverse/` -- reverse a transaction (e.g., enrollment revoked)
- Transaction creation MUST be atomic: balance check and deduction MUST occur within a single database transaction to prevent overcommitment
- Transaction reversal MUST be idempotent: reversing an already-reversed transaction MUST be a no-op
- The ledger MUST maintain an invariant: `current_balance = starting_balance + SUM(committed_transaction_quantities)` at all times

#### Enterprise Integrated Channels Service

- The integrated-channels system MUST support syncing enterprise learner data to external LMS/HR platforms
- The system MUST support the following channel types at launch:
  - Degreed (v2 API)
  - Cornerstone OnDemand (CSOD)
- The system SHOULD support the following channel types in subsequent releases:
  - SAP SuccessFactors
  - Canvas LMS
  - Blackboard Learn
  - Moodle
- Each channel configuration MUST be linked to an `EnterpriseCustomer` and MUST include channel-type-specific credentials (API keys, OAuth tokens, endpoint URLs)
- Channel sync MUST run as Celery periodic tasks with configurable schedules (default: every 4 hours)
- Channel sync MUST transmit: learner identity (as configured by DSC), enrollment status, course completion status, grade/score, completion date
- Channel sync MUST respect data sharing consent: only learners who have granted DSC are included in the sync payload
- Channel sync MUST be idempotent: re-running a sync for the same time period MUST NOT create duplicate records in the external system
- Channel sync failures MUST be logged with the channel type, enterprise customer UUID, error message, and HTTP response code
- Channel sync MUST support dry-run mode for testing configuration without transmitting data

#### SSO/SAML Integration

- The system MUST support SAML 2.0 SSO integration for enterprise clients using the LMS's built-in SAML backend (`edx_sso_providers`)
- Each enterprise customer SAML configuration MUST include: `entity_id`, `metadata_url` (or inline metadata XML), `attr_user_permanent_id`, `attr_email`, `attr_first_name`, `attr_last_name`, `attr_full_name`
- SAML IdP metadata MUST be refreshable on-demand and automatically every 24 hours
- The system MUST support auto-provisioning: a user authenticating via enterprise SAML for the first time MUST be automatically created in the LMS and linked to the `EnterpriseCustomer`
- The system MUST support just-in-time (JIT) attribute mapping: user profile fields (name, email) MUST be updated from SAML assertions on each login
- The system MUST support slug-based login: navigating to `https://{lms_host}/enterprise/login/{enterprise_slug}` MUST redirect to the correct IdP
- SAML authentication MUST enforce that the authenticated user is associated with the correct `EnterpriseCustomer` (no cross-tenant authentication)
- The system MUST support multiple SAML IdPs simultaneously (one per enterprise customer)
- The system SHOULD support OIDC-based SSO as an alternative to SAML for clients that prefer it
- SAML private keys and certificates MUST be stored in K8s secrets (via ExternalSecrets from Infisical), not in the database

#### Enterprise Admin Portal MFE

- The system MUST deploy `frontend-app-admin-portal` as a Caddy-served MFE at `https://admin.academyv2.mereka.io`
- The admin portal MUST support the following views:
  - Dashboard: license utilization, enrollment counts, recent activity
  - Learner management: invite, assign licenses, view progress
  - Catalog management: browse and curate catalogs
  - Code management: coupon code creation and tracking
  - Subscription management: view plans, allocate seats
  - Settings: SSO configuration, branding, data sharing consent policy
  - Analytics: enrollment reports, completion reports, license reports
  - Integrated channels: configure and monitor channel syncs
- The admin portal MUST authenticate via the LMS OAuth2 provider
- The admin portal MUST restrict all views to users with the `enterprise_admin` role for the relevant `EnterpriseCustomer`
- The admin portal MUST NOT display data from enterprise customers other than the one(s) the admin is authorized for

#### Enterprise Learner Portal MFE

- The system MUST deploy `frontend-app-learner-portal-enterprise` as a Caddy-served MFE at `https://learner.academyv2.mereka.io`
- The learner portal MUST allow enterprise learners to:
  - Browse their enterprise catalog
  - Self-enroll in catalog courses (if access policy permits)
  - View their license status and activation
  - Accept data sharing consent
  - View their enterprise-specific learning progress
- The learner portal MUST authenticate via the LMS OAuth2 provider
- The learner portal MUST restrict the catalog view to courses available in the learner's enterprise catalog(s)

#### Database Architecture

- Each enterprise microservice MUST have its own logical MySQL database within the shared Cloud SQL instance:
  - `enterprise_catalog` (for enterprise-catalog service)
  - `license_manager` (for license-manager service)
  - `enterprise_access` (for enterprise-access service)
  - `enterprise_subsidy` (for enterprise-subsidy service)
- The `integrated_channels` app MUST use the existing `openedx` database (it runs within the LMS process)
- Each database MUST have a dedicated MySQL user with grants limited to its own database
- The LMS `openedx` database MUST retain the `enterprise` Django app tables (`enterprise_enterprisecustomer`, `enterprise_enterprisecustomeruser`, `enterprise_pendingenterprisecustomeruser`, `enterprise_enterprisecustomerinvitekey`, `enterprise_enterprisecourseenrollment`, `consent_datasharingconsent`, etc.)
- Database migrations for each enterprise service MUST be executed via init containers or Tutor management commands during deployment
- Cross-service data MUST NOT be accessed via direct database joins; services MUST use REST APIs or the event bus

#### Secrets Management

- Enterprise service secrets MUST follow the naming convention `MEREKA_LMS_ENTERPRISE_<SERVICE>_<KEY>` in Infisical
- The following secrets MUST be provisioned in Infisical at `/k8s/mereka-lms`:
  - `MEREKA_LMS_ENTERPRISE_CATALOG_SECRET_KEY` -- Django secret key
  - `MEREKA_LMS_ENTERPRISE_CATALOG_OAUTH2_SECRET` -- OAuth2 client secret
  - `MEREKA_LMS_ENTERPRISE_CATALOG_MYSQL_PASSWORD` -- Database password
  - `MEREKA_LMS_LICENSE_MANAGER_SECRET_KEY`
  - `MEREKA_LMS_LICENSE_MANAGER_OAUTH2_SECRET`
  - `MEREKA_LMS_LICENSE_MANAGER_MYSQL_PASSWORD`
  - `MEREKA_LMS_ENTERPRISE_ACCESS_SECRET_KEY`
  - `MEREKA_LMS_ENTERPRISE_ACCESS_OAUTH2_SECRET`
  - `MEREKA_LMS_ENTERPRISE_ACCESS_MYSQL_PASSWORD`
  - `MEREKA_LMS_ENTERPRISE_SUBSIDY_SECRET_KEY`
  - `MEREKA_LMS_ENTERPRISE_SUBSIDY_OAUTH2_SECRET`
  - `MEREKA_LMS_ENTERPRISE_SUBSIDY_MYSQL_PASSWORD`
  - `MEREKA_LMS_ENTERPRISE_ALGOLIA_APP_ID` (optional, for catalog search)
  - `MEREKA_LMS_ENTERPRISE_ALGOLIA_SEARCH_API_KEY` (optional)
  - `MEREKA_LMS_ENTERPRISE_ALGOLIA_INDEX_NAME` (optional)
- An ExternalSecret named `enterprise-secrets` MUST be created to sync these from GCP Secret Manager to a K8s Secret
- All enterprise service Deployments MUST reference the `enterprise-secrets` K8s Secret via `envFrom`
- Per-client integrated channel credentials (Degreed API keys, CSOD OAuth secrets) MUST be stored in the `integrated_channels` configuration model in the LMS database, encrypted at rest by the `enterprise_integrated_channels` encrypted model fields -- NOT in Infisical (they are client-specific and admin-managed)

### Non-Functional Requirements

#### Performance

- Enterprise catalog content metadata API p95 latency MUST be <= 300ms for paginated list endpoints (up to 100 items per page)
- Enterprise catalog `contains_content_items` API p95 latency MUST be <= 100ms
- License manager assignment API (batch of up to 500 emails) p95 latency MUST be <= 5 seconds
- License manager single license lookup p95 latency MUST be <= 200ms
- Enterprise access `can-redeem` API p95 latency MUST be <= 500ms (involves cross-service calls to catalog and subsidy)
- Enterprise subsidy transaction creation p95 latency MUST be <= 1 second
- SAML SSO login round-trip (from redirect to IdP to authenticated session in LMS) MUST complete within 5 seconds at p95, excluding IdP response time
- Enterprise admin portal initial page load MUST be <= 3 seconds at p95
- Integrated channel sync for a client with 10,000 learners MUST complete within 30 minutes

#### Reliability

- All enterprise services MUST have a readiness probe (`/health/`) and liveness probe (`/heartbeat/`)
- Enterprise services MUST be available 99.9% of the time (measured monthly, excluding planned maintenance windows)
- License assignment MUST be atomic: either all emails in a batch are assigned or none are (rollback on partial failure)
- Enterprise subsidy ledger MUST be eventually consistent within 30 seconds of a transaction commit
- Integrated channel sync MUST implement retry with exponential backoff (base: 30s, max: 15min, max retries: 5) for transient failures

#### Security

- All inter-service communication within the cluster MUST use K8s Service DNS (no external network egress for internal calls)
- Enterprise service APIs MUST enforce JWT-based authentication for all endpoints except health checks
- Enterprise service APIs MUST enforce `enterprise_admin` or `enterprise_learner` role-based access control
- Enterprise catalog content MUST be filtered by `enterprise_customer_uuid` at the queryset level (Django ORM `filter(enterprise_customer_uuid=...)`) on every query
- License manager MUST enforce that an admin can only view/modify subscription plans belonging to their enterprise customer
- SAML assertion signatures MUST be validated against the IdP's published certificate
- SAML assertions MUST be rejected if the `NotOnOrAfter` timestamp is in the past (replay attack prevention)
- SAML assertions MUST be validated against a configurable audience restriction (`EntityID`)
- The system MUST NOT log SAML assertion XML (contains PII); only assertion metadata (issuer, timestamp, status) MAY be logged
- Database credentials MUST use unique passwords per service (no shared passwords)
- API rate limiting MUST be enforced: 100 requests/minute per enterprise admin user, 1000 requests/minute per enterprise service account

---

## Acceptance Criteria

### Service Deployment

- [ ] AC-001: Given the K8s manifests are applied, when `kubectl get deployments -n mereka-lms -l app.kubernetes.io/component=enterprise` is run, then deployments for enterprise-catalog, license-manager, enterprise-access, and enterprise-subsidy are listed and each deployment has `READY == DESIRED` (steady-state full readiness)
- [ ] AC-002: Given all enterprise services are deployed, when `kubectl get endpoints -n mereka-lms` is run, then each enterprise service has non-empty endpoints
- [ ] AC-003: Given the enterprise-catalog service is running, when `curl http://enterprise-catalog:8160/health/` is called from within the cluster, then the response is HTTP 200 with `{"status": "ok"}`
- [ ] AC-004: Given the license-manager service is running, when `curl http://license-manager:18170/health/` is called from within the cluster, then the response is HTTP 200
- [ ] AC-005: Given the enterprise-access service is running, when `curl http://enterprise-access:18270/health/` is called from within the cluster, then the response is HTTP 200
- [ ] AC-006: Given the enterprise-subsidy service is running, when `curl http://enterprise-subsidy:18280/health/` is called from within the cluster, then the response is HTTP 200
- [ ] AC-007: Given enterprise MFEs are deployed, when `curl https://admin.academyv2.mereka.io/` is called, then the admin portal HTML is returned with HTTP 200
- [ ] AC-008: Given enterprise MFEs are deployed, when `curl https://learner.academyv2.mereka.io/` is called, then the learner portal HTML is returned with HTTP 200
- [ ] AC-009: Given the service is deployed, its domain MUST use DNS-only Cloudflare mode with Let's Encrypt SSL (not Cloudflare proxy)

### Tenant Isolation

- [ ] AC-010: Given enterprise customer A and enterprise customer B exist, when admin A calls `GET /api/v1/enterprise-catalogs/`, then only catalogs belonging to customer A are returned
- [ ] AC-011: Given enterprise customer A with a subscription plan, when admin B calls `GET /api/v1/subscriptions/{plan_uuid_of_A}/`, then the response is HTTP 403 Forbidden
- [ ] AC-012: Given enterprise customer A with enrolled learners, when admin B calls the enterprise-access API for customer A's UUID, then the response is HTTP 403 Forbidden
- [ ] AC-013: Given a learner linked to enterprise customer A, when they browse the enterprise learner portal, then they see only courses from customer A's catalogs
- [ ] AC-014: Given a user belonging to both enterprise customer A and B, when they select customer A in the learner portal, then no data or catalog from customer B is visible until they switch context

### License Management

- [ ] AC-015: Given a subscription plan with 100 licenses and 50 assigned, when an admin assigns 51 more licenses, then the request fails with HTTP 422 and an error indicating insufficient seats
- [ ] AC-016: Given a subscription plan with `should_auto_apply_licenses=true`, when an enterprise learner requests enrollment, then a license is automatically assigned and activated
- [ ] AC-017: Given a license in `activated` state, when an admin revokes it, then the license state transitions to `revoked` and an enrollment revocation event is published
- [ ] AC-018: Given a subscription plan with `is_revocation_cap_enabled=true` and `revoke_max_percentage=10` and 100 licenses, when an admin attempts to revoke the 11th license, then the request fails with HTTP 422 indicating revocation cap reached
- [ ] AC-019: Given an email address already assigned a license in a plan, when the admin assigns a license to the same email again, then no duplicate license is created and the response indicates the existing assignment

### Enterprise Catalog

- [ ] AC-020: Given an enterprise catalog with a content filter for subject "Technology", when `GET /api/v1/enterprise-catalogs/{uuid}/get_content_metadata/` is called, then only courses tagged with "Technology" subject are returned
- [ ] AC-021: Given the catalog sync task has not run in 6 hours, when the Celery beat scheduler fires, then the sync task executes and updates content metadata from the LMS discovery service
- [ ] AC-022: Given a course key "course-v1:Mereka+ENT101+2026", when `GET /api/v1/enterprise-catalogs/{uuid}/contains_content_items/?course_run_ids=course-v1:Mereka+ENT101+2026` is called, then the response indicates whether the course is in the catalog within 100ms

### Enterprise Access and Subsidy

- [ ] AC-023: Given a learner with a PerLearnerEnrollmentCreditAccessPolicy limiting to 5 enrollments and already 5 enrollments, when the learner requests a 6th enrollment, then the `can-redeem` endpoint returns `false` with reason "per-learner enrollment limit reached"
- [ ] AC-024: Given a subsidy with a starting balance of 10000 (cents) and 3000 already spent, when a transaction for 8000 is attempted, then it fails with insufficient balance error and the balance remains 7000
- [ ] AC-025: Given a committed transaction for enrollment in course X, when the admin revokes the enrollment and a reversal is requested, then the subsidy balance is restored by the transaction amount
- [ ] AC-026: Given a reversal is requested on an already-reversed transaction, when the API processes it, then the response is HTTP 200 (idempotent) and no balance change occurs

### SSO/SAML

- [ ] AC-027: Given enterprise customer "Acme Corp" with SAML IdP configured and `enable_slug_login=true`, when a user navigates to `https://academyv2.mereka.io/enterprise/login/acme-corp`, then they are redirected to the Acme Corp SAML IdP login page
- [ ] AC-028: Given a successful SAML assertion from the Acme Corp IdP for a user not yet in the LMS, when the assertion is processed, then a new LMS user is created and linked to the Acme Corp enterprise customer
- [ ] AC-029: Given a SAML assertion with `NotOnOrAfter` in the past, when the LMS processes the assertion, then the authentication is rejected and the user sees an error message
- [ ] AC-030: Given enterprise customer A with SAML IdP "IdP-A" and enterprise customer B with SAML IdP "IdP-B", when a user authenticates via IdP-A, then they are linked to customer A only (no cross-tenant linking)

### Integrated Channels

- [ ] AC-031: Given a Degreed integration configured for enterprise customer A with valid credentials, when the sync task runs, then course completion data for consenting learners of customer A is transmitted to the Degreed API
- [ ] AC-032: Given a channel sync in dry-run mode, when the sync task runs, then no data is transmitted to the external system and the sync log indicates "dry-run"
- [ ] AC-033: Given a channel sync that encounters a transient API error (HTTP 503), when the task retries, then it retries up to 5 times with exponential backoff before marking the sync as failed

### Secrets and Configuration

- [ ] AC-034: Given all enterprise secrets are provisioned in Infisical at `/k8s/mereka-lms`, when ExternalSecrets syncs, then the `enterprise-secrets` K8s Secret contains all expected keys
- [ ] AC-035: Given the enterprise-catalog service starts, when it reads its Django SECRET_KEY from the environment, then the value matches the Infisical secret `MEREKA_LMS_ENTERPRISE_CATALOG_SECRET_KEY`

### Observability

- [ ] AC-036: Given enterprise services are running, when `/metrics` is scraped by Prometheus, then enterprise-specific metrics (request count, latency histogram) are present
- [ ] AC-037: Given a license assignment fails, when the error is logged, then the log entry includes `enterprise_customer_uuid`, `subscription_plan_uuid`, `error_type`, and `user_email_hash` (not the raw email)

---

## Edge Cases

### License Management Edge Cases

- **Concurrent license assignment**: If two admins simultaneously assign the last available license to different users, the database transaction MUST use `SELECT ... FOR UPDATE` to serialize access. Exactly one assignment succeeds; the other receives HTTP 422 (insufficient seats)
- **Expired subscription with active licenses**: When a subscription plan passes its `expiration_date`, the system MUST NOT automatically revoke licenses. Instead, it MUST: (1) prevent new assignments, (2) mark the plan as inactive, (3) emit an `SUBSCRIPTION_EXPIRED` event for admin notification. Existing enrollments remain active until explicitly revoked
- **License assignment to non-existent email**: Assigning a license to an email address not yet registered in the LMS MUST create a `PendingEnterpriseCustomerUser` record. When the user registers with that email, the pending record MUST be resolved and the license activated automatically
- **Bulk assignment partial failure**: If a batch of 500 email assignments encounters a validation error on email #250 (e.g., malformed email), the system MUST reject the entire batch (all-or-nothing) and return the specific error

### Subsidy Ledger Edge Cases

- **Double-redemption prevention**: If a learner has already redeemed a subsidy for course X and attempts to redeem again, the system MUST return an idempotent response (HTTP 200, existing transaction) rather than deducting the balance twice
- **Negative balance prevention**: Under no circumstances MUST the subsidy `current_balance` go negative. The transaction creation endpoint MUST check `current_balance >= abs(transaction_quantity)` within the database transaction
- **Concurrent transaction race condition**: Multiple concurrent redemptions against the same subsidy MUST be serialized at the database level (`SELECT ... FOR UPDATE` on the subsidy row). Only transactions that fit within the remaining balance are committed; others fail with insufficient balance
- **Transaction reversal timing**: If a reversal is requested for a transaction that is still in `pending` state, the system MUST transition it directly to `failed` without restoring balance (pending transactions have not yet deducted balance)

### SAML/SSO Edge Cases

- **IdP metadata refresh failure**: If the periodic metadata refresh fails (IdP endpoint down), the system MUST continue using the cached metadata until the next successful refresh. If no cached metadata exists, SAML login for that enterprise MUST fail gracefully with a user-facing error
- **SAML assertion without required attributes**: If the SAML assertion is missing `email` or `user_permanent_id`, the system MUST reject the authentication and log the missing attributes (without logging the full assertion)
- **Duplicate enterprise user linking**: If a SAML-authenticated user already exists in the LMS but is not linked to the enterprise customer, the system MUST auto-link them (create `EnterpriseCustomerUser` record) on successful SAML login. If the user is already linked to a different enterprise customer, the system MUST still link them (multi-org support) without unlinking the existing association
- **SAML clock skew**: The system MUST tolerate up to 120 seconds of clock skew between the LMS and the IdP when validating `NotBefore` and `NotOnOrAfter` conditions

### Catalog Sync Edge Cases

- **Course deletion during sync**: If a course is removed from the LMS discovery service between catalog syncs, the next sync MUST mark the content as unavailable in the enterprise catalog (soft delete) rather than hard-deleting the metadata record
- **Catalog filter returning zero results**: If an enterprise catalog's content filter matches no courses, the catalog MUST remain valid (empty catalog is a valid state) and the admin portal MUST display a clear message indicating no content matches the filter
- **Discovery service unavailable during sync**: If the discovery service is unreachable, the sync task MUST retry 3 times with exponential backoff. If all retries fail, it MUST log an error, emit an alert, and preserve the last successful sync state

### Integrated Channel Edge Cases

- **External API rate limiting**: If the external system (Degreed, CSOD) returns HTTP 429, the sync task MUST respect the `Retry-After` header and reschedule the remaining batch. It MUST NOT retry immediately in a tight loop
- **Credential rotation**: If a client rotates their Degreed/CSOD API credentials, the sync MUST fail with a clear "authentication failure" log message on the next run. Updating credentials in the LMS admin MUST take effect on the next sync cycle without service restart
- **Large learner set pagination**: For enterprises with >10,000 learners, the channel sync MUST paginate data fetches from the LMS (batch of 500) to avoid memory exhaustion
- **DSC revocation mid-sync**: If a learner revokes data sharing consent between the start and end of a sync, the system MUST exclude that learner from the current sync payload. Already-transmitted data is the responsibility of the enterprise data processing agreement

### Rate Limiting

- Enterprise admin API MUST return HTTP 429 with `Retry-After` header when rate limits are exceeded
- Enterprise service-to-service calls (e.g., enterprise-access calling enterprise-catalog) MUST use a separate, higher rate limit tier (10,000 requests/minute) to avoid blocking internal operations

---

## Observability

### Logs

- **All enterprise services**: Structured JSON logs to stdout, captured by Promtail and shipped to Loki. Every log line MUST include: `service_name`, `enterprise_customer_uuid` (when in request context), `request_id` (correlation ID), `log_level`, `timestamp`
- **License manager**: License state transition events MUST be logged with: `license_uuid`, `old_state`, `new_state`, `enterprise_customer_uuid`, `subscription_plan_uuid`, `triggered_by` (admin user ID or system)
- **Enterprise subsidy**: Transaction events MUST be logged with: `transaction_uuid`, `subsidy_uuid`, `enterprise_customer_uuid`, `content_key`, `quantity`, `resulting_balance`, `state`
- **Enterprise catalog sync**: Sync events MUST be logged with: `enterprise_customer_uuid`, `catalog_uuid`, `sync_started_at`, `sync_completed_at`, `items_added`, `items_removed`, `items_updated`, `errors`
- **Integrated channels**: Sync events MUST be logged with: `channel_type`, `enterprise_customer_uuid`, `sync_started_at`, `learners_synced`, `learners_skipped` (no DSC), `errors`, `external_api_response_codes`
- **SAML authentication**: Auth events MUST be logged with: `event_type` (attempt, success, failure), `enterprise_customer_uuid`, `idp_entity_id`, `assertion_issuer`, `error_code` (if failure). MUST NOT log assertion XML or user PII beyond a hashed email
- **Sensitive data rule**: MUST NOT log: raw SAML assertions, email addresses (use hashed form), API keys, OAuth tokens, database passwords, full user names

### Metrics

- `enterprise_catalog_sync_duration_seconds` (histogram, labels: `enterprise_customer_uuid`, `outcome`) -- catalog sync task duration
- `enterprise_catalog_sync_items_total` (counter, labels: `enterprise_customer_uuid`, `operation` [added, removed, updated])
- `enterprise_catalog_api_requests_total` (counter, labels: `endpoint`, `status_code`, `enterprise_customer_uuid`)
- `enterprise_catalog_api_latency_seconds` (histogram, labels: `endpoint`)
- `license_manager_assignments_total` (counter, labels: `enterprise_customer_uuid`, `outcome` [success, failure, duplicate])
- `license_manager_revocations_total` (counter, labels: `enterprise_customer_uuid`, `outcome`)
- `license_manager_utilization_ratio` (gauge, labels: `enterprise_customer_uuid`, `subscription_plan_uuid`) -- assigned+activated / total
- `enterprise_access_policy_evaluations_total` (counter, labels: `policy_type`, `enterprise_customer_uuid`, `outcome` [allowed, denied])
- `enterprise_access_redemptions_total` (counter, labels: `enterprise_customer_uuid`, `outcome`)
- `enterprise_subsidy_balance_remaining` (gauge, labels: `enterprise_customer_uuid`, `subsidy_uuid`, `unit`)
- `enterprise_subsidy_transactions_total` (counter, labels: `enterprise_customer_uuid`, `state` [committed, failed, reversed])
- `enterprise_integrated_channels_sync_duration_seconds` (histogram, labels: `channel_type`, `enterprise_customer_uuid`)
- `enterprise_integrated_channels_sync_learners_total` (counter, labels: `channel_type`, `enterprise_customer_uuid`, `outcome` [synced, skipped, failed])
- `enterprise_saml_auth_total` (counter, labels: `enterprise_customer_uuid`, `outcome` [success, failure], `failure_reason`)
- `enterprise_service_health` (gauge, labels: `service_name`) -- 1 for healthy, 0 for unhealthy

### Alerts

- **Critical**: Any enterprise service health check fails for > 3 consecutive checks (1 minute) -- page oncall
- **Critical**: `enterprise_subsidy_balance_remaining` drops below 10% of `starting_balance` for any active subsidy -- notify enterprise success team
- **Critical**: `license_manager_utilization_ratio` exceeds 0.95 for any active subscription -- notify enterprise success team
- **Warning**: `enterprise_catalog_sync_duration_seconds` exceeds 30 minutes -- notify channel
- **Warning**: `enterprise_integrated_channels_sync_duration_seconds` exceeds 60 minutes -- notify channel
- **Warning**: `enterprise_saml_auth_total{outcome=failure}` rate exceeds 10% over 15 minutes -- notify channel
- **Warning**: `enterprise_access_policy_evaluations_total{outcome=denied}` rate exceeds 50% over 1 hour for any enterprise customer -- notify channel (may indicate misconfigured policy)
- **Info**: `license_manager_assignments_total` shows zero activity for an active subscription for 30 days -- notify enterprise success team (underutilized subscription)

### Dashboards

- **Enterprise Overview**: Active enterprise customers count, total licenses assigned vs total available, total subsidy balance remaining, active SAML IdP count
- **License Utilization**: Per-customer license pool utilization (assigned/activated/revoked), trending over 30 days, expiring subscription plans
- **Catalog Health**: Sync success rate, items per catalog, last sync time per catalog, catalog query latency percentiles
- **Subsidy Ledger**: Per-customer balance burn rate, transaction volume, reversal rate, projected exhaustion date
- **Integrated Channels**: Sync success/failure rate per channel type per customer, learner sync volume, last successful sync timestamp
- **Enterprise Auth**: SAML login success/failure rate per IdP, auto-provisioned user count, average SSO login duration

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Infrastructure Preparation (Week 1-2)
1. Provision enterprise service MySQL databases in Cloud SQL
2. Create MySQL users with per-database grants
3. Provision all enterprise secrets in Infisical at `/k8s/mereka-lms`
4. Sync secrets to GCP Secret Manager
5. Create ExternalSecret manifest (`enterprise-secrets`)
6. Build enterprise service Docker images and push to Artifact Registry
7. Register OAuth2 client applications in LMS Django admin for each enterprise service
8. Verify the `openedx-enterprise` package is present in the LMS image (it ships with Tutor by default)

#### Phase 1: Enterprise Catalog and Subsidy (Week 3-4)
1. Deploy enterprise-catalog service (Deployment + Service + worker)
2. Run database migrations via init container
3. Verify health endpoint and Prometheus scraping
4. Configure first enterprise customer in LMS Django admin
5. Create enterprise catalog with content filter
6. Verify catalog sync runs and populates content metadata
7. Deploy enterprise-subsidy service
8. Create first subsidy record and verify ledger operations

#### Phase 2: License Manager and Access (Week 5-6)
1. Deploy license-manager service
2. Create first subscription plan for pilot enterprise customer
3. Verify license assignment, activation, and revocation flows
4. Deploy enterprise-access service
5. Create access policies linking catalogs, subscriptions, and subsidies
6. Verify end-to-end enrollment flow: learner requests enrollment -> access policy evaluated -> license consumed or subsidy deducted -> enrollment created

#### Phase 3: Enterprise MFEs (Week 7-8)
1. Build and deploy `frontend-app-admin-portal`
2. Configure Caddy routing for `admin.academyv2.mereka.io`
3. Verify admin portal login and dashboard
4. Build and deploy `frontend-app-learner-portal-enterprise`
5. Configure Caddy routing for `learner.academyv2.mereka.io`
6. Verify learner portal catalog browsing and enrollment

#### Phase 4: SSO/SAML and Integrated Channels (Week 9-10)
1. Configure SAML IdP for first pilot enterprise client
2. Test slug-based login flow end-to-end
3. Test auto-provisioning of new users via SAML
4. Configure Degreed integration for pilot client
5. Run channel sync in dry-run mode, verify payload
6. Enable live channel sync with monitoring

#### Phase 5: Production Hardening (Week 11-12)
1. Enable all alerts and dashboards
2. Load test: simulate 50 concurrent license assignments
3. Load test: simulate 10,000 learner catalog queries
4. Security review: verify tenant isolation under adversarial conditions
5. Onboard second enterprise client to validate repeatability
6. Document operational runbook

### Feature Flags

- `ENABLE_ENTERPRISE_CATALOG_SERVICE` -- gate routing to enterprise-catalog service (LMS setting, default: off)
- `ENABLE_LICENSE_MANAGER` -- gate license management features in admin portal (default: off)
- `ENABLE_ENTERPRISE_SUBSIDY` -- gate subsidy-based enrollment (default: off)
- `ENABLE_ENTERPRISE_ACCESS_POLICIES` -- gate access policy evaluation (default: off)
- `ENABLE_ENTERPRISE_LEARNER_PORTAL` -- gate learner portal MFE link in LMS navigation (default: off)
- `ENABLE_ENTERPRISE_ADMIN_PORTAL` -- gate admin portal MFE access (default: off)
- `ENABLE_ENTERPRISE_SSO` -- gate SAML/OIDC configuration for enterprise clients (default: off)
- `ENABLE_INTEGRATED_CHANNELS` -- gate channel sync tasks (default: off)
- All feature flags MUST be configurable per enterprise customer UUID where applicable (not just globally)

### Backward Compatibility

- Deploying enterprise services MUST NOT affect existing LMS functionality (course enrollment, learner experience, Studio)
- The existing ecommerce service MUST continue to operate independently; enterprise subsidy and ecommerce are complementary systems
- The existing discovery service MUST continue to serve the standard course catalog; enterprise-catalog maintains its own copy and does not modify the source
- Existing users who are not linked to any enterprise customer MUST see no changes in their LMS experience
- The `mereka-lms` namespace MUST continue to function if enterprise services are scaled to zero (no hard dependency from LMS on enterprise services)

### Rollback Steps

#### Per-Service Rollback
1. Scale the failing enterprise service Deployment to 0 replicas: `kubectl scale deployment <service-name> -n mereka-lms --replicas=0`
2. Disable the corresponding feature flag in the LMS
3. The LMS and existing services continue operating without enterprise features
4. Investigate the issue using logs in Loki and metrics in Grafana
5. Fix and redeploy when ready; scale Deployment back to desired replicas

#### Full Enterprise Stack Rollback
1. Disable all enterprise feature flags in the LMS
2. Scale all enterprise service Deployments to 0: `kubectl scale deployment -l app.kubernetes.io/component=enterprise -n mereka-lms --replicas=0`
3. Enterprise MFEs will show "service unavailable" or redirect to LMS (no crash)
4. Existing enrollments created via enterprise services REMAIN active (enrollments are stored in the LMS database, not enterprise service databases)
5. Re-enable by scaling Deployments back up and toggling feature flags

#### Database Rollback
1. Enterprise service databases are independent of the LMS `openedx` database
2. If an enterprise service database is corrupted, restore from the latest Cloud SQL backup (automated daily backups)
3. The LMS continues operating normally during enterprise database restoration
4. After restoration, restart the affected enterprise service to reconnect

#### SSO/SAML Rollback
1. Disable the enterprise customer's SAML configuration in Django admin (set `enabled=False` on the SAML provider config)
2. Enterprise users can still log in via standard LMS login (username/password or Google/Apple SSO) while SAML is disabled
3. Re-enable SAML when the IdP issue is resolved

---

## Monorepo Location

These services deploy **upstream Open edX community images** — no forked source code lives in this repo. Configuration and deployment manifests only:

| Component | Path | Notes |
|-----------|------|-------|
| K8s manifests (all 5 services) | `deploy/k8s/base/apps/enterprise/` | Deployments, Services, HPA |
| Celery worker manifests | `deploy/k8s/base/apps/enterprise/workers/` | Worker Deployments per service |
| ExternalSecrets | `deploy/k8s/base/secrets/external-secrets.yaml` | OAuth2 credentials, DB passwords |
| Tutor plugin config | `infrastructure/tutor/` | LMS settings for enterprise integration |
| MFE config (admin portal) | `deploy/k8s/base/apps/mfe/` | Admin portal + learner portal MFE config |
| Provisioning scripts | `scripts/infra/enterprise/` | Tenant onboarding automation |

**Note**: If Mereka-specific patches are needed for any enterprise service, we build custom images and track the Dockerfiles under `services/enterprise-<name>/` — but the default is to use upstream images.

---

## Open Questions

1. ~~**Event bus transport**~~: **RESOLVED** — Redis Streams is the platform-wide event bus (see `specs/cross-cutting-requirements_spec.md`, Technology Decisions). Capacity planning for event throughput under multi-client load is still needed as a separate task.

2. **Cloud SQL tier**: What is the current Cloud SQL tier and can it support 4 additional databases with the expected enterprise query load? Need to measure current database utilization before provisioning.

3. **Algolia vs Elasticsearch for catalog search**: The upstream enterprise-catalog service supports Algolia for search. Should we use Algolia (SaaS, costs money) or Elasticsearch (already deployed in-cluster)? Algolia provides a better admin portal search UX but adds an external dependency and cost.

4. **Enterprise service image source**: Should we build enterprise service images from source (fork the repos) or use pre-built images from the Open edX community? Forking allows customization but increases maintenance burden. Pre-built images are simpler but may not include Mereka-specific patches.

5. **Admin portal domain**: The spec proposes `admin.academyv2.mereka.io` for the enterprise admin portal. This is a multi-level subdomain that requires DNS-only + Let's Encrypt (per CLAUDE.md Cloudflare SSL limitation). Should we use a different domain pattern like `enterprise-admin.mereka.io` to simplify SSL?

6. **Enterprise customer onboarding automation**: Should onboarding be fully manual (Django admin) for v1, or should we build an onboarding API/script from the start? Manual is faster to ship but error-prone for complex configurations (SAML, catalog filters, access policies).

7. **Data sharing consent UI**: Should the data sharing consent flow use the Open edX upstream consent page or a custom Mereka-branded page? The upstream page is functional but visually sparse.

8. **License cost model**: How are license costs tracked? Is `enterprise-subsidy` the financial ledger for all enterprise billing, or do we use Stripe (via ecommerce) for enterprise invoicing and subsidy only for learner credit budgets?

9. **Multi-org learner UX**: When a learner belongs to multiple enterprise customers, how should the learner portal handle context switching? Options: (a) selector dropdown at portal login, (b) separate portal URLs per enterprise, (c) unified view showing all enterprise content. Need UX input.

10. **Integrated channels priority**: Which channel integrations are highest priority for initial clients? The spec lists Degreed and Cornerstone as launch targets, but actual client requirements may differ. Need client roster input.

11. **Resource sizing**: What are the baseline CPU/memory requests and limits for each enterprise service? The spec assumes 2.5 vCPU / 5 GB RAM total but this needs validation with load testing. Open edX upstream repos may have recommended values.

12. ~~**GKE node pool capacity**~~: **RESOLVED** — Current 3-node pool (12 vCPU, ~48 GB RAM) has sufficient capacity. Enterprise services consume only 14m CPU (0.12%) and 1.1 GB RAM (2.9%) at idle, well within available headroom.

---

## Deployment Status (2026-02-10)

### ✅ Successfully Deployed

**Backend Services (7 deployments, 8 pods):**
1. `enterprise-catalog` (1 pod, port 8160) - Course catalog API + metadata sync
2. `enterprise-catalog-worker` (1 pod) - Celery worker for async indexing
3. `enterprise-access` (1 pod, port 18270) - Access policy evaluation + subsidy enrollment
4. `enterprise-access-worker` (1 pod) - Celery worker for async tasks
5. `enterprise-subsidy` (1 pod, port 18280) - Subsidy ledger + transaction tracking
6. `enterprise-admin-portal` (1 pod, port 8002) - React MFE for B2B admin
7. `enterprise-learner-portal` (1 pod, port 8002) - React MFE for enterprise learners

**Infrastructure:**
- 12 secrets provisioned in Infisical → synced to GCP Secret Manager → K8s ExternalSecrets
- 4 MySQL databases created (enterprise_catalog, enterprise_access, enterprise_subsidy, license_manager)
- 3 Docker images pushed to Artifact Registry (catalog, access, subsidy)
- 5 ClusterIP Services configured
- 1 Ingress configured for MFE portals with TLS (cert-manager)
- Integrated channels configured in LMS (Degreed, Cornerstone, SAP, Canvas, Moodle, Blackboard)

**Actual Resource Consumption:**
- CPU: 14m (0.12% of cluster capacity at idle)
- Memory: 1.1 GB (2.9% of cluster capacity)
- Cluster health: **IMPROVED** after deployment (CPU -8.4%, Memory -8.7% vs baseline)

**Monitoring & Observability:**
- 3 ServiceMonitors deployed (`enterprise-catalog-metrics`, `enterprise-access-metrics`, `enterprise-subsidy-metrics`)
- 1 PrometheusRule deployed (`enterprise-alerts`) with 12 alert rules:
  - Pod down alerts (critical, 5m window)
  - Pod restart alerts (warning, >5 restarts in 15m)
  - Memory usage alerts (warning, >85% of limit for 10m)
  - CPU usage alerts (warning, >85% of limit for 10m)
- Monitoring files: `deploy/k8s/base/monitoring/servicemonitor-enterprise.yaml`, `prometheusrule-enterprise.yaml`
- Status: **Infrastructure monitoring active**, application metrics pending (requires django-prometheus instrumentation)

### ⚠️ Not Deployed (Deferred)

1. **license-manager**: No upstream Docker image available at `docker.io/openedx/license-manager`. Requires building from source. Database and secrets provisioned but service not deployed. License functionality can be added later if needed.

### 🔧 Configuration Patterns Discovered

**Critical Fixes Applied:**
- Health probes: Use `/health/` not `/heartbeat/` (heartbeat endpoint doesn't exist)
- Celery broker: Set component parts (CELERY_BROKER_TRANSPORT, etc.) not full URL
- Cache backend: Use Django 4.2+ built-in `django.core.cache.backends.redis.RedisCache`
- Config-gen pattern: Python init container generates YAML from env vars → emptyDir volume

**Service-Specific Details:**
- Ports: catalog=8160, subsidy=18280, access=18270 (NOT 8000)
- CFG env vars: catalog=`ENTERPRISE_CATALOG_CFG`, subsidy=`EDX_ENTERPRISE_SUBSIDY_CFG` (EDX_ prefix!), access=`ENTERPRISE_ACCESS_CFG`
- Redis DB assignments: catalog cache=8/celery=9, subsidy cache=10, access cache=12/celery=13
- Celery support: catalog and access have workers; subsidy has NO celery installed

---

## Verification

### Machine-Checkable Verification

Run the automated verification script:
```bash
./scripts/qa/verify-enterprise-deployment.sh
```

This script checks:
1. All 7 deployments are ready
2. All pods are running with low restart counts
3. All 5 services have endpoints
4. Health checks return 200
5. Resource usage within expected bounds (<100m CPU, <2000Mi memory)
6. All secrets exist in K8s
7. Integrated channels configured in LMS
8. No ImagePullBackOff or CrashLoopBackOff states
9. MFE ingress exists with IP assigned
10. Config-gen init containers present

**Exit code 0 = all checks passed, exit code 1 = failures detected**

### Manual Verification Commands

**Check deployment status:**
```bash
kubectl get deployments -n mereka-lms -l app.kubernetes.io/component=enterprise
kubectl get pods -n mereka-lms -l app.kubernetes.io/component=enterprise
```

**Check service endpoints:**
```bash
kubectl get services -n mereka-lms -l app.kubernetes.io/component=enterprise
kubectl get endpoints -n mereka-lms -l app.kubernetes.io/component=enterprise
```

**Test health endpoints:**
```bash
# enterprise-catalog
kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8160/health/

# enterprise-access
kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-access -- curl -s -o /dev/null -w "%{http_code}" http://localhost:18270/health/

# enterprise-subsidy
kubectl exec -n mereka-lms -l app.kubernetes.io/name=enterprise-subsidy -- curl -s -o /dev/null -w "%{http_code}" http://localhost:18280/health/
```

**Check resource consumption:**
```bash
kubectl top pods -n mereka-lms -l app.kubernetes.io/component=enterprise
```

**Verify secrets:**
```bash
kubectl get secret enterprise-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys'
```

### Expected Output

All commands should show healthy status:
- Deployments: 7/7 ready
- Pods: 7-9 running (depending on access service replicas)
- Services: 5 ClusterIP services with non-empty endpoints
- Health checks: HTTP 200 responses
- Resource usage: <50m CPU, <1500Mi memory at idle
