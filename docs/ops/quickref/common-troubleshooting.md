# Common Troubleshooting - Mereka LMS

One-page troubleshooting guide for common issues.

---

## Site Down

### 5-Command Diagnostic

```bash
# 1. Are pods running?
kubectl get pods -n mereka-lms

# 2. Do services have endpoints? (CRITICAL - <none> = no traffic)
kubectl get endpoints -n mereka-lms

# 3. Check LoadBalancer
kubectl get svc caddy -n mereka-lms

# 4. Check pod logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50

# 5. Test internal connectivity
kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -n mereka-lms \
  -- curl -I http://lms:8000
```

### Most Common Fix: Service Selector Mismatch

**Symptom**: `kubectl get endpoints` shows `<none>` for services

**Cause**: After pod restart, service selectors don't match new pod labels

**Fix**:
```bash
./scripts/infra/fix-service-selectors.sh
```

**Manual fix**:
```bash
# Check mismatch
kubectl get svc lms -n mereka-lms -o jsonpath='{.spec.selector}'
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms --show-labels

# Patch service selector
kubectl patch svc lms -n mereka-lms -p '{"spec":{"selector":{"app.kubernetes.io/instance":"new-instance-id"}}}'

# Verify endpoints populated
kubectl get endpoints lms -n mereka-lms
```

---

## Performance Issues

### Quick Checks

```bash
# 1. Check resource usage
kubectl top pods -n mereka-lms
kubectl top nodes

# 2. Check pod count
kubectl get pods -n mereka-lms | grep -c lms

# 3. Check for restarts (OOM, crash loops)
kubectl get pods -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# 4. Check database connections
kubectl exec -n mereka-lms deployment/lms -- sh -c \
  'python manage.py lms dbshell -c "SHOW PROCESSLIST;"'

# 5. Check Redis memory
kubectl exec -n mereka-lms deployment/redis -- redis-cli INFO memory
```

### Common Fixes

**High CPU (LMS/CMS)**:
```bash
# Scale up replicas
kubectl scale deployment/lms --replicas=3 -n mereka-lms

# Check slow queries
kubectl logs -n mereka-lms deployment/lms --tail=100 | grep -i "slow query"
```

**High Memory (LMS/CMS)**:
```bash
# Check for memory leak
kubectl exec -n mereka-lms deployment/lms -- python -c \
  "import gc; gc.collect(); print(len(gc.get_objects()))"

# Restart deployment (clears memory)
kubectl rollout restart deployment/lms -n mereka-lms
```

**High Memory (Redis)**:
```bash
# Check Redis keys
kubectl exec -n mereka-lms deployment/redis -- redis-cli DBSIZE

# Clear cache (CAUTION: affects all sessions)
kubectl exec -n mereka-lms deployment/redis -- redis-cli FLUSHALL
```

---

## Database Issues

### Connection Errors

**Symptom**: `Can't connect to MySQL server`

**Checks**:
```bash
# 1. Is Cloud SQL proxy running?
kubectl get pods -n mereka-lms -l app=cloud-sql-proxy

# 2. Check proxy logs
kubectl logs -n mereka-lms -l app=cloud-sql-proxy --tail=50

# 3. Test connection from LMS pod
kubectl exec -n mereka-lms deployment/lms -- sh -c \
  'python -c "import MySQLdb; print(MySQLdb.connect(host=\"mysql\", user=\"root\", passwd=\"\$MYSQL_ROOT_PASSWORD\", db=\"edxapp\"))"'
```

**Fix**:
```bash
# Restart Cloud SQL proxy
kubectl rollout restart deployment/cloud-sql-proxy -n mereka-lms

# Update Cloud SQL secret
kubectl delete secret cloudsql-db-credentials -n mereka-lms
kubectl create secret generic cloudsql-db-credentials \
  --from-literal=username=root \
  --from-literal=password=NEW_PASSWORD \
  -n mereka-lms
```

### Slow Queries

**Find slow queries**:
```bash
# Enable slow query log
kubectl exec -n mereka-lms deployment/mysql -- \
  mysql -u root -p -e "SET GLOBAL slow_query_log = 'ON'; SET GLOBAL long_query_time = 2;"

# View slow queries
kubectl exec -n mereka-lms deployment/mysql -- \
  tail -f /var/log/mysql/slow.log
```

**Optimize**:
```bash
# Analyze table
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms dbshell -c "ANALYZE TABLE table_name;"

# Add index (via Django migration)
tutor local run lms ./manage.py lms makemigrations
```

### MongoDB Connection Errors

**Symptom**: `Connection refused` or `Authentication failed`

**Checks**:
```bash
# 1. Check MongoDB Atlas credentials
kubectl get secret mongodb-secret -n mereka-lms -o jsonpath='{.data.password}' | base64 -d

# 2. Test connection
kubectl exec -n mereka-lms deployment/lms -- sh -c \
  'python -c "from pymongo import MongoClient; client = MongoClient(\"$MONGODB_HOST\"); print(client.server_info())"'

# 3. Check forum service (uses MongoDB)
kubectl logs -n mereka-lms deployment/lms --tail=100 | grep -i "forum\|mongo"
```

**Fix**:
```bash
# Update MongoDB secret
kubectl delete secret mongodb-secret -n mereka-lms
kubectl create secret generic mongodb-secret \
  --from-literal=host=cluster-mereka-lms.2pjex4s.mongodb.net \
  --from-literal=password=NEW_PASSWORD \
  -n mereka-lms

# Restart LMS (forum runs inside LMS)
kubectl rollout restart deployment/lms -n mereka-lms
```

---

## Tutor Config Issues

### Cloud IPs in Local Config

**Symptom**: Services can't connect, logs show `connection refused`

**Verify**:
```bash
grep -E "MYSQL_HOST|MONGODB_HOST|REDIS_HOST" tutor_env/config.yml
# BAD: Shows 10.97.x.x (cloud IPs)
# GOOD: Shows mysql, mongodb, redis (Docker Compose service names)
```

**Fix**:
```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
./scripts/infra/tutor-config-save.sh \
  --set MYSQL_HOST=mysql \
  --set MONGODB_HOST=mongodb \
  --set REDIS_HOST=redis \
  --set MONGODB_PORT=27017
make tutor-restart
```

### Patches Not Applied

**Symptom**: MySQL auth fails, MFE build breaks, missing domains

**Verify**:
```bash
./scripts/infra/verify-tutor-config.sh
```

**Fix**:
```bash
./scripts/infra/prepare-tutor-build-context.sh --target all
make tutor-restart
```

### Build Failures

**loremipsum package error (Tutor v21)**:
```bash
# Use the repo helper; it owns the Tutor 21 compatibility path.
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
```

**node_modules not found (MFE)**:
```bash
# Refresh the governed MFE build context and rebuild through the helper.
./scripts/infra/prepare-tutor-build-context.sh --target mfe
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

**Webpack out of memory**:
```bash
# Increase memory limit (rendered MFE authority sets this)
grep "NODE_OPTIONS" tutor_env/env/plugins/mfe/build/mfe/Dockerfile
# Should show: ENV NODE_OPTIONS="--max-old-space-size=6144"

./scripts/infra/prepare-tutor-build-context.sh --target mfe
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

---

## Authentication & Access

### Can't Log In to LMS

**Checks**:
```bash
# 1. Is Authentik OIDC configured?
kubectl get secret authentik-oidc -n mereka-lms

# 2. Check OAuth2 settings
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "from oauth2_provider.models import Application; print(Application.objects.all())"

# 3. Check session backend (Redis)
kubectl exec -n mereka-lms deployment/redis -- redis-cli KEYS "django.contrib.sessions*" | head -10
```

**Fix**:
```bash
# Reset user password
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms changepassword USERNAME

# Clear sessions (force re-login)
kubectl exec -n mereka-lms deployment/redis -- redis-cli KEYS "django.contrib.sessions*" | \
  xargs kubectl exec -n mereka-lms deployment/redis -- redis-cli DEL
```

### Can't Log In to Studio

**Checks**:
```bash
# 1. Studio OAuth2 secret present?
./scripts/qa/verify-cms-oauth2-secret-present.sh

# 2. Check Studio logs
kubectl logs -n mereka-lms deployment/cms --tail=100 | grep -i "auth\|oauth"
```

**Fix**:
```bash
# Recreate Studio OAuth2 application
kubectl exec -n mereka-lms deployment/cms -- \
  python manage.py cms create_oauth2_client --studio
```

### SSO Not Working

**Checks**:
```bash
# 1. Enterprise SSO enabled?
./scripts/qa/verify-enterprise-sso.sh

# 2. SAML certs present?
kubectl get secret enterprise-sso-secrets -n mereka-lms

# 3. Check third_party_auth app
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "from django.conf import settings; print('third_party_auth' in settings.INSTALLED_APPS)"
```

**Fix**:
```bash
# Generate new SAML keypair
./scripts/tenants/generate-saml-keypair.sh

# Update secret
kubectl delete secret enterprise-sso-secrets -n mereka-lms
kubectl create secret generic enterprise-sso-secrets \
  --from-file=saml_sp_public_cert=saml_cert.pem \
  --from-file=saml_sp_private_key=saml_key.pem \
  -n mereka-lms

# Restart LMS
kubectl rollout restart deployment/lms -n mereka-lms
```

---

## Branding & Theme Issues

### Logo Not Showing

**Checks**:
```bash
# 1. Check static files collected
kubectl exec -n mereka-lms deployment/lms -- \
  ls -la /openedx/staticfiles/mereka-theme/images/

# 2. Check Caddy serving static files
curl -I https://academyv2.mereka.io/static/mereka-theme/images/logo.png
```

**Fix**:
```bash
# Sync branding assets
make branding-sync

# Production: publish a new openedx image through build-tutor-images.yml
# and promote it with release-openedx-gitops.sh using the workflow-emitted
# release-bundle / build-provenance coordinates.
# Exact sequence: docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md

# Local reproduction only:
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
```

### MFE Branding Not Applied

**Checks**:
```bash
# 1. Check MFE environment
curl https://apps.academyv2.mereka.io/env.config.json

# 2. Check branding footer component
kubectl exec -n mereka-lms deployment/mfe -- \
  ls -la /openedx/app/node_modules/@edx/frontend-component-footer/
```

**Fix**:
```bash
# Production: publish a new MFE image through build-tutor-images.yml
# and promote it with release-openedx-gitops.sh using the workflow-emitted
# release-bundle / build-provenance coordinates.
# Exact sequence: docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md

# Local reproduction only:
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

---

## Secrets Issues

### Secret Not Syncing

**Symptom**: ExternalSecret shows `SecretSyncedError`

**Checks**:
```bash
# 1. Check ExternalSecret status
kubectl get externalsecrets -n mereka-lms

# 2. Describe for details
kubectl describe externalsecret openedx-secret -n mereka-lms

# 3. Check GCP Secret Manager
gcloud secrets list --filter="name:MEREKA_LMS_*"
```

**Fix**:
```bash
# Force refresh ExternalSecret
kubectl delete externalsecret openedx-secret -n mereka-lms
kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml

# Wait for sync (up to 1 hour by default)
kubectl wait --for=condition=Ready externalsecret/openedx-secret -n mereka-lms --timeout=60s
```

### Wrong Secret Value

**Checks**:
```bash
# 1. Check Infisical value
${INFISICAL} secrets get MEREKA_LMS_SECRET_KEY \
  --domain https://secrets.mereka.io/api --env prod --path / --plain

# 2. Check GCP Secret Manager
gcloud secrets versions access latest --secret=MEREKA_LMS_SECRET_KEY

# 3. Check K8s secret
kubectl get secret openedx-secret -n mereka-lms -o jsonpath='{.data.SECRET_KEY}' | base64 -d
```

**Fix**:
```bash
# Update in Infisical
${INFISICAL} secrets set MEREKA_LMS_SECRET_KEY="new-value" \
  --domain https://secrets.mereka.io/api --env prod --path /

# Update in GCP SM
gcloud secrets create MEREKA_LMS_SECRET_KEY --data-file=- <<< "new-value"

# Wait for ExternalSecret sync or force refresh
kubectl delete externalsecret openedx-secret -n mereka-lms
kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml
```

---

## Emergency Procedures

### Rollback Deployment

```bash
# View rollout history
kubectl rollout history deployment/lms -n mereka-lms

# Rollback to previous version
kubectl rollout undo deployment/lms -n mereka-lms

# Rollback to specific revision
kubectl rollout undo deployment/lms --to-revision=3 -n mereka-lms

# Watch rollback progress
kubectl rollout status deployment/lms -n mereka-lms
```

### Scale Down (Maintenance)

```bash
# Scale down all services
for d in lms cms lms-worker cms-worker mfe discovery ecommerce; do
  kubectl scale deployment/$d --replicas=0 -n mereka-lms
done

# Verify all down
kubectl get pods -n mereka-lms

# Scale back up
for d in lms cms lms-worker cms-worker mfe discovery ecommerce; do
  kubectl scale deployment/$d --replicas=1 -n mereka-lms
done
```

### Force Pod Restart

```bash
# Delete pod (K8s recreates automatically)
kubectl delete pod <pod-name> -n mereka-lms

# Rolling restart (zero-downtime)
kubectl rollout restart deployment/lms -n mereka-lms
```

### Clear All Caches

```bash
# Redis cache
kubectl exec -n mereka-lms deployment/redis -- redis-cli FLUSHALL

# Django cache
kubectl exec -n mereka-lms deployment/lms -- \
  python manage.py lms shell -c "from django.core.cache import cache; cache.clear()"

# Restart services to clear in-memory caches
kubectl rollout restart deployment/lms -n mereka-lms
kubectl rollout restart deployment/cms -n mereka-lms
```

---

## Quick Verification Commands

```bash
# Verify Tutor patches applied
./scripts/infra/verify-tutor-config.sh

# Verify K8s images (no :latest)
./scripts/qa/verify-k8s-images.sh

# Verify service selectors match pods
./scripts/infra/fix-service-selectors.sh

# Verify ExternalSecret config
./scripts/qa/verify-externalsecret-config.sh

# Run all smoke tests
make qa-smoke
```

---

## Get More Help

- **Full troubleshooting**: [K8s Operations Guide](../../guides/admin/K8S_OPERATIONS_GUIDE.md)
- **Tutor config**: [Tutor Config Safety](../../policies/operations/TUTOR_CONFIG_SAFETY.md)
- **Incident templates**: [Incident Templates](../runbooks/INCIDENT_TEMPLATES.md)
- **Oncall playbook**: [Oncall Observability Playbook](../runbooks/ONCALL_OBSERVABILITY_PLAYBOOK.md)

---

## Common Error Messages

| Error | Likely Cause | Fix |
|-------|--------------|-----|
| `<none>` in endpoints | Service selector mismatch | `./scripts/infra/fix-service-selectors.sh` |
| `Can't connect to MySQL` | Cloud SQL proxy down | `kubectl rollout restart deployment/cloud-sql-proxy` |
| `Authentication failed (MongoDB)` | Wrong password in secret | Update `mongodb-secret` |
| `collectstatic SuspiciousFileOperation` | CSS path outside STATIC_ROOT | Refresh build context: `./scripts/infra/prepare-tutor-build-context.sh --target openedx` |
| `Module 'loremipsum' not found` | Tutor v21 uv pip issue | Build with `PIP_COMMAND=pip` |
| `node_modules not found` | MFE build path issue | Check `RUN mv` in Dockerfile |
| `Heap out of memory` | Webpack memory limit | Check `NODE_OPTIONS` in patches |
