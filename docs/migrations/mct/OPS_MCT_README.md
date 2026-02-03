# Microsoft Community Training → Open edX Migration

This directory contains scripts and outputs for migrating data from Microsoft Community Training (MCT) to Open edX.

## Structure

```
scripts/migrations/mct/
├── README.md                    # This file
└── scripts/
    ├── transform_data.py        # Transform MCT exports → Open edX format
    ├── build_course_packages.py # Generate Open edX course tarballs
    ├── prepare_openedx_imports.py # Create bulk import CSVs
    └── import_courses.py        # Automated course import helper

Note: Migration outputs are now stored in `var/migrations/mct/` (gitignored).
```

## Workflow

### 1. Export Data from MCT

Run the export script from the repo root:

```bash
MCT_BASE_URL=https://learn.skillourfuture.org \
MCT_API_VERSION=v4 \
MCT_ACCESS_TOKEN=<your-token> \
node scripts/migrations/mct/mct-export.mjs \
  --resources users,courses,enrollments \
  --output-dir var/exports/mct
```

This creates NDJSON files in `var/exports/mct/`:
- `users.ndjson`
- `courses.ndjson`
- `enrollments.ndjson`
- `structure/course_content.ndjson`

### 2. Transform Data

Convert MCT exports to Open edX format:

```bash
python scripts/migrations/mct/scripts/transform_data.py \
  --exports-dir var/exports/mct \
  --output-dir var/migrations/mct
```

### 3. Build Course Packages

Generate Open edX course tarballs:

```bash
python scripts/migrations/mct/scripts/build_course_packages.py \
  --course-structure var/migrations/mct/course_structure.json \
  --courses-csv var/migrations/mct/courses.csv \
  --output-dir var/migrations/mct/course_packages \
  --org SKILLOURFUTURE \
  --course-prefix MCT- \
  --run-prefix RUN- \
  --language en
```

### 4. Prepare Open edX Imports

Create bulk import CSVs:

```bash
python scripts/migrations/mct/scripts/prepare_openedx_imports.py \
  --output-root var/migrations/mct \
  --manifest var/migrations/mct/course_packages/course_packages_manifest.csv
```

### 5. Import into Open edX

See `docs/MCT_MIGRATION_PLAN.md` for detailed import instructions.

## Status

### User Import: ✅ COMPLETED (2025-12-18)
- **Imported:** 68,565 users (98.77% success rate)
- **Total Processed:** 69,419 users
- **Script:** `scripts/openedx_bulk_import_mct.py`
- **Documentation:** `/docs/migrations/mct/MCT_USER_IMPORT_COMPLETE.md`

### Next Steps
1. **Enrollment Import** - Ready to proceed
   - Source: `var/migrations/mct/transformed/enrollments_categories.csv`
   - Count: ~31.8 million enrollments
   - Use: `openedx_bulk_import_mct.py enrollments`

2. **Course Import** - Pending
   - Course packages need to be built
   - Import into Open edX Studio

## User Import Scripts

### Main Import Script
`scripts/openedx_bulk_import_mct.py` - Bulk import users and enrollments into Open edX

#### User Import
```bash
python3 openedx_bulk_import_mct.py users \
  --csv /path/to/users.csv \
  --offset 0 \
  --limit 5000 \
  --state-file /tmp/user_import.state
```

#### Enrollment Import
```bash
python3 openedx_bulk_import_mct.py enrollments \
  --csv /path/to/enrollments.csv \
  --offset 0 \
  --limit 5000 \
  --state-file /tmp/enrollment_import.state
```

### K8s Execution Scripts
- `scripts/run_user_import_k8s.sh` - Run full user import in K8s
- `scripts/test_user_import.sh` - Test import with 100 users

### CSV Format

#### users.csv
```csv
username,email,full_name,first_name,last_name,country,gender,dob,learning_pathways,mct_user_id
```

#### enrollments.csv
```csv
email,course_id,mode,is_active
```

See `/docs/migrations/mct/MCT_USER_IMPORT_COMPLETE.md` for the full migration strategy and detailed results.

