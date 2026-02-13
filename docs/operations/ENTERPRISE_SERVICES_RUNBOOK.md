# Enterprise Services Operations Runbook
<!-- Last verified: 2026-02-14 -->

_Audience: Developers & SRE • Owner: SRE • Status: Active_

Comprehensive operations guide for the Open edX enterprise services stack deployed in the mereka-lms GKE cluster. This covers backend APIs, workers, micro-frontends (MFEs), and all enterprise-specific features.

---

## Services Inventory

### Backend Services (Django)

| Service | Port | Health Endpoint | Image | Database |
|---------|------|-----------------|-------|----------|
| enterprise-access | 18270 | `/health/` | enterprise-enterprise-access:latest | enterprise_access (42 tables) |
| enterprise-catalog | 8160 | `/health/` | enterprise-enterprise-catalog:latest | enterprise_catalog (61 tables) |
| enterprise-subsidy | 18280 | `/health/` | enterprise-enterprise-subsidy:latest | enterprise_subsidy (37 tables) |
| license-manager | 18170 | `/health/` | enterprise-license-manager:latest | license_manager (47 tables) |

**Total**: 187 database tables across 4 MySQL databases in shared Cloud SQL instance.

### Auxiliary Services

| Service | Port | Health Endpoint | Image | Notes |
|---------|------|-----------------|-------|-------|
| payments-gateway | 8080 | `/health/` | payments-gateway:0.1.1 | Stripe integration (if deployed) |

### Micro-Frontends (MFEs)

| Service | Port | Health Endpoint | Image | Public URL |
|---------|------|-----------------|-------|------------|
| enterprise-admin-portal | 8002 | `/` | enterprise-admin-portal:latest | https://admin.academyv2.mereka.io |
| enterprise-learner-portal | 8002 | `/` | enterprise-learner-portal:latest | https://enterprise.academyv2.mereka.io |

**Note**: Both MFEs run on port 8002 (Caddy server), served via different K8s services and Ingress routes.

### Background Workers (Celery)

| Service | Replicas | Image | Redis DB | Purpose |
|---------|----------|-------|----------|---------|
| enterprise-catalog-worker | 1 | enterprise-enterprise-catalog:latest | redis:6379/9 | Catalog sync, indexing |
| enterprise-access-worker | 1 | enterprise-enterprise-access:latest | redis:6379/13 | Access policy evaluation |

---

## Health Check Commands

### Quick Health Check (All Services)

```bash
# Check all enterprise pods
kubectl get pods -n mereka-lms -l app.kubernetes.io/component=enterprise

# Check all services have endpoints
kubectl get endpoints -n mereka-lms | grep enterprise
```

**Expected**: All pods `Running`, all services have IP:Port endpoints (NOT `<none>`).

### Backend Service Health Checks

```bash
# enterprise-access (port 18270)
kubectl exec -n mereka-lms deploy/enterprise-access -- \
  python -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:18270/health/'); print(f'HTTP {r.status}')"

# enterprise-catalog (port 8160)
kubectl exec -n mereka-lms deploy/enterprise-catalog -- \
  python -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:8160/health/'); print(f'HTTP {r.status}')"

# enterprise-subsidy (port 18280)
kubectl exec -n mereka-lms deploy/enterprise-subsidy -- \
  python -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:18280/health/'); print(f'HTTP {r.status}')"

# license-manager (port 18170)
kubectl exec -n mereka-lms deploy/license-manager -- \
  python -c "import urllib.request; r=urllib.request.urlopen('http://127.0.0.1:18170/health/'); print(f'HTTP {r.status}')"
```

**Expected**: All return `HTTP 200`.

### MFE Health Checks (External)

```bash
# Admin portal (requires TLS cert resolution)
curl -I https://admin.academyv2.mereka.io

# Learner portal
curl -I https://enterprise.academyv2.mereka.io
```

**Expected**: `HTTP 200` or `302` redirect.

### Worker Health Checks

```bash
# Check worker pods are running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog-worker
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=enterprise-access-worker

# View worker logs (check for task processing)
kubectl logs -n mereka-lms deploy/enterprise-catalog-worker --tail=50
kubectl logs -n mereka-lms deploy/enterprise-access-worker --tail=50
```

**Expected**: Pods `Running`, logs show Celery worker startup and task processing.

---

## Database Information

All enterprise services use the shared MySQL 8 Cloud SQL instance (`mysql` service in K8s).

### Database Schemas

| Database | Tables | Service | Key Models |
|----------|--------|---------|------------|
| enterprise_access | 42 | enterprise-access | SubsidyAccessPolicy, LearnerContentAssignment |
| enterprise_catalog | 61 | enterprise-catalog | EnterpriseCatalog, ContentMetadata |
| enterprise_subsidy | 37 | enterprise-subsidy | Subsidy, Transaction, Ledger |
| license_manager | 47 | license-manager | License, SubscriptionPlan, UserLicense |

### Connection Details

**From K8s pods**:
- Host: `mysql` (K8s internal DNS)
- Port: `3306`
- Authentication: `mysql_native_password`

**Connection strings** (example from enterprise-access):
```yaml
ENGINE: django.db.backends.mysql
NAME: enterprise_access
USER: enterprise_access
PASSWORD: <from enterprise-secrets>
HOST: mysql
PORT: 3306
ATOMIC_REQUESTS: false
CONN_MAX_AGE: 60
```

### Database Credentials

All database passwords stored in `enterprise-secrets` K8s secret (synced from Infisical/GCP SM):

```bash
# View secret keys (not values)
kubectl describe secret enterprise-secrets -n mereka-lms

# Key names:
# - MYSQL_ENTERPRISE_ACCESS_PASSWORD
# - MYSQL_ENTERPRISE_CATALOG_PASSWORD
# - MYSQL_ENTERPRISE_SUBSIDY_PASSWORD
# - MYSQL_LICENSE_MANAGER_PASSWORD
```

**Never commit database passwords** - use ExternalSecrets only.

---

## Secrets Management

### Primary Secret: enterprise-secrets

**Type**: ExternalSecret (syncs from GCP Secret Manager, sourced from Infisical)

**Contains** (11+ keys):
- `ENTERPRISE_ACCESS_SECRET_KEY` - Django secret key
- `ENTERPRISE_ACCESS_OAUTH2_SECRET` - OAuth2 client secret
- `MYSQL_ENTERPRISE_ACCESS_PASSWORD` - Database password
- `ENTERPRISE_CATALOG_SECRET_KEY`
- `ENTERPRISE_CATALOG_OAUTH2_SECRET`
- `MYSQL_ENTERPRISE_CATALOG_PASSWORD`
- `ENTERPRISE_SUBSIDY_SECRET_KEY`
- `ENTERPRISE_SUBSIDY_OAUTH2_SECRET`
- `MYSQL_ENTERPRISE_SUBSIDY_PASSWORD`
- `LICENSE_MANAGER_SECRET_KEY`
- `LICENSE_MANAGER_OAUTH2_SECRET`
- `MYSQL_LICENSE_MANAGER_PASSWORD`

**Refresh interval**: 1 hour (automatic sync from GCP SM)

### SSO/Identity Secret: enterprise-sso-secrets

**Type**: ExternalSecret

**Contains**:
- `SAML_SP_CERTIFICATE` - SAML service provider cert
- `SAML_SP_PRIVATE_KEY` - SAML SP private key
- `OIDC_CLIENT_SECRET` - OpenID Connect client secret
- `SCIM_BEARER_TOKEN` - SCIM provisioning token

**Use case**: Enterprise SSO integration (SAML, OIDC), user provisioning (SCIM).

### OAuth2 Applications

All enterprise services authenticate with LMS via OAuth2. Each service has 2 OAuth2 apps:

#### Backend Service Apps (client_credentials grant)

| Client ID | Service | Purpose |
|-----------|---------|---------|
| enterprise-access-key | enterprise-access | Server-to-server API calls |
| enterprise-catalog-key | enterprise-catalog | Server-to-server API calls |
| enterprise-subsidy-key | enterprise-subsidy | Server-to-server API calls |
| license-manager-key | license-manager | Server-to-server API calls |

**Client secrets** stored in `enterprise-secrets` as `*_OAUTH2_SECRET`.

#### MFE SSO Apps (authorization_code grant)

| Client ID | MFE | Public URL |
|-----------|-----|------------|
| enterprise-admin-portal-sso | enterprise-admin-portal | https://admin.academyv2.mereka.io |
| enterprise-learner-portal-sso | enterprise-learner-portal | https://enterprise.academyv2.mereka.io |

**Redirect URIs**:
- Admin portal: `https://admin.academyv2.mereka.io/auth/callback`
- Learner portal: `https://enterprise.academyv2.mereka.io/auth/callback`

---

## Observability

### Metrics (Prometheus)

**ServiceMonitors** (if configured):
- `enterprise-access-metrics` - Scrapes `:18270/metrics`
- `enterprise-catalog-metrics` - Scrapes `:8160/metrics`
- `enterprise-subsidy-metrics` - Scrapes `:18280/metrics`
- `license-manager-metrics` - Scrapes `:18170/metrics`

**Key metrics**:
- `django_http_requests_total` - Request count by method/status
- `django_http_request_duration_seconds` - Request latency
- `celery_task_total` - Celery task count (workers)
- `celery_task_runtime_seconds` - Task execution time

### Alerts (PrometheusRule)

**Alert name**: `enterprise-alerts` (if configured)

**Example alerts**:
- `EnterpriseServiceDown` - Service health endpoint returns non-200
- `EnterpriseHighErrorRate` - >5% 5xx responses in 5 minutes
- `EnterpriseSlowRequests` - P95 latency >2s
- `CeleryWorkerDown` - Worker pod not running

**View active alerts**:
```bash
kubectl get prometheusrule -n mereka-lms enterprise-alerts -o yaml
```

### Logs (Promtail → Loki)

All enterprise services send logs to Loki via Promtail.

**View logs**:
```bash
# Tail logs for a service
kubectl logs -n mereka-lms -l app.kubernetes.io/name=enterprise-access --tail=100 -f

# View logs in Grafana Loki
# Query: {namespace="mereka-lms", app_kubernetes_io_name="enterprise-access"}
```

**Log patterns**:
- `INFO` - Normal operations, task processing
- `WARNING` - Retries, degraded performance
- `ERROR` - Failed requests, database errors
- `CRITICAL` - Service startup failures, config errors

---

## Common Operations

### Restart a Service

```bash
# Restart a backend service (triggers rolling update)
kubectl rollout restart deployment/enterprise-access -n mereka-lms
kubectl rollout restart deployment/enterprise-catalog -n mereka-lms
kubectl rollout restart deployment/enterprise-subsidy -n mereka-lms
kubectl rollout restart deployment/license-manager -n mereka-lms

# Restart an MFE
kubectl rollout restart deployment/enterprise-admin-portal -n mereka-lms
kubectl rollout restart deployment/enterprise-learner-portal -n mereka-lms

# Restart a worker
kubectl rollout restart deployment/enterprise-catalog-worker -n mereka-lms
kubectl rollout restart deployment/enterprise-access-worker -n mereka-lms

# Check rollout status
kubectl rollout status deployment/enterprise-access -n mereka-lms
```

**Timing**: Rolling update completes in 1-2 minutes.

### View Logs

```bash
# Real-time logs (follow)
kubectl logs -n mereka-lms -l app.kubernetes.io/name=enterprise-access -f

# Last 100 lines
kubectl logs -n mereka-lms deploy/enterprise-catalog --tail=100

# Logs from specific pod
kubectl logs -n mereka-lms enterprise-access-abc123-xyz --tail=50

# Filter logs for errors
kubectl logs -n mereka-lms deploy/enterprise-subsidy --tail=500 | grep ERROR
```

### Run Migrations

Migrations run automatically via `initContainer` on pod startup. To manually trigger:

```bash
# enterprise-access migrations
kubectl exec -n mereka-lms deploy/enterprise-access -- \
  python manage.py migrate --noinput

# enterprise-catalog migrations
kubectl exec -n mereka-lms deploy/enterprise-catalog -- \
  python manage.py migrate --noinput

# enterprise-subsidy migrations
kubectl exec -n mereka-lms deploy/enterprise-subsidy -- \
  python manage.py migrate --noinput

# license-manager migrations
kubectl exec -n mereka-lms deploy/license-manager -- \
  python manage.py migrate --noinput
```

**WARNING**: Only run manual migrations if pod initialization fails or during emergency rollback.

### Scale Replicas

```bash
# Scale up (increase capacity)
kubectl scale deployment/enterprise-catalog --replicas=2 -n mereka-lms

# Scale down (reduce cost)
kubectl scale deployment/enterprise-access --replicas=1 -n mereka-lms

# Auto-scale workers based on queue depth (if HPA configured)
kubectl autoscale deployment/enterprise-catalog-worker --min=1 --max=5 --cpu-percent=80 -n mereka-lms

# View current replica count
kubectl get deployment -n mereka-lms | grep enterprise
```

**Recommendation**: Start with 1 replica per service, scale up based on load testing.

### Rotate Secrets

**CRITICAL**: Follow safe rotation workflow to prevent downtime.

```bash
# 1. Generate new secret value in Infisical
# Use canonical wrapper from VPS infrastructure
INFISICAL=/home/gurpreet/projects/vps/infrastructure/scripts/infisical
${INFISICAL} secrets set MEREKA_LMS_ENTERPRISE_ACCESS_SECRET_KEY="<new-value>" \
  --domain https://secrets.mereka.io/api --env prod --path /

# 2. Sync to GCP Secret Manager
gcloud secrets versions add MEREKA_LMS_ENTERPRISE_ACCESS_SECRET_KEY --data-file=- <<< "<new-value>"

# 3. Force ExternalSecret refresh (max 1 hour wait otherwise)
kubectl annotate externalsecret enterprise-secrets -n mereka-lms \
  force-sync="$(date +%s)" --overwrite

# 4. Restart affected service
kubectl rollout restart deployment/enterprise-access -n mereka-lms

# 5. Verify health
kubectl exec -n mereka-lms deploy/enterprise-access -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:18270/health/').status)"
```

**Timing**: ExternalSecret sync (1-60 min) + pod restart (1-2 min) = 2-62 min total.

---

## Troubleshooting

### Service CrashLoopBackOff

**Symptoms**: Pod repeatedly restarts, never reaches `Running` state.

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod -n mereka-lms <pod-name>

# View crash logs
kubectl logs -n mereka-lms <pod-name> --previous

# Common errors:
# - "django.core.exceptions.ImproperlyConfigured" → Config file missing/invalid
# - "pymysql.err.OperationalError: (2003, "Can't connect to MySQL")" → DB connection failure
# - "KeyError: 'DJANGO_SECRET_KEY'" → Secret not loaded
```

**Fixes**:

1. **Config generation failure** (initContainer config-gen fails):
   ```bash
   # Check config-gen logs
   kubectl logs -n mereka-lms <pod-name> -c config-gen

   # Fix: Verify all required env vars are set
   kubectl get secret enterprise-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys'
   ```

2. **Migration failure** (initContainer migrate fails):
   ```bash
   # Check migrate logs
   kubectl logs -n mereka-lms <pod-name> -c migrate

   # Fix: Manually run migrations (see "Run Migrations" section)
   ```

3. **Missing secret**:
   ```bash
   # Check if secret exists
   kubectl get secret enterprise-secrets -n mereka-lms

   # Force resync from GCP SM
   kubectl annotate externalsecret enterprise-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
   ```

### Database Connection Issues

**Symptoms**: Service health check fails, logs show MySQL connection errors.

**Diagnosis**:
```bash
# Test MySQL connectivity from pod
kubectl exec -n mereka-lms deploy/enterprise-access -- \
  python -c "import pymysql; pymysql.connect(host='mysql', user='enterprise_access', password='<test>', database='enterprise_access')"

# Check MySQL service endpoints
kubectl get endpoints mysql -n mereka-lms

# Verify credentials
kubectl get secret enterprise-secrets -n mereka-lms -o jsonpath='{.data.MYSQL_ENTERPRISE_ACCESS_PASSWORD}' | base64 -d
```

**Fixes**:

1. **MySQL service down**:
   ```bash
   kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mysql
   kubectl rollout restart deployment/mysql -n mereka-lms
   ```

2. **Wrong password**:
   ```bash
   # Update password in Infisical → GCP SM → K8s (see "Rotate Secrets")
   # Restart service after secret sync
   ```

3. **Database doesn't exist**:
   ```bash
   # Create database (run from mysql pod)
   kubectl exec -n mereka-lms deploy/mysql -- \
     mysql -u root -p<root-password> -e "CREATE DATABASE IF NOT EXISTS enterprise_access;"

   # Run migrations
   kubectl exec -n mereka-lms deploy/enterprise-access -- python manage.py migrate --noinput
   ```

### OAuth2 Authentication Failures

**Symptoms**: MFE login fails, backend API calls return `401 Unauthorized`.

**Diagnosis**:
```bash
# Check OAuth2 app exists in LMS
kubectl exec -n mereka-lms deploy/lms -- \
  python manage.py lms shell -c "from oauth2_provider.models import Application; print(Application.objects.filter(client_id='enterprise-access-key').first())"

# Check client secret matches
kubectl get secret enterprise-secrets -n mereka-lms -o jsonpath='{.data.ENTERPRISE_ACCESS_OAUTH2_SECRET}' | base64 -d

# Test OAuth2 token exchange
curl -X POST https://academyv2.mereka.io/oauth2/access_token/ \
  -d "grant_type=client_credentials&client_id=enterprise-access-key&client_secret=<secret>"
```

**Fixes**:

1. **OAuth2 app not created**:
   ```bash
   # Create OAuth2 application in LMS
   kubectl exec -n mereka-lms deploy/lms -- \
     python manage.py lms create_oauth2_application \
       --client-id enterprise-access-key \
       --client-secret <secret> \
       --client-type confidential \
       --authorization-grant-type client-credentials \
       --skip-authorization
   ```

2. **Client secret mismatch**:
   ```bash
   # Update OAuth2 app secret in LMS to match enterprise-secrets
   kubectl exec -n mereka-lms deploy/lms -- \
     python manage.py lms update_oauth2_application \
       --client-id enterprise-access-key \
       --client-secret <new-secret>
   ```

3. **Redirect URI mismatch** (MFEs only):
   ```bash
   # Update redirect URIs
   kubectl exec -n mereka-lms deploy/lms -- \
     python manage.py lms update_oauth2_application \
       --client-id enterprise-admin-portal-sso \
       --redirect-uris "https://admin.academyv2.mereka.io/auth/callback"
   ```

### MFE Loading Issues

**Symptoms**: MFE shows blank page, loading spinner, or 404 errors.

**Diagnosis**:
```bash
# Check pod is running
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=enterprise-admin-portal

# Check Caddy service is serving files
kubectl exec -n mereka-lms deploy/enterprise-admin-portal -- \
  curl -I http://localhost:8002/

# Check MFE env config
kubectl exec -n mereka-lms deploy/enterprise-admin-portal -- \
  cat /openedx/dist/env.config.js

# Check Ingress routing
kubectl get ingress -n mereka-lms -o yaml | grep -A 5 "admin.academyv2.mereka.io"
```

**Fixes**:

1. **ConfigMap not mounted**:
   ```bash
   # Verify ConfigMap exists
   kubectl get configmap enterprise-mfe-env -n mereka-lms

   # Recreate ConfigMap if missing (check deploy/k8s/base/apps/enterprise/mfe/)
   kubectl apply -f deploy/k8s/base/apps/enterprise/mfe/
   ```

2. **Caddy config incorrect**:
   ```bash
   # Check Caddyfile
   kubectl get configmap enterprise-admin-portal-caddy-config -n mereka-lms -o yaml

   # Should include: root * /openedx/dist, file_server, try_files
   ```

3. **TLS certificate issue**:
   ```bash
   # Check cert-manager issued cert
   kubectl get certificate -n mereka-lms | grep admin.academyv2.mereka.io

   # Check cert SANs include MFE domain
   kubectl describe certificate <cert-name> -n mereka-lms
   ```

---

## DNS + TLS

### DNS Records (Cloudflare)

| Hostname | Type | Target | TTL | Proxy |
|----------|------|--------|-----|-------|
| admin.academyv2.mereka.io | A | <GKE LoadBalancer IP> | 300 | DNS-only (gray cloud) |
| enterprise.academyv2.mereka.io | A | <GKE LoadBalancer IP> | 300 | DNS-only (gray cloud) |

**Why DNS-only**: Cloudflare Free SSL doesn't cover multi-level subdomains (`*.*.mereka.io`). Use Let's Encrypt via cert-manager instead.

### TLS Certificates (Let's Encrypt)

**Certificate name**: `academyv2-mereka-io-tls` (shared with main LMS)

**SANs** (Subject Alternative Names):
```yaml
dnsNames:
  - academyv2.mereka.io
  - studio.academyv2.mereka.io
  - apps.academyv2.mereka.io
  - admin.academyv2.mereka.io          # Enterprise admin portal
  - enterprise.academyv2.mereka.io     # Enterprise learner portal
  - discovery.academyv2.mereka.io
  - ecommerce.academyv2.mereka.io
  # ... (other domains)
```

**Verify certificate**:
```bash
# Check cert is ready
kubectl get certificate academyv2-mereka-io-tls -n mereka-lms

# Check SANs include enterprise domains
kubectl get secret academyv2-mereka-io-tls -n mereka-lms -o jsonpath='{.data.tls\.crt}' | \
  base64 -d | openssl x509 -noout -text | grep -A 10 "Subject Alternative Name"
```

**Renew certificate** (if SANs missing):
```bash
# Delete existing cert (triggers re-issuance)
kubectl delete certificate academyv2-mereka-io-tls -n mereka-lms

# Wait for cert-manager to issue new cert (2-5 min)
kubectl get certificate academyv2-mereka-io-tls -n mereka-lms -w
```

### Caddy Ingress Routing

**Caddyfile** (inside main Caddy pod):
```caddyfile
admin.academyv2.mereka.io {
  reverse_proxy enterprise-admin-portal:8002
  tls /etc/caddy/tls.crt /etc/caddy/tls.key
}

enterprise.academyv2.mereka.io {
  reverse_proxy enterprise-learner-portal:8002
  tls /etc/caddy/tls.crt /etc/caddy/tls.key
}
```

**Verify routing**:
```bash
# Check Caddy config
kubectl exec -n mereka-lms deploy/caddy -- cat /etc/caddy/Caddyfile | grep -A 3 "admin.academyv2.mereka.io"

# Test internal routing
kubectl run curl-test --rm -i --image=curlimages/curl --restart=Never -n mereka-lms -- \
  curl -H "Host: admin.academyv2.mereka.io" http://caddy/
```

---

## Quick Reference

### Pod Names to Service Names

| Pod Label | Service Name | Port |
|-----------|--------------|------|
| `app.kubernetes.io/name=enterprise-access` | `enterprise-access` | 18270 |
| `app.kubernetes.io/name=enterprise-catalog` | `enterprise-catalog` | 8160 |
| `app.kubernetes.io/name=enterprise-subsidy` | `enterprise-subsidy` | 18280 |
| `app.kubernetes.io/name=license-manager` | `license-manager` | 18170 |
| `app.kubernetes.io/name=enterprise-admin-portal` | `enterprise-admin-portal` | 8002 |
| `app.kubernetes.io/name=enterprise-learner-portal` | `enterprise-learner-portal` | 8002 |

### Key ConfigMaps

| ConfigMap | Purpose |
|-----------|---------|
| `enterprise-mfe-env` | Environment variables for both MFEs (env.config.js) |
| `enterprise-admin-portal-caddy-config` | Caddy web server config for admin portal |
| `enterprise-learner-portal-caddy-config` | Caddy web server config for learner portal |

### Resource Requests/Limits

| Service | CPU Request | Memory Request | CPU Limit | Memory Limit |
|---------|-------------|----------------|-----------|--------------|
| enterprise-access | 200m | 256Mi | 500m | 512Mi |
| enterprise-catalog | 50m | 256Mi | 250m | 512Mi |
| enterprise-subsidy | 50m | 256Mi | 250m | 512Mi |
| license-manager | 200m | 256Mi | 500m | 512Mi |
| enterprise-*-portal (MFE) | 50m | 64Mi | 200m | 128Mi |
| enterprise-catalog-worker | 50m | 256Mi | 250m | 512Mi |
| enterprise-access-worker | 50m | 256Mi | 250m | 512Mi |

---

## Related Documentation

- **Site Down Runbook**: [site-down.md](runbooks/site-down.md) - Generic K8s troubleshooting
- **Database Issues**: [database-issues.md](runbooks/database-issues.md) - MySQL connection failures
- **Auth & Permissions**: [AUTH_AND_PERMISSIONS.md](AUTH_AND_PERMISSIONS.md) - OAuth2 app setup
- **Domain Management**: [DOMAIN_MANAGEMENT.md](DOMAIN_MANAGEMENT.md) - DNS + TLS setup
- **Secrets Management Spec**: [../../specs/secrets-management.md](../../specs/secrets-management.md) - Infisical → GCP SM → K8s flow

---

## Emergency Contacts

- **On-call SRE**: Check `docs/operations/ONCALL_ROTATION.md`
- **Incident management**: Follow `docs/operations/INCIDENT_TEMPLATES.md`
- **Escalation**: See `docs/operations/runbooks/site-down.md` decision tree

---

**Last updated**: 2026-02-14 by Claude Code
**Next review**: 2026-03-14 (monthly verification)
