# GDPR Compliance Operational Runbook

> **Spec**: `specs/data-privacy-gdpr-compliance_spec.md`
> **Related**: `docs/ops/runbooks/PRIVACY_RUNBOOK.md` (brief quick-reference)
> **Owner**: platform-engineering
> **Last Updated**: 2026-02-24
> **Regulations covered**: GDPR (EU), PDPA (Malaysia Personal Data Protection Act 2010)

---

## Table of Contents

1. [Cookie Consent Implementation](#1-cookie-consent-implementation)
2. [User Retirement Pipeline](#2-user-retirement-pipeline)
3. [PII Cleanup for Custom Services](#3-pii-cleanup-for-custom-services)
4. [Data Export Request Handling](#4-data-export-request-handling)
5. [Data Retention Policy and Schedule](#5-data-retention-policy-and-schedule)
6. [Incident Response: Data Breach](#6-incident-response-data-breach)
7. [Verification](#7-verification)

---

## 1. Cookie Consent Implementation

### Status

Cookie consent banner is **not yet implemented** (feature flag `ENABLE_COOKIE_CONSENT_BANNER=false`).
The feature flag must be set before the banner activates. Until then, the LMS operates under
the PDPA legitimate-interest basis for analytics and essential cookies only.

### Open edX Built-in Consent Tracking

Open edX Ulmo has partial consent tracking support. The relevant Django settings are:

```python
# infrastructure/tutor/apply-patches.sh (add to LMS production.py patch)
ENABLE_COOKIE_CONSENT_BANNER = env("ENABLE_COOKIE_CONSENT_BANNER", default=False)
ENABLE_CONSENT_ENFORCEMENT = env("ENABLE_CONSENT_ENFORCEMENT", default=False)
CONSENT_TRACKING_ENABLED = True   # Enables Open edX's own event consent checks
```

The `consent_datasharingconsent` MySQL table already exists (created by Open edX migrations)
and stores enterprise data-sharing consent decisions. Cookie consent uses a separate mechanism.

### Cookie Inventory

| Cookie Name | Purpose | Category | Duration | First/Third Party |
|-------------|---------|----------|----------|-------------------|
| `sessionid` | User authentication session | strictly_necessary | Session | First |
| `csrftoken` | CSRF protection | strictly_necessary | 1 year | First |
| `edx-jwt-cookie-*` | JWT authentication tokens | strictly_necessary | 1 hour | First |
| `stage-edx-*` | Staging environment auth | strictly_necessary | Session | First |
| `openedx-*` | LMS preferences (language, timezone) | functional | 1 year | First |
| `_ga`, `_gid` | Google Analytics (if configured) | analytics | 2 years / 1 day | Third |

### Implementing the Cookie Banner

When ready to implement, use the Olive/Ulmo MFE plugin slot approach:

1. Create a consent banner component in `infrastructure/tutor/plugins/mereka_lms.py` (or another
   supported Tutor plugin location) as a plugin slot:

   ```js
   // Targets the PLUGIN_OPERATIONS.Insert slot in the LearningFooter MFE
   // or use a global banner via a custom HTML template injection
   ```

2. Add the banner script to Caddy or the LMS base template:
   ```
   # infrastructure/tutor/apply-patches.sh — inject into base.html via patch
   ```

3. Set the feature flag:
   ```bash
   export TUTOR_ROOT="$(pwd)/tutor_env"
   ./scripts/infra/tutor-config-save.sh --set ENABLE_COOKIE_CONSENT_BANNER=True
   tutor local restart
   ```

4. Verify banner presence:
   ```bash
   ./scripts/qa/verify-gdpr-compliance.sh --online
   ```

### Cookie Consent Geo-Detection

Per spec, EU/UK users require opt-in consent; ASEAN users receive notice-only.
The feature flag `ENABLE_CONSENT_GEO_DETECTION` gates this behavior.
Until enabled, show the banner to all users (conservative default).

---

## 2. User Retirement Pipeline

Open edX provides the `UserRetirementStatus` model and `retire_user` management command
as the canonical mechanism for GDPR right-to-erasure requests. This pipeline is integrated
into the platform and available for use.

### What the Retirement Pipeline Does

When `retire_user` runs for a target username, it:

1. Deactivates the account (`auth_user.is_active = False`)
2. Anonymizes `auth_user`: sets `email → retired_email_{hash}@retired.invalid`,
   `username → retired_user_{hash}`, clears `first_name` / `last_name`
3. Deletes `auth_userprofile` demographics record
4. Anonymizes forum posts (`author_username → [deleted]`) via Forum service API
5. Deletes enrollment records and grades (or anonymizes, per DPA terms)
6. Revokes and deletes certificates
7. Deletes SSO linkages (`social_auth_usersocialauth`)
8. Invalidates active sessions (Redis)
9. Records `UserRetirementStatus` transition: `COMPLETE`

### Running the Retirement Pipeline

**Production (Kubernetes)**:

```bash
# Step 1: Verify the username to retire
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms show_retirement_states

# Step 2: Initiate retirement request (queues the user)
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms retirement_retire_learner \
  --username <username>

# Step 3: Execute the pipeline
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms perform_retirement \
  --username <username>

# Step 4: Verify completion
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms show_retirement_states \
  --username <username>
```

**Alternative — direct retire_user command** (simpler, uses tubular):

```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms retire_user \
  --username <username>
```

### Verifying Retirement Completion

```bash
# Check UserRetirementStatus table
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from openedx.core.djangoapps.user_authn.utils import is_retiring_username
print(is_retiring_username('<username>'))
"

# Check auth_user record is anonymized
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
users = User.objects.filter(username__startswith='retired_user_')
print(f'Retired users: {users.count()}')
"
```

### SLA and Timeline

| Action | SLA |
|--------|-----|
| Acknowledge request | 3 business days |
| Identity verification | 5 business days |
| Execute retirement pipeline | Within 30 days of verified request |
| Confirm deletion to requester | Within 30 days |

### If Retirement Fails Mid-Run

```bash
# Check Celery task status
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from openedx.core.djangoapps.user_api.accounts.retirement_api import \
  get_retirement_for_learner
status = get_retirement_for_learner(username='<username>')
print(status)
"

# Resume with force flag
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms retire_user \
  --username <username> \
  --force
```

---

## 3. PII Cleanup for Custom Services

### Purchase Gateway (PostgreSQL)

The Purchase Gateway stores PII in these tables:
- `orders`: `buyer_email`, `buyer_user_id` — retained 7 years (financial obligation)
- `entitlements`: `recipient_email`
- `stripe_events`: `payload` JSON (may contain buyer email from Stripe)

**Anonymization procedure** (run after Open edX retirement pipeline completes):

```bash
# Get purchase-gateway pod name
PG_POD=$(kubectl get pod -n mereka-lms -l app=payments-gateway \
  -o jsonpath='{.items[0].metadata.name}')

# Anonymize buyer_email in orders (retain financial data per 7-year obligation)
kubectl exec -n mereka-lms "$PG_POD" -- python -c "
import os, hashlib
from app.database import get_session
from app.models.order import Order
from sqlalchemy import update

username = '<username>'
email = '<email>'
email_hash = hashlib.sha256(email.encode()).hexdigest()[:16]
retired_email = f'retired_{email_hash}@retired.invalid'

with get_session() as db:
    db.execute(
        update(Order).where(Order.buyer_email == email).values(
            buyer_email=retired_email,
            buyer_user_id=None
        )
    )
    db.commit()
    print(f'Anonymized orders for {email} -> {retired_email}')
"

# Anonymize recipient_email in entitlements
kubectl exec -n mereka-lms "$PG_POD" -- python -c "
import hashlib
from app.database import get_session
from app.models.entitlement import Entitlement
from sqlalchemy import update

email = '<email>'
email_hash = hashlib.sha256(email.encode()).hexdigest()[:16]
retired_email = f'retired_{email_hash}@retired.invalid'

with get_session() as db:
    db.execute(
        update(Entitlement).where(Entitlement.recipient_email == email).values(
            recipient_email=retired_email
        )
    )
    db.commit()
    print(f'Anonymized entitlements for {email}')
"
```

**Important**: Do NOT delete order records. Malaysian Companies Act 2016 requires financial
records to be retained for 7 years. Only anonymize the PII fields; retain order UUIDs,
amounts, and currency for accounting.

### Forum (MongoDB Atlas)

Forum posts are anonymized (not deleted) to preserve community value. The Open edX
retirement pipeline handles this automatically via the Forum service API.

Verify forum anonymization:

```bash
# Via the Forum API (in-process with LMS)
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
from openedx_django_wiki.views import *
# Forum posts with author '[deleted]' confirm anonymization
"
```

### Meilisearch Search Index

After forum anonymization, the Meilisearch index must be updated:

```bash
# Re-index forum content (triggers re-sync from MongoDB)
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms reindex_forum
```

### ClickHouse Analytics (Aspects)

ClickHouse does not support row-level deletion in most configurations.
The retention policy (365 days) handles historical data.

For immediate erasure, contact the Aspects/ClickHouse administrator to run:

```sql
-- Delete all events for a user (identified by hashed actor_id)
-- Note: hash must match the anonymization applied by the analytics pipeline
ALTER TABLE xapi_events_all
  DELETE WHERE actor_id = hashUser('<user_id>');
```

### Redis Session Cleanup

The Open edX retirement pipeline invalidates sessions. Manual cleanup if needed:

```bash
kubectl exec -n mereka-lms deployment/redis -- \
  redis-cli KEYS "user:<user_id>:*" | \
  xargs redis-cli DEL
```

---

## 4. Data Export Request Handling

Data export (GDPR Article 20 — Right to Data Portability) allows users to download
all their personal data in machine-readable format.

### Self-Service Export (User-Initiated)

Users can initiate data export from their account settings:

```
https://academyv2.mereka.io/account/settings
→ "Download my data" (if enabled in LMS settings)
```

The Open edX data export API endpoint:

```
GET /api/user/v1/accounts/download/
Authorization: Bearer <user-jwt>
```

This returns a ZIP archive containing profile data, enrollments, grades, and forum activity.

### Operator-Initiated Export (SAR Response)

For Subject Access Requests received via privacy@mereka.io:

```bash
# 1. Export user data
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms export_user_data \
  --username <username> \
  --output /tmp/user_data_export.zip

# 2. Copy export from pod
kubectl cp mereka-lms/<lms-pod>:/tmp/user_data_export.zip \
  ./user_data_export_<username>.zip

# 3. Review and redact before delivery
#    - Remove third-party SSO tokens
#    - Remove internal system identifiers not relevant to user
#    - Verify no other users' data is included
```

The export archive includes:
- `profile.json` — user profile fields
- `enrollments.json` — course enrollment records
- `grades.json` — course grades and completion status
- `certificates.json` — issued certificates
- `forum_activity.json` — forum posts and comments
- `consent_records.json` — consent history (required by GDPR Article 7)

### SLA

| Milestone | Deadline |
|-----------|----------|
| Acknowledge SAR | 3 business days |
| Verify identity | 5 business days |
| Deliver export | Within 30 days of verified request |
| Complex requests (extension) | Up to 90 days (notify requester of extension) |

---

## 5. Data Retention Policy and Schedule

### Retention Periods by Data Category

| Data Store | Data Category | Retention Period | Legal Basis | Deletion Method |
|------------|--------------|-----------------|-------------|-----------------|
| MySQL: `auth_user` | User accounts | Account lifetime | Contract | Anonymize on retirement |
| MySQL: `auth_userprofile` | Demographics | Account lifetime | Contract | Delete record |
| MySQL: `student_courseenrollment` | Enrollment records | Account lifetime or per DPA | Contract | Delete or anonymize |
| MySQL: `grades_persistentcoursegrade` | Grades | Account lifetime | Contract | Delete or anonymize |
| MySQL: `consent_datasharingconsent` | Consent evidence | 5 years post-relationship | Legal obligation | Anonymize user ID, retain record |
| MySQL: `django_session` | Session state | 24 hours (TTL) | Contract | Automatic expiry |
| PostgreSQL: `orders` | Financial records | 7 years | Legal obligation (Companies Act 2016) | Anonymize PII fields; retain financial data |
| PostgreSQL: `stripe_events` | Webhook payloads | 90 days | Contract | Delete records >90 days old |
| ClickHouse: `xapi_events_all` | Analytics events | 365 days | Legitimate interest | Automatic TTL-based expiry |
| Redis: sessions/cache | Session and cache data | 24 hours (TTL) | Contract | Automatic TTL-based expiry |
| Loki: application logs | Application logs | 30 days | Legitimate interest | Automatic retention policy |
| Tempo: traces | Distributed traces | 30 days | Legitimate interest | Automatic retention policy |
| GCS: profile images | Profile images | Account lifetime | Contract | Delete on retirement |
| GCS: certificate PDFs | Certificates | 10 years | Legitimate interest | Delete on retirement (with notice) |
| GCS: backup snapshots | Database backups | 90 days (rotation) | Legitimate interest | Automatic rotation |

### Retention Schedule (Automated)

Retention policies should be verified monthly. Add to the ops calendar:

```
Monthly:
  - Verify Loki retention is enforced: kubectl exec grafana-loki -- loki-canary --check-retention
  - Verify backup rotation: gsutil ls -l gs://mereka-lms-backups/ | tail -20
  - Verify ClickHouse TTL: check xapi_events_all for records older than 365 days

Quarterly:
  - Audit stripe_events table for records >90 days
  - Review consent_datasharingconsent for records >5 years post-relationship
  - Review PII registry (specs/pii-registry.yml) for schema drift

Annually:
  - Full PII audit: ./scripts/qa/verify-gdpr-compliance.sh --offline
  - Review and update this runbook
  - DPIA review for any new processing activities added during the year
```

### Configuring Loki Retention

The Loki configuration at `infrastructure/monitoring/` should set:

```yaml
# loki-config.yaml
limits_config:
  retention_period: 720h  # 30 days
```

### Configuring ClickHouse Retention

In the Aspects/ClickHouse configuration:

```sql
-- Set TTL on xapi_events_all (run once during setup)
ALTER TABLE xapi_events_all
  MODIFY TTL toDateTime(emission_time) + INTERVAL 365 DAY;
```

---

## 6. Incident Response: Data Breach

### GDPR Breach Notification Timeline

| Time | Action |
|------|--------|
| T+0 | Breach discovered |
| T+0h | Incident commander assigned, incident channel opened |
| T+4h | Breach assessment: affected users, data types, severity |
| T+24h | Internal decision: notifiable or not? |
| T+72h | **GDPR deadline**: Notify relevant supervisory authority if risk to individuals |
| T+72h | Notify affected individuals if high risk to their rights and freedoms |
| T+5 business days | **PDPA (Malaysia) deadline**: Notify Personal Data Protection Commissioner |

### Breach Severity Classification

| Tier | Description | Action |
|------|-------------|--------|
| Critical | Direct identifiers (email, name) exposed externally | Notify authority + individuals |
| High | Pseudonymized data exposed; re-identification risk | Notify authority |
| Medium | Internal access log exposure, no external breach | Internal incident, no notification required |
| Low | Accidental log exposure, expired credentials | Internal remediation only |

### Notification Contacts

- **GDPR Supervisory Authority**: Determined by jurisdiction of affected EU data subjects
- **Malaysia PDPC**: https://www.pdp.gov.my/pdpkpd/index.php/form/borang-aduan (72h for breach notification)
- **Internal**: privacy@mereka.io, incident@mereka.io
- **DPO (Data Protection Officer)**: Assign from engineering leadership

### Post-Breach Actions

```bash
# 1. Identify affected users
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "
# Query relevant audit logs / access logs for affected period
"

# 2. Invalidate sessions for all affected users
kubectl exec -n mereka-lms deployment/redis -- \
  redis-cli FLUSHDB  # Use only if all sessions need invalidation

# 3. Force password reset for affected users (if credentials exposed)
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms force_password_reset \
  --username <username>

# 4. Document in incident log (docs/operations/postmortems/)
```

---

## 7. Verification

Run the GDPR compliance verification script regularly:

```bash
# Offline checks only (CI-safe, no network required)
./scripts/qa/verify-gdpr-compliance.sh --offline

# Full verification (requires live cluster + LMS URL)
LMS_URL=https://academyv2.mereka.io \
  ./scripts/qa/verify-gdpr-compliance.sh --online

# Both (default)
./scripts/qa/verify-gdpr-compliance.sh
```

The script checks:
- Privacy policy documentation exists
- Cookie consent feature flags are configured
- User retirement pipeline is documented
- Purchase Gateway has PII cleanup procedures
- Analytics PII audit script is present and covers ClickHouse/Loki
- ExternalSecrets do not expose user PII fields
- Data retention policy is configured
- `/privacy` endpoint responds (online)
- Cookie consent banner is present in LMS HTML (online)
- User retirement API endpoint exists (online)
- Data export endpoint exists (online)

### Expected State

Until the full GDPR consent management system is implemented (per spec Phase 1 roadmap),
most CONSENT-* checks will show SKIP. This is expected. The FAIL count should remain 0.

### Related Scripts

| Script | Purpose |
|--------|---------|
| `scripts/qa/verify-gdpr-compliance.sh` | Cookie consent + retirement pipeline verification |
| `scripts/qa/verify-data-privacy-gdpr.sh` | Full GDPR spec AC coverage verification |
| `scripts/qa/audit-analytics-pii.sh` | Scan analytics events for PII leakage |
| `scripts/qa/verify-observability-pii-filtering.sh` | Verify PII is filtered from Loki/Tempo |

---

## References

- Spec: `specs/data-privacy-gdpr-compliance_spec.md`
- PII Registry: `specs/pii-registry.yml` (to be created)
- Privacy Runbook (quick-reference): `docs/ops/runbooks/PRIVACY_RUNBOOK.md`
- Open edX User Retirement: https://docs.openedx.org/en/latest/developers/references/user_retirement/index.html
- GDPR Article 17 (Right to Erasure): https://gdpr-info.eu/art-17-gdpr/
- PDPA Malaysia: https://www.pdp.gov.my/
- Tubular (Open edX retirement tool): https://github.com/openedx/tubular
