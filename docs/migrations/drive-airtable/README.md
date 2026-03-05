# Drive <-> Airtable Video Inventory Runbook
_Audience: Platform Eng + Data + AI Agents • Owner: Migration Squad • Last verified: 2026-03-05 (UTC)_

## Why This Exists

We have a large nested Google Drive corpus and need a repeatable way to map usable lesson videos into Airtable, then forward that clean mapping to Mux and Open edX.

This runbook defines the operating method so future agents do not re-discover the workflow from scratch.

## Document Set

- Runbook (method + contract): `docs/migrations/drive-airtable/README.md`
- Live status snapshot (review board): `docs/migrations/drive-airtable/STATUS.md`
- Human review checklist (waivers + subtitle orphans): `docs/migrations/drive-airtable/REVIEW_QUEUE.md`

## Canonical Base

- Airtable base (working inventory): `appmEKK1SN2MNwdMJ`
- Primary working table: `Videos`
- Supporting tables:
  - `Drive Folder Targets`
  - `Video Lesson Mapping`
  - `Open edX Courses`
  - `Open edX Mapping`
  - `Pipeline Review Summary`
  - `Projects` (maps to Open edX programs)
  - `Courses`, `Modules`, `📁 Lessons` (lesson targets)

## Data Contract (Do Not Drift)

### 1) `Videos` (core table)

Every active video row must end with deterministic mapping state and relationship links.

Required fields used by pipeline:

- `Linked Lesson` (record link to `📁 Lessons`)
- `Match Status` (`mapped`, `excluded`, and temporary review states when unresolved)
- `Matched Lesson IDs` (text or array snapshot)
- `Lesson Match Count` (numeric)
- `Pipeline Decision`
- `Decision Reason`
- `Open edX Handoff Bucket` (`ready_execute`, `blocked_waiver`, `blocked_content`, `unmapped`)
- `Open edX Migration Gate` (`ready`, `blocked`, `unmapped`)
- `Review Queue` (`ready_execute`, `waiver_pending`, `not_in_scope`)
- `Review Priority` (deterministic numeric order for `waiver_pending` items)
- `Review Decision` (`pending_review`, `approved`, `rejected`, `deferred`, `not_applicable`)
- `Review Owner` (free-text assignee)
- `Review Updated UTC` (decision timestamp)
- `Mux Migration Status` (`pending`, `in_progress`, `done`, `skipped`, `not_applicable`)
- `Open edX Publish Status` (`pending`, `in_progress`, `done`, `skipped`, `not_applicable`)
- `Open edX Waiver Decision` (`pending_review`, `approved`, `rejected`, `not_applicable`)
- project/course links (must not be empty for mapped videos)

Rule: `Videos` is the canonical surface for operators. Mapping rows are helper rows, not the end-user table.

### 2) `Drive Folder Targets` (queue + targeting)

Folder-first execution queue with lifecycle states:

- `ready_for_review`
- `completed`
- `rejected`
- `blocked_crosswalk`

Target lifecycle states:

- `candidate`
- `approved`
- `pilot_done`
- `rejected`

Classification values:

- `target`
- `review`
- `raw`
- `archive`
- `ignore`

Only folders classified as lesson-source targets are processed. Raw footage/source-assets folders should be rejected early.

### 3) `Video Lesson Mapping` (candidate resolution log)

One row per candidate video-to-lesson decision.

Key fields:

- `Pipeline Decision`
- `Status`
- `Review Bucket`

Policy for ambiguity:

- Default: if multiple plausible lessons exist, do not auto-pick.
- Exception: auto-resolve only when there is strong extra evidence (for example subtitle transcript overlap with a single clear winner), and log scoring evidence in `Decision Reason`.
- If still unresolved, set `Pipeline Decision=keep`, `Status=ambiguous`, `Review Bucket=needs_manual_choice`.
- Keep unresolved rows visible for human review.

### 4) `Pipeline Review Summary` (control panel)

Store durable counters/health signals here, including:

- folder queue counts
- mapping backlog counts
- subtitle review backlog
- videos table readiness counters

Required dashboard fields:

- `Metric` (stable key, for example `mapping.gate.ready`)
- `Value`
- `Updated UTC` (last refresh timestamp)
- `Source Table` (origin table for metric)
- `Metric Group` (for this pipeline: `drive_airtable_readiness`)
- `Notes` (short definition so future agents do not reinterpret metrics)

Recommended metric keys:

- `videos.total`, `videos.mapped`, `videos.excluded`, `videos.needs_manual_choice`
- `subtitles.total`, `subtitles.linked_lesson`, `subtitles.linked_video`, `subtitles.needs_video_match`
- `mapping.total`, `mapping.gate.ready`, `mapping.gate.blocked`, `mapping.waiver_allowed_publish`
- `courses.total`, `courses.gate.ready`, `courses.gate.blocked`
- `videos.mux_status.*`, `videos.publish_status.*`, `videos.waiver_decision.*`
- `courses.mux_status.*`, `courses.publish_status.*`, `courses.waiver_pending_rows.total`
- `reviews.waiver_pending.*`, `reviews.subtitle_orphan.rows`, `reviews.total.pending_items`
- `folders.queue.completed`, `folders.queue.ready_for_review`, `folders.queue.rejected`

### 5) `Open edX Courses` (course-level anchor)

One row per course intended for Open edX delivery.

Table: `Open edX Courses` (`tblSgou4LKJhlDfFk`)

Required fields:

- `Open edX Course Key`
- `Course Key Status`
- `Open edX Org`, `Open edX Course Number`, `Open edX Run`
- links to `Project`, `Course`, `Modules`, `Lessons`, `Videos`, `Subtitle Assets`, `Target Folders`
- `Course Mapping Status` (`ready`, `blocked`, `review_later`)
- `Mapping Rows` (link to `Open edX Mapping`)
- `Review Queue` (`ready_execute`, `waiver_pending`, `content_blocked`)

Policy:

- Review and approve at course level first.
- If any required lesson/video mapping row is blocked, keep `Course Mapping Status=blocked`.

### 6) `Open edX Mapping` (delivery contract table)

One row per lesson-video unit intended for Open edX publishing.

Table: `Open edX Mapping` (`tblqaV3oJAfqhz7eN`)

Required fields:

- `Open edX Course Key` (for example `course-v1:ORG+COURSE+RUN`)
- `Open edX Block Usage ID` (for example `block-v1:ORG+COURSE+RUN+type@video+block@<slug>`)
- `Open edX Org`, `Open edX Course Number`, `Open edX Run`
- `Course Key Status` (`proposed` or `confirmed`)
- links to `Project`, `Course`, `Module`, `Lesson`, `Video`, `Subtitle Asset`, `Target Folder`
- `Mapping Status` (`ready`, `blocked`, etc.)
- `Needs Human Review`
- `Review Queue` (`ready_execute`, `waiver_pending`, `content_blocked`)
- `Review Priority` (mirrored from linked `Videos.Review Priority` for waiver queue order)
- `Review Decision` (`pending_review`, `approved`, `rejected`, `deferred`, `not_applicable`)
- `Review Owner` (free-text assignee)
- `Review Updated UTC` (decision timestamp)

Policy:

- Use `proposed` identifiers until Open edX course IDs are confirmed.
- Mark missing transcript/video pairs as `blocked` with review notes.
- Keep this table as the Open edX handoff contract; use `Videos` as the operator-facing source table.

### 7) `Open edX Mapping` migration-readiness fields (required for Mux/Open edX rollout)

These fields were added to prevent ambiguous migration state:

- `Migration Gate`: `ready`, `ready_pending_key`, `blocked`
- `Migration Blockers`: multi-value reason list
- `Mux Migration Status`: `pending`, `queued`, `uploaded`, `failed`, `skipped`
- `Open edX Migration Status`: `pending`, `queued`, `imported`, `failed`, `skipped`
- `Migration Batch ID`: immutable batch label for audit/replay
- `Migration Last QA UTC`: latest QA timestamp written by pipeline
- `Content Gate`: `ready`, `blocked` (asset-level readiness only)
- `Handoff Bucket`: `ready_execute`, `blocked_waiver`, `blocked_content`
- `Waiver Decision`: `pending_review`, `approved`, `rejected`, `not_applicable`

Policy:

- `Content Gate=ready` does not imply publish-ready if course key is still unconfirmed.
- `Migration Gate=ready_pending_key` means technically complete assets but blocked for final publish until key confirmation.
- `Migration Blockers` must always explain non-ready rows; never leave gate-only rows without reasons.

### 8) `Open edX Courses` migration-readiness fields (course release control)

Course-level controls now mirror mapping-level controls:

- `Migration Gate`: `ready`, `pending_key_confirmation`, `blocked`
- `Migration Blockers`
- `Ready Mapping Ratio`
- `Migration Queue Status`
- `Migration Priority` (`p0`..`p3`)
- `Migration Last QA UTC`
- `Content Gate` (`ready`, `blocked`)
- `Content Ready Ratio`
- `Handoff Bucket` (`ready_execute`, `blocked_content`)

Policy:

- Course is publish-ready only when `Migration Gate=ready`.
- `pending_key_confirmation` indicates course mapping is content-ready but awaiting authoritative Open edX course key confirmation.
- Course-level blockers must be derived from linked mapping blockers, not ad-hoc free text.

## Operating Method (Course-First, Not File-First)

### Step 0: Define Target Scope

1. Pick one parent folder.
2. Identify course/module-level subfolders that represent real lesson delivery content.
3. Mark non-learning branches (`raw footage`, `b-roll`, drafts, source exports) as out of scope.

### Step 0.5: Discovery Sweep (Before Ingest)

1. Crawl the parent folder tree and compare folder IDs against `Drive Folder Targets`.
2. Create discovery rows only for delivery-root folders (for example `Final Videos`, `Final MP4 Exports`), not child asset folders (`Slides`, `Thumbnails`, `Project Files`).
3. Insert discovery rows with valid select values only:
   `Classification=review`, `Target Status=candidate`, `Queue Status=ready_for_review`.
4. If select value is invalid (for example trying to use `queued`), read schema options first and retry with allowed values.
5. For shared-drive folders, fetch metadata first and use `driveId` + `corpora=drive` when listing children. Otherwise queries can return empty even when folder exists.

### Step 1: Ingest One Target Folder

1. Recursively list video and subtitle files.
2. Upsert videos into `Videos`.
3. Maintain folder metadata so each row can be traced back to source folder.

### Step 2: Resolve Course/Module Context First

1. Map each video to `Project` and `Course` from folder lineage before lesson matching.
2. If context cannot be resolved, hold row for review; do not force lesson matching blind.

### Step 3: Lesson Matching

1. Run deterministic matching using filename/title + course/module scope.
2. If exactly one lesson candidate: mark `mapped` and set `Linked Lesson`.
3. If zero candidates and file is non-lesson media: mark `excluded`.
4. If multiple candidates: mark `needs_manual_choice` in `Videos` and `ambiguous` in mapping table.

### Step 4: Subtitle Pass

1. Detect subtitle files (`.vtt`, `.srt`) in same tree.
2. Attach/match subtitles to video records by normalized basename + language suffix.
3. Unclear subtitle pairings go to manual review bucket; do not silently drop.

### Step 4.5: Subtitle Backfill to Lessons

1. For `mapped` videos that have `Subtitle Assets`, compare against linked lesson `Subtitle Assets`.
2. Merge-mutate lessons only (union of existing + video subtitle links). Never delete lesson subtitle links in this step.
3. Re-audit until `remaining_lesson_subtitle_backfill=0`.

### Step 5: Folder Completion Gate

A folder can move to `completed` only when all are true:

1. No `unclassified` video statuses remain.
2. Every `mapped` video has `Linked Lesson` populated.
3. Every `mapped` video has project/course links populated.
4. Ambiguous items are either resolved, excluded by policy, or explicitly left in `ready_for_review`.

If unresolved keep/review rows remain, keep folder in `ready_for_review`.

### Step 6: No-Delta Duplicate Check for Newly Discovered Roots

1. Before ingesting a newly discovered delivery root, compare Drive file IDs against existing `Videos.File ID`.
2. If `new_video_files_not_in_airtable=0`, mark row as duplicate/no-delta and close it (`Queue Status=completed`, `Target Status=pilot_done`) with evidence in `Queue Notes`.
3. Only run ingest when there is real delta.

### Step 7: Open edX Mapping Pass (post-folder completion)

1. Create one `Open edX Mapping` row per mapped lesson-video in the selected target folder.
2. Populate link fields (`Project/Course/Module/Lesson/Video/Subtitle Asset/Target Folder`).
3. Build `Open edX Block Usage ID` deterministically from the proposed/confirmed course key and normalized lesson slug.
4. Set `Mapping Status=ready` only when video + lesson + transcript are all present.
5. Set `Mapping Status=blocked` + `Needs Human Review=yes` when any required delivery asset is missing.
6. Back-links to `Open edX Mapping` must appear in `Videos` and `📁 Lessons` for reviewer visibility.

## Current Baseline (Snapshot: 2026-03-05, post systematic integrity pass)

- `Videos` total: 453
- `mapped`: 124
- `excluded`: 329
- `needs_manual_choice` active queue: 0
- `Videos` rows with lesson link: 124
- Mapped videos missing project links: 0
- Mapped videos missing course links: 0
- Mapped videos missing target folder links: 0
- Decision/status consistency issues: 0
- `Video Lesson Mapping` status counts: `mapped=244`, `ambiguous=5`, `no_match=11`
- Active unresolved mapping queue (`keep/review` + unresolved status): 0
- Excluded unresolved backlog (`exclude` + `ambiguous/no_match`): 16
- Mapped videos with subtitles: 106
- Remaining lesson subtitle backfill: 0 (61 lessons backfilled in merge mode)
- Subtitle assets: `total=107`, `linked lesson=107`, `linked video=106`, `needs_video_match=1` (`PF 5.3.srt`)
- `Open edX Mapping`: `total=124`, `ready=106`, `blocked=18`
- `Open edX Courses`: `total=11`, `ready=7`, `blocked=4`
- Mapped videos missing `Open edX Mapping` link: 0
- Mapped videos missing `Open edX Courses` link: 0
- `Open edX Mapping` back-links verified in `Videos` and `📁 Lessons`
- Folder queue: `completed=15`, `ready_for_review=0`, `rejected=4`, `blocked_crosswalk=0`
- BC branch outcome: `(BC) Business Communications` root (`1y2iQ1_FYH6-GoeGVbg4k6PYtxQ7plU9D`) closed as `raw/rejected` after recursive audit (non-delivery asset branch)
- Discovery roots from Drive crawl: 2 discovered, 0 active candidate (SP closed as duplicate/no-delta, Marketing closed as empty/no-delta)

## Migration Readiness Snapshot (UTC 2026-03-05T07:07:29Z)

### Mapping-level gates (`Open edX Mapping`)

- Total rows: 124
- `Migration Gate=ready`: 106
- `Migration Gate=ready_pending_key`: 0
- `Migration Gate=blocked`: 18
- `Content Gate=ready`: 106
- `Content Gate=blocked`: 18
- rows with `Course Key Status=confirmed`: 124
- `Migration Batch ID`: `migration-readiness-2026-03-05-01` + normalization pass `2026-03-05T06:59:35Z`
- `Handoff Bucket` counts: `ready_execute=106`, `blocked_waiver=18`, `blocked_content=0`

### Course-level gates (`Open edX Courses`)

- Total rows: 11
- `Migration Gate=ready`: 7
- `Migration Gate=pending_key_confirmation`: 0
- `Migration Gate=blocked`: 4
- `Content Gate=ready`: 7
- `Content Gate=blocked`: 4
- course rows with `Course Key Status=confirmed`: 11
- `Handoff Bucket` counts: `ready_execute=7`, `blocked_content=4`
- `Mux Migration Status` counts: `pending=7`, `in_progress=3`, `skipped=1`
- `Open edX Publish Status` counts: `pending=7`, `in_progress=3`, `skipped=1`
- `Waiver Pending Rows` total: 18
- `Waiver Approved Rows` total: 0
- `Review Queue` counts: `ready_execute=7`, `waiver_pending=4`, `content_blocked=0`

### Video-level execution tracking (`Videos`)

- `Mux Migration Status`: `not_applicable=329`, `pending=106`, `skipped=18`
- `Open edX Publish Status`: `not_applicable=329`, `pending=106`, `skipped=18`
- `Open edX Waiver Decision`: `not_applicable=435`, `pending_review=18`
- `Review Queue`: `ready_execute=106`, `waiver_pending=18`, `not_in_scope=329`
- `Review Priority`: assigned for all `18` waiver-pending rows (1..18)
- `Review Decision`: `pending_review=18`, `not_applicable=435`
- `Pipeline Review Summary` metric group size: `drive_airtable_readiness=128` (full-pagination refresh + full-table linkage + orphan-drive-scan telemetry + review-owner queue-load telemetry + contract-health telemetry)

### Review decision telemetry

- `reviews.total.pending_items=19` tracks unique queue items for humans (18 waiver videos + 1 subtitle orphan).
- `reviews.decision.pending.total=37` tracks table-level decision rows pending (videos + mappings + subtitles).
- `reviews.decision.pending.unassigned.total=37` confirms every pending decision is explicitly owner-tagged (`Review Owner=unassigned`) and ready for assignment.
- `integrity.review_decision.video_mapping_mismatch=0` confirms waiver-linked video/mapping decision parity.
- `reviews.decision.completion_ratio_pct=0.0` tracks reviewer progress toward clearing pending decisions.
- `reviews.subtitle_orphan.pf53_video_candidates=0` and `reviews.subtitle_orphan.pf_video_scope_count=41` confirm no deterministically linkable PF 5.3 video candidate in latest exhaustive PF-video sweep (`reviews.subtitle_orphan.pf53_drive_scan_utc=2026-03-05T08:11:15Z`).
- `readiness.contract.ready_rows.pass_ratio_pct=100.0` and `readiness.contract.waiver_rows.metadata_drift.total=0` confirm execution-contract integrity for ready and waiver queues.

### Blocker distribution (blocked mapping rows)

- `missing_subtitle_asset`: 18
- `missing_transcript_url`: 18
- `mapping_status_blocked`: 18
- `waiver_allowed_publish`: 18

### Subtitle edge case still open

- `PF 5.3.srt` remains linked to lesson (and Open edX course) but not linked to any discoverable source video (`needs_video_match=1`).

### Known Open Items

1. `Open edX Courses` blocked keys (4) are currently:
   - `course-v1:FOW-ENG+LLP+2026T1` (`blocked_rows=12`)
   - `course-v1:FOW-IDN+PF-IDN+2026T1` (`blocked_rows=1`)
   - `course-v1:FOW-MAL+SP-MAL+2026T1` (`blocked_rows=1`)
   - `course-v1:FOW_ST-ENG+PP-ENG+2026T1` (`blocked_rows=4`)
2. `PF 5.3.srt` (`Subtitle Assets`: `recT8W0XETEaIkSDO`) has `Linked Lesson` but no matching source video found in accessible Drive files (global PF video search returned no `PF 5.3` filename variant); currently retained as `needs_video_match`.
3. Safe auto-resolution pass (2026-03-05) recovered 2 blocked rows (`F101-MAL`) by linking newly discovered subtitle files and updating mappings to `ready`.
4. `(BC) Business Communications` root has been audited and closed as non-delivery (`raw/rejected`): recursive scan found 59 folders / 85 videos with dominant prefixes `Rendered(61)`, `PF(9)`, `PW(7)`, and no BC-labelled delivery files.

## Immediate Review Queue (Operator Checklist)

1. Resolve `PF 5.3.srt` orphan subtitle by either linking to a recovered source video or keeping it in `needs_video_match`.
2. Decide per batch whether to migrate 18 waiver-tagged blocked rows as-is (`waiver_allowed_publish`) or recover subtitle/transcript assets first.
3. Keep migration execution status fields updated during manual migration:
   - `Mux Migration Status`
   - `Open edX Publish Status`

## Change Log

- 2026-03-05:
  - Added migration-readiness fields to `Open edX Mapping` and `Open edX Courses`.
  - Added deterministic migration/content gates and blocker reasons.
  - Added batch-scoped QA stamping (`migration-readiness-2026-03-05-01`, QA timestamp in UTC).
  - Backfilled migration gate values across current mapping/course inventory.
  - Confirmed all Open edX course keys in Airtable (`Course Key Status=confirmed` for all mapping/course rows).
  - Promoted 106 mapping rows from `ready_pending_key` to `ready`.
  - Normalized 18 blocked rows with waiver tagging (`waiver_allowed_publish`) while preserving content blockers.
  - Hardened `Pipeline Review Summary` with timestamped/source-attributed metric rows and refreshed 25 migration readiness counters.
  - Standardized `Open edX Mapping.Block Reason` on blocked rows (`missing_subtitle` for all 18) to improve queue filtering.
  - Added and populated `Handoff Bucket` fields on Open edX tables for explicit ready-vs-blocked execution filtering.
  - Added `Metric Group` tagging in `Pipeline Review Summary` (`drive_airtable_readiness`) to isolate 25 core migration metrics from legacy rows.
  - Added integrity governance metrics (`integrity.violations.total=0`, `integrity.audit.timestamp_utc`) and expanded `drive_airtable_readiness` dashboard group to 31 metrics.
  - Added and backfilled video-level handoff fields (`Open edX Handoff Bucket`, `Open edX Migration Gate`) so migration readiness is visible directly in `Videos`.
  - Expanded `drive_airtable_readiness` dashboard group to 36 metrics including video handoff/gate coverage.
  - Added blocked-course breakdown metrics (`courses.blocked_rows.*`) and expanded `drive_airtable_readiness` dashboard group to 40 metrics.
  - Added `Waiver Decision` workflow state on mapping rows and expanded `drive_airtable_readiness` dashboard group to 42 metrics.
  - Standardized `Mapping Notes` on blocked rows with explicit remediation and waiver workflow guidance for reviewer handoff.
  - Normalized `Open edX Courses.Migration Priority` by blocked-row volume and expanded `drive_airtable_readiness` dashboard group to 45 metrics.
  - Added aggregate execution tracking fields on `Videos` (`Mux Migration Status`, `Open edX Publish Status`, `Open edX Waiver Decision`) and `Open edX Courses` (`Mux Migration Status`, `Open edX Publish Status`, `Waiver Pending Rows`, `Waiver Approved Rows`).
  - Refreshed `Pipeline Review Summary` with full pagination (all 453 videos) and added execution-status aggregates; `drive_airtable_readiness` metric group now contains 96 metrics with `duplicate_metric_keys=0`.
  - Added explicit link-integrity metrics for mapped rows (`videos.mapped_missing_project_links`, `videos.mapped_missing_course_links`, `videos.mapped_missing_target_folder_links`) and verified all are `0`.
  - Normalized human-review queue signals across `Open edX Mapping` (waiver rows), `Videos` (waiver-pending tags), and `Subtitle Assets` (orphan subtitle tag), then added `reviews.*` dashboard metrics (`reviews.total.pending_items=19`).
  - Added `Videos.Review Queue` as an operator-first filter surface and backfilled all rows (`ready_execute=106`, `waiver_pending=18`, `not_in_scope=329`) with corresponding `videos.review_queue.*` dashboard metrics.
  - Added `Open edX Courses.Review Queue` for course-level triage (`ready_execute=7`, `waiver_pending=4`, `content_blocked=0`) and synced `courses.review_queue.*` dashboard metrics.
  - Added per-course waiver backlog metrics (`reviews.waiver_pending.by_course.*`) to prioritize reviewer order across blocked courses.
  - Added `Videos.Review Priority` and `Open edX Mapping.Review Queue` to enforce consistent review sequencing across core/operator and contract tables.
  - Added `Open edX Mapping.Review Priority` so mapping-level execution can follow the same deterministic waiver order as the `Videos` table.
  - Added explicit review-decision fields (`Review Decision`, `Review Owner`, `Review Updated UTC`) across Videos/Open edX Mapping/Subtitle Assets and synced `reviews.decision.*` + decision-integrity metrics.
  - Added review-outcome progress metrics (`reviews.decision.approved.total`, `...rejected.total`, `...deferred.total`, `...resolved.total`, `...tracked.total`, `...completion_ratio_pct`) for reviewer throughput visibility.
  - Backfilled missing `Subtitle Assets.Open edX Courses` links for the remaining three subtitle rows (`subtitles.linked.openedx_courses.missing=0`) while preserving `PF 5.3.srt` as `needs_video_match`.
  - Added full-table linkage quality metrics across `Videos`/`Open edX Mapping`/`Subtitle Assets` and refreshed `drive_airtable_readiness` group size to `113` (`duplicate_metric_keys=0`).

## Handoff Checklist For Next Agent

1. Start with discovery sweep on the next parent folder, then process any new `Drive Folder Targets` candidates.
2. Never bypass the course-first targeting step.
3. Keep unresolved rows explicit in review buckets (`needs_manual_choice`, `needs_video_match`) rather than leaving silent blanks.
4. Keep `Videos` as the final truth table and refresh `Pipeline Review Summary` counters after each batch.
5. Preserve excluded backlog as audit history, but prioritize only active keep/review queues.
6. Do not start Mux/Open edX writeback until folder queue is stable and active unresolved queues are near-zero.
7. Maintain `Open edX Mapping` as the canonical publish contract so future agents can continue without re-deriving lesson/video relationships.

## Open edX References (Official)

- Course key components and immutability (`org`, `course number`, `run`): https://docs.openedx.org/en/latest/educators/quickstarts/studio_quickstart/create_new_course.html
- Video setup and supported hosting strategy in Studio: https://docs.openedx.org/en/latest/educators/how-tos/course_development/exercise_tools/manage_video_component.html
- Transcript workflow for video components: https://docs.openedx.org/en/latest/educators/how-tos/course_development/exercise_tools/manage_transcripts.html
- Usage key format (`block-v1` and related identifiers): https://docs.openedx.org/projects/edx-platform/en/open-release-sumac.master/references/docs/xmodule/docs/usage_keys.html

## MCP Execution Pattern (Rube)

Use this pattern for repeatable agent runs:

1. `RUBE_SEARCH_TOOLS` with `session.generate_id=true` for a new workflow.
2. `RUBE_MANAGE_CONNECTIONS` for `googledrive` + `airtable` before execution.
3. `RUBE_MULTI_EXECUTE_TOOL` for all app calls (schema-compliant args only).
4. Persist stable IDs in `memory` (folder IDs, base/table IDs, field IDs).
5. Reuse the same `session_id` across the run for continuity.

Avoid ad-hoc API calls when an MCP tool already exists.
