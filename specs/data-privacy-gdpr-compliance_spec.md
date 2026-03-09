---
title: "Data Privacy & GDPR Compliance"
type: "feature_spec"
id: "SPEC-DAT-002"
status: "draft"
spec_class: "security"
owner: "engineering"
vehicle: "talent_platform"
created: "2026-02-10"
last_reviewed: "2026-03-09"
review_due: "2026-06-09"
domain: "data"
normativity: "normative"
last_updated: "2026-02-10"
version: "1.0.0"
depends_on:
  - "specs/enterprise-microservices_spec.md"
  - "specs/multi-tenancy-architecture_spec.md"
  - "specs/ecommerce-purchase-gateway_spec.md"
  - "specs/email-notifications-pipeline_spec.md"
  - "specs/badges-credentials-enterprise_spec.md"
  - "specs/content-libraries-v2_spec.md"
  - "specs/advanced-assessment-xqueue_spec.md"
  - "specs/proposals/external-registration-hubspot_spec.md"
supersedes: []
superseded_by: null
verification_sources:
  - "scripts/qa/run-spec-integrity-gates.sh"
interfaces:
  - "Open edX"
  - "Purchase Gateway"
  - "Aspects"
  - "MongoDB Atlas"
tags:
  - "data.pii"
  - "data.retention"
  - "docs.evidence"
summary: "Defines the platform-wide privacy, consent, deletion, export, and compliance controls for personal data across the Mereka LMS stack."
links:
  related_docs:
    - "docs/ops/runbooks/DATA_ERASURE_RUNBOOK.md"
    - "docs/ops/runbooks/TROUBLESHOOTING.md"
    - "docs/concepts/architecture/multi-tenancy-overview.md"
  related_specs:
    - "specs/analytics-pipeline_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/ecommerce-purchase-gateway_spec.md"
    - "specs/auth-sso-enterprise_spec.md"
    - "specs/multi-tenancy-architecture_spec.md"
    - "specs/enterprise-microservices_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/disaster-recovery-business-continuity_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
---

# Human Summary

## What we're building

A cross-platform data privacy and compliance framework for Mereka Academy that enforces GDPR (EU General Data Protection Regulation), PDPA (Malaysia Personal Data Protection Act 2010), and SOC 2 Type II requirements across every service that touches personally identifiable information. The scope spans the entire Open edX stack -- LMS, CMS, Forum, Ecommerce (legacy and new Purchase Gateway), Discovery, Notes, Credentials, XQueue, analytics (Aspects/ClickHouse), and the observability pipeline (Loki/Tempo/Prometheus) -- plus all external data processors (Stripe, MongoDB Atlas, Google Cloud, Infisical, SendGrid).

The framework delivers five foundational capabilities:

1. **PII Inventory and Data Map**: A machine-verifiable registry of every PII field across every data store (MySQL, MongoDB Atlas, Redis, ClickHouse, PostgreSQL, Loki, object storage), classified by sensitivity tier, legal basis for processing, retention period, and the set of services that read or write each field.

2. **Consent Management**: A centralized consent service that records, versions, and enforces user consent decisions across all processing activities, with granular opt-in/opt-out controls, consent withdrawal workflows, and per-tenant consent policy configuration for enterprise clients.

3. **Right to Be Forgotten (Data Deletion Pipeline)**: An orchestrated, cross-service data deletion pipeline that, upon a verified deletion request, removes or anonymizes all PII for a given user across MySQL, MongoDB Atlas, PostgreSQL (Purchase Gateway), ClickHouse (analytics), Redis (cache/session), Loki (logs), and object storage (profile images, certificate PDFs), with cryptographic proof of completion.

4. **Data Portability (Export Pipeline)**: A self-service data export capability that packages all personal data for a user into a structured, machine-readable archive (JSON + CSV) covering enrollment records, course progress, grades, certificates, forum posts, notes, purchase history, consent records, and audit trail entries.

5. **Compliance Governance**: Audit trail infrastructure, Data Processing Impact Assessment (DPIA) templates, breach notification procedures, data processing agreements (DPA) with third-party processors, and automated compliance reporting dashboards.

## Why it matters

Mereka Academy serves enterprise clients across ASEAN (Malaysia, Singapore, Indonesia, Thailand, Philippines) and is expanding into EU markets. The analytics pipeline spec (`specs/analytics-pipeline_spec.md`) explicitly defers GDPR compliance as a non-goal and lists "SLA for data deletion requests" as an open question. The ecommerce purchase gateway spec stores buyer emails, order histories, and Stripe customer IDs. The auth/SSO spec provisions and deprovisions user accounts with identity provider data. The multi-tenancy spec requires per-tenant data offboarding. None of these specs define a unified privacy contract.

Without this spec:
- Enterprise clients (especially those with EU employees or PDPA-regulated Malaysian operations) cannot contractually commit to using the platform because there is no provable compliance posture
- A single GDPR subject access request (SAR) or deletion request would require manual forensic work across 8+ databases with no orchestration, no verification, and no audit trail
- PII leaks into analytics events, application logs, and observability traces with no systematic detection or prevention
- There is no consent record for data processing, meaning every enrollment, analytics event, and forum post is processed without demonstrable legal basis
- A data breach would trigger notification obligations under GDPR (72 hours) and PDPA (notification to Commissioner) with no procedure, no contact list, and no incident commander assignment

## Success looks like

- A GDPR data subject can exercise their right to erasure and receive cryptographic proof of deletion within 30 days across all 8+ data stores, with zero manual intervention
- A PDPA-regulated enterprise client receives a Data Processing Agreement (DPA) and Data Processing Impact Assessment (DPIA) within 5 business days of request
- PII exposure in analytics events, application logs, and traces is zero: automated scanning detects and flags any PII leakage within 24 hours
- Consent records exist for every active user, versioned and timestamped, with audit trail entries for every consent change
- Data export requests produce a complete, machine-readable archive within 72 hours
- The compliance dashboard shows real-time status: pending deletion requests, consent coverage percentage, PII scan results, retention policy adherence, and breach notification readiness
- SOC 2 Type II auditors can pull evidence packages (access logs, consent records, deletion proofs, DPA inventory) directly from the compliance API

---

# Agent Contract

## Scope

- In scope:
  - Complete PII inventory across all Open edX services and data stores (MySQL, MongoDB Atlas, PostgreSQL, Redis, ClickHouse, Loki, object storage)
  - PII classification taxonomy (sensitivity tiers, legal basis, retention period, processing purposes)
  - Consent management service: consent collection, storage, versioning, enforcement, withdrawal
  - Per-tenant consent policy configuration for enterprise clients
  - Cookie consent and tracking pixel management for LMS and MFE frontend surfaces
  - Right-to-be-forgotten implementation: cross-service data deletion pipeline with orchestration, verification, and proof of completion
  - Data portability: self-service data export pipeline producing structured archives
  - Data retention policies per data category and legal basis
  - Audit trail infrastructure: tamper-evident logging of all privacy-relevant events
  - Data Processing Impact Assessment (DPIA) template and workflow
  - Breach notification procedures: detection, classification, notification timelines, contact lists, communication templates
  - Third-party data processor inventory and DPA requirements (Stripe, MongoDB Atlas, Google Cloud, Infisical, SendGrid, Cloudflare)
  - Data residency requirements and cross-border transfer safeguards
  - Privacy-by-design architecture principles for new and existing services
  - PII leakage detection in logs, metrics, traces, and analytics events
  - Compliance reporting API and dashboards
  - Integration with the existing secrets management pipeline for encryption key management
  - GDPR (EU), PDPA (Malaysia), and SOC 2 Type II control mapping

- Out of scope:
  - Implementing GDPR compliance for services outside the Mereka Academy platform (e.g., corporate websites, marketing tools)
  - Building a standalone consent management platform (SaaS CMP product)
  - Legal review or drafting of privacy policies, terms of service, or DPA contract text (legal counsel responsibility; this spec defines technical requirements)
  - Implementing region-specific data residency via multi-region GKE clusters (all data currently resides in `asia-southeast1`; multi-region is a future enhancement)
  - PCI DSS compliance (Stripe handles all card data per `specs/ecommerce-purchase-gateway_spec.md`)
  - HIPAA compliance (no health data is processed)
  - Children's data protection (COPPA, Age Appropriate Design Code) unless an enterprise tenant specifically requires it
  - Mobile app privacy controls (covered by `specs/proposals/mobile-apps-enterprise_spec.md`)

## Non-goals

- Building a general-purpose privacy compliance framework applicable to any SaaS product (this is purpose-built for the Mereka Academy Open edX stack)
- Achieving compliance certification without external auditor engagement (this spec provides the technical infrastructure; certification requires auditor attestation)
- Implementing real-time PII masking in database queries at the database proxy layer (application-level controls are the initial approach)
- Supporting GDPR "right to restriction of processing" as a distinct technical mechanism separate from consent withdrawal (consent withdrawal achieves the same effect)
- Implementing automated data subject identity verification (identity verification for deletion/export requests is an operational procedure handled by support staff for v1)
- Building per-field encryption for all PII at rest (encryption at rest is handled at the infrastructure layer by GCP and MongoDB Atlas; application-level field encryption is a future enhancement for the highest sensitivity tier)

## Assumptions

- The Open edX platform stores PII primarily in MySQL (user profiles, enrollments, grades, certificates), MongoDB Atlas (forum posts, modulestore), and Redis (sessions, cache)
- The Purchase Gateway adds PostgreSQL as a PII-bearing data store (buyer emails, order history, Stripe customer IDs)
- The analytics pipeline (ClickHouse) is configured to anonymize user identifiers per `specs/analytics-pipeline_spec.md` requirements, but verification is needed
- The observability stack (Loki, Tempo) may contain PII in log lines and trace attributes -- this must be audited and addressed
- MongoDB Atlas provides encryption at rest and in transit (confirmed by Atlas configuration)
- GCP Cloud SQL provides encryption at rest via Google-managed keys
- GCP provides GDPR-compliant Data Processing Addendum
- The existing `UserRetirementStatus` model in Open edX provides a foundation for the deletion pipeline (the platform has a partial retirement workflow)
- Enterprise tenants may require their own DPAs and DPIAs as conditions of contract
- The platform will be subject to both GDPR (EU data subjects) and PDPA (Malaysian data subjects) simultaneously
- SOC 2 Type II audit is planned within 12 months and requires evidence collection infrastructure

---

## Requirements

### Functional

#### PII Inventory and Data Map

- The system MUST maintain a machine-readable PII registry (YAML or JSON) enumerating every field across all data stores that contains or derives from personal data
- The PII registry MUST classify each field using the following attributes:
  - `data_store`: which database/service holds the field (e.g., `mysql:auth_user`, `mongodb:cs_comments_service`, `postgresql:purchase_gateway.orders`)
  - `field_name`: the column or document field name
  - `pii_type`: classification (e.g., `email`, `name`, `ip_address`, `device_fingerprint`, `location`, `payment_identifier`, `learning_record`, `behavioral_data`)
  - `sensitivity_tier`: `critical` (direct identifiers like email, name, SSN), `high` (indirect identifiers like IP, device ID, location), `medium` (pseudonymized identifiers like hashed user IDs), `low` (aggregated or anonymized data)
  - `legal_basis`: one of `consent`, `contract`, `legal_obligation`, `legitimate_interest`, `vital_interest`, `public_task` per GDPR Article 6
  - `retention_period`: how long the data is retained (e.g., `account_lifetime`, `90_days`, `7_years_financial`, `30_days_logs`)
  - `processing_purposes`: array of purposes (e.g., `authentication`, `enrollment`, `analytics`, `billing`, `support`)
  - `services_with_access`: array of services that read or write this field
  - `deletion_method`: how the field is handled during right-to-erasure (`delete`, `anonymize`, `retain_legal_obligation`)
  - `export_included`: whether the field is included in data portability exports (`yes`, `no`, `redacted`)
- The PII registry MUST be version-controlled in the repository at `specs/pii-registry.yml`
- The system MUST provide a validation tool that checks the PII registry against actual database schemas and flags drift (new fields not in registry, registry entries for deleted fields)
- The PII registry MUST be reviewed and updated whenever a new service is added, a database schema is migrated, or a new third-party processor is integrated

#### PII Data Store Inventory

- The system MUST document PII in the following data stores:

  **MySQL (Open edX core)**:
  - `auth_user`: `email`, `username`, `first_name`, `last_name`, `date_joined`, `last_login`
  - `auth_userprofile`: `name`, `gender`, `date_of_birth`, `phone_number`, `country`, `city`, `bio`, `profile_image_uploaded_at`
  - `student_courseenrollment`: `user_id`, `course_id`, `created` (learning record)
  - `grades_persistentcoursegrade`: `user_id`, `course_id`, `percent_grade`, `letter_grade`, `passed_timestamp`
  - `certificates_generatedcertificate`: `user_id`, `course_id`, `name`, `download_url`
  - `consent_datasharingconsent`: `username`, `enterprise_customer_uuid`, `granted`
  - `student_anonymoususerid`: `user_id`, `anonymous_user_id` (pseudonymization mapping)
  - `django_session`: `session_data` (may contain serialized user data)
  - `user_api_userorgtag`: `user_id`, `key`, `value` (custom user metadata)
  - `social_auth_usersocialauth`: `user_id`, `provider`, `uid` (SSO identifiers)

  **MongoDB Atlas (Forum, Modulestore)**:
  - `cs_comments_service.contents`: `author_username`, `author_id`, `body` (may contain PII in free text), `votes`
  - `cs_comments_service.users`: `username`, `email` (if stored), `external_id`
  - `openedx.modulestore.structures`: content authored by users (Studio content, generally not PII unless user-submitted)

  **PostgreSQL (Purchase Gateway)**:
  - `orders`: `buyer_email`, `buyer_user_id`, `stripe_customer_id`, `stripe_checkout_session_id`, `metadata`
  - `entitlements`: `recipient_email`, `claimed_by_user_id`
  - `stripe_events`: `payload` (contains buyer email, name in Stripe event JSON)
  - `order_audit_log`: `triggered_by` (may contain user identifiers)

  **ClickHouse (Analytics)**:
  - `xapi_events_all`: `actor_id` (hashed), `actor_mbox` (MUST be hashed, not raw email)
  - Any materialized views derived from events

  **Redis**:
  - Session data: serialized user session containing `user_id`, potentially `email`
  - Celery task arguments: may contain user identifiers in task payloads
  - Cache entries: may contain serialized user profile data

  **Loki (Logs)**:
  - Application log lines: may contain `email`, `username`, `ip_address`, `user_agent` in request logs
  - Error tracebacks: may contain user data in exception context

  **Object Storage (GCS)**:
  - Profile images: `profile-images/{username}/`
  - Certificate PDFs: per-user certificate files
  - Course export archives: may contain user-submitted content

#### PII Data Classification Matrix

- The system MUST maintain a data classification matrix mapping each data store to PII categories, retention policies, access controls, and deletion mechanisms:

  | Data Store | Data Categories | PII Sensitivity Tier | Legal Basis | Retention Period | Access Controls | Deletion Mechanism | Verification Method |
  |------------|-----------------|---------------------|-------------|------------------|-----------------|-------------------|---------------------|
  | **MySQL: auth_user** | Email, name, auth timestamps | Critical (direct identifiers) | Contract | Account lifetime | LMS/CMS backend, admin panel | Anonymize (replace with `retired_email_{hash}@retired.invalid`, `retired_user_{hash}`) | Query for `retired_` prefixes |
  | **MySQL: auth_userprofile** | Demographics, profile images | Critical (direct identifiers) | Contract | Account lifetime | LMS backend, profile API | Delete record entirely | `SELECT COUNT(*)` for user_id returns 0 |
  | **MySQL: student_courseenrollment** | Learning records (enrollments) | High (learning behavior) | Contract | Account lifetime or per enterprise DPA | LMS backend, analytics pipeline | Delete or anonymize per DPA terms | Query by user_id returns empty |
  | **MySQL: grades_persistentcoursegrade** | Learning records (grades) | High (learning behavior) | Contract | Account lifetime or per enterprise DPA | LMS backend, instructor dashboard | Delete or anonymize per DPA terms | Query by user_id returns empty |
  | **MySQL: certificates_generatedcertificate** | Certificates (name, course) | Critical (achievement record) | Legitimate interest | 10 years or account lifetime | LMS backend, certificate API | Revoke and delete (archive notification sent) | Query for user_id returns empty, GCS bucket has no cert files |
  | **MySQL: consent_datasharingconsent** | Consent decisions | Medium (compliance evidence) | Legal obligation | 5 years post-relationship | Privacy service, admin panel | Anonymize user identifiers only (retain consent decision for evidence) | Consent records exist with anonymized `username` |
  | **MySQL: student_anonymoususerid** | Pseudonymization mapping | Medium (hashed identifiers) | Legitimate interest | Account lifetime | Analytics pipeline (read-only) | Delete mapping | Query for user_id returns empty |
  | **MySQL: django_session** | Session state (serialized) | High (may contain email/profile) | Contract | 24 hours after session expiry | Session middleware (auto TTL) | Automatic expiry + manual invalidation | Redis/MySQL session table query for user_id returns empty |
  | **MySQL: user_api_userorgtag** | Custom user metadata | High (varies by tag) | Contract | Account lifetime | LMS backend | Delete records | Query for user_id returns empty |
  | **MySQL: social_auth_usersocialauth** | SSO provider identifiers | High (authentication identity) | Contract | Account lifetime | Django social-auth backend | Delete records | Query for user_id returns empty |
  | **MongoDB Atlas: cs_comments_service.contents** | Forum posts (may contain voluntarily disclosed PII) | Medium (user-generated content) | Consent (forum participation) | Account lifetime (anonymized on deletion) | Forum API, LMS forum views | Anonymize author (replace `author_username` with `[deleted]`, retain post body for community value) | Query for `author_username: "retired_user_{hash}"` |
  | **MongoDB Atlas: cs_comments_service.users** | Forum user profiles | High (username, email) | Consent | Account lifetime | Forum API | Delete user record | Query for external_id or username returns empty |
  | **MongoDB Atlas: openedx.modulestore.structures** | Course content authored by users | Low (generally not PII unless user-submitted assignments) | Contract (for instructors) | Course lifetime | CMS backend, modulestore API | Anonymize author attribution only (do not delete course content serving other learners) | Author fields anonymized |
  | **PostgreSQL: orders (Purchase Gateway)** | Order records (buyer email, Stripe IDs) | Critical (financial + identity) | Contract (for orders within fulfillment period), Legal obligation (7-year retention) | 7 years (financial records) | Purchase Gateway API, Stripe webhook handler | Anonymize `buyer_email` to `retired_{hash}@retired.invalid`, retain `order_uuid`, `total_cents`, `currency` for accounting | Query for `buyer_email` returns only anonymized values |
  | **PostgreSQL: entitlements (Purchase Gateway)** | Entitlement grants (recipient email) | Critical (identity) | Contract | Account lifetime or redemption + 90 days | Purchase Gateway API | Anonymize `recipient_email` | Query for `recipient_email` with real email returns empty |
  | **PostgreSQL: stripe_events** | Stripe webhook payloads (contains buyer PII) | Critical (PII in JSON payload) | Contract | 90 days | Purchase Gateway Stripe webhook handler | Delete events older than 90 days, anonymize buyer email in `payload` JSON | Query for user email in `payload` returns empty |
  | **PostgreSQL: order_audit_log** | Audit trail for order state changes | Medium (contains user identifiers in `triggered_by`) | Legal obligation | 7 years | Audit log query API | Anonymize `triggered_by` user identifiers | User identifiers in audit log are anonymized |
  | **ClickHouse: xapi_events_all** | Learning analytics events | High (behavioral data, MUST use hashed identifiers) | Legitimate interest or Consent (per jurisdiction) | 365 days (anonymized beyond 90 days) | Analytics dashboard (Superset/Aspects), data science queries | Delete all events where `actor_id` matches user's hashed ID | Query for `actor_id = hash(user_id)` returns empty |
  | **ClickHouse: materialized views** | Aggregated analytics | Medium (derived from events) | Legitimate interest | Tied to source event retention | Analytics dashboard | Drop and rebuild views after event deletion | Views recalculated without user's events |
  | **Redis: session keys** | Active user sessions | High (serialized session contains user_id, email) | Contract | 24 hours (TTL-based) | Django session middleware | Delete all keys matching `user:{user_id}:*` pattern | `KEYS user:{user_id}:*` returns empty |
  | **Redis: Celery task queues** | Async task payloads (may contain user identifiers) | Medium (task args may include user_id) | Contract | Task completion or 7 days (dead letter) | Celery workers | Not directly deletable (ephemeral); flush dead-letter queue matching user_id | Scan Celery result backend for user_id returns empty |
  | **Redis: cache entries** | Cached user profile/enrollment data | High (serialized user data) | Contract | 1 hour - 24 hours (TTL-based) | LMS/CMS caching layer | Delete all keys matching `user_profile:{user_id}`, `enrollment:{user_id}:*` | `KEYS *{user_id}*` returns empty |
  | **Loki: application logs** | Request logs, error tracebacks (may contain email, IP, user agent) | High (may leak PII if not sanitized) | Legitimate interest | 30 days (retention policy) | Grafana Explore, observability dashboards | Not directly deletable (Loki does not support selective deletion); rely on 30-day retention policy + flag user_id for future log scrubbing | PII leakage scanner confirms no raw email/username in recent logs; 30-day expiry handles historical logs |
  | **Tempo: distributed traces** | Trace spans (may contain user_id in span attributes) | Medium (hashed user identifiers preferred) | Legitimate interest | 30 days | Grafana Tempo, trace search | Not directly deletable; rely on 30-day retention policy | Verify span attributes use hashed user_id, not raw email |
  | **GCS: profile images** | User-uploaded profile images | Critical (visual identity) | Contract | Account lifetime | LMS profile image API | Delete blobs matching `profile-images/{username}/*` | GCS bucket query for username path returns empty |
  | **GCS: certificate PDFs** | Generated certificate files | Critical (achievement record) | Legitimate interest | 10 years or account lifetime | Certificate download API, LMS backend | Delete blobs matching `certificates/{course_id}/{username}/*` | GCS bucket query for username path returns empty |
  | **GCS: course export archives** | Zipped course exports (may contain student submissions) | Medium (may contain user-submitted content) | Contract (for instructors) | 90 days post-export | CMS export API | Delete blobs older than 90 days; filter user-submitted content on export | GCS retention policy + manual deletion for active courses |
  | **GCS: backup snapshots (MySQL/MongoDB)** | Database backups containing all PII | Critical (full dataset replica) | Legitimate interest (disaster recovery) | 90 days (rotation) | Database restore procedures only | Automatic rotation; user deletion takes effect in backups after 90 days | Backup metadata shows no snapshots older than 90 days |
  | **Meilisearch: forum search index** | Indexed forum posts (author, body) | Medium (derived from forum data) | Consent (forum participation) | Real-time sync with forum data | Forum search API | Delete documents where `author_id` matches user, or re-anonymize indexed posts | Meilisearch query for user_id or username returns empty |

- The classification matrix MUST be reviewed and updated whenever:
  - A new data store is added to the platform
  - A database schema migration adds PII-bearing fields
  - A new third-party processor begins storing personal data
  - Retention policies are changed by legal counsel
  - A DPIA identifies new PII processing risks

- The system MUST provide a verification tool that validates the classification matrix against actual database schemas and flags:
  - PII-bearing fields in production databases not listed in the matrix (new PII risk)
  - Matrix entries referencing tables/fields that no longer exist in schemas (stale documentation)
  - Mismatches between documented retention periods and actual data age in production (retention policy violations)

#### Consent Management

- The system MUST implement a consent management service that records user consent for each distinct processing purpose
- The system MUST define the following consent purposes (at minimum):
  - `essential_service`: processing necessary for the learning platform to function (legal basis: `contract`; not opt-out-able)
  - `analytics`: processing for learning analytics and platform improvement (legal basis: `legitimate_interest` or `consent` depending on jurisdiction)
  - `marketing_communications`: email marketing, promotional content (legal basis: `consent`; opt-in required)
  - `third_party_sharing`: sharing data with enterprise tenant administrators (legal basis: `contract` for enterprise users, `consent` for non-enterprise)
  - `cookie_analytics`: non-essential cookies and tracking pixels (legal basis: `consent`; opt-in required for EU users)
  - `forum_participation`: processing forum posts which may contain voluntarily disclosed PII (legal basis: `consent`)
- Each consent record MUST include: `user_id`, `purpose`, `granted` (boolean), `granted_at` (timestamp), `withdrawn_at` (nullable timestamp), `consent_version` (version of the privacy policy/consent text shown), `collection_method` (e.g., `registration_form`, `preference_center`, `cookie_banner`, `api`, `enterprise_enrollment`), `ip_address_hash` (hashed IP at time of consent for evidentiary purposes), `tenant_id` (nullable, for per-tenant consent policies)
- The system MUST version consent records: updating a consent decision MUST create a new record (append-only), not overwrite the existing one
- The system MUST support consent withdrawal: a user MUST be able to withdraw consent for any non-essential purpose at any time through the preference center
- Consent withdrawal MUST take effect within 24 hours (processing stops for the withdrawn purpose)
- The system MUST provide a consent preference center accessible to authenticated users at `/account/privacy/`
- The system MUST enforce consent decisions at the application layer: services MUST check consent status before processing data for a given purpose
- The system MUST support per-tenant consent policies: enterprise tenants MAY define additional consent purposes or modify default consent text (within regulatory limits)
- The system SHOULD support pre-checked consent for purposes with `contract` or `legitimate_interest` legal basis (where jurisdictionally permitted)
- The system MUST NOT pre-check consent checkboxes for purposes requiring explicit opt-in (EU: all marketing and analytics consent)

#### Cookie Consent and Tracking Management

- The system MUST implement a cookie consent banner on all LMS and MFE frontend surfaces for users in jurisdictions requiring cookie consent (EU, UK)
- The cookie consent banner MUST categorize cookies into: `strictly_necessary` (session, CSRF, authentication), `analytics` (Google Analytics, Aspects event collection), `marketing` (HubSpot, advertising pixels), `functional` (language preferences, UI customization)
- The system MUST NOT set non-essential cookies until the user has granted consent for the corresponding category
- The system MUST persist cookie consent preferences in a first-party cookie and in the consent management backend
- The system MUST provide a mechanism to revoke cookie consent at any time (accessible from the privacy preference center)
- The system SHOULD support geo-based consent banner behavior: show consent banner to EU/UK users, show notice-only to ASEAN users (where PDPA does not require opt-in cookie consent)
- The system MUST maintain a cookie inventory documenting: cookie name, purpose, category, duration, first-party vs third-party, associated service

#### Right to Be Forgotten (Data Deletion Pipeline)

- The system MUST implement a cross-service data deletion pipeline that handles GDPR Article 17 erasure requests
- The deletion pipeline MUST be triggered by an authenticated API call: `POST /api/v1/privacy/deletion-request/` with the requesting user's credentials (or admin credentials on behalf of a user)
- The system MUST support the following deletion request states: `pending_verification`, `verified`, `processing`, `completed`, `partially_completed`, `failed`, `rejected` (with rejection reason)
- Upon a verified deletion request, the system MUST orchestrate deletion across all data stores in the following order:
  1. **Session invalidation**: Immediately invalidate all active sessions for the user (Redis session store)
  2. **Account deactivation**: Deactivate the user account in `auth_user` (set `is_active=false`) to prevent further data generation
  3. **Forum content**: Anonymize forum posts by replacing `author_username` with `[deleted]` and removing author attribution (posts are retained for community value per GDPR Recital 65; full deletion available if user requests)
  4. **Analytics events**: Delete or anonymize all events in ClickHouse where `actor_id` matches the user's hashed identifier
  5. **Purchase records**: Anonymize `buyer_email` in the Purchase Gateway PostgreSQL database; retain `order_uuid`, `total_cents`, `currency`, and financial fields for accounting obligations (7-year retention per Malaysian Companies Act 2016)
  6. **Notes**: Delete all user notes from the Notes service database
  7. **Enrollment and grade records**: Delete enrollment records, grades, and progress data from MySQL (or retain anonymized records per retention policy if required by enterprise DPA)
  8. **Certificates**: Revoke and delete certificate records and PDFs from object storage
  9. **Profile data**: Delete `auth_userprofile` record, profile images from object storage
  10. **User account**: Anonymize `auth_user` record: replace `email` with `retired_email_{hash}@retired.invalid`, replace `username` with `retired_user_{hash}`, clear `first_name` and `last_name`
  11. **SSO linkages**: Delete `social_auth_usersocialauth` records for the user
  12. **Consent records**: Retain consent records as evidence of lawful processing (GDPR Article 7(1)), but anonymize user identifiers
  13. **Audit trail entries**: Retain privacy-related audit entries with anonymized user identifiers (compliance evidence)
  14. **Cache cleanup**: Invalidate all Redis cache entries containing the user's data
  15. **Log anonymization**: Flag the user ID for log anonymization (Loki retention policy handles expiry; immediate deletion from logs is impractical)
- The deletion pipeline MUST complete within 30 calendar days of the verified request (GDPR Article 12(3) compliance)
- The system MUST generate a deletion proof record upon completion: a signed document listing every data store processed, the deletion/anonymization action taken, the timestamp of completion, and a hash of the deletion manifest
- The system MUST send a confirmation notification to the user's original email address (stored temporarily during the deletion process) upon completion
- The system MUST handle partial failures: if deletion fails for one data store, the pipeline MUST continue processing remaining stores, mark the request as `partially_completed`, and alert the privacy operations team
- The system MUST support re-running a partially completed deletion to process the failed stores
- The system MUST reject deletion requests where legal retention obligations override the right to erasure (e.g., financial records within the mandatory retention period), and MUST inform the user of the specific legal basis for retention
- The system MUST maintain a deletion request log (separate from the deleted user's data) for compliance auditing

#### Data Portability (Export Pipeline)

- The system MUST implement a data export pipeline for GDPR Article 20 data portability requests
- The export pipeline MUST be accessible via self-service: `POST /api/v1/privacy/export-request/` by the authenticated user
- The export MUST produce a structured archive (ZIP file) containing:
  - `profile.json`: user profile data (name, email, date of birth, country, bio)
  - `enrollments.json`: all course enrollments with dates and status
  - `grades.json`: all course grades and completion records
  - `certificates.json`: certificate metadata and download links
  - `forum_posts.json`: all forum posts authored by the user
  - `notes.json`: all user notes
  - `purchases.json`: all purchase/order records from the Purchase Gateway
  - `consents.json`: all consent records and their history
  - `audit_log.json`: privacy-relevant audit trail entries for the user
  - `README.md`: human-readable explanation of the archive contents and format
- The export MUST be generated within 72 hours of the request (well within GDPR's 30-day limit)
- The export archive MUST be encrypted with a user-provided password or a one-time download link with 48-hour expiry
- The system MUST delete the export archive from server-side storage after download or after 7 days (whichever comes first)
- The system MUST log the export request and completion in the audit trail
- The system MUST rate-limit export requests: one pending request per user at a time, maximum 3 requests per user per 30-day period

#### Data Retention Policies

- The system MUST enforce the following retention periods by data category:

  | Data Category | Retention Period | Legal Basis | Deletion Method |
  |---------------|-----------------|-------------|-----------------|
  | Active user account | Account lifetime | Contract | User-initiated or admin deletion |
  | Inactive user account (no login >24 months) | 24 months after last login | Legitimate interest | Automated reminder at 18 months, deletion at 24 months |
  | Session data (Redis) | 24 hours after session expiry | Contract | Automatic TTL |
  | Application logs (Loki) | 30 days | Legitimate interest | Loki retention policy |
  | Analytics events (ClickHouse) | 365 days (anonymized beyond 90 days) | Legitimate interest / consent | Automatic partition drop |
  | Financial records (orders, payments) | 7 years | Legal obligation (Malaysian Companies Act 2016, GDPR Art. 6(1)(c)) | Anonymize PII, retain financial data |
  | Certificate records | 10 years (or account lifetime, whichever is longer) | Legitimate interest / contract | Deletion upon user request (after archival) |
  | Consent records | Duration of relationship + 5 years | Legal obligation (GDPR Art. 7 evidence) | Anonymize user identifier after retention period |
  | Forum posts | Account lifetime (anonymized on deletion) | Legitimate interest | Anonymize author on user deletion |
  | Notes | Account lifetime | Contract | Delete on user account deletion |
  | Audit trail entries | 7 years | Legal obligation / legitimate interest | Retain with anonymized identifiers |
  | Profile images | Account lifetime | Contract | Delete on user account deletion |
  | Backup data | 90 days | Legitimate interest | Automatic rotation |

- The system MUST implement automated retention enforcement: a scheduled job MUST scan for data exceeding its retention period and execute the specified deletion method
- The retention enforcement job MUST run at least weekly
- The system MUST log all automated retention deletions in the audit trail

#### Audit Trail

- The system MUST maintain a tamper-evident audit trail for all privacy-relevant events
- The audit trail MUST record the following event types:
  - `consent_granted`, `consent_withdrawn`, `consent_updated`
  - `deletion_requested`, `deletion_verified`, `deletion_processing`, `deletion_completed`, `deletion_failed`
  - `export_requested`, `export_completed`, `export_downloaded`
  - `pii_access` (when an admin or system process accesses PII outside normal operations)
  - `breach_detected`, `breach_classified`, `breach_notified`
  - `retention_enforcement_executed`
  - `dpa_signed`, `dpa_expired`
- Each audit trail entry MUST include: `event_id` (UUID), `event_type`, `user_id` (or anonymized reference), `actor_id` (who performed the action), `tenant_id`, `timestamp`, `details` (JSON), `integrity_hash` (SHA-256 hash of the entry concatenated with the previous entry's hash, forming a hash chain)
- The audit trail MUST be append-only: entries MUST NOT be modified or deleted (except for the user identifier anonymization during right-to-erasure, which MUST itself be logged)
- The audit trail MUST be stored in a dedicated database table (not in application logs) to ensure durability and queryability
- The system SHOULD replicate audit trail entries to an immutable storage backend (GCS with object versioning and retention policy) for tamper resistance

#### Breach Notification

- The system MUST define a breach notification procedure compliant with GDPR Article 33 (72-hour supervisory authority notification) and PDPA Section 12B (notification to Commissioner and affected individuals)
- The breach notification procedure MUST include:
  1. **Detection**: automated PII leakage scanning, anomaly detection on data access patterns, alerts from the observability stack
  2. **Classification**: severity assessment (number of records affected, sensitivity tier, scope of exposure), determination of whether notification is required (risk to rights and freedoms of data subjects)
  3. **Containment**: immediate steps to stop the breach (revoke credentials, patch vulnerability, isolate affected systems)
  4. **Assessment**: within 24 hours, produce an impact report: what data, how many users, what services, what jurisdictions
  5. **Notification to supervisory authority**: within 72 hours of becoming aware (GDPR), or "as soon as practicable" (PDPA)
  6. **Notification to affected data subjects**: without undue delay if high risk to rights and freedoms (GDPR Art. 34), or as directed by Commissioner (PDPA)
  7. **Remediation**: root cause analysis, corrective action, updated DPIA
  8. **Post-incident review**: lessons learned, updated procedures, staff training
- The system MUST maintain a breach notification contact list in Infisical or a protected configuration store, containing: Data Protection Officer (DPO) contact, supervisory authority contacts (EU: relevant national DPA; Malaysia: Personal Data Protection Commissioner), legal counsel contact, incident response team members, executive escalation chain
- The system MUST provide a breach notification template (pre-filled with platform details) that can be completed and dispatched within the 72-hour window
- The system MUST log all breach notification activities in the audit trail

#### Third-Party Data Processor Inventory

- The system MUST maintain a Data Processor Inventory documenting every third party that processes personal data on behalf of Mereka Academy
- The inventory MUST include for each processor:
  - Processor name and legal entity
  - Data processing purpose
  - Categories of personal data processed
  - Data location (region/country)
  - DPA status (signed, pending, not applicable)
  - Sub-processor disclosure (whether the processor uses sub-processors)
  - Data transfer mechanism for cross-border transfers (e.g., Standard Contractual Clauses, adequacy decision)
- The system MUST document the following processors (at minimum):

  | Processor | Purpose | Data Processed | Location | DPA Status |
  |-----------|---------|---------------|----------|------------|
  | Google Cloud (GCP) | Infrastructure, Cloud SQL, GCS, GKE | All platform data | asia-southeast1 (Singapore) | Google Cloud DPA (signed) |
  | MongoDB Atlas | Forum data, modulestore | Forum posts, course structure | AWS ap-southeast-1 (Singapore) | MongoDB DPA (required) |
  | Stripe | Payment processing | Buyer email, name, payment methods | US/EU (Stripe data residency varies) | Stripe DPA (required) |
  | Infisical | Secrets management | Secret names (not user PII directly) | Self-hosted (secrets.mereka.io) | N/A (self-hosted) |
  | Cloudflare | CDN, DNS, DDoS protection | IP addresses, request metadata | Global (edge nodes) | Cloudflare DPA (required) |
  | SendGrid (if adopted) | Transactional email | Email addresses, names | US | SendGrid DPA (required) |

- The system MUST verify that each processor with `DPA Status: required` has a signed DPA before production data is shared
- The system MUST review the processor inventory annually and after any new integration

#### Data Residency and Cross-Border Transfers

- The system MUST document the geographic location of all data stores:
  - GCP Cloud SQL (MySQL): `asia-southeast1` (Singapore)
  - MongoDB Atlas: AWS `ap-southeast-1` (Singapore)
  - GCP GKE (pods, Redis): `asia-southeast1` (Singapore)
  - ClickHouse (analytics): in-cluster (`asia-southeast1`)
  - PostgreSQL (Purchase Gateway): Cloud SQL `asia-southeast1` or in-cluster
  - Object Storage (GCS): `asia-southeast1`
  - Loki/Tempo (observability): VPS at Contabo (Singapore)
- The system MUST ensure that EU personal data processed under GDPR has a valid transfer mechanism when stored outside the EEA (Standard Contractual Clauses for Singapore-based processing, as Singapore does not have an EU adequacy decision)
- The system SHOULD support configurable data residency per tenant: enterprise tenants MAY specify a required data residency region in their DPA
- The system MUST NOT transfer personal data to jurisdictions without adequate protection without a valid legal mechanism (SCCs, BCRs, or explicit consent)
- For Stripe: the system MUST configure Stripe to process payments in the appropriate Stripe data region (if available) or document the transfer mechanism for cross-border Stripe data flows

#### Privacy by Design

- All new services and features MUST undergo a Privacy Impact Assessment (PIA) before development begins, documented in the spec or a linked DPIA document
- All new APIs MUST minimize PII in request/response payloads: return only the PII necessary for the stated purpose
- All new log statements MUST NOT contain raw PII (email, name, IP address); use hashed or redacted values
- All new database schemas MUST classify fields against the PII registry taxonomy before migration approval
- All new third-party integrations MUST be added to the Data Processor Inventory before production deployment
- The system MUST implement data minimization: do not collect PII that is not required for a stated processing purpose
- The system SHOULD implement pseudonymization by default for analytics and observability: use hashed user IDs, not raw identifiers
- The system MUST implement access controls: only services with a documented need (per PII registry `services_with_access`) SHOULD access PII fields
- The system MUST enforce encryption in transit (TLS 1.2+) for all inter-service communication and all external API calls
- The system MUST enforce encryption at rest for all data stores containing PII (GCP-managed encryption for Cloud SQL and GCS; Atlas-managed encryption for MongoDB)

#### Compliance Reporting

- The system MUST expose a compliance API for generating audit evidence:
  - `GET /api/v1/privacy/compliance/consent-coverage/`: percentage of active users with complete consent records
  - `GET /api/v1/privacy/compliance/deletion-requests/`: list of deletion requests with status and SLA compliance
  - `GET /api/v1/privacy/compliance/export-requests/`: list of export requests with status
  - `GET /api/v1/privacy/compliance/pii-scan-results/`: latest PII leakage scan results across logs and analytics
  - `GET /api/v1/privacy/compliance/retention-status/`: data categories with records exceeding retention period
  - `GET /api/v1/privacy/compliance/processor-inventory/`: third-party processor list with DPA status
  - `GET /api/v1/privacy/compliance/audit-trail/`: filtered audit trail query
- The compliance API MUST require `privacy_admin` or `compliance_officer` role authentication
- The system MUST provide a Grafana compliance dashboard aggregating the above metrics

### Non-Functional Requirements

#### Performance

- Consent check API (is user consented for purpose X?) MUST respond in <= 10ms at p95 (cached)
- Data deletion pipeline MUST complete all store deletions within 72 hours of pipeline execution start (well within the 30-day GDPR deadline, accounting for verification lead time)
- Data export pipeline MUST produce the export archive within 72 hours for users with up to 100,000 learning events
- PII leakage scanner MUST process 7 days of logs (Loki) within 4 hours
- Audit trail write latency MUST be <= 50ms at p95

#### Reliability

- The deletion pipeline MUST be idempotent: re-running deletion for the same user MUST NOT fail if some stores have already been processed
- The deletion pipeline MUST handle data store unavailability gracefully: retry with exponential backoff (base 30 seconds, max 1 hour, max retries 20), then mark the store as `failed` and continue with remaining stores
- The export pipeline MUST not degrade LMS request latency: exports MUST be processed by background workers, not in the request path
- The consent management service MUST be available at 99.9% uptime (consent checks gate data processing)

#### Security

- The deletion proof MUST be cryptographically signed with a platform key stored in Infisical
- Export archives MUST be encrypted (AES-256) before storage and transfer
- The audit trail integrity hash chain MUST be verifiable by an independent auditor tool
- Access to the compliance API MUST be restricted to authorized personnel with `privacy_admin` or `compliance_officer` roles
- PII in Stripe event payloads stored in the Purchase Gateway `stripe_events` table MUST be encrypted at the application level (field-level encryption for `payload` column) using a key managed via Infisical
- The system MUST NOT expose PII in Prometheus metrics labels (no email, username, or user ID in metric labels)

#### Compliance

- The system MUST meet GDPR requirements for: lawful basis documentation (Art. 6), consent management (Art. 7), data subject rights (Art. 15-22), data protection by design (Art. 25), records of processing activities (Art. 30), security (Art. 32), breach notification (Art. 33-34), data protection impact assessment (Art. 35), data transfers (Art. 44-49)
- The system MUST meet PDPA (Malaysia) requirements for: general principle (proportionality), notice and choice principle, disclosure principle, security principle, retention principle, data integrity principle, access principle
- The system MUST produce evidence artifacts mappable to SOC 2 Type II Trust Service Criteria: CC6 (Logical and Physical Access Controls), CC7 (System Operations), CC8 (Change Management), PI1 (Privacy Criteria)

---

## Acceptance Criteria

### PII Inventory

- [ ] AC-001: Given the PII registry at `specs/pii-registry.yml`, when the validation tool is run against all database schemas, then zero unregistered PII fields are flagged and zero registry entries reference non-existent fields
- [ ] AC-002: Given a new database migration that adds a field containing PII, when the migration is submitted for review, then the CI pipeline requires the PII registry to be updated (validation tool returns non-zero exit code if field is not registered)

### Consent Management

- [ ] AC-003: Given a new user registration, when the user completes the registration form, then consent records are created for all mandatory processing purposes with `granted=true` and for optional purposes according to user selection
- [ ] AC-004: Given an authenticated user, when they visit `/account/privacy/`, then they see all consent purposes with their current consent status and can toggle non-essential consents
- [ ] AC-005: Given a user withdraws consent for `analytics`, when the withdrawal is saved, then analytics event collection for that user stops within 24 hours and a `consent_withdrawn` audit entry is created
- [ ] AC-006: Given a user in the EU visits the LMS, when the page loads, then a cookie consent banner is displayed and no non-essential cookies are set until consent is granted
- [ ] AC-007: Given a user grants cookie consent for `analytics` category, when they subsequently revoke it, then analytics cookies are cleared and the tracking pixel is deactivated on the next page load

### Right to Be Forgotten

- [ ] AC-008: Given an authenticated user submits a deletion request via `POST /api/v1/privacy/deletion-request/`, when the request is verified, then the deletion pipeline begins processing within 48 hours
- [ ] AC-009: Given a deletion pipeline runs for user X, when all stores are processed successfully, then: (a) `auth_user.email` is replaced with `retired_email_{hash}@retired.invalid`, (b) `auth_user.username` is replaced with `retired_user_{hash}`, (c) `auth_userprofile` record is deleted, (d) forum posts show `[deleted]` as author, (e) profile image is deleted from GCS, (f) Redis sessions are invalidated, (g) ClickHouse events for the user are deleted/anonymized, (h) Purchase Gateway `buyer_email` is anonymized
- [ ] AC-010: Given a deletion pipeline completes, when the proof is generated, then the proof document contains: the deletion request ID, each data store name, the action taken (deleted/anonymized/retained with reason), the timestamp of completion, and a valid cryptographic signature
- [ ] AC-011: Given a deletion request for a user with financial records within the 7-year retention period, when the pipeline processes the Purchase Gateway, then financial amounts and order UUIDs are retained (anonymized PII) and the deletion proof notes the legal retention basis
- [ ] AC-012: Given a deletion pipeline fails for MongoDB Atlas (network error), when the failure is detected, then the request transitions to `partially_completed`, the remaining stores are still processed, and an alert is fired to the privacy operations team

### Data Portability

- [ ] AC-013: Given an authenticated user submits an export request via `POST /api/v1/privacy/export-request/`, when the export is generated, then a ZIP archive is produced containing `profile.json`, `enrollments.json`, `grades.json`, `certificates.json`, `forum_posts.json`, `notes.json`, `purchases.json`, `consents.json`, `audit_log.json`, and `README.md`
- [ ] AC-014: Given an export archive is generated, when the user accesses the download link, then the archive is encrypted and the download link expires after 48 hours
- [ ] AC-015: Given a user has already submitted 3 export requests in the current 30-day period, when they submit a 4th request, then the request is rejected with HTTP 429 and a message indicating the rate limit

### Data Retention

- [ ] AC-016: Given a user account with no login for 18 months, when the retention enforcement job runs, then a reminder email is sent to the user warning of impending account deletion at 24 months
- [ ] AC-017: Given a user account with no login for 24 months and no response to the 18-month reminder, when the retention enforcement job runs, then the account enters the deletion pipeline
- [ ] AC-018: Given ClickHouse analytics events older than 365 days, when the retention enforcement job runs, then those partitions are dropped
- [ ] AC-019: Given Loki log entries older than 30 days, when the Loki retention policy executes, then those entries are no longer queryable

### Audit Trail

- [ ] AC-020: Given any consent change, deletion request, export request, or breach event, when the event occurs, then an audit trail entry is created within 1 second with a valid integrity hash linking to the previous entry
- [ ] AC-021: Given an auditor runs the integrity verification tool against the audit trail, when no tampering has occurred, then the hash chain validates completely with zero broken links
- [ ] AC-022: Given the audit trail is replicated to GCS, when an entry is tampered with in the database, then the GCS copy provides evidence of the original entry

### Breach Notification

- [ ] AC-023: Given the PII leakage scanner detects raw email addresses in Loki log entries, when the scan completes, then a `breach_detected` audit entry is created and a Warning alert is fired to the privacy operations team
- [ ] AC-024: Given a confirmed data breach affecting more than 100 users, when the incident commander classifies it as high severity, then the breach notification template is auto-populated with breach details and the supervisory authority contact list is retrieved from the breach contact registry

### PII Leakage Detection

- [ ] AC-025: Given a Loki log query for raw email patterns (`[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`), when the PII leakage scanner runs, then any log lines matching the pattern are flagged in the scan results
- [ ] AC-026: Given ClickHouse `xapi_events_all` contains a field with unhashed email (violating the anonymization requirement), when the PII scanner runs, then the field is flagged as a critical PII leakage

### Compliance Reporting

- [ ] AC-027: Given a `privacy_admin` user, when they call `GET /api/v1/privacy/compliance/consent-coverage/`, then the response includes the percentage of active users with consent records for each purpose
- [ ] AC-028: Given one or more pending deletion requests, when the compliance dashboard is viewed, then each request shows its status, elapsed time, and SLA compliance (green if within 30 days, red if overdue)

### Cross-Service Integration

- [ ] AC-029: Given the analytics pipeline processes an event, when the user has withdrawn `analytics` consent, then the event is dropped before reaching ClickHouse
- [ ] AC-030: Given a tenant offboarding is initiated per `specs/multi-tenancy-architecture_spec.md`, when the offboarding completes, then all tenant user data has been processed through either the deletion pipeline or the export pipeline per the tenant's DPA terms

### GDPR Deletion Workflow

- [ ] AC-GDPR-DEL-001: Given a user submits a right-to-be-forgotten request, when the deletion pipeline executes, then all PII across all 8+ data stores MUST be deleted or anonymized within 30 days. Partial deletion failures MUST be reported to the compliance team within 24 hours.
- [ ] AC-031: Given a verified right-to-erasure request for a user, when the deletion pipeline completes across all data stores (MySQL, MongoDB Atlas, Redis, ClickHouse, GCS), then a cryptographic deletion certificate MUST be generated listing each data store, records deleted count, and SHA-256 hash of the deletion log
- [ ] AC-032: Given a deletion pipeline execution where one data store fails (e.g., MongoDB timeout), when the failure is detected, then all completed deletions MUST be logged, the pipeline MUST retry the failed store 3 times with exponential backoff, and if still failing MUST alert ops and pause (NOT rollback successful deletions since data is already gone)
- [ ] AC-033: Given a completed deletion for user X, when a Subject Access Request is submitted for user X, then the SAR pipeline MUST return zero personal data records and include the deletion certificate reference
- [ ] AC-034: Given a completed right-to-erasure request, when the deletion certificate is generated, then the requesting user (or DPO if user account deleted) MUST receive an email confirmation within 24 hours listing the deletion date and certificate reference

### PII Data Classification and Inventory

- [ ] AC-PRIVACY-001: Given the PII Data Classification Matrix is deployed, when a privacy audit is conducted, then every PII-bearing field in production MUST be documented in the matrix with: data store name, PII sensitivity tier (critical/high/medium/low), legal basis for processing, retention period, access controls, and deletion mechanism
- [ ] AC-PRIVACY-002: Given a database schema migration adds a new field containing PII (e.g., `user_phone_verified_at`), when the migration is merged to main, then the PII classification matrix MUST be updated to include the new field before deployment, or CI MUST block the deployment
- [ ] AC-PRIVACY-003: Given the PII classification matrix documents that `MySQL: auth_user.email` has retention period "Account lifetime" and deletion mechanism "Anonymize to retired_email_{hash}@retired.invalid", when a right-to-erasure request completes, then verification queries MUST confirm `auth_user.email` for the user matches pattern `retired_email_*@retired.invalid`
- [ ] AC-PRIVACY-004: Given the classification matrix lists `ClickHouse: xapi_events_all.actor_mbox` with sensitivity tier "Critical" and requirement "MUST be hashed, not raw email", when the PII leakage scanner runs against ClickHouse, then any `actor_mbox` field containing raw email format (regex match for `@` with domain) MUST be flagged as critical violation
- [ ] AC-PRIVACY-005: Given the classification matrix specifies `GCS: profile-images/{username}/` retention as "Account lifetime" with deletion mechanism "Delete blobs matching path pattern", when a deletion pipeline completes, then GCS bucket verification MUST confirm zero blobs exist under `profile-images/{username}/` for the deleted user
- [ ] AC-PRIVACY-006: Given the classification matrix documents `PostgreSQL: orders.buyer_email` legal basis as "Legal obligation (7-year financial retention)" with deletion mechanism "Anonymize buyer_email, retain order_uuid and amounts", when a deletion request is processed for a user with orders within 7-year window, then `orders.buyer_email` MUST be anonymized to `retired_{hash}@retired.invalid` AND `order_uuid`, `total_cents`, `currency` MUST remain unchanged
- [ ] AC-PRIVACY-007: Given the classification matrix specifies `MongoDB Atlas: cs_comments_service.contents.author_username` deletion mechanism as "Anonymize author (replace with [deleted], retain post body)", when a deletion pipeline completes, then MongoDB queries for posts originally authored by the user MUST return `author_username: "[deleted]"` AND `body` field MUST be unchanged (posts retained for community value per GDPR Recital 65)
- [ ] AC-PRIVACY-008: Given the classification matrix lists `Redis: session keys` retention as "24 hours TTL" with deletion mechanism "Delete all keys matching user:{user_id}:* pattern", when a deletion pipeline begins, then Redis verification MUST confirm `KEYS user:{user_id}:*` returns empty list after session invalidation step
- [ ] AC-PRIVACY-009: Given the classification matrix documents `Loki: application logs` retention as "30 days" with deletion mechanism "Not directly deletable; rely on retention policy + PII leakage prevention", when a deletion request is submitted, then the deletion proof MUST note that log entries will naturally expire within 30 days AND PII leakage scanner MUST confirm no new logs containing the user's email are being written post-deletion
- [ ] AC-PRIVACY-010: Given the classification matrix is updated (e.g., retention period for certificates changed from "10 years" to "5 years"), when the update is committed, then a privacy impact assessment (PIA) MUST be triggered AND affected users MUST be notified if the change reduces their data retention rights

### Data Export Pipeline (Phase 2)

- [ ] AC-EXPORT-001: Given a user submits an export request via `POST /api/v1/privacy/export-request/`, when the export pipeline begins, then the system MUST aggregate data from all stores listed in the classification matrix marked `export_included: yes` (MySQL user profile, enrollments, grades, certificates, forum posts, notes, purchases, consents, audit log)
- [ ] AC-EXPORT-002: Given the export pipeline aggregates data from MySQL, MongoDB Atlas, PostgreSQL, and ClickHouse, when any single data store is temporarily unavailable (e.g., MongoDB Atlas network timeout), then the export pipeline MUST retry the failed store 3 times with exponential backoff (30s, 60s, 120s), and if still failing MUST continue processing remaining stores, mark the export as `partially_completed`, and include a `MISSING_DATA.txt` file in the archive listing which stores failed
- [ ] AC-EXPORT-003: Given an export request completes successfully, when the ZIP archive is generated, then the archive MUST contain: `profile.json` (auth_user + auth_userprofile fields), `enrollments.json` (course_id, enrollment date, status), `grades.json` (course_id, grade, pass/fail), `certificates.json` (course_id, certificate URL, issue date), `forum_posts.json` (post body, thread, timestamps), `notes.json` (note text, course context), `purchases.json` (order_uuid, total, currency, date, anonymized Stripe customer ID), `consents.json` (purpose, granted status, timestamps, consent version), `audit_log.json` (privacy-relevant events for user), `README.md` (human-readable explanation of archive structure, GDPR Article 20 reference)
- [ ] AC-EXPORT-004: Given an export archive is generated, when the archive is downloaded, then the archive MUST be AES-256 encrypted with either: (a) user-provided password (collected during export request), OR (b) auto-generated password sent via separate communication channel (email to user's registered address)
- [ ] AC-EXPORT-005: Given an export archive download link is generated, when 48 hours elapse OR the user downloads the archive once, then the download link MUST expire (HTTP 410 Gone) AND the server-side archive file MUST be deleted from temporary storage within 1 hour of expiry
- [ ] AC-EXPORT-006: Given a user submits an export request, when an export for the same user is already in `processing` state, then the API MUST return HTTP 409 Conflict with the existing export request ID and estimated completion time (not create duplicate export)
- [ ] AC-EXPORT-007: Given a user submits an export request, when the user has already completed 3 export requests within the trailing 30-day window, then the API MUST return HTTP 429 Too Many Requests with `Retry-After` header set to seconds until oldest export exits the 30-day window
- [ ] AC-EXPORT-008: Given an export request is submitted, when the export generation exceeds 72 hours (SLA breach), then the export request status MUST transition to `failed`, an alert MUST fire to privacy operations team, the user MUST receive an email notification with failure reason, and the user MUST be offered a retry option (bypassing rate limit for retry)
- [ ] AC-EXPORT-009: Given an export archive is successfully generated, when the user downloads the archive, then an audit trail entry MUST be created with event type `export_downloaded`, including: `export_request_id`, `user_id_hash`, `download_timestamp`, `download_ip_address_hash`, `archive_size_bytes`
- [ ] AC-EXPORT-010: Given an export request completes, when the archive contains data from 7+ data stores totaling 500MB+, then the export pipeline MUST split the archive into multiple ZIP files (max 200MB each), each encrypted separately, with a manifest file listing all archive parts and their SHA-256 checksums

### Data Deletion Pipeline (Phase 2)

- [ ] AC-DELETE-001: Given a deletion pipeline begins execution, when the pipeline orchestrates deletion across 15+ data stores (per classification matrix), then the orchestrator MUST execute stores in the documented sequence order: (1) session invalidation, (2) account deactivation, (3) forum anonymization, (4) analytics deletion, (5) purchase anonymization, (6) notes deletion, (7) enrollment/grades deletion, (8) certificates revocation, (9) profile deletion, (10) user account anonymization, (11) SSO linkage deletion, (12) consent anonymization, (13) audit trail anonymization, (14) cache cleanup, (15) log flagging
- [ ] AC-DELETE-002: Given the deletion pipeline processes data store X (e.g., MongoDB Atlas forum content), when the deletion step completes, then the pipeline MUST immediately verify deletion success by querying the data store for the user's identifiers (user_id, email, username) and confirming zero records returned OR anonymized values only
- [ ] AC-DELETE-003: Given a deletion pipeline step fails for data store X (e.g., ClickHouse deletion query timeout after 30 minutes), when the failure is detected, then the pipeline MUST: (a) log the failure with full error context (error message, stack trace, data store endpoint), (b) retry the failed step 3 times with exponential backoff (30s, 60s, 120s), (c) if all retries fail, mark data store X as `failed` in deletion manifest, (d) continue processing remaining data stores (do NOT halt pipeline), (e) transition overall deletion request status to `partially_completed`, (f) fire Critical alert to privacy operations team with failed store name and user identifier
- [ ] AC-DELETE-004: Given a deletion pipeline completes with status `partially_completed` (one or more stores failed), when the privacy operations team reviews the failure, then the team MUST have access to a re-run mechanism that: (a) loads the original deletion manifest, (b) skips already-completed stores (idempotent), (c) re-attempts only `failed` stores, (d) updates the deletion certificate upon successful re-run completion
- [ ] AC-DELETE-005: Given a deletion pipeline completes all stores successfully (status `completed`), when the deletion certificate is generated, then the certificate MUST contain: `deletion_request_id` (UUID), `user_id_hash` (SHA-256), `completion_timestamp` (ISO 8601), per-store manifest array with entries: `{data_store: "MySQL:auth_user", action: "anonymized", records_affected: 1, verification_query: "SELECT email FROM auth_user WHERE id=X", verification_result: "retired_email_abc123@retired.invalid", completed_at: "..."}`, `certificate_signature` (HMAC-SHA256 using platform secret key from Infisical)
- [ ] AC-DELETE-006: Given a deletion certificate is generated, when the certificate signature is verified by an independent auditor tool, then the tool MUST validate: (a) HMAC-SHA256 signature matches certificate body using platform public key, (b) `completion_timestamp` is within 30 days of `deletion_request.created_at` (GDPR SLA compliance), (c) all data stores from classification matrix are listed in manifest (no stores skipped), (d) verification queries confirm anonymization/deletion for each store
- [ ] AC-DELETE-007: Given a deletion pipeline processes `PostgreSQL: orders` (Purchase Gateway), when the user has orders with `created_at` within 7-year financial retention window (Malaysian Companies Act 2016, GDPR Art. 6(1)(c)), then the deletion step MUST: (a) anonymize `buyer_email` to `retired_{hash}@retired.invalid`, (b) retain `order_uuid`, `total_cents`, `currency`, `created_at`, `stripe_checkout_session_id` (for dispute resolution), (c) deletion certificate MUST note legal retention basis: "Legal obligation: 7-year financial record retention per Malaysian Companies Act 2016"
- [ ] AC-DELETE-008: Given a deletion pipeline processes `MySQL: consent_datasharingconsent`, when the user has consent records, then the deletion step MUST: (a) anonymize `username` field to `retired_user_{hash}`, (b) retain `enterprise_customer_uuid`, `granted` (boolean), `granted_at`, `consent_version` (GDPR Art. 7(1) evidence of lawful processing), (c) deletion certificate MUST note retention basis: "Legal obligation: Consent evidence retention per GDPR Art. 7(1)"
- [ ] AC-DELETE-009: Given a deletion pipeline processes `GCS: profile-images/{username}/`, when the deletion step executes, then the pipeline MUST: (a) list all blobs matching `gs://mereka-lms-media/profile-images/{username}/*`, (b) delete all matched blobs, (c) verify blob count for path returns 0, (d) log deleted blob names and sizes in deletion manifest
- [ ] AC-DELETE-010: Given a deletion pipeline completes, when the user's original email address is still stored in a temporary deletion context table (for sending completion notification), then the system MUST: (a) send deletion completion email to the original email address within 24 hours, (b) delete the email address from the temporary table immediately after email send confirmation, (c) log email send event in audit trail with `user_id_hash` only (not email)
- [ ] AC-DELETE-011: Given a deletion request is submitted for a user with an in-flight order in Purchase Gateway (status `pending` or `fulfilling`), when the deletion pipeline reaches the Purchase Gateway step, then the pipeline MUST: (a) poll order status every 6 hours, (b) wait for order to reach terminal state (`fulfilled`, `expired`, `canceled`, `failed`), (c) proceed with anonymization once terminal state reached, (d) if order remains non-terminal after 14 days, escalate to privacy operations team for manual review, (e) overall deletion SLA (30 days) accommodates this wait period
- [ ] AC-DELETE-012: Given a deletion request is submitted for a user who is an enterprise admin for tenant X, when the deletion pipeline begins, then the system MUST: (a) check if user has role `enterprise_admin` for any active tenant, (b) if yes, send notification to tenant's designated contact email with 7-day warning, (c) recommend tenant assign new admin, (d) proceed with deletion after 7 days OR upon tenant confirmation of admin handover (whichever is earlier), (e) log enterprise admin handover in audit trail

### Partial Failure Handling

- [ ] AC-PARTIAL-001: Given a deletion pipeline encounters failures in 2 out of 15 data stores, when the pipeline completes, then the deletion request status MUST be `partially_completed` AND the deletion certificate MUST include a `failures` array listing: `{data_store: "MongoDB:cs_comments_service", error: "Connection timeout after 3 retries", retry_count: 3, last_attempt_at: "..."}`
- [ ] AC-PARTIAL-002: Given an export pipeline fails to retrieve data from `ClickHouse: xapi_events_all` due to network partition, when the export completes, then the archive MUST include `MISSING_DATA.txt` file stating: "Data from ClickHouse analytics events could not be retrieved due to: [error message]. You may re-request export after [retry timestamp]. This does not affect your right to data portability under GDPR Article 20."
- [ ] AC-PARTIAL-003: Given a deletion pipeline marks `MongoDB:cs_comments_service` as failed, when the privacy operations team re-runs the deletion, then the re-run MUST: (a) load previous deletion manifest, (b) skip stores with `action: "completed"` status, (c) re-attempt `MongoDB:cs_comments_service` with fresh retry budget, (d) update deletion certificate with new completion timestamp and re-run audit trail entry

### Audit Trail for Export and Deletion

- [ ] AC-AUDIT-001: Given a user submits an export request, when the request is created, then an audit trail entry MUST be logged with: `event_type: "export_requested"`, `user_id_hash`, `request_id`, `requested_at`, `requested_via` (API/preference center), `ip_address_hash`
- [ ] AC-AUDIT-002: Given an export request completes, when the archive is ready, then an audit trail entry MUST be logged with: `event_type: "export_completed"`, `export_request_id`, `user_id_hash`, `archive_size_bytes`, `data_stores_included` (array), `completion_duration_seconds`
- [ ] AC-AUDIT-003: Given a deletion request is verified and enters processing, when the pipeline begins, then an audit trail entry MUST be logged with: `event_type: "deletion_processing_started"`, `deletion_request_id`, `user_id_hash`, `estimated_completion_date` (requested_at + 30 days)
- [ ] AC-AUDIT-004: Given a deletion pipeline completes a single data store deletion, when the store verification passes, then an audit trail entry MUST be logged with: `event_type: "deletion_step_completed"`, `deletion_request_id`, `user_id_hash`, `data_store`, `records_affected`, `verification_status: "passed"`

### Consent Management (Phase 3)

- [ ] AC-CONSENT-001: Given a user visits the LMS for the first time, when the page loads, then a cookie consent banner MUST appear before any non-essential cookies are set
- [ ] AC-CONSENT-002: Given a user interacts with the cookie consent banner, when they make consent choices, then the system MUST store consent choices with: `consent_version` (privacy policy version), `granted_at` (ISO 8601 timestamp), `collection_method` ("banner"), `ip_address_hash` (SHA-256), and per-category consent status (analytics, marketing, functional)
- [ ] AC-CONSENT-003: Given a user has granted consent for a specific category, when they revoke consent at any time via `/account/privacy/`, then the consent record MUST be updated with `withdrawn_at` timestamp AND the withdrawal MUST take effect within 24 hours (cache invalidation)
- [ ] AC-CONSENT-004: Given the cookie consent banner is displayed, when the banner renders, then the banner MUST NOT block page rendering (async load) AND the LMS core functionality MUST remain accessible even if banner JavaScript fails to load
- [ ] AC-CONSENT-005: Given a user accepts the latest privacy policy version on login, when the acceptance is recorded, then the audit trail MUST contain: `event_type: "privacy_policy_accepted"`, `user_id_hash`, `policy_version`, `accepted_at` (timestamp), `ip_address_hash`
- [ ] AC-CONSENT-006: Given a user logs in for the first time after a privacy policy update, when they access any protected resource, then the system MUST present the latest privacy policy version for acceptance before allowing access
- [ ] AC-CONSENT-007: Given the privacy policy version changes from v2.0 to v3.0, when the update is deployed, then the system MUST support multi-language policy versions (English, Malay, Chinese) with language selection based on user's `language_preference` setting
- [ ] AC-CONSENT-008: Given consent is tracked for multiple purposes (analytics, marketing, functional), when a user modifies consent for `analytics` purpose, then the consent change MUST be tracked independently AND MUST NOT affect consent status for `marketing` or `functional` purposes
- [ ] AC-CONSENT-009: Given consent records exist with version history, when an auditor queries consent history for a user, then the system MUST return all consent versions with: `purpose`, `granted` (boolean), `consent_version`, `granted_at`, `withdrawn_at` (if applicable), ordered by `granted_at` descending
- [ ] AC-CONSENT-010: Given the consent schema changes (e.g., new purpose "AI_training" added), when the schema version increments, then the system MUST trigger re-consent for all active users on next login AND MUST display a clear explanation of what changed

### Retention Enforcement (Phase 3)

- [ ] AC-RETENTION-001: Given the PII classification matrix specifies retention periods for each data category, when the automated data purge CronJob runs daily, then the job MUST identify records past their retention period per classification matrix rules (e.g., "ClickHouse analytics events: 365 days", "Inactive accounts: 24 months no login")
- [ ] AC-RETENTION-002: Given the retention enforcement CronJob runs in production, when purge operations complete, then each purge operation MUST be logged in the audit trail with: `event_type: "retention_purge_completed"`, `data_store`, `data_category`, `records_purged_count`, `purge_duration_seconds`, `retention_policy_version`
- [ ] AC-RETENTION-003: Given the retention enforcement CronJob is configured with dry-run mode, when the job executes with `DRY_RUN=true`, then the job MUST identify records eligible for purge AND log the planned actions WITHOUT actually deleting any data AND output a summary report with record counts per data store
- [ ] AC-RETENTION-004: Given the retention enforcement job runs and encounters a data store timeout (e.g., ClickHouse partition drop exceeds 30 minutes), when the timeout occurs, then the job MUST log the failure, skip that data store, continue processing remaining stores, and fire a Warning alert to the privacy operations team

### Compliance Reporting (Phase 3)

- [ ] AC-COMPLIANCE-001: Given a compliance dashboard is deployed, when a `compliance_officer` role user accesses the dashboard, then the dashboard MUST display: DSAR (Data Subject Access Request) count (last 30 days, last 12 months), DSAR SLA compliance percentage (requests completed within 30 days), deletion request pipeline status (pending, processing, completed, failed counts), consent rate by category (percentage of active users with consent granted for analytics, marketing, functional), data retention compliance score (percentage of data stores with zero overdue purge operations)
- [ ] AC-COMPLIANCE-002: Given the DSAR count metric is displayed on the compliance dashboard, when the metric is queried, then the system MUST aggregate: total export requests submitted in the time range, total deletion requests submitted in the time range, average completion time for export requests, average completion time for deletion requests
- [ ] AC-COMPLIANCE-003: Given the deletion request pipeline status is displayed, when a `privacy_admin` user filters by `partially_completed` status, then the dashboard MUST show: request ID, user identifier (hashed), submission date, elapsed days, failed data stores (array), retry count, last retry timestamp, and a "Re-run" action button
- [ ] AC-COMPLIANCE-004: Given the consent rate by category is calculated, when the metric is rendered on the dashboard, then the system MUST compute: `(users_with_consent_granted_for_purpose / total_active_users) * 100` for each purpose (analytics, marketing, functional), with "active users" defined as users with login within the last 90 days
- [ ] AC-COMPLIANCE-005: Given the data retention compliance score is displayed, when the score is calculated, then the system MUST: (a) query each data store for records past retention period, (b) flag any data store with overdue purge count > 0 as non-compliant, (c) compute compliance score as `(compliant_data_stores / total_data_stores_with_retention_policy) * 100`, (d) display the score with color coding (green ≥95%, yellow 90-94%, red <90%)

---

## Edge Cases

### Deletion Pipeline Edge Cases

- **User with active course enrollment**: If a user requests deletion while enrolled in an active course, the deletion pipeline MUST still proceed (GDPR right to erasure overrides contract in most cases). The system MUST deactivate enrollment, then anonymize. If the enterprise DPA requires completion of the current course before deletion, this MUST be negotiated in the DPA and the user MUST be informed of the delay with the legal basis
- **User with in-flight purchase**: If a user requests deletion while an order is in `pending` or `fulfilling` state in the Purchase Gateway, the system MUST wait for the order to reach a terminal state (`fulfilled`, `expired`, `canceled`, `failed`) before processing the Purchase Gateway deletion step. The 30-day SLA accommodates this delay
- **Deletion of user who is also a course author**: If the user created content in Studio (CMS), the deletion pipeline MUST NOT delete the course content (which serves other learners). The pipeline MUST anonymize the author attribution only
- **Re-registration after deletion**: If a user's data is deleted and they later register again with the same email, the system MUST treat them as a new user. The retired email hash ensures the old anonymous records are not re-linked. Consent MUST be collected fresh
- **Concurrent deletion and export requests**: If a user submits both a deletion request and an export request simultaneously, the system MUST complete the export before beginning the deletion. The export acts as a final data portability exercise
- **Deletion request for a user who is an enterprise admin**: If the user is an enterprise admin with active responsibilities, the system MUST notify the enterprise tenant before proceeding with deletion (admin handover may be needed). Deletion MUST NOT be delayed more than 7 days for this handover

### Consent Edge Cases

- **User registered before consent system deployment**: For existing users who registered before the consent management system is deployed, the system MUST present a consent collection prompt on their next login. Until consent is collected, only `essential_service` (contract-based) and `legitimate_interest` processing MAY continue; `consent`-based processing MUST NOT occur
- **Enterprise user with conflicting consent and DPA**: If an enterprise DPA grants the enterprise admin access to learner data (legal basis: `contract`) but the learner withdraws `third_party_sharing` consent, the DPA's contractual basis takes precedence for the specific data categories covered by the DPA. The system MUST log this override in the audit trail
- **Consent version migration**: When the privacy policy or consent text is updated, existing consent records remain valid for the version they were granted under. The system MUST prompt users to re-consent under the new version on their next login. Processing continues under the old version until re-consent or 90-day expiry of old version validity
- **Minor data subjects (under 16 in EU)**: If an enterprise tenant enrolls users under 16, parental consent is required under GDPR Article 8. The system MUST support a parental consent workflow: the minor cannot consent directly; an email is sent to a designated parental email for approval. This is triggered by a per-tenant configuration flag

### Cross-Border Transfer Edge Cases

- **EU user data in Singapore infrastructure**: All Mereka Academy data is stored in Singapore (`asia-southeast1`). For EU data subjects, the system MUST ensure Standard Contractual Clauses (SCCs) are in place with GCP and MongoDB Atlas. This is a contractual/legal requirement, not a technical one, but the system MUST maintain documentation of the SCC status in the processor inventory
- **Stripe data residency**: Stripe may process payment data in the US or EU depending on the Stripe account configuration. The system MUST document which Stripe data residency region is configured and include this in the DPIA for payment processing

### Retention Edge Cases

- **Inactive account with outstanding financial obligation**: If an account is flagged for 24-month inactivity deletion but has financial records within the 7-year retention period, the account MUST be anonymized (not fully deleted) -- the financial records are retained with anonymized PII per the retention policy
- **Inactive account with active enterprise subscription**: If an enterprise admin account is flagged for inactivity but the enterprise subscription is still active, the system MUST NOT auto-delete. The retention enforcement job MUST check for active enterprise admin roles before triggering deletion
- **Backup retention and deletion right**: Backup data (database snapshots) MUST have a 90-day rotation. After a user deletion is completed, the user's data will persist in backups for up to 90 days. The deletion proof MUST note this residual backup retention. Upon backup restoration, the system MUST re-run pending deletions (using the deletion request log)

### Audit Trail Edge Cases

- **Hash chain break after system recovery**: If the audit trail database is restored from backup and the latest entry hash does not match the previous entry in the chain, the system MUST create a "chain break" entry documenting the recovery event and restart the chain from the recovery point. The GCS replica serves as the authoritative record for the broken segment
- **High-volume audit events during bulk deletion**: During a tenant offboarding that triggers deletions for thousands of users, the audit trail MUST handle the write volume without losing events. The system MUST use buffered writes with guaranteed delivery (write-ahead log or queue)

### Retry/Timeout Behavior

- **Deletion pipeline per-store timeout**: Each data store deletion step MUST have a 30-minute timeout. If a store does not respond within 30 minutes, the step is marked as `failed` and the pipeline continues
- **Export pipeline timeout**: If the export generation exceeds 72 hours, the export request MUST be marked as `failed` and the user MUST be notified with an option to retry
- **Consent enforcement cache staleness**: Consent decisions are cached for performance. If the cache contains stale data (user withdrew consent but cache has not expired), the maximum staleness window MUST be 24 hours (cache TTL). Critical consent changes (deletion request) MUST invalidate the cache immediately

### Idempotency

- **Deletion pipeline re-run**: Re-running the deletion pipeline for a user whose data has already been deleted MUST be a no-op for completed stores and MUST retry only `failed` stores
- **Consent record duplication**: Granting consent for the same purpose multiple times MUST NOT create duplicate active consent records. The system MUST check for existing active consent before creating a new record
- **Export request duplication**: Submitting an export request while a previous request is still `processing` MUST return the existing request ID (not create a duplicate)

### Rate Limits

- **Deletion request rate limit**: Maximum 10 deletion requests per hour per IP address (prevents abuse)
- **Export request rate limit**: Maximum 3 pending export requests per user per 30-day period
- **Compliance API rate limit**: Maximum 60 requests per minute per authenticated admin user
- **Consent update rate limit**: Maximum 30 consent changes per user per hour (prevents automated toggling)

### Partial Failures

- **Deletion pipeline with multiple store failures**: If more than 3 data stores fail during a single deletion run, the pipeline MUST pause, fire a Critical alert, and require manual intervention before continuing (indicates systemic issue, not isolated failure)
- **Consent enforcement with consent service unavailable**: If the consent management service is unreachable, the system MUST fail-open for `essential_service` processing (contract-based) and fail-closed for `consent`-based processing (analytics, marketing). This ensures the platform remains functional for essential learning operations while protecting user privacy for optional processing

---

## Observability

### Logs

- **Privacy Service**: Structured JSON logs to stdout, captured by Promtail and shipped to Loki. Every log line MUST include: `service_name: "privacy-service"`, `tenant_id` (when in context), `request_id`, `log_level`, `timestamp`
- **Deletion events**: MUST log: `event: "deletion_step_completed"`, `deletion_request_id`, `user_id_hash` (SHA-256 of user ID), `data_store`, `action` (deleted/anonymized/retained), `duration_ms`. MUST NOT log: raw user email, username, or any PII
- **Consent events**: MUST log: `event: "consent_changed"`, `user_id_hash`, `purpose`, `new_status` (granted/withdrawn), `collection_method`
- **Export events**: MUST log: `event: "export_generated"`, `export_request_id`, `user_id_hash`, `archive_size_bytes`, `file_count`, `duration_ms`
- **PII scan events**: MUST log: `event: "pii_scan_completed"`, `scan_scope` (loki/clickhouse/all), `duration_ms`, `findings_count`, `critical_findings_count`
- **Sensitive data rule**: MUST NOT log raw PII in any privacy service log line. Use SHA-256 hashes for user identifiers. Log deletion request IDs (UUIDs), not user emails

### Metrics

- `privacy_deletion_requests_total` (counter, labels: `status` [pending, processing, completed, failed], `tenant_id`)
- `privacy_deletion_duration_seconds` (histogram, labels: `data_store`)
- `privacy_deletion_sla_compliance` (gauge) -- percentage of deletion requests completed within 30 days
- `privacy_export_requests_total` (counter, labels: `status`, `tenant_id`)
- `privacy_export_duration_seconds` (histogram)
- `privacy_consent_changes_total` (counter, labels: `purpose`, `action` [granted, withdrawn], `tenant_id`)
- `privacy_consent_coverage_ratio` (gauge, labels: `purpose`) -- percentage of active users with consent record for each purpose
- `privacy_pii_leakage_findings_total` (counter, labels: `data_store`, `severity` [critical, high, medium, low])
- `privacy_retention_enforcement_deletions_total` (counter, labels: `data_category`)
- `privacy_audit_trail_entries_total` (counter, labels: `event_type`)
- `privacy_audit_trail_write_latency_seconds` (histogram)
- `privacy_consent_check_latency_seconds` (histogram) -- consent API response time
- `privacy_processor_dpa_status` (gauge, labels: `processor_name`, `status` [signed, pending, expired])

### Alerts

- **Critical**: `privacy_deletion_sla_compliance` < 95% -- deletion requests at risk of missing GDPR 30-day deadline
- **Critical**: `privacy_pii_leakage_findings_total{severity="critical"}` > 0 -- raw PII detected in logs or analytics; potential data breach
- **Critical**: Privacy service health check fails for > 2 consecutive checks -- consent enforcement unavailable
- **Warning**: `privacy_deletion_requests_total{status="failed"}` > 0 -- deletion pipeline failures requiring attention
- **Warning**: `privacy_consent_coverage_ratio{purpose="essential_service"}` < 90% -- significant number of users without consent records
- **Warning**: `privacy_export_duration_seconds` p95 > 48 hours -- export pipeline approaching SLA limit
- **Warning**: `privacy_audit_trail_write_latency_seconds` p95 > 100ms -- audit trail write performance degradation
- **Warning**: `privacy_processor_dpa_status{status="expired"}` > 0 -- DPA expired for a third-party processor
- **Info**: `privacy_retention_enforcement_deletions_total` increases -- routine retention deletions executed (for compliance dashboard visibility)
- **Info**: `privacy_consent_changes_total{action="withdrawn"}` rate > 10 per hour for any purpose -- elevated consent withdrawal (investigate potential UX issue or communication)

### Dashboards

- **Privacy Compliance Overview**: Consent coverage by purpose, deletion request status/SLA, export request status, PII scan results, processor DPA status, retention enforcement activity
- **Deletion Pipeline Monitor**: Active deletion requests, per-store processing time, failure rate by store, partial completion rate, SLA countdown
- **Consent Analytics**: Consent grant/withdrawal trends, consent coverage by tenant, consent method distribution (registration vs preference center vs cookie banner)
- **PII Leakage Tracker**: Scan frequency, findings by data store and severity, trend over 30 days, unresolved findings
- **Audit Trail Dashboard**: Event volume by type, hash chain integrity status, latest events timeline

---

## Rollout & Rollback

### Rollout Plan

#### Phase 0: Foundation (Week 1-4)

1. Create the PII registry (`specs/pii-registry.yml`) by auditing all existing database schemas
2. Develop the PII registry validation tool and integrate into CI
3. Implement the audit trail database table and integrity hash chain mechanism
4. Deploy the audit trail as a Django app within the LMS (or as a standalone microservice)
5. Implement the consent data model (database tables, Django models)
6. Create the privacy operations role (`privacy_admin`) in the LMS authorization system
7. Document the breach notification procedure and populate the contact list
8. Draft and send DPA requests to all third-party processors without signed DPAs

#### Phase 1: Consent Management (Week 5-8)

1. Deploy the consent management service (API endpoints for consent CRUD)
2. Implement the consent preference center UI at `/account/privacy/`
3. Implement the cookie consent banner for LMS and MFE frontends
4. Implement consent enforcement hooks in the analytics pipeline (check consent before sending events to ClickHouse)
5. For existing users, trigger consent collection on next login (migration consent prompt)
6. Feature flag: `ENABLE_CONSENT_ENFORCEMENT=false` initially (collect consent records without enforcing)
7. Monitor consent collection rate for 2 weeks
8. Enable consent enforcement: `ENABLE_CONSENT_ENFORCEMENT=true`

#### Phase 2: Data Deletion Pipeline (Week 9-14)

1. Implement deletion request API endpoint and request state machine
2. Implement per-store deletion handlers: MySQL (Open edX user retirement extended), MongoDB Atlas (forum anonymization), Redis (session invalidation), ClickHouse (event deletion), PostgreSQL (Purchase Gateway anonymization), GCS (profile image/certificate deletion)
3. Implement the deletion orchestrator (sequential execution with per-store retry)
4. Implement deletion proof generation (signed manifest)
5. Test with synthetic users in staging environment
6. Feature flag: `ENABLE_DELETION_PIPELINE=false` initially (accept requests, queue them, do not execute)
7. Execute first batch of queued deletion requests manually with ops oversight
8. Enable automated execution: `ENABLE_DELETION_PIPELINE=true`

#### Phase 3: Data Export Pipeline (Week 15-18)

1. Implement export request API endpoint
2. Implement per-store data extractors for all PII-bearing stores
3. Implement archive assembly (JSON files, ZIP packaging, encryption)
4. Implement download link generation with 48-hour expiry
5. Implement export archive cleanup (delete after download or 7-day expiry)
6. Test with synthetic users and real data shapes
7. Enable self-service export: `ENABLE_SELF_SERVICE_EXPORT=true`

#### Phase 4: PII Leakage Detection and Retention Enforcement (Week 19-22)

1. Deploy PII leakage scanner for Loki (regex-based email/IP detection)
2. Deploy PII leakage scanner for ClickHouse (detect unhashed identifiers)
3. Schedule weekly PII scans and connect alerts
4. Implement retention enforcement job (inactive account detection, ClickHouse partition dropping, Loki retention verification)
5. Send first batch of 18-month inactivity reminder emails
6. Enable automated retention enforcement: `ENABLE_RETENTION_ENFORCEMENT=true`

#### Phase 5: Compliance Reporting and Hardening (Week 23-26)

1. Deploy compliance reporting API endpoints
2. Deploy Grafana compliance dashboard
3. Conduct internal SOC 2 readiness assessment using compliance API evidence
4. Conduct penetration test focused on privacy endpoints (deletion, export, consent)
5. Submit for external GDPR readiness review (if engaging auditor)
6. Onboard first EU enterprise tenant with full DPA and DPIA package

### Feature Flags

- `ENABLE_CONSENT_ENFORCEMENT` -- gate whether consent checks block non-essential processing (default: off during Phase 1 data collection)
- `ENABLE_COOKIE_CONSENT_BANNER` -- gate cookie consent banner display (default: off until frontend is ready)
- `ENABLE_DELETION_PIPELINE` -- gate automated deletion execution (default: off; queue requests only)
- `ENABLE_SELF_SERVICE_EXPORT` -- gate user-facing export request endpoint (default: off until tested)
- `ENABLE_RETENTION_ENFORCEMENT` -- gate automated retention policy execution (default: off until retention periods are validated with legal)
- `ENABLE_PII_SCAN_ALERTS` -- gate alerts from PII leakage scanner (default: off during initial scan tuning to avoid false positive noise)
- `ENABLE_CONSENT_GEO_DETECTION` -- gate geo-based cookie consent behavior (default: off; show banner to all users initially)

### Backward Compatibility

- The consent management system adds new database tables; it does not modify existing Open edX tables
- The deletion pipeline extends the existing Open edX `UserRetirementStatus` model and retirement pipeline rather than replacing it
- The cookie consent banner is additive; it does not change existing cookie behavior until enabled
- The audit trail is a new system with no backward compatibility concerns
- The compliance API is new; it does not change existing API surfaces
- Existing user accounts without consent records continue to function (consent is collected on next interaction); this is the graceful migration path

### Rollback Steps

#### Consent Management Rollback

1. Set `ENABLE_CONSENT_ENFORCEMENT=false` -- processing continues without consent checks
2. Cookie consent banner: set `ENABLE_COOKIE_CONSENT_BANNER=false` -- banner disappears, existing cookies persist
3. Consent records remain in the database (no data loss)
4. Investigate and fix the issue, then re-enable

#### Deletion Pipeline Rollback

1. Set `ENABLE_DELETION_PIPELINE=false` -- new deletion requests are queued but not executed
2. In-progress deletions: if a deletion is mid-pipeline, allow it to complete for the current store step, then pause
3. Partially completed deletions remain in `partially_completed` state for manual resolution
4. Users are notified of the delay (within 30-day SLA)
5. Fix the issue and re-enable; the pipeline resumes from where it paused

#### Export Pipeline Rollback

1. Set `ENABLE_SELF_SERVICE_EXPORT=false` -- users see "export temporarily unavailable"
2. Pending export requests remain in queue
3. Fix and re-enable

#### PII Scanner Rollback

1. Set `ENABLE_PII_SCAN_ALERTS=false` -- scans still run but do not fire alerts
2. Review scan configuration for false positives
3. Re-enable after tuning

#### Full Privacy Service Rollback (Emergency)

1. Disable all privacy feature flags
2. The LMS continues operating normally (privacy features are additive, not blocking for core operations)
3. Consent enforcement disabled: all processing continues without consent checks (acceptable for short-term emergency, not for extended periods)
4. Deletion and export requests queue but do not execute
5. Audit trail continues recording (it has no feature flag; it is always on once deployed)
6. Investigate, fix, and re-enable features one by one

---

## Monorepo Location

| Component | Path | Notes |
|-----------|------|-------|
| Deletion pipeline scripts | `services/privacy-tools/deletion/` | Cross-service PII deletion orchestrator |
| Export pipeline scripts | `services/privacy-tools/export/` | Data portability export generator |
| PII inventory | `services/privacy-tools/inventory/` | Machine-readable PII field registry |
| Consent API (if needed) | `services/privacy-tools/consent/` | Centralized consent service |
| Tests | `services/privacy-tools/tests/` | pytest (deletion verification, export validation) |
| Compliance dashboards | `infrastructure/monitoring/dashboards/` | Grafana dashboard JSON |
| K8s manifests | `deploy/k8s/base/apps/privacy-tools/` | CronJob for retention enforcement |
| Audit scripts | `scripts/qa/audit-pii-*.sh` | CI/CD PII scanning scripts |

---

## Open Questions

1. **Data Protection Officer (DPO) appointment**: Has Mereka appointed a DPO as required by GDPR Article 37 for organizations processing personal data at scale? If not, who is the interim responsible person? This affects the breach notification procedure and supervisory authority contact.

2. **Legal review of retention periods**: The retention periods in this spec are based on regulatory minimums and industry practice. Has legal counsel reviewed and approved the specific retention periods for each data category, especially the 24-month inactive account deletion and the 7-year financial record retention?

3. **Open edX UserRetirement pipeline status**: The existing Open edX `UserRetirementStatus` model and retirement pipeline (via `tubular` library) partially implements user data deletion. What is the current state of this pipeline in the Mereka deployment? Is it functional, partially configured, or not deployed? This determines whether the deletion pipeline extends the existing mechanism or builds a parallel one.

4. **Consent collection UX for existing users**: There are existing active users who registered before any consent framework was in place. What is the UX for collecting their consent? Options: (a) blocking modal on next login requiring consent before proceeding, (b) non-blocking banner with repeated prompts, (c) assume legitimate interest for existing users and collect consent only for new processing activities. Legal guidance needed.

5. **Stripe DPA status**: Has Mereka signed Stripe's Data Processing Agreement? Stripe's DPA covers GDPR requirements for payment data processing. If not signed, payment data processing has no formal GDPR basis from the processor side.

6. **MongoDB Atlas DPA status**: Has Mereka signed MongoDB's DPA? Atlas stores forum data and modulestore content. The DPA is required for GDPR compliance as Atlas is a data processor.

7. **PDPA registration with Commissioner**: Under Malaysia's PDPA, data users who process personal data for commercial purposes must register with the Commissioner. Has Mereka registered? This is a legal/operational prerequisite, not a technical one, but affects the compliance posture.

8. **EU representative appointment**: If Mereka processes EU personal data without an EU establishment, GDPR Article 27 requires appointing an EU representative. Is this needed? If so, who?

9. **Log anonymization vs. deletion**: The spec notes that immediate PII deletion from Loki logs is impractical (Loki does not support selective deletion of log lines). Is a 30-day retention policy for logs (meaning PII in logs is naturally purged within 30 days) acceptable for GDPR compliance, or must the system implement immediate log line redaction? Legal guidance needed.

10. **Budget for compliance tooling**: The PII leakage scanner, consent management UI, export pipeline, and compliance dashboard require development effort. Is dedicated engineering capacity allocated for this work, or will it be interleaved with feature development? This affects the rollout timeline.

11. **Enterprise tenant DPA template**: Should Mereka provide a standard DPA template to enterprise clients, or should each client provide their own? A standard template is faster to negotiate but may not satisfy all enterprise legal teams. Legal counsel input needed.

12. **Parental consent implementation priority**: GDPR Article 8 requires parental consent for processing data of children under 16. Is this a v1 requirement (any enterprise tenant may have minor users) or a future enhancement triggered only when a specific tenant requires it?

13. **ClickHouse anonymization verification**: The analytics spec states that user IDs MUST be hashed in ClickHouse. Has this been verified in the current deployment? If unhashed email addresses are currently in ClickHouse, this is an existing compliance gap that needs immediate remediation.

14. **SOC 2 Type II audit timeline**: When is the SOC 2 audit planned? This determines how aggressively the evidence collection infrastructure needs to be prioritized.
