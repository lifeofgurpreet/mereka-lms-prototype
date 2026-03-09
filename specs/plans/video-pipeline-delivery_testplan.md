---
spec: video-pipeline-delivery_spec.md
tier: 3
status: draft
last_updated: '2026-02-10'
plan: video-pipeline-delivery_plan.md
---

# Test Plan: Video Pipeline & Delivery System

**Source Spec**: `specs/video-pipeline-delivery_spec.md`

## Test Infrastructure

This repository uses:

| Test Type | Tool | Location Pattern |
|-----------|------|------------------|
| `shell_verification` | Bash scripts | `scripts/qa/verify-*.sh`, `scripts/qa/audit-*.sh` |
| `smoke_test` | Bash + curl | `scripts/qa/smoke-*.sh` |
| `pytest` | pytest (Python) | `tests/test_*.py` |
| `manual_verification` | Human checklist | Documented inline below |

No Vitest/Jest -- this is an infrastructure/deployment repository, not a web application.

---

## Test Matrix

### Video Ingestion (AC-001 through AC-004)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-001 | Given a valid MP4 URL, upload to Mux returns asset_id and playback_id with status "preparing" or "ready" | pytest | `tests/test_mux_upload.py` | Mock `mux_python.AssetsApi` (success response) |
| AC-001 | Given an unreachable video URL, upload logs failure and continues to next video | pytest | `tests/test_mux_upload.py` | Mock `mux_python.AssetsApi` (errored response) |
| AC-001 | Given Mux returns 429, upload retries with exponential backoff (2s, 4s, 8s...) up to 5 retries | pytest | `tests/test_mux_api_utils.py` | Mock HTTP 429 responses |
| AC-001 | Given a re-run for already-uploaded video, no duplicate asset is created (idempotency) | pytest | `tests/test_mux_api_utils.py` | Mock `list_assets` returning existing asset with matching passthrough |
| AC-002 | Given `mux_upload_complete.json`, all 503 entries have non-null mux_asset_id and mux_playback_id | shell_verification | `scripts/qa/verify-mux-upload-completeness.sh` | `exports/mct/mux_upload_complete.json` |
| AC-003 | Given a Studio upload request, Mux direct upload URL is generated within 2 seconds | manual_verification | N/A (documented below) | Test in local Tutor with ENABLE_MUX_STUDIO_UPLOAD=true |
| AC-003 | Given Studio upload is complete, video appears in XBlock with poster thumbnail | smoke_test | `scripts/qa/verify-studio-upload.sh` | Mux API credentials, test video file |
| AC-004 | Given a batch of 10 videos with script killed at video 5, resume picks up from video 6 | pytest | `tests/test_mux_upload.py` | Mock Mux API, checkpoint JSON file |

### Transcoding & Playback (AC-005 through AC-007)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-005 | Given a ready Mux asset, HLS manifest contains at least 3 quality renditions (240p, 480p, 720p) | shell_verification | `scripts/qa/verify-hls-renditions.sh` | curl + grep against live Mux HLS URL |
| AC-006 | Given an Open edX course page with Video XBlock, video player renders poster thumbnail and begins HLS playback | smoke_test | `scripts/qa/smoke-video-playback.sh` | Live course page URL, curl/wget |
| AC-006 | Given a Mux playback_id, poster image at 640x360 is served by Mux Image API | shell_verification | `scripts/qa/verify-poster-dimensions.sh` | curl + identify (ImageMagick) against `image.mux.com` |
| AC-007 | Given an HLS manifest, 240p rendition exists for low-bandwidth adaptive switching | shell_verification | `scripts/qa/verify-hls-renditions.sh` | curl against Mux HLS manifest |

### Subtitle Management (AC-008 through AC-010)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-008 | Given a video with SRT subtitle uploaded, English captions display synchronized with playback | manual_verification | N/A | Test in browser with Mux player; verify subtitle timing |
| AC-008 | Given SRT and VTT files, upload to Mux creates text tracks successfully | pytest | `tests/test_mux_subtitle_utils.py` | Mock `mux_python.AssetsApi.create_asset_track` |
| AC-009 | Given a subtitle with empty srclang, Mux track language_code defaults to "en" | pytest | `tests/test_mux_subtitle_utils.py` | Mock Mux API |
| AC-010 | Given Vietnamese subtitle uploaded to Mux, language selector shows "Vietnamese" | manual_verification | N/A | Test in browser with multi-language Mux asset |
| AC-010 | Given a course with Vietnamese subtitles, verification script confirms `vi` track exists on Mux asset | shell_verification | `scripts/qa/verify-video-subtitles.sh` | Mux API query for asset tracks |

### Content Protection (AC-011 through AC-013)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-011 | Given a restricted course with signed policy, unenrolled user cannot play video (403 or error message) | manual_verification | N/A | Test with unenrolled user account on restricted course |
| AC-011 | Given a signed playback token, playback succeeds for enrolled user | shell_verification | `scripts/qa/verify-mux-signed-playback.sh` | Mux signing key, test playback_id |
| AC-012 | Given a signed token with 12-hour expiry, after expiry Mux returns 403 Forbidden | shell_verification | `scripts/qa/verify-mux-signed-playback.sh` | Generate token with short (10s) expiry, wait, verify 403 |
| AC-013 | Given LMS HTML output, no Mux asset IDs appear -- only playback IDs | shell_verification | `scripts/qa/verify-no-mux-asset-ids.sh` | curl LMS course page, grep for Mux asset ID pattern |

### Analytics (AC-014 through AC-016)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-014 | Given a learner watches video to completion, ClickHouse contains `played` and `completed` xAPI events | shell_verification | `scripts/qa/verify-video-xapi-events.sh` | ClickHouse query, test video playback |
| AC-014 | Given xAPI video events, no PII (email, IP) is present in event payloads | shell_verification | `scripts/qa/verify-video-xapi-events.sh` | ClickHouse query for PII patterns in event data |
| AC-015 | Given Mux Data is enabled, QoS metrics (rebuffer ratio, TTFF, startup time) visible in Mux dashboard | manual_verification | N/A | Log into Mux dashboard, verify Data tab shows metrics |
| AC-015 | Given Mux Data integration, verify dashboard API returns data for last 7 days | shell_verification | `scripts/qa/verify-mux-data-dashboard.sh` | Mux Data API query |
| AC-016 | Given Superset video engagement dashboard, play rates and completion percentages are displayed | manual_verification | N/A | Log into Superset, verify dashboard loads with data |
| AC-016 | Given Superset dashboard exists, verification script confirms it loads without error | shell_verification | `scripts/qa/verify-superset-video-dashboard.sh` | Superset API health check |

### Cost Control (AC-017 through AC-019)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-017 | Given 1,290 video-minutes stored for 90+ days, monthly storage cost <= $1.55 | manual_verification | N/A | Check Mux billing dashboard after 90 days; verify cold storage discount |
| AC-017 | Given Mux storage audit script, total storage minutes are reported correctly | shell_verification | `scripts/qa/verify-mux-storage-cost.sh` | Mux API query (or run `mux-storage-audit.py`) |
| AC-018 | Given 30,000 delivery minutes/month, Mux delivery cost is $0.00 (within 100K free tier) | manual_verification | N/A | Check Mux billing dashboard |
| AC-019 | Given delivery minutes exceed 80,000, Slack/email alert is triggered | shell_verification | `scripts/qa/verify-mux-alerts.sh` | Prometheus alertmanager API query for `mux_delivery_warning` |

### Secret Management (AC-020, AC-021)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-020 | Given MUX_TOKEN_ID and MUX_TOKEN_SECRET in Infisical, ExternalSecrets syncs them to K8s `mereka-lms` namespace | shell_verification | `scripts/qa/verify-mux-secrets.sh` | kubectl access to mereka-lms namespace |
| AC-020 | Given ExternalSecrets sync fails, alert fires | shell_verification | `scripts/qa/verify-mux-alerts.sh` | Prometheus alert rule check |
| AC-021 | Given the codebase, no hardcoded Mux tokens found | shell_verification | `scripts/qa/scan-mux-credentials.sh` | grep/ripgrep across repo |

### Migration Continuity (AC-022, AC-023)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-022 | Given `video_mapping_openedx.json`, every playback_id resolves to a valid ready Mux asset | shell_verification | `scripts/qa/verify-mux-asset-status.py` | Mux API credentials, mapping JSON |
| AC-023 | Given 30 course packages with Mux Video XBlocks, import into Open edX and all videos play with poster thumbnails | smoke_test | `scripts/qa/smoke-video-playback.sh` | Live Open edX instance with imported courses |

### Graceful Degradation (AC-024, AC-025)

| AC # | Test Case | Type | File | Mocks/Fixtures |
|------|-----------|------|------|----------------|
| AC-024 | Given a Mux asset in "errored" state, Video XBlock shows poster + "Video temporarily unavailable" | shell_verification | `scripts/qa/verify-video-degradation.sh` | Course page with errored asset reference |
| AC-024 | Given Mux API unreachable, XBlock renders gracefully without 500 error | shell_verification | `scripts/qa/verify-video-degradation.sh` | Simulate by blocking Mux API (iptables or /etc/hosts) |
| AC-025 | Given Mux API unreachable during LMS page load, page renders fully with video placeholder | smoke_test | `scripts/qa/smoke-video-playback.sh` | Block Mux API, load course page |

---

## Edge Case Tests

| Edge Case | Test Case | Type | File | Mocks/Fixtures |
|-----------|-----------|------|------|----------------|
| EC-UPLOAD-FAIL | Unreachable video URL logs failure and continues | pytest | `tests/test_mux_upload.py` | Mock errored asset response |
| EC-RATE-LIMIT | Mux 429 triggers exponential backoff (2s base, 5 retries max) | pytest | `tests/test_mux_api_utils.py` | Mock HTTP 429 then 200 |
| EC-RATE-LIMIT | After 5 retries still failing, operation is queued for later | pytest | `tests/test_mux_api_utils.py` | Mock persistent 429 |
| EC-TIMEOUT | Asset in "preparing" > 60 minutes logs WARNING | pytest | `tests/test_mux_upload.py` | Mock asset status stuck on "preparing" |
| EC-IDEMPOTENCY | Re-run upload for existing video skips creation | pytest | `tests/test_mux_api_utils.py` | Mock existing asset with matching passthrough |
| EC-IDEMPOTENCY | Re-import OLX overwrites existing video references | manual_verification | N/A | Import same OLX twice, verify no duplicate units |
| EC-PARTIAL | 2 of 10 uploads fail; course package built with 8 videos + 2 placeholders | pytest | `tests/test_mux_upload.py` | Mock 2 failures in batch of 10 |
| EC-PARTIAL | Subtitle upload fails but video publishes without subtitles | pytest | `tests/test_mux_subtitle_utils.py` | Mock subtitle API error |
| EC-LARGE | Video > 2 GB uses chunked/resumable upload | pytest | `tests/test_mux_api_utils.py` | Mock direct upload creation for large file |
| EC-LARGE | Video > 30 min flagged with WARNING log | pytest | `tests/test_mux_api_utils.py` | Mock asset with 45-min duration |
| EC-CDN-STALE | Deleted + recreated asset: all XBlocks updated with new playback_id | manual_verification | N/A | Delete Mux asset, recreate, verify XBlock update process |
| EC-MULTI-LANG | Multi-language video variants modeled as separate assets with distinct playback_ids | manual_verification | N/A | Verify course structure for multi-language MCT courses |

---

## Manual Verification Procedures

### MV-001: Studio Upload UX (AC-003)

1. Enable feature flag: `tutor config save --set ENABLE_MUX_STUDIO_UPLOAD=true`
2. Restart LMS/CMS: `tutor k8s restart lms cms`
3. Log into Studio as a course author
4. Navigate to a course unit, add a new Video component
5. Upload a test MP4 file (< 50 MB for speed)
6. **VERIFY**: Upload URL generated within 2 seconds (check browser network tab)
7. **VERIFY**: After upload completes, video status transitions to "ready"
8. **VERIFY**: Video XBlock shows poster thumbnail from Mux Image API
9. **VERIFY**: Video plays via HLS in the LMS learner view

### MV-002: Subtitle Display (AC-008, AC-010)

1. Using `mux_subtitle_utils.py`, upload an English SRT to a test Mux asset
2. Upload a Vietnamese VTT to the same asset
3. Open the course page in LMS
4. **VERIFY**: Caption button appears on video player
5. **VERIFY**: English subtitles are synchronized with video
6. **VERIFY**: Language selector shows "English" and "Vietnamese"
7. **VERIFY**: Switching to Vietnamese displays Vietnamese subtitles

### MV-003: Content Protection (AC-011)

1. Enable feature flag: `tutor config save --set ENABLE_MUX_SIGNED_PLAYBACK=true`
2. Restart LMS: `tutor k8s restart lms`
3. Mark a course as restricted (paid/enrollment-gated)
4. Log in as an **unenrolled** user
5. Navigate to the video lesson
6. **VERIFY**: Video playback is denied with an error message
7. Enroll the user in the course
8. **VERIFY**: Video plays normally with signed token

### MV-004: Mux Data QoS (AC-015)

1. Play 5+ videos across different courses
2. Log into Mux dashboard (https://dashboard.mux.com)
3. Navigate to Data tab
4. **VERIFY**: Rebuffer ratio, TTFF, and startup time metrics are visible
5. **VERIFY**: Data covers the last 7 days

### MV-005: Superset Dashboard (AC-016)

1. Log into Superset instance
2. Navigate to Video Engagement dashboard
3. **VERIFY**: Per-video play rates displayed
4. **VERIFY**: Average completion percentages displayed
5. **VERIFY**: Per-course breakdown available

### MV-006: Cold Storage Cost (AC-017, AC-018)

1. Wait 90+ days after initial Mux upload
2. Log into Mux dashboard billing section
3. **VERIFY**: Storage cost reflects cold storage discount (40% at 30d, 60% at 90d)
4. **VERIFY**: Monthly storage <= $1.55 for 1,290 video-minutes
5. **VERIFY**: Delivery cost = $0.00 for < 100K monthly delivery minutes

---

## Test Execution Order

1. **Phase 2 first** (secrets, alerts, monitoring): `verify-mux-secrets.sh`, `scan-mux-credentials.sh`, `verify-mux-alerts.sh`
2. **Migration validation**: `verify-mux-upload-completeness.sh`, `verify-mux-asset-status.py`, `verify-hls-renditions.sh`, `smoke-video-playback.sh`
3. **Phase 3** (Studio upload): `pytest tests/test_mux_upload.py tests/test_mux_api_utils.py`, `verify-studio-upload.sh`, `verify-video-degradation.sh`
4. **Subtitles**: `pytest tests/test_mux_subtitle_utils.py`, `verify-video-subtitles.sh`, MV-002
5. **Phase 4** (Analytics): `verify-video-xapi-events.sh`, `verify-mux-data-dashboard.sh`, `verify-superset-video-dashboard.sh`
6. **Phase 5** (Protection): `verify-mux-signed-playback.sh`, `verify-no-mux-asset-ids.sh`, MV-003

---

## Self-Check

- [x] Every acceptance criterion (AC-001 through AC-025) has at least one test case
- [x] Every edge case from the spec has a negative/failure test
- [x] Test types match repo conventions (shell_verification, smoke_test, pytest, manual_verification)
- [x] Mocks/fixtures specified for all tests requiring external services (Mux API)
- [x] Manual verification procedures documented with step-by-step instructions
- [x] Test execution order follows phase dependencies
- [x] Source spec linked
