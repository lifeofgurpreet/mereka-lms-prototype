---
title: 'Data Migrations: Kajabi & MCT Legacy Systems'
type: migration_spec
status: active
owner: migration-squad
vehicle: talent_platform
version: 1.0.0
depends_on:
- specs/repository-structure_spec.md
- specs/k8s-deployment_spec.md
- specs/secrets-management_spec.md
links:
  related_docs:
  - docs/migrations/kajabi/KAJABI_MIGRATION_HANDOVER.md
  - docs/migrations/kajabi/KAJABI_MIGRATION_STATUS.md
  - docs/migrations/kajabi/KAJABI_MIGRATION_VERIFICATION.md
  - docs/migrations/kajabi/KAJABI_REMIGRATION_RUNBOOK.md
  - docs/migrations/kajabi/ROLLBACK_AND_SAFETY.md
  - docs/migrations/kajabi/KAJABI_CERTIFICATE_MIGRATION.md
  - docs/migrations/mct/MIGRATION_PLAN.md
  - docs/migrations/mct/MCT_MIGRATION_STATUS.md
  - docs/migrations/mct/MCT_PRE_MIGRATION_INVENTORY.md
  - docs/migrations/mct/MCT_TO_OPENEDX_MAPPING.md
  - docs/migrations/mct/VIDEO_MIGRATION.md
  - docs/migrations/mct/EXPORT_GUIDE.md
  - docs/migrations/BBI-K8-MIGRATION.md
  related_specs:
  - specs/secrets-management_spec.md
  - specs/k8s-deployment_spec.md
  - specs/mongodb-atlas-integration_spec.md
  - specs/video-pipeline-delivery_spec.md
  - specs/observability-stack_spec.md
  - specs/cross-cutting-requirements_spec.md
id: SPEC-DATA-MIGRATIONS-KAJABI-MCT
spec_class: domain
created: '2026-02-10'
last_reviewed: '2026-02-10'
review_due: '2026-05-11'
domain: data
normativity: normative
summary: Normative contract for migrating Kajabi and MCT legacy data into the Mereka
  LMS platform.
---

# Human Summary

## What is changing

Two legacy learning management platforms -- Kajabi and Microsoft Community Training (MCT) -- are being migrated to a single Open edX deployment on GKE. This involves exporting users, courses, enrollments, certificates, video content, and learning pathway data from both source systems, transforming it to Open edX-compatible formats, and importing it with zero data loss guarantees.

Kajabi serves as the primary LMS for Mereka Academy courses (109 courses, 94K users, 147K enrollments, 3.3K certificates). MCT (branded "Skill Our Future") provides digital skills training across Southeast Asia (30 courses from 31 categories, 69K users, 621K enrollments, 503 videos). Both migrations target the same Open edX instance at `academyv2.mereka.io` in the `mereka-lms` GKE namespace.

The Kajabi migration pipeline has been run twice (initial Nov 2024, re-migration Feb 2026). The MCT migration was completed in Dec 2025. This spec formalizes the contract governing both migrations, including re-migration capability, incremental sync, and post-migration verification.

## Why we must migrate

1. **Platform consolidation**: Operating two separate LMS platforms (plus Open edX) creates fragmented learner experiences, duplicate infrastructure costs, and maintenance burden across three codebases.
2. **Kajabi API limitations**: Kajabi lacks completion and certificate APIs; progress data requires tag-based workarounds. No webhook reliability guarantees. API pagination is non-deterministic (duplicate pages observed).
3. **MCT sunset**: Microsoft Community Training is being deprecated. Azure SAS tokens for video content expire within 6 hours, making content increasingly unreliable.
4. **Single source of truth**: Consolidating onto Open edX provides unified analytics, single sign-on, consistent branding, and program/pathway management via Discovery service.
5. **Cost reduction**: Eliminating Kajabi and MCT subscriptions while serving the same learner base from a single, self-hosted platform.

## Success looks like

- Zero data loss: every user, enrollment, and certificate from source systems is present in Open edX with verifiable counts.
- All 109 Kajabi courses and 30 MCT courses render correctly with proper structure, content, and video playback.
- All 503 MCT videos stream via Mux with HLS URLs. Kajabi course thumbnails render in Open edX.
- All 3,265+ Kajabi certificates and MCT program certificates are issued in Open edX.
- Re-migration is idempotent: running the pipeline again does not create duplicates.
- Post-migration verification script produces a passing report with less than 0.5% discrepancy on all entity counts.

# Agent Contract

## Scope

- **Source systems**:
  - Kajabi (api.kajabi.com via OAuth2 client credentials) -- contacts, customers, courses, purchases, offers, products, transactions, course structure (modules/lessons/media), tag-based completions
  - MCT (learn.skillourfuture.org via Azure AD OAuth2 client credentials) -- users, categories, courses, enrollments (from Reports API), course content, videos (Azure CDN with SAS tokens), learning pathways/groups
- **Target system**:
  - Open edX on GKE (namespace `mereka-lms`) with MySQL 8 (Cloud SQL), MongoDB Atlas (`cluster-mereka-lms.2pjex4s.mongodb.net`), Mux for video delivery
- **Data entities in scope**:
  - User accounts (PII: email, name, profile data)
  - Course structures (OLX packages -- sections, subsections, units, XBlocks)
  - Enrollments (user-to-course relationships with timestamps)
  - Certificates and completion records
  - Video content (MCT: Azure CDN to Mux migration; Kajabi: thumbnail migration)
  - Programs / learning pathways (MCT groups to Open edX Programs via Discovery service)
  - Course metadata (thumbnails, descriptions, slugs)
- **Data volumes**:
  - Kajabi: 326K contacts (94K unique emails), 219K purchases, 218 courses, 846 modules, 3,146 lessons, 11K completion records
  - MCT: 69K users, 2.3M raw enrollment records (441K unique), 31 categories, 178 courses, ~1,500 lessons, 503 videos
- **Cutover window**: 4-8 hours per full migration run (database backup + export + transform + import + verify)

## Non-goals

- Real-time bidirectional sync between Kajabi/MCT and Open edX (one-way migration only)
- Migration of Kajabi marketing automation, email sequences, landing pages, forms, or blog posts into Open edX
- Migration of MCT announcement/notification data
- Migration of Kajabi payment/transaction/ecommerce data into Open edX ecommerce (purchases are mapped to enrollments only)
- Building a custom discussion forum migration (MCT forums are out of scope; Kajabi has no forum feature)
- Automating Kajabi lesson HTML scraping at scale (manual or Playwright-based, documented as future enhancement)
- SSO federation between legacy platforms and Open edX during cutover (users get password reset links or social login)
- Migration of MCT analytics/reporting data beyond what the Reports API provides
- Replacing the Kajabi API pagination bug (documented as known limitation with deduplication workaround)

## Assumptions

- Kajabi API credentials (`KAJABI_CLIENT_ID`, `KAJABI_CLIENT_SECRET`, `KAJABI_SITE_ID`) remain valid in Infisical at `/mereka-lms/kajabi`
- MCT Azure AD service principal (`MCT_CLIENT_ID`, `MCT_CLIENT_SECRET`, `MCT_TENANT_ID`) remains valid until secret expiry 2026-12-17
- Open edX instance is running in `mereka-lms` GKE namespace with LMS, CMS, MongoDB, MySQL pods healthy
- MongoDB Atlas cluster (`cluster-mereka-lms.2pjex4s.mongodb.net`) is accessible from GKE
- Mux API credentials are configured for video upload and streaming
- VPS has Node 20+, Python 3.12+, and access to the GKE cluster via `kubectl`
- The `exports/` directory (gitignored) has sufficient disk space for raw exports (~1GB Kajabi, ~600MB MCT)

## Migration Strategy

### Approach: Full Export-Transform-Load (ETL) with Idempotent Re-run Capability

The migration uses a four-phase pipeline that can be re-executed end-to-end without creating duplicates:

```
Phase 1: Export        Phase 2: Transform       Phase 3: Import         Phase 4: Verify
─────────────────      ──────────────────       ────────────────        ───────────────
Kajabi API ──NDJSON──> transform_data.py        run_batches.py          verify-and-sync
MCT API ────NDJSON──> build_course_packages.py  import_courses.py       count checks
                      prepare_openedx_imports    resilient_import.sh     UI spot-check
                                                issue_certificates.py   comparison report
```

### Dual Write / Shadow Read: Not applicable

This is a one-way bulk migration, not a gradual cutover with dual writes. Both source systems continue operating until the business decides to decommission them.

### Backfill Approach

1. **Full export** from source APIs to NDJSON files on disk
2. **Transform** NDJSON to CSVs and OLX course packages
3. **Batched import** into Open edX via Django management commands running inside K8s pods
4. **Certificate issuance** from tag-based completion data (Kajabi) or enrollment completion status (MCT)

### Verification Approach

1. **Row-count parity** between source exports and Open edX database queries
2. **Sample-based structural verification** of course content (modules, lessons, XBlocks)
3. **UI spot-checks** on LMS and Studio dashboards
4. **Automated comparison scripts** producing CSV reports with discrepancy percentages

### Cutover Plan

1. Announce maintenance window to stakeholders
2. Back up Open edX databases (MySQL dump + MongoDB dump)
3. Run full pipeline (export, transform, import) on VPS
4. Run verification suite
5. If verification passes (<0.5% discrepancy), declare migration complete
6. If verification fails, execute rollback (database restore or selective unenroll)

## Requirements

### Functional

#### Data Export

- The export pipeline MUST extract all user accounts, courses, enrollments, and completion data from Kajabi via its REST API
- The export pipeline MUST extract all users, categories, courses, enrollments, and video metadata from MCT via its REST API (V1 primary, V3 supplementary)
- The Kajabi exporter MUST handle API pagination non-determinism by deduplicating records post-export based on unique identifiers (email for contacts, purchase ID for purchases)
- The MCT exporter MUST handle Azure SAS token expiry by supporting re-export with fresh URLs before upload operations
- The export pipeline MUST write output as NDJSON files to `exports/kajabi/` and `exports/mct/` respectively
- The Kajabi completion exporter MUST use `filter[has_tag_id]` (not `filter[tag_id]`) to query tag-based completion data
- The export pipeline SHOULD support chunked export with `--start-page` and `--end-page` flags for resumability
- The export pipeline SHOULD log progress (records exported, pages processed, errors encountered) to timestamped log files

#### Data Transformation

- The transform pipeline MUST convert Kajabi NDJSON exports to Open edX-compatible CSVs (`users_import.csv`, `enrollments_import.csv`) and OLX course packages (`.tar.gz`)
- The transform pipeline MUST convert MCT NDJSON exports to Open edX-compatible CSVs and OLX course packages using the correct structural mapping: MCT Category = Open edX Course, MCT "Course" = Open edX Section, MCT Lesson = Open edX Unit
- The transform pipeline MUST NOT create 81 separate courses for MCT data; it MUST create exactly the number of courses matching MCT categories (currently 30 from 31 categories, excluding empty/test)
- The transform pipeline MUST generate a `course_packages_manifest.csv` mapping source IDs to Open edX course keys
- The Kajabi transform MUST filter user imports to enrolled users only (~73K with purchases), not all 326K contacts
- The Kajabi transform MUST deduplicate enrollment records to unique (email, course_id) pairs before import
- The MCT transform MUST deduplicate enrollment records from 2.3M raw to unique (user, category) pairs (~441K)
- The transform pipeline MUST generate course keys in the format `course-v1:{ORG}+{PREFIX}-{SOURCE_ID}+{RUN}` where ORG is `MEREKA` for Kajabi and `SKILLOURFUTURE` for MCT
- The transform pipeline SHOULD preserve original enrollment timestamps where available
- The transform pipeline SHOULD map tag prefixes to Open edX course keys for certificate issuance (Kajabi: 12 prefix mappings)

#### User Account Migration

- The import pipeline MUST create user accounts in Open edX using `update_or_create` semantics keyed on email address
- The import pipeline MUST handle email collisions between Kajabi and MCT users by merging into a single Open edX account (email is the canonical identifier)
- The import pipeline MUST create a `UserProfile` for every imported user (required for certificate issuance)
- The import pipeline MUST NOT send welcome/registration emails to migrated users (`--send-email False` / `--email-students False`)
- The import pipeline MUST support batched import (batch size configurable, default 2,000 rows) with offset-based resumability
- The import pipeline SHOULD generate unique usernames from email local-part when the source system does not provide a username
- The import pipeline SHOULD log created/updated/failed counts per batch to `scripts/migrations/{source}/logs/`

#### Course Structure Migration

- The course import pipeline MUST import OLX tarball packages into the CMS pod via `manage.py cms import`
- The course import pipeline MUST rewrite `course.xml` `run/url_name` attributes to match the manifest-defined course keys
- The Kajabi course import MUST produce courses with proper hierarchical structure: Course > Module (Section) > Lesson (Unit) > XBlock
- The MCT course import MUST produce courses with the corrected structural mapping: MCT Category = Course, MCT "Course" = Section (Chapter), MCT Lesson = Unit (Vertical) with Video/HTML XBlocks
- The course import pipeline MUST support `--dry-run` and `--limit` flags for safe testing
- The course import pipeline SHOULD support `--only` flag for selective course re-import

#### Enrollment Migration

- The enrollment import MUST use `CourseEnrollment.get_or_create_enrollment()` or equivalent idempotent API
- The enrollment import MUST handle the case where a user account does not exist (skip and log, do not fail the batch)
- The enrollment import MUST handle the case where a course does not exist (skip and log, do not fail the batch)
- The enrollment import SHOULD preserve enrollment mode as `audit` (default for free courses)

#### Certificate Migration

- The certificate issuance pipeline MUST issue certificates for Kajabi users with `course_completed` tags using `GeneratedCertificate.objects.update_or_create()` with `CertificateStatuses.downloadable`
- The certificate issuance pipeline MUST map Kajabi tag prefixes (F101, MYFC, PB, PF, mce-cert, etc.) to Open edX course keys via `tag_prefix_to_course_mapping.json`
- The certificate issuance pipeline MUST skip users whose email is not found in Open edX and log the skip
- The MCT certificate pipeline MUST configure `ProgramCertificate` records in the Credentials service for each program
- The certificate pipeline SHOULD report the number of certificates issued, skipped, and failed

#### Video Content Migration

- The MCT video migration MUST upload all 503 videos to Mux via the Mux API using source URLs from MCT exports
- The MCT video migration MUST handle Azure SAS token expiry by re-exporting MCT data for fresh URLs before upload
- The MCT video migration MUST generate Video XBlocks pointing to Mux HLS stream URLs (`https://stream.mux.com/{PLAYBACK_ID}.m3u8`)
- The MCT video migration MUST include caption tracks (34 videos with VTT captions) in Mux asset creation
- The Kajabi thumbnail migration MUST download course thumbnail images and upload them to the CMS contentstore
- The video migration SHOULD rate-limit Mux API calls to 5 requests/second (0.25s delay between uploads)

#### Identity Reconciliation and Deduplication

- The migration MUST use email address as the canonical identity key across all source systems
- The migration MUST handle users present in both Kajabi and MCT by merging into a single Open edX account
- The migration MUST NOT create duplicate user accounts for the same email address
- The migration MUST preserve the union of enrollments from both source systems for merged accounts
- The deduplication logic MUST log all merge operations with source system, email, and action taken

#### Programs and Learning Pathways

- The MCT learning pathway migration MUST create Programs in the Discovery service with correct ProgramType (Professional Certificate, XSeries, Certificate)
- The MCT learning pathway migration MUST create a Partner record (`sof` / Skill Our Future) in Discovery
- The MCT learning pathway migration MUST link courses to programs according to the `programs_mapping.json`
- Programs with manual course ordering (Entrepreneur, Impact, Green Jobs) MUST have order restrictions set
- The migration SHOULD upload program thumbnails to Discovery for all programs that have logos in MCT source data

### Non-Functional Requirements

#### Data Integrity

- The migration MUST achieve zero data loss: 100% of valid source records (users with emails, enrollments with valid user+course pairs) MUST be present in Open edX post-migration
- Post-migration verification MUST show less than 0.5% discrepancy between source export counts and Open edX database counts for each entity type (users, enrollments, courses)
- For discrepancies exceeding 0.5%, the migration team MUST produce a written explanation (e.g., missing emails, invalid data format, Kajabi API pagination duplicates)

#### Performance

- Full Kajabi export SHOULD complete within 4 hours (326K contacts at ~100/page)
- Full MCT export SHOULD complete within 2 hours (69K users + 2.3M enrollment records)
- User import (batched at 2,000 rows) SHOULD process at a rate of at least 1,000 users per minute
- Enrollment import SHOULD process at a rate of at least 2,000 enrollments per minute
- Course import (109 Kajabi + 30 MCT) SHOULD complete within 2 hours total
- Video upload to Mux (503 videos) SHOULD complete within 4 hours

#### Resilience

- The import pipeline MUST survive K8s pod restarts mid-import (via offset-based resumability and `resilient_import.sh` pod re-resolution)
- The import pipeline MUST retry transient failures with exponential backoff (3 attempts, 10s initial backoff)
- The import pipeline MUST NOT require re-running the entire pipeline on partial failure; it MUST resume from the last successful offset
- All scripts MUST be idempotent: re-running with the same inputs MUST NOT create duplicate records

#### Security

- The migration MUST NOT log or print raw passwords, API secrets, or bearer tokens
- Kajabi and MCT API credentials MUST be sourced from Infisical, not hardcoded in scripts or committed to git
- Exported NDJSON files containing PII (emails, names) MUST remain in gitignored directories (`exports/`)
- The migration MUST NOT expose user email addresses in public-facing logs or error messages

#### Observability

- Each migration phase MUST produce timestamped log files in `scripts/migrations/{source}/logs/`
- Batch imports MUST log per-batch statistics: batch number, offset, created count, updated count, failed count, elapsed time

## Acceptance Criteria

### Export Phase

- [ ] AC-001: Given valid Kajabi API credentials in Infisical, when `kajabi-export.mjs` runs, then all 17 resource types are exported to `exports/kajabi/` as NDJSON files with row counts matching the Kajabi API total headers (within 5% tolerance for pagination duplicates)
- [ ] AC-002: Given valid MCT Azure AD credentials, when `mct-export.mjs` runs, then users, categories, courses, and enrollment data are exported to `exports/mct/` with row counts matching MCT platform statistics (within 1% tolerance)
- [ ] AC-003: Given Kajabi completion tags exist, when `kajabi-export-completions.mjs` runs with `filter[has_tag_id]`, then completion records are exported with correct `tag_type` classification (course_completed, quiz_completed, started, onboarded, certificate)
- [ ] AC-004: Given MCT video content with Azure SAS tokens, when `mct-export.mjs --resources courses --force` runs, then fresh video URLs are exported that are valid for at least 6 hours

### Transform Phase

- [ ] AC-005: Given Kajabi NDJSON exports, when `transform_data.py` runs, then `users_import.csv` contains only users with at least one enrollment (approximately 73K, not 326K contacts)
- [ ] AC-006: Given Kajabi NDJSON exports, when `prepare_openedx_imports.py` runs, then `enrollments_import.csv` contains deduplicated (email, course_id) pairs
- [ ] AC-007: Given MCT NDJSON exports, when `transform_data.py` runs with category-level mapping, then exactly 30 course packages are generated (not 81 or 178)
- [ ] AC-008: Given MCT enrollment data (2.3M raw records), when deduplication runs, then unique (user, category) pairs total approximately 441K records
- [ ] AC-009: Given Kajabi course structure data, when `build_course_packages.py` runs, then 109 OLX tarballs are generated with correct course keys in `course-v1:MEREKA+MEKA-{id}+RUN-{id}` format
- [ ] AC-010: Given MCT category/course/lesson hierarchy, when OLX packages are built, then each package has MCT Category as Course, MCT "Course" as Chapter/Section, and MCT Lesson as Unit/Vertical

### User Import Phase

- [ ] AC-011: Given `users_import.csv` from Kajabi (73K rows), when batched import runs, then Open edX user count increases by at least 72K (allowing for email collisions) and each user has a `UserProfile` record
- [ ] AC-012: Given `users.csv` from MCT (69K rows), when batched import runs, then Open edX user count increases by at least 68K (allowing for email collisions with existing users)
- [ ] AC-013: Given a user email exists in both Kajabi and MCT exports, when both imports run, then exactly one Open edX user account exists for that email with enrollments from both source systems
- [ ] AC-014: Given a batch import is interrupted by a pod restart, when the import is re-executed, then it resumes from the last successful offset without duplicating previously imported users

### Course Import Phase

- [ ] AC-015: Given 109 Kajabi OLX tarballs, when `import_courses.py` runs against CMS, then MongoDB `modulestore.active_versions` increases by 109 and all courses are visible in Studio
- [ ] AC-016: Given 30 MCT OLX tarballs with Mux Video XBlocks, when imported to CMS, then all courses contain properly structured Sections (from MCT "Courses") and Units (from MCT Lessons) with video playback URLs
- [ ] AC-017: Given a specific imported Kajabi course, when queried via modulestore, then it contains the expected number of modules and lessons matching the source `course_structure.json`
- [ ] AC-018: Given a specific imported MCT course (e.g., Basic Microsoft), when inspected in Studio, then it contains 12 sections matching the 12 MCT "Courses" under that category

### Enrollment Import Phase

- [ ] AC-019: Given Kajabi enrollment CSV (~147K unique pairs after dedup), when batched import runs, then Open edX enrollment count increases by at least 146K (allowing for skips where user or course not found)
- [ ] AC-020: Given MCT enrollment CSV (~441K unique pairs), when batched import runs, then Open edX enrollment count increases by at least 440K (allowing for profile-related failures <1%)
- [ ] AC-021: Given an enrollment record where the user email is not found in Open edX, when the import processes that record, then it is skipped with a log entry and the batch continues without failure
- [ ] AC-022: Given an enrollment record where the course key is not found in Open edX, when the import processes that record, then it is skipped with a log entry and the batch continues without failure

### Certificate Phase

- [ ] AC-023: Given Kajabi `completions.ndjson` with `course_completed` tags and `tag_prefix_to_course_mapping.json`, when `issue_certificates.py` runs, then `GeneratedCertificate` records are created for all mappable (email, course_key) pairs with `CertificateStatuses.downloadable`
- [ ] AC-024: Given 3,268 Kajabi completion records, when certificate issuance runs, then at least 3,265 certificates are issued (allowing for 3 unfound emails)
- [ ] AC-025: Given MCT Programs configured in Discovery with ProgramCertificate records, when a user completes all courses in a program, then the Credentials service can issue a program certificate

### Video Migration Phase

- [ ] AC-026: Given 503 MCT videos with fresh Azure SAS URLs, when `upload_videos_to_mux.py` runs, then all 503 assets are created in Mux with proper titles and playback IDs
- [ ] AC-027: Given 34 videos with VTT caption tracks, when uploaded to Mux, then caption tracks are associated with the corresponding Mux assets
- [ ] AC-028: Given Mux upload results, when OLX packages are rebuilt with `build_courses_with_mux.py`, then Video XBlocks contain `https://stream.mux.com/{PLAYBACK_ID}.m3u8` source URLs
- [ ] AC-029: Given 109 Kajabi courses with thumbnail URLs, when `upload_thumbnails.py` runs, then `course_image` field is updated in modulestore for each course

### Verification Phase

- [ ] AC-030: Given migration complete, when count verification runs via Django shell, then reported counts for Users, Enrollments, and Courses are within 0.5% of source export counts
- [ ] AC-031: Given migration complete, when `verify-and-sync-kajabi-to-openedx.py` runs, then a comparison report is produced showing discrepancies per course with explanations
- [ ] AC-032: Given migration complete, when a sample of 10 courses is inspected via Studio UI, then course structure (sections, units, content) renders correctly
- [ ] AC-033: Given migration complete, when a sample of 5 users logs into the LMS, then their enrolled courses are visible in the dashboard

### Rollback Phase

- [ ] AC-034: Given a database backup taken before import, when `tutor local do restore-db` runs, then Open edX reverts to pre-migration state
- [ ] AC-035: Given the rollback script `rollback-openedx-imports.py`, when run with `--action unenroll --dry-run`, then it reports the number of enrollments that would be removed without modifying data
- [ ] AC-036: Given a failed import, when re-executing the import pipeline from the beginning, then no duplicate records are created (idempotency)

### Idempotency and Re-migration

- [ ] AC-037: Given the full pipeline has already been run once, when the entire pipeline is re-executed with the same export data, then entity counts remain unchanged (no duplicates, no data loss)
- [ ] AC-038: Given new users/enrollments have appeared in Kajabi since last export, when a fresh export and import runs, then only net-new records are created and existing records are updated

## Edge Cases

### API and Network Failures

- **Kajabi API rate limiting**: Exporter encounters HTTP 429. Mitigation: exponential backoff with configurable delay between pages (default 400ms).
- **Kajabi API pagination non-determinism**: The API returns duplicate pages (654 pages appeared 4x in one observed run). Mitigation: post-export deduplication by unique ID (email for contacts, record ID for other entities).
- **MCT Azure SAS token expiry**: Video URLs become 403 after 6 hours. Mitigation: re-export MCT data immediately before video upload operations.
- **MCT service principal expiry**: Azure AD secret expires 2026-12-17. Mitigation: renew before expiry; alert 30 days in advance.
- **Network timeout during course import**: `kubectl exec` to CMS pod times out during large tarball transfer. Mitigation: `import_courses.py` processes one course at a time and logs success; resume with `--only` for failed courses.

### K8s Infrastructure Failures

- **Pod restart during batch import**: ArgoCD ConfigMap churn causes LMS pods to restart every 3-5 minutes during CSS changes. Mitigation: `resilient_import.sh` re-resolves pod names and re-uploads files on each batch.
- **Pod OOM during large course import**: CMS pod runs out of memory processing a large OLX package. Mitigation: course packages are imported individually, not in bulk; restart CMS pod and retry the failed course.
- **Empty endpoints after pod restart**: Service selector mismatch. Mitigation: run `scripts/infra/fix-service-selectors.sh` and verify with `kubectl get endpoints -n mereka-lms`.

### Data Quality Issues

- **Users without emails**: Kajabi contacts may lack email addresses. Mitigation: skip rows with missing email in transform phase; log count of skipped rows.
- **Duplicate usernames across systems**: A Kajabi user and MCT user may generate the same username from different emails. Mitigation: email-keyed `update_or_create`; usernames are generated with collision-avoidance suffix.
- **Missing UserProfile**: Some pre-existing admin users lack UserProfile records, causing certificate issuance to fail. Mitigation: create UserProfile with default `allow_certificate=True` before certificate issuance.
- **Enrollment for non-existent course**: Enrollment CSV references a course key that failed to import. Mitigation: skip and log; count as explained discrepancy.
- **Enrollment for non-existent user**: Enrollment CSV references a user email that was not imported (e.g., missing email in source). Mitigation: skip and log.
- **Kajabi contacts vs enrolled users**: 326K contacts includes leads/subscribers who never took courses. Mitigation: filter to enrolled-only (~73K with purchases) during transform.

### Partial Failures

- **Partial batch completion**: Import processes 1,500 of 2,000 rows before failure. Mitigation: offset file tracks position; re-run resumes from last committed offset.
- **Partial Mux upload**: 400 of 503 videos uploaded before quota/rate limit. Mitigation: `mux_upload_results.json` tracks completed uploads; re-run skips already-uploaded videos.
- **Partial certificate issuance**: 2,000 of 3,268 certificates issued before failure. Mitigation: `update_or_create` ensures re-run does not duplicate; script logs progress.

### Idempotency

- **User import**: `update_or_create` keyed on email. Re-run updates existing records, creates only net-new.
- **Enrollment import**: `get_or_create_enrollment` returns existing enrollment if already present.
- **Course import**: Re-import overwrites course content in modulestore (latest version wins).
- **Certificate issuance**: `update_or_create` on (user, course_key) pair. Re-run updates status, does not duplicate.
- **Video upload**: Mux does not deduplicate by URL; re-upload creates new asset. Mitigation: check `mux_upload_results.json` before re-running.

### Rate Limits

- **Kajabi API**: No documented rate limit; observed ~100 requests/minute before throttling. Exporter uses 400ms delay between requests.
- **MCT API**: 5 requests/second observed limit. Exporter uses 200ms delay.
- **Mux API**: 5 requests/second. Upload script uses 250ms delay.
- **Open edX management commands**: No external rate limit, but batched to 2,000 rows to avoid memory pressure on LMS pod.

### Timeout Behavior

- **Export script timeout**: Kajabi full export takes 3-4 hours. Script must be run in a persistent session (`tmux` or `nohup`). Timeout is not applicable; the script runs to completion or fails per-page.
- **K8s exec timeout**: `kubectl exec` defaults to no timeout for streaming operations. For batch imports, each batch processes independently within ~30-60 seconds.
- **Mux upload timeout**: Mux ingests video asynchronously from source URL. Upload API returns immediately; actual encoding may take minutes per video. Script does not block on encoding completion.

## Observability

### Logs

- **Export logs**: `exports/kajabi/export_YYYYMMDD.log`, `exports/kajabi/completions_YYYYMMDD.log`
- **Batch import logs**: `scripts/migrations/kajabi/logs/users_offset_*.log`, `scripts/migrations/kajabi/logs/enrollments_offset_*.log`, `scripts/migrations/kajabi/logs/course_import_YYYYMMDD.log`
- **MCT import logs**: `/var/migrations/mct/user_import_log_YYYY-MM-DD.txt`, `/var/migrations/mct/ENROLLMENT_IMPORT_FINAL_REPORT.md`
- **Verification logs**: `scripts/migrations/kajabi/output/verification/`, `scripts/migrations/kajabi/output/comparison/`
- **Log retention**: Migration logs MUST be preserved for at least 90 days post-migration for audit trail

### Metrics

- **Entity count deltas**: Source export count vs Open edX count per entity type (users, enrollments, courses, certificates) -- tracked in verification reports
- **Import throughput**: Records per minute per batch phase (users, enrollments, courses)
- **Error rate per batch**: Failed records / total records per batch
- **Export duration**: Wall-clock time for each export phase
- **Mux video upload success rate**: Uploaded / total videos

### Alerts

- **MCT service principal expiry**: Alert 30 days before 2026-12-17 expiry date
- **Verification discrepancy**: If post-migration verification shows >0.5% discrepancy on any entity type, alert migration squad
- **Import failure**: If any batch reports >10% failure rate, pause pipeline and alert
- **Pod health during import**: Monitor LMS/CMS pod restart count during migration window; alert if >5 restarts in 30 minutes

### Dashboards

- Post-migration entity count dashboard (can be manual spreadsheet or Grafana panel):
  - Users: Kajabi source count | MCT source count | Open edX count | Delta
  - Enrollments: Kajabi source count | MCT source count | Open edX count | Delta
  - Courses: Kajabi source count | MCT source count | Open edX count | Delta
  - Certificates: Kajabi source count | Open edX count | Delta
  - Videos: MCT source count | Mux count | Delta
  - Programs: MCT learning paths | Discovery programs | Delta

## Rollout & Rollback

### Rollout Plan

1. **Pre-migration (no downtime)**:
   - Verify all scripts are committed and pushed
   - Verify Infisical credentials are current
   - Verify K8s pods are healthy (`kubectl get pods -n mereka-lms`)
   - Verify MongoDB Atlas is accessible
   - Run export dry-run to confirm API access

2. **Migration execution (maintenance window)**:
   - Announce maintenance window to stakeholders
   - Take MySQL dump: `tutor local do backup-db` or `mysqldump` from Cloud SQL
   - Take MongoDB dump: `mongodump` from Atlas
   - Execute pipeline phases sequentially: courses first, then users, then enrollments, then certificates
   - Run verification suite after each phase
   - Log all counts to verification report

3. **Post-migration validation**:
   - Run automated count checks
   - Run comparison scripts
   - Perform UI spot-checks (login, course access, enrollment visibility, certificate download)
   - Verify video playback (Mux HLS streams)
   - Verify program pages in Discovery

4. **Sign-off**:
   - Migration squad reviews verification report
   - If discrepancy <0.5% with explanations, approve
   - If discrepancy >0.5% without explanation, escalate or rollback

### Feature Flags

- No feature flags applicable (infrastructure migration, not feature rollout)
- ArgoCD `selfHeal` should be disabled during migration to prevent pod churn undoing manual changes

### Backward Compatibility

- Kajabi and MCT platforms continue to operate independently after migration
- No DNS changes are made to Kajabi or MCT URLs
- Open edX URLs (`academyv2.mereka.io`, `studio.academyv2.mereka.io`, `apps.academyv2.mereka.io`) remain unchanged
- Users accessing legacy platforms are unaffected
- The migration only adds data to Open edX; it does not delete or modify data in source systems

### Rollback Steps

**Option 1: Full Database Restore (if migration corrupted data)**
```bash
# Restore MySQL from backup
tutor local do restore-db backup_file.sql

# Restore MongoDB from dump
kubectl exec -n mereka-lms mongodb-0 -- mongorestore /tmp/mongodb-backup/
```

**Option 2: Selective Enrollment Rollback (if only enrollments are problematic)**
```bash
# Dry run first
python scripts/migrations/kajabi/rollback-openedx-imports.py \
  --import-file scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --action unenroll --dry-run

# Execute rollback
python scripts/migrations/kajabi/rollback-openedx-imports.py \
  --import-file scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --action unenroll
```

**Option 3: Re-run from Scratch (if Open edX was empty before migration)**
```bash
# Wipe and re-import
# Only if the instance was intentionally rebuilt (as in Feb 2026 re-migration)
```

**Rollback time estimate**: Full database restore takes 30-60 minutes. Selective enrollment rollback takes 1-2 hours for large datasets.

## Webhook Integration Services

### Kajabi Webhook Receiver (Real-time Sync)

**Implementation**: `services/kajabi-webhook/main.py` (FastAPI, 120 lines)

A lightweight FastAPI service that receives Kajabi webhook events for incremental sync of purchases, enrollments, and tag changes after the initial bulk migration.

**Architecture**:
- **Endpoint**: `POST /webhooks/kajabi` — receives webhook payloads from Kajabi
- **Health**: `GET /healthz` — readiness probe (fails if secret not configured)
- **Authentication**: HMAC-SHA256 signature verification via `X-Kajabi-Signature` header
- **Persistence**: NDJSON outbox pattern — events written to `var/services/kajabi-webhook/outbox/{event}.ndjson`
- **Secret**: `KAJABI_WEBHOOK_SECRET` from environment variable (Infisical)

**Supported Events**: `purchase`, `payment_succeeded`, `order_created`, `form_submission`, `tag_added`, `tag_removed`

**Requirements**:
- REQ-WH-001: The service MUST verify the HMAC-SHA256 signature before processing any webhook
- REQ-WH-002: The service MUST return 401 for invalid or missing signatures
- REQ-WH-003: The service MUST return 400 for payloads missing an `event` or `type` key
- REQ-WH-004: The service MUST persist valid events to the NDJSON outbox atomically (append-only)
- REQ-WH-005: The service MUST accept unknown event types and write them to `unknown__{type}.ndjson`
- REQ-WH-006: The service MUST return 202 Accepted for successfully persisted events
- REQ-WH-007: The `/healthz` endpoint MUST return 500 if `KAJABI_WEBHOOK_SECRET` is not set

### MCT User Provisioning (HubSpot-driven)

**Implementation**: `services/hubspot-webhook/` (Firebase Cloud Functions, Node.js)

A legacy Firebase Cloud Function that provisions users in the MCT (Mereka Career Training) platform when HubSpot contacts are created. This is **independent** of the bulk migration pipeline and is **not in scope** for migration verification.

**Flow**: HubSpot form submission → webhook → create MCT user → create Azure AD B2C account → send welcome email (SendGrid) → schedule reminder email (7 days)

> **Note**: This service is deployed to Firebase and managed separately. See `services/hubspot-webhook/README.md` for deployment details.

### Webhook Acceptance Criteria

- [ ] AC-039: Given the Kajabi webhook receiver is running, when a `GET /healthz` request is made, then the service MUST return `{"status": "ok"}` with HTTP 200 if `KAJABI_WEBHOOK_SECRET` is configured
- [ ] AC-040: Given a valid Kajabi webhook with correct HMAC signature, when `POST /webhooks/kajabi` is called, then the event MUST be appended to the correct NDJSON outbox file and HTTP 202 returned
- [ ] AC-041: Given a Kajabi webhook with an invalid or missing `X-Kajabi-Signature`, when `POST /webhooks/kajabi` is called, then the service MUST return HTTP 401
- [ ] AC-042: Given a Kajabi webhook payload missing the `event` key, when `POST /webhooks/kajabi` is called, then the service MUST return HTTP 400
- [ ] AC-043: Given a Kajabi webhook with an unknown event type, when `POST /webhooks/kajabi` is called, then the event MUST be written to `unknown__{type}.ndjson` and HTTP 202 returned
- [ ] AC-044: Given the Kajabi webhook receiver is running without `KAJABI_WEBHOOK_SECRET`, when `GET /healthz` is called, then the service MUST return HTTP 500

## Open Questions

- ~~**OQ-001**~~: **RESOLVED**: Accept placeholder content for Kajabi lessons in v1. Scraping 3,146 lessons is high-effort with diminishing returns since courses are being rebuilt for Open edX. Scraper available if content recovery becomes business-critical.
- ~~**OQ-002**~~: **RESOLVED**: No. Kajabi webhook receiver stays as a local script for batch sync. Real-time sync unnecessary since Kajabi is being decommissioned. Cloud Run deployment deferred.
- **OQ-003**: What is the maintenance window for the next full re-migration? **STATUS**: Schedule during next quarterly maintenance window. Requires 4-hour window with read-only LMS mode.
- ~~**OQ-004**~~: **RESOLVED**: No. Import only users with at least one enrollment from MCT. Non-enrolled users can self-register on Open edX if needed. Reduces import volume from 69K to active users only.
- ~~**OQ-005**~~: **RESOLVED**: Store completion percentages in user profile metadata (custom field) for reference only. Do not inject tracking logs. Students restart courses in Open edX with fresh progress. Historical completion data preserved in migration audit archive.
- ~~**OQ-006**~~: **RESOLVED**: No cross-platform deduplication. Kajabi and MCT courses are separate orgs in Open edX (org: kajabi, org: mct). Students enrolled in both platforms retain both enrollments.
- ~~**OQ-007**~~: **RESOLVED**: Issue certificates manually for the 4 Kajabi courses without completion tags (DP, DT, AI, PKMU) based on Kajabi enrollment status. Create Studio completion criteria post-migration.
- **OQ-008**: What is the target date for decommissioning Kajabi and MCT platforms? **STATUS**: Target Q4 2026 after all courses migrated, verified, and enterprise clients transitioned. Hard deadline pending business confirmation.
- ~~**OQ-009**~~: **RESOLVED**: Yes. Migration produces NDJSON audit trail with SHA-256 checksums per batch. Retained 7 years in GCS archive bucket per cross-cutting compliance requirements.
