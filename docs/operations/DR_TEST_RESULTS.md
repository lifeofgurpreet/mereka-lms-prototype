# Disaster Recovery Test Results

**Date:** 2026-02-03
**Tester:** Claude Agent
**Status:** ✅ PASSED

## Test Summary

| Metric | Value |
|--------|-------|
| Backup Used | `velero-local-daily-all-apps-20260202180005` |
| Backup Age | ~6 hours |
| Restore Time | 7 seconds |
| Data Verified | ✅ Yes |

## Backup Infrastructure

### Velero Schedules Active

| Schedule | Frequency | Last Backup | Status |
|----------|-----------|-------------|--------|
| `velero-local-hourly-critical-databases` | Every hour | Recent | ✅ Active |
| `velero-local-daily-all-apps` | Daily 6PM UTC | Recent | ✅ Active |
| `velero-local-weekly-full` | Weekly Sunday 7PM UTC | Recent | ✅ Active |

### Namespaces Included in Backup

- mereka-lms (LMS/CMS/MFE)
- authentik
- infisical
- n8n
- listmonk
- temporal
- twentycrm
- mereka-dev
- monitoring
- argocd
- cert-manager
- external-secrets
- ingress-nginx

## Test Procedure

### 1. Restore PVC to Test Namespace

```yaml
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: dr-test-mereka-lms-mysql
  namespace: velero
spec:
  backupName: velero-local-daily-all-apps-YYYYMMDDHHMMSS
  includedNamespaces:
    - mereka-lms
  includedResources:
    - persistentvolumeclaims
    - persistentvolumes
  labelSelector:
    matchLabels:
      app.kubernetes.io/name: mysql
  namespaceMapping:
    mereka-lms: mereka-lms-dr-test
  restorePVs: true
```

### 2. Verify Data Integrity

```bash
# Create MySQL pod with restored PVC
kubectl run mysql-dr-verify -n mereka-lms-dr-test \
  --image=mysql:8.4.0 \
  --env="MYSQL_ROOT_PASSWORD=test123" \
  --overrides='{"spec":{"containers":[{"name":"mysql-dr-verify","args":["--skip-grant-tables"],"volumeMounts":[{"name":"data","mountPath":"/var/lib/mysql"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"mysql"}}]}}'

# Query data
kubectl exec -n mereka-lms-dr-test mysql-dr-verify -- \
  mysql -u root -e "SELECT COUNT(*) FROM openedx.auth_user;"
```

### 3. Results

| Check | Result |
|-------|--------|
| PVC Restored | ✅ 5Gi MySQL volume cloned |
| MySQL Started | ✅ Server started successfully |
| Databases Present | ✅ openedx, mysql, sys |
| User Data | ✅ 4 users (staging) |
| Data Readable | ✅ No corruption |

## Recovery Time Objectives

| Scenario | RTO | RPO |
|----------|-----|-----|
| Single PVC failure | ~5 min | 1 hour (hourly backups) |
| Namespace loss | ~15 min | 1 hour |
| Full cluster loss | ~1 hour | 24 hours (daily backups) |

## Restore Procedure (Production)

### Partial Restore (Single Service)

```bash
# 1. Find latest backup
kubectl get backups -n velero | grep daily-all-apps | head -1

# 2. Create restore
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-mysql-$(date +%Y%m%d%H%M)
  namespace: velero
spec:
  backupName: BACKUP_NAME_HERE
  includedNamespaces:
    - mereka-lms
  includedResources:
    - persistentvolumeclaims
    - persistentvolumes
    - deployments
    - services
    - configmaps
    - secrets
  labelSelector:
    matchLabels:
      app.kubernetes.io/name: mysql
  existingResourcePolicy: update
EOF

# 3. Monitor restore
kubectl get restore -n velero -w
```

### Full Namespace Restore

```bash
kubectl apply -f - <<EOF
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-mereka-lms-full-$(date +%Y%m%d%H%M)
  namespace: velero
spec:
  backupName: BACKUP_NAME_HERE
  includedNamespaces:
    - mereka-lms
  existingResourcePolicy: update
EOF
```

## Recommendations

1. **Consider MongoDB Backup**: Currently using in-cluster MongoDB; ensure it's included in backups
2. **Test Full Namespace Restore**: This test only verified PVC restore
3. **Add Backup Verification**: The `backup-verification` jobs should alert on failures
4. **Document Secrets Recovery**: Secrets are backed up but may need rotation after restore

## Next Steps

- [ ] Test full namespace restore (non-production hours)
- [ ] Add MongoDB Atlas backup verification
- [ ] Create runbook for different failure scenarios
- [ ] Set up backup failure alerting
