# Kajabi → Open edX Migration Guide
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-11-09_

This is the canonical playbook for taking Kajabi exports, transforming them, and feeding them into our Tutor environments. The satellite docs under `docs/` dive deeper into specific sub-topics (handovers, verification, bug trackers), but everything starts here.

_Last verified: 2025‑11‑09_

## 1. Raw Exports

1. Pull fresh NDJSON dumps from Kajabi (`contacts.ndjson`, `customers.ndjson`, `offers.ndjson`, `products.ndjson`, `courses_index.ndjson`, and `structure/*.ndjson`).
2. Drop them under `exports/kajabi/` (git-ignored) on your workstation.
3. Update `docs/status/migrations/KAJABI_MIGRATION_STATUS.md` with the export date.

## 2. Transform Stage

```bash
python scripts/migrations/kajabi/transform_data.py \
  --exports-dir exports/kajabi \
  --structure-dir exports/kajabi/structure \
  --output-dir scripts/migrations/kajabi/output
```

Outputs:
- `users.csv`, `enrollments.csv`, `courses.csv`
- `course_structure.json`, `course_summary.csv`

Reference: [`KAJABI_MIGRATION_NOTES.md`](../../../../reference/migrations/kajabi/KAJABI_MIGRATION_NOTES.md) for column-level quirks.

## 3. Build Open edX Tarballs

```bash
python scripts/migrations/kajabi/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA --course-prefix MEKA- --run-prefix RUN- --language en
```

Result: `scripts/migrations/kajabi/output/course_packages/<slug>/<slug>.tar.gz` plus a manifest with generated course keys. See [`KAJABI_MIGRATION_VERIFICATION.md`](KAJABI_MIGRATION_VERIFICATION.md) for QA steps.

## 4. Produce Open edX-Friendly CSVs

```bash
python scripts/migrations/kajabi/prepare_openedx_imports.py \
  --output-root scripts/migrations/kajabi/output \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv
```

This creates `scripts/migrations/kajabi/output/openedx/users_import.csv` and `enrollments_import.csv`.

## 5. Import into Tutor (Local or K8s)

### Local Tutor (recommended for dry runs)

```bash
source infrastructure/tutor/tutor-env.sh
tutor local start -d

# Users
tutor local run --volume="$(pwd)/scripts/migrations/kajabi/openedx_bulk_import.py:/tmp/openedx_bulk_import.py:ro" \
  --volume="$(pwd)/scripts/migrations/kajabi/output/openedx/users_import.csv:/tmp/kajabi-users.csv:ro" \
  lms python /tmp/openedx_bulk_import.py users --csv /tmp/kajabi-users.csv --settings=lms.envs.tutor.production

# Enrollments (same script, different sub-command)
tutor local run --volume="$(pwd)/scripts/migrations/kajabi/openedx_bulk_import.py:/tmp/openedx_bulk_import.py:ro" \
  --volume="$(pwd)/scripts/migrations/kajabi/output/openedx/enrollments_import.csv:/tmp/kajabi-enrollments.csv:ro" \
  lms python /tmp/openedx_bulk_import.py enrollments --csv /tmp/kajabi-enrollments.csv --settings=lms.envs.tutor.production
```

Course content imports can be automated via `scripts/migrations/kajabi/import_courses.py` or done manually through Studio (`http://studio.localhost` → Import Course). Details live in [`KAJABI_MIGRATION_HANDOVER.md`](../../../../../reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md).

### Tutor K8s (production)

Use `scripts/migrations/kajabi/run_batches.py` to stream CSVs into the LMS pod with retryable batches:

```bash
python scripts/migrations/kajabi/run_batches.py users \
  --csv scripts/migrations/kajabi/output/openedx/users_import.csv \
  --batch-size 2000
```

The script uploads `openedx_bulk_import.py`, runs it inside the LMS pod, and tracks offsets in `/tmp/<target>.offset`. Review logs under `scripts/migrations/kajabi/logs/`.

## 6. Verification & Sign-off

1. Follow [`KAJABI_MIGRATION_VERIFICATION.md`](KAJABI_MIGRATION_VERIFICATION.md) to spot-check users, enrollments, and course content.
2. Record progress in `docs/status/migrations/KAJABI_MIGRATION_STATUS.md`.
3. Update `reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md` once Ops validates prod and QA signs off.

> Need to debug a broken lesson or mismatched structure? See `docs/ops/runbooks/migrations/kajabi/KAJABI_LESSON_CONTENT_FIX.md` and `docs/reference/migrations/kajabi/KAJABI_LESSON_CONTENT_ISSUE.md` for known patterns and scripts.
