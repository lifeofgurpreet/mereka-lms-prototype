# Enterprise Bootstrap Evidence Template

> Fill this template after running `bootstrap-enterprise-tenants.py --apply`.
> Save completed version to `var/proofs/enterprise-bootstrap-evidence-dev.md`.

## Execution Metadata

| Field | Value |
|-------|-------|
| Date | `YYYY-MM-DD HH:MM UTC` |
| Executor | (name / agent ID) |
| Environment | dev |
| Variant applied | `shared-mereka` / `partner-isolated` |
| Spec file | `config/enterprise-tenants/dev.enterprise-tenants.yaml` |
| LMS pod | (pod name) |
| Commit SHA | (HEAD of main at execution time) |

## Pre-Apply Checks

| Check | Status | Evidence |
|-------|--------|----------|
| LMS pod running | PASS / FAIL | `kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms` output |
| Enterprise admin portal HTTP response | PASS / FAIL | `curl -sI https://admin.academyv2.mereka.dev/` |
| Enterprise learner portal HTTP response | PASS / FAIL | `curl -sI https://learner.academyv2.mereka.dev/` |
| Spec copied to pod | PASS / FAIL | `kubectl cp` command output |
| Dry-run output reviewed | PASS / FAIL | Paste dry-run output below |

### Dry-Run Output

```
(paste full dry-run output here)
```

## Apply Output

```
(paste full --apply output here)
```

## Post-Apply Validation

### validate-enterprise-tenants.py Output

```
(paste full validation output here)
```

### validate-enterprise-tenants.py --json Output

Save to: `var/proofs/enterprise-bootstrap-dev.json`

```json
(paste JSON output here)
```

## Expected Objects — Enterprise Customers

| Slug | Name | Active | Site Domain | Verified |
|------|------|--------|-------------|----------|
| mereka | Mereka Academy | true | academyv2.mereka.dev | YES / NO |
| bijibiji | Biji-Biji Academy | true | academy.biji-biji.com | YES / NO |
| skillourfuture | Skill Our Future | true | skillourfuture.academy.mereka.io | YES / NO |

### Verification Command

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomer
for ec in EnterpriseCustomer.objects.all():
    print(f'{ec.slug}: uuid={ec.uuid}, active={ec.active}, site={ec.site.domain}')
"
```

```
(paste output here)
```

## Expected Objects — Catalogs

| Tenant | Catalog Title | org_filter | Verified |
|--------|---------------|------------|----------|
| mereka | Mereka Academy Full Catalog | `['MEREKA']` | YES / NO |
| bijibiji | Biji-Biji Academy Catalog | `['BIJIBIJI', 'MEREKA']` (shared) or `['BIJIBIJI']` (isolated) | YES / NO |
| skillourfuture | Skill Our Future Catalog | `['SKILLOURFUTURE', 'MEREKA']` (shared) or `['SKILLOURFUTURE']` (isolated) | YES / NO |

### Verification Command

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomerCatalog
for cat in EnterpriseCustomerCatalog.objects.all():
    print(f'{cat.enterprise_customer.slug}: {cat.title} filter={cat.content_filter}')
"
```

```
(paste output here)
```

## Expected Objects — User Links

| Tenant | Email | Role | Verified |
|--------|-------|------|----------|
| mereka | team@mereka.io | admin | YES / NO |
| bijibiji | admin@biji-biji.com | admin | YES / NO |
| skillourfuture | admin@mereka.io | admin | YES / NO |

### Verification Command

```bash
kubectl exec -n mereka-lms-dev deploy/lms -- python manage.py lms shell -c "
from enterprise.models import EnterpriseCustomerUser
for ecu in EnterpriseCustomerUser.objects.select_related('enterprise_customer').all():
    print(f'{ecu.enterprise_customer.slug}: user_id={ecu.user_id}, active={ecu.active}')
"
```

```
(paste output here)
```

## Expected Objects — Waffle Switches

| Switch Pattern | Count | Verified |
|----------------|-------|----------|
| `enterprise.enable_learner_portal.<slug>` | 3 (all on) | YES / NO |
| `enterprise.enable_analytics_screen.<slug>` | 3 (all on) | YES / NO |
| `enterprise.enable_audit_enrollment.<slug>` | 3 (all off) | YES / NO |
| `enterprise.enable_portal_code_management.<slug>` | 3 (all off) | YES / NO |
| `enterprise.enable_integrated_learner_portal_search.<slug>` | 3 (all on) | YES / NO |

## Expected — Enrollments

| Tenant | Expected Count | Notes |
|--------|---------------|-------|
| mereka | 0 initially | Enrollments created via learner portal |
| bijibiji | 0 initially | Enrollments created via learner portal |
| skillourfuture | 0 initially | Enrollments created via learner portal |

## Screenshots Required

| Screenshot | Path | Captured |
|------------|------|----------|
| Enterprise admin portal login page | `assets/screenshots-of-issues/enterprise-admin-portal.png` | YES / NO |
| Enterprise learner portal landing | `assets/screenshots-of-issues/enterprise-learner-portal.png` | YES / NO |
| Admin portal catalog view (if accessible) | `assets/screenshots-of-issues/enterprise-admin-catalog.png` | YES / NO |

## Final Verdict

| Metric | Expected | Actual | Status |
|--------|----------|--------|--------|
| Enterprise customers | 3 | | PASS / FAIL |
| Catalogs | 3 | | PASS / FAIL |
| User links | 3 | | PASS / FAIL |
| Waffle switches | 15 | | PASS / FAIL |
| Errors | 0 | | PASS / FAIL |
| Admin portal HTTP 200/302 | yes | | PASS / FAIL |
| Learner portal HTTP 200/302 | yes | | PASS / FAIL |

**Overall**: PASS / FAIL
