# Mereka-LMS Migration to BBI-K8

This document outlines the migration of mereka-lms (OpenEdX) from its standalone GCloud project to the BBI-K8 cluster.

## Overview

**Source Environment:**
- GKE Autopilot cluster in `mereka-lms` GCloud project
- Cloud SQL (MySQL 8) at private IP 10.97.0.2
- MongoDB Atlas (external service)
- Memorystore (Redis)

**Target Environment:**
- BBI-K8 GKE cluster (shared infrastructure)
- In-cluster MySQL pod
- In-cluster MongoDB pod
- In-cluster Redis pod

## Pre-Migration Checklist

- [ ] Verify BBI-K8 cluster has sufficient resources (~12Gi RAM)
- [ ] Create PVCs for MySQL, MongoDB, Redis, Elasticsearch in BBI-K8
- [ ] Set up backup of source databases
- [ ] Schedule maintenance window (expect 1-2 hours downtime)
- [ ] Notify users of scheduled maintenance

## Database Migration

### 1. MySQL Migration (Cloud SQL → In-cluster)

**Databases to migrate:**
- `openedx` - Main LMS/CMS data (users, courses, enrollments, grades)
- `discovery` - Course catalog service
- `notes` - Student notes
- `ecommerce` - E-commerce transactions
- `xqueue` - External grader queue

**Export from Cloud SQL:**
```bash
# Connect to current GKE cluster
gcloud container clusters get-credentials mereka-lms --zone asia-southeast1 --project mereka-lms

# Port forward to Cloud SQL proxy or use direct connection
# Get the root password from secrets
kubectl get secret -n mereka-lms mysql-credentials -o jsonpath='{.data.password}' | base64 -d

# Export all databases
mysqldump -h 10.97.0.2 -u root -p --all-databases --single-transaction --routines --triggers > openedx-full-dump.sql

# Or export individually for selective restore:
mysqldump -h 10.97.0.2 -u root -p openedx --single-transaction > openedx-db.sql
mysqldump -h 10.97.0.2 -u root -p discovery --single-transaction > discovery-db.sql
mysqldump -h 10.97.0.2 -u root -p notes --single-transaction > notes-db.sql
mysqldump -h 10.97.0.2 -u root -p ecommerce --single-transaction > ecommerce-db.sql
```

**Import to BBI-K8 MySQL:**
```bash
# Switch to BBI-K8 cluster
kubectl config use-context <bbi-k8-context>

# Copy dump to MySQL pod
kubectl cp openedx-full-dump.sql mereka-lms/mysql-0:/tmp/

# Import
kubectl exec -n mereka-lms mysql-0 -- mysql -u root -p < /tmp/openedx-full-dump.sql
```

### 2. MongoDB Migration (Atlas → In-cluster)

**Databases to migrate:**
- `edxapp` - Course structure, modulestore
- `cs_comments_service` - Forum discussions

**Export from MongoDB Atlas:**
```bash
# Get Atlas connection string from tutor config
MONGO_URI=$(grep MONGODB_URI tutor_env/config.yml)

# Export using mongodump
mongodump --uri="$MONGO_URI" --out=/tmp/mongodb-backup/

# Specifically export the needed databases
mongodump --uri="$MONGO_URI" --db=edxapp --out=/tmp/mongodb-backup/
mongodump --uri="$MONGO_URI" --db=cs_comments_service --out=/tmp/mongodb-backup/
```

**Import to BBI-K8 MongoDB:**
```bash
# Copy to pod
kubectl cp /tmp/mongodb-backup/ mereka-lms/mongodb-0:/tmp/

# Restore
kubectl exec -n mereka-lms mongodb-0 -- mongorestore /tmp/mongodb-backup/
```

### 3. Redis (No Migration Needed)

Redis data is transient (session cache, celery broker). No migration required - the new Redis will start fresh and caches will rebuild.

### 4. Elasticsearch (Reindex)

Elasticsearch indexes can be rebuilt from MySQL data. After migration:
```bash
kubectl exec -n mereka-lms -it $(kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o name) -- \
  ./manage.py lms reindex_course --setup --all
```

## Storage Migration

**GCS Bucket Migration:**
Current bucket: `staging-academy-mereka-io-content`

Option A: Keep using existing GCS bucket (recommended)
- Add service account to BBI-K8 with access to the bucket
- No content migration needed

Option B: Copy to new bucket
```bash
gsutil -m cp -r gs://staging-academy-mereka-io-content gs://new-bucket-name
```

## Configuration Changes

### Secrets to Create in BBI-K8

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mereka-lms-secrets
  namespace: mereka-lms
type: Opaque
stringData:
  MYSQL_ROOT_PASSWORD: "<generate-new>"
  OPENEDX_SECRET_KEY: "<from-current-config>"
  OPENEDX_ID_JWT_SECRET_KEY: "<from-current-config>"
  SOCIAL_AUTH_GOOGLE_OAUTH2_KEY: "<from-current-config>"
  SOCIAL_AUTH_GOOGLE_OAUTH2_SECRET: "<from-current-config>"
```

### DNS Changes

After migration, update DNS records:
| Domain | Old IP (Cloud SQL LB) | New IP (BBI-K8 Ingress) |
|--------|----------------------|-------------------------|
| academyv2.mereka.io | 34.126.186.80 | <BBI-K8-ingress-IP> |
| studio.academyv2.mereka.io | 34.126.186.80 | <BBI-K8-ingress-IP> |
| apps.academyv2.mereka.io | 34.126.186.80 | <BBI-K8-ingress-IP> |

## Migration Steps

### Phase 1: Preparation (No Downtime)
1. Deploy mereka-lms to BBI-K8 with empty databases
2. Verify all pods come up healthy
3. Test with `kubectl port-forward`
4. Create backup of production databases

### Phase 2: Data Migration (Scheduled Downtime)
1. Enable maintenance mode on current LMS
2. Take final database dumps
3. Import to BBI-K8 databases
4. Update DNS to point to BBI-K8
5. Verify site functionality

### Phase 3: Cutover Verification
1. Test user login
2. Test course access
3. Test Studio (course authoring)
4. Test MFE microfrontends
5. Test forum access
6. Run smoke tests: `make qa-smoke`

### Phase 4: Cleanup
1. Keep old cluster running for 1 week (rollback safety)
2. Monitor for any issues
3. Decommission old GKE cluster
4. Delete Cloud SQL instance (after confirming no data loss)

## Rollback Plan

If issues occur during migration:
1. Revert DNS to old IP
2. Data is still in old Cloud SQL
3. Old cluster remains functional

## Post-Migration Tasks

- [ ] Update CI/CD pipelines to deploy to BBI-K8
- [ ] Update monitoring/alerting
- [ ] Update backup schedules
- [ ] Remove old infrastructure (after validation period)
- [ ] Update documentation

## Estimated Timeline

| Phase | Duration |
|-------|----------|
| Preparation | 1-2 days |
| Data Migration | 1-2 hours |
| Verification | 1-2 hours |
| Monitoring Period | 1 week |
| Cleanup | 1 day |

## Contacts

- Platform Team: (contact info)
- On-call: (contact info)
