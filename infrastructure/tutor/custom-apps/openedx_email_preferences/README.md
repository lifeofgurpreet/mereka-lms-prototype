# Open edX Email Preferences & GDPR Consent

Django app for email preference management and GDPR-compliant consent tracking.

## Purpose

This app provides the email preferences backend for Mereka Academy Open edX, enabling:

1. **Per-User Preferences**: Category-based email opt-in/opt-out (marketing, transactional, announcements, reminders, discussions)
2. **GDPR Compliance**: Explicit consent tracking with version control and audit trail (Article 7 & 21)
3. **One-Click Unsubscribe**: RFC 8058 compliant unsubscribe via HMAC-signed URLs
4. **ACE Integration**: Preference enforcement in email dispatch pipeline
5. **Admin API**: GDPR SAR (Subject Access Request) compliance

## Specification

- **Spec**: `specs/email-notifications-pipeline_spec.md` (Phase 2: Notification Preferences)
- **Bead**: `mereka-lms-bnw1`
- **Acceptance Criteria**: AC-020 through AC-024, AC-043 through AC-045

## Installation

```bash
cd infrastructure/tutor/custom-apps/openedx_email_preferences
pip install -e .
```

## Configuration

Add to `INSTALLED_APPS` in LMS settings:

```python
INSTALLED_APPS += [
    'openedx_email_preferences',
]
```

Add to URL configuration:

```python
urlpatterns += [
    path('api/user/v1/preferences/email/', include('openedx_email_preferences.urls')),
]
```

Enable feature flag:

```python
ENABLE_EMAIL_PREFERENCES = True
```

Set unsubscribe secret (optional, defaults to SECRET_KEY):

```python
EMAIL_UNSUBSCRIBE_SECRET_KEY = os.environ.get('EMAIL_UNSUBSCRIBE_SECRET_KEY', SECRET_KEY)
```

## Database Schema

### UserEmailPreference Model

| Field | Type | Description |
|-------|------|-------------|
| `user` | ForeignKey | User whose preferences these are |
| `category` | CharField(50) | Email category (marketing, transactional, etc.) |
| `opted_in` | BooleanField | Whether user has opted in |
| `consent_version` | CharField(50) | Version of consent text (GDPR audit) |
| `created_at` | DateTimeField | When preference was first created (UTC) |
| `updated_at` | DateTimeField | When preference was last modified (UTC) |

**Unique constraint**: `(user, category)`

**Indexes**:
- `(user, category)`
- `(updated_at)`

### ConsentRecord Model (Immutable Audit Trail)

| Field | Type | Description |
|-------|------|-------------|
| `user` | ForeignKey | User whose consent this records |
| `category` | CharField(50) | Email category affected |
| `old_value` | BooleanField | Previous opted-in state |
| `new_value` | BooleanField | New opted-in state |
| `consent_version` | CharField(50) | Version of consent text shown |
| `ip_address_hash` | CharField(64) | SHA-256 hash of IP (not plaintext) |
| `source` | CharField(50) | How change was made (api, one_click_unsubscribe, admin) |
| `timestamp` | DateTimeField | When consent was recorded (UTC) |

**Indexes**:
- `(user, timestamp)`
- `(category, timestamp)`

## Email Categories

| Category | Default | Description | System Critical |
|----------|---------|-------------|-----------------|
| `marketing` | False | Marketing communications | No |
| `transactional` | True | Transactional emails (receipts, etc.) | Yes |
| `announcements` | True | Course announcements | No |
| `reminders` | True | Assignment reminders | No |
| `discussions` | True | Discussion notifications | No |

**Note**: System-critical categories (transactional) cannot be opted out.

## API Endpoints

### Get Email Preferences

```http
GET /api/user/v1/preferences/email/
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "preferences": {
    "marketing": false,
    "transactional": true,
    "announcements": true,
    "reminders": true,
    "discussions": true
  }
}
```

**Rate Limit**: 60 requests per minute per user

### Update Email Preferences

```http
PUT /api/user/v1/preferences/email/
Authorization: Bearer <token>
Content-Type: application/json

{
  "preferences": [
    {
      "category": "marketing",
      "opted_in": true,
      "consent_version": "v1.0-2026-02-14"
    },
    {
      "category": "announcements",
      "opted_in": false
    }
  ]
}
```

**Response** (200 OK):
```json
{
  "preferences": {
    "marketing": true,
    "transactional": true,
    "announcements": false,
    "reminders": true,
    "discussions": true
  },
  "updated_count": 2
}
```

**Rate Limit**: 60 requests per minute per user

### One-Click Unsubscribe

```http
GET /api/user/v1/preferences/email/unsubscribe/<token>/
```

**No authentication required** - token proves identity.

**Response** (200 OK):
```html
<html><body>
<h1>Unsubscribe Successful</h1>
<p>You have been unsubscribed from <strong>marketing</strong> emails.</p>
<p>You can manage all your email preferences in your account settings.</p>
</body></html>
```

**POST support** (RFC 8058):
```http
POST /api/user/v1/preferences/email/unsubscribe/<token>/
```

Response:
```json
{
  "success": true,
  "message": "You have been unsubscribed from marketing emails."
}
```

### Admin: Get Consent Records (GDPR SAR)

```http
GET /api/user/v1/preferences/email/admin/consent-records/?user=<username>
Authorization: Bearer <admin-token>
```

**Requires**: Staff permission

**Response** (200 OK):
```json
{
  "user": "learner1",
  "user_id": 123,
  "total_records": 5,
  "records": [
    {
      "id": 1,
      "username": "learner1",
      "category": "marketing",
      "old_value": false,
      "new_value": true,
      "consent_version": "v1.0-2026-02-14",
      "ip_address_hash": "a1b2c3d4e5f6g7h8",
      "source": "api",
      "timestamp": "2026-02-14T10:30:00Z"
    }
  ]
}
```

## HMAC Unsubscribe URLs

### Generate Token

```python
from openedx_email_preferences.utils import generate_unsubscribe_url

url = generate_unsubscribe_url(user, category='marketing')
# https://academyv2.mereka.io/api/user/v1/preferences/email/unsubscribe/<token>/
```

### Add to Email Headers (RFC 8058)

```python
from openedx_email_preferences.utils import get_list_unsubscribe_headers

headers = get_list_unsubscribe_headers(user, category='marketing')
# {
#   'List-Unsubscribe': '<https://academyv2.mereka.io/...>',
#   'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click'
# }
```

### Security

- HMAC-SHA256 signature with server secret
- Token format: `base64(user_id|category|hmac)`
- **No expiry** (permanent opt-out per GDPR)
- Constant-time signature comparison (timing attack resistant)

## ACE Integration

### Check Before Sending

```python
from openedx_email_preferences.utils import check_user_can_receive_email

if check_user_can_receive_email(user, category='marketing'):
    # Send email
    ace.send(message)
else:
    # User has opted out
    logger.info(f"Email blocked: user {user.username} opted out of {category}")
```

### Default Preferences

New users get these defaults:

```python
{
    'marketing': False,  # GDPR: explicit opt-in required
    'transactional': True,
    'announcements': True,
    'reminders': True,
    'discussions': True,
}
```

## GDPR Compliance

### Consent Tracking (Article 7)

Every preference change creates an immutable `ConsentRecord` with:

- User ID
- Category
- Old value → New value
- Consent version (which privacy policy version)
- IP address hash (SHA-256, not plaintext)
- Source (api, one_click_unsubscribe, admin)
- Timestamp (UTC)

### Right to Object (Article 21)

Users can opt out via:

1. **API**: `PUT /api/user/v1/preferences/email/`
2. **One-Click Unsubscribe**: Click link in email (no login required)
3. **Admin**: Staff can update on user's behalf (rare)

### Subject Access Request (Article 15)

Admin API returns full consent history:

```bash
curl -H "Authorization: Bearer <admin-token>" \
  "https://academyv2.mereka.io/api/user/v1/preferences/email/admin/consent-records/?user=learner1"
```

### Right to Erasure (Article 17)

On user deletion, consent records are **anonymized** (user_id set to null) but retained for audit purposes.

## Rate Limiting

- **Preferences API**: 60 requests per minute per user
- **One-Click Unsubscribe**: No rate limit (single-use tokens)
- **Admin API**: No rate limit (staff only, audited)

Exceeded rate limit returns:

```json
{
  "error": "Rate limit exceeded. Maximum 60 requests per minute."
}
```

HTTP Status: `429 Too Many Requests`

## Testing

### Unit Tests

```bash
pytest infrastructure/tutor/custom-apps/openedx_email_preferences/tests/
```

### Manual Testing

```bash
# 1. Get preferences
curl -H "Authorization: Bearer <token>" \
  https://academyv2.mereka.io/api/user/v1/preferences/email/

# 2. Update preferences
curl -X PUT -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"preferences": [{"category": "marketing", "opted_in": true}]}' \
  https://academyv2.mereka.io/api/user/v1/preferences/email/

# 3. Generate unsubscribe token (Django shell)
from django.contrib.auth import get_user_model
from openedx_email_preferences.utils import generate_unsubscribe_url
User = get_user_model()
user = User.objects.get(username='learner1')
url = generate_unsubscribe_url(user, 'marketing')
print(url)

# 4. Test one-click unsubscribe
curl <unsubscribe-url>

# 5. Verify consent records
curl -H "Authorization: Bearer <admin-token>" \
  "https://academyv2.mereka.io/api/user/v1/preferences/email/admin/consent-records/?user=learner1"
```

## Observability

**Metrics** (Prometheus):
- `email_preferences_changes_total{category, action}` - Preference updates
- `email_unsubscribe_total{method, category}` - Unsubscribe events

**Logs**:
- Preference updates: `user_id`, `category`, `old_value`, `new_value`
- One-click unsubscribes: `user_id`, `category`, `ip_hash`
- Admin consent access: `admin_user`, `accessed_user`

**Alerts**:
- Unsubscribe rate > 5% of total sends (quality problem)

## Security Notes

- IP addresses hashed (SHA-256) before storage
- HMAC tokens use constant-time comparison
- Consent records are immutable (append-only)
- Admin access logged for audit trail
- Rate limiting prevents abuse

## Dependencies

- Django ≥3.2
- Django REST Framework ≥3.14
- django-ratelimit ≥4.1.0

## Future Enhancements

- Push notification preferences (Phase 4)
- In-app notification preferences (Phase 3)
- Per-course granular preferences
- Preference import/export
- Batch preference updates for enterprise admins
