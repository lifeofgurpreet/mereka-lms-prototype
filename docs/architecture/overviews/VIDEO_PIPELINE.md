# Video Pipeline & Delivery Architecture
_Audience: Engineering + Architecture • Last updated: 2026-02-24_

## System Overview

The video pipeline delivers 503 migrated MCT video lessons to 69,000+ enrolled learners across
Southeast Asia using Mux as the primary hosting and transcoding provider. Videos are served as
adaptive bitrate HLS streams via Mux's global CDN, rendered through the Open edX Video XBlock,
and tracked through the xAPI analytics pipeline.

**Key differentiator**: Zero-configuration global CDN delivery with just-in-time transcoding, all
within Mux's free tier at current scale (30,000 delivery minutes/month vs. 100,000 free). Annual
cost stays below $50 for the full 1,290-minute catalog.

**Spec**: `specs/video-pipeline-delivery_spec.md` (38 ACs)

---

## Component Diagram

```
┌───────────────────────────────────────────────────────────────────────┐
│                         Content Authors                               │
│  - Studio upload (Phase 3)          - MCT migration batch upload     │
└────────────────────────┬──────────────────────────────────────────────┘
                         │ HTTP/HTTPS (MP4 URL or direct upload)
                         ▼
┌───────────────────────────────────────────────────────────────────────┐
│                   openedx_mux_upload (Django app)                     │
│   - upload_videos_to_mux.py     - Mux direct upload URL generation   │
│   - Batch upload with resume    - Webhook signature verification      │
│   - mux_upload_complete.json    - Rate-limit: 1 req/sec              │
└────────────────────────┬──────────────────────────────────────────────┘
                         │ Mux API (mux.com/v1/assets)
                         ▼
┌───────────────────────────────────────────────────────────────────────┐
│                         Mux Platform                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────────────┐ │
│  │   Asset Storage │  │   Transcoding   │  │    Mux Data (QoS)     │ │
│  │   Basic Quality │  │  JIT: 240p/     │  │  Rebuffer ratio,      │ │
│  │   Cold at 90d   │  │  480p/720p HLS  │  │  TTFF, startup time   │ │
│  └────────┬────────┘  └────────┬────────┘  └───────────────────────┘ │
│           │                    │ asset.ready webhook                   │
│           ▼                    ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │               Mux Global CDN                                    │  │
│  │   stream.mux.com/{PLAYBACK_ID}.m3u8  (HLS manifest)            │  │
│  │   image.mux.com/{PLAYBACK_ID}/thumbnail.jpg  (poster)          │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────┬───────────────────────────────────────┘
                                │ HLS (443/HTTPS)
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                    Open edX LMS (mereka-lms namespace)                │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │  Video XBlock (HTML5 player with HLS.js)                        │  │
│  │  - source: stream.mux.com/{PLAYBACK_ID}.m3u8                    │  │
│  │  - poster: image.mux.com/{PLAYBACK_ID}/thumbnail.jpg            │  │
│  │  - download_video: false                                        │  │
│  │  - show_captions: true (when subtitle tracks exist)             │  │
│  └────────────────────────────┬────────────────────────────────────┘  │
│                               │ xAPI events                            │
│                               ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │  openedx_video_analytics (xAPI emitter)                         │  │
│  │  - played / paused / seeked / completed events                  │  │
│  │  - No PII (no email, no IP address)                             │  │
│  └────────────────────────────┬────────────────────────────────────┘  │
└───────────────────────────────┼───────────────────────────────────────┘
                                │ event-tracking → Aspects
                                ▼
┌───────────────────────────────────────────────────────────────────────┐
│              Aspects Analytics Pipeline (ClickHouse)                  │
│   - xAPI video events stored per learner per video                    │
│   - Superset dashboard: play rate, completion %, drop-off heatmaps   │
└───────────────────────────────────────────────────────────────────────┘

Observability path:
┌───────────────────────────────────────────────────────────────────────┐
│  mux-delivery-monitor (K8s Deployment, mereka-lms namespace)          │
│   - Polls Mux API every 6h → exposes /metrics (port 8000)            │
│   - video_delivery_minutes_monthly, video_transcode_success_rate      │
│   → ServiceMonitor → Prometheus → PrometheusRule alerts               │
│   → MuxDeliveryMinutesWarning (80K), MuxDeliveryMinutesCritical (95K) │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Upload Workflow

### MCT Batch Upload (Completed)

The 503 MCT videos were bulk-uploaded via `scripts/migrations/mct/upload_videos_to_mux.py`:

1. Script reads a list of video source URLs from MCT export data
2. For each video, it checks Mux for an existing asset with `passthrough=mct_lesson_id:{id}` (idempotency)
3. If no asset exists, it calls `POST /v1/assets` with the source URL (server-to-server ingestion)
4. Mux fetches the video from the URL, transcodes asynchronously, and returns `asset_id` + `playback_id`
5. Results are checkpointed to `exports/mct/mux_upload_complete.json` every 10 videos (resume support)
6. The mapping `mct_lesson_id → mux_asset_id, mux_playback_id` is stored in `exports/mct/video_mapping_openedx.json`
7. Course packages are rebuilt via `scripts/migrations/mct/build_courses_with_mux.py` with Video XBlocks referencing the Mux playback IDs

Rate limiting: 1 request/second (Mux allows 5/s; conservative margin for bulk ops).

### Studio Upload (Phase 3 — Not Yet Deployed)

For new content from course authors:

1. Author selects "Upload Video" in Studio
2. LMS calls `openedx_mux_upload` to create a Mux direct upload URL (`POST /v1/direct-uploads`)
3. Studio receives the pre-signed URL and streams the file directly from the browser to Mux
4. Mux webhook `video.asset.ready` fires when transcoding completes
5. LMS updates the Video XBlock with the new `playback_id`

---

## Video XBlock Configuration

The `openedx_video_pipeline.xblock_config` module generates XBlock configuration:

```python
# Key constants
MUX_STREAM_BASE = os.environ.get('MUX_PLAYBACK_BASE_URL', 'https://stream.mux.com')
MUX_IMAGE_BASE  = 'https://image.mux.com'

# HLS URL format
hls_url    = f'{MUX_STREAM_BASE}/{playback_id}.m3u8'
poster_url = f'{MUX_IMAGE_BASE}/{playback_id}/thumbnail.jpg?width=1280&height=720'
```

OLX structure for a video unit:

```xml
<video display_name="Intro to Python - Variables"
       download_video="false"
       show_captions="true"
       sub="en">
    <source src="https://stream.mux.com/{PLAYBACK_ID}.m3u8" />
    <poster src="https://image.mux.com/{PLAYBACK_ID}/thumbnail.jpg?width=1280&height=720" />
    <transcript language="en" label="English" src="https://..." />
</video>
```

**Critical rules**:
- `download_video` is always `false` (AC-VPD: no direct download)
- `show_captions` is `true` whenever subtitle tracks exist
- Only `playback_id` is embedded in HTML — never `asset_id` or API credentials (AC-VPD-013)
- No iframe embedding; native HLS XBlock support is used instead

---

## Signed URL Support (Content Protection — Phase 5)

For restricted/paid courses, the video pipeline supports Mux signed playback tokens:

| Setting | Value |
|---------|-------|
| Playback policy | `signed` (restricted) or `public` (open courses) |
| Token expiry | 12 hours (configurable) |
| Token scope | `playback_id` only, generated server-side |
| Endpoint | `GET /api/video/playback-token/<playback_id>/` |
| Domain restriction | `MUX_ENABLE_DOMAIN_RESTRICTION=true` → allow only `academyv2.mereka.io` and `academy.biji-biji.com` |

Token generation is handled by `openedx_video_protection`. Signed tokens are JWTs with an `exp`
claim. Key rotation runs at least every 12 months with a 24-hour dual-key overlap period to
prevent breaking active sessions.

Currently `ENABLE_MUX_SIGNED_PLAYBACK` defaults to `False` (all courses use public playback).

---

## Analytics Events

The `openedx_video_analytics` app and `openedx_video_pipeline.xapi_emitter` emit xAPI events:

| Event | Trigger | Fields |
|-------|---------|--------|
| `played` | User presses play | `video_id`, `course_id`, `timestamp`, `progress_pct` |
| `paused` | User pauses | `video_id`, `course_id`, `timestamp`, `progress_pct` |
| `seeked` | User seeks to position | `video_id`, `course_id`, `from_pct`, `to_pct` |
| `completed` | Player reaches end | `video_id`, `course_id`, `total_watch_seconds` |

Events flow via Open edX event-tracking → Aspects pipeline → ClickHouse. PII is never collected:
no email addresses or IP addresses in video analytics events.

Completion percentage is persisted per learner per video in the Open edX progress tracking system
(`StudentModule` model) to support resume playback and course completion requirements.

---

## Subtitle Management

Subtitle tracks are managed per Mux asset:

- **Supported formats**: SRT, VTT
- **Required**: English (`en`) for all content
- **Target languages**: Vietnamese (`vi`), Chinese (`zh`) for localized courses
- **Fallback**: When `srclang` is empty, language defaults to `en`

Subtitles are uploaded to Mux via `POST /v1/assets/{ASSET_ID}/text-tracks` and referenced in
OLX via `<transcript>` elements. The `show_captions` attribute on the Video XBlock is set to
`true` only when subtitle tracks exist for that asset.

---

## Monitoring and Alerting

Alerting is wired in `deploy/k8s/base/monitoring/` (T026, `verify-mux-alert-wiring.sh`).

### Prometheus Metrics (mux-delivery-monitor)

The `mux-delivery-monitor` Deployment polls the Mux API every 6 hours and exposes metrics at
`:8000/metrics`. It is scraped by Prometheus via the `ServiceMonitor/mux-delivery-monitor`.

| Metric | Type | Description |
|--------|------|-------------|
| `video_delivery_minutes_monthly` | gauge | Current month delivery minutes from Mux API |
| `video_transcode_success_rate` | gauge | % of assets reaching "ready" status (24h window) |
| `mux_asset_processing_queue_depth` | gauge | Assets currently in "preparing" state |
| `video_upload_total` | counter | Total uploads, labeled by `status` |
| `video_upload_duration_seconds` | histogram | Time from upload to "ready" status |

### Alert Rules (PrometheusRule/video-alerts)

| Alert | Condition | Severity |
|-------|-----------|----------|
| `MuxDeliveryMinutesWarning` | `video_delivery_minutes_monthly > 80000` | warning |
| `MuxDeliveryMinutesCritical` | `video_delivery_minutes_monthly > 95000` | critical |
| `MuxTranscodeSuccessRateLow` | `video_transcode_success_rate < 0.95` for 6h | warning |
| `MuxErroredAssetsGrowing` | Errored asset count increasing | warning |
| `MuxExporterDown` | mux-delivery-monitor pod not scraping | critical |
| `MuxPollStale` | metrics not updated in >7h | warning |

### Verification Scripts

| Script | Covers | Notes |
|--------|--------|-------|
| `scripts/qa/verify-video-pipeline.sh` | AC-VPD-001..025 | Upload, playback, subtitles, secrets, migration |
| `scripts/qa/verify-mux-alert-wiring.sh` | AC-VPD-019,020,029,030 | PrometheusRule, ServiceMonitor, exporter wiring |
| `scripts/qa/verify-video-observability.sh` | AC-VPD-015..021,026..030 | Grafana dashboards, cost metrics |
| `scripts/qa/verify-video-content-protection.sh` | AC-VPD-031..038 | Signed URLs, domain restriction, edge cases |

---

## Secret Management

Mux credentials flow through the standard secrets pipeline:

```
Infisical (source of truth)
  MEREKA_LMS_MUX_TOKEN_ID
  MEREKA_LMS_MUX_TOKEN_SECRET
  MEREKA_LMS_MUX_WEBHOOK_SECRET
         │
         ▼ (ExternalSecrets, sync every 1h)
GCP Secret Manager (bbi-k8 project)
         │
         ▼
K8s Secret: openedx-secrets (mereka-lms namespace)
  MUX_TOKEN_ID
  MUX_TOKEN_SECRET
         │
         ├──▶ LMS pod (Django app env vars)
         └──▶ mux-delivery-monitor pod (Mux API polling)
```

Credentials are never hardcoded. The pre-commit hook (`scripts/qa/scan-mux-credentials.sh`)
scans for accidental credential leakage. The `verify-mux-secrets.sh` script verifies the
ExternalSecret mapping is complete.

---

## Cost Model

At current scale (1,290 video-minutes, ~10,000 monthly views):

| Item | Calculation | Monthly Cost |
|------|-------------|--------------|
| Storage (base) | 1,290 min × $0.007/min | $9.03 |
| Storage (90d cold, 60% discount) | $9.03 × 0.40 | **$3.61** |
| Delivery (30,000 min/mo) | Within 100K free tier | **$0.00** |
| Encoding | Mux Basic Quality, included | **$0.00** |
| **Total** | | **~$3.61/mo** |

Annual cost: ~$43/year (well within $50/year target).

**Scale trigger**: If monthly views consistently exceed 100,000 for 3 consecutive months, a GCS +
Cloudflare CDN fallback path evaluation is required. The provider abstraction layer in
`openedx_video_pipeline` is designed to accommodate this migration.

---

## Graceful Degradation

The pipeline is designed so Mux outages do not break the LMS:

1. **Mux asset in "errored" state**: Video XBlock renders a poster image with "Video temporarily
   unavailable" message instead of a broken player
2. **Mux API unreachable**: LMS page loads fully — video content is embedded as static HLS URLs
   with no runtime API dependency for playback
3. **HLS manifest timeout** (>5s): Client-side retry with exponential backoff (1s, 2s, 4s);
   after 3 failed attempts the "Video unavailable" fallback is shown

---

## Key Files

| File | Purpose |
|------|---------|
| `infrastructure/tutor/custom-apps/openedx_mux_upload/` | Django app: upload, webhooks |
| `infrastructure/tutor/custom-apps/openedx_video_pipeline/xblock_config.py` | XBlock config helper |
| `infrastructure/tutor/custom-apps/openedx_video_pipeline/xapi_emitter.py` | xAPI event emission |
| `infrastructure/tutor/custom-apps/openedx_video_analytics/` | Video analytics models and API |
| `infrastructure/tutor/custom-apps/openedx_video_protection/` | Signed URL generation |
| `scripts/migrations/mct/upload_videos_to_mux.py` | MCT batch upload script |
| `scripts/migrations/mct/build_courses_with_mux.py` | OLX course package builder |
| `deploy/k8s/base/monitoring/mux-exporter.yaml` | mux-delivery-monitor Deployment + Service |
| `deploy/k8s/base/monitoring/servicemonitor-mux.yaml` | Prometheus ServiceMonitor |
| `deploy/k8s/base/monitoring/prometheusrule-video.yaml` | Alert rules |
| `deploy/k8s/base/secrets/external-secrets.yaml` | MUX_TOKEN_ID/SECRET ExternalSecret mapping |
| `exports/mct/mux_upload_complete.json` | Upload results (503 MCT videos, migration workstation) |
| `exports/mct/video_mapping_openedx.json` | mct_lesson_id → playback_id mapping |

---

## Related Documentation

- Spec: `specs/video-pipeline-delivery_spec.md`
- Implementation plan: `specs/plans/video-pipeline-delivery_plan.md`
- Test plan: `specs/plans/video-pipeline-delivery_testplan.md`
- Cost comparison: `VIDEO_HOSTING_COST_COMPARISON.md`
- MCT migration status: `docs/status/migrations/MCT_MIGRATION_STATUS.md`
- Alert wiring (T026): `scripts/qa/verify-mux-alert-wiring.sh`
