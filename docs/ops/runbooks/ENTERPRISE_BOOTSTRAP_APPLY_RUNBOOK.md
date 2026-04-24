# Enterprise Bootstrap Apply Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

> Step-by-step guide to bootstrap enterprise tenant data in the dev environment.
>
> **Status**: READY — waiting for runtime blocker to close before apply.
> **Risk**: LOW — idempotent, reversible, dev environment only.

## Prerequisites

Before running `--apply`:

- [ ] Runtime blocker resolved (enterprise admin/learner MFE renders)
- [ ] Operator has chosen variant (shared-mereka or partner-isolated)
- [ ] Slug decision finalized (`bijibiji` recommended — see ENTERPRISE_TENANT_VARIANTS.md)
- [ ] LMS pod is running and accessible via `kubectl exec`
- [ ] `pyyaml` available in LMS Python environment (standard in Open edX)
- [ ] Bootstrap spec file copied to LMS pod or accessible via mount

## Step 1: Choose variant

```bash
# Recommended: shared-mereka (partner tenants see MEREKA courses)
cp config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml \
   config/enterprise-tenants/dev.enterprise-tenants.yaml

# Alternative: partner-isolated (partner tenants see only their own courses)
# cp config/enterprise-tenants/dev.enterprise-tenants.partner-isolated.yaml \
#    config/enterprise-tenants/dev.enterprise-tenants.yaml
```

## Step 2: Dry run

```bash
# From repo root (if spec is accessible from LMS pod):
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/bootstrap-enterprise-tenants.py \
    --env dev

# Or copy spec to pod first:
kubectl cp config/enterprise-tenants/dev.enterprise-tenants.yaml \
    mereka-lms-dev/$(kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}'):/tmp/spec.yaml

kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/bootstrap-enterprise-tenants.py \
    --env dev
```

**Expected output**: List of CREATE/ENSURE actions for each tenant. No errors.

**Review**: Verify the dry-run output matches your expectations before proceeding.

## Step 3: Apply

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/bootstrap-enterprise-tenants.py \
    --env dev --apply
```

**Expected output**: CREATED confirmations for each record. No errors.

## Step 4: Validate

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/validate-enterprise-tenants.py

# With spec comparison:
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/validate-enterprise-tenants.py \
    --spec /openedx/config/enterprise-tenants/dev.enterprise-tenants.yaml

# Machine-readable output:
kubectl exec -n mereka-lms-dev deploy/lms -- python \
    /openedx/scripts/tenants/validate-enterprise-tenants.py --json
```

**Expected**: All enterprise customers present, catalogs present, user links present. No GAP/MISSING warnings.

## Step 5: Verify portals

After bootstrap AND runtime blocker is resolved:

```bash
# Enterprise admin portal should show catalog
curl -sI https://admin.academyv2.mereka.dev/ | head -5

# Enterprise learner portal should show courses
curl -sI https://learner.academyv2.mereka.dev/ | head -5

# LMS enterprise API should return customer data
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
for ec in EnterpriseCustomer.objects.all():
    print(f'{ec.slug}: uuid={ec.uuid}, active={ec.active}, site={ec.site.domain}')
"
```

## Step 6: Capture proofs

After successful apply, capture:

- [ ] `validate-enterprise-tenants.py --json` output saved to `var/proofs/enterprise-bootstrap-dev.json`
- [ ] Enterprise customer count = 3
- [ ] Catalog count per customer >= 1
- [ ] User links exist for admin emails
- [ ] Enterprise admin portal loads (screenshot or HTTP 200)
- [ ] Enterprise learner portal loads (screenshot or HTTP 200)

## Rollback Plan

The bootstrap tool creates records but does not delete existing ones. To rollback:

```bash
# Via Django shell (LMS pod):
kubectl exec -it -n mereka-lms-dev deploy/lms -- python manage.py lms shell

# In the shell:
from enterprise.models import EnterpriseCustomer, EnterpriseCustomerCatalog, EnterpriseCustomerUser

# List what was created:
for ec in EnterpriseCustomer.objects.all():
    print(f"EC: {ec.slug} ({ec.uuid})")
    for cat in EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec):
        print(f"  Catalog: {cat.title} ({cat.uuid})")
    for user in EnterpriseCustomerUser.objects.filter(enterprise_customer=ec):
        print(f"  User: {user.user_id}")

# To remove a specific enterprise customer and all related records:
# ec = EnterpriseCustomer.objects.get(slug="mereka")
# EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec).delete()
# EnterpriseCustomerUser.objects.filter(enterprise_customer=ec).delete()
# ec.delete()
```

**WARNING**: Do not rollback in production without coordination. Dev environment rollback is safe.

## Things NOT done before runtime blocker closes

- [ ] Production bootstrap (prod spec not created yet)
- [ ] Staging bootstrap (staging spec not created yet)
- [ ] Enterprise enrollment creation (happens naturally via learner portal)
- [ ] License pool setup (no business requirement defined yet)
- [ ] Integrated channel configuration (no external LMS targets)
- [ ] Subsidy ledger initialization (no budget pools defined)
- [ ] Per-tenant branding in enterprise portals (shared Mereka theme for now)
