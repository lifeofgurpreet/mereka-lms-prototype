# Kajabi → Open edX Data Migration Notes
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-09-30_

> **Legacy note:** This doc predates the production/dev naming. References to the old environment label should be read as production (GKE); dev runs on kind.

## Credentials & Endpoints
- Base API URL: `https://academy.mereka.my/api` (tenant-specific).
- OAuth2 client credentials flow against `https://api.kajabi.com/v1/oauth/token`.
 Environment variables needed for scripts:
  - `KAJABI_CLIENT_ID` / `KAJABI_API_KEY`
  - `KAJABI_CLIENT_SECRET`
  - `KAJABI_SITE_ID` (optional filter, recommended)
  - `KAJABI_WEBHOOK_SECRET` (for verifying webhook payloads)
  - `WEBHOOK_TARGET_URL` when subscribing to live events

## Public API Coverage (v1)
The official Public API delivers JSON API responses with pagination metadata. Key resources we can fully export:

| Resource        | Purpose                                                                | Notes/Relationships                                                |
|-----------------|------------------------------------------------------------------------|--------------------------------------------------------------------|
| `contacts`      | People records (name, email, custom_1..3, tags)                        | Combine with `contact_tags`, `custom_fields` for segmentation      |
| `customers`     | Login-capable members                                                  | Includes last sign-in, relationships to offers/products            |
| `offers`        | Entitlements / catalog SKUs                                            | Provide price, currency, checkout URL                              |
| `products`      | Product catalog                                                        | Map to courses, communities, etc.                                  |
| `courses`       | Courses and modules/lessons                                            | Use `?include=modules,lessons,lessons.media,offers` for structure  |
| `purchases`     | Offer purchases, ties customer ↔ offer/product                         | Good anchor for enrollments                                        |
| `transactions`  | Payment records (success, refund, dispute)                             | Revenue history                                                    |
| `orders`, `order_items` | Itemized order detail                                          | Optional deep-dive into commerce                                   |
| `forms`, `form_submissions` | Opt-in forms and payloads                                  | Useful for CRM sync                                                |
| `contact_tags`  | Tag catalog                                                            | Tag membership determined via `contacts[].relationships.tags`      |
| Webhooks        | Events: `purchase`, `payment_succeeded`, `order_created`, `form_submission`, `tag_added`, `tag_removed` | Real-time mirroring during cut-over                                |

### Missing / Manual Exports
- Lesson video binaries (download manually from UI).
- Progress / assessments CSV exports (Analytics section).
- Email automations / sequences content not surfaced via Public API.

## Migration Strategy
1. **Backfill via API**
   - Use client credential token to paginate through contacts, customers, products, courses, commerce entities, forms.
   - Store raw JSON dumps under `exports/kajabi/` for auditing.
   - Expand course structure with `include=modules,lessons,lessons.media,offers`.

2. **Transform for Open edX**
   - Map customers → Open edX users.
   - Map products/offers/courses to edx course ids and enrollments.
   - Translate purchases/transactions into enrollment + payment reports.
   - Stage data in a database or JSON for import management commands.

3. **Live Sync / Cut-over**
   - Subscribe to webhooks for purchase/tag changes.
   - For each event, refetch the entity (idempotent upsert).

4. **Manual Follow-Up**
   - Download course video assets.
   - Export progress/assessment data for archival or manual import.

## Export Script
`scripts/migrations/kajabi/kajabi-export.mjs` implements the API crawl (Node 20+, NDJSON output):
```bash
# minimal (all default resources):
KAJABI_CLIENT_ID=... \
KAJABI_CLIENT_SECRET=... \
node scripts/migrations/kajabi/kajabi-export.mjs

# chunk a large resource (contacts pages 1-50 only):
node scripts/migrations/kajabi/kajabi-export.mjs \
  --resources contacts \
  --site 2147565329 \
  --start-page 1 \
  --end-page 50 \
  --page-size 100

# courses index + details (10 pages) without lesson expansion:
node scripts/migrations/kajabi/kajabi-export.mjs \
  --resources courses \
  --site 2147565329 \
  --page-size 50 \
  --start-page 1 \
  --end-page 10 \
  --skip-course-details
```

Key features:
- Authenticates via OAuth2 client credentials once per run.
- Streams each resource to `exports/kajabi/<resource>.ndjson` (newline-delimited JSON) so huge collections don’t exhaust memory.
- Supports chunking via `--start-page` / `--end-page` and resource filtering (`--resources contacts,customers`).
- Course exports attempt `include=modules,lessons,lessons.media,offers` and fall back to basic course payload if Kajabi returns 500s.
- Webhook provisioning available with `--ensure-webhooks --webhook-target https://...` (or `WEBHOOK_TARGET_URL` env).

Sample output sizes (latest pull):

| File | Records |
|------|---------|
| `contacts.ndjson` | 85,206 |
| `customers.ndjson` | 85,202 |
| `offers.ndjson` | 375 |
| `products.ndjson` | 110 |
| `purchases.ndjson` | 104,470 |
| `transactions.ndjson` | 3 |
| `contact_tags.ndjson` | 100 |
| `forms.ndjson` | 17 |
| `form_submissions.ndjson` | 2 |
| `courses_index.ndjson` | 107 (entire catalog) |
| `courses_full.ndjson` | 107 (course metadata + any modules/lessons returned by `include=...` requests) |
| `structure/modules.ndjson` | 401 |
| `structure/lessons.ndjson` | 1,527 |
| `structure/lesson_media.ndjson` | 32 (only courses where `lessons.media` succeeded) |

> For very large tables (contacts, purchases) run the exporter in batches, e.g. `--start-page 1 --end-page 100`, then resume with `--start-page 101`.

### Course structure helper
`scripts/migrations/kajabi/kajabi-course-structure.mjs` reads `courses_index.ndjson` and for each course:
- Calls `?include=modules` and `?include=lessons` (two separate requests to avoid 500 errors) and writes the results to `exports/kajabi/structure/{modules,lessons}.ndjson`.
- Attempts `?include=lessons.media`; when Kajabi throws 500s the script logs to `structure/errors.ndjson` but still records any media returned.

Convert those NDJSON files into analyst-friendly CSVs with:
```bash
python scripts/migrations/kajabi/kajabi-ndjson-to-csv.py \
  --ndjson-dir exports/kajabi/structure \
  --csv-dir exports/kajabi/csv/structure
```

## Open edX Import Workflow (Tutor local or Tutor k8s)

Once the CSVs/tarballs under `scripts/migrations/kajabi/output/` are refreshed, run the following pipeline to land the data in Open edX. Everything below works against both `tutor local` (Docker on your laptop) and `tutor k8s` (GKE production). Substitute the namespace/service names if your deployment differs from `mereka-lms`/`cms`/`lms`.

### 1. Prerequisites & Health Checks

1. `source infrastructure/tutor/tutor-env.sh` to seed the virtualenv and Tutor CLI on the host machine that will orchestrate the imports.
2. For GKE, authenticate `gcloud` (`gcloud auth login`, `gcloud config set project mereka-lms`, `gcloud container clusters get-credentials mereka-lms --region asia-southeast1`).
3. Confirm the namespace/pods you will target:

   ```bash
   kubectl get pods -n mereka-lms
   # optional override for Tutor commands
   export TUTOR_K8S_NAMESPACE=mereka-lms
   ```

4. Snapshot current counts so you have a before/after signal:

   ```bash
   kubectl exec -n mereka-lms deploy/lms -- \
     /bin/bash -c "cd /openedx/edx-platform && \\
       ./manage.py lms shell -c 'from django.contrib.auth import get_user_model; \\
       from common.djangoapps.student.models import CourseEnrollment; \\
       print(get_user_model().objects.count()); \\
       print(CourseEnrollment.objects.count())' --settings=tutor.production"
   ```

### 2. Users & Enrollments (batch-safe)

- Script: `scripts/migrations/kajabi/scripts/openedx_bulk_import.py` (runs *inside* the LMS container).
- Driver: `scripts/migrations/kajabi/scripts/run_batches.py` (runs on the host, handles chunking/resume/retries/logs).

Steps:

1. Copy the helper + CSVs into the LMS pod once. The driver does this automatically unless you pass `--skip-upload` (handy when resuming):

   ```bash
   python3 scripts/migrations/kajabi/scripts/run_batches.py users \
     --csv scripts/migrations/kajabi/output/openedx/users_import.csv \
     --batch-size 2000 \
     --remote-csv /tmp/kajabi-users.csv \
     --namespace mereka-lms
   ```

   - Creates `/tmp/openedx_bulk_import.py` + `/tmp/kajabi-users.csv` inside the pod.
   - Maintains `/tmp/users.offset` so you can rerun the command and it resumes automatically.
   - Logs each batch to `scripts/migrations/kajabi/logs/users_offset_<n>.log` for post-mortem analysis.

2. Repeat for enrollments (same script, different target file):

   ```bash
   python3 scripts/migrations/kajabi/scripts/run_batches.py enrollments \
     --csv scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
     --batch-size 2000 \
     --remote-csv /tmp/kajabi-enrollments.csv \
     --namespace mereka-lms
   ```

3. The driver retries transient `kubectl exec` failures (defaults: 3 attempts, 10 s backoff; tweak via `--retries`/`--retry-delay`). After completion you should see `All batches completed` and the offsets at `/tmp/{users,enrollments}.offset` will match your CSV row counts.

4. Re-run the count shell from step 1 to confirm the expected deltas (for the latest run we landed 84 379 `auth_user` rows and 137 464 `CourseEnrollment` rows).

### 3. Course Imports (OLX tarballs)

- Script: `scripts/migrations/kajabi/scripts/import_courses.py`
- Usage now supports Kubernetes through `--backend k8s --k8s-namespace mereka-lms` and automatically rewrites each extracted `course.xml` `url_name`/`run` to match `course_packages_manifest.csv` so the resulting IDs align with the enrollment CSV.

Example (single dry run):

```bash
python3 scripts/migrations/kajabi/scripts/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s \
  --k8s-namespace mereka-lms \
  --limit 1  # drop limit to import the full catalog
```

Key behaviour:

- Streams each tarball via `stdin` to `tutor k8s exec cms -- bash -c …` (or `tutor local run cms` locally) so nothing touches disk on the orchestrator.
- Extracts into `/tmp/kajabi-import/<slug>` inside the CMS container, rewrites `course.xml`, then runs `./manage.py cms import /tmp/kajabi-import <slug>`.
- Leaves `/tmp/kajabi-import` clean unless you pass `--keep-temp` for debugging.
- Logs stack traces straight into your terminal; capture stdout to `scripts/migrations/kajabi/logs/course_import.log` for full history (latest run imported 107/107 courses and bumped Mongo `active_versions` to 109).

### 4. Post-import Validation

1. Spot-check a few course keys:

   ```bash
   kubectl exec -n mereka-lms deploy/cms -- \
     /bin/bash -c "cd /openedx/edx-platform && \\
       ./manage.py cms shell -c 'from xmodule.modulestore.django import modulestore; \\
       from opaque_keys.edx.keys import CourseKey; \\
       print(bool(modulestore().get_course(CourseKey.from_string(\\"course-v1:MEREKA+MEKA-2149223856+RUN-2149223856\\"))))' \
       --settings=tutor.production"
   ```

2. Confirm Mongo shows the expected number of `active_versions`:

   ```bash
   kubectl exec -n mereka-lms mongodb-0 -- \
     mongo openedx --quiet --eval 'printjson(db.modulestore.active_versions.count())'
   ```

3. Browse `https://studio.academyv2.mereka.io/` and verify the imported courses appear in the Studio dashboard; the earlier import run triggered course overview + discussion map updates automatically.

4. Archive the latest logs (`scripts/migrations/kajabi/logs/*.log`) alongside the manifest for traceability before starting another batch.

### 5. Real-time deltas via Kajabi webhooks

Full refreshes keep production accurate, but we still need a way to capture purchases/tag changes that happen between export runs. The lightweight FastAPI receiver in `scripts/migrations/kajabi/webhook_app/` does the following:

1. Verifies the `X-Kajabi-Signature` header using `KAJABI_WEBHOOK_SECRET` (same value you provision in the Kajabi UI when adding the webhook).
2. Writes each accepted event to `scripts/migrations/kajabi/webhook_app/outbox/<event>.ndjson` so downstream workers can pick them up (ship to Pub/Sub, append to BigQuery, etc.).
3. Responds with HTTP 202 to keep Kajabi happy; if the signature fails it returns HTTP 401 (Kajabi will retry a few times).

Usage:

```bash
cd scripts/migrations/kajabi/webhook_app
python -m pip install -r requirements.txt
KAJABI_WEBHOOK_SECRET=supersecret \
KAJABI_WEBHOOK_OUTBOX=/var/tmp/kajabi-webhooks \
uvicorn main:APP --host 0.0.0.0 --port 8080
```

- For Cloud Run / GKE, bake the folder into a PVC or write to stdout and ship logs instead.
- Point Kajabi at `https://<your-host>/webhooks/kajabi` and re-run the exporter with `--ensure-webhooks --webhook-target https://<your-host>/webhooks/kajabi` to auto-provision each event type.
- The outbox format is newline-delimited JSON so you can tail it with `jq -c` or feed it into a dbt/ELT job.

### 6. (Optional) Scrape lesson bodies when the API falls short

Kajabi’s public API currently exposes lesson titles/status/media metadata but not the lesson body itself. When you need the actual HTML (e.g., to avoid placeholder content in Open edX), use the Playwright helper in `scripts/migrations/kajabi/scripts/scrape_lessons.py`:

```bash
pip install -r scripts/migrations/kajabi/scripts/requirements.txt
playwright install chromium  # one-time browser download

KAJABI_EMAIL=admin@example.com \
KAJABI_PASSWORD=supersecret \
python scripts/migrations/kajabi/scripts/scrape_lessons.py \
  --structure scripts/migrations/kajabi/output/course_structure.json \
  --output exports/kajabi/lesson_html \
  --ndjson-output exports/kajabi/structure/lesson_details.ndjson \
  --site-id 2147565329 \
  --lesson-url-template "https://academy.mereka.my/admin/sites/{site_id}/products/{course_id}/posts/{lesson_id}"
```

- The script signs into the Kajabi admin UI, visits each lesson URL, and writes both a per-lesson JSON snapshot and an aggregated `lesson_details.ndjson`. Any failures end up in `scrape_failures.json` for manual retries.
- Set `--limit` during testing to scrape just a few lessons. Adjust the URL template if your admin path differs.
- After scraping, rerun the transformer so it ingests the lesson details and propagates them into the course structure:

  ```bash
  python scripts/migrations/kajabi/scripts/transform_data.py \
    --exports-dir exports/kajabi \
    --structure-dir exports/kajabi/structure \
    --lesson-details-file exports/kajabi/structure/lesson_details.ndjson \
    --output-dir scripts/migrations/kajabi/output
  ```

  Then rebuild packages/import again—lessons with scraped HTML will display the real content, while any missing ones keep the metadata placeholder for manual follow-up.

## Next Steps
- [ ] Run the exporter + importer regularly on production to keep Kajabi and Open edX in sync until cut-over.
- [ ] Stand up the webhook receiver endpoint (FastAPI/Express) to capture deltas between full refreshes.
- [ ] Plan manual video/progress exports and storage locations.
- [ ] Document mapping tables (Kajabi offer/product IDs → Open edX course IDs) for downstream analytics.
