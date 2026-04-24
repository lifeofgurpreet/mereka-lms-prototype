# MongoDB Atlas Permissions Issue
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

<!-- Last verified: 2026-02-13 -->

## Issue Summary

**Date Identified**: 2026-02-03
**Status**: Resolved

## Important Context (Hybrid Reality)

This issue only affects **LMS/CMS modulestore** if (and only if) modulestore is configured to use
**MongoDB Atlas**.

Today:
- **Forum** uses **Atlas** (`cs_comments_service`) regardless.
- **LMS/CMS modulestore** may still be using **in-cluster MongoDB** unless `MONGODB_HOST` (or the
  rendered `CONTENTSTORE['DOC_STORE_CONFIG']['host']`) points at Atlas.

Before applying any Atlas-permissions fix, confirm where modulestore is pointing:
```bash
kubectl exec -n mereka-lms deploy/lms -- python /openedx/edx-platform/manage.py lms shell -c \
"from django.conf import settings; \
cfg=settings.CONTENTSTORE.get('DOC_STORE_CONFIG', {}); \
print('DOC_STORE_HOST', cfg.get('host')); \
print('DOC_STORE_DB', cfg.get('db'));"
```

## Problem

The MongoDB Atlas user `cs_comments_user` currently lacks write permissions to the `openedx.modulestore.structures` collection, preventing:
- Importing demo courses via Django management commands
- Creating courses programmatically
- Bulk course operations

### Error Message

```
pymongo.errors.OperationFailure: user is not allowed to do action [insert] on [openedx.modulestore.structures],
full error: {'ok': 0, 'errmsg': 'user is not allowed to do action [insert] on [openedx.modulestore.structures]',
'code': 8000, 'codeName': 'AtlasError'}
```

### Current Configuration

```yaml
MongoDB Cluster: cluster-mereka-lms.2pjex4s.mongodb.net
Database: openedx
User: `MEREKA_LMS_MONGODB_USERNAME` (currently `cs_comments_user`)
Password: stored in Infisical as `MEREKA_LMS_MONGODB_PASSWORD`
```

## Root Cause

The `cs_comments_user` was originally created for the forum service (`cs_comments_service` database) and does not have full read/write permissions on the `openedx` database collections, specifically:
- `openedx.modulestore.structures`
- `openedx.modulestore.definitions` (likely affected too)

## Required Fix

### Option 1: Grant Additional Permissions (Recommended)

Update the `cs_comments_user` permissions in MongoDB Atlas to include:

```json
{
  "role": "readWrite",
  "db": "openedx"
}
```

Or create a new dedicated user for Open edX with full `readWrite` permissions on the `openedx` database.

If you are provisioning via `scripts/infra/provision-atlas-cluster.sh`, the script now grants
`readWrite` on both `cs_comments_service` and `openedx` by default (override with `OPENEDX_DATABASE`
if needed).

To avoid interactive Atlas login, configure the CLI from Infisical first:
```bash
./scripts/infra/atlas-config-from-infisical.sh
```

### Option 2: Create Dedicated Open edX User

Create a new MongoDB user specifically for Open edX operations:

```javascript
// In MongoDB Atlas or via mongosh
db.getSiblingDB("admin").createUser({
  user: "openedx_admin",
  pwd: "<secure-password>",
  roles: [
    { role: "readWrite", db: "openedx" },
    { role: "readWrite", db: "cs_comments_service" }
  ]
})
```

Then update the connection string in:
1. Infisical: Update `MEREKA_LMS_MONGODB_USERNAME` + `MEREKA_LMS_MONGODB_PASSWORD`
2. ExternalSecrets: Ensure `MONGODB_USERNAME` mapping exists
3. Open edX settings: use `MONGODB_USERNAME` in LMS/CMS production config

## Workaround

Until MongoDB permissions are fixed, courses must be created through:
1. **Studio UI** (https://studio.academyv2.mereka.io) - Web-based course authoring
2. **Manual import after fixing permissions** - Fix permissions, then run:
   ```bash
   kubectl exec -n mereka-lms <cms-pod> -- \
     python manage.py cms import /tmp/openedx-demo-course demo-course/course
   ```

## Testing Permissions

To verify permissions are fixed, run:

```bash
kubectl exec -n mereka-lms deploy/cms -- python /openedx/edx-platform/manage.py cms shell -c "
from pymongo import MongoClient
from django.conf import settings
import os

mongo_config = settings.CONTENTSTORE['DOC_STORE_CONFIG']
client = MongoClient(mongo_config['host'],
                     username=mongo_config['user'],
                     password=mongo_config['password'],
                     authSource='admin')

db = client['openedx']
try:
    # Test insert
    result = db['modulestore.structures'].insert_one({'test': 'document'})
    print(f'✓ Write permission OK: {result.inserted_id}')
    # Clean up test doc
    db['modulestore.structures'].delete_one({'_id': result.inserted_id})
    print('✓ Delete permission OK')
except Exception as e:
    print(f'✗ Permission error: {e}')
"
```

## Impact

- **High Impact**: Cannot import demo courses programmatically
- **Medium Impact**: Cannot use Tutor's `importdemocourse` job
- **Workaround Available**: Manual course creation via Studio UI works fine

## Related Files

- `deploy/k8s/base/secrets/external-secrets.yaml` - Secret mappings
- `docs/adr/historical/001-mongodb-atlas.md` - MongoDB Atlas decision record

## Action Items

- [ ] Access MongoDB Atlas console
- [ ] Update `cs_comments_user` permissions or create new user
- [ ] Update Infisical secrets if new user created
- [ ] Update ExternalSecret mappings if needed
- [ ] Test permissions with verification script above
- [ ] Re-run demo course import
- [ ] Update this document when resolved

## Resolution

**Status**: RESOLVED  
**Date Resolved**: 2026-02-05  
**Resolved By**: Atlas API keys + CLI automation  
**Solution Applied**:
- Updated `cs_comments_user` to include `readWrite` on both `cs_comments_service` and `openedx` using Atlas CLI.
- Verified write access by inserting/deleting a test document in `openedx.modulestore.structures`.

**Command used**:
```bash
atlas dbusers update cs_comments_user \
  --authDB admin \
  --projectId 690e7c787757f4238efc94d1 \
  --role readWrite@cs_comments_service \
  --role readWrite@openedx \
  -P mereka-lms
```
