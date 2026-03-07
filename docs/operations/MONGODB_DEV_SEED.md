# MongoDB Dev Seed Runbook

Populate a **development** Atlas cluster with minimal fixture data so new contributors
can work against a realistic Open edX database without accessing production.

> **WARNING**: Never run this against the production Atlas cluster
> (`cluster-mereka-lms.2pjex4s.mongodb.net`). The script blocks the production
> connection string, but you are responsible for exporting the correct
> `MONGODB_CONNECTION_STRING`.

---

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| `mongosh` (preferred) | 2.x | [MongoDB Shell](https://www.mongodb.com/try/download/shell) |
| `mongoimport` (alternative) | 100.x | [MongoDB Database Tools](https://www.mongodb.com/try/download/database-tools) |
| `python3` | 3.10+ | System package |

Either `mongosh` **or** `mongoimport` must be on `PATH`. If both are present,
`mongoimport` is used for inserts (faster) and `mongosh` is used for connection
validation and the `--obliterate` drop step.

---

## Environment Variable

```bash
export MONGODB_CONNECTION_STRING="mongodb+srv://devuser:s3cr3t@cluster-dev.example.mongodb.net"
```

The script will **refuse to run** if this variable is unset or if it detects the
production cluster hostname.

---

## Usage

### 1. Dry-run first (always)

Prints exactly what would be seeded without writing anything:

```bash
export MONGODB_CONNECTION_STRING="mongodb+srv://..."
./scripts/infra/seed-mongo-dev.sh --dry-run
```

Example output:

```
==> Validating connection to Atlas...
WARN: [dry-run] Would run: mongosh "<connection-string>" --eval 'db.adminCommand({ping:1})'

==> Seeding openedx database...
INFO: [dry-run] Would import 1 doc(s) matching _type='org' -> openedx.modulestore.active_versions
INFO: [dry-run] Would import 5 doc(s) matching _type='definition' -> openedx.modulestore.definitions
INFO: [dry-run] Would import 1 doc(s) matching _type='user.profile' -> openedx.user.profiles

==> Seeding cs_comments_service database (forum)...
INFO: [dry-run] Would import 2 document(s) from forum-seed.json -> cs_comments_service.contents

==> Seed summary

  Collection                                    Documents
  ----------------------------------------- ---------
  openedx.modulestore.active_versions           1 (dry-run)
  openedx.modulestore.definitions               5 (dry-run)
  openedx.user.profiles                         1 (dry-run)
  cs_comments_service.contents                  2 (dry-run)

WARN: Dry-run complete — no data was written.
```

### 2. Seed (safe — upserts only)

```bash
./scripts/infra/seed-mongo-dev.sh
```

Documents are inserted with `--mode upsert` (by `_id`), so running the script
twice is idempotent.

### 3. Obliterate and re-seed (drops collections first)

Useful when fixture format has changed and you want a clean slate:

```bash
./scripts/infra/seed-mongo-dev.sh --obliterate
```

The script prints a warning, lists every collection that will be dropped, and
requires you to type `YES` (uppercase) to confirm. To skip the prompt in a
CI/automation context:

```bash
FORCE_OBLITERATE=1 ./scripts/infra/seed-mongo-dev.sh --obliterate
```

---

## What Gets Seeded

### Database: `openedx`

| Collection | What | Key field |
|---|---|---|
| `modulestore.active_versions` | Demo organisation (`MerekaDemo`) | `_type: "org"` |
| `modulestore.definitions` | Demo course stub + chapter + sequential + vertical + html block | `_type: "definition"` |
| `user.profiles` | One fake learner profile (`dev_seed_student`) | `_type: "user.profile"` |

Fixture file: `scripts/infra/fixtures/openedx-demo-course.json`

### Database: `cs_comments_service`

| Collection | What |
|---|---|
| `contents` | One pinned `CommentThread` + one `Comment` reply |

Fixture file: `scripts/infra/fixtures/forum-seed.json`

All fixture data is obviously synthetic:

- Emails use the `.invalid` TLD (`dev-seed-student@example.invalid`)
- Course ID: `course-v1:MerekaDemo+DEMO101+2025_T1`
- `_id` values start with `000000000000000000000001` / `100000000000000000000001`

---

## Adding New Fixtures

### Adding documents to an existing fixture file

Open `scripts/infra/fixtures/openedx-demo-course.json` or `forum-seed.json` and
append JSON objects to the array. Follow the `_type` convention already present
so the seed script routes them to the correct collection.

### Adding a new fixture file and target collection

1. Create `scripts/tenants/acme-branding.json` as a JSON array.
2. Call `import_fixture` in `seed-mongo-dev.sh`:

```bash
# Inside the "Seed: openedx database" section
import_fixture "openedx" "my_new_collection" "$FIXTURES_DIR/my-new-fixture.json"
```

3. If you add a new collection that should be wiped by `--obliterate`, add it to
   the `OPENEDX_COLLECTIONS` or `FORUM_COLLECTIONS` array at the top of the script.

4. Update this document with a row in the "What Gets Seeded" table.

---

## Troubleshooting

### `MONGODB_CONNECTION_STRING is not set`

Export the variable before calling the script:

```bash
export MONGODB_CONNECTION_STRING="mongodb+srv://user:pass@cluster-dev.example.mongodb.net"
```

### `Connection to Atlas failed`

- Confirm the connection string is correct (copy from Atlas UI → Connect → Drivers).
- Check your IP is on the Atlas IP allowlist for the dev cluster
  (`Atlas UI → Network Access → Add IP Address`).
- Try pinging manually: `mongosh "$MONGODB_CONNECTION_STRING" --eval 'db.runCommand({ping:1})'`

### `appears to point at the PRODUCTION Atlas cluster`

The script detected `cluster-mereka-lms.2pjex4s` in your connection string, which
is the production cluster. Create a separate dev Atlas cluster and use its
connection string.

### `mongosh not available — cannot drop collections`

Install `mongosh` for the `--obliterate` drop step:
<https://www.mongodb.com/try/download/shell>

Or set `FORCE_OBLITERATE=1` and use `mongoimport` only — it will skip the drop
step and use upsert mode instead.

---

## Production Safety Checklist

Before running outside a local/dev context, confirm:

- [ ] `MONGODB_CONNECTION_STRING` does **not** contain `cluster-mereka-lms.2pjex4s`
- [ ] You ran `--dry-run` first and reviewed the output
- [ ] You understand `--obliterate` will permanently drop collection data
- [ ] This is a dev/staging cluster, not production
