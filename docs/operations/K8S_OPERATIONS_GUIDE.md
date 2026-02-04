# Kubernetes Operations Guide - Mereka LMS

_Audience: Platform Engineers, SREs, Developers_
_Last updated: 2026-02-03_

This guide provides practical commands and procedures for operating the Mereka LMS Kubernetes deployment. Environment model: **production (GKE)** + **dev (kind/VPS)** only; any “staging” wording in commands or buckets is legacy production naming.

---

## 1. Quick Reference

### Cluster Context

```bash
# Set the correct context (GKE cluster)
kubectl config use-context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster

# Verify context
kubectl config current-context

# Set default namespace for session
kubectl config set-context --current --namespace=mereka-lms
```

### Common Commands

```bash
# View all resources in namespace
kubectl get all -n mereka-lms

# Check pod status (most common)
kubectl get pods -n mereka-lms

# Check services and their endpoints
kubectl get svc,endpoints -n mereka-lms

# View pod logs
kubectl logs -n mereka-lms deployment/lms --tail=100
kubectl logs -n mereka-lms deployment/lms -f  # Follow logs

# Execute command in pod
kubectl exec -n mereka-lms deployment/lms -- <command>

# Interactive shell
kubectl exec -it -n mereka-lms deployment/lms -- bash

# Describe a resource (debugging)
kubectl describe pod/<pod-name> -n mereka-lms
kubectl describe deployment/lms -n mereka-lms

# View resource usage
kubectl top pods -n mereka-lms
kubectl top nodes
```

### Quick Diagnostics (5-Command Site-Down Check)

```bash
# 1. Are pods running?
kubectl get pods -n mereka-lms

# 2. Do services have endpoints? (CRITICAL - <none> = no traffic)
kubectl get endpoints -n mereka-lms

# 3. Check service selectors vs pod labels
kubectl get svc -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.selector}{"\n"}{end}'

# 4. LoadBalancer status
kubectl get svc caddy -n mereka-lms

# 5. Test internal connectivity
kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -n mereka-lms -- curl -I http://lms:8000
```

---

## 2. Deployment Procedures

### Directory Structure

```
deploy/k8s/
  base/                    # Base Kustomize configuration
    kustomization.yaml     # Main kustomization file
    deployments.yml        # All deployment definitions
    services.yml           # Service definitions
    volumes.yml            # PVC definitions
    secrets/               # ExternalSecrets configuration
    apps/                  # App-specific configs (Caddy, OpenEdX)
    plugins/               # Plugin configs (MFE, Discovery, etc.)
  overlays/
    local/                 # Local development overrides
    production/            # GKE production (academyv2.mereka.io)
    production/            # Production environment
  patches/                 # Ad-hoc patches
```

### Deploying with Kustomize

```bash
# Preview what will be deployed (dry-run)
kubectl kustomize deploy/k8s/overlays/production

# Deploy to production
kubectl apply -k deploy/k8s/overlays/production

# Deploy to production
kubectl apply -k deploy/k8s/overlays/production

# Deploy only base (development)
kubectl apply -k deploy/k8s/base
```

### Environment-Specific Deployments

| Environment | Overlay Path | Image Tag | Replicas |
|-------------|--------------|-----------|----------|
| Local | `overlays/local` | `latest` | 1 each |
| Production | `overlays/production` | `production` | 1 each |
| Production | `overlays/production` | `production` | LMS: 2, CMS: 1 |

### Deployment Strategies

**Rolling Update (default)**: Zero-downtime deployments
```bash
# Trigger rolling update
kubectl set image deployment/lms lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:new-tag -n mereka-lms

# Watch rollout progress
kubectl rollout status deployment/lms -n mereka-lms

# Rollback if needed
kubectl rollout undo deployment/lms -n mereka-lms

# View rollout history
kubectl rollout history deployment/lms -n mereka-lms
```

**Recreate Strategy** (for stateful services like MySQL, Redis, Elasticsearch):
```bash
# These deployments use strategy: Recreate
# Check current strategy
kubectl get deployment mysql -n mereka-lms -o jsonpath='{.spec.strategy.type}'
```

### Applying Configuration Changes

```bash
# After modifying ConfigMaps or Secrets
kubectl rollout restart deployment/lms -n mereka-lms
kubectl rollout restart deployment/cms -n mereka-lms

# Restart all backend services (recommended order)
for svc in lms cms discovery ecommerce notes xqueue; do
  kubectl rollout restart deployment/$svc -n mereka-lms
done

# Then restart reverse proxy
kubectl rollout restart deployment/caddy -n mereka-lms

# CRITICAL: Always check endpoints after restarts
kubectl get endpoints -n mereka-lms
```

---

## 3. Scaling

### Manual Scaling

```bash
# Scale LMS replicas
kubectl scale deployment/lms --replicas=3 -n mereka-lms

# Scale CMS replicas
kubectl scale deployment/cms --replicas=2 -n mereka-lms

# Scale workers
kubectl scale deployment/lms-worker --replicas=3 -n mereka-lms
kubectl scale deployment/cms-worker --replicas=2 -n mereka-lms
```

### Current Replica Counts by Environment

| Deployment | Local (kind) | Production (GKE) |
|------------|---------------|------------------|
| lms | 1 | 2 |
| cms | 1 | 1 |
| lms-worker | 1 | 2 |
| cms-worker | 1 | 1 |
| mfe | 1 | 1 |
| caddy | 1 | 1 |
| discovery | 1 | 1 |
| ecommerce | 1 | 1 |
| forum | 1 | 1 |

### When to Scale

**Scale UP when:**
- Response times increase (>2s for LMS pages)
- HTTP 502/504 errors appear
- Worker queue backlog grows
- During expected traffic spikes (course launches, enrollment periods)

**Scale DOWN when:**
- Off-peak hours (nights, weekends)
- Cost optimization needed
- Low traffic periods

### View Current Resource Usage

```bash
# Pod resource usage
kubectl top pods -n mereka-lms

# Check resource requests/limits
kubectl get deployment lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

---

## 4. Monitoring and Logs

### Viewing Logs

```bash
# Single deployment logs
kubectl logs -n mereka-lms deployment/lms --tail=100
kubectl logs -n mereka-lms deployment/cms --tail=100

# Follow logs in real-time
kubectl logs -n mereka-lms deployment/lms -f

# Logs from all pods of a deployment
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50

# Previous container logs (if pod restarted)
kubectl logs -n mereka-lms deployment/lms --previous

# Logs with timestamps
kubectl logs -n mereka-lms deployment/lms --timestamps

# Service-specific log checks
kubectl logs -n mereka-lms -l app.kubernetes.io/name=caddy --tail=50 | grep -i error
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50 | grep -i "error\|database\|mysql"
```

### Common Log Patterns to Monitor

| Pattern | Indicates | Action |
|---------|-----------|--------|
| `upstream timed out` | Backend unreachable | Check service endpoints |
| `502 Bad Gateway` | Backend down | Check LMS/CMS pods |
| `504 Gateway Timeout` | Slow backend | Check DB connections, scale up |
| `OperationalError` | Database issue | Check MySQL connectivity |
| `CSRF verification failed` | Missing trusted origins | Update config |
| `ConnectionRefusedError` | Service unavailable | Check pod/service status |
| `OOM killed` | Out of memory | Increase resource limits |

### Health Checks

```bash
# Check pod readiness
kubectl get pods -n mereka-lms -o wide

# Test LMS health endpoint
kubectl exec -n mereka-lms deployment/caddy -- wget -q -O- http://lms:8000/heartbeat

# Test CMS health
kubectl exec -n mereka-lms deployment/caddy -- wget -q -O- http://cms:8000/heartbeat

# External health check
curl -I https://academyv2.mereka.io/heartbeat
```

### Events (Cluster-Level Debugging)

```bash
# Recent events in namespace
kubectl get events -n mereka-lms --sort-by='.lastTimestamp' | tail -20

# Events for specific pod
kubectl describe pod/<pod-name> -n mereka-lms | grep -A 20 "Events:"

# Watch events in real-time
kubectl get events -n mereka-lms --watch
```

---

## 5. Troubleshooting

### Quick Reference

For detailed troubleshooting procedures, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

### Most Common Issues

**Issue 1: Service Has No Endpoints (`<none>`)**
```bash
# Check
kubectl get endpoints -n mereka-lms

# Fix (automated script)
./scripts/infra/fix-service-selectors.sh

# Manual fix for single service
POD_INSTANCE=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.labels.app\.kubernetes\.io/instance}')
kubectl patch svc lms -n mereka-lms --type='json' -p="[{\"op\": \"replace\", \"path\": \"/spec/selector/app.kubernetes.io~1instance\", \"value\": \"$POD_INSTANCE\"}]"
```

**Issue 2: Pods Stuck in CrashLoopBackOff**
```bash
# Check logs
kubectl logs -n mereka-lms <pod-name> --previous

# Common causes:
# - Config errors: Check ConfigMaps
# - Secret missing: Check ExternalSecrets status
# - DB unreachable: Check connectivity

# Restart deployment
kubectl rollout restart deployment/<name> -n mereka-lms
```

**Issue 3: LoadBalancer IP Not Responding**
```bash
# Check Caddy service
kubectl get svc caddy -n mereka-lms

# Verify ports (should include 80 and 443)
kubectl get svc caddy -n mereka-lms -o jsonpath='{.spec.ports[*].port}'

# Add HTTPS port if missing
kubectl patch svc caddy -n mereka-lms --type='json' \
  -p='[{"op": "add", "path": "/spec/ports/-", "value": {"name": "https", "port": 443, "protocol": "TCP", "targetPort": 443}}]'
```

**Issue 4: Database Connection Errors**
```bash
# Test MySQL connectivity from pod
kubectl exec -n mereka-lms deployment/lms -- python -c "import socket; s = socket.socket(); result = s.connect_ex(('mysql', 3306)); print('MySQL reachable' if result == 0 else 'MySQL NOT reachable'); s.close()"

# Check MySQL endpoint
kubectl get endpoints mysql -n mereka-lms
```

### Useful Diagnostic Scripts

```bash
# Fix all service selectors
./scripts/infra/fix-service-selectors.sh

# Repair routing (selectors + HTTPS)
./scripts/infra/repair-routing.sh

# Check cluster status
./scripts/infra/check-cluster-status.sh
```

---

## 6. Secrets Management

### Architecture

```
Infisical (Source of Truth)
    |
    v (sync)
GCP Secret Manager
    |
    v (ExternalSecrets Operator)
Kubernetes Secrets
```

**Infisical path policy**: All `MEREKA_LMS_*` secrets must live under `/k8s/mereka-lms` in both `prod` and `dev` environments. Avoid duplicating them in `/` or other folders.

### ExternalSecrets Pipeline

ExternalSecrets syncs secrets from GCP Secret Manager to Kubernetes:

```bash
# Check ExternalSecrets status
kubectl get externalsecrets -n mereka-lms

# View specific ExternalSecret
kubectl describe externalsecret openedx-secrets -n mereka-lms

# Check if secrets are synced
kubectl get secret openedx-secrets -n mereka-lms
kubectl get secret database-secrets -n mereka-lms

# View ClusterSecretStore
kubectl describe clustersecretstore gcp-secret-manager
```

### Kind (dev) bootstrap

Kind does not support Workload Identity. Use the helper to create the
`external-secrets/gcp-secret-manager` key secret and apply the local
ClusterSecretStore override:

```bash
./scripts/infra/bootstrap-kind-secrets.sh
kubectl get externalsecrets -n mereka-lms
```

### Adding New Secrets

1. **Add to Infisical** (source of truth)

2. **Sync to GCP Secret Manager**:
```bash
# Create secret in GCP SM
gcloud secrets create MEREKA_LMS_NEW_SECRET --project=bbi-k8
gcloud secrets versions add MEREKA_LMS_NEW_SECRET --data-file=- --project=bbi-k8 <<< "secret-value"
```

3. **Add to ExternalSecret manifest** (`deploy/k8s/base/secrets/external-secrets.yaml`):
```yaml
- secretKey: NEW_SECRET
  remoteRef:
    key: MEREKA_LMS_NEW_SECRET
```

4. **Apply changes**:
```bash
kubectl apply -k deploy/k8s/base/secrets
```

### Current Secret Groups

| Secret Name | Contains |
|-------------|----------|
| `openedx-secrets` | Django keys, JWT keys, API keys, OAuth secrets |
| `database-secrets` | MySQL passwords |
| `ses-smtp-credentials` | AWS SES SMTP credentials |

### Manual Secret Operations

```bash
# View secret keys (not values)
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys'

# Decode a secret value
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.OPENEDX_SECRET_KEY}' | base64 -d

# Force ExternalSecret refresh
kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync=$(date +%s) --overwrite
```

### Force ArgoCD refresh (remote base updates)

Remote Kustomize bases can lag until ArgoCD refreshes the Application. Use this helper to
force a refresh after remote base updates (including this repo).

```bash
# List ArgoCD applications
kubectl get applications -n argocd

# Refresh specific apps
ARGO_APPS="mereka-lms-production mereka-lms-local" ./scripts/infra/argocd-refresh.sh

# Optional overrides
ARGO_NAMESPACE=argocd ARGO_REFRESH_TYPE=hard ./scripts/infra/argocd-refresh.sh mereka-lms-production
```

For detailed secrets management architecture, see `/home/gurpreet/projects/secrets-management/specs/`.

---

## 7. Disaster Recovery

### Backup Procedures

#### Database Backups (Cloud SQL)

```bash
# Ad-hoc backup of all databases
./scripts/infra/backup-db.sh

# Backup specific databases only
DATABASES='openedx discovery' ./scripts/infra/backup-db.sh

# Backups are stored at:
# gs://staging-academy-mereka-io-backup/sql/<timestamp>/<database>.sql.gz
# (legacy bucket name; still used for production backups)
```

**Automated Backups**: GitHub workflow runs every 3 days (`.github/workflows/cloud-sql-backup.yml`)

#### MongoDB Backups (Atlas)

MongoDB Atlas handles backups automatically. For manual backup:
```bash
# Use mongodump from a pod
kubectl exec -n mereka-lms deployment/lms -- mongodump \
  --uri="mongodb+srv://openedx:PASSWORD@cluster-mereka-lms.2pjex4s.mongodb.net" \
  --archive=/tmp/mongo-backup.gz --gzip

# Copy backup locally
kubectl cp mereka-lms/<lms-pod>:/tmp/mongo-backup.gz ./mongo-backup.gz
```

#### Persistent Volume Backups

```bash
# List PVCs
kubectl get pvc -n mereka-lms

# Velero backup (if installed)
velero backup create mereka-lms-backup --include-namespaces mereka-lms
```

### Restore Procedures

#### Restore Cloud SQL Database

```bash
# List available backups
gsutil ls gs://staging-academy-mereka-io-backup/sql/  # legacy bucket name for production backups

# Download backup
gsutil cp gs://staging-academy-mereka-io-backup/sql/<timestamp>/openedx.sql.gz /tmp/  # legacy bucket name for production backups

# Import to Cloud SQL
gunzip /tmp/openedx.sql.gz
gcloud sql import sql mereka-lms-mysql /tmp/openedx.sql --database=openedx --project=mereka-lms
```

#### Restore MongoDB (Atlas)

Use Atlas Console for point-in-time recovery or restore from snapshot.

#### Restore PVCs with Velero

```bash
# List available backups
velero backup get

# Restore from backup
velero restore create --from-backup mereka-lms-backup

# Restore specific resources
velero restore create --from-backup mereka-lms-backup --include-resources persistentvolumeclaims
```

### Velero Commands Reference

```bash
# Install Velero (one-time)
velero install \
  --provider gcp \
  --plugins velero/velero-plugin-for-gcp:v1.8.0 \
  --bucket staging-academy-mereka-io-backup \  # legacy bucket name for production backups
  --secret-file ./credentials-velero

# Create backup
velero backup create <backup-name> --include-namespaces mereka-lms

# Create scheduled backup
velero schedule create daily-backup --schedule="0 3 * * *" --include-namespaces mereka-lms

# List backups
velero backup get

# Describe backup
velero backup describe <backup-name>

# View backup logs
velero backup logs <backup-name>

# Restore
velero restore create --from-backup <backup-name>

# Delete old backups
velero backup delete <backup-name>
```

### Recovery Checklist

1. **Assess the damage**: What's affected? (pods, PVCs, database, config)
2. **Stop bleeding**: Scale down affected deployments if needed
3. **Restore data**: From most recent backup
4. **Verify secrets**: Check ExternalSecrets are synced
5. **Restart services**: In correct order (backends -> reverse proxy -> edge)
6. **Verify endpoints**: `kubectl get endpoints -n mereka-lms`
7. **Smoke test**: Run `./scripts/qa/smoke-test.sh`
8. **Monitor**: Watch logs for errors

---

## 8. Database Password Reset

### When to Use

Use this procedure when passwords stored in ExternalSecrets/GCP Secret Manager do not match what MySQL has configured internally. This typically occurs after:
- Manual password changes in MySQL without updating secrets
- Failed secret sync operations
- Migration or restore from backup with different passwords

### Symptoms

- LMS/CMS pods showing error: `Access denied for user 'openedx'@... (using password: YES)`
- Pods crashing with database connection errors
- Application logs showing `OperationalError: (1045, "Access denied for user...")`
- Services unable to start despite secrets appearing correctly configured

### Procedure

```bash
# 1. Enable skip-grant-tables to bypass authentication
kubectl patch deployment mysql -n mereka-lms --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["mysqld", "--skip-grant-tables", "--mysql-native-password=ON", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci"]}]'

# 2. Wait for MySQL to restart with new configuration
kubectl rollout status deployment/mysql -n mereka-lms

# 3. Get the expected passwords from Kubernetes secrets
ROOT_PW=$(kubectl get secret database-secrets -n mereka-lms -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d)
OPENEDX_PW=$(kubectl get secret database-secrets -n mereka-lms -o jsonpath='{.data.OPENEDX_MYSQL_PASSWORD}' | base64 -d)

# 4. Reset passwords in MySQL to match secrets
kubectl exec -n mereka-lms deployment/mysql -- mysql -u root -e "
  FLUSH PRIVILEGES;
  ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ROOT_PW';
  ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$ROOT_PW';
  ALTER USER 'openedx'@'%' IDENTIFIED WITH mysql_native_password BY '$OPENEDX_PW';
  FLUSH PRIVILEGES;"

# 5. Remove skip-grant-tables and restore normal operation
kubectl patch deployment mysql -n mereka-lms --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["mysqld", "--character-set-server=utf8mb4", "--collation-server=utf8mb4_unicode_ci", "--binlog-expire-logs-seconds=259200", "--mysql-native-password=ON"]}]'

# 6. Wait for MySQL to restart with authentication enabled
kubectl rollout status deployment/mysql -n mereka-lms

# 7. Restart LMS/CMS to reconnect with correct credentials
kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
```

### Verification

```bash
# Check LMS/CMS pods are running
kubectl get pods -n mereka-lms -l 'app.kubernetes.io/name in (lms,cms)'

# Verify external access
curl -sI https://academyv2.mereka.io | head -1  # Should be HTTP/2 200

# Check LMS logs for database errors
kubectl logs -n mereka-lms deployment/lms --tail=50 | grep -i "mysql\|database\|error"
```

### Prevention

To avoid password mismatches in the future:

1. **Never directly modify MySQL passwords** without updating the secrets pipeline
2. **Always update secrets in this order**:
   - Infisical (source of truth) first
   - Then GCP Secret Manager (manual sync or automated)
   - Let ExternalSecrets sync to Kubernetes
   - Finally restart affected deployments
3. **Force ExternalSecret refresh** after GCP SM updates:
   ```bash
   kubectl annotate externalsecret database-secrets -n mereka-lms force-sync=$(date +%s) --overwrite
   ```
4. **Verify secrets are synced** before restarting services:
   ```bash
   kubectl get externalsecret database-secrets -n mereka-lms
   # Status should show "SecretSynced"
   ```

---

## 9. Quick Command Reference Card

```bash
# === CONTEXT ===
kubectl config use-context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
kubectl config set-context --current --namespace=mereka-lms

# === STATUS ===
kubectl get pods -n mereka-lms
kubectl get svc,endpoints -n mereka-lms
kubectl get events -n mereka-lms --sort-by='.lastTimestamp' | tail -20

# === LOGS ===
kubectl logs -n mereka-lms deployment/lms --tail=100
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms -f

# === DEPLOY ===
kubectl apply -k deploy/k8s/overlays/production
kubectl rollout restart deployment/lms -n mereka-lms
kubectl rollout status deployment/lms -n mereka-lms
kubectl rollout undo deployment/lms -n mereka-lms

# === SCALE ===
kubectl scale deployment/lms --replicas=3 -n mereka-lms

# === DEBUG ===
kubectl exec -it -n mereka-lms deployment/lms -- bash
kubectl describe pod/<pod-name> -n mereka-lms

# === FIX ===
./scripts/infra/fix-service-selectors.sh

# === BACKUP ===
./scripts/infra/backup-db.sh
```

---

## Related Documentation

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Detailed troubleshooting procedures
- [DEPLOYMENT_RUNBOOK.md](./DEPLOYMENT_RUNBOOK.md) - Full deployment procedures
- [../ACCESS_URLS.md](../ACCESS_URLS.md) - Service URLs and access info
- `/home/gurpreet/projects/secrets-management/specs/` - Secrets architecture
