# Import Lane Status — 2026-04-01

> **Last updated**: 2026-04-02T05:00Z
> **Lane owner**: LMS-I (import)

## Claim scope

Branch-backed repo progress plus verified phase-0 dry-run with explicit
`EXPORTS_ROOT`. This document does NOT claim operational closure or runtime
validation. Production namespace does not exist. Staging has a MEKA-* course
ID divergence from an older import run.

## Export artifacts (data on disk)

| What | Count | Verification |
|------|-------|-------------|
| MCT courses (OLX input) | 30 categories | `verify-course-import-counts.sh --source mct` PASS |
| MCT users (export file) | 69,419 | `verify-user-import-counts.sh --source mct` PASS |
| Kajabi users (export file) | 73,107 | `verify-user-import-counts.sh --source kajabi` PASS |
| MCT enrollments (unique pairs) | 441,578 | `verify-enrollment-import-counts.sh --source mct` PASS |
| Kajabi enrollments (unique pairs) | 85,355 | Was 147,971. Reduced by 21,696 UPAI4/5 orphan rows (no course identity, no Kajabi product mapping) and separation of UPAI1/3 into course shells. |
| Mux video assets | 503 MCT + 72 Drive = 575 | `verify-mux-upload-completeness.sh` PASS |
| Kajabi completions (export) | 11,179 | `verify-kajabi-completions-export.sh` PASS |
| OLX packages (MCT) | 28 tarballs with valid archives | `personal-branding-en/` directory exists but has no tarball — see note below. |
| OLX packages (FOW/UPAI) | 11 tarballs | 9 original + 2 UPAI1-EN/UPAI3-EN course shells (placeholder content, no videos). |

### `personal-branding-en` tarball warning

Phase-0 warns: `No tarball for MCT package: personal-branding-en`. This is
expected. The directory was created during OLX build but its content duplicates
`personal-branding/` (MCT32-EN). The PB-EN to MCT32-EN remap means
`personal-branding-en` is never imported. The canonical package is
`personal-branding/` which has its tarball. The warning is cosmetic.

## Dev database state (`mereka-lms-dev` on rke2-nonprod)

These counts were queried on 2026-04-02. They may change as enrollment
imports continue in the background. Background enrollment imports have been
interrupted multiple times by pod restarts and are not yet complete.

| What | Count | Notes |
|------|-------|-------|
| Courses (modulestore) | 39 | All `org=MEREKA`, `run=course`. |
| Users | 99,929 | MCT + Kajabi + pre-existing |
| Enrollments | 176,359 | Includes partial UPAI1/3 (~65K of 66K target) |
| Certificates | 7,755 | Kajabi completions including PB to MCT32-EN remap |
| Enterprise customers | 3 | Mereka Academy, Skill Our Future, Biji-Biji Academy |
| Enterprise catalogs | 3 | Mereka (all), SOF (MCT+FOW), BijiBiji (UPAI prefix match) |
| Taxonomy tags | 117 | 39 courses x 3 taxonomies |
| Duplicate emails | 0 | Verified 2026-04-02 |
| Duplicate enrollments | 0 | Verified 2026-04-02 |

## Pipeline status (`run_full_import.sh`)

All 9 phases wired. Phase-0 pre-flight passes with `EXPORTS_ROOT` set:

```
EXPORTS_ROOT=/path/to/exports ./scripts/migrations/run_full_import.sh \
  --env dev --phase phase-0-verify --dry-run --yes
```

Result: 0 errors, 1 cosmetic warning (personal-branding-en, explained above).

EXPORTS_ROOT hardening: phase-0 fails hard if directory missing, CSV files
checked in required-files loop.

## Missing courses

See `docs/status/active/IMPORT_MISSING_COURSES.md` for full evidence.

| Course | Decision |
|--------|----------|
| PB-EN | Remapped to MCT32-EN |
| UPAI1-EN | Imported as shell (no videos), enrollments in progress |
| UPAI3-EN | Imported as shell (no videos), enrollments in progress |
| UPAI4-EN/5-EN | Dropped — orphan enrollments, no course identity |
| PP-EN | Deferred — 0 enrollments |
| Skills Test (7x) | Deferred — zero content |

## Staging parity

Staging (`stg-mereka-lms`) has ~147K enrollments under `MEKA-*` auto-generated
course IDs from an old import. Canonical courses exist but show 0 enrollments
because enrollment records are keyed to the wrong course IDs.

Courses, taxonomy, and certificates are at parity with dev. Enrollments are not.

Recommendation: wipe staging enrollments and re-import with the canonical
pipeline for clean parity.

## Production readiness

| Gate | Passed |
|------|--------|
| Pipeline dry-run passes with EXPORTS_ROOT | Yes |
| Prod context points to RKE2 (not GKE) | Yes |
| Context-switching side-effect fixed | Yes |
| personal-branding-en warning documented | Yes |
| Kajabi enrollment count reconciled (85,355) | Yes |
| `mereka-lms-prod` namespace exists | No — infra dependency |
| LMS/CMS pods running in prod | No — blocked on namespace |

## Runtime blockers (not import-owned)

| Blocker | Owner |
|---------|-------|
| Redis AOF I/O errors | infra-runtime |
| JWT signing keys not configured | platform-config |
| Enterprise consent backend OAuth | platform-config |
| Block structure generation in workers | platform-runtime |
| Credentials timezone/tzdata | infra-runtime |

## Ruff lint debt

20 pre-existing Ruff errors in `scripts/migrations/` (15 auto-fixable).
Not introduced by import work. Shared repo debt — route as separate chore PR.
