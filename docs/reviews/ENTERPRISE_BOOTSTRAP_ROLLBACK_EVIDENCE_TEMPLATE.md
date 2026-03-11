# Enterprise Bootstrap Rollback Evidence Template

> Fill this template if rollback is needed after a failed or incorrect bootstrap.
> Save completed version to `var/proofs/enterprise-bootstrap-rollback-dev.md`.

## Rollback Metadata

| Field | Value |
|-------|-------|
| Date | `YYYY-MM-DD HH:MM UTC` |
| Executor | (name / agent ID) |
| Environment | dev |
| Reason for rollback | (describe what went wrong) |
| Original apply evidence | `var/proofs/enterprise-bootstrap-evidence-dev.md` |

## Pre-Rollback State

### Enterprise Customers Before Rollback

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer, EnterpriseCustomerCatalog, EnterpriseCustomerUser
for ec in EnterpriseCustomer.objects.all():
    cats = EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec).count()
    users = EnterpriseCustomerUser.objects.filter(enterprise_customer=ec).count()
    print(f'{ec.slug}: uuid={ec.uuid}, catalogs={cats}, users={users}')
"
```

```
(paste output here)
```

## Rollback Commands Executed

### Per-Tenant Deletion

For each tenant being rolled back, record the commands run:

```python
# In Django shell:
# kubectl exec -it -n mereka-lms-dev deploy/lms -- python manage.py lms shell

from enterprise.models import (
    EnterpriseCustomer,
    EnterpriseCustomerCatalog,
    EnterpriseCustomerUser,
)

# Tenant: <slug>
ec = EnterpriseCustomer.objects.get(slug="<slug>")
cat_count = EnterpriseCustomerCatalog.objects.filter(enterprise_customer=ec).delete()
user_count = EnterpriseCustomerUser.objects.filter(enterprise_customer=ec).delete()
ec.delete()
print(f"Deleted: {ec.slug}, catalogs={cat_count}, users={user_count}")
```

### Rollback Log

| Tenant | Catalogs Deleted | Users Deleted | EC Deleted | Verified |
|--------|-----------------|---------------|------------|----------|
| mereka | | | YES / NO | YES / NO |
| bijibiji | | | YES / NO | YES / NO |
| skillourfuture | | | YES / NO | YES / NO |

## Post-Rollback Verification

### Enterprise Customer Count

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
print(f'EC count: {EnterpriseCustomer.objects.count()}')
"
```

Expected: `EC count: 0` (if full rollback) or previous count

```
(paste output here)
```

### Waffle Switch Cleanup

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from waffle.models import Switch
enterprise_switches = Switch.objects.filter(name__startswith='enterprise.')
for s in enterprise_switches:
    print(f'{s.name}: active={s.active}')
print(f'Total: {enterprise_switches.count()}')
# To delete: enterprise_switches.delete()
"
```

```
(paste output here)
```

### Portal State After Rollback

| Check | Expected | Actual |
|-------|----------|--------|
| Admin portal | Still renders (no enterprise data) | |
| Learner portal | Still renders (empty catalog) | |
| LMS main site | Unaffected | |

## Rollback Verdict

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Enterprise customers remaining | 0 (or pre-bootstrap count) | | PASS / FAIL |
| Catalogs remaining | 0 (or pre-bootstrap count) | | PASS / FAIL |
| User links remaining | 0 (or pre-bootstrap count) | | PASS / FAIL |
| LMS unaffected | yes | | PASS / FAIL |
| Portals still render | yes | | PASS / FAIL |

**Rollback**: COMPLETE / PARTIAL / FAILED
