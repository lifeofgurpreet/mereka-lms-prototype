# Drive <-> Airtable Review Queue
_Audience: Operators + Reviewers + AI Agents • Snapshot: 2026-03-05T08:15:13Z (UTC)_

## Purpose

This file is the stable human-review checklist for items intentionally held out of automatic migration execution.

Use this with Airtable filters:

- `Videos.Review Queue=waiver_pending`
- sort by `Videos.Review Priority` ascending (1 is first)
- `Open edX Courses.Review Queue=waiver_pending`
- `Open edX Mapping.Review Queue=waiver_pending`
- sort `Open edX Mapping.Review Priority` ascending when executing mapping-level batches
- `Subtitle Assets.Match Status=needs_video_match`

## Queue Summary

- Waiver-pending videos: `18`
- Waiver-pending courses: `4`
- Subtitle orphans: `1`
- Total pending review items: `19`
- Table-level pending review decisions: `37` (`18` video rows + `18` mapping rows + `1` subtitle row)
- Pending decisions currently unassigned: `37` (`Review Owner=unassigned`)
- Decision completion ratio: `0.0%` (`resolved=0 / tracked=37`)

---

## Waiver Course Priority (by pending rows)

| Priority | Course Key | Blocked Rows | Courses Gate |
|---|---|---|---|
| p1 | `course-v1:FOW-ENG+LLP+2026T1` | 12 | `waiver_pending` |
| p2 | `course-v1:FOW_ST-ENG+PP-ENG+2026T1` | 4 | `waiver_pending` |
| p3 | `course-v1:FOW-IDN+PF-IDN+2026T1` | 1 | `waiver_pending` |
| p3 | `course-v1:FOW-MAL+SP-MAL+2026T1` | 1 | `waiver_pending` |

All 4 blocked courses share the same block reason: `missing_subtitle` on every blocked mapping row.
7 courses are `ready_execute` and unblocked — they can proceed to Mux upload and Open edX publish without any review action.

---

## Waiver-Pending Videos (18)

| Priority | Video | Course | Project | Video Record | Mapping Row |
|---|---|---|---|---|---|
| 1 | LLP 1.2.mp4 | LLP | FOW-ENG | `recavsrPmX4ShsaZD` | `recm5wCFgafos2mt5` |
| 2 | LLP 2.1.mp4 | LLP | FOW-ENG | `recmdd7Cyb4LRRMx5` | `recX0JkntDeWp9kJg` |
| 3 | LLP 2.2_1.mp4 | LLP | FOW-ENG | `recY1CfesV08JjQDW` | `recymnOhgtrPcXKPq` |
| 4 | LLP 2.3.mp4 | LLP | FOW-ENG | `recqrGEGEcQx4knQz` | `rectaXMcZwUzE1gFz` |
| 5 | LLP 2.4.mp4 | LLP | FOW-ENG | `recRYCET0DBlXEcan` | `recBmsOnbtgLRSI5z` |
| 6 | LLP 2.6.mp4 | LLP | FOW-ENG | `recnTnQq6RZOaMuXw` | `recc6mcLt61Y5JiNX` |
| 7 | LLP 2.7 Draft 2.mp4 | LLP | FOW-ENG | `recKm7X08sTi0JnT9` | `reco7xEDipuvdWzsW` |
| 8 | LLP 3.1.mp4 | LLP | FOW-ENG | `rectiQ1Knfh9kRadq` | `recvIs9cQWqH4NeP0` |
| 9 | LLP 3.2.mp4 | LLP | FOW-ENG | `recMBKHijGk4JVBY8` | `rectPyGaOzzyDyE3L` |
| 10 | LLP 4.2.mp4 | LLP | FOW-ENG | `recV7FWbzmZGRLPj3` | `rec0nRPJ5KlLgmr5O` |
| 11 | LLP 4.3_1.mp4 | LLP | FOW-ENG | `reczrCILz4drjENgz` | `recsITFuIaO8BEpLI` |
| 12 | LLP 5.1.mp4 | LLP | FOW-ENG | `recdvxz7Ndxru81SW` | `recj65KjRheKpqL5H` |
| 13 | ProP-ENG-1.3-v1.mp4 | PP-ENG | FOW_ST-ENG | `recAbzD78wOzrAqKW` | `recq5wWZdg2RbltdB` |
| 14 | ProP-ENG-2.3-v1.mp4 | PP-ENG | FOW_ST-ENG | `recmFY3wsF1wS5t1t` | `recwTU2L18xi4mqlX` |
| 15 | ProP-ENG-2.7-v1.mp4 | PP-ENG | FOW_ST-ENG | `recJOA3eGPmtCoTFY` | `recsQ1BKT0KM0IHHr` |
| 16 | ProP-ENG-3.1-v2.mp4 | PP-ENG | FOW_ST-ENG | `rectcPCd2qXmqu0Dl` | `recAx8RpOOOEvfyW5` |
| 17 | PF 5.15 V6.mp4 | PF-IDN | FOW-IDN | `recODVfrikx62JyQG` | `recmdgiRq1Idp9tXU` |
| 18 | 1.3 Meet your Instructor Jey Bala.mp4 | SP-MAL | FOW-MAL | `rec2O6iqes0eOZjq5` | `recmjFRMWn1P7CecE` |

### Per-course blocking metrics

**`course-v1:FOW-ENG+LLP+2026T1`** (priorities 1–12, 12 rows)
- Block reason: `missing_subtitle` on all 12 rows
- `Content Gate=blocked`, `Migration Gate=blocked`, `Handoff Bucket=blocked_waiver`
- Course `Mux Migration Status=in_progress` (partially started before block was hit)
- Waiver approval here unblocks the largest single batch (12/18 rows)

**`course-v1:FOW_ST-ENG+PP-ENG+2026T1`** (priorities 13–16, 4 rows)
- Block reason: `missing_subtitle` on all 4 rows
- `Content Gate=blocked`, `Migration Gate=blocked`, `Handoff Bucket=blocked_waiver`
- Course `Mux Migration Status=in_progress`

**`course-v1:FOW-IDN+PF-IDN+2026T1`** (priority 17, 1 row)
- Block reason: `missing_subtitle` on 1 row (PF 5.15 V6.mp4)
- Note: `PF 5.3.srt` orphan subtitle is also linked to this course (separate item 2 below)
- Course `Mux Migration Status=in_progress`

**`course-v1:FOW-MAL+SP-MAL+2026T1`** (priority 18, 1 row)
- Block reason: `missing_subtitle` on 1 row
- Course `Mux Migration Status=skipped` (lowest priority)

### Resolution paths for waiver-pending rows

**Option A — Approve waiver (migrate without subtitles)**

For each row (or per course in bulk):
1. In `Videos` table: set `Open edX Waiver Decision=approved`, `Review Decision=approved`, `Review Owner=<name>`, `Review Updated UTC=<now UTC>`.
2. In `Open edX Mapping` table: set `Waiver Decision=approved`, `Review Decision=approved`, `Review Owner=<name>`, `Review Updated UTC=<now UTC>`.
3. After bulk update verify `integrity.review_decision.video_mapping_mismatch=0` in `Pipeline Review Summary`.
4. Update `Mux Migration Status` and `Open edX Publish Status` as execution proceeds.
5. Keep `waiver_allowed_publish` tag on `Handoff Bucket` field for auditability — do not remove it.

**Option B — Recover subtitle/transcript assets first**

For each blocked row:
1. Locate the source subtitle/transcript file (check Drive, vendor deliveries, MCT exports).
2. Ingest subtitle into `Subtitle Assets`, link to the corresponding `Videos` row.
3. Run safe auto-resolution pass (same method as the F101-MAL recovery on 2026-03-05 that recovered 2 rows).
4. When resolved: `Mapping Status` transitions from `blocked` to `ready`, `Content Gate` flips to `ready`.
5. If all 18 rows are resolved: `Open edX Courses.Migration Gate` flips to `ready` for affected courses.

**Option C — Defer (keep blocked, do not migrate)**
1. Set `Review Decision=deferred` on video + mapping rows.
2. Set `Open edX Waiver Decision=rejected` if policy is no migration without subtitles.
3. These courses remain `waiver_pending` in the course review queue until subtitles are recovered.

---

## Subtitle Orphans (1)

| Subtitle | Course | Project | Subtitle Record | Linked Lesson | Status |
|---|---|---|---|---|---|
| PF 5.3.srt | PF-IDN | FOW-IDN | `recT8W0XETEaIkSDO` | `recrwoHLgu0RXQ4HP` | `needs_video_match` |

Latest scan evidence on subtitle row note:
- `[DRIVE_SCAN] pf53_video_candidates=0; pf_video_scope_count=41; scanned_utc=2026-03-05T08:11:15Z`

### Why this is separate from the waiver rows

This subtitle is already linked to its lesson and Open edX course. The orphan state is specifically about the missing `Linked Video` pointer — there is no source video record in `Videos` to attach the subtitle to. This is distinct from the 18 waiver rows where videos exist but subtitles are missing.

### Resolution paths for PF 5.3.srt

**Option A — Accept as orphan (recommended if no source video exists)**
1. Keep `Subtitle Assets.needs_video_match=1` as the declared state.
2. In the `Subtitle Assets` row: set `Review Decision=resolved`, `Review Owner=<name>`, `Review Updated UTC=<now UTC>`.
3. Add `Review Notes`: "No source video found after exhaustive Drive sweep (41 PF videos scanned 2026-03-05). Subtitle retained for lesson linkage only. Not blocking migration."
4. The subtitle remains linked to lesson and course but will not be associated with a Mux video upload.
5. Decrement `reviews.subtitle_orphan.rows` metric in `Pipeline Review Summary` to `0` after decision is logged.

**Option B — Recover source video**
1. Search for `PF 5.3` filename variants outside the scanned Drive scope (shared drives, archived folders, external vendor uploads, MCT deliveries).
2. If found: upload to Drive, ingest into Airtable `Videos` (follow ingest steps in `README.md`), link to `recT8W0XETEaIkSDO`.
3. Once linked: clear `needs_video_match` state, set `Review Decision=resolved`.
4. Re-run integrity audit to confirm `subtitles.linked_video=107`.

---

## Reviewer Assignment Workflow

### Before you start

1. Open the Airtable base `appmEKK1SN2MNwdMJ`.
2. Filter `Videos` by `Review Queue=waiver_pending` — surfaces 18 rows in `Review Priority` order.
3. Filter `Videos` by `Review Queue=subtitle_orphan` (or `Subtitle Assets` by `Match Status=needs_video_match`) — surfaces `PF 5.3.srt`.
4. Filter `Open edX Mapping` by `Review Queue=waiver_pending` — parallel mapping view for the same 18 items.

Resolve the subtitle orphan first (single decision, low-cost) then work through waiver rows in priority order.

### Claiming a row

1. Set `Review Owner=<your name or team handle>` on both the `Videos` row and the linked `Open edX Mapping` row simultaneously to avoid split ownership.
2. Set `Review Updated UTC=<current UTC timestamp>` when you begin review.
3. Do not set `Review Decision` until you have a final call — an intermediate "in progress" state is communicated via `Review Owner` only.

### Recording a decision

For each item record the same decision on all linked tables in a single pass:

| Table | Fields to update |
|---|---|
| `Videos` | `Review Decision`, `Review Owner`, `Review Updated UTC` |
| `Open edX Mapping` | `Review Decision`, `Review Owner`, `Review Updated UTC` |
| `Subtitle Assets` (orphan only) | `Review Decision`, `Review Owner`, `Review Updated UTC` |

Valid `Review Decision` values: `approved`, `rejected`, `deferred`.

For waiver approvals also update `Open edX Waiver Decision` (Videos) and `Waiver Decision` (Open edX Mapping).

### Integrity check after decisions

After recording decisions:
1. In `Pipeline Review Summary` verify `integrity.review_decision.video_mapping_mismatch=0`.
2. Check `reviews.decision.completion_ratio_pct` is incrementing.
3. Refresh `reviews.*` metric group if running pipeline tooling.

### When queue is cleared

Once all 19 items have a non-`pending_review` decision:
- `reviews.decision.completion_ratio_pct` reaches `100.0`
- `reviews.total.pending_items` drops to `0`
- Courses with approved waivers transition to `ready_execute` for Mux and Open edX publish pipeline
- See `README.md` → "Next Pipeline Step After Review" for execution steps

---

## Airtable Dashboard References

| Table | Filter | Purpose |
|---|---|---|
| `Videos` | `Review Queue=waiver_pending` | 18 waiver rows in priority order |
| `Videos` | `Review Queue=subtitle_orphan` | Orphan subtitle row |
| `Open edX Mapping` | `Review Queue=waiver_pending` | Parallel mapping view |
| `Open edX Courses` | `Review Queue=waiver_pending` | 4 blocked courses |
| `Pipeline Review Summary` | `Metric Group=drive_airtable_readiness` | 128 live dashboard metrics |

---

## Reviewer Actions (Checklist)

1. Process waiver-pending videos in `Review Priority` order and decide waiver outcome (`approved`, `rejected`, or `deferred`) for each item.
2. Update both mapping/video review fields to keep tables in sync: `Review Decision`, `Review Owner`, and `Review Updated UTC`.
3. For the subtitle orphan, either link the recovered source video or mark as accepted orphan with rationale.
4. After decisions, refresh dashboard metrics (`reviews.*`, `videos.review_queue.*`, `mapping.review_queue.*`) and verify `duplicate_metric_keys=0`.

---

## Related Documents

- [README.md](README.md) — Operating method, data contract, field definitions, change log
- [STATUS.md](STATUS.md) — Live snapshot of all counts (updated per batch run)
- `scripts/qa/verify-airtable-readiness.sh` — CI gate script verifying STATUS.md structural integrity
