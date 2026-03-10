# Kajabi Re-Migration Runbook

_Audience: Platform Eng • Owner: Migration Squad • Last reviewed: 2026-03-10_

> Use this runbook when the target Open edX environment must be repopulated from
> the Kajabi export pipeline after a rebuild, reset, or failed migration attempt.

## Prerequisites

- VPS access: `ssh mereka`
- Infisical CLI authenticated (`infisical login` done)
- `mereka-lms` pods running: `kubectl get pods -n mereka-lms`
- Node 20+ and Python 3.12+ available on VPS

## Secrets

All Kajabi credentials live in Infisical under the `mereka-lms` project:

| Path | Environment | Secrets |
|------|-------------|---------|
| `/mereka-lms/kajabi` | `prod` | `KAJABI_CLIENT_ID`, `KAJABI_CLIENT_SECRET`, `KAJABI_SITE_ID`, `KAJABI_WEBHOOK_SECRET` |
| `/mereka-lms/kajabi` | `dev` | Same values (Kajabi has one environment) |

**Usage pattern** — prefix any command with:
```bash
cd ~/projects/k8s/mereka-lms
infisical run --env=prod --path=/mereka-lms/kajabi -- <command>
```

---

## Kajabi API Coverage

Endpoints confirmed via [official docs](https://developers.kajabi.com) and live probing (Feb 2026):

| Endpoint | Status | Exported by |
|----------|--------|-------------|
| contacts | 200 | `kajabi-export.mjs` |
| customers | 200 | `kajabi-export.mjs` |
| contact_tags | 200 | `kajabi-export.mjs` |
| custom_fields | 200 | `kajabi-export.mjs` |
| offers | 200 | `kajabi-export.mjs` |
| products | 200 | `kajabi-export.mjs` |
| courses | 200 | `kajabi-export.mjs` |
| purchases | 200 | `kajabi-export.mjs` |
| transactions | 200 | `kajabi-export.mjs` |
| orders | 200 | `kajabi-export.mjs` |
| order_items | 200 | `kajabi-export.mjs` |
| forms | 200 | `kajabi-export.mjs` |
| form_submissions | 200 | `kajabi-export.mjs` |
| blog_posts | 200 | `kajabi-export.mjs` |
| landing_pages | 200 | `kajabi-export.mjs` |
| contact_notes | 200 | `kajabi-export.mjs` |
| podcasts | 200 | `kajabi-export.mjs` |
| **completions** | **404** | No API — use tag-based workaround |
| **certificates** | **404** | No API — use tag-based workaround |
| **progress** | **404** | Not available |

### Completion Data Workaround

Kajabi has no completions/certificates API. However, lesson automations tag
contacts on completion (e.g. `F101 - Course Completed`, `MYFC - Quiz 1 Completed`).

`kajabi-export-completions.mjs` queries contacts by these tags to produce
`completions.ndjson` — real completion data that can drive certificate issuance
in Open edX.

---

## Contacts vs Users

Kajabi "contacts" includes everyone who ever touched the site (leads, subscribers,
form fills). Only a subset are actual course users:

| Segment | Feb 2026 count | Import? |
|---------|---------------|---------|
| All contacts | 326K | No — too broad |
| With enrollments (purchases) | ~73K | Yes — these are real learners |
| Signed in 2+ times | ~106K | Alternative filter |
| Never signed in | ~23K | No |

**Decision**: Import only users with actual enrollments (~73K), not all 326K contacts.
The `prepare_openedx_imports.py` script should be updated to filter accordingly.

---

## Phase 1: Export (run on VPS)

All commands assume `cd ~/projects/k8s/mereka-lms`.

### 1a. Full API Export

```bash
mkdir -p exports/kajabi

infisical run --env=prod --path=/mereka-lms/kajabi -- \
  node scripts/migrations/kajabi/kajabi-export.mjs \
    --out exports/kajabi \
    2>&1 | tee exports/kajabi/export_$(date +%Y%m%d).log
```

**Duration**: ~3-4 hours (326K contacts at 100/page, plus other resources)

**IMPORTANT**: The export script resets each file before writing. If rate-limited
mid-export, resume with `--resources <remaining> --start-page 1` — do NOT use
`--start-page N` on a resource that was partially exported (it truncates the file first).

### 1b. Course Structure Export

```bash
infisical run --env=prod --path=/mereka-lms/kajabi -- \
  node scripts/migrations/kajabi/kajabi-course-structure.mjs \
    --input exports/kajabi/courses_index.ndjson \
    --out exports/kajabi/structure \
    --delay 400
```

### 1c. Completions Export (tag-based)

```bash
infisical run --env=prod --path=/mereka-lms/kajabi -- \
  node scripts/migrations/kajabi/kajabi-export-completions.mjs \
    --out exports/kajabi \
    2>&1 | tee exports/kajabi/completions_$(date +%Y%m%d).log
```

**Duration**: Several hours (50 tags, many with 90K+ contacts each)

**Output**: `completions.ndjson` — each record has:
```json
{
  "email": "user@example.com",
  "name": "User Name",
  "contact_id": "...",
  "tag_id": "...",
  "tag_name": "MYFC - Course Completed",
  "tag_type": "course_completed",
  "course_prefix": "MYFC"
}
```

Tag types: `course_completed`, `quiz_completed`, `certificate`, `onboarded`, `started`

### 1d. Sanity Check

```bash
echo "=== Export Counts ==="
for f in exports/kajabi/*.ndjson; do
  printf "%8d %s\n" "$(wc -l < "$f")" "$(basename $f)"
done
echo "=== Structure Counts ==="
for f in exports/kajabi/structure/*.ndjson; do
  printf "%8d %s\n" "$(wc -l < "$f")" "$(basename $f)"
done
```

---

## Phase 2: Transform

### 2a. Transform NDJSON to CSVs

```bash
python3 scripts/migrations/kajabi/transform_data.py \
  --exports-dir exports/kajabi \
  --structure-dir exports/kajabi/structure \
  --output-dir scripts/migrations/kajabi/output
```

### 2b. Build OLX Course Packages

```bash
python3 scripts/migrations/kajabi/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA --course-prefix MEKA- --run-prefix RUN-
```

Course key format: `course-v1:MEREKA+MEKA-{kajabi_id}+RUN-{kajabi_id}`

### 2c. Prepare Import CSVs

```bash
python3 scripts/migrations/kajabi/prepare_openedx_imports.py \
  --output-root scripts/migrations/kajabi/output \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv
```

The import set must be limited to users with actual enrollments rather than the
full Kajabi contacts universe.

---

## Phase 3: Import into Open edX

> **STOP**: Confirm the Open edX instance is empty and ready before proceeding.

### 3a. Import Courses (into CMS)

**Dry run first** (3 courses):
```bash
python3 scripts/migrations/kajabi/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s --k8s-namespace mereka-lms \
  --dry-run --limit 3
```

**Full import**:
```bash
python3 scripts/migrations/kajabi/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s --k8s-namespace mereka-lms \
  2>&1 | tee scripts/migrations/kajabi/logs/course_import_$(date +%Y%m%d).log
```

### 3b. Import Users (batched, resumable)

```bash
python3 scripts/migrations/kajabi/run_batches.py users \
  --csv scripts/migrations/kajabi/output/openedx/users_import.csv \
  --batch-size 2000 \
  --namespace mereka-lms
```

### 3c. Import Enrollments (batched, resumable)

```bash
python3 scripts/migrations/kajabi/run_batches.py enrollments \
  --csv scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --batch-size 2000 \
  --namespace mereka-lms
```

### 3d. Issue Certificates (from completions data)

After users and enrollments are imported, use `completions.ndjson` to issue certs:

```bash
# Filter to course_completed tags only, extract unique emails per course_prefix
python3 -c "
import json
completions = {}
with open('exports/kajabi/completions.ndjson') as f:
    for line in f:
        d = json.loads(line)
        if d['tag_type'] == 'course_completed':
            key = (d['email'], d['course_prefix'])
            if key not in completions:
                completions[key] = d
print(f'Unique course completions: {len(completions)}')
"
```

Certificate issuance requires a maintained mapping from Kajabi tag prefixes to
Open edX course keys before invoking the certificate workflow.

---

## Phase 4: Verification

### 4a. Count Checks

```bash
kubectl exec -n mereka-lms deploy/lms -- \
  /bin/bash -c "cd /openedx/edx-platform && \
  ./manage.py lms shell -c '
from django.contrib.auth.models import User
from common.djangoapps.student.models import CourseEnrollment
from xmodule.modulestore.django import modulestore
print(\"Courses:\", len(modulestore().get_courses()))
print(\"Users:\", User.objects.count())
print(\"Enrollments:\", CourseEnrollment.objects.count())
' --settings=tutor.production"
```

### 4b. Verification Script

```bash
python3 scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir scripts/migrations/kajabi/output/verification
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Export rate-limited | Wait 2-5 min, restart with `--resources <remaining>` (NOT `--start-page`, it truncates) |
| `Missing KAJABI_CLIENT_ID` | Use `infisical run --path=/mereka-lms/kajabi` prefix |
| Course import fails | Check CMS pod logs: `kubectl logs -n mereka-lms deploy/cms --tail=50` |
| Batch import resumes wrong | Delete offset file in `scripts/migrations/kajabi/logs/` |
| `transform_data.py` | NDJSON → CSVs |
| `build_course_packages.py` | CSVs → OLX tarballs |
| `prepare_openedx_imports.py` | Generate import-ready CSVs (enrolled-only, deduplicated) |
| `import_courses.py` | OLX → CMS import |
| `run_batches.py` | Batched user/enrollment import |
| `scrape_lessons.py` | Playwright-based lesson HTML scraper |

### File Locations (VPS)

```
~/projects/k8s/mereka-lms/
├── exports/kajabi/                          # Raw NDJSON exports (691MB)
│   ├── contacts.ndjson                      # 326K contacts
│   ├── customers.ndjson                     # 190K customers
│   ├── purchases.ndjson                     # 219K purchases
│   ├── courses_index.ndjson                 # 218 courses
│   ├── completions.ndjson                   # 11,179 tag-based completions
│   ├── landing_pages.ndjson                 # 22 landing pages
│   ├── podcasts.ndjson                      # 1 podcast
│   └── structure/                           # Course structure
├── scripts/migrations/kajabi/
│   ├── output/                              # Transformed data
│   │   ├── course_packages/                 # 109 OLX tarballs
│   │   ├── openedx/                         # Import-ready CSVs
│   │   └── tag_prefix_to_course_mapping.json
│   └── logs/                                # Import logs
└── docs/ops/runbooks/migrations/kajabi/
    └── KAJABI_REMIGRATION_RUNBOOK.md         # This file
```

---

## Import Execution Results (2026-02-09)

### Summary

| Entity | CSV Rows | Unique | Imported | Notes |
|--------|----------|--------|----------|-------|
| Courses | 109 | 109 | **109** | All successful, ~55 min |
| Users | 73,107 | 73,107 | **72,354** | 753 merged via email collision |
| Enrollments | 386,300 | 147,971 | **146,887** | 238K duplicate rows, 1,084 skipped |
| Certificates | 3,268 | — | **3** (test) | gurpreet@biji-biji.com test certs |

### Key Lessons

1. **ArgoCD ConfigMap churn**: LMS pods roll every 3-5 min due to CSS ConfigMap hash changes. Use `resilient_import.sh` instead of `run_batches.py`.

2. **Resilient import script**: Re-resolves pods and re-uploads files on each batch. Survived 3+ pod changes during 6.5-hour enrollment import.

3. **Enrollment duplicates**: CSV had 238K duplicate (email, course_id) pairs. Handled idempotently.

4. **Certificate API**: Use `GeneratedCertificate.objects.update_or_create()` with `CertificateStatuses.downloadable`. The `generate_certificate_task()` requires actual course completion/grading.

5. **Profile requirement**: Users need a UserProfile for certificates. Pre-existing admin users may not have one.

### Incremental Re-migration

All scripts are idempotent (update_or_create / enroll). Re-export from Kajabi and re-run to add new data without duplicating existing records.


## Post-Import Follow-up (2026-02-09, Session 2)

### Contact Duplication Investigation

The contacts export (326,104 records) was found to have only **94,872 unique emails**. Root cause: **Kajabi API pagination bug** -- the API returns the same page multiple times before advancing. Analysis:
- 654 pages appeared 4x consecutively
- 437 pages appeared 3x consecutively
- 30 pages appeared 2x consecutively
- 295 pages appeared 1x (no duplication)
- This is NOT a script bug -- the resetFile() call works correctly. The Kajabi API itself is non-deterministic with page[number] pagination.

### Remaining Contacts Import

After deduplicating, 21,779 contacts were not in the initial enrolled-users import. These were imported using resilient_import.sh:
- 11 batches, ~25 minutes
- ~21,663 created, ~116 updated (overlap with enrolled set), 0 failed

### Certificate Issuance

Issued certificates for all 3,268 course_completed records from completions.ndjson:
- **3,265 certificates issued** (1,131 first pass + 2,135 after contacts import)
- 3 skipped (user email not found)
- Uses GeneratedCertificate.objects.update_or_create() with CertificateStatuses.downloadable

### Course Thumbnails Migration

Downloaded 109 thumbnail images from Kajabi S3 pre-signed URLs and uploaded to CMS contentstore:
- 109/109 uploaded, 0 failed
- Each course's course_image field updated in modulestore
- **NOTE**: Kajabi S3 pre-signed URLs expire 7 days after export. If re-export is needed, run the Kajabi export again.

### Final Verification

| Metric | Count |
|--------|-------|
| Courses | 109 |
| Users | 94,017 |
| Enrollments | 146,887 |
| Certificates | 3,266 |
| Course thumbnails | 109/109 |
