# Forum Service: Meilisearch Dependency

_Audience: Platform Eng + SRE | Owner: Engineering Lead | Last updated: 2026-02-24_

> **Related**: `docs/ops/runbooks/FORUM_SERVICE_RUNBOOK.md` | `specs/forum-service-migration_spec.md`

---

## Forum Service Overview

The forum runs as **openedx-forum v0.3.8** (Python), integrated directly into the LMS Django process. There is no separate forum container or service. Storage is MongoDB Atlas (`cs_comments_service` database). Search is delegated to Meilisearch.

| Property | Value |
|----------|-------|
| Package | `openedx-forum v0.3.8` |
| Runtime | LMS Django process (no separate pod) |
| Storage | MongoDB Atlas — `cs_comments_service` DB |
| Search backend | Meilisearch v1.8.4 |
| Meilisearch port | 7700 (ClusterIP, in-cluster only) |
| Infisical secret prefix | `MEREKA_LMS_MEILISEARCH_*` |

---

## Meilisearch Dependency

### Version

Meilisearch **v1.8.4** (`docker.io/getmeili/meilisearch:v1.8.4`), deployed as a dedicated pod in the `mereka-lms` namespace.

### Deployment

- K8s Deployment: `deploy/k8s/base/apps/meilisearch/deployment.yaml` (name: `meilisearch`)
- K8s Service: `deploy/k8s/base/apps/meilisearch/service.yaml` (name: `meilisearch`, ClusterIP, port 7700)
- PersistentVolumeClaim: `deploy/k8s/base/volumes.yml` (name: `meilisearch`, 10Gi SSD)

Meilisearch is **required** for forum search. Browse and read operations continue if Meilisearch is unavailable (degraded mode), but all search queries will fail.

---

## Configuration

### Environment Variables

Set in LMS and CMS Django settings (`deploy/k8s/base/apps/openedx/settings/lms/production.py` and `cms/production.py`):

| Variable | Value | Source |
|----------|-------|--------|
| `MEILISEARCH_ENABLED` | `True` | Hardcoded in settings file |
| `MEILISEARCH_URL` | `http://meilisearch:7700` | Hardcoded (K8s service DNS) |
| `MEILISEARCH_INDEX_PREFIX` | `tutor_` | Hardcoded in settings file |
| `MEILISEARCH_API_KEY` | `os.environ.get("MEILISEARCH_API_KEY", "")` | K8s Secret → ExternalSecret |

### Secrets

Both `MEILISEARCH_MASTER_KEY` and `MEILISEARCH_API_KEY` flow through the standard secrets pipeline:

```
Infisical (prod env)
  MEREKA_LMS_MEILISEARCH_MASTER_KEY
  MEREKA_LMS_MEILISEARCH_API_KEY
    → GCP Secret Manager
      → ExternalSecret (deploy/k8s/base/secrets/external-secrets.yaml)
        → K8s Secret: openedx-secrets
          → Pod env vars
```

The `MEILISEARCH_MASTER_KEY` is injected directly into the Meilisearch pod. The `MEILISEARCH_API_KEY` is consumed by LMS and CMS.

---

## Health Check

Verify Meilisearch is running and reachable from within the cluster:

```bash
# 1. Check pod is running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=meilisearch

# 2. Health endpoint (from Meilisearch pod itself)
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" http://localhost:7700/health
# Expected: {"status":"available"}

# 3. List indexes
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" http://localhost:7700/indexes | python3 -m json.tool

# 4. Check forum index document count
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  http://localhost:7700/indexes/tutor_forum_threads/stats
```

**Dev (Kind) — port-forward:**

```bash
kubectl port-forward -n mereka-lms svc/meilisearch 7700:7700
curl -s -H "Authorization: Bearer <dev-api-key>" http://localhost:7700/health
```

---

## Index Management

### Trigger Re-indexing

Re-index all forum content from MongoDB into Meilisearch:

```bash
# Run from LMS pod
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms --settings=tutor.production reindex_forum
```

Re-indexing 183 MB of forum data takes approximately 8 minutes. Search returns empty results (not errors) while indexing is in progress.

### Delete and Rebuild Index

Use when the index is corrupted or stale:

```bash
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)

# 1. Delete the index
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -X DELETE -H "Authorization: Bearer ${MEILI_KEY}" \
  http://localhost:7700/indexes/tutor_forum_threads

# 2. Re-trigger indexing
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms --settings=tutor.production reindex_forum
```

### API Key Rotation

```bash
# 1. Update GCP SM with new key
printf '%s' 'NEW_API_KEY' | gcloud secrets versions add MEREKA_LMS_MEILISEARCH_API_KEY \
  --data-file=- --project=bbi-k8

# 2. Force ExternalSecret refresh
kubectl annotate externalsecret openedx-secrets -n mereka-lms \
  force-sync=$(date +%s) --overwrite

# 3. Restart consumers
kubectl rollout restart deployment/lms -n mereka-lms
kubectl rollout restart deployment/cms -n mereka-lms
kubectl rollout restart deployment/meilisearch -n mereka-lms
```

---

## Troubleshooting

### Connection Refused (`http://meilisearch:7700`)

**Symptom**: Forum search returns 500 or "connection refused" errors in LMS logs.

**Diagnosis**:
```bash
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=meilisearch
kubectl get endpoints -n mereka-lms meilisearch
```

**Cause / Fix**:
- Pod not running → check events: `kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=meilisearch`
- PVC not bound → `kubectl get pvc meilisearch -n mereka-lms`
- Service selector mismatch → run `./scripts/infra/fix-service-selectors.sh`

### Empty Index (Search Returns No Results)

**Symptom**: Forum search UI returns zero results for known queries.

**Diagnosis**:
```bash
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  http://localhost:7700/indexes/tutor_forum_threads/stats
```

**Cause / Fix**: Index was never built or was deleted. Re-index:
```bash
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms --settings=tutor.production reindex_forum
```

### Stale Data (Search Missing Recent Posts)

**Symptom**: Newly created threads do not appear in search results.

**Cause**: Indexing pipeline is delayed or failed.

**Diagnosis**:
```bash
# Check for failed Meilisearch tasks
MEILI_KEY=$(kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d)
kubectl exec -n mereka-lms deployment/meilisearch -- \
  curl -s -H "Authorization: Bearer ${MEILI_KEY}" \
  "http://localhost:7700/tasks?statuses=failed&limit=10"

# Check LMS logs for search errors
kubectl logs -n mereka-lms deployment/lms --tail=100 | grep -i "meilisearch\|search"
```

**Fix**: Trigger a full re-index (see Index Management above).

### Authentication Error (403 from Meilisearch)

**Symptom**: LMS logs show `403 Forbidden` responses from `http://meilisearch:7700`.

**Cause**: `MEILISEARCH_API_KEY` in K8s secret does not match the key configured in Meilisearch, or the ExternalSecret has not synced yet.

**Diagnosis**:
```bash
# Check the key stored in K8s secret
kubectl get secret openedx-secrets -n mereka-lms \
  -o jsonpath='{.data.MEILISEARCH_API_KEY}' | base64 -d

# Check ExternalSecret sync status
kubectl get externalsecret openedx-secrets -n mereka-lms -o yaml | grep -A5 conditions
```

**Fix**: Rotate the key via the API Key Rotation procedure above.

---

## Offline Validation

Run the offline configuration validator (no cluster access required):

```bash
./scripts/qa/verify-forum-meilisearch.sh
```

This checks that:
- Meilisearch Deployment and Service manifests exist
- `MEILISEARCH_URL` and `MEILISEARCH_API_KEY` are present in Django settings
- ExternalSecret mappings reference `MEREKA_LMS_MEILISEARCH_*` keys
- No missing config that would cause forum search to silently fail
