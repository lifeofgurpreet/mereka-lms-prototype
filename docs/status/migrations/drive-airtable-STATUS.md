# Drive <-> Airtable Migration Status
_Audience: Operators + Reviewers + AI Agents • Last updated: 2026-03-05T08:15:13Z (UTC)_

## Current Position

### Core inventory

- `Videos`: 453 total
- `mapped`: 124
- `excluded`: 329
- `needs_manual_choice`: 0
- mapped videos missing project links: 0
- mapped videos missing course links: 0
- mapped videos missing target folder links: 0
- `Videos.Open edX Handoff Bucket` counts: `ready_execute=106`, `blocked_waiver=18`, `unmapped=329`
- `Videos.Open edX Migration Gate` counts: `ready=106`, `blocked=18`, `unmapped=329`
- `Videos.Mux Migration Status`: `not_applicable=329`, `pending=106`, `skipped=18`
- `Videos.Open edX Publish Status`: `not_applicable=329`, `pending=106`, `skipped=18`
- `Videos.Open edX Waiver Decision`: `not_applicable=435`, `pending_review=18`
- `Videos.Review Queue`: `ready_execute=106`, `waiver_pending=18`, `not_in_scope=329`
- `Videos.Review Priority`: assigned on all `18` waiver-pending rows (`max=18`)
- `Videos.Review Decision`: `pending_review=18`, `not_applicable=435`

### Subtitle integrity

- subtitle assets total: 107
- linked to lesson: 107
- linked to video: 106
- linked to Open edX courses: 107
- subtitle review queue (`needs_video_match`): 1 (`PF 5.3.srt`)
- latest PF 5.3 drive sweep: `2026-03-05T08:11:15Z` (`pf_video_scope_count=41`, `pf53_video_candidates=0`)

### Open edX contract integrity

- `Open edX Mapping`: 124 total
- `Mapping Status=ready`: 106
- `Mapping Status=blocked`: 18
- mapped videos missing `Open edX Mapping` link: 0
- mapped videos missing `Open edX Courses` link: 0
- mapping rows with `Course Key Status=confirmed`: 124

## Migration Readiness Gates

### Mapping-level (`Open edX Mapping`)

- `Migration Gate=ready_pending_key`: 0
- `Migration Gate=ready`: 106
- `Migration Gate=blocked`: 18
- `Content Gate=ready`: 106
- `Content Gate=blocked`: 18
- `Handoff Bucket=ready_execute`: 106
- `Handoff Bucket=blocked_waiver`: 18
- `Waiver Decision=pending_review`: 18
- `Waiver Decision=not_applicable`: 106
- `Open edX Mapping.Review Queue`: `ready_execute=106`, `waiver_pending=18`, `content_blocked=0`
- `Open edX Mapping.Review Priority`: assigned on all `18` waiver-pending rows
- `Open edX Mapping.Review Decision`: `pending_review=18`, `not_applicable=106`

### Course-level (`Open edX Courses`)

- total courses: 11
- `Migration Gate=ready`: 7
- `Migration Gate=pending_key_confirmation`: 0
- `Migration Gate=blocked`: 4
- `Content Gate=ready`: 7
- `Content Gate=blocked`: 4
- course rows with `Course Key Status=confirmed`: 11
- `Handoff Bucket=ready_execute`: 7
- `Handoff Bucket=blocked_content`: 4
- `Mux Migration Status`: `pending=7`, `in_progress=3`, `skipped=1`
- `Open edX Publish Status`: `pending=7`, `in_progress=3`, `skipped=1`
- `Waiver Pending Rows` total: 18
- `Waiver Approved Rows` total: 0
- `Open edX Courses.Review Queue`: `ready_execute=7`, `waiver_pending=4`, `content_blocked=0`

### Batch audit markers

- `Migration Batch ID`: `migration-readiness-2026-03-05-01`
- `Migration Last QA UTC`: `2026-03-05T07:03:59Z`
- `Pipeline Review Summary` metrics refreshed/upserted through: `2026-03-05T08:15:13Z` (contract-health metrics sync)
- `Pipeline Review Summary` metric group tagging: `drive_airtable_readiness=128` (`2026-03-05T08:15:13Z`)
- Integrity audit metric: `integrity.violations.total=0` (`2026-03-05T07:10:59Z`)
- Post-change integrity audit: `mapping_waiver_state_mismatch=0`, `video_handoff_mismatch=0` (`2026-03-05T07:16:48Z`)
- Metric-key integrity audit: `duplicate_metric_keys=0` (post-refresh on 2026-03-05 UTC)

### Review queue metrics (P1)

- `reviews.waiver_pending.mapping_rows`: 18
- `reviews.waiver_pending.video_rows`: 18
- `reviews.subtitle_orphan.rows`: 1
- `reviews.total.pending_items`: 19
- `courses.review_queue.ready_execute`: 7
- `courses.review_queue.waiver_pending`: 4
- `courses.review_queue.content_blocked`: 0
- `reviews.waiver_pending.by_course.course_v1_FOW_ENG_LLP_2026T1`: 12
- `reviews.waiver_pending.by_course.course_v1_FOW_ST_ENG_PP_ENG_2026T1`: 4
- `reviews.waiver_pending.by_course.course_v1_FOW_IDN_PF_IDN_2026T1`: 1
- `reviews.waiver_pending.by_course.course_v1_FOW_MAL_SP_MAL_2026T1`: 1
- `mapping.review_queue.ready_execute`: 106
- `mapping.review_queue.waiver_pending`: 18
- `mapping.review_queue.content_blocked`: 0
- `mapping.review_priority.assigned_rows`: 18
- `videos.review_priority.assigned_rows`: 18
- `videos.review_priority.max`: 18
- `reviews.decision.pending.video_rows`: 18
- `reviews.decision.pending.mapping_rows`: 18
- `reviews.decision.pending.subtitle_rows`: 1
- `reviews.decision.pending.total`: 37
- `integrity.review_decision.video_mapping_mismatch`: 0
- `reviews.decision.approved.total`: 0
- `reviews.decision.rejected.total`: 0
- `reviews.decision.deferred.total`: 0
- `reviews.decision.resolved.total`: 0
- `reviews.decision.tracked.total`: 37
- `reviews.decision.completion_ratio_pct`: 0.0
- `reviews.decision.pending.unassigned.video_rows`: 18
- `reviews.decision.pending.unassigned.mapping_rows`: 18
- `reviews.decision.pending.unassigned.subtitle_rows`: 1
- `reviews.decision.pending.unassigned.total`: 37

### Contract health metrics (P2)

- `readiness.contract.ready_rows.total`: 106
- `readiness.contract.ready_rows.hard_missing.total`: 0
- `readiness.contract.ready_rows.soft_missing.total`: 0
- `readiness.contract.ready_rows.subtitle_link_mismatch`: 0
- `readiness.contract.ready_rows.pass_ratio_pct`: 100.0
- `readiness.contract.waiver_rows.total`: 18
- `readiness.contract.waiver_rows.metadata_drift.total`: 0

## Blockers (Active)

- `missing_subtitle_asset`: 18 mapping rows
- `missing_transcript_url`: 18 mapping rows
- `mapping_status_blocked`: 18 mapping rows
- `waiver_allowed_publish`: 18 mapping rows

Blocked course keys:

- `course-v1:FOW-ENG+LLP+2026T1` (`blocked_rows=12`)
- `course-v1:FOW-IDN+PF-IDN+2026T1` (`blocked_rows=1`)
- `course-v1:FOW-MAL+SP-MAL+2026T1` (`blocked_rows=1`)
- `course-v1:FOW_ST-ENG+PP-ENG+2026T1` (`blocked_rows=4`)

## Decisions Applied

- Closed `(BC) Business Communications` parent as non-delivery (`raw/rejected`) after recursive audit.
- Preserved ambiguous/non-delivery history in helper tables while keeping `Videos` as canonical operator table.
- Ran safe auto-resolution for deterministic subtitle recovery and moved 2 `F101-MAL` mapping rows from `blocked` to `ready`.
- Confirmed all Open edX keys in Airtable (`Course Key Status=confirmed` for all 124 mapping rows and all 11 course rows).
- Promoted 106 mapping rows from `ready_pending_key` to `ready`.
- Applied waiver tagging on blocked rows (`waiver_allowed_publish`) while preserving content blockers.
- Refreshed `Pipeline Review Summary` into a stable dashboard contract using `Metric/Value/Updated UTC/Source Table/Notes`.
- Standardized blocked mapping `Block Reason` values to `missing_subtitle` (18/18 blocked rows).
- Added and populated `Handoff Bucket` fields on Open edX tables for explicit ready-vs-blocked execution filtering.
- Added `Metric Group` tagging in `Pipeline Review Summary` so readiness metrics are filterable as a single dashboard group.
- Added integrity and block-reason governance metrics into `Pipeline Review Summary` (`integrity.*`, `mapping.block_reason.*`, `videos.mapped_with_full_core_links`).
- Added and backfilled `Videos`-level Open edX handoff/gate fields so operators can review migration readiness from the main table.
- Added blocked-course breakdown metrics (`courses.blocked_rows.*`) for prioritization in the dashboard layer.
- Added `Open edX Mapping.Waiver Decision` workflow field and backfilled deterministic values (`pending_review` for waiver rows, `not_applicable` otherwise).
- Standardized actionable `Mapping Notes` for all 18 blocked rows (explicit remediation + waiver workflow guidance).
- Normalized course migration priorities by blocker volume (`p1=1`, `p2=3`, `p3=7`) and added priority distribution metrics.
- Added aggregate execution tracking fields on `Videos` and `Open edX Courses` for Mux/publish/waiver state visibility.
- Upserted 17 new dashboard metrics from full-pagination reads (`453` videos across `5` pages) and verified summary metric uniqueness (`duplicate_metric_keys=0`).
- Added and refreshed mapped-link integrity metrics (`project/course/target folder`), all at `0`.
- Normalized review queue fields: `Open edX Mapping` waiver rows forced to explicit review state, corresponding `Videos` tagged with `[REVIEW_QUEUE] waiver_pending`, and orphan subtitle tagged `[REVIEW_QUEUE] subtitle_orphan`.
- Added P1 dashboard review metrics (`reviews.*`) and updated dashboard metric-group count to `69`.
- Added `Videos.Review Queue` field (`ready_execute`, `waiver_pending`, `not_in_scope`) and backfilled all 453 rows for operator-first filtering in the core table.
- Added `videos.review_queue.*` dashboard metrics and updated dashboard metric-group count to `72`.
- Added `Open edX Courses.Review Queue` field (`ready_execute`, `waiver_pending`, `content_blocked`) for course-level triage and synced `courses.review_queue.*` metrics.
- Refreshed dashboard metric-group count to `75` after course-level review queue instrumentation.
- Added per-course waiver backlog metrics (`reviews.waiver_pending.by_course.*`) to prioritize review order and refreshed dashboard metric-group count to `79`.
- Added `Videos.Review Priority` (deterministic reviewer order across waiver-pending rows) and backfilled all 18 queue rows.
- Added `Open edX Mapping.Review Queue` for mapping-level queue parity with videos/courses and synced `mapping.review_queue.*` metrics.
- Added `Open edX Mapping.Review Priority` (mirrored from linked `Videos.Review Priority`) and synced `mapping.review_priority.assigned_rows`.
- Refreshed dashboard metric-group count to `85` after mapping-priority instrumentation.
- Added review-decision workflow fields (`Review Decision`, `Review Owner`, `Review Updated UTC`) to Videos/Open edX Mapping/Subtitle Assets and synced `reviews.decision.*` metrics.
- Added cross-table decision parity metric (`integrity.review_decision.video_mapping_mismatch=0`) and refreshed dashboard metric-group count to `90`.
- Added review-outcome progress metrics (`approved/rejected/deferred/resolved/tracked/completion_ratio_pct`) and refreshed dashboard metric-group count to `96`.
- Completed subtitle Open edX course-link backfill (`subtitles.linked.openedx_courses.missing=0`) while preserving orphan subtitle review state for `PF 5.3.srt`.
- Added full-table linkage metrics for videos/mappings/subtitles and refreshed dashboard metric-group count to `113` (`duplicate_metric_keys=0`).
- Added exhaustive orphan evidence marker on `PF 5.3.srt` (`[DRIVE_SCAN] pf53_video_candidates=0; pf_video_scope_count=41`) and synced orphan scan metrics into dashboard.
- Refreshed dashboard metric-group count to `116` (`duplicate_metric_keys=0`) after orphan scan telemetry upsert.
- Normalized `Review Owner` for all pending-review rows to `unassigned` (videos=18, mappings=18, subtitles=1) and refreshed queue-load metrics.
- Refreshed dashboard metric-group count to `120` (`duplicate_metric_keys=0`) after review-owner telemetry upsert.
- Added mapping contract-health metrics for `ready_execute` rows (`hard/soft missing`, subtitle-link parity, pass ratio) and waiver metadata drift checks.
- Refreshed dashboard metric-group count to `128` (`duplicate_metric_keys=0`) after contract-health telemetry upsert.

## Reviewer Queue (What needs human confirmation now)

1. Resolve orphan subtitle `PF 5.3.srt` (link recovered source video or keep as `needs_video_match`).
2. Decide if 18 waiver-tagged blocked mappings should remain blocked for content QA or be moved to execution-ready by waiver at migration time.

## Review Telemetry Note

- `reviews.total.pending_items=19` is unique human queue size.
- `reviews.decision.pending.total=37` is table-level pending decision rows across videos/mappings/subtitles.

## Next Pipeline Step After Review

1. Keep Airtable as source-of-truth and run migration batches manually when ready.
2. For each batch, set status fields while executing:
   - `Mux Migration Status`
   - `Open edX Publish Status`
3. Keep waiver-tagged rows auditable (`waiver_allowed_publish`) if migrated without subtitle/transcript assets.
