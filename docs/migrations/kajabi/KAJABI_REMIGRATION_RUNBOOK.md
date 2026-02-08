# Kajabi Re-Migration Runbook (Feb 2026)

_Audience: Platform Eng • Owner: Migration Squad • Created: 2026-02-08_

> The Open edX instance (`mereka-lms` namespace on GKE) was intentionally rebuilt
> and is empty (0 courses, 0 users, 0 enrollments). This runbook covers the fresh
> re-migration from Kajabi.

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

**Validate credentials**:
```bash
infisical run --env=prod --path=/mereka-lms/kajabi -- node -e "
const r = await fetch('https://api.kajabi.com/v1/oauth/token', {
  method: 'POST', headers: {'Content-Type':'application/json'},
  body: JSON.stringify({grant_type:'client_credentials',
    client_id:process.env.KAJABI_CLIENT_ID,
    client_secret:process.env.KAJABI_CLIENT_SECRET})
}); const j = await r.json(); console.log(j.access_token ? 'TOKEN OK' : j);
"
```

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

**Duration**: ~2-3 hours (85K+ contacts, 100/page)

**Expected output files**:

| File | Expected count |
|------|---------------|
| `contacts.ndjson` | ~85,000+ |
| `customers.ndjson` | ~85,000+ |
| `courses_index.ndjson` | ~107+ |
| `purchases.ndjson` | ~104,000+ |
| `offers.ndjson` | ~375 |
| `products.ndjson` | ~110 |
| `transactions.ndjson` | varies |
| `contact_tags.ndjson` | ~100 |
| `forms.ndjson` | varies |
| `form_submissions.ndjson` | varies |

### 1b. Course Structure Export

```bash
infisical run --env=prod --path=/mereka-lms/kajabi -- \
  node scripts/migrations/kajabi/kajabi-course-structure.mjs \
    --input exports/kajabi/courses_index.ndjson \
    --out exports/kajabi/structure \
    --delay 400
```

**Duration**: ~45 min (107 courses, 400ms delay between requests)

**Expected**: `structure/{modules,lessons,lesson_media,lesson_details,errors}.ndjson`

### 1c. Certificate Eligibility

```bash
infisical run --env=prod --path=/mereka-lms/kajabi -- \
  node scripts/migrations/kajabi/kajabi-export-certificates.mjs \
    --out exports/kajabi
```

**Expected**: `certificate_eligibility.ndjson`

### 1d. Sanity Check

```bash
echo "=== Export Counts ==="
for f in exports/kajabi/*.ndjson; do
  echo "$(wc -l < "$f") $f"
done
echo "=== Structure Counts ==="
for f in exports/kajabi/structure/*.ndjson; do
  echo "$(wc -l < "$f") $f"
done
```

Compare against Nov 2024 baseline: contacts ~85K, customers ~85K, courses ~107, purchases ~104K.
If counts differ by >10%, investigate before proceeding.

---

## Phase 2: Transform

### 2a. Transform NDJSON to CSVs

```bash
python3 scripts/migrations/kajabi/transform_data.py \
  --exports-dir exports/kajabi \
  --structure-dir exports/kajabi/structure \
  --output-dir scripts/migrations/kajabi/output
```

**Outputs**: `users.csv`, `enrollments.csv`, `courses.csv`, `course_structure.json`, `course_summary.csv`

### 2b. Build OLX Course Packages

```bash
python3 scripts/migrations/kajabi/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA --course-prefix MEKA- --run-prefix RUN-
```

**Outputs**: ~107 `.tar.gz` OLX tarballs + `course_packages_manifest.csv`

Course key format: `course-v1:MEREKA+MEKA-{kajabi_id}+RUN-{kajabi_id}`

### 2c. Prepare Import CSVs

```bash
python3 scripts/migrations/kajabi/prepare_openedx_imports.py \
  --output-root scripts/migrations/kajabi/output \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv
```

**Outputs**: `openedx/users_import.csv`, `openedx/enrollments_import.csv`

---

## Phase 3: Import into Open edX

> **STOP**: Confirm the Open edX instance is empty and ready before proceeding.
> ```bash
> kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell \
>   -c "from django.contrib.auth.models import User; print('Users:', User.objects.count())" \
>   --settings=tutor.production
> ```

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
  --namespace mereka-lms \
  2>&1 | tee scripts/migrations/kajabi/logs/users_import_$(date +%Y%m%d).log
```

**Expected**: ~43 batches, ~84K users

### 3c. Import Enrollments (batched, resumable)

```bash
python3 scripts/migrations/kajabi/run_batches.py enrollments \
  --csv scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --batch-size 2000 \
  --namespace mereka-lms \
  2>&1 | tee scripts/migrations/kajabi/logs/enrollments_import_$(date +%Y%m%d).log
```

**Expected**: ~69 batches, ~137K enrollments

---

## Phase 4: Verification

### 4a. Count Checks

```bash
# Courses
kubectl exec -n mereka-lms deploy/lms -- \
  /bin/bash -c "cd /openedx/edx-platform && \
  ./manage.py lms shell -c 'from xmodule.modulestore.django import modulestore; \
  print(\"Courses:\", len(modulestore().get_courses()))' --settings=tutor.production"

# Users
kubectl exec -n mereka-lms deploy/lms -- \
  /bin/bash -c "cd /openedx/edx-platform && \
  ./manage.py lms shell -c 'from django.contrib.auth.models import User; \
  print(\"Users:\", User.objects.count())' --settings=tutor.production"

# Enrollments
kubectl exec -n mereka-lms deploy/lms -- \
  /bin/bash -c "cd /openedx/edx-platform && \
  ./manage.py lms shell -c 'from common.djangoapps.student.models import CourseEnrollment; \
  print(\"Enrollments:\", CourseEnrollment.objects.count())' --settings=tutor.production"
```

**Expected**: ~107 courses, ~84K users, ~137K enrollments

### 4b. Verification Script

```bash
python3 scripts/migrations/kajabi/verify-and-sync-kajabi-to-openedx.py \
  --kajabi-enrollments scripts/migrations/kajabi/output/enrollments.csv \
  --kajabi-users scripts/migrations/kajabi/output/users.csv \
  --course-manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --output-dir scripts/migrations/kajabi/output/verification
```

### 4c. UI Spot-Check

- Browse LMS catalog — courses should appear
- Open 2-3 courses — check content renders
- Check Studio dashboard — verify course list

---

## Phase 5: Post-Migration (optional, later)

1. **Lesson content scraping** — Kajabi API doesn't expose lesson body HTML.
   Run `scrape_lessons.py` with admin creds to capture real content.

2. **Webhook deployment** — Deploy `services/kajabi-webhook/` to Cloud Run for
   real-time sync of new purchases/enrollments.

3. **Certificate generation** — Use certificate eligibility data + Open edX
   `generate_certificates` command.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Export hangs on large collection | Restart with `--resources <resource> --start-page <N>` |
| `Missing KAJABI_CLIENT_ID` | Ensure `infisical run --path=/mereka-lms/kajabi` prefix |
| Course import fails | Check CMS pod logs: `kubectl logs -n mereka-lms deploy/cms --tail=50` |
| Batch import resumes from wrong offset | Delete offset file in `scripts/migrations/kajabi/logs/` |
| Users import skips rows | Check for missing email/username in CSV |

---

## Current Status (2026-02-08)

### Completed

- [x] **Phase 0**: Kajabi credentials stored in Infisical at `/mereka-lms/kajabi` (prod + dev)
- [x] **Phase 1**: Full export to `exports/kajabi/` (691MB total)
- [x] **Phase 2**: Transform complete — CSVs and OLX packages ready

### Actual Export Counts (Feb 2026)

| Resource | Count | Notes |
|----------|-------|-------|
| contacts | 326,104 | ~4x growth since Nov 2024 |
| customers | 189,640 | ~2x growth |
| courses_index | 218 | ~2x growth |
| purchases | 219,204 | ~2x growth |
| offers | 768 | |
| products | 224 | |
| contact_tags | 196 | |
| custom_fields | 52 | |
| certificate_eligibility | 386,620 | |
| structure/modules | 846 | |
| structure/lessons | 3,146 | |
| structure/lesson_media | 1,394 | |

### Transform Output

| File | Records |
|------|---------|
| users_import.csv | ~326K |
| enrollments_import.csv | ~386K |
| course_packages | 109 OLX tarballs |
| courses.csv | 218 courses |

### Pending

- [ ] **Phase 3**: Import into Open edX (courses, users, enrollments)
- [ ] **Phase 4**: Verification
- [ ] **Phase 5**: Post-migration (lesson content scraping, webhooks, certificates)

### File Locations (VPS)

```
~/projects/k8s/mereka-lms/
├── exports/kajabi/                          # Raw NDJSON exports (691MB)
│   ├── contacts.ndjson                      # 326K records
│   ├── customers.ndjson                     # 190K records
│   ├── purchases.ndjson                     # 219K records
│   ├── courses_index.ndjson                 # 218 courses
│   ├── certificate_eligibility.ndjson       # 387K records
│   └── structure/                           # Course structure
├── scripts/migrations/kajabi/output/        # Transformed data
│   ├── users.csv                            # Combined contacts/customers
│   ├── enrollments.csv                      # Purchase→enrollment mappings
│   ├── courses.csv                          # Course metadata
│   ├── course_structure.json                # Nested structure
│   ├── course_packages/                     # 109 OLX tarballs
│   │   └── course_packages_manifest.csv
│   └── openedx/                             # Import-ready CSVs
│       ├── users_import.csv
│       └── enrollments_import.csv
└── docs/migrations/kajabi/
    └── KAJABI_REMIGRATION_RUNBOOK.md        # This file
```
