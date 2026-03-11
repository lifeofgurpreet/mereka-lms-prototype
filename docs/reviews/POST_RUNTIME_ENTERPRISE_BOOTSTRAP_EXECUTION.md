# Post-Runtime Enterprise Bootstrap Execution Packet

> Execute this ONLY after the runtime blocker (`fix/enterprise-mfe-build-config`)
> is merged and enterprise MFE portals render in the browser.

## Prerequisites Checklist

- [ ] PR `fix/enterprise-mfe-build-config` merged to main
- [ ] ArgoCD has synced the new MFE image to the dev cluster
- [ ] Enterprise admin portal responds: `curl -sI https://admin.academyv2.mereka.dev/ | head -5`
- [ ] Enterprise learner portal responds: `curl -sI https://learner.academyv2.mereka.dev/ | head -5`
- [ ] Operator has chosen variant (see `ENTERPRISE_OPERATOR_DECISION_PACKET.md`)
- [ ] LMS pod is running: `kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms`

## Step 1: Select Variant

```bash
# RECOMMENDED: shared-mereka (partners see MEREKA courses)
cp config/enterprise-tenants/dev.enterprise-tenants.shared-mereka.yaml \
   config/enterprise-tenants/dev.enterprise-tenants.yaml

# ALTERNATIVE: partner-isolated (partners see only own courses — currently 0)
# cp config/enterprise-tenants/dev.enterprise-tenants.partner-isolated.yaml \
#    config/enterprise-tenants/dev.enterprise-tenants.yaml
```

## Step 2: Copy Spec to LMS Pod

```bash
LMS_POD=$(kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[0].metadata.name}')

kubectl cp config/enterprise-tenants/dev.enterprise-tenants.yaml \
  mereka-lms-dev/${LMS_POD}:/tmp/spec.yaml

kubectl cp scripts/tenants/bootstrap-enterprise-tenants.py \
  mereka-lms-dev/${LMS_POD}:/tmp/bootstrap.py

kubectl cp scripts/tenants/validate-enterprise-tenants.py \
  mereka-lms-dev/${LMS_POD}:/tmp/validate.py
```

## Step 3: Dry Run

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/bootstrap.py --env dev
```

**Expected output**: 3 tenants, ~30 actions (CREATE/ENSURE), 0 errors.

Review the output. Confirm it matches the expected dry-run in:
- `docs/reviews/ENTERPRISE_BOOTSTRAP_DRYRUN_SHARED_MEREKA.md` (if shared-mereka)
- `docs/reviews/ENTERPRISE_BOOTSTRAP_DRYRUN_PARTNER_ISOLATED.md` (if partner-isolated)

## Step 4: Apply

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/bootstrap.py --env dev --apply
```

**Expected output**: CREATED confirmations for each record. 0 errors.

## Step 5: Validate

```bash
# Basic validation
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/validate.py

# JSON output for proof capture
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/validate.py --json \
  > var/proofs/enterprise-bootstrap-dev.json
```

**Expected validation**:
- Enterprise customer count = 3
- Each customer has >= 1 catalog
- User links exist for admin emails
- No GAP/MISSING warnings

## Step 6: Verify Portals

```bash
# Enterprise admin portal
curl -sI https://admin.academyv2.mereka.dev/ | head -5
# Expected: HTTP 200 or 302 (redirect to login)

# Enterprise learner portal
curl -sI https://learner.academyv2.mereka.dev/ | head -5
# Expected: HTTP 200 or 302

# LMS enterprise API
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
for ec in EnterpriseCustomer.objects.all():
    print(f'{ec.slug}: uuid={ec.uuid}, active={ec.active}, site={ec.site.domain}')
"
```

## Step 7: Capture Evidence

Save the following proofs:

| Evidence | Command | Save to |
|----------|---------|---------|
| Validation JSON | `validate.py --json` | `var/proofs/enterprise-bootstrap-dev.json` |
| EC count | Django shell query | Screenshot or text output |
| Admin portal HTTP | `curl -sI` | Text output |
| Learner portal HTTP | `curl -sI` | Text output |
| Catalog content | Admin portal screenshot | `assets/screenshots-of-issues/` |

```bash
# Create proof directory
mkdir -p var/proofs

# Capture validation
kubectl exec -n mereka-lms-dev deploy/lms -- python /tmp/validate.py --json \
  > var/proofs/enterprise-bootstrap-dev.json

# Capture portal responses
curl -sI https://admin.academyv2.mereka.dev/ \
  > var/proofs/enterprise-admin-portal-response.txt

curl -sI https://learner.academyv2.mereka.dev/ \
  > var/proofs/enterprise-learner-portal-response.txt
```

## Rollback

The bootstrap tool creates records but does not delete existing ones. To rollback:

```bash
kubectl exec -it -n mereka-lms-dev deploy/lms -- python manage.py lms shell
```

```python
from enterprise.models import (
    EnterpriseCustomer,
    EnterpriseCustomerCatalog,
    EnterpriseCustomerUser,
)

# List what exists
for ec in EnterpriseCustomer.objects.all():
    print(f"EC: {ec.slug} ({ec.uuid})")
    for cat in EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec):
        print(f"  Catalog: {cat.title} ({cat.uuid})")
    for user in EnterpriseCustomerUser.objects.filter(enterprise_customer=ec):
        print(f"  User: {user.user_id}")

# To remove a specific tenant (CAREFUL — dev only):
# ec = EnterpriseCustomer.objects.get(slug="bijibiji")
# EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec).delete()
# EnterpriseCustomerUser.objects.filter(enterprise_customer=ec).delete()
# ec.delete()
```

**WARNING**: Do not rollback in production without coordination.

## What This Does NOT Do

- [ ] Production bootstrap (no prod spec exists yet)
- [ ] Staging bootstrap (no staging spec exists yet)
- [ ] Enterprise enrollment creation (happens via learner portal)
- [ ] License pool setup (no business requirement)
- [ ] Integrated channel configuration (no external LMS targets)
- [ ] Per-tenant branding (shared Mereka theme for now)
