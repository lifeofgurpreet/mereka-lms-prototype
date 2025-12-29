# MongoDB Atlas Migration

**Migration Date:** 2025-12-17
**Status:** Complete

## Overview

MongoDB has been migrated from an in-cluster deployment to MongoDB Atlas for improved reliability, managed backups, and scalability.

## Atlas Cluster Details

| Setting | Value |
|---------|-------|
| Cluster Name | `cluster-mereka-lms` |
| Connection String | `mongodb+srv://cluster-mereka-lms.2pjex4s.mongodb.net` |
| Username | `cs_comments_user` |
| Authentication Source | `admin` |
| SSL | Enabled |

## Databases

| Database | Purpose | Used By |
|----------|---------|---------|
| `openedx` | Course modulestore, contentstore | LMS, CMS, Workers |
| `cs_comments_service` | Discussion forum data | Forum service |

## Configuration Files Updated

### LMS/CMS Settings
- `deploy/k8s/base/apps/openedx/settings/lms/production.py`
- `deploy/k8s/base/apps/openedx/settings/cms/production.py`

Both files contain:
```python
mongodb_parameters = {
    "db": "openedx",
    "host": "mongodb+srv://cluster-mereka-lms.2pjex4s.mongodb.net",
    "port": 27017,
    "user": "cs_comments_user",
    "password": "<password>",
    "connect": False,
    "ssl": True,
    "authsource": "admin",
    "replicaSet": None,
}
```

### Forum Service
- `deploy/k8s/base/deployments.yml`

Environment variables:
```yaml
- name: MONGODB_AUTH
  value: "cs_comments_user:<password>"
- name: MONGODB_HOST
  value: "cluster-mereka-lms.2pjex4s.mongodb.net"
- name: MONGODB_DATABASE
  value: "cs_comments_service"
- name: MONGOID_USE_SSL
  value: "true"
```

## Disabled In-Cluster MongoDB

The following files have been commented out/deprecated:

| File | Contents |
|------|----------|
| `deploy/k8s/base/deployments.yml` | MongoDB deployment (commented) |
| `deploy/k8s/base/services.yml` | MongoDB service (commented) |
| `deploy/k8s/base/volumes.yml` | MongoDB PVC (commented) |
| `infrastructure/k8s/mongodb.yaml` | Deprecated with explanation |

## ArgoCD Considerations

**Important:** ArgoCD selfHeal was disabled to prevent automatic reversion of manual changes:

```bash
kubectl patch application mereka-lms-local -n argocd \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/syncPolicy/automated/selfHeal", "value": false}]'
```

After committing these changes to git, you can re-enable selfHeal if desired.

## Network Access

Ensure the GKE cluster's egress IP addresses are whitelisted in MongoDB Atlas:
- Go to MongoDB Atlas > Network Access
- Add the external IP of your GKE nodes or NAT gateway

## Verification Commands

```bash
# Check LMS MongoDB connection
kubectl exec -n mereka-lms deployment/lms -- python -c "
from django.conf import settings
print('HOST:', settings.DOC_STORE_CONFIG.get('host'))
print('SSL:', settings.DOC_STORE_CONFIG.get('ssl'))
print('USER:', settings.DOC_STORE_CONFIG.get('user'))
"

# Check course count
kubectl exec -n mereka-lms deployment/lms -- python -c "
import pymongo
from django.conf import settings
cfg = settings.DOC_STORE_CONFIG
client = pymongo.MongoClient(
    cfg['host'],
    username=cfg['user'],
    password=cfg['password'],
    tls=cfg.get('ssl', False),
    authSource=cfg.get('authsource', 'admin')
)
db = client['openedx']
print('Courses:', db['modulestore.active_versions'].count_documents({}))
"
```

## Rollback Procedure

If rollback to in-cluster MongoDB is needed:

1. Uncomment the MongoDB sections in:
   - `deploy/k8s/base/deployments.yml`
   - `deploy/k8s/base/services.yml`
   - `deploy/k8s/base/volumes.yml`

2. Update `mongodb_parameters` in production.py files:
   ```python
   mongodb_parameters = {
       "db": "openedx",
       "host": "mongodb",
       "port": 27017,
       "user": None,
       "password": None,
       "connect": False,
       "ssl": False,
       "authsource": "admin",
       "replicaSet": None,
   }
   ```

3. Update forum deployment env vars to point to in-cluster `mongodb`.

4. Apply changes via ArgoCD or kubectl.

## Related Documentation

- [MCT Pre-Migration Inventory](../migrations/mct/MCT_PRE_MIGRATION_INVENTORY.md)
- [Database Architecture](DATABASE_ARCHITECTURE.md)
