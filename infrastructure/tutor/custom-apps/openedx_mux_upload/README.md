# Open edX Mux Video Upload Integration

Django app for Mux-powered video upload workflow in Open edX Studio (Phase 3).

## Purpose

This app enables course authors to upload videos directly from Studio using Mux direct uploads. Videos are automatically transcoded to HLS adaptive bitrate streams and delivered via Mux's global CDN.

## Specification

- **Spec**: `specs/video-pipeline-delivery_spec.md` (Phase 3: Studio Upload Workflow)
- **Acceptance Criteria**: AC-VPD-003, AC-VPD-004, AC-VPD-005
- **Rollout Week**: 4-6

## Installation

```bash
cd infrastructure/tutor/custom-apps/openedx_mux_upload
pip install -e .
```

## Configuration

Add to `INSTALLED_APPS` in LMS settings:

```python
INSTALLED_APPS += [
    'openedx_mux_upload',
]
```

Add to URL configuration (LMS):

```python
urlpatterns += [
    path('api/mux/upload/', include('openedx_mux_upload.urls')),
]
```

Enable feature flag:

```python
ENABLE_MUX_STUDIO_UPLOAD = True
```

Set Mux API credentials (synced from Infisical):

```python
MUX_TOKEN_ID = os.environ.get('MUX_TOKEN_ID')
MUX_TOKEN_SECRET = os.environ.get('MUX_TOKEN_SECRET')
MUX_WEBHOOK_SECRET = os.environ.get('MUX_WEBHOOK_SECRET', '')  # Optional
```

## Database Schema

### MuxUpload Model

| Field | Type | Description |
|-------|------|-------------|
| `user` | ForeignKey | Course author who initiated upload |
| `course_key` | CourseKeyField | Course where video will be used |
| `upload_id` | CharField(255) | Mux direct upload ID (unique) |
| `asset_id` | CharField(255) | Mux asset ID (populated after upload) |
| `playback_id` | CharField(255) | Mux playback ID for HLS streaming |
| `status` | CharField(20) | Upload status (pending, uploading, processing, ready, errored) |
| `error_message` | TextField | Error details if status=errored |
| `filename` | CharField(255) | Original filename |
| `filesize_bytes` | BigIntegerField | File size in bytes |
| `video_title` | CharField(255) | Video title for display |
| `created_at` | DateTimeField | When upload was initiated |
| `updated_at` | DateTimeField | Last status update |
| `completed_at` | DateTimeField | When upload reached ready or errored |
| `webhook_payload` | JSONField | Last webhook payload (debugging) |

**Indexes**:
- `(user, course_key)`
- `(status, created_at)`
- `upload_id` (unique)
- `asset_id`

## API Endpoints

### Create Direct Upload

```http
POST /api/mux/upload/create/
Authorization: Bearer <token>
Content-Type: application/json

{
  "course_key": "course-v1:MerekaAcademy+COURSE101+2024",
  "filename": "lesson-1-intro.mp4",
  "filesize_bytes": 52428800,
  "video_title": "Lesson 1: Introduction"
}
```

**Response** (200 OK):
```json
{
  "upload_id": "abcd1234",
  "upload_url": "https://storage.googleapis.com/...",
  "timeout": 172800,
  "mux_upload_id": 42
}
```

**Performance Target**: <= 2 seconds (AC-VPD-003)

**Usage**:
1. Studio frontend calls this endpoint to get upload URL
2. Browser uploads video directly to Mux using `upload_url`
3. Mux processes video and sends webhook when ready
4. Studio polls `/api/mux/upload/{upload_id}/status/` for completion

### Get Upload Status

```http
GET /api/mux/upload/{upload_id}/status/
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "id": 42,
  "upload_id": "abcd1234",
  "status": "ready",
  "asset_id": "xyz789",
  "playback_id": "efg456",
  "filename": "lesson-1-intro.mp4",
  "video_title": "Lesson 1: Introduction",
  "created_at": "2026-02-14T10:00:00Z",
  "completed_at": "2026-02-14T10:05:00Z"
}
```

### List Uploads

```http
GET /api/mux/upload/list/?course_key=...&status=...
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "count": 10,
  "results": [...]
}
```

### Mux Webhook Handler

```http
POST /api/mux/upload/webhook/
Mux-Signature: t=1234567890,v1=abc123...

{
  "type": "video.asset.ready",
  "data": {
    "id": "xyz789",
    "status": "ready",
    "playback_ids": [{"id": "efg456", "policy": "public"}]
  }
}
```

**Webhook Events**:
- `video.upload.asset_created`: Upload completed, asset created
- `video.asset.ready`: Video transcoding completed
- `video.asset.errored`: Video processing failed

**Webhook Configuration** (Mux Dashboard):
- URL: `https://academyv2.mereka.io/api/mux/upload/webhook/`
- Events: `video.upload.asset_created`, `video.asset.ready`, `video.asset.errored`

## Workflow

1. **Studio author initiates upload**:
   - Frontend: `POST /api/mux/upload/create/`
   - Backend: Creates `MuxUpload` record (status=pending)
   - Backend: Calls Mux API to generate direct upload URL
   - Response: `upload_url` returned to browser

2. **Browser uploads video**:
   - Frontend: `PUT {upload_url}` with video file
   - Mux: Receives file, creates asset
   - Mux: Sends webhook `video.upload.asset_created`
   - Backend: Updates `MuxUpload` (status=processing, asset_id set)

3. **Mux transcodes video**:
   - Mux: Generates HLS renditions (240p, 480p, 720p)
   - Mux: Sends webhook `video.asset.ready`
   - Backend: Updates `MuxUpload` (status=ready, playback_id set)

4. **Studio displays video**:
   - Frontend: Polls `GET /api/mux/upload/{upload_id}/status/`
   - Frontend: Shows "Processing..." until status=ready
   - Frontend: Inserts Video XBlock with `https://stream.mux.com/{playback_id}.m3u8`

## Video XBlock Integration

After upload completes (status=ready), insert Video XBlock in OLX:

```xml
<video
    url_name="lesson-1-intro"
    display_name="Lesson 1: Introduction"
    download_video="false"
    show_captions="true">
  <source src="https://stream.mux.com/efg456.m3u8"/>
  <transcript language="en" src="https://..."/>
</video>
```

**Poster Image**:
```
https://image.mux.com/{playback_id}/thumbnail.jpg
```

## Error Handling

### Upload Failures

If status=errored, check `error_message`:

```json
{
  "status": "errored",
  "error_message": "Unsupported codec: HEVC. Use H.264/AAC MP4."
}
```

**Common Errors**:
- Unsupported codec (HEVC, AV1) → Re-encode to H.264
- File too large (>5GB) → Use chunked upload (future enhancement)
- Upload timeout (48 hours) → Retry with new upload URL

### Graceful Degradation

If Mux API is unreachable:
- Return 503 Service Unavailable
- Log error for monitoring
- Display "Video upload temporarily unavailable" in Studio

## Security

- **Authentication**: All endpoints require `IsAuthenticated` except webhook (uses signature verification)
- **Authorization**: Users can only access their own uploads
- **Webhook Signature**: Optional but recommended (set `MUX_WEBHOOK_SECRET`)
- **CORS**: Direct uploads allow `*` origin (constrained by Mux)

## Observability

**Logs**:
- Upload creation: `INFO` level with user, course, upload_id
- Webhook events: `INFO` level with event type, asset_id
- Errors: `ERROR` level with full details

**Metrics** (future):
- `mux_upload_total{status}` - Upload count by status
- `mux_upload_duration_seconds` - Time from pending to ready
- `mux_webhook_events_total{type}` - Webhook event count

## Testing

### Unit Tests

```bash
pytest infrastructure/tutor/custom-apps/openedx_mux_upload/tests/
```

### Manual Testing

```bash
# 1. Create direct upload
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"course_key": "course-v1:Test+101+2024", "filename": "test.mp4"}' \
  https://academyv2.mereka.io/api/mux/upload/create/

# 2. Upload video to Mux
# (Use upload_url from response)

# 3. Check status
curl -H "Authorization: Bearer <token>" \
  https://academyv2.mereka.io/api/mux/upload/{upload_id}/status/

# 4. Verify in admin
# https://academyv2.mereka.io/admin/openedx_mux_upload/muxupload/
```

## Dependencies

- Django ≥3.2
- Django REST Framework ≥3.14
- requests ≥2.28.0
- PyJWT ≥2.6.0 (for webhook signature verification)
- opaque-keys (for CourseKey validation)

## Future Enhancements (Phase 4+)

- Chunked upload support for files >2GB
- Auto-caption generation via Mux
- Subtitle upload API
- Video replacement workflow
- Batch upload API
- Upload progress tracking (websocket/SSE)
- Video analytics integration (Mux Data)
