# MCT Platform Integration Spec

_Last verified: 2026-02-08 | Owner: Platform Eng_

## Status: Migration Complete, Ongoing Sync

The Microsoft Community Training (MCT) platform at `learn.skillourfuture.org` has been fully migrated to Open edX. This spec documents the verified architecture, authentication, data model, and export pipeline for ongoing data synchronization.

## 1. Authentication

### Azure AD Service-to-Service (OAuth2 Client Credentials)

| Parameter | Value | Notes |
|-----------|-------|-------|
| Token endpoint | `https://login.microsoft.com/{tenant_id}/oauth2/v2.0/token` | |
| Tenant ID | `b1aab053-6242-46ec-9cf8-bd02e63dd2da` | BBI Azure AD |
| Client ID | `caa4dce3-e49c-4c09-9160-031d51bfd2a9` | **SOF S2S-Client** (the ONLY whitelisted client) |
| API URI / Scope | `api://bf8331fd-17ed-4bcf-af5f-599db14ff4f4/.default` | UNDP App Registration (audience) |
| Grant type | `client_credentials` | |
| Secret expiry | **2026-08-07** | Stored in Infisical |

### CRITICAL: ServiceApplicationIds Whitelist

MCT's Azure App Service has a `ServiceApplicationIds` setting that whitelists which client app IDs can call the API. **Only `caa4dce3` (SOF S2S-Client) is whitelisted.** The UNDP S2S-Client (`f16cdc2f`) will always get HTTP 401.

### Required HTTP Headers

| Header | Value | Purpose |
|--------|-------|---------|
| `Authorization` | `Bearer {token}` | OAuth2 access token |
| `Accept` | `application/json` | Response format |
| `ClientType` | `service` | **Required** — without this, API returns 401 |

### Secrets Location

All credentials stored in Infisical:
- **MCT**: `/mereka-lms/mct/` (6 secrets: MCT_CLIENT_ID, MCT_CLIENT_SECRET, MCT_TENANT_ID, MCT_API_URI, MCT_BASE_URL, MCT_SECRET_EXPIRES)
- **Mux**: `/mereka-lms/mux/` (3 secrets: MUX_TOKEN_ID, MUX_TOKEN_SECRET, MUX_ENV_ID)

## 2. API Endpoints (Verified Working)

Base URL: `https://learn.skillourfuture.org`

| Endpoint | Method | Returns | Volume |
|----------|--------|---------|--------|
| `/api/v1/organization` | GET | JSON array | 46 orgs |
| `/api/v1/Courses` | GET | JSON (Categories > Courses) | 15 categories, 81 courses |
| `/api/v2/Courses` | GET | JSON (same structure, localized) | 15 categories, 81 courses |
| `/api/v3/admin/categoriesAndCourses` | GET | JSON (Offers, CourseItems, Restricted) | 31 offers, 178 course items |
| `/api/v1/Groups` | GET | JSON array | 27 groups |
| `/api/v1/learningpaths` | GET | JSON array | 13 paths |
| `/api/v2/learningpaths` | GET | JSON | Same paths, extended data |
| `/api/v1/Certificates` | GET | JSON | **Always empty** (courseCertificates: [], learningPathCertificates: []) |
| `/api/v1/admin/users?skip={n}&take={m}` | GET | JSON (UserDetails array, paginated) | **705,610 users** |
| `/api/v1/Reports/Users` | GET | CSV (demographics) | **71,013 rows**, 19 MB |
| `/api/v1/Reports/Course/{courseId}/Learners` | GET | CSV (per-course enrollments) | **2,305,395 total** across 178 courses |

### Key Gotchas

- **v1 Courses vs v3 CourseItems**: v1 returns 81 courses under 15 categories. v3 returns 178 CourseItems under 31 offers. Use v3 for the full catalog and course IDs.
- **Admin users pagination**: Default `take` is 100. Use `take=1000` for efficiency. Token refresh every ~50 pages.
- **Certificates always empty**: The endpoint works but MCT has no certificates configured.
- **Enrollment CSVs**: Use v3 CourseItems for course IDs, then hit `/api/v1/Reports/Course/{id}/Learners` per course. Generic enrollment endpoints return 404.

## 3. Data Volumes (Verified 2026-02-07)

| Data Set | Count | Size | Source |
|----------|-------|------|--------|
| Admin users (structured) | 705,610 | 208 MB | v1/admin/users (paginated) |
| Demographics (CSV) | 71,013 rows | 19 MB | v1/Reports/Users |
| Courses (v3 catalog) | 178 | 209 KB | v3/admin/categoriesAndCourses |
| Categories/Offers | 31 | (in catalog) | v3/admin/categoriesAndCourses |
| Enrollment records | 2,305,395 | 238 MB | Per-course CSVs |
| Organizations | 46 | 4 KB | v1/organization |
| Groups | 27 | 11 KB | v1/Groups |
| Learning paths | 13 | 7 KB | v1/learningpaths |
| Mux videos | 503 (500 ready, 3 errored) | N/A | Mux API |

### Mux Video Status

- 503 videos uploaded from MCT Azure Blob Storage to Mux
- 500 ready and serving (HLS playback via `stream.mux.com/{playback_id}.m3u8`)
- 3 errored: Financial Planning lessons 2610, 2611, 2612 (source Azure blob URLs expired before Mux could download)
- Mux environment: `d2pf0l73ablr4ghl1b607jpa2`

## 4. MCT-to-OpenEdX Mapping

### Terminology (Verified)

| MCT Term | What It Actually Is | Open edX Equivalent |
|----------|---------------------|---------------------|
| **Category** | A full course/program (e.g., "Basic Microsoft") | **Course** (`course-v1:SKILLOURFUTURE+{SLUG}+2024`) |
| **Course** | A module/section within a category (workaround for missing module feature) | **Section (Chapter)** |
| **Lesson** (CourseItem) | Individual content item (video, PDF, etc.) | **Unit (Vertical)** + XBlock |
| **Group** | Learning pathway with auto-enrollment rules | **Program** (13 created) |
| **Organization** | Country/Region/Institution | All mapped to `SKILLOURFUTURE` |

### Migration Counts

| Entity | MCT Count | Open edX Result |
|--------|-----------|-----------------|
| Categories | 31 (1 test/empty) | 30 Open edX courses |
| Courses (modules) | 178 | 178 sections across 30 courses |
| Lessons | ~833 total (503 with video) | Units with Video/HTML XBlocks |
| Users | 69,419 (demographics CSV at migration time) | 68,565 imported (98.77% success) |
| Enrollments | 2,303,026 raw records | 621,430 imported (502,407 new MCT) |
| Programs | 13 learning paths | 13 Open edX Programs |

### Content Type Mapping

| MCT FileType | Open edX XBlock |
|--------------|----------------|
| Video (PlaybackUrl) | `video` XBlock with Mux HLS URL |
| PDF (AuxPdfUrl) | `html` XBlock with embedded viewer |
| HTML content | `html` XBlock |
| SCORM/external link | `html` XBlock with iframe |

### Course ID Format

```
course-v1:SKILLOURFUTURE+{slug}+2024
```

Where `{slug}` is derived from the MCT category name (e.g., `basic-microsoft`, `ai-fluency`).

## 5. Export Pipeline

### Location

```
VPS: ~/projects/mereka-lms/
  scripts/migrations/mct/mct_export.py   # Python export (current)
  scripts/migrations/mct/mct-export.mjs  # Node.js export (legacy, still works)
  exports/mct/                           # Export output directory
    raw_api/                             # JSON/CSV from API (admin_users, courses, etc.)
    enrollments_by_course/               # Per-course enrollment CSVs
    *.ndjson                             # Original NDJSON exports (Dec 2025)
    video_mapping_*.json                 # Video/thumbnail mapping files
    complete_lesson_mapping.json         # Full lesson-to-content mapping
```

### Usage

```bash
cd ~/projects/mereka-lms

# Full export (all 11 resources):
infisical run --env prod --path /mereka-lms/mct -- \
  python3 scripts/migrations/mct/mct_export.py

# Delta export (users + enrollments only):
infisical run --env prod --path /mereka-lms/mct -- \
  python3 scripts/migrations/mct/mct_export.py --delta

# Specific resources:
infisical run --env prod --path /mereka-lms/mct -- \
  python3 scripts/migrations/mct/mct_export.py --resources admin_users,enrollments

# Dry run:
infisical run --env prod --path /mereka-lms/mct -- \
  python3 scripts/migrations/mct/mct_export.py --dry-run
```

### Available Resources

`organizations`, `courses_v1`, `courses_v2`, `courses_v3`, `groups`, `learningpaths_v1`, `learningpaths_v2`, `certificates`, `admin_users`, `reports_users`, `enrollments`

## 6. Data Field Reference

### course_content.ndjson (per course)

```
Top-level: courseId, categoryId, categoryName, courseName, courseDescription,
           CourseItems[], LearningFlowType, IsCertificateEnabled

CourseItem: CourseItemId, ItemType, DisplayOrder, Data{}, CompletionPercentage,
            IsPublished, VideoProgressDuration, Uuid

CourseItem.Data: Id, Title, Description, Url, ThumbnailUrl, DownloadUrl,
                 PlaybackUrl, TotalDuration, Tags, FileType, VideoTextTracks,
                 AuxPdfUrl, AuxPptUrl, AuxVideoUrl, AuxWordUrl, AuxZipUrl
```

### users.ndjson (demographics)

```
Contact, First Name, Last Name, Nickname, Gender, Source, University,
Consent, My groups, Referral Partner, Linkedin Profile Link,
Which Country are you from?, Which city are you from?,
Which province are you from?, When were you born?,
Which learning pathway are you interested in?,
Do you consider yourself to be part of a marginalised...
```

### enrollments.ndjson (per enrollment)

```
Contact, Name, Course, courseId, Course Completion Percentage,
Lessons Completed, Quizzes Completed, Average Score
```

### admin_users.json (per user via v1/admin/users)

Paginated JSON with `UserDetails` array. Each user has structured profile fields, enrollment status, group memberships.

## 7. Known Issues and Gaps

1. **3 Mux video errors**: Financial Planning lessons 2610, 2611, 2612 need re-upload from a valid source URL
2. **Certificates always empty**: MCT platform has no certificates configured. Cannot be migrated.
3. **User count discrepancy**: Demographics CSV has 71,013 rows. Admin users API returns 705,610. The difference is because admin/users includes ALL registered users (including inactive/test), while Reports/Users filters to active learners with profile data.
4. **Client secret expires 2026-08-07**: Must rotate before expiry. Create new secret via Azure CLI: `az ad app credential reset --id caa4dce3-e49c-4c09-9160-031d51bfd2a9`
5. **No incremental/delta API**: MCT has no "modified since" filter. Delta exports re-download all data and overwrite. Compare file sizes/counts to detect changes.

## 8. Related Documents

| Document | Path | Status |
|----------|------|--------|
| Migration status | `docs/migrations/mct/MCT_MIGRATION_STATUS.md` | Complete |
| OpenEdX mapping | `docs/migrations/mct/MCT_TO_OPENEDX_MAPPING.md` | Canonical |
| API reference | `docs/migrations/mct/API_COMPLETE_REFERENCE.md` | Needs update |
| Export guide | `docs/migrations/mct/EXPORT_GUIDE.md` | Updated 2026-02-08 |
| Video migration | `docs/migrations/mct/VIDEO_MIGRATION.md` | Updated 2026-02-08 |
| Data model | `docs/migrations/mct/DATA_MODEL_COMPLETE.md` | Needs count updates |
| Secrets management | `specs/secrets-management.md` | Current |


## 9. CRITICAL: Course Key Naming Inconsistency

Three different naming conventions were used across migration scripts. This caused duplicate courses and required cleanup scripts.

| Convention | Example | Used by |
|------------|---------|---------|
| `MCT-{course_id}+course` | `MCT-22+course` | `build_course_packages.py` (early approach) |
| `MCTCAT-{category_id}+RUN-{id}` | `MCTCAT-24+RUN-24` | `build_category_packages.py` (canonical) |
| `MCT-{category_id}+course` | `MCT-24+course` | `build_courses_with_mux.py`, `video_mapping_openedx.json` |

### Impact

- Duplicate courses were created in Open edX
- `cleanup_duplicate_courses.py` deleted old-format courses
- `migrate_mct22_enrollments.py` moved 45,684 enrollments from empty `MCT-22+course` to `MCT-22+RUN-22`

### Program Course Keys (13 programs)

The 13 programs in `link_courses_to_programs.py` use **manually crafted** course keys like:
- `SKILLOURFUTURE+INTRO-ENTREPRENEURIAL-MYTHS+2024`
- `SKILLOURFUTURE+BASIC-MICROSOFT+2024`

These are NOT auto-generated from MCT IDs. They represent curated learning pathways mapped manually.

### What to verify

Before assuming any mapping is correct, check:
1. Which course key format is actually live in Open edX right now
2. Whether programs reference the correct (current) course keys
3. Whether enrollments point to courses that have actual content

## 10. Script Status Matrix

| Script | Lines | Status | Purpose |
|--------|-------|--------|---------|
| `mct_export.py` | 326 | **Active** | Data export pipeline (Infisical) |
| `mct-export.mjs` | 937 | Legacy | JS export (still works, superseded) |
| `transform_data.py` | 651 | **Active** | MCT NDJSON -> OpenEdX CSV/JSON |
| `build_category_packages.py` | 416 | **Active** | OLX packages (Category=Course) |
| `build_courses_with_mux.py` | 270 | **Active** | OLX with Mux video XBlocks |
| `build_course_packages.py` | 404 | Superseded | OLX (1:1 course mapping, wrong) |
| `create_video_mapping.py` | 156 | **Active** | Joins MCT lessons with Mux |
| `upload_videos_to_mux.py` | 237 | Done | Mux upload (503 complete) |
| `openedx_bulk_import_mct.py` | 382 | **Active** | Bulk user+enrollment import |
| `import_with_verification.py` | 224 | **Active** | Course import with verification |
| `link_courses_to_programs.py` | 308 | **Active** | Links courses to 13 programs |
| `validate_course_content.py` | 157 | **Active** | Post-import validation |
| `cleanup_duplicate_courses.py` | 269 | Done | Fixed naming inconsistency |
| `migrate_mct22_enrollments.py` | 207 | Done | Moved MCT-22 enrollments |
| `download_thumbnails.py` | 157 | **Broken** | Wrong path (/home/dev/ not /home/gurpreet/) |
| `create_programs*.py` (5 files) | ~1000 | Superseded | Multiple program creation iterations |
| `fix_mux_titles.py` | 100 | Done | One-time Mux title fix |
