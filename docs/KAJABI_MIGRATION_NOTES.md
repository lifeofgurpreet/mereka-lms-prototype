# Kajabi → Open edX Data Migration Notes

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
`tools/kajabi-export.mjs` implements the API crawl (Node 20+, NDJSON output):
```bash
# minimal (all default resources):
KAJABI_CLIENT_ID=... \
KAJABI_CLIENT_SECRET=... \
node tools/kajabi-export.mjs

# chunk a large resource (contacts pages 1-50 only):
node tools/kajabi-export.mjs \
  --resources contacts \
  --site 2147565329 \
  --start-page 1 \
  --end-page 50 \
  --page-size 100

# courses index + details (10 pages) without lesson expansion:
node tools/kajabi-export.mjs \
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
`tools/kajabi-course-structure.mjs` reads `courses_index.ndjson` and for each course:
- Calls `?include=modules` and `?include=lessons` (two separate requests to avoid 500 errors) and writes the results to `exports/kajabi/structure/{modules,lessons}.ndjson`.
- Attempts `?include=lessons.media`; when Kajabi throws 500s the script logs to `structure/errors.ndjson` but still records any media returned.

Convert those NDJSON files into analyst-friendly CSVs with:
```bash
python tools/kajabi-ndjson-to-csv.py \
  --ndjson-dir exports/kajabi/structure \
  --csv-dir exports/kajabi/csv/structure
```

## Next Steps
- [ ] Run exporter in staging to gather sample datasets.
- [ ] Define transformation scripts for Open edX ingestion (users, courses, enrollments).
- [ ] Stand up webhook receiver endpoint (FastAPI/Express) to process delta events.
- [ ] Plan manual video/progress exports and storage.
- [ ] Document mapping tables (Kajabi offer/product IDs → Open edX course IDs).
