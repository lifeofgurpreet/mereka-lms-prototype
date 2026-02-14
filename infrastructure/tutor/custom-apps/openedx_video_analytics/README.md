# Open edX Video Analytics

Django app for tracking and aggregating video playback analytics (Phase 4).

## Purpose

This app provides video engagement analytics for Mereka Academy Open edX, enabling:

1. **Client-side Event Tracking**: Video XBlock emits playback events (played, paused, seeked, completed)
2. **Event Storage**: Events stored in VideoPlaybackEvent model
3. **Daily Aggregation**: Celery task rolls up raw events into VideoAnalyticsSummary
4. **Instructor Dashboard**: REST API for retrieving video analytics (completion rates, watch time, etc.)
5. **Privacy-First**: IP addresses hashed, PII minimized

## Specification

- **Spec**: `specs/video-pipeline-delivery_spec.md` (Phase 4: Analytics Integration)
- **Bead**: `mereka-lms-17jr`
- **Rollout Week**: 6-8

## Installation

```bash
cd infrastructure/tutor/custom-apps/openedx_video_analytics
pip install -e .
```

## Configuration

Add to `INSTALLED_APPS` in LMS settings:

```python
INSTALLED_APPS += [
    'openedx_video_analytics',
]
```

Add to URL configuration (LMS):

```python
urlpatterns += [
    path('api/video/v1/', include('openedx_video_analytics.urls')),
]
```

Enable feature flag:

```python
ENABLE_VIDEO_ANALYTICS = True
```

## Database Schema

### VideoPlaybackEvent Model (Raw Events)

| Field | Type | Description |
|-------|------|-------------|
| `user` | ForeignKey | Learner who triggered the event |
| `course_key` | CourseKeyField | Course containing the video |
| `video_id` | CharField(255) | Video identifier (playback_id or usage_key) |
| `event_type` | CharField(20) | played, paused, seeked, completed, ended |
| `position` | FloatField | Playback position in seconds |
| `duration` | FloatField | Total video duration (if known) |
| `timestamp` | DateTimeField | When event occurred (UTC) |
| `org_slug` | CharField(100) | Organization slug for multi-tenant analytics |
| `session_id` | CharField(100) | Session identifier for grouping events |
| `user_agent` | CharField(500) | Client user agent |
| `ip_address_hash` | CharField(64) | SHA-256 hash of IP (not plaintext) |

**Indexes**:
- `(user, timestamp)`
- `(course_key, video_id, timestamp)`
- `(event_type, timestamp)`
- `(org_slug, timestamp)`

### VideoAnalyticsSummary Model (Aggregated Daily)

| Field | Type | Description |
|-------|------|-------------|
| `course_key` | CourseKeyField | Course containing the video |
| `video_id` | CharField(255) | Video identifier |
| `org_slug` | CharField(100) | Organization slug |
| `date` | DateField | Analytics date (UTC) |
| `play_count` | IntegerField | Number of play events |
| `unique_viewers` | IntegerField | Number of unique users who played |
| `completion_count` | IntegerField | Users who completed (90%+) |
| `completion_rate` | FloatField | Completion rate (0.0 - 1.0) |
| `avg_watch_time` | FloatField | Average watch duration per user (seconds) |
| `total_watch_time` | FloatField | Total watch time across all users (seconds) |
| `avg_position_reached` | FloatField | Average furthest position reached (seconds) |

**Unique constraint**: `(course_key, video_id, date)`

## API Endpoints

### Record Video Playback Event

```http
POST /api/video/v1/events/
Authorization: Bearer <token>
Content-Type: application/json

{
  "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
  "video_id": "abcd1234efgh5678",
  "event_type": "played",
  "position": 10.5,
  "duration": 300.0,
  "session_id": "session-uuid"
}
```

**Response** (201 Created):
```json
{
  "id": 42,
  "user": 123,
  "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
  "video_id": "abcd1234efgh5678",
  "event_type": "played",
  "position": 10.5,
  "duration": 300.0,
  "timestamp": "2026-02-14T12:00:00Z",
  "org_slug": "MerekaAcademy",
  "session_id": "session-uuid"
}
```

**Event Types**:
- `played`: Video started or resumed
- `paused`: Video paused by user
- `seeked`: User jumped to different position
- `completed`: User reached 90%+ of video
- `ended`: Video reached the end

### Get Video Analytics

```http
GET /api/video/v1/analytics/?course_key=...&video_id=...&start_date=2026-02-01&end_date=2026-02-14
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "count": 5,
  "results": [
    {
      "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
      "video_id": "abcd1234",
      "org_slug": "MerekaAcademy",
      "date": "2026-02-14",
      "play_count": 150,
      "unique_viewers": 75,
      "completion_count": 60,
      "completion_rate": 0.8,
      "completion_rate_percent": 80.0,
      "avg_watch_time": 245.5,
      "total_watch_time": 18412.5,
      "avg_position_reached": 270.2
    }
  ]
}
```

**Query Parameters**:
- `course_key` (optional): Filter by course
- `video_id` (optional): Filter by video
- `start_date` (optional): Filter from date (YYYY-MM-DD)
- `end_date` (optional): Filter to date (YYYY-MM-DD), defaults to last 30 days
- `org_slug` (optional): Filter by organization

**Permissions**:
- Instructors can view analytics for their courses
- Admins can view analytics for all courses

## Celery Tasks

### Daily Aggregation (Scheduled)

```python
from openedx_video_analytics.tasks import aggregate_video_analytics_daily

# Aggregate yesterday's events (automatic)
aggregate_video_analytics_daily.delay()

# Aggregate specific date
aggregate_video_analytics_daily.delay('2026-02-14')
```

**Schedule**: Daily at 00:30 UTC via Celery Beat

**Celery Beat Configuration**:
```python
CELERYBEAT_SCHEDULE = {
    'aggregate-video-analytics-daily': {
        'task': 'openedx_video_analytics.tasks.aggregate_video_analytics_daily',
        'schedule': crontab(hour=0, minute=30),  # 00:30 UTC daily
    },
}
```

### Cleanup Old Events (Scheduled)

```python
from openedx_video_analytics.tasks import cleanup_old_video_events

# Delete events older than 90 days
cleanup_old_video_events.delay(90)
```

**Schedule**: Weekly on Sunday at 02:00 UTC

**Retention Policy**:
- Raw events: 90 days (configurable)
- Aggregated summaries: Indefinite

### Backfill Analytics

```python
from openedx_video_analytics.tasks import backfill_video_analytics

# Backfill January 2026
backfill_video_analytics.delay('2026-01-01', '2026-01-31')
```

**Usage**:
- Initial data migration
- Fixing missing summaries
- Re-aggregating after schema changes

## Video XBlock Integration

To emit events from the Video XBlock, add JavaScript event listeners:

```javascript
// Video XBlock client-side integration
const videoElement = document.querySelector('video');
const sessionId = generateSessionId();  // Generate unique session ID

// Helper function to record event
function recordVideoEvent(eventType, position) {
  fetch('/api/video/v1/events/', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${authToken}`,
    },
    body: JSON.stringify({
      course_key: courseKey,
      video_id: videoId,
      event_type: eventType,
      position: position,
      duration: videoElement.duration,
      session_id: sessionId,
    }),
  });
}

// Event listeners
videoElement.addEventListener('play', () => {
  recordVideoEvent('played', videoElement.currentTime);
});

videoElement.addEventListener('pause', () => {
  recordVideoEvent('paused', videoElement.currentTime);
});

videoElement.addEventListener('seeked', () => {
  recordVideoEvent('seeked', videoElement.currentTime);
});

videoElement.addEventListener('ended', () => {
  recordVideoEvent('ended', videoElement.currentTime);
});

// Completion detection (90%)
videoElement.addEventListener('timeupdate', () => {
  const completionThreshold = 0.9;
  if (videoElement.currentTime / videoElement.duration >= completionThreshold && !completed) {
    recordVideoEvent('completed', videoElement.currentTime);
    completed = true;
  }
});
```

## Privacy & Data Minimization

- **IP Addresses**: Hashed (SHA-256) before storage, not plaintext
- **User Agent**: Truncated to 500 chars
- **Session IDs**: Client-generated UUIDs, not server-side identifiers
- **Raw Events**: Retained for 90 days, then deleted
- **Aggregated Summaries**: No PII, safe for long-term retention

## Observability

**Metrics** (Prometheus):
- `video_events_total{event_type}` - Total events recorded
- `video_event_recording_errors_total` - Event recording failures
- `video_analytics_aggregation_duration_seconds` - Daily aggregation runtime

**Logs**:
- Event recording: `INFO` level with user, video_id, event_type, position
- Aggregation: `INFO` level with date, summaries_created, events_processed
- Errors: `ERROR` level with full traceback

**Alerts**:
- Alert when daily aggregation fails
- Alert when event recording error rate > 5%

## Testing

### Unit Tests

```bash
pytest infrastructure/tutor/custom-apps/openedx_video_analytics/tests/
```

### Manual Testing

```bash
# 1. Record a video event
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "course_key": "course-v1:Test+101+2024",
    "video_id": "test-video-123",
    "event_type": "played",
    "position": 10.5,
    "duration": 300.0
  }' \
  https://academyv2.mereka.io/api/video/v1/events/

# 2. Trigger daily aggregation
kubectl exec -it deployment/lms-worker -n mereka-lms -- python manage.py shell -c \
  "from openedx_video_analytics.tasks import aggregate_video_analytics_daily; \
   aggregate_video_analytics_daily.delay()"

# 3. Query analytics
curl -H "Authorization: Bearer <token>" \
  "https://academyv2.mereka.io/api/video/v1/analytics/?course_key=course-v1:Test+101+2024&start_date=2026-02-01&end_date=2026-02-14"

# 4. Verify in admin
# https://academyv2.mereka.io/admin/openedx_video_analytics/videoplaybackevent/
```

## Dependencies

- Django ≥3.2
- Django REST Framework ≥3.14
- Celery ≥5.2.0
- opaque-keys (for CourseKey)

## Future Enhancements (Post Phase 4)

- Real-time analytics via websockets
- Drop-off heatmaps (time-series analysis)
- Per-student analytics (GDPR-compliant)
- A/B testing for video content
- Integration with Mux Data for QoS metrics
- Export to ClickHouse for advanced analytics
- Superset dashboards for instructors
