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
kubectl set image deployment/lms lms=ghcr.io/biji-biji-initiative/mereka-lms/openedx:new-tag -n mereka-lms

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

For detailed troubleshooting procedures, see [TROUBLESHOOTING.md](../../operations/TROUBLESHOOTING.md).

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

If secrets are scattered across root paths, run:
```bash
./scripts/infra/infisical-sync-mereka-lms.sh prod
./scripts/infra/infisical-sync-mereka-lms.sh dev
```

Full key inventory: `docs/ops/security/INFISICAL_MEREKA_LMS_KEYS.md`.

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

# Never print secret values to your terminal logs. If you need to debug, prefer
# non-sensitive checks like length/endswith-newline.
kubectl exec -n mereka-lms deploy/lms -- python - <<'PY'
import os
v=os.environ.get("OPENEDX_MYSQL_PASSWORD","")
print("len", len(v))
print("endswith_newline", v.endswith("\\n") or v.endswith("\\r"))
PY

# Force ExternalSecret refresh
kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync=$(date +%s) --overwrite
```

### Force ArgoCD refresh (remote base updates)

Remote Kustomize bases can lag until ArgoCD refreshes the Application. Use this helper to
force a refresh after remote base updates (including this repo).

```bash
# List ArgoCD applications
kubectl get applications -n argocd

# Refresh specific apps (current production uses `mereka-lms-local`)
ARGO_APPS="mereka-lms-local" ./scripts/infra/argocd-refresh.sh

# Optional overrides
ARGO_NAMESPACE=argocd ARGO_REFRESH_TYPE=hard ./scripts/infra/argocd-refresh.sh mereka-lms-local
```

For detailed secrets management architecture, see `/home/gurpreet/projects/secrets-management/specs/`.

### Bump Production GitOps Base Ref (Required After App Repo Changes)

Production is ArgoCD-managed from `Biji-Biji-Initiative/BBI-K8` (legacy docs may still reference `infrastructure`), and it pins this repo
as a remote Kustomize base.

When you change anything under `deploy/k8s/base/` in this repo, you must bump the pinned ref:

1. In `mereka-lms`, get the full commit SHA:
   ```bash
   cd /home/gurpreet/projects/k8s/mereka-lms
   git rev-parse HEAD
   ```
2. In the active GitOps repo (`BBI-K8`), update:
   - `apps/mereka-lms/base/kustomization.yaml`
3. Commit + push to `BBI-K8` (or mirrored remote in your environment).
4. Force Argo refresh if needed:
   ```bash
   kubectl annotate application mereka-lms-local -n argocd argocd.argoproj.io/refresh=hard --overwrite
   ```

Gotcha:
- Always use the full 40-char SHA. Short SHAs can produce Argo `ComparisonError` with `not our ref <sha>`.

---

## 7. Disaster Recovery

### Backup Procedures

#### Database Backups (Production Reality: In-Cluster PVCs)

```bash
# Production MySQL/Redis are PVC-backed. Backups are Velero-driven.
# Use the audit script to verify schedules/recency/coverage:
./scripts/qa/audit-velero.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster

# Before any risky operation: create a pre-op Velero backup (data protection rule)
velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) --include-namespaces mereka-lms --wait
```

**Legacy note**: `.github/workflows/cloud-sql-backup.yml` is gated (disabled unless `ENABLE_CLOUD_SQL_BACKUPS=true`) and only relevant if/when MySQL runs in Cloud SQL again.

#### MongoDB Backups (Atlas)

MongoDB Atlas handles backups automatically. For manual backup:
```bash
# Use mongodump from a pod (never paste passwords into shell history).
# Prefer a pre-provisioned URI via environment variable or a securely retrieved value.
kubectl exec -n mereka-lms deployment/lms -- mongodump \
  --uri="$ATLAS_URI" \
  --archive=/tmp/mongo-backup.gz --gzip

# Copy backup locally
kubectl cp mereka-lms/<lms-pod>:/tmp/mongo-backup.gz ./mongo-backup.gz
```

#### Persistent Volume Backups

```bash
# List PVCs
kubectl get pvc -n mereka-lms

# Velero backup (preferred)
velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) --include-namespaces mereka-lms --wait

# If velero CLI is not installed, create a Backup CR instead:
name=pre-op-mereka-lms-$(date +%Y%m%d-%H%M)
cat > /tmp/$name.yaml <<YAML
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: $name
  namespace: velero
spec:
  includedNamespaces:
    - mereka-lms
  ttl: 720h0m0s
YAML
kubectl apply -f /tmp/$name.yaml
kubectl -n velero get backup $name -o jsonpath='{.status.phase}{"\n"}'
```

### Restore Procedures

#### Restore PVCs with Velero (MySQL/Redis/Elasticsearch)

```bash
# List available backups
velero backup get

# Restore from backup (creates restore object)
velero restore create --from-backup <backup-name>

# Watch restore progress
velero restore get
velero restore describe <restore-name>
```

#### Restore MongoDB (Atlas)

Use Atlas Console for point-in-time recovery or restore from snapshot.

Note: production modulestore/forum traffic is Atlas-backed. Legacy in-cluster MongoDB deployment has been retired; keep the production overlay patch that deletes `Service/mongodb` so this path cannot reappear silently (see `docs/concepts/architecture/ARCHITECTURE_MONGODB.md`).

### Velero Commands Reference

```bash
# Velero is GitOps-managed in production (outside this repo). Do not reinstall it ad-hoc.

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
# 1) Normalize upstream secrets (removes trailing CR/LF so restarts can't regress)
./scripts/infra/normalize-mysql-secrets.sh
APPLY=1 ./scripts/infra/normalize-mysql-secrets.sh

# 2) Align MySQL users to match current K8s secrets (non-destructive; no value printing)
./scripts/infra/repair-gke-mysql-users.sh

# 3) Restart affected services to re-read env vars / configmaps
kubectl rollout restart -n mereka-lms deploy/lms deploy/lms-worker deploy/cms deploy/cms-worker
kubectl rollout restart -n mereka-lms deploy/notes deploy/xqueue
```

**Last resort only:** If you cannot authenticate as MySQL root and `repair-gke-mysql-users.sh` fails,
you may need a maintenance window to run MySQL with `--skip-grant-tables`. Treat that as a security
incident and require a pre-op Velero backup plus explicit review.

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
./scripts/qa/audit-velero.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
velero backup create pre-op-mereka-lms-$(date +%Y%m%d-%H%M) --include-namespaces mereka-lms --wait
```

---

## 10. Observability Integration

### ServiceMonitors

**Purpose**: Prometheus scrape configs for metrics collection via Prometheus Operator.

**Current ServiceMonitors**:
- `servicemonitor-lms.yaml` - LMS metrics (port 8000, `/metrics`)
- `servicemonitor-cms.yaml` - CMS metrics (port 8000, `/metrics`)
- `servicemonitor-mysql.yaml` - MySQL exporter sidecar (port 9104)
- `servicemonitor-redis.yaml` - Redis exporter sidecar (port 9121)

**View ServiceMonitors**:
```bash
kubectl get servicemonitors -n mereka-lms

kubectl describe servicemonitor servicemonitor-lms -n mereka-lms
```

**Verify metrics are being scraped**:
```bash
# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets
# Look for mereka-lms/servicemonitor-* entries with status "UP"
```

**ServiceMonitor requirements** (per spec):
- ✅ Must use label selector matching Service labels
- ✅ Must define `endpoints` with port name and path
- ✅ Must set `interval: 30s` for scrape frequency
- ✅ Must carry label `app.kubernetes.io/component: monitoring`

**Example ServiceMonitor** (LMS):
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: servicemonitor-lms
  namespace: mereka-lms
  labels:
    app.kubernetes.io/component: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: lms
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### PrometheusRules

**Purpose**: Alerting rules for Open edX platform health.

**Current rules**:
- `OpenEdxSyntheticOrBackupJobFailures` - Critical alert for CronJob failures (synthetic tests, backups)
- `OpenEdxHighMemoryUsage` - Warning when pod memory > 90%
- `OpenEdxHighCPU` - Warning when pod CPU > 80%
- `OpenEdxPodCrashLooping` - Critical alert for CrashLoopBackOff
- `OpenEdxServiceDown` - Critical alert when service endpoints = 0

**View PrometheusRules**:
```bash
kubectl get prometheusrules -n mereka-lms

kubectl get prometheusrule openedx-alerts -n mereka-lms -o yaml
```

**Check active alerts**:
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/alerts
# Look for mereka-lms alerts
```

**Testing alerts** (safe in dev):
```bash
# Trigger high memory alert (Kind only!)
kubectl run memory-hog --image=polinux/stress --rm -i -n mereka-lms --restart=Never -- \
  stress --vm 1 --vm-bytes 256M --timeout 60s

# Trigger CrashLoopBackOff (Kind only!)
kubectl run crash-test --image=busybox --rm -i -n mereka-lms --restart=Always -- sh -c 'exit 1'

# Clean up
kubectl delete pod memory-hog crash-test -n mereka-lms --ignore-not-found
```

**Alert routing** (per spec):
- Critical alerts → PagerDuty + Slack #alerts channel
- Warning alerts → Slack #alerts channel only
- Verify routing: `./scripts/qa/verify-alert-routing.sh`

---

## 11. Image Management

### Artifact Registry

**Registry**: `ghcr.io/biji-biji-initiative/mereka-lms`

**Images**:
- `openedx:latest` - LMS/CMS/workers (dev builds)
- `openedx:production` - LMS/CMS/workers (production tag)
- `openedx:<git-sha>` - Immutable commit-tagged builds
- `openedx-mfe:latest` - Micro-frontends (dev)
- `openedx-mfe:production` - Micro-frontends (production)

**View images**:
```bash
# List all tags for openedx image
gcloud artifacts docker tags list \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx

# Get digest for specific tag
gcloud artifacts docker images describe \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx:production
```

### Tagging Strategy

**Local dev** (`overlays/local`):
- Uses `latest` tag for rapid iteration
- Build locally: `tutor images build openedx`
- Load to Kind: `./scripts/infra/kind-load-openedx-image.sh`

**Production** (`overlays/production`):
- Uses `production` tag for releases
- Tagged by CI/CD: `.github/workflows/build-tutor-images.yml`
- Includes git SHA in image labels for traceability

**Kustomize image overrides**:
```yaml
# deploy/k8s/overlays/production/kustomization.yaml
images:
  - name: overhangio/openedx
    newName: ghcr.io/biji-biji-initiative/mereka-lms/openedx
    newTag: production  # Or specific git SHA for rollback
  - name: overhangio/openedx-mfe
    newName: ghcr.io/biji-biji-initiative/mereka-lms/mfe
    newTag: production
```

### Updating Images

**Update to new git SHA** (immutable deploy):
```bash
# 1. Build and push new image (CI/CD does this)
# Resulting tag: openedx:abc123def (git SHA)

# 2. Update production kustomization
cd deploy/k8s/overlays/production
# Edit kustomization.yaml: newTag: abc123def

# 3. Verify render
kubectl kustomize . | grep "image:" | grep openedx

# 4. Deploy
kubectl apply -k .

# 5. Watch rollout
kubectl rollout status deployment/lms -n mereka-lms
kubectl rollout status deployment/cms -n mereka-lms
```

**Quick production tag update** (via script):
```bash
# Updates production overlay to use latest production-tagged image
./scripts/infra/release-openedx-gitops.sh
```

**Rollback to previous image**:
```bash
# Check rollout history for previous image
kubectl rollout history deployment/lms -n mereka-lms

# Rollback (uses previous ReplicaSet)
kubectl rollout undo deployment/lms -n mereka-lms

# Or explicit image rollback
kubectl set image deployment/lms lms=ghcr.io/biji-biji-initiative/mereka-lms/openedx:previous-sha -n mereka-lms
```

### Image Pull Secrets (if needed)

**Current**: GKE nodes have built-in Artifact Registry access (Workload Identity).

**For external clusters** (Kind, other K8s):
```bash
# Create pull secret
kubectl create secret docker-registry gcr-pull-secret \
  --docker-server=asia-southeast1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat gcp-service-account-key.json)" \
  -n mereka-lms

# Add to deployment spec
spec:
  template:
    spec:
      imagePullSecrets:
        - name: gcr-pull-secret
```

---

## 12. Security and Resource Management

### Security Contexts

**Requirements** (per spec):

**Application workloads** (LMS, CMS, workers, Discovery, Ecommerce, etc.):
```yaml
securityContext:
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
  fsGroupChangePolicy: "OnRootMismatch"
  allowPrivilegeEscalation: false
```

**MySQL**:
```yaml
securityContext:
  runAsUser: 999
  runAsGroup: 999
  fsGroup: 999
  fsGroupChangePolicy: "OnRootMismatch"
  allowPrivilegeEscalation: false
```

**SMTP (Exim)**:
```yaml
securityContext:
  runAsUser: 100
  runAsGroup: 101
  allowPrivilegeEscalation: false
```

**Verify security contexts**:
```bash
# Check LMS pod security context
kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].spec.securityContext}'

# Check container-level security context
kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].spec.containers[0].securityContext}'

# Verify no privilege escalation
kubectl get deploy -n mereka-lms -o json | jq '.items[].spec.template.spec.containers[].securityContext.allowPrivilegeEscalation' | sort -u
# Should output: false or null (null inherits from PodSecurityContext)
```

### Resource Limits

**Current limits** (production):

| Workload | CPU Request | CPU Limit | Memory Request | Memory Limit |
|----------|-------------|-----------|----------------|--------------|
| lms | 1000m | 2000m | 2Gi | 4Gi |
| cms | 500m | 1000m | 1Gi | 2Gi |
| lms-worker | 500m | 1000m | 1Gi | 2Gi |
| cms-worker | 500m | 1000m | 1Gi | 2Gi |
| mysql | 1000m | 2000m | 2Gi | 4Gi |
| redis | 500m | 1000m | 1Gi | 2Gi |
| elasticsearch | 1000m | 2000m | 2Gi | 4Gi |

**View current resource usage**:
```bash
# Pod-level usage
kubectl top pods -n mereka-lms

# Node-level usage
kubectl top nodes

# Detailed resource requests/limits
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Update resource limits**:
```bash
# Edit deployment
kubectl edit deployment lms -n mereka-lms

# Or patch
kubectl patch deployment lms -n mereka-lms --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/resources/limits/memory",
    "value": "5Gi"
  }
]'

# Verify
kubectl get deployment lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

**OOMKilled debugging**:
```bash
# Check for OOMKilled events
kubectl get events -n mereka-lms --field-selector reason=OOMKilling

# Check pod status
kubectl get pods -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].lastState.terminated.reason}{"\n"}{end}' | grep OOMKilled

# View memory usage before restart
kubectl logs -n mereka-lms <pod-name> --previous | tail -100
```

**Resource quota** (namespace-level - not currently enabled):
```yaml
# Future enhancement if needed
apiVersion: v1
kind: ResourceQuota
metadata:
  name: mereka-lms-quota
  namespace: mereka-lms
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
```

### Health Checks

**Liveness probes** (restart unhealthy containers):
```yaml
livenessProbe:
  httpGet:
    path: /heartbeat
    port: 8000
  initialDelaySeconds: 120
  periodSeconds: 30
  timeoutSeconds: 10
  failureThreshold: 3
```

**Readiness probes** (remove from load balancer when unhealthy):
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 60
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Verify health checks**:
```bash
# Check liveness probe configuration
kubectl get deployment lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'

# Check readiness probe configuration
kubectl get deployment lms -n mereka-lms -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'

# View probe failures in events
kubectl get events -n mereka-lms --field-selector reason=Unhealthy

# Test health endpoint manually
kubectl exec -it -n mereka-lms deployment/lms -- curl -I http://localhost:8000/health
```

**Common probe failures**:
- `Liveness probe failed` → Container restarted (check logs: `kubectl logs <pod> --previous`)
- `Readiness probe failed` → Pod removed from service endpoints (check: `kubectl get endpoints -n mereka-lms`)
- Probe timeout → Increase `timeoutSeconds` or investigate slow responses

---

## Related Documentation

- **Specs**: `specs/k8s-deployment_spec.md` - Complete K8s deployment specification (32 ACs)
- **Operations**:
  - [TROUBLESHOOTING.md](../../operations/TROUBLESHOOTING.md) - Detailed troubleshooting procedures
  - [DEPLOYMENT_RUNBOOK.md](../../ops/runbooks/DEPLOYMENT_RUNBOOK.md) - Full deployment procedures
  - [SECRETS_MANAGEMENT_GUIDE.md](./SECRETS_MANAGEMENT_GUIDE.md) - Secrets pipeline and rotation
  - [access-urls.md](../../ops/quickref/access-urls.md) - Service URLs and access info
- **Scripts**:
  - `scripts/infra/release-openedx-gitops.sh` - GitOps image promotion
  - `scripts/infra/fix-service-selectors.sh` - Fix service selector mismatches
  - `scripts/qa/verify-k8s-deployment-spec.sh` - Verify spec compliance
