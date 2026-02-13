---
title: "Video Pipeline & Delivery System"
type: "feature_spec"
status: "in_progress"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-12"
implementation_note: "Mux integration being handled by separate agent"
depends_on:
  - "specs/repository-structure_spec.md"
  - "specs/k8s-deployment_spec.md"
  - "specs/secrets-management_spec.md"
links:
  related_docs:
    - "docs/VIDEO_HOSTING_COST_COMPARISON.md"
    - "docs/migrations/mct/MCT_MIGRATION_STATUS.md"
  related_specs:
    - "specs/k8s-deployment_spec.md"
    - "specs/observability-stack_spec.md"
    - "specs/secrets-management_spec.md"
    - "specs/analytics-pipeline_spec.md"
    - "specs/branding-system_spec.md"
    - "specs/cross-cutting-requirements_spec.md"
    - "specs/repository-structure_spec.md"
---

# Human Summary

## What we're building

A complete video hosting, transcoding, delivery, and analytics system for Mereka Academy's Open edX platform. The system uses Mux as the primary video provider, delivering adaptive bitrate streams via global CDN to learners across Southeast Asia. It covers the full lifecycle: author upload in Studio, automatic transcoding, HLS/DASH delivery through the Open edX Video XBlock, subtitle management, video analytics, mobile optimization, and content protection via signed URLs.

The system also includes migration tooling for the 503 MCT videos already uploaded to Mux, ensuring continuity with the completed MCT-to-Open-edX migration. Future growth beyond 100,000 monthly views triggers a cost-based re-evaluation of the GCS+CDN fallback path.

## Why it matters

Video is the primary content medium for Mereka Academy courses. The 30 courses migrated from MCT contain 503 video lessons that 69,000+ enrolled learners depend on. Without a formally specified video pipeline, the team risks: inconsistent playback quality across devices, uncontrolled storage costs, broken subtitles for multi-language content (EN/VN/ZH), no visibility into video engagement metrics, and no protection against content hotlinking or unauthorized distribution. The specification also prevents vendor lock-in by defining a provider-abstraction layer and clear scaling thresholds.

## Success looks like

- All 503 MCT videos stream via Mux HLS with adaptive bitrate and under 2-second time-to-first-frame on a 5 Mbps connection
- Annual video hosting cost stays below $50/year for the current catalog of 1,290 video-minutes at 10,000 monthly views
- Course authors can upload and publish new videos from Studio in under 5 minutes (wall-clock, excluding transcoding time)
- Video engagement data (play rate, completion rate, rebuffer ratio) flows into the Aspects analytics pipeline
- Mobile learners on the Open edX mobile apps can stream videos with adaptive quality down to 240p on 1 Mbps connections
- Subtitle tracks are available in at least English and Vietnamese for all courses with localized content

# Agent Contract

## Scope

- In scope:
  - Mux as the primary video hosting and transcoding provider (Basic Quality tier)
  - Video XBlock integration for HLS playback within Open edX LMS
  - Studio-side upload workflow for course authors (new video ingestion)
  - Adaptive bitrate streaming configuration (HLS with multiple renditions)
  - Global CDN delivery via Mux's built-in CDN
  - Signed URL generation for content protection
  - Subtitle/caption management (upload, auto-generation, multi-language)
  - Video analytics integration with the Aspects/ClickHouse pipeline
  - MCT video migration tooling (503 videos already uploaded, mapping maintenance)
  - Video storage lifecycle (cold storage discounts, retention policies)
  - Mobile video optimization (low-bandwidth renditions, poster images)
  - Mux API secret management via Infisical/ExternalSecrets
  - Provider abstraction layer for future migration to GCS+CDN if cost thresholds are exceeded

- Out of scope:
  - DRM (Widevine/FairPlay) -- not justified at current scale ($100/month add-on)
  - Live streaming / webinar functionality
  - Video editing or post-production tools within Studio
  - YouTube or Vimeo integration (existing Open edX built-in; not part of this pipeline)
  - Offline video download for mobile (deferred to mobile-apps-enterprise spec)
  - Video search / content-based indexing (AI-powered)
  - Cloudflare Stream integration (eliminated in cost analysis)

## Non-goals

- Building a custom video player. The system uses the Open edX Video XBlock with standard HLS.js.
- Supporting user-generated content uploads. Only course authors with Studio access can upload videos.
- Implementing real-time video collaboration or video conferencing features.
- Achieving sub-second latency. This is VOD, not live streaming.
- Transcoding to formats other than HLS (no DASH, no MP4 download unless Mux tier supports it).
- Replacing Mux before the 100,000 monthly views threshold is reached.

## Assumptions

- Mux Basic Quality tier remains available with free encoding and 100,000 free delivery minutes/month
- Average video length is 5 minutes (1,290 total minutes for 258 unique videos, 503 total including duplicates across courses)
- Average watch time per view is 60% of video duration (3 minutes)
- Current viewership is approximately 10,000 views/month (30,000 delivery minutes/month)
- The Open edX Video XBlock supports external HLS URLs via the `<source>` element
- Mux API credentials (MUX_TOKEN_ID, MUX_TOKEN_SECRET) are stored in Infisical
- Southeast Asia (Singapore region) is the primary viewer geography
- The Aspects analytics pipeline (see specs/analytics-pipeline_spec.md) is operational for event ingestion

## Requirements

### Functional

#### Video Ingestion & Upload

- The system MUST support video upload via the Mux API using direct URL ingestion (server-to-server, no client-side upload)
- The system MUST support video upload via Mux direct uploads for Studio-initiated uploads (pre-signed upload URLs for browser-based upload)
- The system MUST store the MCT-to-Mux mapping (mct_lesson_id -> mux_asset_id, mux_playback_id) in a persistent JSON file and as passthrough metadata on each Mux asset
- The system MUST accept MP4, MOV, MKV, and WebM input formats for new uploads
- The system SHOULD support batch upload with resume capability (tracking progress in a results JSON file)
- The system MUST validate that uploaded videos complete Mux processing (status transitions from "preparing" to "ready") before marking them available in courses
- The system MUST rate-limit API calls to Mux at no more than 1 request per second for bulk operations

#### Transcoding & Quality

- The system MUST use Mux Basic Quality tier for all educational video content
- The system MUST NOT request Plus or Premium quality tiers unless explicitly approved (cost control)
- The system MUST produce HLS adaptive bitrate streams with at least 3 renditions (240p, 480p, 720p)
- The system SHOULD rely on Mux's just-in-time encoding to create renditions only when viewers request them
- The system MUST generate thumbnail images for each video via the Mux Image API (`https://image.mux.com/{PLAYBACK_ID}/thumbnail.jpg`)
- The system SHOULD generate animated GIF previews for video hover states where the player supports it

#### Video Playback & XBlock Integration

- The system MUST deliver video content through the Open edX Video XBlock using HLS URLs in the format `https://stream.mux.com/{PLAYBACK_ID}.m3u8`
- The system MUST set the `download_video` attribute to `false` on all Video XBlocks (no direct download)
- The system MUST set poster images on Video XBlocks using Mux-generated thumbnails or GCS-hosted course thumbnails
- The system MUST set `show_captions` to `true` on all Video XBlocks where subtitle tracks exist
- The system SHOULD support the `<video>` XBlock's `start_time` and `end_time` attributes for segment playback
- The system MUST NOT embed videos via iframe when the Video XBlock's native HLS source support is available

#### Subtitle & Caption Management

- The system MUST support uploading SRT and VTT subtitle files as text tracks on Mux assets
- The system MUST support at least English (`en`) subtitle tracks for all video content
- The system SHOULD support Vietnamese (`vi`) and Chinese (`zh`) subtitle tracks for localized courses
- The system MUST default the `language_code` to `en` when the source subtitle has no language specified
- The system SHOULD integrate with an auto-transcription service for new uploads where no subtitle file is provided
- The system MAY support closed captions (CC) in addition to subtitles, with the `closed_captions` flag set appropriately

#### Content Protection & Access Control

- The system MUST use Mux signed URLs for video playback tokens when enrolling content becomes paid or access-restricted
- The system MUST configure playback policy as `public` for free/open courses and `signed` for restricted courses
- The system MUST generate signed playback tokens with a configurable expiry (default: 12 hours)
- The system MUST restrict video access based on Open edX course enrollment status (only enrolled users can view)
- The system SHOULD implement domain restriction on Mux playback to allow only `academyv2.mereka.io` and `academy.biji-biji.com`
- The system MUST NOT expose Mux asset IDs in client-facing HTML; only playback IDs are permitted in the rendered page

#### Video Analytics & Engagement

- The system MUST emit xAPI `played`, `paused`, `seeked`, and `completed` events from the Video XBlock to the Aspects analytics pipeline
- The system MUST track video completion percentage per learner per video and persist it in the Open edX progress tracking system
- The system SHOULD integrate Mux Data for server-side quality-of-service metrics (rebuffer ratio, time-to-first-frame, startup time)
- The system SHOULD expose per-video engagement metrics (play rate, average watch time, drop-off points) in Superset dashboards
- The system MUST NOT collect PII (email, IP address) in video analytics events

#### CDN & Global Delivery

- The system MUST rely on Mux's built-in global CDN for video delivery (no separate CDN configuration required)
- The system SHOULD verify CDN edge presence in Singapore/Southeast Asia for acceptable latency (<100ms TTFB for manifest requests)
- The system MAY configure a custom domain for video delivery (`video.mereka.io`) via Mux's custom domains feature if branding requires it

#### Mobile Video Optimization

- The system MUST serve a 240p rendition for connections below 1.5 Mbps (handled by HLS adaptive bitrate)
- The system MUST set appropriate `Cache-Control` headers on video segments for mobile caching
- The system SHOULD provide poster images at 640x360 resolution for mobile thumbnail display
- The system MUST ensure Video XBlock HTML is responsive and renders correctly in the Open edX mobile app WebView

### Non-Functional Requirements

#### Performance

- Time-to-first-frame MUST be <= 2 seconds on a 5 Mbps connection for 720p content
- Video start time (manifest fetch + first segment) SHOULD be <= 3 seconds on a 2 Mbps connection
- Rebuffer ratio MUST be < 1% for viewers on connections >= 3 Mbps
- Mux API response time for asset creation MUST be <= 5 seconds (p95)
- Studio upload initiation (obtaining a direct upload URL) MUST complete in <= 2 seconds

#### Availability

- Video playback availability SHOULD be >= 99.9% (per Mux's SLA)
- The system MUST gracefully degrade if Mux is unreachable: display poster image with "Video temporarily unavailable" message
- The system MUST NOT cause LMS page load failure if a video asset is unavailable or in "errored" state

#### Cost

- Annual video hosting cost MUST be <= $50/year for the current catalog (1,290 video-minutes, 10,000 monthly views)
- Monthly delivery cost MUST remain $0 while usage stays below 100,000 delivery minutes/month (Mux free tier)
- Storage cost SHOULD decrease over time via Mux automatic cold storage (40% at 30 days, 60% at 90 days)
- The system MUST alert when monthly delivery minutes exceed 80,000 (80% of free tier threshold)

#### Security

- Mux API credentials (MUX_TOKEN_ID, MUX_TOKEN_SECRET) MUST be stored in Infisical and synced to K8s via ExternalSecrets
- Mux API credentials MUST NOT appear in source code, environment files, or client-side JavaScript
- Signed playback tokens MUST use Mux signing keys rotated at least every 12 months
- The system MUST validate that playback token generation occurs server-side only

#### Scalability

- The system MUST support up to 1,000 video assets without architectural changes
- The system SHOULD support up to 100,000 monthly views within the Mux free delivery tier
- The system MUST define a documented migration path to GCS+CDN when monthly views consistently exceed 100,000 for 3 consecutive months

## Acceptance Criteria

### Video Ingestion

- [ ] AC-VPD-001: Given a valid MP4 URL, when `upload_videos_to_mux.py` is executed, then a Mux asset is created with status "preparing" or "ready" and a playback_id is returned
- [ ] AC-VPD-002: Given 503 MCT videos, when the Mux upload results file (`mux_upload_complete.json`) is checked, then all 503 entries have a non-null `mux_asset_id` and `mux_playback_id`
- [ ] AC-VPD-003: Given a new video upload from Studio, when the author submits a video file, then a Mux direct upload URL is generated within 2 seconds and the file upload begins
- [ ] AC-VPD-004: Given a batch upload of 10 videos, when the upload script runs, then progress is saved every 10 videos and the script can resume from the last checkpoint

### Transcoding & Playback

- [ ] AC-VPD-005: Given a Mux asset with status "ready", when the HLS URL `https://stream.mux.com/{PLAYBACK_ID}.m3u8` is requested, then the response contains an HLS manifest with at least 3 quality renditions
- [ ] AC-VPD-006: Given an Open edX course with a Video XBlock, when the learner loads the unit page, then the video player displays a poster thumbnail and begins HLS playback within 2 seconds on a 5 Mbps connection
- [ ] AC-VPD-007: Given a mobile learner on a 1 Mbps connection, when the HLS player performs adaptive bitrate switching, then the video degrades to 240p without buffering

### Subtitle Management

- [ ] AC-VPD-008: Given a video with an uploaded SRT subtitle in English, when the learner enables captions, then English subtitles display synchronized with video playback
- [ ] AC-VPD-009: Given a video with text tracks where `srclang` is empty, when the Mux asset is created, then the language_code defaults to "en"
- [ ] AC-VPD-010: Given a Vietnamese-localized course, when subtitle files in Vietnamese are uploaded to Mux, then the language selector in the video player shows "Vietnamese" as an option

### Content Protection

- [ ] AC-VPD-011: Given a restricted course with `signed` playback policy, when an unenrolled user attempts to play the video, then playback is denied with an appropriate error message
- [ ] AC-VPD-012: Given a signed playback token with 12-hour expiry, when the token is used after 12 hours, then Mux returns a 403 Forbidden response
- [ ] AC-VPD-013: Given the LMS HTML source, when inspected in browser DevTools, then only Mux playback IDs are visible -- never Mux asset IDs or API credentials

### Analytics

- [ ] AC-VPD-014: Given a learner watching a video to completion, when the xAPI pipeline is checked, then `played` and `completed` events exist in ClickHouse with the correct video identifier
- [ ] AC-VPD-015: Given Mux Data is enabled, when the Mux dashboard is accessed, then quality metrics (rebuffer ratio, TTFF, startup time) are visible for the last 7 days
- [ ] AC-VPD-016: Given a Superset dashboard for video engagement, when an instructor views it, then per-video play rates and average completion percentages are displayed

### Cost Control

- [ ] AC-VPD-017: Given the current catalog of 1,290 video-minutes, when Mux storage charges are calculated after 90 days, then monthly storage cost is <= $1.55 (cold storage discount applied)
- [ ] AC-VPD-018: Given 30,000 delivery minutes/month, when the Mux invoice is reviewed, then delivery cost is $0.00 (within 100K free tier)
- [ ] AC-VPD-019: Given a monitoring alert rule, when monthly delivery minutes exceed 80,000, then a Slack/email alert is triggered

### Secret Management

- [ ] AC-VPD-020: Given MUX_TOKEN_ID and MUX_TOKEN_SECRET in Infisical, when ExternalSecrets syncs, then the secrets are available in the `mereka-lms` K8s namespace as a Secret resource
- [ ] AC-VPD-021: Given the application codebase, when searched for Mux credentials, then no hardcoded tokens are found (verified by pre-commit hook)

### Migration Continuity

- [ ] AC-VPD-022: Given `video_mapping_openedx.json`, when cross-referenced with Mux API `list assets`, then every mapped playback_id resolves to a valid, ready asset
- [ ] AC-VPD-023: Given the 30 course packages rebuilt with Mux Video XBlocks, when imported into Open edX, then all video lessons play correctly with poster thumbnails

### Graceful Degradation

- [ ] AC-VPD-024: Given a Mux asset in "errored" state, when the Video XBlock renders, then a poster image with "Video temporarily unavailable" text is shown instead of a broken player
- [ ] AC-VPD-025: Given Mux API is unreachable, when the LMS page loads, then the page renders fully with video placeholder -- no 500 errors or blank pages

### Observability

- [ ] AC-VPD-026: Given the Video Operations Dashboard in Grafana, when accessed, then it displays upload counts, processing queue depth, transcode success rate, and API error rates
- [ ] AC-VPD-027: Given the Video Cost Dashboard in Grafana, when monthly delivery minutes exceed 80,000, then the free tier usage percentage panel shows a visual warning (orange/red threshold)
- [ ] AC-VPD-028: Given the Video Engagement Dashboard in Superset, when a course instructor accesses it, then drop-off heatmaps show time-series data for where learners pause or stop watching
- [ ] AC-VPD-029: Given Prometheus scraping Mux metrics, when `video_delivery_minutes_monthly` is queried, then the value updates at least every 6 hours
- [ ] AC-VPD-030: Given an alert rule for `video_transcode_success_rate`, when the rate drops below 95% for 6 hours, then a warning alert is sent to #ops-warnings Slack channel

### Content Protection & Signed URLs

- [ ] AC-VPD-031: Given a signed playback token generated server-side, when inspected, then it contains a JWT with `exp` claim set to 12 hours from generation time
- [ ] AC-VPD-032: Given domain restriction is enabled (`MUX_ENABLE_DOMAIN_RESTRICTION=true`), when a video is embedded on an external site (not academyv2.mereka.io or academy.biji-biji.com), then Mux returns a 403 Forbidden response
- [ ] AC-VPD-033: Given a Mux signing key rotation in progress, when both old and new keys are active, then videos can be played using tokens signed with either key (dual-key support)
- [ ] AC-VPD-034: Given the signed URL generation endpoint `/api/video/playback-token/<playback_id>/`, when called by an enrolled user, then a valid signed URL is returned in <100ms (p95)

### Edge Case Handling

- [ ] AC-VPD-035: Given a video upload with an unsupported codec (e.g., HEVC), when the upload is attempted, then the system rejects it with error message "Codec X is not supported. Please use H.264/AAC MP4."
- [ ] AC-VPD-036: Given two course authors uploading videos with the same `mct_lesson_id` simultaneously, when the upload script runs, then only one Mux asset is created (no duplicates)
- [ ] AC-VPD-037: Given storage quota is exceeded, when a new video upload is attempted, then the upload is queued and retried automatically after quota space becomes available
- [ ] AC-VPD-038: Given a CDN edge serving a corrupted HLS manifest, when the Video XBlock player retries with exponential backoff (1s, 2s, 4s), then playback succeeds on retry or shows "Video unavailable" message after 3 failed attempts

## Edge Cases

### Video Upload Failures

- If a video URL is unreachable during Mux ingestion, the asset transitions to "errored" status. The upload script MUST log the failure, record it in the results JSON, and continue with the next video.
- If the Mux API returns 429 (rate limited), the upload script MUST implement exponential backoff starting at 2 seconds, with a maximum of 5 retries.

### Retry/timeout behavior

- Mux asset creation is asynchronous. The system MUST poll asset status or use Mux webhooks to detect completion. Polling interval: every 10 seconds for up to 30 minutes.
- If a video remains in "preparing" status for more than 60 minutes, the system MUST log a warning and mark it for manual investigation.
- HLS manifest requests that timeout (>5 seconds) MUST trigger a retry with a different CDN edge if the player supports it. Otherwise, show the degradation message.

### Idempotency

- Re-running the upload script for already-uploaded videos MUST NOT create duplicate Mux assets. The script MUST check the passthrough metadata (mct_lesson_id) against existing assets before creating new ones.
- Re-importing OLX course packages with Video XBlocks MUST overwrite existing video references without creating duplicate units.

### Rate limits

- Mux API rate limits: 5 requests/second per environment. The system MUST enforce a 1 request/second rate for bulk operations (conservative margin).
- If bulk operations exceed rate limits, the system MUST queue remaining operations and retry after the reset window.

### Partial failures

- If a course has 10 video lessons and 2 fail to upload, the course package MUST still be built with the 8 successful videos. The 2 failed lessons MUST render as HTML placeholders with "Video processing -- check back later" messages.
- If subtitle upload fails but video upload succeeds, the video MUST be published without subtitles rather than blocking the entire video.

### Large videos

- Videos exceeding 2 GB MUST use Mux's chunked upload mechanism (direct uploads with resumable upload protocol).
- Videos exceeding 30 minutes SHOULD be flagged for review (educational videos should typically be 5-15 minutes for engagement).

### Stale CDN cache

- If a video is re-encoded or replaced, the HLS manifest URL remains the same (tied to playback_id). Mux handles cache invalidation automatically.
- If a Mux asset is deleted and recreated, the playback_id changes. The system MUST update all Video XBlocks referencing the old playback_id.

### Multi-language video variants

- Some MCT courses have separate video files per language (not subtitle tracks, but entirely different recordings). These MUST be modeled as separate Mux assets with distinct playback_ids, organized into language-specific course sections or as variant Video XBlocks with language selectors.

### Codec incompatibility

- If an uploaded video uses an unsupported codec (e.g., HEVC with proprietary DRM, AV1 without browser support), Mux may fail transcoding or produce an "errored" asset. The system MUST detect unsupported codecs during upload validation (via `ffprobe` or similar) and reject them with a clear error message: "Codec X is not supported. Please use H.264/AAC MP4."
- If Mux accepts the upload but transcoding fails with codec errors, the system MUST log the failure, mark the asset as "errored", and notify the course author with remediation steps.

### Storage quota exceeded

- If the Mux account reaches storage limits (unlikely with current catalog size, but possible with aggressive course expansion), new uploads MUST be rejected with a quota error. The system MUST alert ops when storage usage exceeds 80% of any quota limit.
- The system SHOULD implement a grace period: queue uploads when quota is exceeded, retry automatically after old content is archived or deleted.

### Concurrent uploads and race conditions

- If two course authors upload videos with the same `mct_lesson_id` passthrough metadata simultaneously, the system MUST NOT create duplicate Mux assets. The upload script MUST use `mct_lesson_id` as a uniqueness constraint: query existing assets via Mux API `/assets?passthrough=mct_lesson_id:{id}` before creating a new asset.
- If a video is re-uploaded while the original is still in "preparing" status, the system MUST either: (a) cancel the in-progress upload and replace it, or (b) reject the new upload with "Video already processing" error. Option (b) is simpler and recommended.

### Signed URL key rotation

- Mux signed playback URLs use signing keys that MUST be rotated at least every 12 months. During key rotation, the system MUST support both the old and new signing keys for a configurable overlap period (default: 24 hours) to prevent breaking active playback sessions.
- The system MUST provide a runbook for zero-downtime key rotation: (1) generate new signing key in Mux, (2) add new key to Infisical, (3) update ExternalSecrets to include both keys, (4) deploy pods with dual-key support, (5) wait 24 hours, (6) remove old key from Infisical, (7) clean up old key references.

### CDN cache poisoning

- If a Mux CDN edge serves stale or corrupted HLS manifests (rare but possible), learners may experience playback failures. The system MUST implement client-side retries with exponential backoff (1s, 2s, 4s) before showing the "Video unavailable" fallback message.
- If widespread CDN issues are detected (e.g., >5% of playback requests failing across multiple geos), the system MUST page on-call and provide a runbook for Mux support escalation.

## Observability

### Logs

- Video upload operations: Log each upload attempt, result (success/failure), Mux asset ID, and processing time to `scripts/migrations/mct/logs/video_upload_YYYY-MM-DD.log`
- Studio upload events: Log via Django's standard logging framework at `INFO` level, including user, course_id, video title, and Mux asset_id
- Playback errors: Log Video XBlock rendering errors (missing playback_id, errored asset, unreachable manifest) at `WARNING` level
- Mux webhook events: Log all incoming webhook payloads at `DEBUG` level, asset status transitions at `INFO` level

### Metrics

**Upload & Transcoding Metrics**:
- `video_upload_total` (counter): Total videos uploaded to Mux, labeled by `status` (success, failed, duplicate)
- `video_upload_duration_seconds` (histogram): Time from upload initiation to "ready" status, bucketed at 30s, 60s, 120s, 300s, 600s
- `video_transcode_success_rate` (gauge): Percentage of uploads that reach "ready" status (not "errored"), per 24h window
- `mux_asset_processing_queue_depth` (gauge): Number of assets in "preparing" status, checked every 5 minutes
- `mux_upload_errors_total` (counter): Upload failures, labeled by `error_type` (rate_limit, invalid_format, quota_exceeded, network_error)

**Delivery & Playback Metrics**:
- `video_delivery_minutes_monthly` (gauge): Current month's delivery minutes consumed (from Mux API or webhook), updated every 6 hours
- `video_playback_start_count` (counter): Number of video play initiations, labeled by `course_id` and `video_id`
- `video_completion_rate` (gauge): Percentage of videos watched to >= 90%, per `course_id` and `video_id`
- `video_ttff_seconds` (histogram): Time-to-first-frame from player load to first frame rendered, bucketed at 0.5s, 1s, 2s, 5s, 10s (from Mux Data or Video XBlock client instrumentation)
- `video_rebuffer_ratio` (gauge): Percentage of playback time spent rebuffering, per video, aggregated hourly (from Mux Data)
- `video_startup_time_seconds` (histogram): Time from user click to video start, bucketed at 0.5s, 1s, 2s, 3s, 5s
- `video_playback_errors_total` (counter): Playback failures, labeled by `error_code` (403_forbidden, 404_not_found, network_timeout, codec_error)

**CDN & Cache Metrics**:
- `video_cdn_cache_hit_ratio` (gauge): CDN cache hit rate for HLS segments, per region, updated hourly
- `video_manifest_request_latency_seconds` (histogram): Latency for `.m3u8` manifest requests, bucketed at 0.05s, 0.1s, 0.2s, 0.5s, 1s

**Storage & Cost Metrics**:
- `mux_storage_minutes` (gauge): Total video-minutes stored in Mux, refreshed daily via Mux API
- `mux_storage_cost_usd_monthly` (gauge): Estimated monthly storage cost based on cold storage discounts (40% at 30d, 60% at 90d)
- `mux_delivery_cost_usd_monthly` (gauge): Estimated monthly delivery cost based on minutes consumed (should remain $0 under 100K free tier)

**API & Infrastructure Metrics**:
- `mux_api_errors` (counter): Mux API error responses, labeled by `status_code` (429, 500, 503) and `endpoint` (/assets, /uploads, /playback-ids)
- `mux_api_request_duration_seconds` (histogram): Mux API response time, bucketed at 0.5s, 1s, 2s, 5s, 10s
- `signed_url_generation_duration_ms` (histogram): Time to generate signed playback tokens server-side, bucketed at 10ms, 50ms, 100ms, 500ms
- `subtitle_upload_success_rate` (gauge): Percentage of subtitle uploads that succeed, per 24h window

### Alerts

**Cost & Quota Alerts** (severity: critical, route to #ops-alerts):
- MUST alert when `video_delivery_minutes_monthly` exceeds 80,000 (80% of free tier, 3-month trailing average)
- MUST alert when `video_delivery_minutes_monthly` exceeds 95,000 (approaching free tier limit, immediate)
- MUST alert when `mux_storage_cost_usd_monthly` projected cost exceeds $3/month (indicates unexpected growth)
- SHOULD alert when `mux_asset_processing_queue_depth` exceeds 50 for >30 minutes (upload backlog)

**Playback Quality Alerts** (severity: warning, route to #ops-warnings):
- SHOULD alert when `video_ttff_seconds` p95 exceeds 5 seconds for more than 15 minutes (poor user experience)
- SHOULD alert when `video_rebuffer_ratio` p95 exceeds 2% for more than 30 minutes (CDN or encoding issue)
- SHOULD alert when `video_playback_errors_total` rate exceeds 5% of playback starts for >10 minutes (widespread issue)
- MUST alert when `video_cdn_cache_hit_ratio` drops below 80% for >1 hour (CDN edge misconfiguration)

**Upload & Transcoding Alerts** (severity: warning):
- MUST alert when any Mux asset transitions to "errored" status (individual video failure)
- MUST alert when `video_transcode_success_rate` drops below 95% over a 6-hour window (systemic issue)
- SHOULD alert when `video_upload_duration_seconds` p95 exceeds 600 seconds (10 minutes) for >1 hour (Mux API slowness)

**API & Infrastructure Alerts** (severity: critical):
- SHOULD alert when `mux_api_errors` rate exceeds 10 errors/hour (API instability)
- MUST alert when `mux_api_errors` rate exceeds 50 errors/hour for >5 minutes (API outage)
- MUST alert when MUX_TOKEN_SECRET or MUX_TOKEN_ID secrets fail ExternalSecrets sync (access loss imminent)
- MUST alert when `signed_url_generation_duration_ms` p95 exceeds 500ms for >10 minutes (authentication slowdown)

### Dashboards

**Video Operations Dashboard** (Grafana, `infrastructure/monitoring/dashboards/video-operations.json`):
- **Upload Health Panel**: `video_upload_total` by status (success/failed/duplicate), upload duration histogram, transcode success rate trend
- **Processing Queue Panel**: `mux_asset_processing_queue_depth` over time, assets in "preparing" vs "ready" vs "errored" states
- **API Health Panel**: Mux API request rate, error rate by endpoint, API latency p50/p95/p99
- **Storage Usage Panel**: `mux_storage_minutes` trend, storage cost estimate, cold storage discount application timeline
- **Alert Status Panel**: Active alerts related to video pipeline, alert history for last 7 days

**Video Engagement Dashboard** (Superset, integrated with Aspects analytics pipeline):
- **Play Rate Panel**: Video play starts per course, per video, per day/week/month
- **Completion Funnel Panel**: Play → 25% → 50% → 75% → 90% completion rates by video
- **Drop-off Heatmap**: Time-series heatmap showing where learners stop watching (derived from xAPI `seeked` and `paused` events)
- **Course Breakdown Panel**: Top 10 most-watched videos, bottom 10 least-watched videos, average watch time per course
- **Mobile vs Desktop Panel**: Playback starts and completion rates segmented by device type (from Video XBlock user agent)

**Video Cost Dashboard** (Grafana, `infrastructure/monitoring/dashboards/video-cost.json`):
- **Delivery Usage Panel**: `video_delivery_minutes_monthly` trend, free tier usage percentage (80K/95K thresholds marked), projected overage cost if threshold exceeded
- **Storage Cost Panel**: `mux_storage_cost_usd_monthly` trend, cost breakdown by cold storage tier (30d vs 90d discounts)
- **Projected Annual Cost Panel**: 12-month rolling cost estimate, comparison to GCS+CDN alternative at current usage levels
- **Scaling Trigger Panel**: Highlight when 3-month trailing average delivery minutes exceeds 80K (migration trigger per cost analysis)

**Video Quality Dashboard** (Grafana, populated by Mux Data integration):
- **Playback Performance Panel**: `video_ttff_seconds` p50/p95/p99, `video_startup_time_seconds` p95, rebuffer ratio trend
- **CDN Performance Panel**: `video_cdn_cache_hit_ratio` by region, manifest request latency by edge location
- **Error Breakdown Panel**: `video_playback_errors_total` by error code, error rate trend, affected videos list
- **Geographic Insights Panel**: Playback performance by viewer region (Singapore, Malaysia, Indonesia, global)

## Rollout & Rollback

### Rollout plan

#### Phase 1: MCT Migration Validation (Week 1) -- COMPLETED

1. 503 MCT videos uploaded to Mux via `upload_videos_to_mux.py`
2. Video mapping created via `create_video_mapping.py`
3. Course packages rebuilt with Mux Video XBlocks via `build_courses_with_mux.py`
4. All 30 courses re-imported into Open edX with video content

#### Phase 2: Observability & Cost Monitoring (Week 2-3)

1. Deploy Mux delivery-minutes monitoring (API polling script as K8s CronJob, every 6 hours)
2. Configure alert rules for delivery-minutes thresholds (80K, 95K)
3. Set up Grafana dashboard for video operations metrics
4. Validate cold storage discounts are applied after 30/90 days

#### Phase 3: Studio Upload Workflow (Week 4-6)

1. Implement Studio video upload via Mux direct uploads
2. Add Mux webhook handler for asset status notifications
3. Test end-to-end: author uploads video in Studio -> Mux processes -> Video XBlock renders
4. Deploy behind feature flag: `ENABLE_MUX_STUDIO_UPLOAD`

#### Phase 4: Analytics Integration (Week 6-8)

1. Extend Video XBlock to emit xAPI events for play/pause/seek/complete
2. Configure Mux Data integration for QoS metrics
3. Build Superset dashboards for video engagement
4. Validate analytics data flows to ClickHouse

#### Phase 5: Content Protection & Signed URLs (Week 8-10)

1. **Generate Mux signing keys** (via Mux Dashboard or API)
2. **Store signing keys in Infisical** as `MEREKA_LMS_MUX_SIGNING_KEY_ID` and `MEREKA_LMS_MUX_SIGNING_KEY_SECRET`
3. **Sync to K8s** via ExternalSecrets (verify `kubectl get secret mereka-lms-runtime-secrets -n mereka-lms -o json | jq .data`)
4. **Implement server-side signed URL generation**:
   - Add Django view `/api/video/playback-token/<playback_id>/` that generates signed tokens
   - Token expiry: 12 hours (configurable via `MUX_SIGNED_URL_EXPIRY_HOURS`)
   - Enforce enrollment check: `CourseEnrollment.objects.filter(user=request.user, course_id=course_key).exists()`
5. **Update Video XBlock rendering** to:
   - Check if course is restricted (via `CourseMode` or `EnterpriseCustomer.enable_video_drm`)
   - If restricted: fetch signed playback token from `/api/video/playback-token/` via AJAX before initializing player
   - If public: use public playback URL directly
6. **Set Mux playback policies per asset**:
   - For free courses: `playback_policy: "public"` (default, no token required)
   - For paid/restricted courses: `playback_policy: "signed"` (token required, enforced by Mux CDN)
7. **Test enrollment-gated access**:
   - Verify unenrolled users receive 403 Forbidden from Mux when attempting playback with no token
   - Verify enrolled users can play videos after token generation
   - Verify tokens expire after 12 hours (test with manually backdated tokens)
8. **Deploy behind feature flag**: `ENABLE_MUX_SIGNED_PLAYBACK` (default: `false`)
   - When `true`: all courses with `CourseMode` other than "honor" or "audit" use signed playback
   - When `false`: all videos use public playback (backward compatible)
9. **Domain restriction** (optional hardening):
   - Configure Mux playback policy to allow only `academyv2.mereka.io` and `academy.biji-biji.com` domains
   - Prevents video hotlinking from external sites (reduces unauthorized delivery costs)
10. **Monitor signed URL performance**: Track `signed_url_generation_duration_ms` and alert if p95 exceeds 500ms

### Feature flags

- `ENABLE_MUX_STUDIO_UPLOAD` (default: `false`): Enables the Studio-side Mux direct upload workflow. When disabled, video URLs must be manually configured in OLX.
- `ENABLE_MUX_SIGNED_PLAYBACK` (default: `false`): Enables signed URL playback tokens for restricted courses. When disabled, all videos use public playback policy. **Rollout plan**: Enable for single test course → all paid courses → all courses (if content protection becomes universal).
- `ENABLE_VIDEO_XAPI_EVENTS` (default: `false`): Enables xAPI event emission from the Video XBlock. When disabled, video analytics are not collected. **Rollout plan**: Enable for staging → 10% of courses (A/B test) → all courses.
- `MUX_DELIVERY_ALERT_THRESHOLD` (default: `80000`): Delivery-minutes threshold for cost alerts. Configurable to adjust alert sensitivity.
- `MUX_SIGNED_URL_EXPIRY_HOURS` (default: `12`): Expiry time for signed playback tokens in hours. Longer expiry reduces server load but increases risk of token sharing. Shorter expiry improves security but may cause playback interruptions for long sessions.
- `MUX_ENABLE_DOMAIN_RESTRICTION` (default: `false`): When enabled, Mux playback policy restricts playback to allowed domains (`academyv2.mereka.io`, `academy.biji-biji.com`). Prevents video hotlinking but requires testing to ensure no legitimate playback is blocked.

### Backward compatibility

- The Video XBlock already supports external HLS URLs via `<source>` tags. No XBlock code changes are required for Phase 1.
- Existing MCT Azure CDN video URLs remain functional as long as the CDN is active. The migration replaces them with Mux URLs but does not delete the originals.
- Courses without Mux videos continue to work with YouTube or direct MP4 URLs as before.

### Rollback steps

**Phase 1 Rollback (Video content)**:
```bash
# 1. Revert to pre-Mux course packages (Azure CDN URLs)
cd /home/gurpreet/projects/k8s/mereka-lms
# Rebuild packages with original Azure CDN URLs
python scripts/migrations/mct/build_category_packages.py

# 2. Re-import original packages
python scripts/migrations/mct/import_courses_k8s.py --packages var/migrations/mct/course_packages_category/

# 3. Verify playback with Azure CDN URLs
make qa-smoke
```

**Phase 3 Rollback (Studio uploads)**:
```bash
# 1. Disable feature flag
tutor config save --set ENABLE_MUX_STUDIO_UPLOAD=false

# 2. Restart LMS/CMS
tutor k8s restart lms cms
# Authors revert to manual OLX URL configuration
```

**Phase 5 Rollback (Signed playback)**:
```bash
# 1. Disable signed playback feature flag
tutor config save --set ENABLE_MUX_SIGNED_PLAYBACK=false

# 2. Restart LMS to apply config change
tutor k8s restart lms

# 3. Revert Mux playback policies to public (if assets were changed to "signed")
python scripts/migrations/mct/revert_mux_playback_policies.py --policy public

# 4. Verify playback works without tokens
curl -I "https://stream.mux.com/{PLAYBACK_ID}.m3u8"  # Should return 200 OK, not 403
```

**Signed URL key rotation rollback** (if rotation causes issues):
```bash
# 1. Identify which key is failing
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms | grep "MUX_SIGNING_KEY"

# 2. Revert to single-key configuration in Infisical
# Remove the new key, keep only the old working key

# 3. Force ExternalSecrets refresh
kubectl annotate externalsecret mereka-lms-runtime-secrets -n mereka-lms force-sync=$(date +%s)

# 4. Restart LMS pods to pick up reverted secrets
kubectl rollout restart deployment/lms -n mereka-lms

# 5. Verify signed URL generation works
kubectl exec -it deployment/lms -n mereka-lms -- python manage.py lms shell -c \
  "from mereka_platform.video import generate_signed_playback_url; print(generate_signed_playback_url('PLAYBACK_ID'))"
```

**Cost emergency rollback** (if Mux costs spike unexpectedly):
```bash
# 1. Identify high-traffic videos
curl -H "Authorization: Bearer $MUX_TOKEN" \
  https://api.mux.com/video/v1/assets?limit=100 | jq '.data[] | {id, playback_ids, duration}'

# 2. Set videos to on-demand only (disable preloading)
# Update Video XBlocks to add preload="none"

# 3. If critical: migrate to GCS+CDN (see Open Questions for migration plan)
```

## Open Questions

1. **Mux signing key rotation**: What is the process for rotating Mux signing keys? Is there a zero-downtime rotation procedure, or does it require a brief window where old tokens are invalid?
2. **Auto-transcription provider**: Should we use Mux's auto-caption feature (if available on Basic tier), or integrate a separate service like Whisper/Deepgram for subtitle generation? What is the cost?
3. **MCT Azure CDN sunset date**: When will the MCT Azure CDN URLs stop working? This determines the urgency of completing the Mux migration validation.
4. **Studio upload UX design**: Should video upload be integrated into the existing "Upload" button in Studio's content editor, or should it be a separate "Mux Video" XBlock type in the component picker?
5. **GCS+CDN migration trigger**: The cost comparison shows GCS+CDN becomes cheaper at 80,000+ monthly views. Should the migration trigger be automated (alert + runbook) or manual (quarterly cost review)?
6. **Video replacement workflow**: When a course author wants to replace an existing video, should the system create a new Mux asset (new playback_id) or re-ingest over the existing asset? The former breaks bookmarks/progress; the latter is not supported by Mux.
7. **Mux webhook endpoint**: Where should the Mux webhook listener run -- as a sidecar in the LMS pod, a standalone K8s deployment, or a Cloud Function? What is the expected webhook volume?
8. **Multi-language video variants vs. subtitles**: For courses with entirely separate video recordings per language (not just subtitle tracks), should we use Open edX's built-in language selection, separate course runs, or a custom language-switcher XBlock?
9. **Offline download for mobile**: The mobile-apps-enterprise spec mentions offline access. Does this require Mux MP4 download support (not available on Basic tier) or a separate download mechanism?
10. **Video content backup**: Should Mux assets be backed up to GCS for disaster recovery? Mux does not guarantee perpetual storage if the account is closed. What is the backup cadence and cost?

