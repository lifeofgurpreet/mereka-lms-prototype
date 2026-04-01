# Mereka LMS Content Migration — Import Runbook

Master runbook for the full Mereka LMS data import pipeline.

## Contents

1. [Pre-requisites](#pre-requisites)
2. [Quick start](#quick-start)
3. [Phase reference](#phase-reference)
4. [Expected outputs](#expected-outputs)
5. [Re-running a phase (idempotency)](#re-running-a-phase-idempotency)
6. [Troubleshooting](#troubleshooting)
7. [Wipe and re-run](#wipe-and-re-run)
8. [Environment reference](#environment-reference)

---

## Pre-requisites

### Local machine

| Requirement | Check |
|-------------|-------|
| `kubectl` in PATH | `kubectl version --client` |
| `python3` in PATH | `python3 --version` (3.10+) |
| kubeconfig with all three contexts | `kubectl config get-contexts` |
| Disk space: ~5 GB for log files | `df -h var/` |

### Contexts required

| Env | Context |
|-----|---------|
| dev | `rke2-nonprod` |
| staging | `rke2-nonprod` |
| prod | `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster` |

### Import artifacts (must exist before running)

```
exports/
  mct/
    olx_packages/          # 28 MCT course directories, each with <name>.tar.gz
    openedx_import/
      users_import.csv     # 71,260 rows
      enrollments_import.csv  # 2,305,395 rows
  kajabi/
    openedx_import/
      users_import.csv     # 94,872 rows
      enrollments_import.csv  # 107,051 rows
      completions_import.csv  # 11,178 rows
  drive/
    olx_packages/          # 9 Drive/FOW course directories, each with <name>.tar.gz
```

Run phase 0 to validate all artifacts are present:

```bash
./scripts/migrations/run_full_import.sh --env dev --phase phase-0-verify
```

### Resources inside the cluster

Pods must be Running before starting:

```bash
kubectl get pods -n mereka-lms-dev -l 'app.kubernetes.io/name in (lms, cms)'
```

---

## Quick start

### Dry-run (print all commands without executing)

```bash
./scripts/migrations/run_full_import.sh --env dev --phase all --dry-run
```

### Full run — dev environment

```bash
./scripts/migrations/run_full_import.sh --env dev --phase all --yes
```

### Full run — staging

```bash
./scripts/migrations/run_full_import.sh --env staging --phase all --yes
```

### Full run — production

```bash
# Production requires explicit --yes because it prompts before large imports
./scripts/migrations/run_full_import.sh --env prod --phase all --yes
```

### Run a single phase

```bash
# Courses only
./scripts/migrations/run_full_import.sh --env dev --phase phase-1-courses

# Users only (after courses are imported)
./scripts/migrations/run_full_import.sh --env dev --phase phase-2-users

# Continue from enrollments if users are done
./scripts/migrations/run_full_import.sh --env dev --phase phase-3-enrollments --yes
```

### Override kubectl context

```bash
./scripts/migrations/run_full_import.sh \
  --env dev \
  --phase phase-1-courses \
  --context rke2-nonprod
```

---

## Phase reference

### phase-0-verify — Pre-flight

Validates cluster access, pod health, all export artifacts, and CSV row counts.
No writes. Always safe to run.

Expected runtime: 5–15 seconds.

### phase-1-courses — Course import

Copies each OLX tarball to the CMS pod via `kubectl cp`, extracts it, and
runs `manage.py cms import`. Processes MCT packages first, then Drive packages.

- MCT packages: 28 courses (from `exports/mct/olx_packages/`)
- Drive packages: 9 courses (from `exports/drive/olx_packages/`)
- 5-second delay between each course import (avoids overloading CMS workers)
- Idempotent: re-importing an existing course key overwrites with the same
  data — Open edX course import is a replace operation, not an append.

Expected runtime: 20–45 minutes (37 courses × ~60s avg).

**Note**: The script detects success by looking for `Seeding forum`,
`Successfully imported`, or `import_course_draft` in the manage.py output. If a
course import silently fails, check the log file for that course's output block.

### phase-2-users — User import

Copies the bulk import scripts and user CSVs to the LMS pod, then runs
batched imports for MCT users (71,260 rows) and Kajabi users (94,872 rows).

Batch size: 2,000 rows per batch.

- MCT import uses `openedx_bulk_import_mct.py` — handles `full_name`, `dob`,
  `learning_pathways`, `mct_user_id` fields, plus de-duplication by email.
- Kajabi import uses `openedx_bulk_import.py` — handles `kajabi_contact_id` /
  `kajabi_customer_id` metadata.

**Column name note**: Both CSVs use the column `name` for the user's display
name, but both import scripts read the column `full_name`. The `name` column
is therefore not applied to the user profile. Names can be patched in a
follow-up using `post_import_metadata.py`.

Both scripts are idempotent: existing users are updated (not duplicated).
Username conflicts are resolved by appending an email hash suffix.

Expected runtime: 2–4 hours (166,000 users at ~20ms/user).

### phase-3-enrollments — Enrollment import

Copies enrollment CSVs to the LMS pod and runs batched imports.

Batch size: 5,000 rows per batch.

- MCT enrollments: 2,305,395 rows (most time-consuming phase)
- Kajabi enrollments: 107,051 rows
- Rows where the course does not exist in Open edX are silently skipped
  (counted as `skipped_course_not_found` in logs).
- Rows where the user email has no matching account are similarly skipped.

Idempotent: `CourseEnrollment.get_or_create_enrollment` is used. Re-running
updates mode/active-state but does not create duplicate enrollments.

Expected runtime: 6–18 hours for MCT (2.3M rows), 30–60 min for Kajabi.

**Tip**: Run MCT enrollments overnight. You can also run phases 4–7 in
parallel or immediately after phase-2 by running them in separate terminals.

### phase-4-completions — Kajabi certificate issuance

Copies `completions_import.csv` and `post_import_completions.py` to the LMS
pod and runs them inside `manage.py lms shell`. Creates
`GeneratedCertificate` records (status=downloadable) for completed Kajabi
courses.

11,178 completions. Script caches user lookups in memory for speed.

A result CSV is copied back to `var/import/cert_import_results_{env}_{ts}.csv`
for audit purposes.

Expected runtime: 5–15 minutes.

### phase-5-metadata — Descriptions and images

Runs `post_import_metadata.py` from the host (not inside a pod). This script
uses `kubectl exec` internally to push course descriptions and thumbnail images.

Expected runtime: 10–30 minutes depending on image upload speed.

### phase-6-catalogs — Enterprise catalog assignment

Runs `post_import_enterprise_catalogs.py` from the host. Creates
`EnterpriseCustomerCatalog` records linking each tenant to the right course set:

- Mereka Academy → all MEREKA org courses
- Skill Our Future → MCT + FOW courses
- Biji-Biji Academy → UPAI courses

Idempotent: existing catalogs are updated, not duplicated.

Expected runtime: 2–5 minutes.

### phase-7-taxonomy — Taxonomy tagging

Copies `post_import_taxonomy.py` to the LMS pod and runs it inside
`manage.py lms shell`. Tags all 36 courses with subjects, difficulty,
language, etc.

Idempotent: tags are replaced with the canonical mapping on re-run.

Expected runtime: 2–5 minutes.

### phase-8-verify — Post-import verification

Runs `run-verification-pipeline.sh` which executes QA verification scripts
under `scripts/qa/`. Also prints a quick DB count summary (users, enrollments,
certificates) directly from the LMS pod.

Expected runtime: 5–15 minutes.

---

## Expected outputs

After a successful full run:

| Metric | Dev target |
|--------|------------|
| Courses in CMS | 37 (28 MCT + 9 Drive) |
| Users created | ~112,000 (71,260 MCT + 94,872 Kajabi, minus ~94 overlap) |
| Enrollments | ~2.4M (2,305,395 MCT + 107,051 Kajabi, minus missing-course skips) |
| Certificates | ~11,178 (Kajabi completions) |

Quick verification from any terminal:

```bash
NS=mereka-lms-dev
LMS_POD=$(kubectl get pods -n $NS -l app.kubernetes.io/name=lms --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n $NS $LMS_POD -c lms -- \
  python manage.py lms shell -c "
from django.contrib.auth import get_user_model
from common.djangoapps.student.models import CourseEnrollment
from lms.djangoapps.certificates.models import GeneratedCertificate
User = get_user_model()
print('Users:',        User.objects.count())
print('Enrollments:',  CourseEnrollment.objects.count())
print('Certificates:', GeneratedCertificate.objects.count())
"
```

Count courses in CMS:

```bash
CMS_POD=$(kubectl get pods -n $NS -l app.kubernetes.io/name=cms --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n $NS $CMS_POD -c cms -- \
  python manage.py cms shell -c "
from xmodule.modulestore.django import modulestore
courses = list(modulestore().get_courses())
print('Total courses:', len(courses))
for c in sorted(courses, key=lambda x: str(x.id)):
    print(' ', c.id)
"
```

---

## Re-running a phase (idempotency)

All phases are designed to be re-run safely:

| Phase | Re-run behaviour |
|-------|-----------------|
| phase-0 | Read-only — always safe |
| phase-1 | Course import is a replace operation — existing course data is overwritten with identical data |
| phase-2 | Users are `update_or_create` — no duplicates created |
| phase-3 | Enrollments use `get_or_create_enrollment` — no duplicates; mode/active-state may be re-updated |
| phase-4 | Certificates are inserted with `ignore_conflicts=True` — existing certs untouched |
| phase-5 | Metadata script checks for existing descriptions before writing |
| phase-6 | Enterprise catalogs are updated in-place if they already exist |
| phase-7 | Taxonomy tags are replaced with canonical mapping |
| phase-8 | Verification only — no writes |

### Resuming a failed enrollment import

The bulk import scripts support `--offset` and `--limit` flags. If phase-3
fails partway through, find the last successfully logged batch boundary in the
log file and resume from there:

```bash
# Find the last successful batch offset in the log
grep "MCT enr batch" var/import/import-dev-*.log | tail -5

# Resume from the next batch
RESUME_OFFSET=1500000  # adjust to the offset AFTER the last successful batch

NS=mereka-lms-dev
LMS_POD=$(kubectl get pods -n $NS -l app.kubernetes.io/name=lms \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n $NS $LMS_POD -c lms -- \
  python /tmp/openedx_bulk_import_mct.py enrollments \
    --csv /tmp/mct_enrollments.csv \
    --settings lms.envs.tutor.production \
    --offset $RESUME_OFFSET \
    --limit 5000
```

The CSV files remain on the pod after phase-3 completes. If the pod has been
restarted you will need to re-copy them.

---

## Troubleshooting

### "No running LMS pod found"

```bash
kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms
```

If pods are in `CrashLoopBackOff` or `Pending`, fix the pod issue before
running the import. The script will wait up to 50 seconds retrying.

### "kubectl cp" fails with "error: pods not in Running state"

The pod may be restarting. Wait for it to be fully Ready:

```bash
kubectl wait --for=condition=Ready pod -n mereka-lms-dev \
  -l app.kubernetes.io/name=cms --timeout=120s
```

### Course import shows no success marker

Check the full output for that course in the log file:

```bash
grep -A 20 "phase-1-courses" var/import/import-dev-*.log | grep -A 10 "<course-name>"
```

Common reasons:
- Corrupt tarball — re-export the OLX package
- Course key collision — check if an existing course has the same key with
  different run metadata (Open edX treats key as unique)
- OOM in CMS pod — run `kubectl top pod -n mereka-lms-dev` and check CMS memory

### Enrollment skips are very high (>50% of rows)

Most likely cause: courses were not imported before enrollments were run.
Run phase-1-courses first, wait for the course overview cache to refresh
(~5 minutes), then re-run phase-3.

Check which course IDs are being skipped:

```bash
kubectl exec -n mereka-lms-dev $LMS_POD -c lms -- \
  python manage.py lms shell -c "
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
keys = sorted(str(k) for k in CourseOverview.objects.values_list('id', flat=True))
print('Courses in overview:', len(keys))
for k in keys:
    print(' ', k)
"
```

### Certificate phase fails with "CSV not found"

The completions CSV was not copied to the pod. Re-run phase-4 — it always
re-copies before running.

### Enterprise catalog script fails with "LMS pod not found"

`post_import_enterprise_catalogs.py` defaults to namespace `mereka-lms-dev`.
Pass `--namespace` explicitly if targeting a different namespace.

### Large file transfers time out

For large CSVs (MCT enrollments = ~500MB), `kubectl cp` can time out on slow
connections. Alternative: stream via `stdin`:

```bash
kubectl exec -n mereka-lms-dev $LMS_POD -c lms -- \
  bash -c "cat > /tmp/mct_enrollments.csv" \
  < exports/mct/openedx_import/enrollments_import.csv
```

### Checking what's already in the pod's /tmp

```bash
kubectl exec -n mereka-lms-dev $LMS_POD -c lms -- ls -lh /tmp/
```

---

## Wipe and re-run

To wipe all imported data and start fresh on dev:

### Wipe enrollments and users

```bash
NS=mereka-lms-dev
LMS_POD=$(kubectl get pods -n $NS -l app.kubernetes.io/name=lms \
  --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n $NS $LMS_POD -c lms -- \
  python manage.py lms shell -c "
from common.djangoapps.student.models import CourseEnrollment
from lms.djangoapps.certificates.models import GeneratedCertificate
from django.contrib.auth import get_user_model
User = get_user_model()

# WARNING: This deletes ALL non-staff, non-superuser accounts
count = User.objects.filter(is_staff=False, is_superuser=False).count()
print(f'About to delete {count} users and all their enrollments/certs')
# Uncomment to actually execute:
# CourseEnrollment.objects.all().delete()
# GeneratedCertificate.objects.all().delete()
# User.objects.filter(is_staff=False, is_superuser=False).delete()
print('DRY RUN - uncomment lines above to execute')
"
```

### Wipe all courses

Use the `rollback-openedx-imports.py` script which handles modulestore cleanup:

```bash
python3 scripts/migrations/rollback-openedx-imports.py \
  --namespace mereka-lms-dev \
  --dry-run
# Remove --dry-run to execute
```

### Re-run after wipe

```bash
./scripts/migrations/run_full_import.sh --env dev --phase all --yes
```

---

## Environment reference

| Property | dev | staging | prod |
|----------|-----|---------|------|
| Namespace | `mereka-lms-dev` | `stg-mereka-lms` | `mereka-lms` |
| Cluster context | `rke2-nonprod` | `rke2-nonprod` | `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster` |
| LMS URL | `https://academyv2.mereka.dev` | `https://staging.academyv2.mereka.dev` | `https://academyv2.mereka.io` |

### Checking log files

All runs write to `var/import/import-{env}-{timestamp}.log`:

```bash
ls -lt var/import/*.log
tail -f var/import/import-dev-*.log  # follow latest
```

### Batch size tuning

Default batch sizes are set conservatively. If the pods have enough memory
and the run is taking too long, increase them:

```bash
# Example: larger enrollment batches on prod
# Edit USER_BATCH_SIZE and ENROLLMENT_BATCH_SIZE near the top of run_full_import.sh
USER_BATCH_SIZE=5000
ENROLLMENT_BATCH_SIZE=10000
```
