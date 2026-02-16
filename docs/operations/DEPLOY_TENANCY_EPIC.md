# Tenancy Epic Deployment Runbook

**Epic**: mereka-lms-1gcr — Complete Multi-Tenant Architecture (28 ACs)
**Spec**: `specs/multi-tenancy-architecture_spec.md`
**Status**: Ready for deployment (patches verified, code ready)

## Overview

This runbook deploys the complete multi-tenancy system with:
- `mereka_tenancy` module baked into LMS Docker image
- `TenantResolutionMiddleware` active in MIDDLEWARE stack
- EnterpriseCustomer records for 3 tenants (MEREKA, BIJIBIJI, SKILLOURFUTURE)
- Full tenant isolation with X-Tenant-ID header propagation

**Time estimate**: 60-75 minutes (45 min image build + 15 min deploy + 15 min provisioning)

## Prerequisites

- [ ] Access to GKE cluster (`kubectl` configured for mereka-lms namespace)
- [ ] Access to Artifact Registry (push permission for `asia-southeast1-docker.pkg.dev/mereka-lms/openedx`)
- [ ] Tutor environment configured (`TUTOR_ROOT` set)
- [ ] Docker with ≥12 GB RAM allocated
- [ ] Current LMS image tag noted for rollback

## Step 1: Apply Patches

```bash
# Set Tutor environment
export TUTOR_ROOT="$(pwd)/tutor_env"

# Apply patches (includes mereka_tenancy installation)
./infrastructure/tutor/apply-patches.sh

# Verify patches applied
./scripts/infra/verify-tutor-config.sh
```

**Expected output**:
```
✓ MySQL 8 authentication plugin configured
✓ MFE Node 18 build toolchain present
✓ Mereka tenancy module configured
✓ All required patches verified successfully!
```

## Step 2: Rebuild LMS Image

```bash
# Build Open edX image with mereka_tenancy baked in
tutor images build openedx

# This takes 30-45 minutes
# Verify build completed successfully
docker images | grep openedx
```

**Expected output**:
```
<registry>/openedx   latest   <image-id>   <timestamp>   <size>GB
```

## Step 3: Tag and Push Image

```bash
# Get current git SHA for tagging
GIT_SHA=$(git rev-parse --short HEAD)

# Tag image
docker tag openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${GIT_SHA}
docker tag openedx:latest asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:latest

# Push to Artifact Registry
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${GIT_SHA}
docker push asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:latest
```

## Step 4: Deploy to GKE Cluster

```bash
# Update deployment image
kubectl set image -n mereka-lms deployment/lms \
  lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${GIT_SHA}

# Watch rollout
kubectl rollout status -n mereka-lms deployment/lms --timeout=10m
```

**Expected output**:
```
deployment "lms" successfully rolled out
```

## Step 5: Verify mereka_tenancy Module Installed

```bash
# Verify module is importable
kubectl exec -n mereka-lms deploy/lms -- python -c "import mereka_tenancy; print(f'mereka_tenancy version: {mereka_tenancy.__version__}')"
```

**Expected output**:
```
mereka_tenancy version: 1.0.0
```

## Step 6: Verify TenantResolutionMiddleware Active

```bash
# Check middleware is in MIDDLEWARE list
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.conf import settings
middleware_list = [m for m in settings.MIDDLEWARE]
tenant_mw = 'mereka_tenancy.middleware.TenantResolutionMiddleware'
if tenant_mw in middleware_list:
    idx = middleware_list.index(tenant_mw)
    print(f'✓ TenantResolutionMiddleware at position {idx}')
    print(f'✓ Middleware: {middleware_list[idx-1:idx+2]}')
else:
    print('✗ TenantResolutionMiddleware NOT FOUND')
    exit(1)
"
```

**Expected output**:
```
✓ TenantResolutionMiddleware at position XX
✓ Middleware: ['django.contrib.sites.middleware.CurrentSiteMiddleware', 'mereka_tenancy.middleware.TenantResolutionMiddleware', ...]
```

## Step 7: Provision 3 Tenants

```bash
# Run batch provisioning script
./scripts/tenants/provision-all-tenants.sh

# OR provision individually:

# 1. MEREKA tenant
./scripts/tenants/provision-tenant.sh \
  --slug mereka \
  --name "Mereka Academy" \
  --domain academyv2.mereka.io \
  --contact-email team@mereka.io \
  --country MY

# 2. BIJIBIJI tenant
./scripts/tenants/provision-tenant.sh \
  --slug bijibiji \
  --name "Biji-Biji Initiative" \
  --domain academy.biji-biji.com \
  --contact-email admin@biji-biji.com \
  --country MY

# 3. SKILLOURFUTURE tenant
./scripts/tenants/provision-tenant.sh \
  --slug skillourfuture \
  --name "Skill Our Future" \
  --domain skillourfuture.academy.mereka.io \
  --contact-email admin@mereka.io \
  --country MY
```

**Expected output** (per tenant):
```
[1/11] Validating tenant slug...
[2/11] Creating or retrieving Django Site...
[3/11] Creating or retrieving SiteConfiguration...
[4/11] Creating or retrieving EnterpriseCustomer...
[5/11] Creating or retrieving TenantConfig...
...
✓ Tenant provisioned successfully
  EnterpriseCustomer UUID: <uuid>
  Domain: <domain>
```

## Step 8: Verify EnterpriseCustomer Records

```bash
# Count EnterpriseCustomer records
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
count = EnterpriseCustomer.objects.count()
print(f'EnterpriseCustomer count: {count}')
for ec in EnterpriseCustomer.objects.all():
    print(f'  - {ec.name} ({ec.uuid})')
"
```

**Expected output**:
```
EnterpriseCustomer count: 3
  - Mereka Academy (<uuid>)
  - Biji-Biji Initiative (<uuid>)
  - Skill Our Future (<uuid>)
```

## Step 9: Run Full Verification

```bash
# Run tenant isolation verification script
bash scripts/qa/verify-tenant-isolation.sh
```

**Expected output** (target: 10/10 PASS):
```
=== Tenant Isolation Verification ===

Section 1: Management Command Structure
✓ provision_tenant.py exists
✓ backfill_xapi_enterprise_uuid.py exists
...

=== Summary ===
PASS: 10
FAIL: 0
SKIP: 0

✓ Verification PASSED
```

## Step 10: Test X-Tenant-ID Header

```bash
# Test MEREKA tenant
curl -I https://academyv2.mereka.io/courses | grep X-Tenant-ID

# Test BIJIBIJI tenant
curl -I https://academy.biji-biji.com/courses | grep X-Tenant-ID

# Test SKILLOURFUTURE tenant
curl -I https://skillourfuture.academy.mereka.io/courses | grep X-Tenant-ID
```

**Expected output** (each domain should have X-Tenant-ID header):
```
X-Tenant-ID: <tenant-uuid>
```

## Rollback Procedure

If deployment fails or causes issues:

```bash
# 1. Revert to previous image
PREVIOUS_TAG="<previous-git-sha>"  # Note this before deployment
kubectl set image -n mereka-lms deployment/lms \
  lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${PREVIOUS_TAG}

# 2. Watch rollback
kubectl rollout status -n mereka-lms deployment/lms

# 3. Verify service restored
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms
curl -I https://academyv2.mereka.io/courses
```

**Rollback notes**:
- Sites and SiteConfiguration records remain (dormant, no code to use them)
- EnterpriseCustomer records remain (safe, no side effects)
- No data loss — all changes are additive

## Post-Deployment Validation

- [ ] All 3 domains accessible (academyv2.mereka.io, academy.biji-biji.com, skillourfuture.academy.mereka.io)
- [ ] X-Tenant-ID header present on all requests
- [ ] Course org filter working (each tenant sees only its org courses)
- [ ] Cookie domain scoping correct (.mereka.io vs .biji-biji.com)
- [ ] No 500 errors in LMS logs
- [ ] verify-tenant-isolation.sh shows 10/10 PASS

## Monitoring

After deployment, monitor:

```bash
# Watch LMS logs for errors
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=100 -f | grep -i "tenant\|error"

# Check pod health
kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms

# Verify endpoints
kubectl get endpoints -n mereka-lms lms
```

## Troubleshooting

### Issue: mereka_tenancy module not found

**Symptoms**: `ImportError: No module named 'mereka_tenancy'`

**Fix**:
```bash
# Verify image was built with plugin
docker run --rm <image> python -c "import mereka_tenancy; print(mereka_tenancy.__version__)"

# If fails, rebuild image with apply-patches.sh
./infrastructure/tutor/apply-patches.sh
tutor images build openedx
```

### Issue: TenantResolutionMiddleware not in MIDDLEWARE

**Symptoms**: No X-Tenant-ID header on responses

**Fix**:
```bash
# Re-apply patches
./infrastructure/tutor/apply-patches.sh

# Rebuild image
tutor images build openedx

# Redeploy
kubectl set image -n mereka-lms deployment/lms lms=<new-image>
```

### Issue: EnterpriseCustomer provisioning fails

**Symptoms**: `provision_tenant.py` command errors

**Fix**:
```bash
# Check if Site already exists
kubectl exec -n mereka-lms deploy/lms -- python manage.py lms shell -c "
from django.contrib.sites.models import Site
print(Site.objects.filter(domain='academyv2.mereka.io').exists())
"

# If exists, use --dry-run to check what would be created
./scripts/tenants/provision-tenant.sh --slug mereka --name "Mereka" --domain academyv2.mereka.io --dry-run
```

## Success Criteria

Deployment is successful when:

1. ✅ mereka_tenancy module importable in LMS pod
2. ✅ TenantResolutionMiddleware in MIDDLEWARE list
3. ✅ 3 EnterpriseCustomer records exist
4. ✅ X-Tenant-ID header on all domain responses
5. ✅ verify-tenant-isolation.sh shows 10/10 PASS
6. ✅ No 500 errors in logs
7. ✅ All 3 domains accessible and rendering correctly

## Documentation Updates

After successful deployment, update:

- [ ] `docs/architecture/MULTI_TENANCY.md` — Architecture overview
- [ ] `scripts/tenants/PROVISIONING.md` — Tenant provisioning guide
- [ ] `CHANGELOG.md` — Add entry for tenancy epic completion

## Related

- Epic bead: `mereka-lms-1gcr`
- Spec: `specs/multi-tenancy-architecture_spec.md`
- Verification script: `scripts/qa/verify-tenant-isolation.sh`
- Provisioning script: `scripts/tenants/provision-tenant.sh`
