# Open edX Video Content Protection

Django app for protecting Mux video content via signed playback URLs (Phase 5).

## Purpose

This app provides content protection for Mux videos in Mereka Academy Open edX, enabling:

1. **Signed Playback URLs**: JWT tokens with RSA-2048 signatures for time-limited video access
2. **Enrollment Verification**: Server-side enrollment checks before token generation
3. **Domain Restriction**: Playback limited to production domains
4. **Rate Limiting**: 100 signed URL requests/hour/user
5. **Audit Trail**: Full logging of access attempts (granted/denied)

## Specification

- **Spec**: `specs/video-pipeline-delivery_spec.md` (Phase 5: Content Protection)
- **Bead**: `mereka-lms-2k9i`
- **Rollout Week**: 9-10

## Installation

```bash
cd infrastructure/tutor/custom-apps/openedx_video_protection
pip install -e .
```

## Configuration

Add to `INSTALLED_APPS` in LMS settings:

```python
INSTALLED_APPS += [
    'openedx_video_protection',
]
```

Add to URL configuration (LMS):

```python
urlpatterns += [
    path('api/mux/protection/', include('openedx_video_protection.urls')),
]
```

Enable feature flag and configure signing keys:

```python
# Feature flag (default: off for safe rollout)
ENABLE_MUX_SIGNED_PLAYBACK = os.environ.get('ENABLE_MUX_SIGNED_PLAYBACK', 'false').lower() == 'true'

# Mux signing credentials (from ExternalSecrets)
MUX_SIGNING_KEY_ID = os.environ.get('MUX_SIGNING_KEY_ID')  # Mux signing key ID
MUX_SIGNING_PRIVATE_KEY = os.environ.get('MUX_SIGNING_PRIVATE_KEY')  # RSA private key (PEM)

# Optional: Domain restriction for playback
MUX_PLAYBACK_AUDIENCE = os.environ.get('MUX_PLAYBACK_AUDIENCE', 'academyv2.mereka.io')
```

## Database Schema

### SignedPlaybackToken Model

| Field | Type | Description |
|-------|------|-------------|
| `user` | ForeignKey | User who requested the signed URL |
| `course_key` | CourseKeyField | Course containing the video |
| `video_id` | CharField(255) | Mux playback ID |
| `org_slug` | CharField(100) | Organization slug |
| `token` | TextField | JWT token (for audit) |
| `expires_at` | DateTimeField | Token expiration timestamp |
| `created_at` | DateTimeField | When token was generated |
| `ip_address_hash` | CharField(64) | SHA-256 hash of IP |
| `user_agent` | CharField(500) | Client user agent |

**Indexes**:
- `(user, -created_at)`
- `(course_key, video_id, -created_at)`
- `(org_slug, -created_at)`
- `(expires_at)`

### VideoAccessLog Model

| Field | Type | Description |
|-------|------|-------------|
| `user` | ForeignKey | User who requested access (null for anonymous) |
| `course_key` | CourseKeyField | Course containing the video |
| `video_id` | CharField(255) | Mux playback ID |
| `status` | CharField(20) | granted or denied |
| `denial_reason` | CharField(100) | Reason for denial (if denied) |
| `timestamp` | DateTimeField | When access was requested |
| `ip_address_hash` | CharField(64) | SHA-256 hash of IP |
| `org_slug` | CharField(100) | Organization slug |

**Indexes**:
- `(user, -timestamp)`
- `(course_key, video_id, -timestamp)`
- `(status, -timestamp)`
- `(org_slug, -timestamp)`

## API Endpoints

### Generate Signed Playback URL

```http
POST /api/mux/protection/signed-url/
Authorization: Bearer <token>
Content-Type: application/json

{
  "playback_id": "abcd1234efgh5678",
  "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
  "expiry_hours": 12
}
```

**Response** (201 Created):
```json
{
  "url": "https://stream.mux.com/abcd1234efgh5678.m3u8?token=eyJhbG...",
  "expires_at": "2026-02-15T00:00:00Z",
  "playback_id": "abcd1234efgh5678"
}
```

**Error Responses**:
- **400**: Invalid request (missing fields, invalid course key)
- **403**: Not enrolled in course
- **429**: Rate limit exceeded (100/hour)
- **503**: Feature disabled (`ENABLE_MUX_SIGNED_PLAYBACK=false`)

### Check Video Access

```http
GET /api/mux/protection/check-access/?course_key=course-v1:MerekaAcademy+COURSE101+2024
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "has_access": true,
  "feature_enabled": true,
  "enrollment_status": "enrolled"
}
```

## Mux Signed URLs

Mux signed URLs use JWT tokens with RSA-2048 signatures. Token payload:

```json
{
  "sub": "abcd1234efgh5678",  // Playback ID
  "kid": "signing-key-123",    // Mux signing key ID
  "exp": 1739577600,           // Unix timestamp (12h from now)
  "aud": "academyv2.mereka.io", // Domain restriction
  "user_id": 42                // Custom claim for audit
}
```

### Mux Signing Key Setup

1. **Generate RSA key pair** (2048-bit):
   ```bash
   openssl genrsa -out mux_signing_key.pem 2048
   openssl rsa -in mux_signing_key.pem -pubout -out mux_signing_key.pub
   ```

2. **Register public key with Mux** (via API or dashboard):
   ```bash
   curl -X POST https://api.mux.com/video/v1/signing-keys \
     -u ${MUX_TOKEN_ID}:${MUX_TOKEN_SECRET} \
     -H "Content-Type: application/json" \
     -d @- <<EOF
   {
     "public_key": "$(cat mux_signing_key.pub)"
   }
   EOF
   ```

3. **Store private key in Infisical**:
   ```bash
   infisical secrets set MEREKA_LMS_MUX_SIGNING_PRIVATE_KEY \
     --value "$(cat mux_signing_key.pem)" \
     --domain https://secrets.mereka.io/api --env prod --path /
   ```

4. **Sync to GCP Secret Manager and ExternalSecrets** (see `specs/secrets-management.md`)

## Celery Tasks

### Daily Token Cleanup

```python
from openedx_video_protection.tasks import cleanup_expired_tokens_task

# Delete expired tokens older than 7 days
cleanup_expired_tokens_task.delay(7)
```

**Schedule**: Daily at 01:00 UTC via Celery Beat

**Celery Beat Configuration**:
```python
CELERYBEAT_SCHEDULE = {
    'cleanup-expired-tokens': {
        'task': 'openedx_video_protection.tasks.cleanup_expired_tokens_task',
        'schedule': crontab(hour=1, minute=0),  # 01:00 UTC daily
        'args': (7,),  # Keep for 7 days after expiry
    },
}
```

### Weekly Access Log Cleanup

```python
from openedx_video_protection.tasks import cleanup_old_access_logs_task

# Delete access logs older than 90 days
cleanup_old_access_logs_task.delay(90)
```

**Schedule**: Weekly on Sunday at 03:00 UTC

## Video XBlock Integration

Frontend code to request signed URLs for restricted courses:

```javascript
// Video XBlock client-side integration
async function getSignedPlaybackUrl(playbackId, courseKey) {
  const response = await fetch('/api/mux/protection/signed-url/', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      playback_id: playbackId,
      course_key: courseKey,
      expiry_hours: 12,
    }),
  });

  if (!response.ok) {
    if (response.status === 403) {
      throw new Error('You must be enrolled to watch this video');
    }
    throw new Error('Failed to get video URL');
  }

  const data = await response.json();
  return data.url;  // Use this signed URL in video player
}

// Example: Load signed URL into player
const signedUrl = await getSignedPlaybackUrl('abcd1234', courseKey);
videoPlayer.src = signedUrl;
```

## Security

- **RSA 2048-bit signing**: Industry-standard asymmetric encryption
- **Private key storage**: Infisical → GCP SM → ExternalSecrets (never in code)
- **Enrollment verification**: Server-side check before token generation
- **Domain restriction**: Playback limited to production URLs (`academyv2.mereka.io`)
- **Rate limiting**: 100 requests/hour/user to prevent abuse
- **IP hashing**: SHA-256 hash (truncated to 16 chars) for privacy
- **Audit trail**: Full logging of access attempts (granted/denied)

### Token Expiry

- **Default**: 12 hours
- **Configurable**: 1-72 hours via API request
- **Trade-offs**:
  - Shorter = More secure (less window for URL sharing)
  - Longer = Better UX (fewer re-authentications during long viewing sessions)
  - 12h balances security and UX for typical learning sessions

### Signing Key Rotation

1. Generate new RSA key pair
2. Register new public key with Mux API
3. Update `MUX_SIGNING_KEY_ID` and `MUX_SIGNING_PRIVATE_KEY` in ExternalSecrets
4. Wait 24h for old tokens to expire
5. Deactivate old signing key in Mux dashboard

## Privacy & Data Minimization

- **IP Addresses**: Hashed (SHA-256, truncated to 16 chars), not plaintext
- **User Agent**: Truncated to 500 chars
- **Token Retention**: 7 days after expiry (audit trail)
- **Access Logs**: 90 days retention, then auto-deleted
- **No PII in Logs**: Only hashed IP, no email/name

## Observability

**Metrics** (Prometheus):
- `mux_signed_tokens_generated_total` - Total signed tokens generated
- `mux_signed_token_denied_total{reason}` - Access denials by reason
- `mux_signed_token_rate_limited_total` - Rate limit hits

**Logs**:
- Token generation: `INFO` level with user, video_id, expiry
- Access denial: `WARNING` level with reason (not_enrolled, feature_disabled, rate_limited)
- Errors: `ERROR` level with full traceback

**Alerts**:
- Alert when `mux_signed_token_denied_rate > 20%` (possible abuse)
- Alert when token generation fails (signing key issue)

## Testing

### Unit Tests

```bash
pytest infrastructure/tutor/custom-apps/openedx_video_protection/tests/
```

### Manual Testing

```bash
# 1. Generate signed URL (enrolled user)
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "playback_id": "abcd1234",
    "course_key": "course-v1:Test+101+2024",
    "expiry_hours": 12
  }' \
  https://academyv2.mereka.io/api/mux/protection/signed-url/

# 2. Verify token in JWT.io (decode only, no verification)
# Copy token from response, paste into https://jwt.io/

# 3. Test unenrolled user (should return 403)
curl -X POST -H "Authorization: Bearer <unenrolled-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "playback_id": "abcd1234",
    "course_key": "course-v1:Test+101+2024"
  }' \
  https://academyv2.mereka.io/api/mux/protection/signed-url/

# 4. Verify in admin
# https://academyv2.mereka.io/admin/openedx_video_protection/signedplaybacktoken/
```

## Dependencies

- Django ≥3.2
- Django REST Framework ≥3.14
- PyJWT ≥2.8.0
- cryptography ≥41.0.0
- opaque-keys (for CourseKey)

## Future Enhancements (Post Phase 5)

- DRM integration (Widevine/FairPlay) for premium courses
- Per-video watermarking with user info
- Geographic playback restrictions
- Offline download with protection
- Session binding (tie token to specific device/browser)
- Real-time revocation via Redis blacklist

## Troubleshooting

### "MUX_SIGNING_KEY_ID not configured"

**Cause**: Signing credentials not set in environment variables.

**Fix**:
1. Check ExternalSecret is synced: `kubectl get secret mux-signing-key -n mereka-lms`
2. Verify environment variables in LMS pod: `kubectl exec -n mereka-lms deploy/lms -- env | grep MUX_SIGNING`
3. Check Infisical has `MEREKA_LMS_MUX_SIGNING_KEY_ID` and `MEREKA_LMS_MUX_SIGNING_PRIVATE_KEY`

### "Access denied: not enrolled"

**Cause**: User is not enrolled in the course.

**Fix**: Enroll user via Django admin or LMS enrollment API.

### "Rate limit exceeded"

**Cause**: User has generated >100 tokens in the last hour.

**Fix**: Wait for rate limit window to reset (1 hour) or contact administrator to clear rate limit.

### Token expires too quickly

**Cause**: Default 12h expiry may be too short for some use cases.

**Fix**: Increase `expiry_hours` in API request (max: 72h) or adjust default in code.
