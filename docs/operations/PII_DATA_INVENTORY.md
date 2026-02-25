# PII Data Inventory

> **Regulations**: PDPA (Malaysia), GDPR (EU)
> **OEP-30 categories**: DIRECT (name, email, phone), QUASI (DOB, gender, city), BEHAVIORAL (enrollments, grades, forum activity)
> **Owner**: platform-engineering
> **Last Updated**: 2026-02-25
> **Review cycle**: Quarterly

---

## 1. MySQL (Cloud SQL — Open edX LMS/CMS)

**Access controls**: Cloud SQL IAM auth; only LMS/CMS/worker pods have credentials via ExternalSecret `openedx-secrets`.

| Table | PII Fields | OEP-30 Category | Retention | Encrypted at Rest |
|-------|-----------|-----------------|-----------|-------------------|
| `auth_user` | `username`, `email`, `first_name`, `last_name`, `date_joined`, `last_login` | DIRECT | Account lifetime → anonymized on retirement | Yes (Cloud SQL) |
| `auth_userprofile` | `name`, `year_of_birth`, `gender`, `language`, `country`, `city`, `bio`, `phone_number` | DIRECT + QUASI | Account lifetime → deleted on retirement | Yes |
| `student_courseenrollment` | `user_id` (FK → auth_user) | BEHAVIORAL | Account lifetime → anonymized | Yes |
| `grades_persistentcoursegrade` | `user_id`, `percent_grade`, `passed_timestamp` | BEHAVIORAL | Account lifetime → anonymized | Yes |
| `certificates_generatedcertificate` | `user_id`, `name`, `download_url` | DIRECT + BEHAVIORAL | 10 years → deleted on retirement with notice | Yes |
| `social_auth_usersocialauth` | `user_id`, `uid` (SSO identifier), `extra_data` (may include OAuth tokens) | DIRECT | Account lifetime → deleted on retirement | Yes |
| `consent_datasharingconsent` | `username`, `course_id`, consent timestamps | BEHAVIORAL | 5 years post-relationship (anonymize user ID, retain record) | Yes |
| `django_session` | `session_data` (encrypted; contains `user_id`) | DIRECT | 24 h TTL | Yes |
| `openedx_notifications_*` | `user_id`, notification content | BEHAVIORAL | 90 days TTL | Yes |
| `user_api_userretirementstatus` | `original_username`, `original_email`, `retired_username`, `retired_email` | DIRECT | 3 years post-completion (audit trail) | Yes |

**PII NOT stored in MySQL**: payment card numbers (handled by Stripe), raw passwords (bcrypt hashed).

---

## 2. MongoDB Atlas (`cluster-mereka-lms.2pjex4s.mongodb.net`)

**Access controls**: Atlas IP allowlist (GKE egress NAT IPs); credentials in ExternalSecret `openedx-secrets`.

| Collection | PII Fields | OEP-30 Category | Retention | Encrypted at Rest |
|-----------|-----------|-----------------|-----------|-------------------|
| `cs_comments_service.contents` (forum posts) | `author_username`, `author_id`, `body` (may contain self-disclosed PII) | DIRECT + BEHAVIORAL | Indefinite → anonymized on retirement (`author_username → [deleted]`, body unchanged) | Yes (Atlas) |
| `cs_comments_service.users` | `username`, `email`, `external_id` | DIRECT | Account lifetime → deleted on retirement | Yes |
| `openedx.modulestore.*` | Course content only — no learner PII | — | Course lifetime | Yes |
| `openedx.split_modulestore.*` | Course content only — no learner PII | — | Course lifetime | Yes |

**Note**: Forum post `body` content may contain user-disclosed PII (names, locations). Body is retained after retirement; only authorship is anonymized. Document this trade-off in DPIA.

---

## 3. Redis (in-cluster)

**Access controls**: No external exposure; only LMS/CMS/worker pods via ClusterIP service.

| Key Pattern | Contents | OEP-30 Category | Retention |
|------------|---------|-----------------|-----------|
| `django.contrib.sessions.*` | Encrypted session blob containing `user_id` | DIRECT | 24 h TTL |
| `cache:.*` | Rendered HTML fragments, API responses (may include username) | QUASI | 5 min–1 h TTL |
| `celery:*` | Celery task payloads (may include `user_id`, `email` for async operations) | DIRECT | Task lifetime (~1 h) |
| `openedx:user:<id>:*` | Per-user caches (enrollments, grades) | BEHAVIORAL | 5–30 min TTL |

**PII NOT stored in Redis**: passwords, full profile data, payment data.

---

## 4. PostgreSQL (Purchase Gateway — `postgresql-payments`)

**Access controls**: ClusterIP only; payments-gateway pod via ExternalSecret `purchase-gateway-secrets`.

| Table | PII Fields | OEP-30 Category | Retention | Encrypted at Rest |
|-------|-----------|-----------------|-----------|-------------------|
| `orders` | `buyer_email`, `buyer_user_id`, `stripe_customer_id`, `stripe_checkout_session_id`, `stripe_payment_intent_id` | DIRECT | 7 years (Companies Act 2016) → PII fields anonymized; financial data retained | Yes (GKE disk encryption) |
| `line_items` | No direct PII (FK to orders) | — | 7 years | Yes |
| `entitlements` | `recipient_email`, `claimed_by_user_id` | DIRECT | 7 years → PII fields anonymized | Yes |
| `subscriptions` | `stripe_customer_id` (links to Stripe customer record) | QUASI | Subscription lifetime + 7 years | Yes |
| `stripe_events` | `payload_json` (JSONB; may contain buyer email from Stripe webhook) | DIRECT | 90 days → deleted | Yes |
| `order_audit_log` | `triggered_by` (may be username or system name) | QUASI | 7 years | Yes |

---

## 5. Application Logs

**Access controls**: Loki — internal GKE; read access requires Grafana viewer role.

| Source | Potential PII | OEP-30 Category | Retention | Notes |
|--------|--------------|-----------------|-----------|-------|
| LMS/CMS pod logs (Loki) | `username`, `user_id` in request log lines | DIRECT | 30 days | PII filtering via Promtail `replace` stage should be configured |
| Caddy access logs | Source IP, User-Agent, request path (may include username in URL) | QUASI | 30 days | IPs are quasi-identifier |
| Purchase Gateway logs (Loki) | `buyer_email` if logged at ERROR level | DIRECT | 30 days | Log level must be INFO; avoid logging email |
| HubSpot webhook logs (Cloud Logging) | `email`, `first_name`, `last_name` in debug output | DIRECT | 30 days (Cloud Logging default) | **Gap**: Debug logs may expose full profile; set LOG_LEVEL=warn in prod |

---

## 6. File Storage (GCS)

**Access controls**: Bucket IAM — only LMS service account can read/write; no public access.

| Bucket / Path | Contents | OEP-30 Category | Retention |
|--------------|---------|-----------------|-----------|
| `mereka-lms-static/profile-images/` | User profile photos | DIRECT | Account lifetime → deleted on retirement |
| `mereka-lms-static/certificates/` | Certificate PDFs (contain learner name) | DIRECT | 10 years → deleted on retirement with notice |
| `mereka-lms-backups/` | MySQL and MongoDB backup snapshots | DIRECT (all categories) | 90-day rotation |

---

## 7. HubSpot Webhook (Firebase Cloud Function — Legacy)

**Access controls**: HTTPS endpoint with HMAC signature verification. Firebase project: `mereka-lms`.

| Storage | PII Fields | OEP-30 Category | Retention | Notes |
|---------|-----------|-----------------|-----------|-------|
| Firestore (duplicate detection) | `email` (dedupe key), registration timestamp | DIRECT | 7 days (dedup window) | **Gap**: No automated cleanup; add TTL policy |
| Transient (in-memory) | `first_name`, `last_name`, `email`, `gender`, `DOB`, `country`, `city`, `university`, `phone_number`, `language`, `referral_partner` | DIRECT + QUASI | Not persisted (passed to Open edX API, then discarded) | 16 profile fields fetched from HubSpot |

**Downstream write**: Creates Open edX `auth_user` + `auth_userprofile` records (see MySQL section). No permanent PII storage in Firebase beyond the Firestore dedup key.

---

## 8. External Services

| Service | What We Share | Legal Basis | DPA in Place | User Deletion |
|---------|--------------|-------------|--------------|---------------|
| **Stripe** | `buyer_email`, billing name, card (tokenized), purchase amount | Contract performance | Yes (Stripe DPA) | Delete via Stripe Dashboard → Customers or Stripe API `DELETE /v1/customers/{id}` |
| **MongoDB Atlas** | Full forum and modulestore data (see §2) | Contract performance | Yes (Atlas DPA) | Data stays within Atlas cluster; retirement handled in-app |
| **SendGrid** | `email`, `first_name` (for welcome email templates) | Contract performance | Yes (SendGrid DPA) | No persistent storage beyond delivery logs (30 days) |
| **HubSpot** | Contact records (CRM source of truth) | Legitimate interest | Yes (HubSpot DPA) | Must delete contact in HubSpot separately from Open edX retirement |
| **Meilisearch** | Forum post index (usernames, post bodies) | Contract performance | Self-hosted (in-cluster) | Re-index after forum anonymization |
| **GCP Cloud Logging** | Firebase function logs (may contain email) | Legitimate interest | Yes (Google DPA) | 30-day default retention |

---

## 9. Data Flows

```
Registration flow:
  HubSpot form → Firebase webhook → Open edX API → MySQL auth_user + auth_userprofile

Learning flow:
  User login → Redis session → MySQL enrollments/grades → MongoDB forum posts
  → Meilisearch index (forum search)

Payment flow:
  Stripe Checkout → PostgreSQL orders + stripe_events → LMS enrollment fulfillment

Analytics flow (future):
  LMS events → ClickHouse/Aspects → anonymized dashboards
  Retention: 365 days with TTL

Backup flow:
  MySQL/MongoDB snapshots → GCS (90-day rotation) → encrypted at rest
```

---

## 10. Known Gaps

| Gap | Risk | Remediation |
|-----|------|------------|
| Firestore dedup records have no TTL | Low (email only; 7-day window sufficient) | Add Firestore TTL policy on `created_at` field |
| HubSpot webhook debug logs may expose email | Medium | Set `LOG_LEVEL=warn` in Firebase function env |
| Forum post bodies retained after retirement | Medium (community value trade-off) | Document in DPIA; consider content scrubbing option |
| Stripe customer records not auto-deleted | Medium | Add Stripe customer deletion to erasure runbook |
| HubSpot CRM contact not included in Open edX retirement | High | Erasure runbook must include HubSpot contact deletion step |
| `stripe_events.payload_json` may contain email | Medium | Ensure 90-day deletion cron is scheduled |

---

## References

- Open edX OEP-30: https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0030-arch-pii-markup-and-auditing.html
- Erasure runbook: `docs/operations/DATA_ERASURE_RUNBOOK.md`
- GDPR operational runbook: `docs/operations/GDPR_COMPLIANCE.md`
- Spec: `specs/data-privacy-gdpr-compliance_spec.md`
