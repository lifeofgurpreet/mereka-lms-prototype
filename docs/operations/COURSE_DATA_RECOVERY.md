# Course Data Recovery (MCT + Kajabi)
_Last updated: 2026-02-05 • Owner: Platform Ops_

## Summary
MongoDB Atlas is the source of truth, but `modulestore` is currently empty in prod.
MySQL `CourseOverview` is also empty, so Studio/LMS appear blank until data is restored.

### Current Findings (2026-02-05)
- LMS `CourseOverview` count: **0**
- Modulestore course count: **0**
- MySQL backup exists in GCS and contains course_overviews rows:
  `gs://staging-academy-mereka-io-backup/sql/2025-12-13T180926Z/openedx.sql.gz` (legacy bucket name for production backups)
- Atlas snapshots list returns **0** (backups not enabled)

## Symptoms
- Studio dashboard shows no courses
- LMS catalog empty
- `CourseOverview.objects.count()` returns `0`
- Modulestore course count `0` (no active versions)

## Confirm the Gap
```bash
kubectl exec -n mereka-lms deploy/lms -- python /openedx/edx-platform/manage.py lms shell -c \
"from openedx.core.djangoapps.content.course_overviews.models import CourseOverview; \
print('CourseOverview', CourseOverview.objects.count())"

kubectl exec -n mereka-lms deploy/lms -- python /openedx/edx-platform/manage.py lms shell -c \
"from xmodule.modulestore.django import modulestore; \
store=modulestore(); \
print('modulestore_courses', sum(1 for _ in store.get_courses()))"

# MySQL backup sanity check (contains course_overviews rows; legacy bucket name)
gsutil cat gs://staging-academy-mereka-io-backup/sql/2025-12-13T180926Z/openedx.sql.gz | \
  zgrep -m1 'course_overviews_courseoverview'

# Atlas snapshots (currently empty; backups need enabling)
atlas backups snapshots list cluster-mereka-lms --projectId <PROJECT_ID>
```

## Required Secrets (Infisical)
All migration secrets live under `/k8s/mereka-lms/migrations` (prod + dev envs).

### MCT
- `MCT_BASE_URL`, `MCT_ENDPT`, `MCT_API_URI`
- `MCT_CLIENT_ID`, `MCT_CLIENT_SECRET`, `MCT_TENANT_ID`
- `MCT_API_VERSION`, `MCT_ACCESS_TOKEN` (optional override)

**Infisical path:** `/k8s/mereka-lms/migrations/mct`

### Kajabi
- `KAJABI_CLIENT_ID`, `KAJABI_CLIENT_SECRET`, `KAJABI_SITE_ID`
- `KAJABI_WEBHOOK_SECRET`, `KAJABI_EMAIL`, `KAJABI_PASSWORD`

**Infisical path:** `/k8s/mereka-lms/migrations/kajabi`

## Recovery Flow (High Level)

### 1) Export MCT + Kajabi data
```bash
# MCT export (writes to exports/mct/)
MCT_BASE_URL=... \
MCT_API_URI=... \
MCT_CLIENT_ID=... \
MCT_CLIENT_SECRET=... \
MCT_TENANT_ID=... \
node scripts/migrations/mct/mct-export.mjs

# Kajabi export (writes to exports/kajabi/)
KAJABI_CLIENT_ID=... \
KAJABI_CLIENT_SECRET=... \
KAJABI_SITE_ID=... \
node scripts/migrations/kajabi/kajabi-export.mjs
```

### 2) Transform + build course packages
```bash
python scripts/migrations/mct/build_course_packages.py
python scripts/migrations/kajabi/build_course_packages.py
```

### 3) Import into Open edX (K8s)
```bash
# MCT
python scripts/migrations/mct/import_courses_k8s.py

# Kajabi
python scripts/migrations/kajabi/import_courses.py \
  --backend k8s --k8s-namespace mereka-lms \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages
```

### 4) Verify
```bash
kubectl exec -n mereka-lms deploy/lms -- python /openedx/edx-platform/manage.py lms shell -c \
"from xmodule.modulestore.django import modulestore; print(len(modulestore().get_courses()))"

curl -I https://studio.academyv2.mereka.io
curl -I https://academyv2.mereka.io/courses
```

## Notes
- Do **not** drop or truncate MongoDB collections; import only.
- Store exports under `exports/` or `var/migrations/` (gitignored).
- Update `docs/migrations/*/KAJABI_MIGRATION_STATUS.md` and `MCT_MIGRATION_STATUS.md`
  after successful imports.
