# Content Libraries v2 Migration Runbook

## Overview

This document describes the migration state from legacy Content Libraries (v1) to Content
Libraries v2 (Blockstore-backed) on the Mereka Academy Open edX deployment (Tutor 21.0.0 /
Ulmo release).

**Current status: Phase 0 — Foundation in place, feature flags off by default.**

The underlying Django app is installed and all feature flags are wired into LMS and CMS
settings files. No feature flag is active in production until an operator explicitly sets the
corresponding environment variable. Content Libraries v2 is a dark launch.

## What "Legacy Libraries" Means on This Platform

Open edX originally shipped a "Content Libraries v1" system backed directly by MongoDB
modulestore. In Redwood / Ulmo (v21), that v1 system is replaced by Content Libraries v2
which is backed by **Blockstore** — a Django app that stores XBlock bundles as structured
files in object storage (GCS in production, local filesystem in dev).

On this deployment:
- **v1 libraries** were never actively used in production. The platform migrated directly
  from Kajabi and MCT source content into Open edX courses, not into v1 libraries.
- **There are no v1 library assets to migrate.** The migration work for T115 is therefore
  a foundation + readiness audit, not a data migration.

## What Is Already Enabled

### Django App (Both LMS and CMS)

`openedx.core.djangoapps.content_libraries.apps.ContentLibrariesConfig` is present in
`INSTALLED_APPS` in both LMS and CMS production settings:

```
deploy/k8s/base/apps/openedx/settings/lms/production.py   line 358-359
deploy/k8s/base/apps/openedx/settings/cms/production.py   line 242-244
infrastructure/tutor/plugins/mereka_lms.py                  line 92-93, 279-280, 317-318
```

The REST API endpoint `/api/libraries/v2/` is available on the running cluster.

### Custom Extension App

`openedx_content_libraries` (Mereka custom app) is installed at build time via
`mereka_lms.py`. It provides:

| Module | Purpose |
|--------|---------|
| `backup.py` | OLX export + GCS upload via `backup_libraries` management command |
| `export_import.py` | OLX archive import/export helpers |
| `search.py` | Meilisearch re-indexing via `reindex_libraries` management command |
| `models.py` | `LibraryMetadata`, `LibraryVersion`, `LibraryComponent`, `LibraryRole`, `LibraryAccessLog`, `LibraryTenantQuota` |
| `quotas.py` | Per-org library and component quota enforcement |
| `xapi.py` | xAPI event emission for library interactions |
| `sanitize.py` | XSS/content sanitization via `audit_library_security` management command |
| `views.py`, `urls.py` | Extended REST endpoints |
| `signals.py` | Library lifecycle signal handlers |
| `analytics.py` | Usage analytics helpers |
| `admin.py` | Django admin registration for all models |

### Monitoring

PrometheusRule `library-alerts` is defined and included in Kustomize:

```
deploy/k8s/base/monitoring/prometheusrule-libraries.yaml
```

Alert rules cover:
- Cross-tenant access denial spikes
- Publish failure spikes
- Search index lag (> 1 hour)
- API latency above 2 seconds (p95)
- Export archive size > 100 MB

A nightly CronJob is defined (but not yet included in Kustomize):
```
deploy/k8s/base/monitoring/cronjob-library-export.yaml
```

### Admin Console

The `frontend-app-admin-console` MFE is built into the MFE image and served at
`/admin-console/` on the apps subdomain. It provides the UI for:
- Creating v2 libraries
- Managing library team roles
- Browsing library blocks

See `docs/operations/ADMIN_CONSOLE_SETUP.md` for full setup documentation.

## What Requires Operator Action Before Going Live

### 1. Enable the Master Feature Flag

All feature flags default to `false`. To enable Content Libraries v2 for Studio authors,
set the following environment variables on LMS and CMS pods:

```bash
CONTENT_LIBRARIES_V2_ENABLED=true
LIBRARY_RBAC_ENABLED=true
LIBRARY_TENANT_ISOLATION_ENABLED=true
LIBRARY_ACCESS_LOGGING_ENABLED=true
```

**How to activate (production):**

The environment variables must be injected via the LMS/CMS K8s Deployment. Add them as
env entries sourced from a Secret or ConfigMap:

```yaml
# In your overlay patch for lms/cms Deployment
env:
  - name: CONTENT_LIBRARIES_V2_ENABLED
    value: "true"
  - name: LIBRARY_RBAC_ENABLED
    value: "true"
  - name: LIBRARY_TENANT_ISOLATION_ENABLED
    value: "true"
  - name: LIBRARY_ACCESS_LOGGING_ENABLED
    value: "true"
```

Rolling restart pods after adding the env vars:
```bash
kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
```

### 2. Create the GCS Blockstore Bucket

Content Libraries v2 uses GCS as the backing storage for library bundles. The bucket
must exist before any library is created:

```bash
# Create bucket (one-time)
gsutil mb -p mereka-lms -l asia-southeast1 gs://lms-blockstore/
gsutil versioning set on gs://lms-blockstore/

# Grant workload identity service account access
gsutil iam ch \
  serviceAccount:blockstore@mereka-lms.iam.gserviceaccount.com:objectAdmin \
  gs://lms-blockstore/
```

The bucket name `lms-blockstore` is the default in `BLOCKSTORE_BUCKET_NAME`. Override
via env var if you rename it.

See `docs/operations/LIBRARIES_GCS_SETUP.md` for full details.

### 3. Add the Backup CronJob to Kustomize

The nightly library backup CronJob is defined but not yet included in any Kustomization:

```bash
# In deploy/k8s/base/operational/kustomization.yaml (or monitoring/kustomization.yaml)
# Add: - ../../../deploy/k8s/base/monitoring/cronjob-library-export.yaml
```

Or reference it in `deploy/k8s/base/kustomization.yaml` directly.

The CronJob calls `python manage.py lms backup_libraries` nightly at 03:00 UTC. Verify
it can resolve the `$(OPENEDX_IMAGE)` variable at runtime — the image reference must be
a concrete tag, not a variable, unless your CronJob environment patches this.

### 4. Add BLOCKSTORE_BUCKET_NAME to ExternalSecrets

`BLOCKSTORE_BUCKET_NAME` is currently not wired into ExternalSecrets. For production:

```yaml
# In deploy/k8s/base/secrets/external-secrets.yaml — add to the lms/cms secretStore data:
- secretKey: BLOCKSTORE_BUCKET_NAME
  remoteRef:
    key: MEREKA_LMS_BLOCKSTORE_BUCKET_NAME
```

If using a ConfigMap instead (non-secret value), add it directly to the LMS/CMS
environment as a literal value.

### 5. Run Database Migrations

The custom `openedx_content_libraries` app includes custom models. Migrations must run:

```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py lms migrate openedx_content_libraries
```

Verify the tables exist:
```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py lms shell -c "
from openedx_content_libraries.models import LibraryMetadata
print('OK:', LibraryMetadata.objects.count(), 'libraries')
"
```

### 6. Create the Platform-Shared Library

Mereka's spec calls for a global shared-templates library accessible to all tenants.
After enabling the feature flag:

```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py lms create_platform_library \
    --org Mereka \
    --slug shared-templates \
    --title "Mereka Shared Templates" \
    --allow-public-read
```

### 7. Validate Role Assignments via Admin Console

After enabling, verify that:
1. A staff user can reach `https://apps.academyv2.mereka.io/admin-console/libraries/`
2. Creating a library with org "Mereka" succeeds
3. Library team member assignment (read / author / admin roles) works
4. A non-staff user from a different org cannot see the library

## Migration from Legacy v1 Libraries (If Any Exist)

**This step only applies if v1 libraries were previously created by authors.**

To check if any v1 libraries exist:

```bash
kubectl exec -n mereka-lms -it deploy/lms -- \
  python manage.py lms shell -c "
from contentstore.views.library import get_library_creator_status
from openedx.core.djangoapps.content.course_overviews.models import CourseOverview
# v1 libraries appear as library/* keys in modulestore
from xmodule.modulestore.django import modulestore
ms = modulestore()
libs = ms.get_libraries()
print(f'v1 libraries found: {len(libs)}')
for lib in libs:
    print(' -', lib.location)
"
```

If v1 libraries are found, the export path is:
1. Export each v1 library via Studio: **Tools > Export**
2. Import the OLX tar.gz into a new v2 library via `/api/libraries/v2/import/`
3. Validate component count matches
4. Re-assign team members to the new library using the Admin Console
5. Update any courses that reference v1 library blocks to use v2 library references

**Expected state for Mereka Academy:** Zero v1 libraries (content came from Kajabi/MCT
course imports, not library authoring). Run the check above to confirm.

## Architecture Notes

### Storage Architecture

```
Content Libraries v2
  ├── Metadata         → MySQL (via openedx_content_libraries Django models)
  ├── XBlock content   → Blockstore → GCS (lms-blockstore bucket)
  ├── Search index     → Meilisearch (in-cluster, mereka-lms namespace)
  └── Access audit     → MySQL (LibraryAccessLog model)
```

### Feature Flag Dependency Graph

Enabling `CONTENT_LIBRARIES_V2_ENABLED=true` does not automatically enable all
sub-features. Each flag is independent:

| Flag | Default | Controls |
|------|---------|---------|
| `CONTENT_LIBRARIES_V2_ENABLED` | false | Master switch — v2 API and UI |
| `LIBRARY_RBAC_ENABLED` | false | Per-library role enforcement |
| `LIBRARY_TENANT_ISOLATION_ENABLED` | false | Org-scoped listing filtering |
| `LIBRARY_PUBLIC_READ_ENABLED` | false | Global shared libraries |
| `LIBRARIES_SEARCH_ENABLED` | false | Meilisearch integration |
| `LIBRARIES_ANALYTICS_ENABLED` | false | Usage tracking |
| `LIBRARIES_BULK_IMPORT_ENABLED` | false | Bulk OLX import |
| `LIBRARY_BACKUP_ENABLED` | false | GCS backup CronJob |
| `LIBRARY_ACCESS_LOGGING_ENABLED` | false | Cross-tenant security audit log |
| `LIBRARY_XAPI_ENABLED` | false | xAPI event emission |
| `LIBRARY_QUOTAS_ENABLED` | false | Per-tenant library/component caps |

Recommended activation order:
1. `CONTENT_LIBRARIES_V2_ENABLED=true`
2. `LIBRARY_RBAC_ENABLED=true`
3. `LIBRARY_TENANT_ISOLATION_ENABLED=true`
4. `LIBRARY_ACCESS_LOGGING_ENABLED=true`
5. `LIBRARIES_SEARCH_ENABLED=true` (after Meilisearch is confirmed healthy)
6. Remaining flags as needed per feature rollout plan

### Role Model

Library roles are stored in `ContentLibraryPermission` (upstream model) and the custom
`openedx_content_libraries.models.LibraryRole` (Mereka extension). The upstream roles are:

| Role | Can Create Blocks | Can Publish | Can Delete Library | Can Manage Team |
|------|:-----------------:|:-----------:|:------------------:|:---------------:|
| read  | N | N | N | N |
| author | Y | N | N | N |
| admin  | Y | Y | Y | Y |

Platform staff (`is_staff=True`) can access all libraries regardless of team membership.

## Verification

Run the automated checks:

```bash
./scripts/qa/verify-content-libraries-v2.sh
```

This script checks:
- Django app is installed in LMS and CMS settings
- Custom extension app is wired in Dockerfile
- PrometheusRule is included in Kustomize
- Feature flags are wired (set to false by default — that is the correct pre-activation state)
- Blockstore bucket env var is configured in settings
- Admin Console MFE is present (T114 dependency)
- CronJob manifest exists
- Migration management commands exist

## Related Documentation

| Document | Purpose |
|----------|---------|
| `docs/operations/ADMIN_CONSOLE_SETUP.md` | Admin Console RBAC and library UI |
| `docs/operations/LIBRARIES_GCS_SETUP.md` | GCS Blockstore bucket setup |
| `specs/content-libraries-v2_spec.md` | Full acceptance criteria (33 ACs) |
| `specs/plans/content-libraries-v2_plan.md` | Implementation plan |
| `specs/plans/content-libraries-v2_testplan.md` | Test plan |
| `deploy/k8s/base/monitoring/prometheusrule-libraries.yaml` | Alert rules |
| `deploy/k8s/base/monitoring/cronjob-library-export.yaml` | Backup CronJob |
| `infrastructure/tutor/custom-apps/openedx_content_libraries/` | Custom extension app |
