# Kajabi → Open edX Migration Implementation Guide
_Audience: Platform Eng • Owner: Migration Squad • Last verified: 2025-10-05_

> **Legacy note:** This doc predates the production/dev naming. References to the old environment label should be read as production (GKE); dev runs on kind.

**Last Updated:** 2024-11-08  
**Status:** ✅ **MIGRATION COMPLETE** - All data imported successfully

> **Note:** This document is for implementing the migration end-to-end. The migration has been completed. See `docs/status/migrations/KAJABI_MIGRATION_STATUS.md` for current status.

## Current State

- **Data on production (GKE):** 84,379 users, 137,464 enrollments, 109 courses (Mongo `modulestore.active_versions`) after latest run
- **All course tarballs imported** via `scripts/migrations/kajabi/import_courses.py --backend k8s --k8s-namespace mereka-lms`
- **Batch tooling:** `scripts/migrations/kajabi/run_batches.py` + `openedx_bulk_import.py` handle offsets, retries, and log each batch to `scripts/migrations/kajabi/logs/`
- **Webhook receiver:** FastAPI app under `services/kajabi-webhook/` (with Dockerfile + README) captures real-time Kajabi events, verifies HMAC, and writes NDJSON outbox files
- **Documentation:** `docs/reference/migrations/kajabi/KAJABI_MIGRATION_NOTES.md` documents the full pipeline (exports, batched imports, course imports, validation, and webhook wiring)

## Handover Checklist

### 1. Environment Prep

**Prerequisites:**
```bash
# Activate Tutor environment
source infrastructure/tutor/tutor-env.sh

# Authenticate with GCP
gcloud auth login
gcloud config set project mereka-lms
gcloud container clusters get-credentials mereka-lms --region asia-southeast1

# Verify cluster readiness
kubectl get pods -n mereka-lms
# Expected: lms, cms, mongodb pods all in Running state
```

**Verify Tutor CLI:**
```bash
tutor --version  # Should be available after sourcing tutor-env.sh
```

### 2. Exports

**Run the Kajabi exporter:**
```bash
# From repo root
KAJABI_CLIENT_ID=<your-client-id> \
KAJABI_CLIENT_SECRET=<your-secret> \
KAJABI_SITE_ID=<optional-site-id> \
node scripts/migrations/kajabi/kajabi-export.mjs

# Outputs go to exports/kajabi/ (gitignored)
# Files: contacts.ndjson, customers.ndjson, purchases.ndjson, courses_index.ndjson, etc.
```

**Chunked exports (for large datasets):**
```bash
# Export pages 1-100 only
node scripts/migrations/kajabi/kajabi-export.mjs \
  --resources contacts \
  --start-page 1 \
  --end-page 100 \
  --page-size 100

# Resume from page 101
node scripts/migrations/kajabi/kajabi-export.mjs \
  --resources contacts \
  --start-page 101 \
  --end-page 200
```

**Course structure details:**
```bash
# If course details weren't included, run the structure helper
node scripts/migrations/kajabi/kajabi-course-structure.mjs \
  --exports-dir exports/kajabi \
  --output-dir exports/kajabi/structure
```

### 3. Transforms

**Transform raw exports to Open edX format:**
```bash
# Step 1: Transform NDJSON → CSVs
python scripts/migrations/kajabi/transform_data.py \
  --exports-dir exports/kajabi \
  --structure-dir exports/kajabi/structure \
  --output-dir scripts/migrations/kajabi/output

# Step 2: Build course packages (OLX tarballs)
python scripts/migrations/kajabi/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA \
  --course-prefix MEKA- \
  --run-prefix RUN- \
  --language en

# Step 3: Prepare Open edX import CSVs
python scripts/migrations/kajabi/prepare_openedx_imports.py \
  --output-root scripts/migrations/kajabi/output \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv
```

**Outputs created:**
- `scripts/migrations/kajabi/output/openedx/users_import.csv` - Ready for bulk user import
- `scripts/migrations/kajabi/output/openedx/enrollments_import.csv` - Ready for bulk enrollment import
- `scripts/migrations/kajabi/output/course_packages/*.tar.gz` - Course tarballs
- `scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv` - Course ID mapping

### 4. Users & Enrollments Imports

**Users import (batched, resumable):**
```bash
python3 scripts/migrations/kajabi/run_batches.py users \
  --csv scripts/migrations/kajabi/output/openedx/users_import.csv \
  --batch-size 2000 \
  --remote-csv /tmp/kajabi-users.csv \
  --namespace mereka-lms

# The script:
# - Uploads openedx_bulk_import.py + CSV to the LMS pod
# - Maintains /tmp/users.offset for resume capability
# - Logs each batch to scripts/migrations/kajabi/logs/users_offset_<n>.log
# - Retries transient failures (3 attempts, 10s backoff)
```

**Enrollments import:**
```bash
python3 scripts/migrations/kajabi/run_batches.py enrollments \
  --csv scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --batch-size 2000 \
  --remote-csv /tmp/kajabi-enrollments.csv \
  --namespace mereka-lms

# Same behavior: maintains /tmp/enrollments.offset, logs to logs/enrollments_offset_<n>.log
```

**Resuming interrupted imports:**
```bash
# Simply re-run the same command - it reads the offset file and continues
# Use --skip-upload to avoid re-uploading files if they're already in the pod
python3 scripts/migrations/kajabi/run_batches.py users \
  --csv scripts/migrations/kajabi/output/openedx/users_import.csv \
  --batch-size 2000 \
  --remote-csv /tmp/kajabi-users.csv \
  --namespace mereka-lms \
  --skip-upload
```

**Review logs:**
```bash
# Check latest batch logs
ls -lt scripts/migrations/kajabi/logs/ | head -10

# Inspect a specific batch
tail -100 scripts/migrations/kajabi/logs/users_offset_85214.log
```

### 5. Course Imports

**Import all courses:**
```bash
python3 scripts/migrations/kajabi/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s \
  --k8s-namespace mereka-lms

# Script behavior:
# - Streams each tarball via stdin to the CMS pod
# - Extracts to /tmp/kajabi-import/<slug> inside CMS
# - Rewrites course.xml run/url_name to match manifest
# - Runs ./manage.py cms import
# - Cleans up temp files automatically
```

**Dry run (test first):**
```bash
python3 scripts/migrations/kajabi/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s \
  --k8s-namespace mereka-lms \
  --dry-run \
  --limit 1
```

**Import specific courses:**
```bash
python3 scripts/migrations/kajabi/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s \
  --k8s-namespace mereka-lms \
  --only <kajabi-course-id-1> <kajabi-course-id-2>
```

**Capture full import log:**
```bash
python3 scripts/migrations/kajabi/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s \
  --k8s-namespace mereka-lms \
  2>&1 | tee scripts/migrations/kajabi/logs/course_import_$(date +%Y%m%d_%H%M%S).log
```

### 6. Validation

**User counts:**
```bash
kubectl exec -n mereka-lms deploy/lms -- \
  /bin/bash -c "cd /openedx/edx-platform && \
  ./manage.py lms shell -c '
  from django.contrib.auth import get_user_model;
  print(\"Users:\", get_user_model().objects.count())
  ' --settings=tutor.production"
```

**Enrollment counts:**
```bash
kubectl exec -n mereka-lms deploy/lms -- \
  /bin/bash -c "cd /openedx/edx-platform && \
  ./manage.py lms shell -c '
  from common.djangoapps.student.models import CourseEnrollment;
  print(\"Enrollments:\", CourseEnrollment.objects.count())
  ' --settings=tutor.production"
```

**Course presence check:**
```bash
# Replace COURSE_KEY with actual course key from manifest
COURSE_KEY="course-v1:MEREKA+MEKA-2149223856+RUN-2149223856"

kubectl exec -n mereka-lms deploy/cms -- \
  /bin/bash -c "cd /openedx/edx-platform && \
  ./manage.py cms shell -c '
  from xmodule.modulestore.django import modulestore;
  from opaque_keys.edx.keys import CourseKey;
  key = CourseKey.from_string(\"$COURSE_KEY\");
  print(\"Course exists:\", bool(modulestore().get_course(key)))
  ' --settings=tutor.production"
```

**Mongo active_versions count:**
```bash
kubectl exec -n mereka-lms mongodb-0 -- \
  mongo openedx --quiet --eval 'printjson(db.modulestore.active_versions.count())'
```

**UI spot-check:**
- LMS: `https://academyv2.mereka.io` - Verify courses appear in catalog
- Studio: `https://studio.academyv2.mereka.io` - Verify courses in dashboard

### 7. Webhook Deployment

**Build and push Docker image:**
```bash
cd services/kajabi-webhook

# Build
docker build -t gcr.io/<project-id>/kajabi-webhook:latest .

# Push
docker push gcr.io/<project-id>/kajabi-webhook:latest
```

**Deploy to Cloud Run:**
```bash
gcloud run deploy kajabi-webhook \
  --image gcr.io/<project-id>/kajabi-webhook:latest \
  --region asia-southeast1 \
  --set-env-vars KAJABI_WEBHOOK_SECRET=<your-secret>,KAJABI_WEBHOOK_OUTBOX=/tmp/outbox \
  --allow-unauthenticated \
  --port 8080

# Note the service URL (e.g., https://kajabi-webhook-xyz.a.run.app)
```

**Configure Kajabi webhooks:**
```bash
# Option 1: Manual setup in Kajabi UI
# Point each event type to: https://<service-url>/webhooks/kajabi

# Option 2: Auto-provision via exporter
WEBHOOK_TARGET_URL=https://<service-url>/webhooks/kajabi \
node scripts/migrations/kajabi/kajabi-export.mjs \
  --ensure-webhooks \
  --webhook-target $WEBHOOK_TARGET_URL
```

**Monitor webhook events:**
```bash
# If using file-based outbox (Cloud Run with mounted volume)
tail -f /path/to/outbox/purchase.ndjson | jq

# Or check Cloud Run logs
gcloud run services logs read kajabi-webhook --region asia-southeast1 --tail=50
```

**Health check:**
```bash
curl https://<service-url>/healthz
# Expected: {"status":"ok"}
```

### 8. Documentation Reference

**Primary docs:**
- `docs/reference/migrations/kajabi/KAJABI_MIGRATION_NOTES.md` - Full pipeline documentation, API coverage, webhook details
- `docs/ops/runbooks/migrations/kajabi/KAJABI_MIGRATION.md` - Transformation pipeline overview
- `services/kajabi-webhook/README.md` - Webhook receiver setup

**Script locations:**
- `scripts/migrations/kajabi/kajabi-export.mjs` - Main exporter (Node.js)
- `scripts/migrations/kajabi/kajabi-course-structure.mjs` - Course structure helper
- `scripts/migrations/kajabi/transform_data.py` - NDJSON → CSV transformer
- `scripts/migrations/kajabi/build_course_packages.py` - Course tarball builder
- `scripts/migrations/kajabi/prepare_openedx_imports.py` - Open edX CSV generator
- `scripts/migrations/kajabi/run_batches.py` - Batch runner (users/enrollments)
- `scripts/migrations/kajabi/openedx_bulk_import.py` - Django import helper (runs in pod)
- `scripts/migrations/kajabi/import_courses.py` - Course import orchestrator

**Log locations:**
- `scripts/migrations/kajabi/logs/` - Batch logs (`users_offset_*.log`, `enrollments_offset_*.log`)
- `scripts/migrations/kajabi/logs/course_import.log` - Course import history

**Output locations:**
- `exports/kajabi/` - Raw NDJSON exports (gitignored)
- `scripts/migrations/kajabi/output/` - Transformed CSVs and course packages
- `services/kajabi-webhook/outbox/` - Webhook event NDJSON files

### 9. Open Questions / To-Do

**Pending items:**
- [ ] Finalize destination for webhook events (NDJSON → Pub/Sub/BigQuery)
- [ ] Automate exporter/importer cadence (Cron/Cloud Scheduler)
- [ ] Capture Kajabi media/progress exports (manual step still outstanding)
- [ ] Document course/offer mapping for analytics (not done yet)
- [ ] Set up monitoring/alerting for webhook receiver failures
- [ ] Create rollback procedure for failed imports

**Future enhancements:**
- Adapt `_append_event` in webhook app to publish to Pub/Sub instead of files
- Add idempotency checks to prevent duplicate imports
- Create dashboard for migration progress tracking

### 10. Next Operator Tips

**Best practices:**
- ✅ Stay inside the repo's tooling; don't craft ad-hoc kubectl commands unless necessary
- ✅ Use existing logs + offsets to understand progress before rerunning anything
- ✅ When debugging, use `--dry-run` or `--limit` flags to avoid re-importing everything
- ✅ If webhook service needs customization (e.g., Pub/Sub), extend `_append_event` but keep signature verification intact
- ✅ Always snapshot counts before/after imports for validation
- ✅ Archive logs after successful runs for traceability

**Common pitfalls:**
- ⚠️ Don't forget to `source infrastructure/tutor/tutor-env.sh` before running Tutor commands
- ⚠️ Ensure `gcloud` is authenticated and cluster credentials are current
- ⚠️ Check pod readiness (`kubectl get pods -n mereka-lms`) before starting imports
- ⚠️ Verify CSV paths exist before running batch imports
- ⚠️ Course imports require the manifest CSV to match tarball paths exactly

**Troubleshooting:**
- If batch import fails mid-run, check the offset file: `kubectl exec -n mereka-lms deploy/lms -- cat /tmp/users.offset`
- If course import fails, check CMS logs: `kubectl logs -n mereka-lms deploy/cms --tail=100`
- If webhook signature fails, verify `KAJABI_WEBHOOK_SECRET` matches Kajabi UI configuration
- For large imports, monitor pod resource usage: `kubectl top pods -n mereka-lms`

## Quick Reference Commands

**Full pipeline (from scratch):**
```bash
# 1. Export
KAJABI_CLIENT_ID=... KAJABI_CLIENT_SECRET=... node scripts/migrations/kajabi/kajabi-export.mjs

# 2. Transform
python scripts/migrations/kajabi/transform_data.py \
  --exports-dir exports/kajabi --output-dir scripts/migrations/kajabi/output
python scripts/migrations/kajabi/build_course_packages.py \
  --course-structure scripts/migrations/kajabi/output/course_structure.json \
  --courses-csv scripts/migrations/kajabi/output/courses.csv \
  --output-dir scripts/migrations/kajabi/output/course_packages \
  --org MEREKA --course-prefix MEKA- --run-prefix RUN-
python scripts/migrations/kajabi/prepare_openedx_imports.py \
  --output-root scripts/migrations/kajabi/output \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv

# 3. Import users
python3 scripts/migrations/kajabi/run_batches.py users \
  --csv scripts/migrations/kajabi/output/openedx/users_import.csv \
  --batch-size 2000 --namespace mereka-lms

# 4. Import enrollments
python3 scripts/migrations/kajabi/run_batches.py enrollments \
  --csv scripts/migrations/kajabi/output/openedx/enrollments_import.csv \
  --batch-size 2000 --namespace mereka-lms

# 5. Import courses
python3 scripts/migrations/kajabi/import_courses.py \
  --manifest scripts/migrations/kajabi/output/course_packages/course_packages_manifest.csv \
  --packages-root scripts/migrations/kajabi/output/course_packages \
  --backend k8s --k8s-namespace mereka-lms
```

---

**All relevant code/config lives under `scripts/migrations/kajabi/` and `docs/reference/migrations/kajabi/KAJABI_MIGRATION_NOTES.md`.**  
**With this playbook, the next person can reproduce the migration end-to-end or push it into production without retracing the last few days of trial-and-error.**
