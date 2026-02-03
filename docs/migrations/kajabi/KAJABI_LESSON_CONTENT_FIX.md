# Kajabi Lesson Content Migration Fix
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-08-18_

## Overview
Fixed the pipeline to capture actual lesson content (body, HTML, media URLs) instead of just metadata.

## Changes Made

1. **Extended `tools/kajabi-course-structure.mjs`**
   - Now fetches full lesson details via `GET /v1/lessons/{id}?include=media,downloads`
   - Writes to `exports/kajabi/structure/lesson_details.ndjson`

2. **Updated `scripts/migrations/kajabi/scripts/transform_data.py`**
   - Loads and merges lesson details into course structure
   - Preserves `content_html`, `body`, `video_url`, `download_url` fields

3. **Enhanced `scripts/migrations/kajabi/scripts/build_course_packages.py`**
   - Uses real lesson content instead of placeholders
   - Falls back gracefully if content unavailable

## Testing Steps

### Step 1: Test Lesson Detail API (Optional but Recommended)

Test what fields Kajabi returns for a single lesson:

```bash
export KAJABI_CLIENT_ID="your_client_id"
export KAJABI_CLIENT_SECRET="your_client_secret"
node tools/kajabi-test-lesson-detail.mjs --lesson-id 2192178188
```

This will show you what fields are available (body, content_html, video_url, etc.).

### Step 2: Re-export Course Structure with Lesson Details

```bash
node tools/kajabi-course-structure.mjs \
  --input exports/kajabi/courses_index.ndjson \
  --out exports/kajabi/structure \
  --delay 400
```

This will:
- Fetch modules and lessons (as before)
- **NEW**: Fetch detailed content for each lesson
- Write to `lesson_details.ndjson`

**Note**: This may take longer since it makes one API call per lesson. The `--delay` flag controls rate limiting.

### Step 3: Re-transform Data

```bash
python scripts/migrations/kajabi/scripts/transform_data.py \
  --exports-dir exports/kajabi \
  --structure-dir exports/kajabi/structure \
  --output-dir scripts/migrations/kajabi/output
```

This merges lesson details into `course_structure.json`.

### Step 4: Rebuild Course Packages

```bash
python scripts/migrations/kajabi/scripts/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA \
  --course-prefix MEKA- \
  --run-prefix R \
  --keep-build
```

The `--keep-build` flag keeps the expanded folders so you can inspect the HTML content.

### Step 5: Verify Content

Check a lesson HTML file in the build directory:

```bash
cat scripts/migrations/kajabi/output/course_packages/<course-slug>/build/html/*.xml | grep -A 20 "<html"
```

You should see actual lesson content instead of placeholders.

## Troubleshooting

- **If lesson details are empty**: Kajabi API may not expose `content_html`/`body` for your plan. Check the test script output.
- **If API rate limits**: Increase `--delay` (e.g., `--delay 1000` for 1 second between requests).
- **If some lessons fail**: Check `exports/kajabi/structure/errors.ndjson` for failed lesson fetches.

## Fallback Behavior

If lesson content isn't available from the API:
- Placeholder HTML is still generated with metadata
- Media/download links are preserved if available
- You can manually copy content later using the Kajabi lesson IDs

