---
spec: data-migrations-kajabi-mct_spec.md
tier: 3
status: draft
estimated_effort: "10-14 weeks (1 engineer) or 5-7 weeks (2 engineers parallel on Kajabi/MCT)"
last_updated: "2026-02-10"
---

# Implementation Plan: Data Migrations -- Kajabi & MCT

**Source Spec**: `specs/data-migrations-kajabi-mct_spec.md`
**Tier**: 3 (Data & Migrations)
**Depends On**: Tier 0 (repository-structure, secrets-management, tutor-configuration) + Tier 1 (k8s-deployment, mongodb-atlas-integration)

## Summary

This plan breaks down the Kajabi and MCT migration spec intoimplementation tasks across 7 categories: Export, Transform, Import, Certificates & Video, Verification, Rollback & Idempotency, and Documentation & Observability. The migration isa four-phase ETL pipeline (Export, Transform, Import, Verify) that moves ~163K users, ~588K enrollments, 139 courses, 503videos, and 3.2K+ certificates from two legacy LMS platformsinto a single Open edX deployment on GKE.

Most scripts already exist in `scripts/migrations/kajabi/` and `scripts/migrations/mct/`. The implementation work focuseson hardening idempotency, adding resumability, improving logging/observability, building a unified verification suite, anddocumenting operational runbooks.

## Prerequisites

Before starting any migration task:

1. **Tier 0 complete**: Repository structure spec approved, secrets-management operational in Infisical
2. **Tier 1 complete**: GKE cluster healthy (`kubectl get pods -n mereka-lms` shows all pods Running), MongoDB Atlas accessible, Cloud SQL accessible
3. **API credentials valid**: Kajabi OAuth2 credentials at Infisical path `/mereka-lms/kajabi`, MCT Azure AD credentials valid (check expiry < 2026-12-17)
4. **Disk space**: At least 2GB free in `exports/` directoryon VPS
5. **Runtime**: Node 20+, Python 3.12+ on VPS; `kubectl` configured for GKE cluster

## Milestones

| Milestone | Tasks | Target | Gate |
|-----------|-------|--------|------|
| **M1: Export Pipeline Hardened** | T01-T08 | Week 2 | All export scripts produce NDJSON with dedup; dry-run passes |
| **M2: Transform Pipeline Verified** | T09-T16 | Week 4 | All CSVs and OLX packages generated with correct counts |
| **M3: User & Course Import Working** | T17-T23 | Week 6 | Users and courses imported; Studio shows all courses |
| **M4: Enrollment & Certificate Import** | T24-T30 | Week 8| Enrollments imported; certificates issued; videos on Mux |
| **M5: Verification & Rollback Proven** | T31-T37 | Week 10| Automated verification passes; rollback tested in staging |
| **M6: Docs & Observability Complete** | T38-T42 | Week 11 |Runbooks written; dashboards configured; log retention verified |

---

## Task Breakdown

### Phase 1: Export (T01-T08)

- [ ] **T01 [M]** Harden Kajabi export with deduplication andresumability (`scripts/migrations/kajabi/kajabi-export.mjs`)| AC: #1 | Depends: None
  - Add `--start-page` / `--end-page` flags for chunked export
  - Add post-export deduplication pass (dedup by email for contacts, by record ID for other entities)
  - Add progress logging (records exported, pages processed,errors) to timestamped log file
  - **Done**: Running `kajabi-export.mjs` produces 17 NDJSONfiles in `exports/kajabi/` with deduplication applied and a timestamped export log

- [ ] **T02 [S]** Harden Kajabi completions export with correct tag filter (`scripts/migrations/kajabi/kajabi-export-completions.mjs`) | AC: #3 | Depends: None
  - Verify script uses `filter[has_tag_id]` (not `filter[tag_id]`)
  - Add `tag_type` classification logic (course_completed, quiz_completed, started, onboarded, certificate)
  - **Done**: Running `kajabi-export-completions.mjs` produces `completions.ndjson` with correct `tag_type` field

- [ ] **T03 [M]** Harden MCT export with SAS token refresh and resumability (`scripts/migrations/mct/mct-export.mjs`) | AC: #2, #4 | Depends: None
  - Add `--resources` and `--force` flags for selective re-export
  - Handle Azure SAS token expiry (re-export courses with fresh URLs via `--force`)
  - Add progress logging to timestamped log file
  - **Done**: Running `mct-export.mjs` produces NDJSON filesin `exports/mct/` with fresh video URLs valid for 6+ hours

- [ ] **T04 [S]** Add exponential backoff for Kajabi API ratelimiting (`scripts/migrations/kajabi/kajabi-export.mjs`) | AC: #1, Edge: API rate limiting | Depends: T01
  - Detect HTTP 429 responses and retry with exponential backoff (configurable initial delay, default 400ms)
  - Log rate limit events
  - **Done**: Export survives 429 responses without manual intervention

- [ ] **T05 [S]** Add configurable delay for MCT API rate limiting (`scripts/migrations/mct/mct-export.mjs`) | AC: #2, Edge: MCT rate limits | Depends: T03
  - Ensure 200ms delay between API calls (configurable via `--delay` flag)
  - **Done**: Export completes without 429 errors from MCT API

- [ ] **T06 [S]** Validate Kajabi API credentials from Infisical before export (`scripts/migrations/kajabi/kajabi-export.mjs`) | Req: Security | Depends: T01
  - Source `KAJABI_CLIENT_ID`, `KAJABI_CLIENT_SECRET`, `KAJABI_SITE_ID` from Infisical (not hardcoded)
  - Fail fast with clear error if credentials missing
  - **Done**: Script fails with descriptive error when Infisical credentials are missing; never logs raw secrets

- [ ] **T07 [S]** Validate MCT Azure AD credentials before export (`scripts/migrations/mct/mct-export.mjs`) | Req: Security | Depends: T03
  - Source `MCT_CLIENT_ID`, `MCT_CLIENT_SECRET`, `MCT_TENANT_ID` from Infisical
  - Add expiry date check (warn if <30 days before 2026-12-17)
  - **Done**: Script warns on approaching credential expiry;never logs raw secrets

- [ ] **T08 [S]** Update dry-run script for both pipelines (`scripts/migrations/run-dry-run.sh`) | AC: #1, #2 | Depends: T01, T03
  - Verify dry-run covers both Kajabi and MCT exports
  - Confirm API access without writing production data
  - **Done**: `run-dry-run.sh` exits 0 when both APIs are accessible

### Phase 2: Transform (T09-T16)

- [ ] **T09 [M]** Harden Kajabi user transform to enrolled-only filter (`scripts/migrations/kajabi/transform_data.py`) | AC: #5 | Depends: T01
  - Filter `users_import.csv` to only users with at least onepurchase/enrollment (~73K, not 326K contacts)
  - Generate unique usernames from email local-part with collision avoidance
  - **Done**: `users_import.csv` row count is ~73K (not 326K); no duplicate usernames

- [ ] **T10 [M]** Harden Kajabi enrollment deduplication (`scripts/migrations/kajabi/prepare_openedx_imports.py`) | AC: #6| Depends: T01
  - Deduplicate to unique (email, course_id) pairs
  - Preserve original enrollment timestamps where available
  - Log dedup statistics (total raw, unique pairs, duplicatesremoved)
  - **Done**: `enrollments_import.csv` contains only unique (email, course_id) pairs (~147K)

- [ ] **T11 [L]** Harden MCT transform with correct category-level mapping (`scripts/migrations/mct/transform_data.py`, `scripts/migrations/mct/prepare_openedx_imports.py`) | AC: #7,#8 | Depends: T03
  - Enforce MCT Category = Open edX Course (exactly 30 courses, not 81 or 178)
  - Deduplicate MCT enrollments from 2.3M raw to ~441K unique(user, category) pairs
  - Log dedup statistics
  - **Done**: Exactly 30 course packages generated; enrollment CSV has ~441K rows

- [ ] **T12 [M]** Build Kajabi OLX course packages with correct keys (`scripts/migrations/kajabi/build_course_packages.py`) | AC: #9 | Depends: T09
  - Generate 109 OLX tarballs with course keys in `course-v1:MEREKA+MEKA-{id}+RUN-{id}` format
  - Generate `course_packages_manifest.csv` mapping source IDs to Open edX keys
  - Produce correct hierarchy: Course > Module (Section) > Lesson (Unit) > XBlock
  - **Done**: 109 tarballs exist; manifest CSV has 109 rows;course keys match format

- [ ] **T13 [M]** Build MCT OLX course packages with Mux video XBlocks (`scripts/migrations/mct/build_courses_with_mux.py`, `scripts/migrations/mct/build_category_packages.py`) | AC:#10, #28 | Depends: T11, T29 (video upload)
  - Enforce structural mapping: MCT Category = Course, MCT "Course" = Section/Chapter, MCT Lesson = Unit/Vertical
  - Generate Video XBlocks pointing to Mux HLS URLs (`https://stream.mux.com/{PLAYBACK_ID}.m3u8`)
  - Generate `course_packages_manifest.csv` with SKILLOURFUTURE org prefix
  - **Done**: 30 OLX tarballs with correct structure; Video XBlocks contain Mux HLS URLs

- [ ] **T14 [S]** Generate course key format for both sources(`scripts/migrations/kajabi/transform_data.py`, `scripts/migrations/mct/transform_data.py`) | AC: #9, #10 | Depends: T09,T11
  - Kajabi: `course-v1:MEREKA+MEKA-{id}+RUN-{id}`
  - MCT: `course-v1:SKILLOURFUTURE+SOF-{id}+RUN-{id}`
  - Validate no key collisions between sources
  - **Done**: All course keys follow the specified format; noduplicates between Kajabi and MCT

- [ ] **T15 [S]** Build tag-prefix-to-course mapping for Kajabi certificates (`scripts/migrations/kajabi/output/tag_prefix_to_course_mapping.json`) | AC: #23 | Depends: T12
  - Map 12 tag prefixes (F101, MYFC, PB, PF, mce-cert, etc.)to Open edX course keys
  - **Done**: JSON file contains all 12 mappings; every prefix resolves to a valid course key

- [ ] **T16 [S]** Handle users without emails in transform (`scripts/migrations/kajabi/transform_data.py`, `scripts/migrations/mct/transform_data.py`) | Edge: Users without emails | Depends: T09, T11
  - Skip rows with missing/empty email field
  - Log count of skipped rows with reason
  - **Done**: Transform logs report skipped rows; no empty-email rows in output CSVs

### Phase 3: Import (T17-T23)

- [ ] **T17 [L]** Harden Kajabi user import with batching andresumability (`scripts/migrations/kajabi/openedx_bulk_import.py`, `scripts/migrations/kajabi/run_batches.py`) | AC: #11,#14 | Depends: T09
  - Use `update_or_create` keyed on email for idempotency
  - Create `UserProfile` for every imported user
  - Support batch size config (default 2,000 rows) with offset-based resumability
  - Do NOT send welcome/registration emails (`--send-email False`)
  - Log created/updated/failed counts per batch to `scripts/migrations/kajabi/logs/`
  - **Done**: 72K+ users imported with UserProfile; re-run creates no duplicates; logs show per-batch stats

- [ ] **T18 [L]** Harden MCT user import with batching and resumability (`scripts/migrations/mct/openedx_bulk_import_mct.py`, `scripts/migrations/mct/run_full_user_import.sh`) | AC: #12, #14 | Depends: T11
  - Same idempotency and batching contract as T17
  - Handle email collisions with existing Kajabi-imported users (merge, do not duplicate)
  - **Done**: 68K+ MCT users imported; users present in bothsystems have exactly one account

- [ ] **T19 [M]** Implement cross-system identity reconciliation (`scripts/migrations/kajabi/openedx_bulk_import.py`, `scripts/migrations/mct/openedx_bulk_import_mct.py`) | AC: #13 |Depends: T17, T18
  - Email is the canonical identity key
  - When a user exists in both Kajabi and MCT, the second import updates (not creates)
  - Log all merge operations with source system, email, and action taken
  - **Done**: Running both imports produces exactly one OpenedX account per unique email; merge log exists

- [ ] **T20 [M]** Harden course import with dry-run and selective re-import (`scripts/migrations/kajabi/import_courses.py`, `scripts/migrations/mct/import_courses_k8s.py`) | AC: #15,#16, #17, #18 | Depends: T12, T13
  - Import OLX tarballs via `manage.py cms import` on CMS pod
  - Support `--dry-run`, `--limit`, and `--only` flags
  - Process one course at a time; log success/failure per course
  - Rewrite `course.xml` `run/url_name` to match manifest
  - **Done**: 109 Kajabi + 30 MCT courses visible in Studio;`--dry-run` produces no side effects

- [ ] **T21 [M]** Harden enrollment import with skip-and-logfor missing entities (`scripts/migrations/kajabi/run_batches.py`, `scripts/migrations/mct/migrate_mct22_enrollments.py`) |AC: #19, #20, #21, #22 | Depends: T17, T18, T20
  - Use `CourseEnrollment.get_or_create_enrollment()` for idempotency
  - Skip and log enrollments where user email not found (do not fail batch)
  - Skip and log enrollments where course key not found (do not fail batch)
  - Set enrollment mode to `audit`
  - **Done**: 146K+ Kajabi enrollments + 440K+ MCT enrollments imported; skip log exists with reasons

- [ ] **T22 [M]** Add resilient import wrapper for K8s pod restarts (`scripts/migrations/kajabi/resilient_import.sh` or inline in `run_batches.py`) | AC: #14, Edge: Pod restart | Depends: T17
  - Re-resolve pod names on each batch (handles ArgoCD pod churn)
  - Re-upload CSV files to new pod if pod restarted mid-import
  - Retry transient failures with exponential backoff (3 attempts, 10s initial)
  - **Done**: Import survives pod restarts; logs show pod re-resolution events

- [ ] **T23 [S]** Ensure no welcome emails sent during import(`scripts/migrations/kajabi/openedx_bulk_import.py`, `scripts/migrations/mct/openedx_bulk_import_mct.py`) | Req: User Account Migration | Depends: T17, T18
  - Verify `--send-email False` / `--email-students False` flags are enforced
  - **Done**: Zero emails sent during import (verified via mail server logs or Django email backend config)

### Phase 4: Certificates & Video (T24-T30)

- [ ] **T24 [M]** Harden Kajabi certificate issuance pipeline(`scripts/migrations/kajabi/issue_certificates.py`) | AC: #23, #24 | Depends: T15, T17, T20
  - Use `GeneratedCertificate.objects.update_or_create()` with `CertificateStatuses.downloadable`
  - Map tag prefixes to course keys via `tag_prefix_to_course_mapping.json`
  - Skip users whose email is not found; log skip with reason
  - Create missing `UserProfile` records with `allow_certificate=True` before issuance
  - Report issued/skipped/failed counts
  - **Done**: 3,265+ certificates issued; 3 unfound emails logged as skips; re-run produces no duplicates

- [ ] **T25 [M]** Configure MCT Programs in Discovery service(`scripts/migrations/mct/setup_discovery_programs.py`, `scripts/migrations/mct/create_programs_simple.py`) | AC: #25 | Depends: T20
  - Create Partner record (`sof` / Skill Our Future) in Discovery
  - Create Programs with correct ProgramType (Professional Certificate, XSeries, Certificate)
  - Link courses to programs per `programs_mapping.json`
  - Set order restrictions for sequential programs (Entrepreneur, Impact, Green Jobs)
  - **Done**: Programs visible in Discovery admin; courses linked; ProgramCertificate records created

- [ ] **T26 [S]** Upload MCT program thumbnails to Discovery(`scripts/migrations/mct/download_thumbnails.py`) | AC: #25 |Depends: T25
  - Download program logos from MCT source data
  - Upload to Discovery service for each program
  - **Done**: Program pages in Discovery show thumbnails

- [ ] **T27 [L]** Harden Mux video upload pipeline (`scripts/migrations/mct/upload_videos_to_mux.py`) | AC: #26, #27 | Depends: T03
  - Upload all 503 videos to Mux with proper titles
  - Include caption tracks for 34 videos with VTT captions
  - Rate-limit to 5 requests/second (250ms delay between uploads)
  - Track completed uploads in `mux_upload_results.json` (skip already-uploaded on re-run)
  - Handle partial failures: resume from where left off
  - **Done**: 503 Mux assets created with playback IDs; 34 have captions; results JSON is complete

- [ ] **T28 [S]** Handle Azure SAS token refresh for video URLs (`scripts/migrations/mct/mct-export.mjs`, `scripts/migrations/mct/upload_videos_to_mux.py`) | AC: #4, Edge: SAS expiry| Depends: T03, T27
  - Before video upload, verify SAS URLs are <6 hours old; re-export if needed
  - **Done**: Video upload never encounters 403 from expiredSAS tokens

- [ ] **T29 [S]** Generate Video XBlocks with Mux HLS URLs (`scripts/migrations/mct/build_courses_with_mux.py`) | AC: #28| Depends: T27
  - Generate Video XBlock XML with `source` pointing to `https://stream.mux.com/{PLAYBACK_ID}.m3u8`
  - **Done**: OLX packages contain Video XBlocks with valid Mux HLS URLs

- [ ] **T30 [M]** Upload Kajabi course thumbnails to CMS contentstore (`scripts/migrations/kajabi/upload_thumbnails.py`) |AC: #29 | Depends: T20
  - Download thumbnails from Kajabi course metadata
  - Upload to CMS contentstore via `manage.py cms` or API
  - Update `course_image` field in modulestore for each course
  - **Done**: 109 Kajabi courses show thumbnails in Studio and LMS

### Phase 5: Verification & Rollback (T31-T37)

- [ ] **T31 [L]** Build unified count verification script (`scripts/migrations/run-verification-pipeline.sh`, `scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py`) | AC: #30, #31 | Depends: T21, T24
  - Query Open edX database for Users, Enrollments, Courses,Certificates counts
  - Compare against source export counts
  - Flag discrepancies >0.5% per entity type
  - Produce comparison report CSV with per-course discrepancyand explanations
  - **Done**: Verification script produces a report; all entity counts within 0.5% or have written explanations

- [ ] **T32 [S]** Add sample-based structural verification for courses (`scripts/migrations/mct/validate_course_content.py` or new script) | AC: #17, #18, #32 | Depends: T20
  - Query modulestore for a sample of 10 courses
  - Verify section/unit count matches source `course_structure.json`
  - Verify a specific MCT course (e.g., Basic Microsoft) hassections
  - **Done**: Sample verification passes; MCT Basic Microsofthas 12 sections

- [ ] **T33 [S]** Add user login spot-check procedure (`docs/migrations/VERIFICATION_CHECKLIST.md`) | AC: #33 | Depends: T17, T21
  - Document manual procedure: login as 5 sample users, verify enrolled courses visible in dashboard
  - **Done**: Checklist document exists with step-by-step login verification for 5 users

- [ ] **T34 [M]** Harden full database rollback procedure (`scripts/migrations/rollback-openedx-imports.py`) | AC: #34 | Depends: None
  - Document and test MySQL restore via `tutor local do restore-db`
  - Document and test MongoDB restore via `mongorestore` fromAtlas dump
  - **Done**: Rollback tested in staging; restore completes within 60 minutes

- [ ] **T35 [S]** Add selective enrollment rollback with dry-run (`scripts/migrations/rollback-openedx-imports.py`) | AC:#35 | Depends: T34
  - Support `--action unenroll --dry-run` (report only, no modifications)
  - Support `--action unenroll` (execute rollback)
  - **Done**: Dry-run reports correct count; execute removesenrollments without errors

- [ ] **T36 [M]** Prove full pipeline idempotency (`scripts/migrations/run-dry-run.sh` + documentation) | AC: #36, #37 | Depends: T17, T20, T21, T24
  - Run full pipeline twice on staging
  - Verify entity counts are unchanged after second run
  - Document results
  - **Done**: Second pipeline run produces zero new records;verification counts unchanged

- [ ] **T37 [S]** Prove incremental sync for net-new records(`scripts/migrations/kajabi/openedx_bulk_import.py`) | AC: #3| Depends: T36
  - Add synthetic test record to export
  - Re-run pipeline
  - Verify only net-new record is created; existing records updated, not duplicated
  - **Done**: Only 1 net-new record created on second run with 1 additional source record

### Phase 6: Observability & Logging (T38-T40)

- [ ] **T38 [M]** Standardize log output for all migration phases (`scripts/migrations/kajabi/`, `scripts/migrations/mct/`) | Req: Observability | Depends: T01, T03, T17, T21
  - All scripts produce timestamped log files in `scripts/migrations/{source}/logs/`
  - Batch imports log: batch number, offset, created count, updated count, failed count, elapsed time
  - Preserve logs for 90 days post-migration
  - **Done**: Every script produces structured logs; log directory contains timestamped files

- [ ] **T39 [S]** Add MCT service principal expiry alert (`infrastructure/monitoring/` or Infisical alert) | Req: Alerts |Depends: None
  - Alert 30 days before 2026-12-17 MCT credential expiry
  - **Done**: Alert fires when <30 days remain on MCT serviceprincipal

- [ ] **T40 [S]** Create post-migration entity count dashboard (`docs/migrations/MIGRATION_DASHBOARD.md` or Grafana panel)| Req: Dashboards | Depends: T31
  - Track: Users, Enrollments, Courses, Certificates, Videos,Programs with source counts and deltas
  - Can be manual spreadsheet or Grafana panel
  - **Done**: Dashboard (or spreadsheet) exists with all entity counts and deltas

### Phase 7: Documentation (T41-T42)

- [ ] **T41 [M]** Write unified migration runbook (`docs/migrations/MIGRATION_RUNBOOK.md`) | Req: Rollout | Depends: T31,T34
  - Pre-migration checklist (credentials, disk space, pod health)
  - Step-by-step execution sequence (backup, export, transform, import, verify)
  - Maintenance window announcement template
  - Post-migration validation checklist (counts, UI spot-checks, video playback, programs)
  - Sign-off criteria (<0.5% discrepancy)
  - Rollback procedures (full restore, selective unenroll, re-run from scratch)
  - **Done**: Runbook is complete and covers all phases; reviewed by migration squad

- [ ] **T42 [S]** Update migration README and link to spec (`scripts/migrations/README.md`, `docs/migrations/README.md`) |Req: Docs | Depends: T41
  - Link to spec, runbook, and verification scripts
  - Update usage instructions with current script locations and flags
  - **Done**: README references spec, runbook, and all scripts

---

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Kajabi API pagination non-determinism causes missing records | Data loss | Medium | Post-export deduplication + count verification with 5% tolerance (AC-001) |
| MCT Azure SAS tokens expire mid-video-upload | Partial video migration | High | Re-export with `--force` immediately before video upload (T28) |
| MCT service principal expires before final re-migration | Export impossible | Low (expiry 2026-12-17) | Alert 30 days inadvance (T39); renew proactively |
| K8s pod restarts during long import batches | Interrupted import | High (observed frequently) | Resilient import wrapperwith pod re-resolution (T22) |
| Email collisions between Kajabi and MCT create duplicate accounts | Data integrity | Medium | Email-keyed `update_or_create`; cross-system reconciliation (T19) |
| OLX import fails for individual courses due to malformed content | Missing courses | Low | Per-course import with `--only` retry; log and count failures (T20) |
| Mux re-upload creates duplicate assets (not deduplicated byURL) | Wasted storage + confusion | Medium | Track uploads in `mux_upload_results.json`; skip already-uploaded (T27) |
| Insufficient disk space for full export | Export fails | Low | Check disk space in pre-migration checklist (T41) |

## Open Questions (Blocking)

| OQ | Question | Impact on Tasks |
|----|----------|-----------------|
| OQ-001 | Kajabi lesson HTML content: scrape or accept placeholders? | Affects T12 (OLX content richness) |
| OQ-004 | Should MCT users with zero enrollments be imported? | Affects T11 count expectations (~69K vs enrolled-only subset) |
| OQ-005 | How to restore MCT completion percentages in OpenedX? | Affects T21 (enrollment import may need custom tracking log injection) |
| OQ-007 | Certificate handling for 4 Kajabi courses withoutcompletion tags (DP, DT, AI, PKMU)? | Affects T24 (certificate issuance for tagless courses) |└ specs/plans/disaster-recovery-business-continuity_plan.md (+0
---
spec: disaster-recovery-business-continuity_spec.md
tier: 3
status: draft
estimated_effort: "6-8 weeks (4 phases)"
generated: "2026-02-10"
---

# Implementation Plan: Disaster Recovery & Business Continuity

**Source Spec**: `specs/disaster-recovery-business-continuity_spec.md`
**Tier**: 3 (Data & Migrations)
**Dependencies**: Tier 0 (repository-structure, secrets-management, tutor-configuration) + Tier 1 (k8s-deployment, mongodb-atlas-integration)

## Summary

This plan formalizes existing ad-hoc DR/BC infrastructure into a spec-compliant, auditable framework. Most backup toolingalready exists (Velero schedules, Atlas snapshots, restore-test CronJobs, evidence bundle scripts, GCP Cloud Monitoring alerts). The work is primarily hardening, gap-filling, and adding missing monitoring/alerting/documentation rather than greenfield implementation.

The plan follows the four rollout phases defined in the spec:Baseline Hardening, Monitoring and Alerting, Cross-Region Readiness, and Compliance and Evidence.

## Prerequisites

Before starting implementation:

1. **Tier 0 complete**: Repository structure finalized, secrets management operational
2. **Tier 1 substantially complete**: GKE cluster running, MongoDB Atlas accessible
3. **Cluster access**: `kubectl` authenticated to `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`
4. **Velero installed**: Velero deployed in the `velero` namespace with GCS backend
5. **Open Questions resolved** (or accepted with documented defaults):
   - Atlas cluster tier (M0 vs M10+) -- determines Atlas backup capabilities
   - GCS backup bucket name and region
   - DR coordinator assignment
   - Budget approval for cross-region storage

## Task Breakdown

### Phase 1 -- Baseline Hardening (Week 1-2)

#### Build

- [ ] **[M]** Verify and update Velero schedule definitions to match spec RPO requirements (`infrastructure/k8s/velero/schedules/`) | AC: #1, #2, #3 | Depends: None
  - **Done**: Three schedules (hourly-critical, daily-all-apps, weekly-full) active with correct frequencies, retention, namespaces, `includeClusterResources: true`, and `volumeSnapshotLocations: ["default"]`
  - Files: New `infrastructure/k8s/velero/schedules/hourly-critical.yaml`, `daily-all-apps.yaml`, `weekly-full.yaml` (declarative schedule manifests)

- [ ] **[S]** Audit and eliminate emptyDir usage for criticalstateful services (`deploy/k8s/base/apps/`) | AC: #4 | Depends: None
  - **Done**: `./scripts/qa/audit-velero.sh` reports zero critical services using emptyDir for persistent data
  - Files: Any affected deployment manifests in `deploy/k8s/base/apps/`

- [ ] **[S]** Verify Atlas continuous backup is enabled and snapshot policy is correct | AC: #2 (Tier 2 RPO) | Depends: Open Question #1 (Atlas tier)
  - **Done**: Atlas dashboard shows continuous backup enabledfor `cluster-mereka-lms`; PITR window >= 7 days (if tier supports it)
  - Files: `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md` (update Atlas row)

- [ ] **[S]** Verify GCS backup bucket encryption and IAM restrictions (`infrastructure/terraform/`) | AC: #3 | Depends: Open Question #2 (bucket name)
  - **Done**: GCS bucket has encryption at rest, IAM restricted to Velero service account only
  - Files: `infrastructure/terraform/main.tf` (if bucket managed by Terraform; otherwise manual verification)

- [ ] **[M]** Update Backup Coverage Matrix to match spec data tier table (`docs/reference/operations/BACKUP_COVERAGE_MATRIX.md`) |AC: #19, #20 | Depends: None
  - **Done**: Matrix maps every stateful component (MySQL, MongoDB, Redis, Elasticsearch, config, images) to backup mechanism, RPO, RTO, and verification command
  - Files: `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md`

- [ ] **[S]** Verify Cloud SQL backup workflow exists in disabled state (`.github/workflows/cloud-sql-backup.yml`) | AC: (Req: legacy Cloud SQL backup) | Depends: None
  - **Done**: Workflow file exists with `ENABLE_CLOUD_SQL_BACKUPS` gate; runs only when variable is `true`
  - Files: `.github/workflows/cloud-sql-backup.yml`

- [ ] **[S]** Create pre-operation backup script or documentthe manual procedure (`scripts/infra/pre-op-backup.sh`) | AC:(Req: pre-op backup) | Depends: None
  - **Done**: Script creates `pre-op-mereka-lms-YYYYMMDD-HHMM` Velero backup with `--wait` and `--ttl 168h`; exits non-zero if backup fails or takes >10 minutes
  - Files: `scripts/infra/pre-op-backup.sh`

#### Test (Phase 1)

- [ ] **[M]** Run `./scripts/qa/audit-velero.sh --json` end-to-end and fix any failures | AC: #1 | Depends: Schedule verification task
  - **Done**: Script returns exit 0 with all three schedulesreporting `Completed` and non-zero `volumeSnapshotsCompleted`

- [ ] **[S]** Verify BSL phase is `Available` via kubectl | AC: #3 | Depends: None
  - **Done**: `kubectl -n velero get backupstoragelocation default -o jsonpath='{.status.phase}'` returns `Available`

#### Docs (Phase 1)

- [ ] **[S]** Update `docs/operations/DISASTER_RECOVERY.md` with spec RPO/RTO table and scenario matrix (`docs/operations/DISASTER_RECOVERY.md`) | AC: #15-#18 | Depends: None
  - **Done**: DR doc contains the 6-tier RPO/RTO table and the 11-scenario DR matrix with response procedures

- [ ] **[S]** Update `docs/ops/runbooks/SECRET_ROTATION_CHECKLIST.md` to cover DR-006 scenario (`docs/ops/runbooks/SECRET_ROTATION_CHECKLIST.md`) | AC: #17 | Depends: None
  - **Done**: Checklist includes Infisical rotation, GCP SM sync, ExternalSecrets resync, pod restart, and 1-hour target

---

### Phase 2 -- Monitoring and Alerting (Week 3-4)

#### Build

- [ ] **[M]** Create PrometheusRule for Velero backup/restorealerts (`deploy/k8s/base/monitoring/prometheusrule-velero.yaml`) | AC: #12, #13, #14 | Depends: Phase 1 complete
  - **Done**: PrometheusRule includes rules for `VeleroBackupFailed`, `VeleroBackupStale`, `VeleroRestoreTestStale`, `VeleroSnapshotMismatch`, `BackupVerificationFailed`, `EmptyDirCriticalData`
  - Files: `deploy/k8s/base/monitoring/prometheusrule-velero.yaml`, `deploy/k8s/base/monitoring/kustomization.yaml` (add to resources)

- [ ] **[M]** Create or update GCP Cloud Monitoring alert policies for Velero log-based metrics (`infrastructure/monitoring/alerts/`) | AC: #12, #13 | Depends: None
  - **Done**: All 8 alert policies from the spec Observability section exist in GCP Cloud Monitoring; alert pipeline auditreturns all-green
  - Files: `infrastructure/monitoring/alerts/*.json` (alreadypartially exist; verify completeness), `infrastructure/monitoring/logging-metrics/*.json`

- [ ] **[S]** Add custom metrics exporter for `dr_evidence_bundle_age_days` and `dr_restore_drill_age_days` (`scripts/qa/export-dr-metrics.sh`) | AC: #13 (stale drill) | Depends: None
  - **Done**: Script calculates evidence bundle age and restore drill age; pushes to Prometheus Pushgateway or writes to GCP custom metrics
  - Files: `scripts/qa/export-dr-metrics.sh`

- [ ] **[M]** Create Grafana DR Health dashboard JSON model (`infrastructure/monitoring/grafana/dashboard-dr-health.json`)| AC: (Obs: DR dashboard) | Depends: Metrics exporter
  - **Done**: Dashboard shows backup freshness per schedule,restore drill history, volume snapshot vs PVC count, evidencebundle freshness, alert pipeline health
  - Files: `infrastructure/monitoring/grafana/dashboard-dr-health.json`

- [ ] **[S]** Add Velero backup health panel to existing Operations Signals dashboard (`infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`) | AC: (Obs: Operations Signals panel) | Depends: None
  - **Done**: Existing dashboard includes a Velero section with backup age and success/failure counters
  - Files: `infrastructure/monitoring/grafana/dashboard-contract.bbi-mereka-lms.json`

#### Test (Phase 2)

- [ ] **[M]** Run `./scripts/qa/audit-velero-alert-pipeline.sh --json` with `STRICT_RUNTIME=1` and verify all checks pass| AC: #12, #13, #14 | Depends: Alert policy creation
  - **Done**: Script returns exit 0 with all log metrics, alert policies, and freshness signals green

- [ ] **[S]** Run `./scripts/qa/verify-alert-routing.sh` to confirm alerts reach on-call | AC: #12 | Depends: Alert policies
  - **Done**: Test alert fires and is received by the configured notification channel

---

### Phase 3 -- Cross-Region Readiness (Week 5-8)

#### Build

- [ ] **[M]** Configure GCS backup bucket for multi-region storage or cross-region replication (`infrastructure/terraform/main.tf`) | AC: #22 | Depends: Open Question #5 (budget)
  - **Done**: Bucket storage class is `MULTI_REGIONAL` or a secondary bucket exists with object replication enabled
  - Files: `infrastructure/terraform/main.tf` or manual GCS config

- [ ] **[S]** Enable Artifact Registry multi-region replication (`infrastructure/terraform/main.tf`) | AC: (Req: containerimage replication) | Depends: Open Question #5 (budget)
  - **Done**: `ghcr.io/biji-biji-initiative/mereka-lms` repository has multi-region replication configured
  - Files: `infrastructure/terraform/main.tf`

- [ ] **[M]** Verify Terraform/Kustomize can produce valid manifests for secondary region (`infrastructure/terraform/`, `deploy/k8s/overlays/production/`) | AC: #21 | Depends: None
  - **Done**: `kubectl kustomize deploy/k8s/overlays/production` produces valid YAML; Terraform can plan a secondary cluster without errors
  - Files: `infrastructure/terraform/variables.tf` (region parameterized), `deploy/k8s/overlays/production/kustomization.yaml`

- [ ] **[S]** Verify MongoDB Atlas cluster is accessible frommultiple GCP regions (Atlas networking) | AC: (Req: Atlas cross-region) | Depends: None
  - **Done**: Atlas IP allowlist includes secondary region CIDR or peering is configured for both regions
  - Files: `docs/operations/DISASTER_RECOVERY.md` (document Atlas networking for DR)

- [ ] **[M]** Document cross-region DNS cutover procedure viaCloudflare (`docs/operations/DISASTER_RECOVERY.md`) | AC: (Req: DNS failover) | Depends: None
  - **Done**: Step-by-step procedure for switching `academyv2.mereka.io` DNS to secondary region via Cloudflare API/UI
  - Files: `docs/operations/DISASTER_RECOVERY.md`

#### Test (Phase 3)

- [ ] **[S]** Dry-run `kubectl kustomize deploy/k8s/overlays/production` and validate output | AC: #21 | Depends: Kustomize verification
  - **Done**: Command succeeds and output passes `kubectl apply --dry-run=server`

- [ ] **[M]** Conduct tabletop exercise for DR-007 (full cluster loss) scenario | AC: #18 | Depends: All Phase 3 build tasks
  - **Done**: Team walks through the full cluster rebuild procedure; gaps documented and remediated

---

### Phase 4 -- Compliance and Evidence (Week 9-10)

#### Build

- [ ] **[M]** Verify and harden DR evidence bundle workflow (`.github/workflows/dr-evidence-bundle.yml`, `scripts/qa/build-dr-evidence-bundle.sh`) | AC: #9, #10, #11 | Depends: Phasecomplete
  - **Done**: `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar` produces tarball with all 6 required artifacts; GitHub Actions workflow runs monthly on the 1st at 02:3UTC with 120-day artifact retention
  - Files: `.github/workflows/dr-evidence-bundle.yml`, `scripts/qa/build-dr-evidence-bundle.sh`

- [ ] **[S]** Configure evidence retention for 12 months (`docs/operations/DISASTER_RECOVERY.md`) | AC: #10, #11 | Depends: Evidence bundle verification
  - **Done**: Retention policy documented; GCS archive bucketor GitHub artifact retention configured for 12-month minimum
  - Files: `docs/operations/DISASTER_RECOVERY.md`, `.github/workflows/dr-evidence-bundle.yml`

- [ ] **[M]** Harden restore-test CronJob and backup-verification CronJob (`infrastructure/k8s/velero/`) | AC: #5, #6, #7,#8 | Depends: Phase 1 complete
  - **Done**: Monthly restore-test CronJob creates throwawaynamespace, restores PVCs to Bound state, runs MySQL `SELECT 1` probe, cleans up within 1 hour. Daily backup-verification CronJob confirms freshness within 2h (hourly) and 26h (daily).
  - Files: `infrastructure/k8s/velero/restore-test-cronjob.yaml` (new or updated), `infrastructure/k8s/velero/backup-verification-cronjob.yaml` (new or updated), `infrastructure/k8s/velero/restore-test-script.sh`

- [ ] **[S]** Create DR compliance report template for enterprise clients (`docs/operations/DR_COMPLIANCE_REPORT_TEMPLATE.md`) | AC: #11 | Depends: Evidence bundle
  - **Done**: Template exists with sections for RPO/RTO commitments, backup health summary, restore drill results, evidence bundle inventory, and next-drill date
  - Files: `docs/operations/DR_COMPLIANCE_REPORT_TEMPLATE.md`

- [ ] **[M]** Create incident communication plan and escalation matrix (`docs/operations/DISASTER_RECOVERY.md`) | AC: (Req: business continuity) | Depends: Open Question #4 (DR coordinators)
  - **Done**: DR doc includes P1-P4 escalation tiers, notification channels, DR coordinator contacts, postmortem template,and tabletop exercise schedule
  - Files: `docs/operations/DISASTER_RECOVERY.md`

#### Test (Phase 4)

- [ ] **[M]** Run full restore drill via `./scripts/infra/fix-velero-restore-test.sh` and verify end-to-end | AC: #5, #6,#7 | Depends: CronJob hardening
  - **Done**: Restore creates throwaway namespace, PVCs are Bound, MySQL probe succeeds, namespace cleaned up

- [ ] **[M]** Run `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar` and inspect tarball contents | AC: #9| Depends: Evidence bundle hardening
  - **Done**: Tarball contains `audit-velero.json`, `audit-velero-alert-pipeline.json`, `audit-observability-runtime.json`, restore-test logs, PVC summary, MySQL probe result

- [ ] **[S]** Verify `./scripts/qa/public-health-check.sh prod` passes against production | AC: #20 | Depends: None
  - **Done**: All endpoints (LMS, Studio, Discovery, Ecommerce) return 200/302

---

### Cross-Phase Tasks

#### Observability

- [ ] **[S]** Ensure Velero controller logs are collected byLoki/Promtail (`infrastructure/monitoring/`) | Req: OBS-logs| Depends: None
  - **Done**: `kubectl logs -n velero -l app.kubernetes.io/name=velero` output is forwarded to Loki

- [ ] **[S]** Ensure restore-test and backup-verification joblogs are collected (`infrastructure/monitoring/`) | Req: OBS-logs | Depends: None
  - **Done**: Job logs with labels `component=restore-test` and `component=backup-verification` are forwarded to Loki

#### Docs

- [ ] **[S]** Update `docs/ops/runbooks/VELERO_BACKUP_AUDIT.md`with spec-aligned procedures (`docs/ops/runbooks/VELERO_BACKUP_AUDIT.md`) | Depends: Phase 1
  - **Done**: Doc references all three schedules, links to audit scripts, and includes troubleshooting for edge cases

- [ ] **[S]** Update `docs/ops/runbooks/COURSE_DATA_RECOVERY.md` with spec-aligned recovery procedures (`docs/ops/runbooks/COURSE_DATA_RECOVERY.md`) | Depends: Phase 1
  - **Done**: Doc covers Tier 1 (MySQL) and Tier 2 (MongoDB)recovery with specific commands and verification steps

- [ ] **[S]** Update `docs/ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md` with DR alert response procedures (`docs/ops/runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md`) | Depends: Phase 2
  - **Done**: Playbook includes response procedures for all 8DR-related alerts

- [ ] **[S]** Ensure `docs/operations/DR_TEST_RESULTS.md` isupdated after each drill (`docs/operations/DR_TEST_RESULTS.md`) | Depends: Phase 4
  - **Done**: Document includes drill history with dates, results, and remediation actions

#### Rollout

- [ ] **[S]** Verify `ENABLE_CLOUD_SQL_BACKUPS` GitHub Actions variable exists in disabled state | Depends: None
  - **Done**: Variable exists in repo settings, set to `false`

- [ ] **[S]** Verify `STRICT_RUNTIME` env var behavior in evidence bundle script | Depends: None
  - **Done**: `STRICT_RUNTIME=0` warns on missing deps; `STRICT_RUNTIME=1` fails on missing deps

---

## Milestones

| Milestone | Target | Gate Criteria |
|-----------|--------|---------------|
| Phase 1 Complete | Week 2 | `./scripts/qa/audit-velero.sh`all-green; RPO/RTO table in DR doc |
| Phase 2 Complete | Week 4 | All spec alerts active; `audit-velero-alert-pipeline.sh` all-green |
| Phase 3 Complete | Week 8 | GCS multi-region verified; tabletop exercise completed |
| Phase 4 Complete | Week 10 | Evidence bundle complete; compliance report template created |
| Spec IMPLEMENTED | Week 10 | All 22 ACs verified; testmap coverage 100% |

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Atlas cluster is M0 (free tier) -- no continuous backup | Tier 2 RPO unachievable | Upgrade Atlas tier (requires budgetapproval) |
| GCS bucket is single-region | Cross-region recovery impossible if region fails | Migrate to multi-region storage class (Phase 3) |
| No budget for cross-region | Phase 3 partially blocked | Document as accepted risk; implement what is budget-neutral |
| DR coordinator not assigned | Business continuity plan incomplete | Escalate to leadership; assign interim coordinator |
| Velero CSI driver issues | Volume snapshots may silently fail | `audit-velero.sh` catches this; fix CSI driver config |
| Restore drill namespace stuck in Terminating | Blocks subsequent drills | `fix-velero-restore-test.sh` handles finalizercleanup |
| Clock skew on GKE nodes | False stale-backup alerts | NTP is GKE default; verify in audit scripts using UTC |

## Complexity Summary

| Category | S (<2h) | M (2-8h) | L (>8h) | Total |
|----------|---------|----------|---------|-------|
| Build | 12 | 9 | 0 | 21 |
| Test | 3 | 4 | 0 | 7 |
| Observability | 2 | 0 | 0 | 2 |
| Docs | 6 | 0 | 0 | 6 |
| Rollout | 2 | 0 | 0 | 2 |
| **Total** | **25** | **13** | **0** | **38** |

Estimated total effort: **~80-100 hours** across 6-8 calendarweeks (accounting for cluster access, testing delays, and open question resolution).
