# Content Libraries v2: Meilisearch Operational Runbook

> **Bead**: mereka-lms-2tvv.2
> **ACs**: AC-LIB-OP-001 through AC-LIB-OP-004
> **Date**: 2026-02-19

---

## AC-LIB-OP-001: Applying Meilisearch Config to Dev and Prod Overlays

### Production (GKE)

Meilisearch config is managed via ExternalSecret → GCP SM. No overlay-specific patches needed.

```bash
# 1. Verify Meilisearch pod is running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=meilisearch

# 2. Verify API key synced
kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d

# 3. Initialize indexes (run once, idempotent)
kubectl exec -n mereka-lms deployment/cms -- \
  python manage.py cms --settings=tutor.production shell -c \
  "from openedx_content_libraries.search import ensure_indexes; print(ensure_indexes())"

# 4. Verify health
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" http://localhost:7700/health
# Expected: {"status":"available"}
```

### Dev (Kind)

Dev overlay uses separate API key via `deploy/k8s/overlays/local/patches/openedx-secrets-dev.yaml`.

```bash
# Dev Meilisearch access — port-forward for local inspection:
kubectl port-forward -n mereka-lms svc/meilisearch 7700:7700

# Then locally:
curl -s -H "Authorization: Bearer <dev-api-key>" http://localhost:7700/health
```

---

## AC-LIB-OP-002: Scoped Search Validation Commands

### Global Library Search (all orgs)

```bash
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)

# All libraries:
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  "http://localhost:7700/indexes/content_libraries/search" \
  -H "Content-Type: application/json" \
  -d '{"q": "", "limit": 10}'
```

### Tenant-Scoped Search (by org)

```bash
# MEREKA org only:
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  "http://localhost:7700/indexes/content_libraries/search" \
  -H "Content-Type: application/json" \
  -d '{"q": "", "filter": "org = MEREKA", "limit": 10}'

# SKILLOURFUTURE org only:
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  "http://localhost:7700/indexes/content_libraries/search" \
  -H "Content-Type: application/json" \
  -d '{"q": "", "filter": "org = SKILLOURFUTURE", "limit": 10}'

# BIJIBIJI org only:
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  "http://localhost:7700/indexes/content_libraries/search" \
  -H "Content-Type: application/json" \
  -d '{"q": "", "filter": "org = BIJIBIJI", "limit": 10}'
```

### Index Stats

```bash
# Count documents per index:
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  http://localhost:7700/indexes/content_libraries/stats

kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  http://localhost:7700/indexes/library_components/stats
```

---

## AC-LIB-OP-003: Rollback and Cleanup Checklist

### Search Index Corruption

```bash
# 1. Delete corrupted index
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -X DELETE -H "Authorization: Bearer ${MEILI_KEY}" \
  http://localhost:7700/indexes/content_libraries

# 2. Re-initialize (idempotent)
kubectl exec -n mereka-lms deployment/cms -- \
  python manage.py cms --settings=tutor.production shell -c \
  "from openedx_content_libraries.search import ensure_indexes; ensure_indexes()"

# 3. Re-trigger ingestion for all libraries
kubectl exec -n mereka-lms deployment/cms -- \
  python manage.py cms --settings=tutor.production reindex_content_libraries
```

### Ingestion Failures

```bash
# Check CMS logs for search errors:
kubectl logs -n mereka-lms deployment/cms --tail=100 | grep -i "meilisearch\|search\|library"

# Check Meilisearch task queue (failed tasks):
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  "http://localhost:7700/tasks?statuses=failed&limit=10"
```

### API Key Rotation

```bash
# 1. Update GCP SM secret with new key
printf '%s' 'NEW_API_KEY' | gcloud secrets versions add MEREKA_LMS_MEILISEARCH_API_KEY \
  --data-file=- --project=bbi-k8

# 2. Force ExternalSecret refresh
kubectl annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite

# 3. Restart CMS + Meilisearch to pick up new key
kubectl rollout restart deployment/cms -n mereka-lms
kubectl rollout restart deployment/meilisearch -n mereka-lms
```

---

## AC-LIB-OP-004: Evidence Snapshots

```
Date: 2026-02-19

Meilisearch pod:
  meilisearch-778c489564-f65v2   1/1   Running   0   2d18h

Health check:
  {"status":"available"}

Indexes (current):
  [] (fresh deployment — initialize with ensure_indexes())

CMS Meilisearch env:
  MEILISEARCH_SERVICE_HOST=34.118.236.116
  MEILISEARCH_PORT_7700_TCP_PORT=7700
  MEILISEARCH_API_KEY=<REDACTED>

Content libraries migrations:
  [X] 0001_initial
  [X] 0002_group_permissions
  [X] 0003_contentlibrary_type
  [X] 0004_contentlibrary_license
```

**Owner signoff**: WhiteCliff (2026-02-19)
