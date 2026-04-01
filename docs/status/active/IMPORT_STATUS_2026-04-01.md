# Import Lane Status — 2026-04-01

> **Branch**: `feat/import-lane-closure`
> **Last updated**: 2026-04-01T03:00Z
> **Lane owner**: LMS-I (import)

## Import Evidence Summary

### Verified COMPLETE (import-owned, data on disk)

| What | Count | Verification |
|------|-------|-------------|
| Courses in modulestore | 36 | `verify-course-import-counts.sh --source mct` PASS |
| MCT users (export file) | 69,419 | `verify-user-import-counts.sh --source mct` PASS |
| Kajabi users (export file) | 73,107 | `verify-user-import-counts.sh --source kajabi` PASS |
| MCT enrollments (unique pairs) | 441,578 | `verify-enrollment-import-counts.sh --source mct` PASS |
| Kajabi enrollments (unique pairs) | 147,971 | `verify-enrollment-import-counts.sh --source kajabi` PASS |
| Mux video assets | 503 MCT + 72 Drive = 575 | `verify-mux-upload-completeness.sh` PASS |
| Kajabi completions | 11,179 | `verify-kajabi-completions-export.sh` PASS |
| OLX packages (MCT) | 28 tarballs | Built via `build_course_packages.py` |
| OLX packages (FOW/UPAI) | 9 tarballs | Built via `build_course_packages.py` |

### In dev database (runtime state — `mereka-lms-dev` on rke2-nonprod)

| What | Count | Notes |
|------|-------|-------|
| Courses (modulestore) | 36 | All `org=MEREKA`, `run=course` |
| Users | 99,928 | Mix of MCT import + pre-existing from old Kajabi migration |
| Enrollments | 176,320 | MCT (68K new) + Kajabi (106K new) + pre-existing |
| Enterprise customers | 3 | Mereka Academy, Skill Our Future, Biji-Biji Academy |
| Organizations | 3 | MEREKA, BIJIBIJI, SKILLOURFUTURE |
| Block structures | 14/36 | Platform/runtime limitation — see below |

### Post-import items — APPLIED TO DEV (runtime-only, need repo scripts)

| Item | Applied | Script in repo | Verified |
|------|---------|----------------|----------|
| Course descriptions | 30/36 applied to dev | `post_import_metadata.py` BEING CREATED | Not re-verifiable yet |
| Course images (Mux thumbs) | 31/36 applied to dev | `post_import_metadata.py` BEING CREATED | Not re-verifiable yet |
| Enterprise catalogs | 3 catalogs created in dev | `post_import_enterprise_catalogs.py` ✓ | Idempotent, re-runnable |
| Taxonomy tags | 108 tags applied in dev | `post_import_taxonomy.py` ✓ | Idempotent, re-runnable |
| Kajabi completions | 3,648 certs created in dev | `post_import_completions.py` ✓ | Idempotent, re-runnable |

### Import-owned work REMAINING

#### A. Metadata script codification
- Descriptions + images were applied to dev via an ad-hoc session.
- `scripts/migrations/post_import_metadata.py` does not yet exist in the repo.
- **Status**: Being recreated. Until it exists and is wired into `run_full_import.sh` Phase 5, metadata is NOT repeatable.

#### B. Missing courses decision
- **PB-EN**: MCT32-EN has the same content. 2,957 Kajabi completions reference PB-EN. Decision needed: create alias or remap.
- **UPAI1-EN, UPAI3-EN**: Videos may exist in Mux from Drive upload batch. OLX packages not built.
- **Skills Test (8 courses)**: 0 ready videos. Defer.
- **Status**: Decision document being written (`docs/status/active/IMPORT_MISSING_COURSES.md`).

#### C. User mapping scripts
- `scripts/migrations/mct/map_mct_users_to_openedx.py` and `scripts/migrations/kajabi/map_kajabi_users_to_openedx.py` do not exist in repo.
- These generate the user/enrollment import CSVs from raw exports.
- The CSVs themselves exist on disk, but the generation is not repeatable without these scripts.
- **Status**: Being recreated.

#### D. Drive upload script
- `scripts/migrations/drive/upload_drive_videos_to_mux.py` does not exist in repo.
- The 72 Drive videos were uploaded to Mux via ad-hoc session using Composio R2 proxy.
- **Status**: Being recreated.

### Master import pipeline

| Artifact | Exists | Status |
|----------|--------|--------|
| `scripts/migrations/run_full_import.sh` | ✓ | 946 lines, 9 phases, `--env dev\|staging\|prod`, dry-run, shellcheck clean |
| `scripts/migrations/IMPORT_RUNBOOK.md` | ✓ | 493 lines, per-phase reference, troubleshooting |
| Phase 0 (verify) | ✓ | Dry-run PASS on dev |
| Phase 1 (courses) | ✓ | Uses existing OLX import pattern |
| Phase 2 (users) | ✓ | Uses `openedx_bulk_import_mct.py` (column fix applied) |
| Phase 3 (enrollments) | ✓ | Uses bulk import with batching |
| Phase 4 (completions) | ✓ | Uses `post_import_completions.py` |
| Phase 5 (metadata) | ✗ | Skips if `post_import_metadata.py` missing |
| Phase 6 (catalogs) | ✓ | Uses `post_import_enterprise_catalogs.py` |
| Phase 7 (taxonomy) | ✓ | Uses `post_import_taxonomy.py` |
| Phase 8 (verify) | ✓ | Runs qa verification scripts |

### Block structure generation — CLASSIFICATION

**Owner: Platform/Runtime** (not import-owned)

- CMS `import` command generates block structures for some courses (14/36 succeeded during import).
- Remaining 22 fail because Celery workers hit `NoSuchServiceError: Service 'user' is not available`.
- This is an XBlock runtime service initialization issue, not import data.
- Block structures generate lazily on first learner access IF platform issues are resolved.

### Runtime/platform blockers — NOT import-owned

| Blocker | Owner | Evidence |
|---------|-------|----------|
| Redis AOF I/O errors | infra-runtime | `MISCONF Errors writing to the AOF file` |
| JWT signing keys not configured | platform-config | `JWT_PRIVATE_SIGNING_JWK: False`, `InvalidAlgorithmError` |
| Enterprise consent backend OAuth | platform-config | OAuth2 Application was created ad-hoc, needs GitOps provisioning |
| Block structure generation in workers | platform-runtime | `NoSuchServiceError: Service 'user' is not available` |
| Credentials timezone/tzdata | infra-runtime | See `generate-runtime-blocker-infra-prompt.sh` |

Runtime blocker handoff bundle: `var/qa/frontend-runtime-blocker-handoff-bundle.tar.gz`

## Staging gate criteria

Import lane may NOT propose staging until:
- [ ] Dedicated import branch exists (`feat/import-lane-closure`)
- [ ] All claimed scripts exist in repo
- [ ] Import status doc matches reality
- [ ] `run_full_import.sh --env dev --dry-run` passes all phases
- [ ] Missing courses decision documented
- [ ] Runtime blockers explicitly handed off (not owned by import)
