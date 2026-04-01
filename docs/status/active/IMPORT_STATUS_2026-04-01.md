# Import Lane Status — 2026-04-01

> **Branch**: `feat/import-lane-closure`
> **Last updated**: 2026-04-01T04:30Z
> **Lane owner**: LMS-I (import)

## Import Evidence Summary

### Verified COMPLETE (import-owned, data on disk)

| What | Count | Verification |
|------|-------|-------------|
| MCT courses (OLX input) | 30 categories | `verify-course-import-counts.sh --source mct` PASS |
| MCT users (export file) | 69,419 | `verify-user-import-counts.sh --source mct` PASS |
| Kajabi users (export file) | 73,107 | `verify-user-import-counts.sh --source kajabi` PASS |
| MCT enrollments (unique pairs) | 441,578 | `verify-enrollment-import-counts.sh --source mct` PASS |
| Kajabi enrollments (unique pairs) | 147,971 | `verify-enrollment-import-counts.sh --source kajabi` PASS |
| Mux video assets | 503 MCT + 72 Drive = 575 | `verify-mux-upload-completeness.sh` PASS |
| Kajabi completions (export) | 11,179 | `verify-kajabi-completions-export.sh` PASS |
| OLX packages (MCT) | 29 tarballs (28 + MCT32-EN) | Built via `build_course_packages.py` |
| OLX packages (FOW/UPAI) | 9 tarballs | Built via `build_course_packages.py` |

### In dev database (runtime state — `mereka-lms-dev` on rke2-nonprod)

| What | Count | Notes |
|------|-------|-------|
| Courses (modulestore) | 37 | All `org=MEREKA`, `run=course`. Includes MCT32-EN (PB-EN remap). |
| Users | 99,928 | Mix of MCT import + pre-existing from old Kajabi migration |
| Enrollments | 176,320 | MCT (68K new) + Kajabi (106K new) + pre-existing |
| Certificates | 4,489 | Kajabi completions (3,648 original + 841 PB→MCT32-EN remap) |
| Enterprise customers | 3 | Mereka Academy, Skill Our Future, Biji-Biji Academy |
| Organizations | 3 | MEREKA, BIJIBIJI, SKILLOURFUTURE |
| Enterprise catalogs | 3 | Mereka (all), SOF (35 MCT+FOW), BijiBiji (1 UPAI) |
| Taxonomy tags | 108 | 36 courses × (Subject + Level + Credential Type) |
| Course descriptions | 30/37 | 7 have no source description |
| Course images | 31/37 | 6 have no video content (no Mux thumbnail) |
| Block structures | 14/37 | Platform/runtime limitation — see below |

### Post-import scripts — IN REPO on `feat/import-lane-closure`

| Script | Exists | Applied to dev | Notes |
|--------|--------|----------------|-------|
| `post_import_metadata.py` | ✓ | 30 descriptions, 31 images | Two-phase: `--build-plan` locally, apply in CMS pod |
| `post_import_enterprise_catalogs.py` | ✓ | 3 catalogs | Idempotent, re-runnable |
| `post_import_taxonomy.py` | ✓ | 108 tags | Idempotent, re-runnable |
| `post_import_completions.py` | ✓ | 4,489 certificates | Idempotent. PB→MCT32-EN remap applied. |
| `drive/upload_drive_videos_to_mux.py` | ✓ | 72 Drive videos uploaded | Supports `--dry-run`, `--skip-existing` |
| `mct/map_mct_users_to_openedx.py` | ✓ | CSVs on disk | Generates MCT user/enrollment CSVs from raw exports |
| `kajabi/map_kajabi_users_to_openedx.py` | ✓ | CSVs on disk | PB→MCT32-EN remap applied |

### Master import pipeline — `run_full_import.sh`

| Phase | Wired | Status |
|-------|-------|--------|
| 0 — Pre-flight | ✓ | Needs `EXPORTS_ROOT` hardening (see below) |
| 1 — Courses | ✓ | OLX tarballs → CMS pod → import |
| 2 — Users | ✓ | `openedx_bulk_import_mct.py` / `openedx_bulk_import.py`. Column fix applied. |
| 3 — Enrollments | ✓ | Batched at 5,000 rows |
| 4 — Completions | ✓ | `post_import_completions.py` |
| 5 — Metadata | ✓ | `post_import_metadata.py` |
| 6 — Catalogs | ✓ | `post_import_enterprise_catalogs.py` |
| 7 — Taxonomy | ✓ | `post_import_taxonomy.py` |
| 8 — Verification | ✓ | QA verification scripts |

### Runbook hardening TODO

1. `run_full_import.sh:58` hardcodes `exports/` paths under `$REPO_ROOT`. When run from a worktree without `exports/` (gitignored), Phase 0 should fail hard with "exports directory not found", not silently skip.
2. Phases 2-3 should fail cleanly if CSV files are absent.
3. **Fix**: Add `EXPORTS_ROOT` env var override. Phase 0 must check `$EXPORTS_ROOT` exists and is a directory before proceeding.

### Missing courses — DECISIONS

See `docs/status/active/IMPORT_MISSING_COURSES.md` for full evidence.

| Course | Decision | Status | Impact |
|--------|----------|--------|--------|
| PB-EN | **RESOLVED** — remapped to MCT32-EN | MCT32-EN imported, CSVs remapped | 2,958 completions + 855 enrollments fixed |
| UPAI1-EN | **DEFERRED** — video URLs not in pipeline input | Blocked on content team | 55,109 Kajabi enrollments affected |
| UPAI3-EN | **DEFERRED** — video URLs not in pipeline input | Blocked on content team | 10,911 Kajabi enrollments affected |
| UPAI4-EN/5-EN | **DEFERRED** — same gap as UPAI1/3 | Out of sprint | ~21K enrollments affected |
| PP-EN | **DEFERRED** — 2 Mux videos exist but OLX not built | Low priority (0 enrollments) | None |
| Skills Test (7×ST-*) | **DEFERRED** — zero content, zero enrollments | No staging impact | None |

### Block structure generation — CLASSIFICATION

**Owner: Platform/Runtime** (not import-owned)

- CMS `import` generates block structures for some courses (14/37 succeeded during import).
- Remaining fail: Celery workers hit `NoSuchServiceError: Service 'user' is not available`.
- XBlock runtime service initialization issue, not import data.
- Block structures generate lazily on first learner access IF platform issues are resolved.

### Runtime/platform blockers — NOT import-owned

| Blocker | Owner | Evidence |
|---------|-------|----------|
| Redis AOF I/O errors | infra-runtime | `MISCONF Errors writing to the AOF file` |
| JWT signing keys not configured | platform-config | `JWT_PRIVATE_SIGNING_JWK: False`, `InvalidAlgorithmError` |
| Enterprise consent backend OAuth | platform-config | Missing OAuth2 Application for enterprise backend service |
| Block structure generation in workers | platform-runtime | `NoSuchServiceError: Service 'user' is not available` |
| Credentials timezone/tzdata | infra-runtime | See `generate-runtime-blocker-infra-prompt.sh` |

Runtime blocker handoff bundle: `var/qa/frontend-runtime-blocker-handoff-bundle.tar.gz`

## Staging gate checklist

| Gate | Status |
|------|--------|
| Dedicated import branch exists | ✓ `feat/import-lane-closure` pushed |
| All claimed scripts exist in repo | ✓ 7 post-import + 1 master pipeline + 1 runbook |
| Import status doc matches reality | ✓ This document |
| Missing courses documented | ✓ PB-EN resolved, UPAI/ST deferred with evidence |
| `run_full_import.sh` dry-run passes | ✗ Needs `EXPORTS_ROOT` hardening |
| Runtime blockers handed off | ✓ Bundle at `var/qa/` |

**Staging verdict: NO-GO** until `EXPORTS_ROOT` hardening is done and dry-run passes cleanly.
UPAI1-EN/UPAI3-EN deferral is acceptable for staging if documented and accepted.
