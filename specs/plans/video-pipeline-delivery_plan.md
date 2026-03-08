---
source_spec: specs/video-pipeline-delivery_spec.md
status: ready
created: 2026-02-10
updated: 2026-02-10
---

# Video Pipeline & Delivery System - Implementation Plan

**Source Spec**: `specs/video-pipeline-delivery_spec.md`

**Spec Summary**: 25 Acceptance Criteria spanning video ingestion (Mux upload), transcoding/quality, playback via Video XBlock, subtitle management, content protection (signed URLs),analytics integration, CDN delivery, mobile optimization, cost monitoring, secrets management, migration continuity, and graceful degradation.

---

## Task Categories

Tasks are grouped by category and ordered by dependency. Eachtask includes:
- **Complexity**: S (<2h), M (2-8h), L (>8h)
- **AC Mapping**: Which acceptance criteria this task addresses
- **File Path**: Where the work happens
- **Dependencies**: Prerequisites (or "None" if independent)

---

## Build Tasks

### Video Ingestion & Upload

- [ ] **[M]** Complete Mux API client integration (`scripts/migrations/mct/upload_videos_to_mux.py`) | AC: #1, #2, #4 | Depends: None
  - Already exists; verify rate limiting (1 req/sec), exponential backoff, idempotency checks via passthrough metadata
  - Ensure batch upload with resume capability (tracking progress in `mux_upload_complete.json`)
  - Validate MP4, MOV, MKV, WebM input format support

- [ ] **[M]** Implement Mux asset status polling and webhookhandler (`scripts/monitoring/check_mux_asset_status.py`) | AC: #1 | Depends: Upload script
  - Poll Mux API for asset status transitions (preparing → ready, error)
  - Timeout after 60 minutes with warning
  - Log failures to `scripts/migrations/mct/logs/video_upload_*.log`
  - Store results in `scripts/migrations/mct/output/mux_upload_complete.json`

- [ ] **[M]** Create Studio upload workflow via Mux direct uploads (`infrastructure/tutor/patches/studio-mux-upload.patch`) | AC: #3 | Depends: Mux client
  - Generate Mux direct upload URL (server-side endpoint in CMS)
  - Browser-based upload from Studio content editor
  - Target: 2-second response time for upload URL generation
  - Behind feature flag: `ENABLE_MUX_STUDIO_UPLOAD`

### Video XBlock Integration & Playback

- [ ] **[L]** Update course packages with Mux Video XBlocks (`scripts/migrations/mct/build_courses_with_mux.py`) | AC: #5,#6, #23 | Depends: Video mapping
  - Already exists; verify HLS URL format: `https://stream.mux.com/{PLAYBACK_ID}.m3u8`
  - Set `download_video=false`, `show_captions=true`, posterimages via Mux thumbnail API
  - Validate all 503 MCT videos have valid Mux playback IDs
  - Support `start_time` and `end_time` for segment playback

- [ ] **[M]** Create video mapping validation script (`scripts/migrations/mct/validate_video_mapping.py`) | AC: #22 | Depends: Video upload
  - Cross-reference `video_mapping_openedx.json` with Mux API`list assets`
  - Verify every playback_id resolves to a valid, ready asset
  - Report missing or errored assets

- [ ] **[M]** Implement graceful degradation for Video XBlock(`infrastructure/tutor/patches/video-xblock-error-handling.patch`) | AC: #24, #25 | Depends: XBlock integration
  - Catch Mux asset "errored" status, display poster image +"Video temporarily unavailable"
  - Handle unreachable Mux API, render placeholder instead ofbreaking page
  - No 500 errors on LMS page load

### Subtitle & Caption Management

- [ ] **[M]** Extend Mux upload script with subtitle track support (`scripts/migrations/mct/upload_videos_to_mux.py`) | AC: #8, #9, #10 | Depends: Upload script
  - Already partially implemented; verify SRT/VTT upload to Mux assets
  - Default language_code to "en" when srclang is empty
  - Support Vietnamese (vi) and Chinese (zh) subtitle tracks
  - Set `closed_captions` flag appropriately

- [ ] **[S]** Document subtitle upload workflow (`docs/operations/VIDEO_SUBTITLE_MANAGEMENT.md`) | AC: #8 | Depends: Subtitle upload
  - How to add subtitles to existing Mux assets
  - How to enable multi-language tracks in Video XBlock
  - Auto-transcription integration (future consideration)

### Content Protection & Access Control

- [ ] **[L]** Implement Mux signed playback tokens (`scripts/video/generate_signed_playback_token.py`) | AC: #11, #12, #13| Depends: Secrets management
  - Server-side token generation with 12-hour expiry (configurable)
  - Playback policy: `public` for free courses, `signed` forrestricted
  - Restrict video access based on Open edX enrollment status
  - Domain restriction: `academyv2.mereka.io`, `academy.biji-biji.com`
  - Behind feature flag: `ENABLE_MUX_SIGNED_PLAYBACK`

- [ ] **[M]** Create LMS endpoint for signed playback URLs (`lms/djangoapps/video/views.py`) | AC: #11, #13 | Depends: Token generation
  - Check user enrollment before generating token
  - Return HLS URL with signed token query param
  - Ensure playback IDs only (never asset IDs) in client HTML

### Video Analytics & Engagement

- [ ] **[L]** Extend Video XBlock to emit xAPI events (`infrastructure/tutor/patches/video-xblock-xapi-events.patch`) | AC: #14 | Depends: XBlock integration
  - Emit `played`, `paused`, `seeked`, `completed` events toAspects pipeline
  - Track video completion percentage per learner
  - Ensure no PII (email, IP) in analytics events
  - Behind feature flag: `ENABLE_VIDEO_XAPI_EVENTS`

- [ ] **[M]** Integrate Mux Data for QoS metrics (`infrastructure/tutor/patches/mux-data-integration.patch`) | AC: #15 | Depends: Mux client
  - Enable Mux Data via environment variable
  - Configure Mux Data to collect: rebuffer ratio, time-to-first-frame, startup time
  - Access metrics via Mux dashboard

- [ ] **[M]** Create Superset video engagement dashboards (`infrastructure/analytics/superset/dashboards/video_engagement.json`) | AC: #16 | Depends: xAPI events
  - Per-video play rates, average watch time, drop-off points
  - Completion percentage by course_id
  - Integrate with existing Aspects/ClickHouse pipeline

### Mobile Video Optimization

- [ ] **[M]** Configure Mux adaptive bitrate for mobile (`infrastructure/tutor/tutor-env.sh`) | AC: #7 | Depends: XBlock integration
  - Verify 240p rendition for <1.5 Mbps connections (Mux handles via HLS ABR)
  - Set appropriate Cache-Control headers on video segments
  - Provide poster images at 640x360 for mobile thumbnails
  - Test Video XBlock HTML responsiveness in Open edX mobileapp WebView

---

## Test Tasks

- [ ] **[M]** Write unit tests for Mux upload script (`tests/migrations/test_upload_videos_to_mux.py`) | AC: #1, #2 | Depends: Upload script
  - Mock Mux API responses (success, rate limit 429, asset error)
  - Validate exponential backoff timing (2s, 4s, 8s, 16s, 32s)
  - Test idempotency: duplicate mct_lesson_id in passthroughmetadata
  - Test batch resume from checkpoint

- [ ] **[M]** Write integration tests for Video XBlock rendering (`tests/integration/test_video_xblock_mux.py`) | AC: #5,#6, #24, #25 | Depends: XBlock integration
  - Valid Mux playback_id → HLS player renders, poster thumbnail displays
  - Errored asset → placeholder image with error message
  - Unreachable Mux API → page loads without 500 error
  - Mobile WebView rendering test

- [ ] **[M]** Write unit tests for signed playback token generation (`tests/unit/test_signed_playback_tokens.py`) | AC: #11, #12, #13 | Depends: Token generation
  - Valid enrollment → token generated
  - Unenrolled user → token denied
  - Token expiry after 12 hours
  - Token validation (correct signature)

- [ ] **[M]** Write integration tests for xAPI event emission(`tests/integration/test_video_xapi_events.py`) | AC: #14 |Depends: xAPI integration
  - Play event → ClickHouse has `played` event with video identifier
  - Complete event (>=90% watched) → ClickHouse has `completed` event
  - No PII in event payloads

- [ ] **[M]** Write load tests for video playback (`tests/load/test_video_playback_performance.py`) | AC: Performance NFRs| Depends: XBlock integration
  - 100 concurrent video starts → p95 TTFF <=2 seconds (5 Mbps)
  - Simulate 2 Mbps connection → start time <=3 seconds
  - Rebuffer ratio <1% on 3 Mbps+ connections

- [ ] **[M]** Write integration tests for subtitle display (`tests/integration/test_video_subtitles.py`) | AC: #8, #9, #10| Depends: Subtitle upload
  - English subtitle uploaded → displays synchronized with video
  - Vietnamese subtitle uploaded → language selector shows Vietnamese
  - Empty srclang → defaults to "en"

---

## Observability Tasks

- [ ] **[M]** Implement Mux delivery-minutes monitoring (`scripts/monitoring/check_mux_delivery_minutes.py`) | AC: #17, #18, #19 | Depends: None
  - Poll Mux API for monthly delivery minutes consumed
  - Store in Prometheus gauge: `mux_delivery_minutes_monthly`
  - Run as K8s CronJob every 6 hours
  - Alert at 80K (80%), 95K (95% of free tier)

- [ ] **[M]** Create Prometheus metrics for video operations(`infrastructure/monitoring/prometheus/video-metrics.yml`) |AC: Metrics | Depends: None
  - `video_upload_total` (counter): labeled by status (success, failed, duplicate)
  - `video_playback_start_count` (counter): labeled by course_id
  - `video_completion_rate` (gauge): percentage per course_id
  - `video_ttff_seconds` (histogram): bucketed 0.5s, 1s, 2s,5s, 10s
  - `mux_storage_minutes` (gauge): refreshed daily
  - `mux_api_errors` (counter): labeled by status code and endpoint

- [ ] **[M]** Create Grafana video operations dashboard (`infrastructure/monitoring/grafana/dashboards/video-operations.json`) | AC: Dashboard | Depends: Metrics
  - Upload counts, processing queue depth, error rates, storage usage
  - Delivery minutes trend, projected monthly cost, free tierusage percentage

- [ ] **[M]** Create Grafana video cost dashboard (`infrastructure/monitoring/grafana/dashboards/video-cost.json`) | AC: #| Depends: Metrics
  - Monthly delivery minutes trend, storage minutes, projected cost
  - Free tier usage percentage, alert thresholds

- [ ] **[M]** Create Prometheus alert rules (`deploy/k8s/base/monitoring/prometheusrule-video.yaml`) | AC: #17, #18, #19 |Depends: Metrics
  - CRITICAL: `mux_delivery_minutes_monthly > 80000` (80% free tier)
  - CRITICAL: `mux_delivery_minutes_monthly > 95000` (approaching limit)
  - CRITICAL: Mux asset transitions to "errored" status
  - WARNING: `video_ttff_seconds p95 > 5s` for >15 min
  - WARNING: `mux_api_errors > 10/hour`
  - CRITICAL: MUX_TOKEN_SECRET ExternalSecrets sync failure

---

## Documentation Tasks

- [ ] **[S]** Write video pipeline architecture overview (`docs/architecture/video-pipeline-overview.md`) | Depends: All build tasks
  - System diagram: MCT/Kajabi → Mux → CDN → Video XBlock → Analytics
  - Data flow: upload → transcode → playback
  - Integration points: Mux API, Aspects pipeline

- [ ] **[M]** Write video operations runbook (`docs/operations/VIDEO_OPERATIONS_RUNBOOK.md`) | Depends: All build + observability tasks
  - Operational procedures: upload new videos, troubleshoot playback issues
  - Incident playbooks: Mux asset error, CDN degradation, cost spike
  - Troubleshooting: common symptoms → fixes
  - Rollback: revert to Azure CDN URLs if needed

- [ ] **[S]** Write Mux API setup guide (`docs/operations/MUX_API_SETUP.md`) | Depends: Secrets management
  - How to obtain Mux credentials (dashboard → API Access Tokens)
  - How to store credentials in Infisical
  - How to test Mux API connection

- [ ] **[S]** Update main troubleshooting doc with video section (`docs/runbooks/operations/TROUBLESHOOTING.md`) | Depends: All build tasks
  - Add video diagnostic commands
  - Add video playback issues to 5-command diagnostic flow

---

## Rollout Tasks

### Phase 1: MCT Migration Validation (Week 1) -- COMPLETED

- [ ] **[S]** Verify all 503 MCT videos uploaded to Mux (`scripts/migrations/mct/verify_mux_upload.sh`) | AC: #2 | Depends: None
  - Check `mux_upload_complete.json` for 503 entries with non-null asset_id, playback_id
  - Verify no "errored" assets via Mux API

- [ ] **[S]** Verify video mapping accuracy (`scripts/migrations/mct/verify_video_mapping.sh`) | AC: #22, #23 | Depends: Video mapping validation
  - Run `validate_video_mapping.py`
  - Ensure every mapped playback_id resolves to ready asset
  - Test sample videos play correctly in courses

### Phase 2: Observability & Cost Monitoring (Week 2-3)

- [ ] **[M]** Deploy Mux delivery-minutes monitoring CronJob(`deploy/k8s/base/apps/video-monitoring/`) | AC: #17 | Depends: Monitoring script
  - K8s CronJob manifest for `check_mux_delivery_minutes.py`
  - Schedule: every 6 hours (0 */6 * * *)
  - Mount MUX_TOKEN_ID, MUX_TOKEN_SECRET from ExternalSecrets

- [ ] **[M]** Configure Prometheus alert rules for delivery-minutes thresholds (`deploy/k8s/base/monitoring/prometheusrule-video.yaml`) | AC: #18, #19 | Depends: Metrics
  - 80K and 95K delivery-minutes alerts
  - Slack/email notification channel

- [ ] **[M]** Set up Grafana dashboards for video operationsand cost (`infrastructure/monitoring/grafana/dashboards/`) |AC: Dashboard | Depends: Metrics
  - Import dashboards to Grafana
  - Validate data flows from Prometheus

- [ ] **[S]** Validate cold storage discounts after 30/90 days (`scripts/monitoring/check_mux_cold_storage.sh`) | AC: #17| Depends: None
  - Manual verification after 30 days: storage cost should drop 40%
  - Manual verification after 90 days: storage cost should drop 60%

### Phase 3: Studio Upload Workflow (Week 4-6)

- [ ] **[M]** Implement Studio video upload via Mux direct uploads (`infrastructure/tutor/patches/studio-mux-upload.patch`) | AC: #3 | Depends: Studio upload workflow
  - Server-side endpoint to generate Mux direct upload URL
  - Client-side upload from Studio content editor
  - Test end-to-end: author uploads → Mux processes → Video XBlock renders

- [ ] **[S]** Create Mux webhook handler for asset status notifications (`scripts/webhooks/mux_webhook_handler.py`) | AC:#1 | Depends: Studio upload
  - Webhook endpoint to receive Mux `video.asset.ready`, `video.asset.errored` events
  - Update internal asset status tracking
  - Deploy as K8s service (optional; can poll instead)

- [ ] **[M]** Deploy Studio upload feature behind flag (`infrastructure/tutor/tutor-env.sh`) | AC: #3 | Depends: Studio upload implementation
  - Set `ENABLE_MUX_STUDIO_UPLOAD=false` initially (testing only)
  - Test with admin users only
  - Enable for all authors after validation

### Phase 4: Analytics Integration (Week 6-8)

- [ ] **[M]** Extend Video XBlock to emit xAPI events (`infrastructure/tutor/patches/video-xblock-xapi-events.patch`) | AC: #14 | Depends: xAPI integration
  - Deploy behind `ENABLE_VIDEO_XAPI_EVENTS=false` flag initially
  - Test event flow: Video XBlock → Aspects → ClickHouse

- [ ] **[M]** Configure Mux Data integration (`infrastructure/tutor/tutor-env.sh`) | AC: #15 | Depends: Mux Data integration
  - Set `MUX_DATA_ENV_KEY` in tutor config
  - Verify QoS metrics appear in Mux dashboard

- [ ] **[M]** Build Superset dashboards for video engagement(`infrastructure/analytics/superset/dashboards/`) | AC: #16 |Depends: xAPI events
  - Create dashboards for per-video play rates, completion rates
  - Validate data appears in Superset from ClickHouse

- [ ] **[S]** Enable xAPI events in production (`infrastructure/tutor/tutor-env.sh`) | AC: #14 | Depends: Analytics testing
  - Set `ENABLE_VIDEO_XAPI_EVENTS=true`
  - Monitor ClickHouse ingestion rate

### Phase 5: Content Protection (Week 8-10)

- [ ] **[M]** Implement signed URL generation for restrictedcourses (`scripts/video/generate_signed_playback_token.py`) |AC: #11, #12 | Depends: Token generation
  - Server-side endpoint in LMS
  - Check enrollment before generating token
  - Test with paid/restricted courses

- [ ] **[S]** Add server-side token generation endpoint (`lms/djangoapps/video/views.py`) | AC: #11, #13 | Depends: Tokengeneration
  - REST API endpoint: `POST /api/video/v1/playback-token/`
  - Requires authentication (JWT or session)
  - Returns signed HLS URL with expiry

- [ ] **[M]** Test enrollment-gated video access (`tests/integration/test_video_access_control.py`) | AC: #11 | Depends: Token endpoint
  - Enrolled user → token generated, video plays
  - Unenrolled user → 403 Forbidden
  - Expired token → 403 Forbidden

- [ ] **[S]** Deploy signed playback for paid courses only (`infrastructure/tutor/tutor-env.sh`) | AC: #11 | Depends: Testing
  - Set `ENABLE_MUX_SIGNED_PLAYBACK=false` initially
  - Enable for specific courses (whitelist)
  - Monitor playback success rate

---

## Secrets Management Tasks

- [ ] **[S]** Add Mux API credentials to Infisical (`scripts/infra/create-video-secrets.sh`) | AC: #20 | Depends: None
  - `MEREKA_LMS_MUX_TOKEN_ID`
  - `MEREKA_LMS_MUX_TOKEN_SECRET`
  - `MEREKA_LMS_MUX_SIGNING_KEY` (for signed playback)
  - Sync to GCP Secret Manager

- [ ] **[M]** Create ExternalSecret manifest for Mux credentials (`deploy/k8s/base/secrets/video-secrets.yaml`) | AC: #20| Depends: Infisical secrets
  - Map secrets from GCP SM to K8s Secret `video-secrets`
  - Refresh interval: 1h
  - Mount in LMS, CMS, video-monitoring CronJob

- [ ] **[S]** Verify no hardcoded Mux credentials in codebase(`scripts/qa/check-hardcoded-secrets.sh`) | AC: #21 | Depends: None
  - Grep for MUX_TOKEN, mux_token, hardcoded playback IDs
  - Run pre-commit hook to prevent future leaks

---

## Summary

**Total Tasks**: 58

**By Complexity**:
- Small (S): 14 tasks
- Medium (M): 38 tasks
- Large (L): 6 tasks

**By Category**:
- Build: 18 tasks
- Test: 7 tasks
- Observability: 5 tasks
- Documentation: 4 tasks
- Rollout: 20 tasks
- Secrets: 3 tasks

**Critical Path**:
1. Verify MCT upload complete → Video mapping validation → XBlock integration → Observability → Analytics → Content protection

**Estimated Timeline**: 8-10 weeks (per spec Rollout Plan)

**Dependencies External to This Spec**:
- Mux API credentials (obtain from Mux dashboard)
- Aspects analytics pipeline operational (see `specs/analytics-pipeline_spec.md`)
- Infisical secrets management setup (see `specs/secrets-management_spec.md`)
- Open edX Video XBlock supports external HLS URLs (verified)

---

## Verification Checklist

Before marking any phase complete:
- [ ] All acceptance criteria for that phase are covered by tests
- [ ] Testmap YAML is updated with new test files
- [ ] Metrics are being collected and dashboards display data
- [ ] Alerts have been tested (fire and resolve)
- [ ] Runbook has been validated by team
- [ ] Rollback procedure has been rehearsed
- [ ] Load testing completed with no degradation
- [ ] All secrets are in Infisical/GCP SM, none hardcoded
- [ ] Video playback tested on mobile (iOS/Android Open edX apps)
- [ ] Subtitle display tested for at least English and Vietnamese
