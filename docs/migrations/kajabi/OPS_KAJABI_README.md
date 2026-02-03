# Kajabi → Open edX Transformation Pipeline

This folder holds the tooling that turns the raw Kajabi exports (stored under `exports/kajabi/`) into staging files we can feed into Open edX.

## Inputs

Run the exporter from the repo root (already done once):

```
exports/kajabi/
├── contacts.ndjson
├── customers.ndjson
├── offers.ndjson
├── products.ndjson
├── purchases.ndjson
├── courses_index.ndjson
├── structure/
│   ├── modules.ndjson
│   ├── lessons.ndjson
│   └── lesson_media.ndjson
└── …
```

## Transform script

```
python scripts/migrations/kajabi/scripts/transform_data.py \
  --exports-dir exports/kajabi \
  --structure-dir exports/kajabi/structure \
  --output-dir scripts/migrations/kajabi/output
```

### Outputs

| File | Description |
|------|-------------|
| `users.csv` | Combined contacts/customers with key profile data (ready for Django import). |
| `enrollments.csv` | Offer/purchase mappings -> course enrollments (customer + contact IDs, status, timestamps). |
| `courses.csv` | Catalog metadata (title/description/status per course). |
| `course_structure.json` | Nested structure per course (modules → lessons, plus media references when available). |
| `course_summary.csv` | Module/lesson counts per course for quick QA. |

The script streams NDJSON files line-by-line, so it can be re-run safely as new exports arrive.

## Course package builder

Convert the nested Kajabi structure into importable Open edX tarballs:

```
python scripts/migrations/kajabi/scripts/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA \
  --course-prefix MEKA- \
  --run-prefix RUN- \
  --language en
```

Results:

- `scripts/migrations/kajabi/output/course_packages/<slug>/<slug>.tar.gz` – ready for Studio import.
- `scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv` – maps every Kajabi course ID to the generated course key (`course-v1:ORG+NUMBER+RUN`) plus module/lesson counts.

Each tarball contains placeholder HTML units populated with the Kajabi lesson metadata (IDs, media references, status). Re-run the script any time the JSON inputs change; it will replace previous archives.

## Open edX-ready CSVs

Create CSVs that match Open edX’s built-in bulk import commands:

```
python scripts/migrations/kajabi/scripts/prepare_openedx_imports.py \
  --output-root scripts/migrations/kajabi/output \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv
```

Outputs land in `scripts/migrations/kajabi/output/openedx/`:

| File | Used by | Notes |
|------|---------|-------|
| `users_import.csv` | `manage.py lms importusers` | Password column intentionally empty so Open edX generates reset links. `is_active` mirrors Kajabi’s subscription flag. |
| `enrollments_import.csv` | `manage.py lms bulk_enroll` | Each row contains `email`, `username`, `course-v1` key, mode (`audit`), and active flag. Rows without a matching course/user are skipped and reported in stdout. |

## Importing into Tutor Open edX

Make sure the Tutor stack is running (`tutor local start -d`). From the repo root:

```
source ops/tutor-env.sh

# 1) Users
tutor local run lms bash -c "cat > /tmp/kajabi-users.csv" \
  < scripts/migrations/kajabi/output/openedx/users_import.csv
tutor local run lms ./manage.py lms importusers \
  /tmp/kajabi-users.csv --settings=tutor.production --send-email False

# 2) Enrollments
tutor local run lms bash -c "cat > /tmp/kajabi-enrollments.csv" \
  < scripts/migrations/kajabi/output/openedx/enrollments_import.csv
tutor local run lms ./manage.py lms bulk_enroll --csv /tmp/kajabi-enrollments.csv \
  --settings=tutor.production --email-students False --auto-enroll True

# 3) Courses – easiest via Studio UI
# Sign in to http://studio.localhost, choose "Import Course",
# and upload the desired tarball from scripts/migrations/kajabi/output/course_packages/<slug>/<slug>.tar.gz
```

You can repeat the import commands as new exports arrive. The `bulk_enroll` step is idempotent—the command re-validates each enrollment and only creates the missing ones.

For automated CLI imports, copy a tarball into the CMS container, extract it, then point `manage.py cms import` at the unpacked directory:

```
TARBALL=scripts/migrations/kajabi/output/course_packages/ai-fluency-for-corporates/ai-fluency-for-corporates.tar.gz
tutor local run cms bash -c "rm -rf /tmp/kajabi-course && mkdir -p /tmp/kajabi-course && tar -xzf - -C /tmp/kajabi-course" < "$TARBALL"
tutor local run cms ./manage.py cms import /tmp/kajabi-course --settings=tutor.production
```

This command will create or update the course that is defined inside the tarball (`course-v1:MEREKA+MEKA-2148896997+RUN-2148896997` in the example above). Use the manifest file to locate the generated course keys.

### Batch-import helper

Instead of clicking through Studio 100+ times, use the automation script:

```
source ops/tutor-env.sh
python scripts/migrations/kajabi/scripts/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --limit 5   # drop this flag to import everything
```

Options:

- `--only 2149223856 2149223867` imports a specific subset.
- `--dry-run` prints the plan without calling Tutor.
- `--keep-temp` leaves the extracted `/tmp/kajabi-import/<slug>` folders inside the CMS container for debugging.

By default the script streams each tarball into `tutor local run cms` for extraction, runs `manage.py cms import` against that directory, and then removes the temp folder. Keep Tutor’s services running during the import marathon.
