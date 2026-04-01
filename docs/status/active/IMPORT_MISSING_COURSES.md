# Import Lane — Missing Courses Decision Record

> **Status**: DECISIONS MADE  
> **Branch**: `feat/import-lane-closure`  
> **Last updated**: 2026-03-31  
> **Owner**: Import lane (LMS-I)

This document records the disposition of every course referenced by Kajabi
completion data or Airtable content records that was not built as an OLX
package during the main import pipeline.

---

## Summary

| Course(s) | Count | Decision |
|-----------|-------|----------|
| PB-EN | 1 | Map to MCT32-EN content; remap Kajabi completions |
| UPAI1-EN | 1 | OLX package not built; videos need Drive→OLX build step |
| UPAI3-EN | 1 | OLX package not built; videos need Drive→OLX build step |
| PP-EN | 1 | OLX package built; 2 videos uploaded to Mux |
| ST-AC, ST-CW, ST-DM, ST-OM, ST-SMM, ST-WD, ST-PP, ST-ACS | 8 | Deferred — no video content available |

---

## PB-EN — Personal Branding (English)

### Background

Kajabi has a product "Personal Branding" (`id: 2147807941`) with 2,958
completion records referencing `course-v1:MEREKA+PB-EN+course`.

The MCT platform has category 32 ("FOW (ENG) | Personal Branding") containing
23 video lessons across 5 modules, already imported as
`course-v1:SKILLOURFUTURE+MCT-32+course` (also exported as
`exports/mct/olx_packages/personal-branding/`).  The manifest also provides
`course-v1:MEREKA+MCT32-EN+course`.

Google Drive has 13 additional Personal Branding videos under course number
`PB-ENG` / `course-v1:MEREKA+PB-EN+course` (all uploaded to Mux in the Drive
upload batch).

### Evidence of shared content

| Indicator | MCT32-EN | PB-EN (Drive) |
|-----------|----------|---------------|
| Instructor | Suzanne Ling | Suzanne Ling |
| Shared lesson titles | "Meet Your Instructor: Suzanne Ling", "What is Personal Branding?", "Why Does It Matter?", "Personal Style", "Integrating Your Identity Into a Brand", "Communicating Your Authenticity", "Consistency in Your Personal Brand", "Conclusion" | (same 8 titles) |
| Total videos | 23 (MCT32-EN) | 13 (Drive batch, subset) |
| Mux assets | 23 from MCT upload | 13 from Drive upload (99 successful) |

The Drive batch represents a **separate re-production** of a subset of the
same course.  The MCT32-EN package is the more complete version (5 modules,
23 lessons vs. 13 loose videos with no module structure in Drive).

### Decision: Use MCT32-EN as canonical; remap PB-EN completions

**Action required:**

1. Ensure `course-v1:MEREKA+MCT32-EN+course` is imported and live in the
   target environment (it is already in the OLX manifest and
   `run_full_import.sh`).

2. Add a course key alias or update `post_import_completions.py` so that
   Kajabi completion records for `PB-EN` are credited to `MCT32-EN`:

   ```python
   # In post_import_completions.py, add to COURSE_KEY_REMAP:
   COURSE_KEY_REMAP = {
       "course-v1:MEREKA+PB-EN+course": "course-v1:MEREKA+MCT32-EN+course",
   }
   ```

3. Do **not** create a separate `PB-EN` course shell; it would duplicate
   content and split learner data.

4. Update the Kajabi `completions_import.csv` generator in
   `scripts/migrations/kajabi/map_kajabi_users_to_openedx.py` to map the
   `PB` prefix to `MCT32-EN`.

**Evidence file:** `exports/mct/video_mapping_openedx.json` → category `32`

---

## UPAI1-EN — Getting Started with ChatGPT (Beginner)

### Background

Kajabi has:
- Product `2148348806`: "Getting Started to Unlocking the Power of ChatGPT:
  Beginner edition"
- Completion tag prefix: `elevate-ai-1` → mapped to `course-v1:MEREKA+UPAI1-EN+course`
- 1 completion record exists in `completions_import.csv`.

Airtable had this course listed with 5 videos scheduled for Drive upload.
However, `exports/drive/videos_for_mux.json` contains **no entries** for
`UPAI1-EN` or `UPAIC1-ENG`.  The Drive upload batch (`mux_upload_results.json`)
has no successful uploads for this course number.

### Status

- OLX package: **not built**
- Drive videos in `videos_for_mux.json`: **0**
- Mux uploads: **0**
- Kajabi completions: **1** (test account `ailab@mereka.io`)

### Decision: Pending — content sourcing required

**Action required:**

1. Confirm with content team whether the "Getting Started with ChatGPT"
   videos exist in Google Drive and were omitted from `videos_for_mux.json`,
   or whether the content has not yet been recorded.

2. If videos exist in Drive:
   - Add them to `exports/drive/videos_for_mux.json` with
     `course_number: "UPAIC1-ENG"` and
     `new_course_key: "course-v1:MEREKA+UPAI1-EN+course"`.
   - Run `scripts/migrations/drive/upload_drive_videos_to_mux.py --course UPAIC1-ENG`.
   - Build the OLX package using `scripts/migrations/drive/build_course_packages.py`.

3. If videos do not exist yet: defer this course; document it in the staging
   gate blocker list.

**The single Kajabi completion is a test record; it does not block staging.**

---

## UPAI3-EN — ChatGPT for Job Search and Career Development

### Background

Kajabi has:
- Product `2148185632`: "ChatGPT for Job Search and Career Development"
- No completion tag prefix defined in `completions.ndjson` for this product.
- 0 completion records.

Airtable had this course listed with 7 videos scheduled for Drive upload.
`exports/drive/videos_for_mux.json` contains **no entries** for `UPAI3-EN`
or `UPAIC3-ENG`.  The Drive upload batch has no successful uploads for this
course.

`exports/drive/mux_playback_lookup.json` has no keys matching UPAI3 or
ChatGPT job search.

### Status

- OLX package: **not built**
- Drive videos in `videos_for_mux.json`: **0**
- Mux uploads: **0**
- Kajabi completions: **0**

### Decision: Pending — content sourcing required

**Action required:** Same as UPAI1-EN above.  Check with content team whether
the 7 videos are available in Google Drive.

**No completions exist for this course.  It does not block staging.**

---

## PP-EN — Project Placement

### Background

Not a missing course — PP-EN has 2 videos uploaded to Mux in the Drive batch:
- "Project placement Preparation" (mux_asset_id: `3IA02Ft01QiTC5PBNoHiUj8oLAmZsz600skjximecKI9VY`)
- "Project Placement and What To Expect From It" (mux_asset_id: `RGhXAHKDdWmMKaRPBnuWQcvr00m68UmfrovqozEBNrJ4`)

### Status

- Drive videos: 2 (both uploaded to Mux)
- OLX package: **not built** — the Drive OLX packages manifest
  (`exports/drive/olx_packages/course_packages_manifest.csv`) does not include
  PP-EN.

### Decision: Build OLX package

**Action required:**

1. Build the OLX package: run
   `scripts/migrations/drive/build_course_packages.py --course PP-EN`
   (or add an entry to the Drive manifest and re-run the full build).

2. The course key is `course-v1:MEREKA+PP-EN+course`.

3. No Kajabi completions reference PP-EN (the Kajabi product `2148580657`
   "Project Placement" has purchases but is not in the completion prefix map).

---

## Skills Test Courses (8 courses) — DEFERRED

The following 8 courses are referenced by Kajabi products in the `ready`
status but have **zero video content** in any export file:

| Course key | Kajabi product | Kajabi product ID |
|------------|----------------|-------------------|
| `course-v1:MEREKA+PP-EN+course` | Project Placement | 2148580657 |
| `course-v1:MEREKA+ST-AC+course` | Skills Test - Admin and Customer Support | 2148181265 |
| `course-v1:MEREKA+ST-CW+course` | Skills Test: Content Writing | 2148165761 |
| `course-v1:MEREKA+ST-DM+course` | Skills Test: Digital Marketing | 2148165749 |
| `course-v1:MEREKA+ST-OM+course` | Skills Test - Operation Management | 2148181267 |
| `course-v1:MEREKA+ST-SMM+course` | Skills Test - Social Media Management | 2148181263 |
| `course-v1:MEREKA+ST-WD+course` | Skills Test - Web Design & Development | 2148181261 |
| `course-v1:MEREKA+ST-PP+course` | Skills Profiling (Malay/ID variant) | 2148256173 |

### Evidence

- `exports/drive/videos_for_mux.json`: no entries for any `ST-*` course number.
- `exports/drive/mux_upload_results.json`: no successful uploads for ST-* courses.
- `exports/mct/olx_packages/`: no OLX packages for ST-* courses.
- `exports/kajabi/openedx_import/completions_import.csv`: 0 completion records
  for any ST-* or PP course key.
- The Kajabi products are in `ready` publish status but the Skills Test concept
  appears to have been a product shell without recorded lesson content (tests /
  assessments may have been the intended delivery mechanism, not video).

### Decision: Defer — no content available

**These courses will not be imported.**

Rationale:
1. Zero video content exists in any export source.
2. Zero learner completions exist for these courses.
3. The Kajabi products are likely shells used for access control /
   assessment tracking, not video course delivery.

**Staging gate impact:** None — these courses have no learner data to migrate.

**If content becomes available later:**
1. Record videos and upload to Mux via
   `scripts/migrations/drive/upload_drive_videos_to_mux.py`.
2. Build OLX packages.
3. Import to the target environment using the standard
   `run_full_import.sh --env <env>` pipeline.

---

## Relationship to IMPORT_STATUS_2026-04-01.md

This document resolves the "Missing courses decision" item from section
"Import-owned work REMAINING" in `IMPORT_STATUS_2026-04-01.md`.

Once the PB-EN remap is applied to `post_import_completions.py` and the
UPAI1/UPAI3 sourcing question is answered, the missing-courses gate is
cleared for staging.
