# Infra Team Action Items (2026-03-05)

## P0: Fix Environment Isolation — ExternalSecrets Store Mismatch

**Problem**: All mereka-lms ExternalSecrets on rke2-nonprod use `infisical-secret-store` (prod environment). Dev should use `infisical-secret-store-dev`, staging should use `infisical-secret-store-staging`.

**Evidence**:
```
$ kubectl get externalsecret -n mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}: store={.spec.secretStoreRef.name}{"\n"}{end}'
database-secrets: store=infisical-secret-store       # WRONG — should be infisical-secret-store-dev
enterprise-secrets: store=infisical-secret-store      # WRONG
openedx-secrets: store=infisical-secret-store         # WRONG
payments-gateway-secrets: store=infisical-secret-store # WRONG

$ kubectl get externalsecret -n stg-mereka-lms -o jsonpath='{range .items[*]}{.metadata.name}: store={.spec.secretStoreRef.name}{"\n"}{end}'
database-secrets: store=infisical-secret-store        # WRONG — should be infisical-secret-store-staging
```

The stores exist and are valid:
```
$ kubectl get clustersecretstore
infisical-secret-store           Valid   ReadOnly   True    (env: prod)
infisical-secret-store-dev       Valid   ReadOnly   True    (env: dev)
infisical-secret-store-staging   Valid   ReadOnly   True    (env: staging)
```

**Fix**: In `bbi-infrastructure`, the ArgoCD ApplicationSet or per-app overlays need to patch `.spec.secretStoreRef.name` on each ExternalSecret:

For `mereka-lms-dev` (namespace `mereka-lms`):
```yaml
# In bbi-infrastructure overlay for dev
patches:
  - target:
      group: external-secrets.io
      version: v1
      kind: ExternalSecret
    patch: |
      - op: replace
        path: /spec/secretStoreRef/name
        value: infisical-secret-store-dev
```

For `mereka-lms-staging` (namespace `stg-mereka-lms`):
```yaml
patches:
  - target:
      group: external-secrets.io
      version: v1
      kind: ExternalSecret
    patch: |
      - op: replace
        path: /spec/secretStoreRef/name
        value: infisical-secret-store-staging
```

**Risk if unfixed**: Dev/staging read prod secrets. MySQL password mismatch causes pod crashes. Potential data leakage between environments.

---

## P0: Fix MySQL Authentication — Password Mismatch

**Problem**: MySQL root password in `database-secrets` (from Infisical prod env) doesn't match what MySQL was initialized with.

**Evidence**:
```
django.db.utils.OperationalError: (1045, "Access denied for user 'license_manager'@'10.100.1.88' (using password: YES)")
```

MySQL pod was created Jan 15, 2026. Password is baked into `/var/lib/mysql` at first boot. If the Infisical secret was changed after that date, the new password won't work.

**Fix options**:

### Option A: Reset MySQL password to match current Infisical value (preferred)
```bash
# 1. Get current password from Infisical
MYSQL_PW=$(kubectl get secret database-secrets -n mereka-lms \
  -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d)

# 2. Exec into MySQL pod with --skip-grant-tables
kubectl exec -n mereka-lms mysql-f7c74bff-4sszr -c mysql -- \
  mysqladmin -u root password "$MYSQL_PW"

# OR if that doesn't work, use init file approach:
# - Scale MySQL to 0
# - Mount a ConfigMap with SQL: ALTER USER 'root'@'%' IDENTIFIED BY 'new_pw';
# - Start with --init-file
# - Scale back to 1
```

### Option B: Update Infisical to match MySQL's actual password
```bash
# 1. Find the original password (check git history, Tutor config backups, etc.)
# 2. Update Infisical dev env:
#    - MEREKA_LMS_MYSQL_ROOT_PASSWORD = <original password>
#    - MEREKA_LMS_MYSQL_PASSWORD = <original openedx user password>
# 3. Wait for ExternalSecret refresh (1h) or force refresh
```

### Also needed: Create MySQL users for enterprise services
After root access is restored, create the missing users:
```sql
CREATE USER IF NOT EXISTS 'license_manager'@'%' IDENTIFIED BY '<pw from MYSQL_LICENSE_MANAGER_PASSWORD>';
CREATE DATABASE IF NOT EXISTS license_manager;
GRANT ALL ON license_manager.* TO 'license_manager'@'%';

CREATE USER IF NOT EXISTS 'enterprise_access'@'%' IDENTIFIED BY '<pw from MYSQL_ENTERPRISE_ACCESS_PASSWORD>';
CREATE DATABASE IF NOT EXISTS enterprise_access;
GRANT ALL ON enterprise_access.* TO 'enterprise_access'@'%';

-- Repeat for enterprise_catalog, enterprise_subsidy
```

---

## P1: Deploy ARC Controller (CRDs Missing)

**Problem**: `arc-runners-heavy` ArgoCD app is OutOfSync because `AutoscalingRunnerSet` CRD doesn't exist on the cluster. No ARC controller was ever deployed.

**Evidence**:
```
$ kubectl get crd | grep actions
(empty)

$ kubectl get app arc-runners-heavy -n argocd -o jsonpath='{.status.operationState.syncResult.resources[0].message}'
"The Kubernetes API could not find actions.github.com/AutoscalingRunnerSet for requested resource arc-runners/mereka-k8s-heavy-builders. Make sure the 'AutoscalingRunnerSet' CRD is installed on the destination cluster."
```

**Impact**: Both "Build Tutor Images" and "Build Enterprise MFEs" GitHub Actions workflows are stuck queued for 8+ hours waiting for `mereka-k8s-heavy-builders` runners.

**Fix**: Deploy ARC controller Helm chart:
```bash
helm install arc \
  --namespace arc-systems --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  -f deploy/k8s/base/arc/helm-values.yaml

# Then sync the runner set
argocd app sync arc-runners-heavy
```

See `docs/ops/ci-cd/CI_CD_RUNNERS.md` for full setup.

---

## P2: Populate Infisical Dev Environment Secrets

Once environment isolation is fixed (P0), the `dev` environment in Infisical needs all `MEREKA_LMS_*` secrets populated. Check which keys exist:

```bash
# List all MEREKA_LMS keys in prod env
infisical secrets list --domain https://secrets.mereka.io/api --env prod --path / \
  | grep MEREKA_LMS_ | awk '{print $1}'

# Compare with dev env
infisical secrets list --domain https://secrets.mereka.io/api --env dev --path / \
  | grep MEREKA_LMS_ | awk '{print $1}'
```

Every key in prod must have a corresponding key in dev (with dev-appropriate values — different passwords, dev Stripe keys, etc.).
