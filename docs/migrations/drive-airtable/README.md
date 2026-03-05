# Drive <-> Airtable Video Inventory Runbook
_Audience: Platform Eng + Data + AI Agents • Owner: Migration Squad • Last verified: 2026-03-05_

## Why This Exists

We have a large nested Google Drive corpus and need a repeatable way to map usable lesson videos into Airtable, then forward that clean mapping to Mux and Open edX.

This runbook defines the operating method so future agents do not re-discover the workflow from scratch.

## Canonical Base

- Airtable base (working inventory): `appmEKK1SN2MNwdMJ`
- Primary working table: `Videos`
- Supporting tables:
  - `Drive Folder Targets`
  - `Video Lesson Mapping`
  - `Pipeline Review Summary`
  - `Projects` (maps to Open edX programs)
  - `Courses`, `Modules`, `📁 Lessons` (lesson targets)

## Data Contract (Do Not Drift)

### 1) `Videos` (core table)

Every active video row must end with deterministic mapping state and relationship links.

Required fields used by pipeline:

- `Linked Lesson` (record link to `📁 Lessons`)
- `Match Status` (`mapped`, `excluded`, `needs_manual_choice`)
- `Matched Lesson IDs` (text or array snapshot)
- `Lesson Match Count` (numeric)
- `Pipeline Decision`
- `Decision Reason`
- project/course links (must not be empty for mapped videos)

Rule: `Videos` is the canonical surface for operators. Mapping rows are helper rows, not the end-user table.

### 2) `Drive Folder Targets` (queue + targeting)

Folder-first execution queue with lifecycle states:

- `queued`
- `ready_for_review`
- `completed`
- `rejected`
- `blocked_crosswalk`

Only folders classified as lesson-source targets are processed. Raw footage/source-assets folders should be rejected early.

### 3) `Video Lesson Mapping` (candidate resolution log)

One row per candidate video-to-lesson decision.

Key fields:

- `Pipeline Decision`
- `Status`
- `Review Bucket`

Policy for ambiguity:

- If multiple plausible lessons exist, do not auto-pick.
- Set `Pipeline Decision=keep`, `Status=ambiguous`, `Review Bucket=needs_manual_choice`.
- Keep the row visible for human review.

### 4) `Pipeline Review Summary` (control panel)

Store durable counters/health signals here, including:

- folder queue counts
- mapping backlog counts
- subtitle review backlog
- videos table readiness counters

## Operating Method (Course-First, Not File-First)

### Step 0: Define Target Scope

1. Pick one parent folder.
2. Identify course/module-level subfolders that represent real lesson delivery content.
3. Mark non-learning branches (`raw footage`, `b-roll`, drafts, source exports) as out of scope.

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

### Step 5: Folder Completion Gate

A folder can move to `completed` only when all are true:

1. No `unclassified` video statuses remain.
2. Every `mapped` video has `Linked Lesson` populated.
3. Every `mapped` video has project/course links populated.
4. Ambiguous items are either resolved or explicitly left in `ready_for_review`.

If ambiguous rows remain, keep folder in `ready_for_review`.

## Current Baseline (Snapshot: 2026-03-05)

- `Videos` total: 453
- `mapped`: 121
- `excluded`: 329
- `needs_manual_choice`: 3
- `Videos` rows with lesson link: 121
- Mapped videos missing project links: 0
- Mapped videos missing course links: 0
- Folder queue: `completed=10`, `ready_for_review=3`, `rejected=3`, `blocked_crosswalk=0`

## Handoff Checklist For Next Agent

1. Start from `Drive Folder Targets` rows in `ready_for_review` first, then `queued`.
2. Never bypass the course-first targeting step.
3. Keep ambiguous mappings visible (`needs_manual_choice`) for human review.
4. Keep `Videos` as the final truth table and refresh summary counters after each batch.
5. Do not start Mux/Open edX writeback until folder queue is stable and ambiguity backlog is acceptable.

## MCP Execution Pattern (Rube)

Use this pattern for repeatable agent runs:

1. `RUBE_SEARCH_TOOLS` with `session.generate_id=true` for a new workflow.
2. `RUBE_MANAGE_CONNECTIONS` for `googledrive` + `airtable` before execution.
3. `RUBE_MULTI_EXECUTE_TOOL` for all app calls (schema-compliant args only).
4. Persist stable IDs in `memory` (folder IDs, base/table IDs, field IDs).
5. Reuse the same `session_id` across the run for continuity.

Avoid ad-hoc API calls when an MCP tool already exists.
