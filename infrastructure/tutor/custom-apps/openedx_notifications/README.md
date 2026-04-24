# Open edX In-App Notifications

Django app for in-app notification tray and ACE channel integration.

## Purpose

This app provides the notification tray backend for Mereka Academy Open edX, enabling:

1. **Notification Store**: MySQL-backed storage for user notifications
2. **REST API**: Endpoints for notification list, unread count, mark as read, delete
3. **ACE Integration**: `in_app` channel that creates notifications from ACE messages
4. **Multi-Tenancy**: Notifications isolated by `org_slug` (no cross-tenant leakage)
5. **Expiry & Purge**: Automatic expiry filtering and scheduled purge of old notifications

## Specification

- **Spec**: `specs/email-notifications-pipeline_spec.md` (Phase 3: In-App Notifications)
- **Acceptance Criteria**: AC-010 through AC-014

## Installation

```bash
cd infrastructure/tutor/custom-apps/openedx_notifications
pip install -e .
```

## Configuration

Add to `INSTALLED_APPS` in LMS settings:

```python
INSTALLED_APPS += [
    'openedx_notifications',
]
```

Add to URL configuration:

```python
urlpatterns += [
    path('api/notifications/v1/', include('openedx_notifications.urls')),
]
```

Configure ACE channels:

```python
ACE_ENABLED_CHANNELS = ["django_email", "push", "in_app"]
```

Feature flag (optional):

```python
NOTIFICATION_INAPP_ENABLED = True  # Enable in-app notifications
```

## Database Schema

### Notification Model

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key |
| `user` | ForeignKey | Recipient user |
| `message_type` | CharField(50) | ACE message type (e.g., `course_announcement`) |
| `title` | CharField(255) | Notification title |
| `body` | TextField | Notification body (supports Markdown) |
| `course_id` | CharField(255) | Course ID (nullable) |
| `org_slug` | CharField(255) | Organization slug (multi-tenancy) |
| `deep_link_url` | URLField | Deep link for mobile/MFE navigation (nullable) |
| `read` | BooleanField | Read status (default: False) |
| `created_at` | DateTimeField | Creation timestamp (UTC) |
| `expires_at` | DateTimeField | Expiry timestamp (nullable) |

**Indexes**:
- `(user, read, created_at)`
- `(user, org_slug, read)`
- `(expires_at)`

## API Endpoints

### List Notifications

```http
GET /api/notifications/v1/
```

**Query Parameters**:
- `read` (optional): Filter by read status (`true`/`false`)
- `message_type` (optional): Filter by message type
- `org_slug` (optional): Organization slug (defaults to `default`)
- `page` (optional): Page number (default: 1)
- `page_size` (optional): Items per page (default: 20, max: 100)

**Response** (200 OK):
```json
{
  "count": 50,
  "next": "http://academyv2.mereka.io/api/notifications/v1/?page=2",
  "previous": null,
  "results": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "message_type": "course_announcement",
      "title": "New Assignment Posted",
      "body": "Your instructor has posted a new assignment...",
      "course_id": "course-v1:MerekaX+CS101+2026",
      "org_slug": "merekax",
      "deep_link_url": "https://apps.academyv2.mereka.io/learning/course/course-v1:MerekaX+CS101+2026/home",
      "read": false,
      "created_at": "2026-02-14T10:30:00Z",
      "expires_at": null
    }
  ]
}
```

### Unread Count

```http
GET /api/notifications/v1/unread-count/
```

**Response** (200 OK):
```json
{
  "unread_count": 5
}
```

**Performance**: p95 latency <= 100ms

### Mark as Read

```http
PATCH /api/notifications/v1/{id}/read/
```

**Response** (200 OK):
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "read": true,
  ...
}
```

### Mark All Read

```http
POST /api/notifications/v1/mark-all-read/
```

**Response** (200 OK):
```json
{
  "message": "Marked 10 notifications as read",
  "count": 10
}
```

### Delete Notification

```http
DELETE /api/notifications/v1/{id}/
```

**Response** (204 No Content)

## ACE Integration

The `InAppChannel` creates notifications when ACE dispatches messages through the `in_app` channel.

**Required ACE message context**:
```python
message = Message(
    app_label='lms',
    name='course_announcement',
    recipient=user,
    context={
        'course_id': 'course-v1:MerekaX+CS101+2026',
        'org_slug': 'merekax',
        'deep_link_url': 'https://...',
        'expires_at': None,  # Optional
    }
)

ace.send(message)
```

The channel extracts:
- **Title**: From rendered subject
- **Body**: From rendered body
- **Metadata**: From message context (`course_id`, `org_slug`, `deep_link_url`)

## Notification Purge

Expired notifications older than 90 days are automatically purged via a Celery task.

**Celery Beat schedule** (add to settings):
```python
CELERYBEAT_SCHEDULE = {
    'purge-expired-notifications': {
        'task': 'openedx_notifications.purge_expired_notifications',
        'schedule': crontab(hour=3, minute=0),  # Daily at 3 AM UTC
        'args': (90,),  # Retention days
    },
}
```

**Manual purge**:
```python
from openedx_notifications.tasks import purge_expired_notifications
purge_expired_notifications.delay(retention_days=90)
```

## Multi-Tenancy

Notifications are scoped by `org_slug`:

1. API endpoints filter notifications by user's `org_slug`
2. No cross-tenant leakage (AC-014)
3. Org slug derived from:
   - Request parameter `?org_slug=acme` (temporary)
   - User profile `org_slug` field (future integration with multi-tenancy spec)

**Current implementation** uses request parameter; **production** should integrate with user profile.

## Testing

Run tests:
```bash
pytest infrastructure/tutor/custom-apps/openedx_notifications/tests/
```

Verify API:
```bash
# Create test notification (via Django shell)
from openedx_notifications.models import Notification
from django.contrib.auth import get_user_model
User = get_user_model()
user = User.objects.get(username='learner1')
Notification.objects.create(
    user=user,
    message_type='course_announcement',
    title='Test Notification',
    body='This is a test',
    org_slug='default'
)

# Test API
curl -H "Authorization: Bearer <token>" \
  https://academyv2.mereka.io/api/notifications/v1/unread-count/
```

## Performance

- **Unread count**: Uses database index on `(user, read)`, p95 <= 100ms
- **List query**: Uses index on `(user, org_slug, read)`, p95 <= 200ms
- **Pagination**: Cursor-based for consistent performance with large datasets

## Observability

**Metrics** (Prometheus):
- `notification_inapp_created_total{message_type, org_slug}`
- `notification_inapp_read_total{message_type, org_slug}`

**Logs**:
- Every notification creation logs: `notification_id`, `user_id`, `message_type`, `org_slug`

## Dependencies

- Django ≥3.2
- Django REST Framework ≥3.14
- edx-ace ≥1.3.0
- Celery (for purge task)

## Future Enhancements

- Real-time updates via Server-Sent Events (SSE)
- Notification batching (flood prevention)
- Rich notification templates (HTML body)
- Notification categories and priorities
- Push notification coordination (link to FCM delivery)
