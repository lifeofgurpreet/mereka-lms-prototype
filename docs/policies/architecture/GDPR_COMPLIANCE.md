# GDPR Compliance for Mereka Academy Email System

**Last Updated**: 2026-02-14  
**Owner**: Platform Engineering  
**Status**: Active

## Overview

This document describes how the Mereka Academy email notification system complies with the EU General Data Protection Regulation (GDPR), particularly regarding email communications and user consent.

## Applicable GDPR Articles

### Article 7: Conditions for Consent

**Requirement**: When processing is based on consent, the controller must be able to demonstrate that the data subject has consented.

**Our Implementation**:

1. **Explicit Opt-In for Marketing**: The `marketing` email category defaults to `opted_in=false`. Users must explicitly consent before receiving marketing communications.

2. **Consent Records**: Every preference change creates an immutable `ConsentRecord` with:
   - User ID
   - Category
   - Old value → New value
   - Consent version (which privacy policy version)
   - IP address hash (SHA-256, not plaintext)
   - Source (api, one_click_unsubscribe, admin)
   - Timestamp (UTC)

3. **Consent Version Tracking**: Each consent includes a `consent_version` field (e.g., `v1.0-2026-02-14`) that references the privacy policy version shown to the user at the time of consent.

**Evidence Location**: `openedx_email_preferences.models.ConsentRecord`

### Article 21: Right to Object

**Requirement**: The data subject shall have the right to object at any time to processing of personal data concerning them.

**Our Implementation**:

Users can withdraw consent via three methods:

1. **Preferences API**: `PUT /api/user/v1/preferences/email/`
   - Authenticated endpoint
   - User can update any preference category
   - Change is logged in consent records

2. **One-Click Unsubscribe**: RFC 8058 compliant
   - HMAC-signed URL (no expiry, permanent opt-out)
   - No authentication required
   - Immediately opts user out
   - Supported by Gmail, Outlook, Apple Mail

3. **Admin Interface**: Staff can update on user's behalf (rare cases)
   - Logged with source='admin'
   - Audited access

**Evidence Location**: `openedx_email_preferences.views.one_click_unsubscribe_view`

### Article 15: Right of Access (Subject Access Request)

**Requirement**: The data subject shall have the right to obtain from the controller confirmation as to whether or not personal data concerning them is being processed.

**Our Implementation**:

**Admin API**: `/api/user/v1/preferences/email/admin/consent-records/?user=<username>`

Returns:
- All email preferences (current state)
- Full consent history (every change, with timestamps)
- IP address hashes (not plaintext IPs)
- Source of each change

**Access Control**: Requires staff/admin permission. All accesses logged.

**Evidence Location**: `openedx_email_preferences.views.consent_records_admin_view`

### Article 17: Right to Erasure

**Requirement**: The data subject shall have the right to obtain from the controller the erasure of personal data concerning them without undue delay.

**Our Implementation**:

On user account deletion:

1. **Email Preferences**: Deleted (CASCADE from User FK)
2. **Consent Records**: Anonymized (user_id set to NULL) but retained for audit purposes
   - Rationale: Required for demonstrating GDPR compliance (Article 7)
   - Records contain only hashed IPs, no PII

**Note**: We do NOT delete consent records entirely because they serve as legal evidence of consent for previous communications. Anonymization satisfies GDPR while preserving audit trail.

**Evidence Location**: Django CASCADE on `UserEmailPreference.user` FK

## Email Categories & Consent Requirements

| Category | Requires Explicit Consent | Default Opt-In | System Critical |
|----------|---------------------------|----------------|-----------------|
| `marketing` | **Yes** (GDPR) | **No** | No |
| `transactional` | No (legitimate interest) | Yes | **Yes** |
| `announcements` | No (legitimate interest) | Yes | No |
| `reminders` | No (legitimate interest) | Yes | No |
| `discussions` | No (legitimate interest) | Yes | No |

### Justification

- **Marketing**: Promotional content → requires explicit consent (GDPR Article 6(1)(a))
- **Transactional**: Receipts, password resets → legitimate interest (GDPR Article 6(1)(f))
- **Announcements/Reminders/Discussions**: Part of educational service → legitimate interest

## One-Click Unsubscribe (RFC 8058)

### Implementation

All marketing emails include:

```
List-Unsubscribe: <https://academyv2.mereka.io/api/user/v1/preferences/email/unsubscribe/TOKEN>
List-Unsubscribe-Post: List-Unsubscribe=One-Click
```

### Token Format

- HMAC-SHA256 signed
- Format: `base64(user_id|category|signature)`
- **No expiry** (permanent opt-out per GDPR)
- Uses server-side secret (not user password)

### Security

- Constant-time signature comparison (timing attack resistant)
- Token proves user identity without authentication
- IP address logged (hashed) for audit trail

**Evidence Location**: `openedx_email_preferences.utils.generate_unsubscribe_token`

## Data Minimization (Article 5)

### IP Address Handling

**Requirement**: Personal data shall be adequate, relevant and limited to what is necessary.

**Our Implementation**:

We do NOT store plaintext IP addresses. Instead:

```python
ip_address_hash = hashlib.sha256(ip_address.encode('utf-8')).hexdigest()[:16]
```

This provides:
- Audit trail (detect suspicious patterns)
- User privacy (cannot reverse to original IP)
- Compliance with data minimization

**Evidence Location**: `UserEmailPreference._hash_ip()`

## Consent Version Management

### Purpose

Track which version of privacy policy user consented to.

### Implementation

Each consent record includes `consent_version` (e.g., `v1.0-2026-02-14`).

### Process

1. User views privacy policy v1.0
2. User opts into marketing
3. Consent record stores: `consent_version='v1.0-2026-02-14'`

4. Privacy policy updated to v2.0
5. Next marketing email prompts re-consent
6. New consent record stores: `consent_version='v2.0-2026-03-01'`

### Future Enhancement

Re-prompt users when privacy policy changes (not implemented in v1).

## ACE Integration & Preference Enforcement

### Pre-Send Filter

Before dispatching any email via ACE:

```python
from openedx_email_preferences.utils import check_user_can_receive_email

if not check_user_can_receive_email(user, category='marketing'):
    # User has opted out → block send
    logger.info(f"Email blocked: user {user.username} opted out of {category}")
    return
```

### System-Critical Bypass

**Password resets** and **account activation** emails bypass opt-out:

```python
SYSTEM_CRITICAL = ['transactional', 'account_activation', 'password_reset']
if category in SYSTEM_CRITICAL:
    return True  # Always send
```

**Rationale**: These are essential for account security and service functionality (legitimate interest, GDPR Article 6(1)(f)).

## Audit Trail & Immutability

### ConsentRecord Guarantees

1. **Immutable**: Records cannot be deleted (Django admin permission disabled)
2. **Append-Only**: New records created for every change
3. **Timestamped**: UTC timestamp for every consent
4. **Attributed**: Source field records how change was made

### Use Cases

- **GDPR SAR**: Provide full consent history to user
- **Legal Defense**: Demonstrate consent for previous marketing emails
- **Audit**: Detect suspicious preference changes (e.g., mass opt-outs)

## GDPR Rights Summary

| Right | Article | Implementation | Endpoint |
|-------|---------|----------------|----------|
| **Consent** | Art. 7 | Explicit opt-in for marketing, versioned consent | `PUT /api/user/v1/preferences/email/` |
| **Access** | Art. 15 | Admin API returns full history | `GET /api/user/v1/preferences/email/admin/consent-records/` |
| **Rectification** | Art. 16 | User can update preferences | `PUT /api/user/v1/preferences/email/` |
| **Erasure** | Art. 17 | Delete preferences, anonymize consents on account deletion | Django CASCADE + manual anonymization |
| **Object** | Art. 21 | One-click unsubscribe, API opt-out | `GET /api/user/v1/preferences/email/unsubscribe/<token>/` |
| **Portability** | Art. 20 | Export via admin API (JSON) | `GET /api/user/v1/preferences/email/admin/consent-records/` |

## Observability & Monitoring

### Prometheus Metrics

- `email_preferences_changes_total{category, action}` - Preference updates
- `email_unsubscribe_total{method, category}` - Unsubscribe events

### Logs

- Preference updates: `user_id`, `category`, `old_value`, `new_value`
- One-click unsubscribes: `user_id`, `category`, `ip_hash`
- Admin consent access: `admin_user`, `accessed_user`

### Alerts

- Unsubscribe rate > 5% of total sends (quality issue)

## Compliance Checklist

- [x] Explicit consent for marketing emails (Art. 7)
- [x] Consent version tracking (Art. 7)
- [x] Immutable audit trail (Art. 7)
- [x] One-click unsubscribe (Art. 21, RFC 8058)
- [x] Admin API for SAR (Art. 15)
- [x] User can update preferences (Art. 16)
- [x] Account deletion handling (Art. 17)
- [x] IP address hashing (Art. 5: data minimization)
- [x] System-critical email bypass (legitimate interest)
- [x] All accesses logged (accountability)

## References

- [GDPR Full Text](https://gdpr-info.eu/)
- [RFC 8058: One-Click Unsubscribe](https://datatracker.ietf.org/doc/html/rfc8058)
- [Spec: email-notifications-pipeline_spec.md](../../../specs/email-notifications-pipeline_spec.md)
- Bead: mereka-lms-bnw1 (internal tracker entry)

## Future Enhancements

1. **Re-consent on Privacy Policy Updates**: Automatically detect policy changes and prompt re-consent
2. **Bulk Export**: Self-service GDPR export for users (not just admin)
3. **Consent UI**: In-app modal for explicit marketing consent during onboarding
4. **Per-Course Preferences**: Fine-grained opt-out by course (currently category-level only)

## Questions & Clarifications

Contact: Platform Engineering Team (`platform@mereka.io`)
