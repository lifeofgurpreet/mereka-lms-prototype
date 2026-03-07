# Data Retention Policy

> **Regulations**: PDPA (Malaysia) — Personal Data Protection Act 2010; GDPR (EU) — Regulation 2016/679
> **Owner**: platform-engineering
> **Last Updated**: 2026-02-25
> **Review cycle**: Annual (or after any regulatory change)
> **Contact**: privacy@mereka.io

---

## 1. Purpose and Scope

This policy defines how long Mereka Academy retains personal data across every data store, the legal basis for each retention period, and the automated processes that enforce deletion or anonymization when retention periods expire.

Scope: all services and data stores operated by Mereka Academy — LMS, CMS, Forum, Purchase Gateway, HubSpot webhook, and the observability stack (Loki, Prometheus).

---

## 2. Regulatory Summary

### PDPA (Malaysia / Singapore)

- Personal Data Protection Act 2010 (Malaysia) — enforced by the Personal Data Protection Commissioner.
- Key obligations:
  - Data must not be retained longer than necessary for the purpose it was collected.
  - Data subjects may request access to or correction of their personal data.
  - No explicit statutory minimum retention period for most categories; "necessary" is the operative standard.
  - Financial records: Companies Act 2016 (Malaysia) requires 7-year retention of accounting records.

### GDPR (EU)

- Regulation (EU) 2016/679, applicable to EU residents regardless of where Mereka Academy is incorporated.
- Key obligations:
  - Article 5(1)(e) — storage limitation: personal data must not be kept longer than necessary for the specified purpose.
  - Article 17 — right to erasure: data subjects may request deletion within 30 days.
  - Article 20 — right to data portability: structured, machine-readable export within 30 days.
  - Article 33/34 — breach notification: 72-hour notification to supervisory authority; communication to affected data subjects without undue delay.
  - Recital 26 — anonymized data falls outside GDPR scope.

### Conflict resolution

Where PDPA and GDPR conflict, apply the stricter standard. For financial records, the 7-year Companies Act period overrides shorter GDPR erasure requests (GDPR Art 17(3)(b) — legal obligation exemption).

---

## 3. Data Categories and Retention Periods

### 3.1 User Account Data (MySQL)

| Field Group | Retention Period | Action on Expiry | Legal Basis |
|-------------|-----------------|------------------|-------------|
| `auth_user` (username, email, name) | Account lifetime | Anonymize via retirement pipeline | Contractual necessity |
| `auth_userprofile` (DOB, gender, country, phone) | Account lifetime | Delete on retirement | Contractual necessity |
| `social_auth_usersocialauth` (SSO tokens) | Account lifetime | Delete on retirement | Contractual necessity |
| `django_session` | 24 hours (auto-TTL) | Redis TTL auto-expires | Minimal data; session only |
| `openedx_notifications_*` | 90 days | Scheduled deletion job | Legitimate interest |
| `user_api_userretirementstatus` | 3 years post-completion | Manual review, then delete | Compliance audit trail |

### 3.2 Learning Activity Data (MySQL)

| Table | Retention Period | Action on Expiry | Legal Basis |
|-------|-----------------|------------------|-------------|
| `student_courseenrollment` | Account lifetime | Anonymize user_id on retirement | Contractual necessity |
| `grades_persistentcoursegrade` | Account lifetime | Anonymize user_id on retirement | Contractual necessity |
| `certificates_generatedcertificate` | 10 years | Anonymize user_id; retain certificate record | Legitimate interest (credentialing) |
| `consent_datasharingconsent` | 5 years post-relationship | Anonymize username; retain consent record | Legal obligation |

### 3.3 Forum Data (MongoDB Atlas)

| Collection | Retention Period | Action on Expiry | Notes |
|------------|-----------------|------------------|-------|
| `cs_comments_service.contents` (posts) | Indefinite | Anonymize authorship on retirement; body retained | Community value trade-off; see PII inventory |
| `cs_comments_service.users` | Account lifetime | Delete on retirement | |

Forum post bodies may contain user-disclosed PII. This trade-off is documented in the DPIA. An operator may configure body scrubbing via the forum anonymization management command if required.

### 3.4 Financial Records (PostgreSQL — Purchase Gateway)

| Table | Retention Period | Action on Expiry | Legal Basis |
|-------|-----------------|------------------|-------------|
| `orders` (buyer_email, stripe IDs) | 7 years — PII fields anonymized immediately on erasure request; financial totals retained | Anonymize PII fields; retain amounts, timestamps, line items | Companies Act 2016 (Malaysia) |
| `line_items` | 7 years | Retain (no direct PII) | Companies Act 2016 |
| `entitlements` | 7 years | Anonymize recipient_email on erasure | Companies Act 2016 |
| `subscriptions` | Subscription lifetime + 7 years | Anonymize stripe_customer_id on erasure | Companies Act 2016 |
| `stripe_events` | 90 days | Delete entire row | Webhook audit trail only |
| `order_audit_log` | 7 years | Retain | Legal obligation |

### 3.5 Application Logs (Loki)

| Log Source | Retention Period | Configuration |
|------------|-----------------|---------------|
| LMS / CMS pod logs | 30 days | Loki `limits_config.retention_period: 720h` |
| Caddy access logs | 30 days | Loki retention (same config) |
| Purchase Gateway logs | 30 days | Loki retention |
| HubSpot webhook (Cloud Logging) | 30 days | GCP Log retention policy |

PII filtering via Promtail `replace` stage is configured to mask email addresses and user IDs from LMS request logs before ingestion into Loki.

### 3.6 Observability and Metrics (Prometheus)

| Data | Retention Period | Configuration |
|------|-----------------|---------------|
| Prometheus metrics | 15 days | `--storage.tsdb.retention.time=15d` |
| Grafana dashboards | Indefinite (no PII) | N/A |

Prometheus metrics do not contain personal data at the label level. User IDs are not used as Prometheus labels.

### 3.7 Backups (GCS)

| Backup Type | Retention Period | Rotation |
|-------------|-----------------|---------|
| MySQL (Cloud SQL export) | 90 days | Velero / GCS lifecycle rule deletes after 90 days |
| MongoDB Atlas snapshots | 90 days | Atlas automated backup retention |
| PostgreSQL (pg_dump to GCS) | 90 days | GCS lifecycle rule |

Backups are encrypted at rest. Users who exercise their right to erasure should be informed that their data may persist in backups for up to 90 days after the live systems are cleared.

### 3.8 Object Storage (GCS)

| Path | Retention Period | Action |
|------|-----------------|--------|
| `mereka-lms-static/profile-images/` | Account lifetime | Delete on retirement |
| `mereka-lms-static/certificates/` | 10 years | Anonymize; delete on retirement with notice |

### 3.9 External Service Data

| Service | Data Shared | Retention | Action Required |
|---------|------------|-----------|-----------------|
| Stripe | buyer_email, billing name, Stripe customer ID | Stripe default (7 years for charges) | Delete Stripe customer via API on erasure request |
| HubSpot | Contact record (email, name, profile fields) | Until contact deleted | Manual deletion via HubSpot API |
| SendGrid | Email, first_name (delivery logs) | 30 days (SendGrid default) | No action required (auto-expired) |
| Firestore (HubSpot dedup) | email (dedupe key) | 7 days | Add Firestore TTL policy on `created_at` |

---

## 4. Automated Retention Schedule

The following CronJob manifests enforce retention automatically. Manifests are generated by `scripts/infra/data-retention-jobs.sh` and applied to the `mereka-lms` namespace.

| Job | Schedule (UTC) | What It Cleans |
|-----|---------------|----------------|
| `stripe-events-cleanup` | 02:00 daily | Delete `stripe_events` rows older than 90 days |
| `notifications-cleanup` | 03:00 daily | Delete `openedx_notifications_*` rows older than 90 days |
| `inactive-sessions-cleanup` | 04:00 daily | Flush expired Django sessions from MySQL |
| `retirement-audit-cleanup` | 02:00 first of month | Delete `user_api_userretirementstatus` rows older than 3 years |
| `loki-log-retention` | N/A — continuous | Loki enforces 720h (30 days) retention natively |
| `velero-backup-expiry` | N/A — per schedule | Velero TTL `2160h` (90 days) set on each backup schedule |
| `gcs-backup-lifecycle` | N/A — GCS lifecycle | GCS object lifecycle rule: `age: 90` days on backup bucket |

---

## 5. Data Portability — OEP-30 Compliant Export

Mereka Academy supports data portability under GDPR Article 20 and PDPA Section 30. The export is performed by `scripts/infra/user-data-export.sh`.

### Export contents

The export archive is structured as follows:

```
user-export-<username>-<date>/
  profile/
    user.json               # auth_user + auth_userprofile fields
    social_auth.json        # SSO identities
  learning/
    enrollments.json        # course enrollments and progress
    grades.json             # course grades
    certificates.json       # issued certificates
    notes.json              # personal notes (if Notes service enabled)
  forum/
    posts.json              # forum posts authored by user
    comments.json           # forum comments authored by user
  commerce/
    orders.json             # purchase history (financial data retained 7 years)
    entitlements.json       # course entitlements
  consent/
    consent_records.json    # data sharing consent history
  audit/
    export_metadata.json    # timestamp, requested_by, export_version
  README.txt                # human-readable summary and field glossary
```

### OEP-30 compliance

Open edX OEP-30 defines PII annotation conventions for Django models. The export pipeline follows OEP-30 categories:

- **DIRECT**: Fields that directly identify a person (name, email, username) — always included.
- **QUASI**: Fields that may identify a person in combination (DOB, gender, country) — included.
- **BEHAVIORAL**: Interaction data (enrollments, grades, forum posts) — included.
- **UNIQUE_ID**: Internal identifiers (user_id) — included as cross-reference keys.

Fields annotated `NOT_PII` in Open edX models are excluded from the export.

Reference: https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0030-arch-pii-markup-and-auditing.html

### Format

- Primary format: JSON (machine-readable, structured).
- Secondary format: CSV summaries for tabular data (enrollments, grades, orders).
- Archive: `.tar.gz`, signed with SHA-256 checksum.
- Delivery: download link via email, or operator-retrieved via `kubectl cp`.

### SLA

| Milestone | Target |
|-----------|--------|
| Acknowledge DSAR | 3 business days |
| Deliver export archive | 30 days from verified request |

---

## 6. User Request Workflow (DSAR — Data Subject Access Request)

### Intake

1. User submits request to privacy@mereka.io or via the in-platform privacy request form.
2. Platform team logs the request with: date received, user email, request type (access / erasure / portability / correction), and the assigned handler.
3. Identity is verified: government ID or login-based verification within 5 business days.

### Access request (GDPR Art 15 / PDPA Sec 30)

1. Run `scripts/infra/user-data-export.sh --username <username> --email <email>`.
2. Review archive for completeness.
3. Deliver archive via secure link with 7-day expiry.
4. Log completion in erasure register.

### Erasure request (GDPR Art 17 / PDPA Sec 35)

1. Confirm no legal hold applies (see Section 7).
2. Follow `docs/ops/runbooks/DATA_ERASURE_RUNBOOK.md` step by step.
3. Document completion in erasure register with step log.
4. Notify user of completion within 30-day SLA.

### Correction request (GDPR Art 16 / PDPA Sec 34)

1. Instruct user to update profile via the LMS account settings page (`/account/settings`).
2. For fields not self-serviceable, update via Django admin with audit log entry.
3. Propagate correction to HubSpot CRM if the field is mirrored there.

### Portability request (GDPR Art 20)

Same as access request; specify JSON format explicitly in the delivery email.

### Tracking

All DSARs are tracked in a private register (`docs/operations/DATA_RETENTION_POLICY.md` — not committed to the public repo). Each entry includes: request hash, request type, received date, verified date, completed date, and steps executed.

---

## 7. Retention Exceptions

### Legal holds

A data subject's data must not be deleted or anonymized while a legal hold is active. Legal holds are triggered by:

- Active litigation or regulatory investigation naming the data subject.
- Court order requiring data preservation.
- Fraud or abuse investigation (internal).
- Chargebacks or payment disputes unresolved with Stripe.

To place a legal hold:
1. Record the hold in the private DSAR register with: date, authority or case reference, and the responsible contact.
2. Mark the user account in `user_api_userretirementstatus` with state `LEGAL_HOLD`.
3. Notify the erasure requestor that the request cannot be fulfilled while the hold is active, and provide the statutory basis.

To release a legal hold:
1. Obtain written confirmation from legal counsel or the relevant authority.
2. Remove the `LEGAL_HOLD` state marker.
3. Resume the erasure or portability request within 30 days of hold release.

### Financial record exceptions

Orders, line items, entitlements, and audit logs are retained for 7 years per Companies Act 2016. PII fields (buyer_email, stripe_customer_id) are anonymized on erasure; financial totals and timestamps are retained. Data subjects are informed of this exception at the time of erasure confirmation.

### Certificate records exception

Certificates may be retained for 10 years to support verification requests from employers or academic institutions. Data subjects who request erasure are informed that certificate records are retained anonymized (name removed, certificate ID retained) for this period.

---

## 8. Known Gaps and Remediation

| Gap | Risk | Remediation | Owner |
|-----|------|------------|-------|
| Firestore dedup records have no TTL | Low | Add Firestore TTL policy on `created_at` field | platform-engineering |
| HubSpot CRM deletion is not automated | Medium | Automate via HubSpot API in user-data-export.sh erasure mode | platform-engineering |
| ClickHouse / Aspects retention policy not configured | Medium | Set ClickHouse TTL expression when Aspects is deployed | analytics-team |
| `stripe_events.payload_json` may embed buyer email | Medium | 90-day cleanup CronJob mitigates; confirm job is running | platform-engineering |
| Forum post bodies retained after retirement | Medium | Document in DPIA; provide optional body-scrub command | platform-engineering |

---

## References

- PII Inventory: `docs/operations/PII_DATA_INVENTORY.md`
- Erasure Runbook: `docs/ops/runbooks/DATA_ERASURE_RUNBOOK.md`
- GDPR Compliance Runbook: `docs/operations/GDPR_COMPLIANCE.md`
- Spec: `specs/data-privacy-gdpr-compliance_spec.md`
- OEP-30 (PII Markup): https://open-edx-proposals.readthedocs.io/en/latest/architectural-decisions/oep-0030-arch-pii-markup-and-auditing.html
- PDPA Malaysia: https://www.pdp.gov.my/
- GDPR storage limitation: https://gdpr-info.eu/art-5-gdpr/
- GDPR right to erasure: https://gdpr-info.eu/art-17-gdpr/
- GDPR right to portability: https://gdpr-info.eu/art-20-gdpr/
- Companies Act 2016 (Malaysia): https://www.ssm.com.my/
- Open edX user retirement: https://docs.openedx.org/en/latest/developers/references/user_retirement/index.html
