# Runtime Proof Fixture Rollback Packet

> **Lane**: lane-i (Runtime Proof Fixture Contract)
> **Environment**: dev
> **Applies to**: future apply runs (mutation not yet wired in this lane)
> **Contract**: `docs/stabilization/SYNTHETIC_RUNTIME_PROOF_FIXTURE_CONTRACT.md`

---

## Rollback Scope

This packet covers rollback of synthetic runtime proof fixtures only. It does NOT cover:

- Real tenant data (`config/enterprise-tenants/`)
- Production EnterpriseCustomer records
- Real operator user accounts
- Waffle flags set by other processes

**Rollback applies only to records that match the synthetic naming convention:**

| Object type | Synthetic identifier | How to distinguish |
|-------------|---------------------|--------------------|
| LMS user accounts | username prefix `lanea-` | `User.objects.filter(username__startswith='lanea-')` |
| LMS user emails | domain `@synthetic.test` | `User.objects.filter(email__endswith='@synthetic.test')` |
| Enterprise customer | contact_email ends in `@synthetic.test` | `EnterpriseCustomer.objects.filter(contact_email__endswith='@synthetic.test')` |
| Enterprise user links | linked user email ends in `@synthetic.test` | Traverse `EnterpriseCustomerUser.user.email` |
| Waffle switches | name contains `.biji-biji-initiative` AND switch was created by this tool | Check switch `created` timestamp vs bootstrap run time |

---

## What Can Be Safely Removed

The following objects were created exclusively by the synthetic bootstrap tool and have
no real-user dependency:

- LMS `User` records with `username__startswith='lanea-'`
- `EnterpriseCustomerUser` records where the linked user has `email__endswith='@synthetic.test'`
- Waffle `Switch` objects with pattern `*.biji-biji-initiative` created by this tool
  (verify against a pre-bootstrap waffle switch list before deleting)
- Enterprise-catalog service `EnterpriseCatalog` records linked to the synthetic enterprise UUID
  (obtain UUID from bootstrap output before deleting)

---

## What NOT to Remove

| Object | Why |
|--------|-----|
| `EnterpriseCustomer` with slug `biji-biji-initiative` if contact_email is NOT `@synthetic.test` | This would be a real tenant record, pre-existing before bootstrap. Never delete. |
| Any `EnterpriseCustomerCatalog` linked to a real enterprise customer | Could break real learner enrollments. |
| Platform-wide waffle flags not created by this tool | Other processes may depend on them. |
| Waffle switches for tenant slugs other than `biji-biji-initiative` | Not in scope. |
| Any object whose creation predates the synthetic bootstrap run | Pre-existing records must not be touched. |

---

## How to Distinguish Synthetic from Real Records

### Naming Convention

All synthetic objects follow strict naming rules defined in the contract:

| Prefix/domain | Scope | Example |
|---------------|-------|---------|
| `lanea-` | LMS usernames | `lanea-enterprise-learner` |
| `@synthetic.test` | All synthetic emails | `lanea-enterprise-admin@synthetic.test` |

No real operator or learner account will ever have a `@synthetic.test` email. This domain is not
a valid IANA TLD and cannot receive email. If a `@synthetic.test` email appears in a user record,
it was created by this bootstrap tool.

### Verification Before Rollback

Before deleting any record, run the following shell commands (from inside an LMS pod) to
confirm the record is synthetic:

```bash
# Check user is synthetic
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
for u in User.objects.filter(username__startswith='lanea-'):
    print(f'{u.username}: {u.email}')
"

# Check enterprise customer contact email
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
for ec in EnterpriseCustomer.objects.filter(contact_email__endswith='@synthetic.test'):
    print(f'{ec.slug}: {ec.contact_email}')
"

# Check enterprise user links for synthetic users
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomerUser
for ecu in EnterpriseCustomerUser.objects.select_related('user', 'enterprise_customer').all():
    if ecu.user.email.endswith('@synthetic.test'):
        print(f'{ecu.enterprise_customer.slug} / {ecu.user.username}')
"

# List waffle switches for biji-biji-initiative
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from waffle.models import Switch
for s in Switch.objects.filter(name__contains='biji-biji-initiative'):
    print(f'{s.name}: active={s.active}')
"
```

---

## Rollback Commands (Future Apply — Not Yet Wired)

These commands would be used after a future apply run creates real DB records.
Do not run these in the current lane (no mutation has occurred yet).

```bash
# Delete synthetic LMS users (ONLY after confirming they are lanea- prefixed)
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
to_delete = list(User.objects.filter(username__startswith='lanea-'))
print(f'Will delete {len(to_delete)} synthetic users:')
for u in to_delete:
    print(f'  {u.username} ({u.email})')
# Uncomment to execute:
# User.objects.filter(username__startswith='lanea-').delete()
"

# Delete synthetic enterprise customer (only if contact_email is @synthetic.test)
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
ec = EnterpriseCustomer.objects.filter(
    slug='biji-biji-initiative',
    contact_email__endswith='@synthetic.test'
).first()
if ec:
    print(f'Will delete: {ec.slug} ({ec.contact_email})')
    # Uncomment to execute (cascades to catalogs and user links):
    # ec.delete()
else:
    print('No synthetic biji-biji-initiative enterprise customer found. Nothing to delete.')
"

# Remove tenant-scoped waffle switches
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from waffle.models import Switch
switches = Switch.objects.filter(name__contains='.biji-biji-initiative')
print(f'Will delete {switches.count()} waffle switches:')
for s in switches:
    print(f'  {s.name}')
# Uncomment to execute:
# switches.delete()
"
```

---

## Required Rollback Evidence

After executing a rollback, capture the following:

| Evidence item | How to capture |
|---------------|---------------|
| Pre-rollback user list | Output of user listing command above |
| Pre-rollback enterprise customer state | Output of EC listing command above |
| Post-rollback user count | `User.objects.filter(username__startswith='lanea-').count()` → must be 0 |
| Post-rollback EC state | EC listing → `biji-biji-initiative` with `@synthetic.test` must be absent |
| Post-rollback waffle switches | Switch listing → `*.biji-biji-initiative` count must be 0 |
| Git commit SHA | `git rev-parse HEAD` |
| Rollback timestamp | `date -u +%Y-%m-%dT%H:%M:%SZ` |

---

## Safety Checklist Before Executing Rollback

- [ ] Confirmed that no real learner is enrolled via the synthetic enterprise customer
- [ ] Confirmed that no real operator email is associated with `lanea-` username
- [ ] Confirmed that the `biji-biji-initiative` EnterpriseCustomer contact_email is `@synthetic.test`
  (if it is NOT `@synthetic.test`, this is a real tenant record — do not delete)
- [ ] Rollback is limited to `mereka-lms-dev` namespace — not staging, not production
- [ ] Post-rollback verification commands are ready to run
