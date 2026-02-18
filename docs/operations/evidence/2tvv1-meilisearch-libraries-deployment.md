# Libraries v2: Meilisearch Deployment and Validation

> **Bead**: mereka-lms-2tvv.1
> **ACs**: AC-LIB-001 through AC-LIB-005
> **Date**: 2026-02-19

---

## AC-LIB-001: CMS Meilisearch Config Applied to Cluster

### Status: PASS

| Check | Result |
|-------|--------|
| Meilisearch pod running | ✅ `meilisearch-778c489564-f65v2` — 1/1 Running (2d18h) |
| Meilisearch service (ClusterIP) | ✅ `34.118.236.116:7700` |
| Meilisearch health endpoint | ✅ `{"status":"available"}` |
| `MEILISEARCH_API_KEY` in `openedx-secrets` | ✅ Present (synced from GCP SM) |
| `MEILISEARCH_MASTER_KEY` in CMS env | ✅ `628b1d17660ca71027f87890993082f4` |
| `MEILISEARCH_API_KEY` in CMS env | ✅ `9bff9b95fbdb1a4ba97dc83486ce9b57` |
| CMS → Meilisearch connectivity | ✅ `MEILISEARCH_SERVICE_HOST=34.118.236.116` |
| Content libraries migrations applied | ✅ 0001–0004 all `[X]` |

**Config source**: `deploy/k8s/base/secrets/openedx-secrets.yaml` (ExternalSecret → GCP SM)
**Search integration code**: `infrastructure/tutor/custom-apps/openedx_content_libraries/search.py`

### Index Status

Meilisearch currently has **0 indexes** — this is expected for a fresh deployment. Indexes are created on-demand when `ensure_indexes()` is called from the CMS content libraries app (or via `manage.py` command).

```bash
# Verify current indexes:
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" http://localhost:7700/indexes

# Create indexes (run once to initialize):
kubectl exec -n mereka-lms deployment/cms -- \
  python manage.py cms --settings=tutor.production shell -c \
  "from openedx_content_libraries.search import ensure_indexes; ensure_indexes()"
```

---

## AC-LIB-002: Library Search Endpoints

### Status: READY (pending index creation)

Expected indexes once initialized:
- `content_libraries` — library-level search (primary key: `id`, filterable: `org`, `tenant_uuid`, `is_deleted`, `allow_public_read`)
- `library_components` — block-level search

```bash
# Validate search returns results after index creation:
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  "http://localhost:7700/indexes/content_libraries/search" \
  -d '{"q": ""}'
```

CMS REST API for library search: `GET /api/libraries/v2/?search_term=<query>`

---

## AC-LIB-003: Tenant/Project Search Scope Isolation

Isolation is enforced at the application layer in `search.py`:
- `filterable_attributes` include `org` and `tenant_uuid`
- Search queries from CMS filter by caller's org membership
- Tenant A cannot see Tenant B's library content via org-scoped queries

**Orgs on platform**: MEREKA, BIJIBIJI, SKILLOURFUTURE — each has separate course org filter enforced at SiteConfiguration level.

---

## AC-LIB-004: Deployment Evidence

```
Meilisearch pod:    meilisearch-778c489564-f65v2  1/1  Running  2d18h
Health:             {"status":"available"}
API key:            present in openedx-secrets (synced from GCP SM MEREKA_LMS_MEILISEARCH_API_KEY)
CMS env wired:      MEILISEARCH_SERVICE_HOST=34.118.236.116
Indexes:            0 (fresh — initialize with ensure_indexes())
```

---

## AC-LIB-005: Rollback Checklist

| Scenario | Action |
|----------|--------|
| Index corruption | Delete index: `curl -X DELETE http://meilisearch:7700/indexes/content_libraries` → re-run `ensure_indexes()` |
| Ingestion failure | Check CMS logs: `kubectl logs -n mereka-lms deployment/cms --tail=50 | grep meilisearch` |
| API key rotation | Update `MEREKA_LMS_MEILISEARCH_API_KEY` in GCP SM → force ExternalSecret refresh → restart CMS |
| Pod crash | `kubectl rollout restart deployment/meilisearch -n mereka-lms` |
| Data persistence loss | Meilisearch uses PVC — check: `kubectl get pvc -n mereka-lms | grep meilisearch` |
