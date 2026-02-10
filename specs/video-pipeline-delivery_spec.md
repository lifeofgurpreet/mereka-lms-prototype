---
title: "Video Pipeline & Delivery System"
type: "feature_spec"
status: "draft"
owner: "engineering"
vehicle: "talent_platform"
last_updated: "2026-02-10"
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

### Non-functional (NFRs)

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

- [ ] AC-001: Given a valid MP4 URL, when `upload_videos_to_mux.py` is executed, then a Mux asset is created with status "preparing" or "ready" and a playback_id is returned
- [ ] AC-002: Given 503 MCT videos, when the Mux upload results file (`mux_upload_complete.json`) is checked, then all 503 entries have a non-null `mux_asset_id` and `mux_playback_id`
- [ ] AC-003: Given a new video upload from Studio, when the author submits a video file, then a Mux direct upload URL is generated within 2 seconds and the file upload begins
- [ ] AC-004: Given a batch upload of 10 videos, when the upload script runs, then progress is saved every 10 videos and the script can resume from the last checkpoint

### Transcoding & Playback

- [ ] AC-005: Given a Mux asset with status "ready", when the HLS URL `https://stream.mux.com/{PLAYBACK_ID}.m3u8` is requested, then the response contains an HLS manifest with at least 3 quality renditions
- [ ] AC-006: Given an Open edX course with a Video XBlock, when the learner loads the unit page, then the video player displays a poster thumbnail and begins HLS playback within 2 seconds on a 5 Mbps connection
- [ ] AC-007: Given a mobile learner on a 1 Mbps connection, when the HLS player performs adaptive bitrate switching, then the video degrades to 240p without buffering

### Subtitle Management

- [ ] AC-008: Given a video with an uploaded SRT subtitle in English, when the learner enables captions, then English subtitles display synchronized with video playback
- [ ] AC-009: Given a video with text tracks where `srclang` is empty, when the Mux asset is created, then the language_code defaults to "en"
- [ ] AC-010: Given a Vietnamese-localized course, when subtitle files in Vietnamese are uploaded to Mux, then the language selector in the video player shows "Vietnamese" as an option

### Content Protection

- [ ] AC-011: Given a restricted course with `signed` playback policy, when an unenrolled user attempts to play the video, then playback is denied with an appropriate error message
- [ ] AC-012: Given a signed playback token with 12-hour expiry, when the token is used after 12 hours, then Mux returns a 403 Forbidden response
- [ ] AC-013: Given the LMS HTML source, when inspected in browser DevTools, then only Mux playback IDs are visible -- never Mux asset IDs or API credentials

### Analytics

- [ ] AC-014: Given a learner watching a video to completion, when the xAPI pipeline is checked, then `played` and `completed` events exist in ClickHouse with the correct video identifier
- [ ] AC-015: Given Mux Data is enabled, when the Mux dashboard is accessed, then quality metrics (rebuffer ratio, TTFF, startup time) are visible for the last 7 days
- [ ] AC-016: Given a Superset dashboard for video engagement, when an instructor views it, then per-video play rates and average completion percentages are displayed

### Cost Control

- [ ] AC-017: Given the current catalog of 1,290 video-minutes, when Mux storage charges are calculated after 90 days, then monthly storage cost is <= $1.55 (cold storage discount applied)
- [ ] AC-018: Given 30,000 delivery minutes/month, when the Mux invoice is reviewed, then delivery cost is $0.00 (within 100K free tier)
- [ ] AC-019: Given a monitoring alert rule, when monthly delivery minutes exceed 80,000, then a Slack/email alert is triggered

### Secret Management

- [ ] AC-020: Given MUX_TOKEN_ID and MUX_TOKEN_SECRET in Infisical, when ExternalSecrets syncs, then the secrets are available in the `mereka-lms` K8s namespace as a Secret resource
- [ ] AC-021: Given the application codebase, when searched for Mux credentials, then no hardcoded tokens are found (verified by pre-commit hook)

### Migration Continuity

- [ ] AC-022: Given `video_mapping_openedx.json`, when cross-referenced with Mux API `list assets`, then every mapped playback_id resolves to a valid, ready asset
- [ ] AC-023: Given the 30 course packages rebuilt with Mux Video XBlocks, when imported into Open edX, then all video lessons play correctly with poster thumbnails

### Graceful Degradation

- [ ] AC-024: Given a Mux asset in "errored" state, when the Video XBlock renders, then a poster image with "Video temporarily unavailable" text is shown instead of a broken player
- [ ] AC-025: Given Mux API is unreachable, when the LMS page loads, then the page renders fully with video placeholder -- no 500 errors or blank pages

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

## Observability

### Logs

- Video upload operations: Log each upload attempt, result (success/failure), Mux asset ID, and processing time to `scripts/migrations/mct/logs/video_upload_YYYY-MM-DD.log`
- Studio upload events: Log via Django's standard logging framework at `INFO` level, including user, course_id, video title, and Mux asset_id
- Playback errors: Log Video XBlock rendering errors (missing playback_id, errored asset, unreachable manifest) at `WARNING` level
- Mux webhook events: Log all incoming webhook payloads at `DEBUG` level, asset status transitions at `INFO` level

### Metrics

- `video_upload_total` (counter): Total videos uploaded to Mux, labeled by status (success, failed, duplicate)
- `video_delivery_minutes_monthly` (gauge): Current month's delivery minutes consumed (from Mux API or webhook)
- `video_playback_start_count` (counter): Number of video play initiations, labeled by course_id
- `video_completion_rate` (gauge): Percentage of videos watched to >= 90%, per course_id
- `video_ttff_seconds` (histogram): Time-to-first-frame, bucketed at 0.5s, 1s, 2s, 5s, 10s
- `mux_storage_minutes` (gauge): Total video-minutes stored in Mux, refreshed daily
- `mux_api_errors` (counter): Mux API error responses, labeled by status code and endpoint

### Alerts

- MUST alert when `video_delivery_minutes_monthly` exceeds 80,000 (80% of free tier)
- MUST alert when `video_delivery_minutes_monthly` exceeds 95,000 (approaching free tier limit)
- MUST alert when any Mux asset transitions to "errored" status
- SHOULD alert when `video_ttff_seconds` p95 exceeds 5 seconds for more than 15 minutes
- SHOULD alert when `mux_api_errors` rate exceeds 10 errors/hour
- MUST alert when MUX_TOKEN_SECRET or MUX_TOKEN_ID secrets fail ExternalSecrets sync

### Dashboards

- **Video Operations Dashboard** (Grafana): Upload counts, processing queue depth, error rates, storage usage
- **Video Engagement Dashboard** (Superset): Play rates, completion rates, drop-off heatmaps, per-course breakdowns
- **Video Cost Dashboard** (Grafana): Monthly delivery minutes trend, storage minutes, projected monthly cost, free tier usage percentage

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

#### Phase 5: Content Protection (Week 8-10)

1. Implement signed URL generation for restricted courses
2. Add server-side token generation endpoint
3. Test enrollment-gated video access
4. Deploy signed playback for paid courses only

### Feature flags

- `ENABLE_MUX_STUDIO_UPLOAD` (default: `false`): Enables the Studio-side Mux direct upload workflow. When disabled, video URLs must be manually configured in OLX.
- `ENABLE_MUX_SIGNED_PLAYBACK` (default: `false`): Enables signed URL playback tokens for restricted courses. When disabled, all videos use public playback policy.
- `ENABLE_VIDEO_XAPI_EVENTS` (default: `false`): Enables xAPI event emission from the Video XBlock. When disabled, video analytics are not collected.
- `MUX_DELIVERY_ALERT_THRESHOLD` (default: `80000`): Delivery-minutes threshold for cost alerts. Configurable to adjust alert sensitivity.

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
# 1. Disable signed playback
tutor config save --set ENABLE_MUX_SIGNED_PLAYBACK=false

# 2. Restart LMS
tutor k8s restart lms
# All videos revert to public playback policy
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

