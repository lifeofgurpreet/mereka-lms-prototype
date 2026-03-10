---
spec: data-migrations-kajabi-mct_spec.md
tier: 3
status: draft
last_updated: '2026-02-10'
plan: data-migrations-kajabi-mct_plan.md
---

# Test Plan: Data Migrations -- Kajabi & MCT

**Source Spec**: `specs/data-migrations-kajabi-mct_spec.md`

## Test Framework

This project does not use a standard unit test framework (no `vitest.config`, `jest.config`, `pytest.ini`, or `go.mod` for testing). Migrations are validated through:

- **`shell_verification`**: Bash scripts that check file existence, row counts, format correctness, and command exit codes
- **`manual_verification`**: Human-executed checklists for UI spot-checks, login tests, and visual content inspection

All shell verification scripts live under `scripts/qa/` and `scripts/migrations/`. Manual verification steps are documented in `docs/ops/runbooks/migrations/`.

## Test Matrix

### Export Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-001 | Kajabi export produces 17 NDJSON files in `exports/kajabi/` with row counts matching API total headers (within 5% tolerance) | shell_verification | `scripts/qa/verify-kajabi-export.sh` | Valid Kajabi API credentials in Infisical; `exports/kajabi/` directory exists |
| AC-001 | Kajabi export deduplicates records post-export (contacts by email, others by record ID) | shell_verification | `scripts/qa/verify-kajabi-export.sh` -- dedup check section | Raw NDJSON files from export |
| AC-001 (negative) | Kajabi export fails gracefully when API credentials are missing/invalid | shell_verification | `scripts/qa/verify-kajabi-export.sh --test-invalid-creds` | Intentionally invalid or missing credentials |
| AC-002 | MCT export produces users, categories, courses, and enrollment NDJSON files in `exports/mct/` within 1% of platform statistics | shell_verification | `scripts/qa/verify-mct-export.sh` | Valid MCT Azure AD credentials; `exports/mct/` directory exists |
| AC-002 (negative) | MCT export handles expired Azure AD token gracefully (fails fast with clear error) | shell_verification | `scripts/qa/verify-mct-export.sh --test-expired-token` | Expired or invalid MCT credentials |
| AC-003 | Kajabi completions export uses `filter[has_tag_id]` and produces correct `tag_type` classification | shell_verification | `scripts/qa/verify-kajabi-completions-export.sh` | Completions NDJSON file |
| AC-004 | MCT export with `--resources courses --force` produces fresh video URLs valid for 6+ hours | shell_verification | `scripts/qa/verify-mct-video-urls.sh` | MCT export re-run with `--force`; `curl` to check URL accessibility |

### Transform Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-005 | Kajabi `users_import.csv` contains only enrolled users (~73K, not 326K contacts) | shell_verification | `scripts/qa/verify-kajabi-transform.sh` | `scripts/migrations/kajabi/output/openedx/users_import.csv` |
| AC-005 (negative) | Kajabi transform skips contacts without email addresses (logged and counted) | shell_verification | `scripts/qa/verify-kajabi-transform.sh --check-skips` | Raw contacts NDJSON with some empty-email entries |
| AC-006 | Kajabi `enrollments_import.csv` contains deduplicated (email, course_id) pairs with no duplicates | shell_verification | `scripts/qa/verify-kajabi-transform.sh --check-enrollments` | `scripts/migrations/kajabi/output/openedx/enrollments_import.csv` |
| AC-007 | MCT transform produces exactly 30 course packages (category-level mapping, not 81 or 178) | shell_verification | `scripts/qa/verify-mct-transform.sh` | MCT NDJSON exports; generated OLX packages |
| AC-007 (negative) | MCT transform rejects creation of per-course packages (81) instead of per-category (30) | shell_verification | `scripts/qa/verify-mct-transform.sh --check-overcreation` | MCT NDJSON exports |
| AC-008 | MCT enrollment deduplication reduces 2.3M raw to ~441K unique (user, category) pairs | shell_verification | `scripts/qa/verify-mct-transform.sh --check-enrollment-dedup` | MCT enrollment NDJSON |
| AC-009 | Kajabi produces 109 OLX tarballs with course keys in `course-v1:MEREKA+MEKA-{id}+RUN-{id}` format | shell_verification | `scripts/qa/verify-kajabi-olx-packages.sh` | `course_packages_manifest.csv`; tarball directory |
| AC-010 | MCT OLX packages have correct hierarchy: Category=Course, "Course"=Section, Lesson=Unit | shell_verification | `scripts/qa/verify-mct-olx-packages.sh` | MCT OLX tarballs; extract and inspect `course.xml` structure |

### User Import Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-011 | Kajabi import creates 72K+ users each with a `UserProfile` record | shell_verification | `scripts/qa/verify-user-import-counts.sh --source kajabi` | Open edX Django shell access via `kubectl exec`; pre/post counts |
| AC-012 | MCT import creates 68K+ users (accounting for email collisions with Kajabi users) | shell_verification | `scripts/qa/verify-user-import-counts.sh --source mct` | Open edX Django shell access; pre/post counts |
| AC-013 | User present in both Kajabi and MCT results in exactly one Open edX account with enrollments from both | shell_verification | `scripts/qa/verify-cross-system-identity.sh` | Known overlapping email addresses from both exports |
| AC-013 (negative) | Duplicate user accounts are not created when same email exists in both systems | shell_verification | `scripts/qa/verify-cross-system-identity.sh --check-no-duplicates` | Django shell query for duplicate emails |
| AC-014 | Import resumes from last offset after pod restart (no duplicate users created) | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "Pod Restart Recovery" | Simulate pod restart mid-import; check offset file and re-run |

### Course Import Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-015 | 109 Kajabi courses visible in MongoDB `modulestore.active_versions` and Studio | shell_verification | `scripts/qa/verify-course-import-counts.sh --source kajabi` | MongoDB Atlas shell access; `kubectl exec` to CMS pod |
| AC-016 | 30 MCT courses have correct Section/Unit structure with Mux video playback URLs | shell_verification | `scripts/qa/verify-course-import-counts.sh --source mct` | MongoDB Atlas query; sample XBlock inspection |
| AC-017 | Sample Kajabi course has expected module/lesson count matching `course_structure.json` | shell_verification | `scripts/qa/verify-course-structure-sample.sh --source kajabi` | `course_structure.json`; modulestore query |
| AC-018 | MCT "Basic Microsoft" course contains 12 sections matching 12 MCT "Courses" under that category | shell_verification | `scripts/qa/verify-course-structure-sample.sh --source mct --course basic-microsoft` | Studio inspection or modulestore query |
| AC-018 (negative) | MCT course with empty category (no lessons) is handled gracefully (skipped or empty course created) | shell_verification | `scripts/qa/verify-mct-olx-packages.sh --check-empty-categories` | MCT NDJSON with empty categories |

### Enrollment Import Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-019 | Kajabi enrollment count increases by 146K+ after import | shell_verification | `scripts/qa/verify-enrollment-import-counts.sh --source kajabi` | Open edX Django shell; pre/post enrollment counts |
| AC-020 | MCT enrollment count increases by 440K+ after import | shell_verification | `scripts/qa/verify-enrollment-import-counts.sh --source mct` | Open edX Django shell; pre/post enrollment counts |
| AC-021 | Enrollment for non-existent user is skipped with log entry (batch continues) | shell_verification | `scripts/qa/verify-enrollment-skip-handling.sh --check user-not-found` | Import logs in `scripts/migrations/{source}/logs/` |
| AC-021 (negative) | Batch does not abort when a single enrollment references a non-existent user | shell_verification | `scripts/qa/verify-enrollment-skip-handling.sh --check batch-continues` | Import logs showing batch completion after skip |
| AC-022 | Enrollment for non-existent course is skipped with log entry (batch continues) | shell_verification | `scripts/qa/verify-enrollment-skip-handling.sh --check course-not-found` | Import logs |
| AC-022 (negative) | Batch does not abort when a single enrollment references a non-existent course | shell_verification | `scripts/qa/verify-enrollment-skip-handling.sh --check batch-continues-course` | Import logs showing batch completion after skip |

### Certificate Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-023 | `GeneratedCertificate` records created for all mappable (email, course_key) pairs with `downloadable` status | shell_verification | `scripts/qa/verify-certificate-issuance.sh --source kajabi` | Django shell; `tag_prefix_to_course_mapping.json` |
| AC-024 | At least 3,265 certificates issued from 3,268 completion records (3 unfound emails logged) | shell_verification | `scripts/qa/verify-certificate-issuance.sh --check-counts` | Certificate issuance log; Django shell count |
| AC-024 (negative) | Certificate issuance skips unfound emails without failing the pipeline | shell_verification | `scripts/qa/verify-certificate-issuance.sh --check-skips` | Certificate issuance log showing skip entries |
| AC-025 | MCT ProgramCertificate records exist in Credentials service for each program | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "MCT Program Certificates" | Discovery admin UI; Credentials service API |

### Video Migration Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-026 | 503 Mux assets created with proper titles and playback IDs | shell_verification | `scripts/qa/verify-mux-video-upload.sh` | `mux_upload_results.json`; Mux API key for list query |
| AC-027 | 34 videos with VTT captions have caption tracks in Mux | shell_verification | `scripts/qa/verify-mux-video-upload.sh --check-captions` | `mux_upload_results.json`; Mux API query for caption tracks |
| AC-027 (negative) | Videos without captions do not have erroneous caption tracks | shell_verification | `scripts/qa/verify-mux-video-upload.sh --check-no-spurious-captions` | `mux_upload_results.json` |
| AC-028 | Video XBlocks in OLX contain `https://stream.mux.com/{PLAYBACK_ID}.m3u8` source URLs | shell_verification | `scripts/qa/verify-mct-olx-packages.sh --check-video-xblocks` | OLX tarballs; grep for Mux URL pattern |
| AC-029 | Kajabi `course_image` field updated in modulestore for 109 courses | shell_verification | `scripts/qa/verify-kajabi-thumbnails.sh` | MongoDB Atlas modulestore query |
| AC-029 (negative) | Courses with missing thumbnail URLs are skipped gracefully (not set to empty/broken image) | shell_verification | `scripts/qa/verify-kajabi-thumbnails.sh --check-missing` | Import log for thumbnail upload |

### Verification Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-030 | Count verification shows <0.5% discrepancy for Users, Enrollments, and Courses | shell_verification | `scripts/migrations/run-verification-pipeline.sh` | Full migration completed; Django shell access |
| AC-030 (negative) | Verification flags discrepancies >0.5% with error and non-zero exit code | shell_verification | `scripts/qa/verify-migration-counts.sh --simulate-discrepancy` | Synthetic count mismatch |
| AC-031 | Comparison report produced per course with discrepancy explanations | shell_verification | `scripts/migrations/run-verification-pipeline.sh` -- output check | `scripts/migrations/kajabi/output/verification/` directory |
| AC-032 | 10 sample courses render correctly in Studio (sections, units, content visible) | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "Studio Course Spot-Check" | Studio UI access; list of 10 sample course keys |
| AC-033 | 5 sample users see enrolled courses in LMS dashboard after login | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "User Login Spot-Check" | LMS access; 5 sample user credentials |

### Rollback Phase Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-034 | Database restore via `tutor local do restore-db` reverts to pre-migration state | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "Full Rollback Test" | Pre-migration MySQL and MongoDB backups |
| AC-035 | Rollback script with `--action unenroll --dry-run` reports correct count without modifying data | shell_verification | `scripts/qa/verify-rollback-dry-run.sh` | `rollback-openedx-imports.py`; enrollment CSV |
| AC-035 (negative) | Dry-run mode does not modify any enrollment records | shell_verification | `scripts/qa/verify-rollback-dry-run.sh --check-no-mutations` | Pre/post enrollment count comparison |
| AC-036 | Re-executing full import pipeline after failure creates no duplicate records | shell_verification | `scripts/qa/verify-idempotency.sh` | Two successive pipeline runs; entity count comparison |

### Idempotency & Re-migration Tests

| AC # | Test Case | Type | File / Command | Fixtures / Prerequisites |
|------|-----------|------|----------------|--------------------------|
| AC-037 | Full pipeline re-execution with same export data produces unchanged entity counts | shell_verification | `scripts/qa/verify-idempotency.sh --full-pipeline` | Two successive full pipeline runs; pre/post count comparison |
| AC-037 (negative) | Re-execution does not create duplicate users, enrollments, or certificates | shell_verification | `scripts/qa/verify-idempotency.sh --check-no-duplicates` | Django shell queries for duplicate emails, duplicate (user,course) enrollments |
| AC-038 | Fresh export+import with net-new records creates only the net-new records | shell_verification | `scripts/qa/verify-incremental-sync.sh` | Synthetic new record added to export; pre/post count delta = 1 |

### Edge Case / Negative Tests

| Edge Case | Test Case | Type | File / Command | Fixtures / Prerequisites |
|-----------|-----------|------|----------------|--------------------------|
| Kajabi API rate limiting (429) | Export survives 429 with exponential backoff | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "Rate Limit Handling" | Export log showing 429 retries |
| Kajabi API pagination duplicates | Post-export dedup removes duplicate pages | shell_verification | `scripts/qa/verify-kajabi-export.sh --check-dedup-stats` | Dedup log in export output |
| MCT SAS token expiry | Video upload pipeline re-exports fresh URLs before upload | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "SAS Token Refresh" | Upload log; video URL validity check |
| Pod restart during import | Import resumes from last offset; no duplicates | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "Pod Restart Recovery" | Simulate pod kill; check offset and re-run |
| Pod OOM during course import | CMS pod restarts; failed course retried with `--only` flag | manual_verification | `docs/ops/runbooks/migrations/VERIFICATION_CHECKLIST.md` -- Section: "OOM Recovery" | Monitor pod memory; retry single course |
| Users without emails | Skipped in transform; count logged | shell_verification | `scripts/qa/verify-kajabi-transform.sh --check-skips` | Raw contacts NDJSON |
| Duplicate usernames | Collision avoidance suffix applied | shell_verification | `scripts/qa/verify-user-import-counts.sh --check-username-collisions` | Django shell query for username patterns |
| Missing UserProfile | Created before certificate issuance | shell_verification | `scripts/qa/verify-certificate-issuance.sh --check-profiles` | Django shell query |
| Partial Mux upload | Re-run skips already-uploaded; completes remaining | shell_verification | `scripts/qa/verify-mux-video-upload.sh --check-resume` | `mux_upload_results.json` with partial data |
| Partial batch completion | Offset file tracks position; re-run resumes | shell_verification | `scripts/qa/verify-enrollment-skip-handling.sh --check-offset-resume` | Offset file; interrupt and resume |
| Security: secrets not logged | No raw passwords/tokens in log files | shell_verification | `scripts/qa/scan-secrets-fast.sh` applied to migration logs | Migration log files |
| Security: PII in gitignored dirs | `exports/` directory is in `.gitignore` | shell_verification | `scripts/qa/verify-exports-gitignored.sh` | `.gitignore` file |

## Test Execution Order

1. **Pre-migration**: Run dry-run (`scripts/migrations/run-dry-run.sh`) to verify API access
2. **Post-export**: Run export verification scripts (AC-001 through AC-004)
3. **Post-transform**: Run transform verification scripts (AC-005 through AC-010)
4. **Post-user-import**: Run user count checks (AC-011 through AC-014)
5. **Post-course-import**: Run course count and structure checks (AC-015 through AC-018)
6. **Post-enrollment-import**: Run enrollment count and skip checks (AC-019 through AC-022)
7. **Post-certificate**: Run certificate count checks (AC-023 through AC-025)
8. **Post-video**: Run Mux upload and XBlock checks (AC-026 through AC-029)
9. **Final verification**: Run unified verification pipeline (AC-030 through AC-033)
10. **Rollback validation**: Run rollback tests in staging (AC-034 through AC-036)
11. **Idempotency**: Run full pipeline twice and compare (AC-037, AC-038)

## Coverage Summary

| Category | Total ACs | Automated (shell_verification) | Manual (manual_verification) |
|----------|-----------|-------------------------------|------------------------------|
| Export | 4 | 4 | 0 |
| Transform | 6 | 6 | 0 |
| User Import | 4 | 3 | 1 |
| Course Import | 4 | 4 | 0 |
| Enrollment Import | 4 | 4 | 0 |
| Certificate | 3 | 2 | 1 |
| Video | 4 | 4 | 0 |
| Verification | 4 | 2 | 2 |
| Rollback | 3 | 2 | 1 |
| Idempotency | 2 | 2 | 0 |
| **Total** | **38** | **33** | **5** |

Manual verification is justified for:
- **AC-014**: Pod restart recovery requires intentional pod kill during import -- cannot be safely automated in production
- **AC-025**: MCT ProgramCertificate verification requires Discovery admin UI navigation
- **AC-032**: Studio course rendering is a visual check (sections, units, content display)
- **AC-033**: User login spot-check requires browser-based LMS dashboard verification
- **AC-034**: Full database rollback test is destructive and must be performed manually in staging
