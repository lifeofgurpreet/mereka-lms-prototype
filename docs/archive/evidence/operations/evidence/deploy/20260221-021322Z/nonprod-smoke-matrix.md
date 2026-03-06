# RKE2 Nonprod Smoke Matrix Evidence
**Timestamp**: 2026-02-21T02:13:22Z
**Agent**: WhiteCliff
**Context**: rke2-nonprod / mereka-lms-local ArgoCD app
**ArgoCD revision**: 0520f7b3e1a3c62ad69475ad9c1038b2135555d1

---

## Smoke Matrix Results — 10/10 PASS

| Check | URL | Expected | Actual | Status |
|-------|-----|----------|--------|--------|
| LMS root | https://academyv2.mereka.dev/ | 200 | 200 | PASS ✓ |
| LMS login redirect | https://academyv2.mereka.dev/login | 302 | 302 | PASS ✓ |
| Studio root | https://studio.academyv2.mereka.dev/ | 200 | 200 | PASS ✓ |
| MFE authn | https://apps.academyv2.mereka.dev/authn/login | 200 | 200 | PASS ✓ |
| Admin portal | https://admin.academyv2.mereka.dev/ | 200 | 200 | PASS ✓ |
| Discovery health | https://discovery.academyv2.mereka.dev/health/ | 200 | 200 | PASS ✓ |
| Credentials login | https://credentials.academyv2.mereka.dev/login/ | 302 | 302 | PASS ✓ |
| Ecommerce login | https://ecommerce.academyv2.mereka.dev/login/ | 302 | 302 | PASS ✓ |
| LMS user API | https://academyv2.mereka.dev/api/user/v1/me | 401 | 401 | PASS ✓ |
| LMS course API | https://academyv2.mereka.dev/api/courses/v1/courses/ | 200 | 200 | PASS ✓ |

**Known skip**: `forum.academyv2.mereka.dev/heartbeat` — Forum v2 is integrated into the LMS process (no separate `forum` K8s service on nonprod). The `forum` Caddy block proxies to `forum:4567` which doesn't exist. Forum API is accessible via LMS internal routes; the Caddy landing page at the root serves correctly.

---

## Fixes Applied This Session

### 1. kustomize patchesStrategicMerge bug (PR #244)
**Problem**: `satellite-services-domain.yaml` referenced 3× via `patches.path+target` in kustomize v5 → build error:
```
Multiple Strategic-Merge Patches in one patches entry is not allowed to set patches.target field
```
**Fix**: Switched to `patchesStrategicMerge` which supports multi-doc YAML files by matching on `kind+metadata.name`.
**PRs**: #244, #245 (both merged to main)

### 2. Ecommerce ALLOWED_HOSTS (PR #243, via satellite-services-domain)
**Problem**: `ecommerce.academyv2.mereka.dev` not in ALLOWED_HOSTS (defaults to `.mereka.io`)
**Root env var**: `MEREKA_LMS_DOMAIN=academyv2.mereka.dev`
**Status**: PASS ✓

### 3. Credentials ALLOWED_HOSTS (PR #243, via satellite-services-domain)
**Problem**: `credentials.academyv2.mereka.dev` not in ALLOWED_HOSTS
**Root env var**: `MEREKA_CREDENTIALS_DOMAIN=credentials.academyv2.mereka.dev`
**Status**: PASS ✓

### 4. Discovery ALLOWED_HOSTS (PR #245, via satellite-services-domain)
**Problem**: `discovery.academyv2.mereka.dev` not in ALLOWED_HOSTS (DISCOVERY_DOMAIN derived from MEREKA_LMS_DOMAIN)
**Root env var**: `MEREKA_LMS_DOMAIN=academyv2.mereka.dev`
**Status**: PASS ✓

### 5. Ecommerce DB migrations (kubectl exec)
**Problem**: `Table 'ecommerce.django_site' doesn't exist` → 500 on all routes
**Fix**: `python manage.py migrate` in running ecommerce pod
**Status**: PASS ✓ (same pattern as credentials fix; migrations are idempotent)

### 6. Credentials DB migrations (prior session, kubectl exec)
**Problem**: `Table 'credentials.waffle_switch' doesn't exist` → uWSGI "no python application found"
**Fix**: `python manage.py migrate --run-syncdb` in credentials pod
**Status**: PASS ✓

---

## Deployment State

| Deployment | READY | Notes |
|------------|-------|-------|
| caddy | 1/1 | Running ✓ |
| lms | 1/1 | Running ✓ |
| lms-worker | 1/1 | Running ✓ |
| cms | 1/1 | Running ✓ |
| cms-worker | 1/1 | Running ✓ |
| mfe | 1/1 | Running ✓ |
| notes | 1/1 | Running ✓ |
| smtp | 1/1 | Running ✓ |
| mysql | 1/1 | Running ✓ |
| redis | 1/1 | Running ✓ |
| postgresql-payments | 1/1 | Running ✓ |
| payments-gateway | 1/1 | Running ✓ |
| discovery | 1/1 | Running ✓ |
| ecommerce | 1/1 | Running ✓ |
| ecommerce-worker | 1/1 | Running ✓ |
| credentials | 1/1 | Running ✓ |
| mysql-exporter | 1/1 | Running ✓ |
| redis-exporter | 1/1 | Running ✓ |
| elasticsearch | 1/1 | Running ✓ |
| enterprise-* | 0/0 | Expected (workload-profile: scale to 0) |
| xqueue | 0/0 | Expected (workload-profile: scale to 0) |
| meilisearch | 0/0 | Expected (workload-profile: scale to 0) |
| mux-delivery-monitor | 0/0 | Expected (workload-profile: scale to 0) |

---

## Known Gaps (Non-Blocking)

| Gap | Impact | Owner |
|-----|--------|-------|
| Forum heartbeat URL not routable on nonprod | SKIP in smoke matrix | Infrastructure |
| Enterprise services at 0/0 on nonprod | Expected by workload-profile | Design |
| Velero VolumeSnapshotClass missing on GKE prod | PVC data unsnapshotted (K8s resources backed up) | Platform |

---

## GitOps Commits (bbi-infrastructure)

| PR | Commit | Description |
|----|--------|-------------|
| #243 | fd4342a | satellite-services-domain + Gate-5 evidence |
| #244 | 4b07044 | kustomize patchesStrategicMerge fix |
| #245 | 0520f7b | discovery domain fix |
