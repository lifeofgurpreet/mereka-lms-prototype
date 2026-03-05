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

## Waiver Course Priority (by pending rows)

1. `course-v1:FOW-ENG+LLP+2026T1` → `12`
2. `course-v1:FOW_ST-ENG+PP-ENG+2026T1` → `4`
3. `course-v1:FOW-IDN+PF-IDN+2026T1` → `1`
4. `course-v1:FOW-MAL+SP-MAL+2026T1` → `1`

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

## Subtitle Orphans (1)

| Subtitle | Course | Project | Subtitle Record | Linked Lesson | Status |
|---|---|---|---|---|---|
| PF 5.3.srt | PF-IDN | FOW-IDN | `recT8W0XETEaIkSDO` | `recrwoHLgu0RXQ4HP` | `needs_video_match` |

Latest scan evidence on subtitle row note:
- `[DRIVE_SCAN] pf53_video_candidates=0; pf_video_scope_count=41; scanned_utc=2026-03-05T08:11:15Z`

## Reviewer Actions

1. Process waiver-pending videos in `Review Priority` order and decide waiver outcome (`approved` or `rejected`) for each item.
2. Update both mapping/video review fields to keep tables in sync:
   `Review Decision`, optional `Review Owner`, and `Review Updated UTC`.
3. For the subtitle orphan, either link the recovered source video or keep as unresolved with rationale.
4. After decisions, refresh dashboard metrics (`reviews.*`, `videos.review_queue.*`, `mapping.review_queue.*`) and verify `duplicate_metric_keys=0`.
