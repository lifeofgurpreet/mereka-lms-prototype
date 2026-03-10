# Enterprise Services Operations Guide
_Audience: Operations & Enterprise Admins • Owner: Platform Team • Last updated: 2026-02-11_

**Purpose**: Deploy, monitor, and manage Open edX enterprise microservices for B2B clients.

**TL;DR**: 5 microservices (catalog, license-manager, access, subsidy, integrated-channels) deployed in `mereka-lms` namespace. Support corporate license pools, curated catalogs, SSO, and LMS integrations (Degreed, Cornerstone). Multi-tenant via `EnterpriseCustomer` UUID. All share MySQL/Redis. Events via Redis Streams.

---

## Architecture Overview

### Enterprise Services

| Service | Purpose | Port | Database | Celery Worker |
|---------|---------|------|----------|---------------|
| **enterprise-catalog** | Content curation, catalog queries | 8160 | `enterprise_catalog` | ✅ Yes |
| **license-manager** | License pools, seat allocation | 8170 | `license_manager` | ✅ Yes |
| **enterprise-access** | Access policy evaluation | 18270 | `enterprise_access` | ✅ Yes |
| **enterprise-subsidy** | Subsidy ledger, transactions | 18280 | `enterprise_subsidy` | ❌ No celery |
| **integrated-channels** | LMS sync (Degreed, Cornerstone) | N/A (LMS Django app) | N/A (uses LMS DB) | ✅ Yes (LMS worker) |

### MFEs

| MFE | Purpose | URL |
|-----|---------|-----|
| **frontend-app-admin-portal** | Enterprise admin dashboard | `https://admin.mereka.io/enterprise` |
| **frontend-app-learner-portal-enterprise** | Enterprise learner portal | `https://enterprise.mereka.io` |

**Namespace**: `mereka-lms` (same as LMS/CMS)

### Communication

```
┌─────────────┐      OAuth2       ┌─────────────┐
│   Admin     │──────────────────→│   Catalog   │
│   Portal    │                   │   Service   │
└─────────────┘                   └─────────────┘
                                         ↓
                                    Internal HTTP
                                         ↓
┌─────────────┐      JWT Auth     ┌─────────────┐
│     LMS     │◄─────────────────→│   License   │
│             │                   │   Manager   │
└─────────────┘                   └─────────────┘
       ↓                                 ↓
   Redis Streams (Event Bus)             ↓
       ↓                                 ↓
┌─────────────┐                   ┌─────────────┐
│   Access    │                   │   Subsidy   │
└─────────────┘                   └─────────────┘
```

---

## Deployment

### Service Status

```bash
# Check all enterprise services
kubectl get pods -n mereka-lms -l app.kubernetes.io/component=enterprise

# Check specific service
kubectl get deployment enterprise-catalog -n mereka-lms
```

### Deploy All Services

**Prerequisites**:
- LMS/CMS running
- MySQL databases created (see Database Setup below)
- Secrets synced to K8s (via ExternalSecrets)
- OAuth2 clients registered

**Deploy**:
```bash
kubectl apply -k deploy/k8s/overlays/production

# Verify deployments
kubectl get deployments -n mereka-lms | grep enterprise

# Expected:
# enterprise-catalog          1/1     1            1           5m
# enterprise-catalog-worker   1/1     1            1           5m
# enterprise-access           1/1     1            1           5m
# enterprise-access-worker    1/1     1            1           5m
# license-manager             1/1     1            1           5m
# license-manager-worker      1/1     1            1           5m
# enterprise-subsidy          1/1     1            1           5m
```

### Database Setup

**One-time setup per service**:

```bash
# Create databases in Cloud SQL (via LMS pod)
kubectl exec -it -n mereka-lms deployment/lms -- python manage.py lms shell -c "
import pymysql
conn = pymysql.connect(
    host='mysql',
    user='root',
    password=os.environ['MYSQL_ROOT_PASSWORD'],
)
cursor = conn.cursor()
cursor.execute('CREATE DATABASE IF NOT EXISTS enterprise_catalog DEFAULT CHARACTER SET utf8mb4')
cursor.execute('CREATE DATABASE IF NOT EXISTS license_manager DEFAULT CHARACTER SET utf8mb4')
cursor.execute('CREATE DATABASE IF NOT EXISTS enterprise_access DEFAULT CHARACTER SET utf8mb4')
cursor.execute('CREATE DATABASE IF NOT EXISTS enterprise_subsidy DEFAULT CHARACTER SET utf8mb4')
conn.commit()
conn.close()
print('Databases created')
"

# Run migrations (per service)
kubectl exec -it -n mereka-lms deployment/enterprise-catalog -- python manage.py migrate
kubectl exec -it -n mereka-lms deployment/license-manager -- python manage.py migrate
kubectl exec -it -n mereka-lms deployment/enterprise-access -- python manage.py migrate
kubectl exec -it -n mereka-lms deployment/enterprise-subsidy -- python manage.py migrate
```

Retrieve `MYSQL_ROOT_PASSWORD` from the active secret-management flow before running this locally or in-cluster. Do not paste secret values into this guide.

### OAuth2 Client Registration

**Register service accounts in LMS**:

```bash
# Access LMS admin
# URL: https://academyv2.mereka.io/admin/oauth2_provider/application/

# For each service, create Application:
# - Client ID: enterprise-catalog-backend (use service name)
# - Client secret: <generate strong secret, store in Infisical>
# - Client type: Confidential
# - Authorization grant type: Client credentials
# - Skip authorization: Yes
# - Name: Enterprise Catalog Backend Service
# - User: Leave blank (service account)

# Services needing OAuth2 clients:
# - enterprise-catalog
# - license-manager
# - enterprise-access
# - enterprise-subsidy
```

**Store secrets in Infisical**:
- Path: `/k8s/mereka-lms`
- Keys:
  - `MEREKA_LMS_ENTERPRISE_CATALOG_OAUTH2_SECRET`
  - `MEREKA_LMS_LICENSE_MANAGER_OAUTH2_SECRET`
  - `MEREKA_LMS_ENTERPRISE_ACCESS_OAUTH2_SECRET`
  - `MEREKA_LMS_ENTERPRISE_SUBSIDY_OAUTH2_SECRET`

---

## Enterprise Customer Management

### Create Enterprise Customer

**Via Django Admin** (recommended for first-time setup):

1. Login: https://academyv2.mereka.io/admin
2. Navigate: **Enterprise** → **Enterprise Customers** → **Add**
3. Fill:
   - Name: `Acme Corporation`
   - UUID: Auto-generated (note this UUID - it's the tenant identifier)
   - Active: ✅ Checked
   - Country: Select
   - Site: `academyv2.mereka.io`
4. Save

**Via Management Command**:

```bash
kubectl exec -it -n mereka-lms deployment/lms -- python manage.py lms \
  create_enterprise_customer \
  --name "Acme Corporation" \
  --site academyv2.mereka.io \
  --country US \
  --active
```

**Retrieve Customer UUID**:

```bash
kubectl exec -it -n mereka-lms deployment/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
customer = EnterpriseCustomer.objects.get(name='Acme Corporation')
print(f'UUID: {customer.uuid}')
"
```

### Create Catalog

**Link courses to enterprise customer**:

```bash
# Create catalog via catalog service
curl -X POST https://catalog.mereka.io/api/v1/enterprise-catalogs/ \
  -H "Authorization: Bearer ${ENTERPRISE_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "uuid": "auto-generated",
    "enterprise_customer": "<enterprise-customer-uuid>",
    "title": "Acme Corporation Catalog",
    "enabled_course_modes": ["verified", "professional"],
    "content_filter": {
      "content_type": "course",
      "status": "published"
    }
  }'
```

Retrieve `ENTERPRISE_ADMIN_TOKEN` from the approved secret store or admin console workflow. Do not store bearer tokens in docs.

**Or via Django admin**:
1. Navigate: **Enterprise Catalog** → **Catalogs** → **Add**
2. Link to Enterprise Customer UUID
3. Add content filter rules

### Create License Pool

**Via License Manager admin**:

```bash
# Access: https://license-manager.mereka.io/admin

# Create Subscription Plan:
# - Enterprise Customer: Select Acme Corporation
# - Title: "Acme 2024 License Pool"
# - Start date / Expiration date
# - License count: 100
# - Is active: ✅
```

**Assign licenses**:
```bash
# Via API or admin UI
# Admin: Subscription Plan → Licenses → Assign to user email
```

### Configure SSO

**SAML setup**:

1. LMS admin: **Enterprise** → **Enterprise Customer** → Select customer → **SAML Configuration**
2. Upload IdP metadata XML
3. Entity ID: `https://academyv2.mereka.io/enterprise/<customer-uuid>/saml/metadata`
4. ACS URL: `https://academyv2.mereka.io/enterprise/<customer-uuid>/saml/callback`
5. Enable SSO: ✅

**Verify SSO**:
```bash
./scripts/qa/verify-enterprise-sso-saml.sh <customer-uuid>
```

---

## Monitoring

### Health Checks

```bash
# Catalog service
curl -I https://catalog.mereka.io/health/

# License manager
curl -I https://license-manager.mereka.io/health/

# Access service
curl -I https://access.mereka.io/health/

# Subsidy service
curl -I https://subsidy.mereka.io/health/
```

### Metrics

**ServiceMonitors** (Prometheus):
- `servicemonitor-enterprise-catalog`
- `servicemonitor-license-manager`
- `servicemonitor-enterprise-access`
- `servicemonitor-enterprise-subsidy`

**Key metrics**:
```promql
# Request rate per service
sum(rate(django_http_requests_total[5m])) by (service)

# 95th percentile latency
histogram_quantile(0.95, rate(django_http_requests_latency_seconds_bucket{service="enterprise-catalog"}[5m]))

# Error rate
sum(rate(django_http_requests_total{status=~"5.."}[5m])) by (service)
```

### Logs

**View service logs**:
```bash
# Catalog service
kubectl logs -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog --tail=100

# License manager
kubectl logs -n mereka-lms -l app.kubernetes.io/name=license-manager --tail=100

# Filter errors
kubectl logs -n mereka-lms -l app.kubernetes.io/component=enterprise | grep ERROR
```

**Loki query** (Grafana):
```logql
{namespace="mereka-lms", app_kubernetes_io_component="enterprise"} |= "ERROR"
```

### Alerts

**Current PrometheusRules**:
- `EnterpriseServiceDown` - Service endpoints = 0 (critical)
- `EnterpriseHighLatency` - p95 latency > 1s (warning)
- `EnterpriseHighErrorRate` - 5xx rate > 5% (critical)

---

## Common Operations

### Scale Service

```bash
# Scale catalog service
kubectl scale deployment enterprise-catalog --replicas=3 -n mereka-lms

# Scale worker
kubectl scale deployment enterprise-catalog-worker --replicas=2 -n mereka-lms
```

### Restart Service

```bash
# Rolling restart (zero downtime)
kubectl rollout restart deployment/enterprise-catalog -n mereka-lms

# Restart all enterprise services
for svc in enterprise-catalog license-manager enterprise-access enterprise-subsidy; do
  kubectl rollout restart deployment/$svc -n mereka-lms
done
```

### Update Service Image

```bash
# Update to new tag
kubectl set image deployment/enterprise-catalog \
  enterprise-catalog=ghcr.io/biji-biji-initiative/mereka-lms/enterprise-catalog:v1.2.3 \
  -n mereka-lms

# Watch rollout
kubectl rollout status deployment/enterprise-catalog -n mereka-lms
```

### Run Migrations

**After schema changes or upgrades**:

```bash
# Per service
kubectl exec -it -n mereka-lms deployment/enterprise-catalog -- python manage.py migrate

# Check migration status
kubectl exec -it -n mereka-lms deployment/enterprise-catalog -- python manage.py showmigrations
```

### Access Service Shell

```bash
# Django shell
kubectl exec -it -n mereka-lms deployment/enterprise-catalog -- python manage.py shell

# Bash shell
kubectl exec -it -n mereka-lms deployment/enterprise-catalog -- bash
```

---

## Troubleshooting

### Service Won't Start

**Symptom**: Pod in CrashLoopBackOff

**Debug**:
```bash
# Check logs
kubectl logs -n mereka-lms deployment/enterprise-catalog --tail=100

# Check events
kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=enterprise-catalog

# Common causes:
# 1. Missing database
# 2. Missing secrets
# 3. Migrations not run
# 4. OAuth2 client not registered
```

**Fix checklist**:
- [ ] Database exists: `SHOW DATABASES LIKE 'enterprise_catalog'`
- [ ] Secrets synced: `kubectl get secret enterprise-secrets -n mereka-lms`
- [ ] Migrations run: `kubectl exec ... -- python manage.py showmigrations`
- [ ] OAuth2 client registered in LMS admin

### License Assignment Fails

**Symptom**: User not enrolled after license assigned.

**Debug**:
```bash
# Check license status
kubectl exec -it -n mereka-lms deployment/license-manager -- python manage.py shell -c "
from subscriptions.models import License
license = License.objects.get(user_email='user@example.com')
print(f'Status: {license.status}')
print(f'Subscription: {license.subscription_plan}')
"

# Check enrollment events
kubectl logs -n mereka-lms deployment/lms-worker | grep "LICENSE_ASSIGNED"
```

**Possible causes**:
1. **License not activated**: Status should be `activated`
2. **Event not published**: Check LMS event bus config
3. **Course not in catalog**: Verify course in customer's catalog
4. **Redis connection issues**: Check Redis connectivity

### Catalog Sync Slow

**Symptom**: Catalog queries take >5s.

**Debug**:
```bash
# Check Celery tasks
kubectl exec -it -n mereka-lms deployment/enterprise-catalog-worker -- \
  celery -A enterprise_catalog inspect active

# Check database query performance
kubectl exec -it -n mereka-lms deployment/enterprise-catalog -- python manage.py shell -c "
from django.db import connection
from django.db import reset_queries
from catalog.models import EnterpriseCatalog
reset_queries()
catalogs = list(EnterpriseCatalog.objects.all()[:100])
print(f'Queries: {len(connection.queries)}')
for q in connection.queries:
    print(f'{q[\"time\"]}s: {q[\"sql\"][:100]}')
"
```

**Optimization**:
- Add database indexes on frequently queried fields
- Implement Redis caching for catalog results
- Scale up catalog service replicas

### SSO Login Fails

**Symptom**: Enterprise learner can't login via SSO.

**Debug**:
```bash
# Check SAML configuration
kubectl exec -it -n mereka-lms deployment/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomerIdentityProvider
idp = EnterpriseCustomerIdentityProvider.objects.get(enterprise_customer__uuid='<customer-uuid>')
print(f'Provider ID: {idp.provider_id}')
print(f'Enabled: {idp.enabled}')
"

# Check SAML logs
kubectl logs -n mereka-lms deployment/lms | grep SAML | tail -50
```

**Verify**:
```bash
./scripts/qa/verify-enterprise-sso-saml.sh <customer-uuid>
```

### Integrated Channel Sync Failed

**Symptom**: Course completions not syncing to Degreed/Cornerstone.

**Debug**:
```bash
# Check integrated channels config
kubectl exec -it -n mereka-lms deployment/lms -- python manage.py lms shell -c "
from integrated_channels.degreed.models import DegreedEnterpriseCustomerConfiguration
config = DegreedEnterpriseCustomerConfiguration.objects.filter(active=True).first()
print(f'Config: {config}')
print(f'Base URL: {config.degreed_base_url}')
"

# Check Celery tasks
kubectl logs -n mereka-lms deployment/lms-worker | grep "transmit_content_metadata"

# Test API connection
kubectl exec -it -n mereka-lms deployment/lms -- curl -I <partner-api-url>
```

---

## Verification

### Full Enterprise Stack Check

```bash
./scripts/qa/verify-enterprise-all-acs.sh
```

Checks:
- ✅ All services running
- ✅ Databases exist
- ✅ Migrations applied
- ✅ OAuth2 clients registered
- ✅ Health endpoints responding
- ✅ ServiceMonitors configured

### Per-Service Checks

```bash
# Catalog service
./scripts/qa/verify-enterprise-catalog.sh

# License management
./scripts/qa/verify-enterprise-license-management.sh

# Access + Subsidy
./scripts/qa/verify-enterprise-access-subsidy.sh

# Integrated channels
./scripts/qa/verify-enterprise-integrated-channels.sh

# SSO
./scripts/qa/verify-enterprise-sso.sh
```

---

## Related Resources

**Spec**: `specs/enterprise-microservices_spec.md` (36 ACs, 100% complete)

**Architecture**: `docs/concepts/architecture/enterprise-services-overview.md`

**Runbooks**: `docs/ops/runbooks/ENTERPRISE_SERVICES_RUNBOOK.md`

**Scripts**:
- `scripts/qa/verify-enterprise-all-acs.sh` - Full stack verification
- `scripts/qa/verify-enterprise-deployment.sh` - Deployment health
- `scripts/qa/verify-enterprise-observability.sh` - Monitoring check
- `scripts/qa/verify-enterprise-secrets.sh` - Secrets verification
- `scripts/qa/verify-enterprise-tenant-isolation.sh` - Multi-tenant security

**Configuration**:
- `deploy/k8s/base/apps/enterprise/` - K8s manifests
- `deploy/k8s/base/secrets/external-secrets.yaml` - Secret mappings (enterprise-secrets section)

**Open edX Docs**:
- Enterprise features: https://docs.openedx.org/en/latest/site_ops/how-tos/enable_enterprise_features.html
- Enterprise API: https://docs.openedx.org/projects/enterprise-catalog/
