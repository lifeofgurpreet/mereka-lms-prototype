# Microsoft Community Training → Open edX Migration

This directory contains scripts and outputs for migrating data from Microsoft Community Training (MCT) to Open edX.

## Structure

```
ops/migrations/mct/
├── README.md                    # This file
├── scripts/
│   ├── transform_data.py        # Transform MCT exports → Open edX format
│   ├── build_course_packages.py # Generate Open edX course tarballs
│   ├── prepare_openedx_imports.py # Create bulk import CSVs
│   └── import_courses.py        # Automated course import helper
└── output/                      # Generated transformation outputs
    ├── users.csv
    ├── courses.csv
    ├── enrollments.csv
    ├── course_structure.json
    └── course_packages/         # Open edX course tarballs
```

## Workflow

### 1. Export Data from MCT

Run the export script from the repo root:

```bash
MCT_BASE_URL=https://learn.skillourfuture.org \
MCT_API_VERSION=v4 \
MCT_ACCESS_TOKEN=<your-token> \
node tools/mct-export.mjs \
  --resources users,courses,enrollments \
  --output-dir exports/mct
```

This creates NDJSON files in `exports/mct/`:
- `users.ndjson`
- `courses.ndjson`
- `enrollments.ndjson`
- `structure/course_content.ndjson`

### 2. Transform Data

Convert MCT exports to Open edX format:

```bash
python ops/migrations/mct/scripts/transform_data.py \
  --exports-dir exports/mct \
  --output-dir ops/migrations/mct/output
```

### 3. Build Course Packages

Generate Open edX course tarballs:

```bash
python ops/migrations/mct/scripts/build_course_packages.py \
  --course-structure ops/migrations/mct/output/course_structure.json \
  --courses-csv ops/migrations/mct/output/courses.csv \
  --output-dir ops/migrations/mct/output/course_packages \
  --org SKILLOURFUTURE \
  --course-prefix MCT- \
  --run-prefix RUN- \
  --language en
```

### 4. Prepare Open edX Imports

Create bulk import CSVs:

```bash
python ops/migrations/mct/scripts/prepare_openedx_imports.py \
  --output-root ops/migrations/mct/output \
  --manifest ops/migrations/mct/output/course_packages/course_packages_manifest.csv
```

### 5. Import into Open edX

See `docs/MCT_MIGRATION_PLAN.md` for detailed import instructions.

## Status

🚧 **In Progress** - Scripts are being developed based on API exploration.

See `docs/MCT_MIGRATION_PLAN.md` for the full migration strategy and API exploration notes.

