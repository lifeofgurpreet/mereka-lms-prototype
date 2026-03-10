# Secrets Management Guide
_Audience: Operations & Developers • Owner: Infra Team • Last updated: 2026-02-11_

**Purpose**: Understand how secrets flow through the Mereka LMS platform, how to add/rotate/validate secrets safely, and how to troubleshoot common issues.

**TL;DR**: Secrets flow from Infisical (source of truth) → GCP Secret Manager → ExternalSecrets Operator → K8s Secrets → Application pods. All secrets prefixed `MEREKA_LMS_` in Infisical/GCP. Never hardcode secrets. Always validate with `STRICT=1` before deploying.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Secret Inventory](#secret-inventory)
- [Common Operations](#common-operations)
  - [Adding a New Secret](#adding-a-new-secret)
  - [Rotating an Existing Secret](#rotating-an-existing-secret)
  - [Validating Secrets](#validating-secrets)
- [Secret Locations](#secret-locations)
- [Troubleshooting](#troubleshooting)
- [Security Rules](#security-rules)
- [Related Resources](#related-resources)

---

## Architecture Overview

### The 4-Stage Pipeline

```
┌──────────────┐         ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│  Infisical   │         │  GCP Secret  │         │ ExternalSecr │         │ K8s Secrets  │
│  (Source of  │   →     │   Manager    │   →     │    Operator  │   →     │   (Runtime)  │
│   Truth)     │         │   (Bridge)   │         │    (Sync)    │         │              │
└──────────────┘         └──────────────┘         └──────────────┘         └──────────────┘
      ↑                                                                              ↓
      │                                                                              │
      │                                                                              ▼
      │                                                                    ┌──────────────┐
      │                                                                    │ App Pods     │
      │                                                                    │ (Consume via │
      └────────────────────────── Update flow ──────────────────────────  │  envFrom)    │
                                                                           └──────────────┘
```

**Flow**:
1. **Infisical** (https://secrets.mereka.io) — Central secrets vault, single source of truth
2. **GCP Secret Manager** — Bridge layer (required for ExternalSecrets Operator)
3. **ExternalSecrets Operator** — Syncs GCP SM → K8s Secrets every 1 hour
4. **K8s Secrets** — Runtime secrets consumed by pods via `envFrom`
5. **Application Code** — Reads secrets via `os.environ.get()` pattern

**Key points**:
- Secrets are NEVER committed to git
- All secrets prefixed `MEREKA_LMS_` in Infisical/GCP SM
- K8s secret keys drop the prefix (mapped in ExternalSecret resource)
- Pods restart to pick up new secret values (no automatic reload)

---

## Secret Inventory

### openedx-secrets (33+ keys)

**Purpose**: Core Open edX platform secrets

| Category | Keys | Purpose |
|----------|------|---------|
| **Django Secrets** | `OPENEDX_SECRET_KEY`, `CMS_SECRET_KEY`, `SECRET_KEY` | Django cryptographic keys |
| **MongoDB** | `MONGODB_USERNAME`, `MONGODB_PASSWORD`, `FORUM_MONGODB_SRV` | Atlas connection |
| **JWT Signing** | `JWT_SECRET_KEY_LMS`, `JWT_SECRET_KEY_CMS`, `JWT_SECRET_KEY_DISCOVERY`, `JWT_SECRET_KEY_ECOMMERCE`, `JWT_SECRET_KEY_NOTES`, `JWT_SECRET_KEY_XQUEUE`, `JWT_SECRET_KEY_CREDENTIALS`, `JWT_PRIVATE_SIGNING_JWK` | Service JWT signing (unique per service) |
| **API Keys** | `EDX_API_KEY`, `FORUM_API_KEY` | Platform API access |
| **Service OAuth** | `DISCOVERY_SOCIAL_AUTH_EDX_OAUTH2_SECRET`, `DISCOVERY_BACKEND_OAUTH2_SECRET`, `ECOMMERCE_SOCIAL_AUTH_EDX_OAUTH2_SECRET`, `ECOMMERCE_BACKEND_OAUTH2_SECRET`, `CMS_SOCIAL_AUTH_EDX_OAUTH2_SECRET`, `NOTES_CLIENT_SECRET`, `CREDENTIALS_BACKEND_OAUTH2_SECRET`, `CREDENTIALS_SSO_OAUTH2_SECRET` | Service-to-service auth |
| **Service Django Keys** | `DISCOVERY_SECRET_KEY`, `ECOMMERCE_SECRET_KEY`, `NOTES_SECRET_KEY`, `XQUEUE_SECRET_KEY`, `CREDENTIALS_SECRET_KEY` | Service Django secrets |
| **Stripe** | `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET` | Payment processing |
| **OIDC** | `OIDC_CLIENT_SECRET` | OIDC authentication |

**Total**: 33+ keys (see `specs/secrets-management_spec.md` for complete table)

**K8s Secret**: `openedx-secrets` in `mereka-lms` namespace

### database-secrets (7 keys)

**Purpose**: MySQL database passwords

| Key | Purpose |
|-----|---------|
| `MYSQL_ROOT_PASSWORD` | MySQL root user |
| `OPENEDX_MYSQL_PASSWORD` | OpenEdX database |
| `MYSQL_DISCOVERY_PASSWORD` | Discovery service DB |
| `MYSQL_ECOMMERCE_PASSWORD` | Ecommerce service DB |
| `MYSQL_NOTES_PASSWORD` | Notes service DB |
| `MYSQL_XQUEUE_PASSWORD` | XQueue service DB |
| `MYSQL_CREDENTIALS_PASSWORD` | Credentials service DB |

**K8s Secret**: `database-secrets` in `mereka-lms` namespace

### enterprise-secrets (11 keys)

**Purpose**: Enterprise B2B services (catalog, subsidy, access, license manager)

| Service | Keys | Purpose |
|---------|------|---------|
| **Catalog** | `ENTERPRISE_CATALOG_SECRET_KEY`, `ENTERPRISE_CATALOG_OAUTH2_SECRET`, `MYSQL_ENTERPRISE_CATALOG_PASSWORD` | Enterprise course catalog |
| **Subsidy** | `ENTERPRISE_SUBSIDY_SECRET_KEY`, `ENTERPRISE_SUBSIDY_OAUTH2_SECRET`, `MYSQL_ENTERPRISE_SUBSIDY_PASSWORD` | Subscription management |
| **Access** | `ENTERPRISE_ACCESS_SECRET_KEY`, `ENTERPRISE_ACCESS_OAUTH2_SECRET`, `MYSQL_ENTERPRISE_ACCESS_PASSWORD` | Access control |
| **License Manager** | `LICENSE_MANAGER_SECRET_KEY`, `LICENSE_MANAGER_OAUTH2_SECRET` | License distribution |

**K8s Secret**: `enterprise-secrets` in `mereka-lms` namespace

### Migration Secrets (Not in K8s)

**Purpose**: Data migration from MCT/Kajabi (used only by migration scripts on operator workstations)

**MCT** (`/k8s/mereka-lms/migrations/mct`):
- `MCT_BASE_URL`, `MCT_ENDPT`, `MCT_API_URI`
- `MCT_CLIENT_ID`, `MCT_CLIENT_SECRET`, `MCT_TENANT_ID`
- `MCT_API_VERSION`, `MCT_ACCESS_TOKEN` (optional)

**Kajabi** (`/k8s/mereka-lms/migrations/kajabi`):
- `KAJABI_CLIENT_ID`, `KAJABI_CLIENT_SECRET`, `KAJABI_SITE_ID`
- `KAJABI_WEBHOOK_SECRET`, `KAJABI_EMAIL`, `KAJABI_PASSWORD`

**Note**: Migration secrets are NOT synced to K8s (only used by scripts).

### Atlas Automation Secrets (Not in K8s)

**Purpose**: MongoDB Atlas CLI automation

**Location**: `/k8s/mereka-lms/atlas`

**Keys**:
- `ATLAS_PUBLIC_KEY`, `ATLAS_PRIVATE_KEY`
- `ATLAS_ORG_ID`, `ATLAS_PROJECT_ID`
- `ATLAS_PROFILE` (optional, defaults to `mereka-lms`)

**Note**: Atlas secrets are NOT synced to K8s (only used by scripts).

---

## Common Operations

### Adding a New Secret

**When**: Adding a new service, enabling a new feature, integrating a third-party API.

**Steps**:

1. **Create in Infisical** (both `prod` and `dev` environments):
   ```bash
   # Navigate to secrets.mereka.io
   # Path: /k8s/mereka-lms
   # Add key: MEREKA_LMS_<NAME>
   # Set value (non-empty, non-placeholder)
   ```

2. **Sync to GCP Secret Manager**:
   ```bash
   ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```

   This script:
   - Reads from Infisical `/k8s/mereka-lms`
   - Creates secrets in GCP SM if missing
   - Strips trailing CR/LF bytes automatically
   - Skips existing secrets by default (safe for routine runs)

3. **Add mapping to ExternalSecret**:

   Edit `deploy/k8s/base/secrets/external-secrets.yaml`:

   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: openedx-secrets  # or database-secrets or enterprise-secrets
     namespace: mereka-lms
   spec:
     data:
       - secretKey: MY_NEW_KEY           # Name in K8s Secret (no prefix)
         remoteRef:
           key: MEREKA_LMS_MY_NEW_KEY    # Name in GCP SM (with prefix)
   ```

4. **Validate** (CRITICAL):
   ```bash
   # Check both environments
   STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
   STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
   ```

   Must exit 0 (success). `STRICT=1` enforces:
   - No empty values
   - No placeholder values (`REPLACE_ME`, `CHANGE_ME`, `TODO`)
   - No trailing CR/LF bytes

5. **Apply ExternalSecret**:
   ```bash
   kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml
   ```

6. **Force sync** (don't wait 1 hour):
   ```bash
   kubectl annotate externalsecret openedx-secrets -n mereka-lms \
     force-sync="$(date +%s)" --overwrite
   ```

7. **Verify sync**:
   ```bash
   kubectl get externalsecrets -n mereka-lms
   # STATUS should show: SecretSynced

   kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data}' | jq keys
   # Should include: MY_NEW_KEY
   ```

8. **Restart affected pods**:
   ```bash
   kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
   # Or specific deployment that needs the secret
   ```

9. **Verify application**:
   ```bash
   kubectl exec -it deployment/lms -n mereka-lms -- env | grep MY_NEW_KEY
   # Should show non-empty value
   ```

**Complete example**:
```bash
# Add MEREKA_LMS_NEW_SERVICE_API_KEY to Infisical (via UI)
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
# Edit external-secrets.yaml, add mapping
STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml
kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
kubectl get externalsecrets -n mereka-lms  # Wait for SecretSynced
kubectl rollout restart deployment/lms -n mereka-lms
```

---

### Rotating an Existing Secret

**When**: Secret compromised, leaked, expired, or routine rotation (90-day policy).

**Prerequisites**: Read `docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md` for full procedure.

**Quick steps**:

1. **Update in Infisical**:
   ```bash
   # Navigate to secrets.mereka.io
   # Path: /k8s/mereka-lms
   # Edit: MEREKA_LMS_<NAME>
   # Set new value (ensure no trailing whitespace!)
   ```

2. **Propagate to GCP SM**:
   ```bash
   ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```

   **Note**: By default, this script does NOT overwrite existing GCP SM secrets (safety feature). To force update specific keys (e.g., Stripe rotation):
   ```bash
   OVERWRITE_ALLOWED_REGEX="^MEREKA_LMS_STRIPE_.*" \
     ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```

3. **Validate**:
   ```bash
   STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
   ```

4. **Force ESO refresh**:
   ```bash
   kubectl annotate externalsecret openedx-secrets -n mereka-lms \
     force-sync="$(date +%s)" --overwrite
   ```

5. **Rolling restart**:
   ```bash
   kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
   # Or all deployments:
   # kubectl rollout restart deployment -n mereka-lms
   ```

6. **Verify health**:
   ```bash
   CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
   ./scripts/qa/verify-auth-hardening.sh
   ```

7. **Invalidate old credential**:
   - Stripe: Revoke old key in Stripe dashboard
   - Atlas: Rotate API keys in Atlas console
   - AWS: Deactivate old IAM access key
   - Google: Revoke OAuth2 client secret

8. **Document**:
   - Run `STRICT=1 ./scripts/qa/scan-secrets-fast.sh`
   - Create incident bead if rotation was due to leak
   - Update team changelog

**Rollback if needed**:
```bash
# Revert in Infisical (use version history)
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
kubectl rollout restart deployment/<name> -n mereka-lms
```

---

### Validating Secrets

**3 validation scripts**:

#### 1. infisical-validate-mereka-lms.sh

**Purpose**: Verify all required secrets exist in Infisical at canonical path.

**Usage**:
```bash
# Basic validation
INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh

# Strict validation (enforce no placeholders, no trailing whitespace)
STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh

# Both environments
STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
```

**What it checks**:
- ✅ All `MEREKA_LMS_*` keys in `external-secrets.yaml` exist in Infisical
- ✅ No empty values
- ✅ (`STRICT=1`) No placeholder values (`REPLACE_ME`, `CHANGE_ME`, `TODO`, `TBD`)
- ✅ (`STRICT=1`) No trailing CR/LF bytes in password-type keys
- ⚠️ Reports extra secrets in Infisical not referenced in manifests

**Exit codes**:
- `0` = Pass (all checks succeeded)
- `1` = Fail (missing keys, empty values, or placeholders found)

#### 2. infisical-audit-mereka-lms.sh

**Purpose**: Detect secret sprawl (keys outside canonical path).

**Usage**:
```bash
./scripts/infra/infisical-audit-mereka-lms.sh
```

**What it checks**:
- ✅ No `MEREKA_LMS_*` keys at root path `/`
- ✅ No `MEREKA_LMS_*` keys at legacy path `/mereka-lms` (without `/k8s/`)
- ✅ All keys under canonical `/k8s/mereka-lms`

**If sprawl detected**, run sync script (next section).

#### 3. scan-secrets-fast.sh

**Purpose**: Pre-commit hook validation (no hardcoded secrets in git).

**Usage**:
```bash
# Quick scan
./scripts/qa/scan-secrets-fast.sh

# Strict mode (fail on any findings)
STRICT=1 ./scripts/qa/scan-secrets-fast.sh
```

**What it checks**:
- ✅ No hardcoded passwords in YAML/JSON/Python
- ✅ No API keys with values
- ✅ No AWS credentials (`AKIA*`)
- ✅ No private keys (`BEGIN RSA PRIVATE KEY`)
- ✅ No JWTs (`eyJ*`)
- ✅ No database URIs with embedded credentials
- ✅ No placeholder values (`CHANGE_ME`, `changeme`)

**False positives**: Script excludes:
- `secretKeyRef`, `secretRef`, `remoteRef` (K8s patterns)
- Comments (`#`, `//`)
- Documentation files (`*.md`, `*.txt`)

---

## Secret Locations

### Infisical Paths

| Path | Purpose | Synced to K8s? |
|------|---------|----------------|
| `/k8s/mereka-lms` | Core Open edX secrets (33 openedx + 7 database + 11 enterprise) | ✅ Yes |
| `/k8s/mereka-lms/atlas` | MongoDB Atlas CLI keys | ❌ No (script-only) |
| `/k8s/mereka-lms/migrations/mct` | MCT migration credentials | ❌ No (script-only) |
| `/k8s/mereka-lms/migrations/kajabi` | Kajabi migration credentials | ❌ No (script-only) |
| `/shared/oauth` | Shared admin/test credentials (Google impersonation) | ❌ No (manual use) |

**Naming rule**: All secrets prefixed `MEREKA_LMS_` except those under `/shared/`.

### GCP Secret Manager

**Project**: `bbi-k8`

**Secrets**: All `MEREKA_LMS_*` keys from Infisical `/k8s/mereka-lms`

**Access**: ExternalSecrets Operator service account `external-secrets-gcp` with roles:
- `roles/secretmanager.secretAccessor` (read payload)
- `roles/secretmanager.viewer` (read metadata)

**Versioning**: Latest version used (`LatestOrFail` policy).

### K8s Secrets

**Namespace**: `mereka-lms`

**Secrets**:
- `openedx-secrets` (33+ keys)
- `database-secrets` (7 keys)
- `enterprise-secrets` (11 keys)

**Sync**: ExternalSecrets Operator refreshes every 1 hour.

**Deletion policy**: `Retain` (K8s secrets survive ExternalSecret resource deletion).

---

## Troubleshooting

### ExternalSecret shows `SecretSyncedError`

**Symptom**:
```bash
kubectl get externalsecrets -n mereka-lms
# NAME              STATUS
# openedx-secrets   SecretSyncedError
```

**Possible causes**:

1. **Secret doesn't exist in GCP SM**:
   ```bash
   # Fix: Sync from Infisical
   ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```

2. **IAM roles missing**:
   ```bash
   # Verify service account has both roles
   gcloud projects get-iam-policy bbi-k8 \
     --flatten="bindings[].members" \
     --filter="bindings.members:external-secrets-gcp" \
     --format="table(bindings.role)"

   # Should show:
   # - roles/secretmanager.secretAccessor
   # - roles/secretmanager.viewer

   # If missing, add:
   gcloud projects add-iam-policy-binding bbi-k8 \
     --member=serviceAccount:external-secrets-gcp@bbi-k8.iam.gserviceaccount.com \
     --role=roles/secretmanager.secretAccessor
   ```

3. **ClusterSecretStore unreachable**:
   ```bash
   # Check ESO operator logs
   kubectl logs -n external-secrets deployment/external-secrets -f

   # Verify ClusterSecretStore config
   kubectl get clustersecretstore gcp-secret-manager -o yaml
   ```

### MySQL `ERROR 1045 Access denied`

**Symptom**: LMS/CMS pods fail to connect to MySQL with authentication error.

**Possible causes**:

1. **Trailing whitespace in password** (invisible in Infisical UI):
   ```bash
   # Detect
   ./scripts/infra/normalize-mysql-secrets.sh

   # Fix (strips trailing CR/LF)
   APPLY=1 ./scripts/infra/normalize-mysql-secrets.sh
   ```

2. **Password mismatch after rotation** (production password rotated, but Kind MySQL PVC has old password):
   ```bash
   # For Kind dev environments only
   K8S_CONTEXT=kind-dev ./scripts/infra/repair-kind-mysql-users.sh
   ```

3. **ExternalSecret not synced yet**:
   ```bash
   # Force sync
   kubectl annotate externalsecret database-secrets -n mereka-lms \
     force-sync="$(date +%s)" --overwrite

   # Restart MySQL (if using local MySQL, not Cloud SQL)
   kubectl rollout restart statefulset/mysql -n mereka-lms
   ```

### JWT Validation Failures

**Symptom**: MFEs fail to load, "Invalid JWT signature" errors in logs.

**Possible causes**:

1. **JWT secrets not loaded**:
   ```bash
   # Verify secret exists
   kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data.JWT_SECRET_KEY_LMS}' | base64 -d
   # Should show non-empty value

   # If empty, check ExternalSecret mapping
   kubectl get externalsecret openedx-secrets -n mereka-lms -o yaml | grep JWT_SECRET_KEY
   ```

2. **Services sharing JWT secret** (security violation):
   ```bash
   # Verify each service has unique JWT key
   ./scripts/qa/verify-jwt-uniqueness.sh
   ```

3. **JWT secret rotation without pod restart**:
   ```bash
   # Rolling restart all services
   kubectl rollout restart deployment -n mereka-lms
   ```

### Infisical CLI Errors

**Symptom**: `infisical-validate-mereka-lms.sh` fails with authentication error.

**Fix**:
```bash
# Login to Infisical
infisical login

# Verify access
infisical secrets list --env prod --path /k8s/mereka-lms --plain
```

### Secret Sprawl (Keys Outside Canonical Path)

**Symptom**: `infisical-audit-mereka-lms.sh` finds keys at root `/` or `/mereka-lms`.

**Fix**:
```bash
# 1. Audit to identify sprawl
./scripts/infra/infisical-audit-mereka-lms.sh

# 2. Sync from canonical path (consolidates)
./scripts/infra/infisical-sync-mereka-lms.sh prod
./scripts/infra/infisical-sync-mereka-lms.sh dev

# 3. Validate
STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh

# 4. Manually delete sprawl keys in Infisical UI
```

### Pre-Commit Hook Blocks Commit

**Symptom**: `git commit` blocked with "Hardcoded secret detected".

**Fix**:

1. **If false positive** (e.g., comment explaining secrets, not actual secret):
   ```bash
   # Emergency bypass (use sparingly!)
   git commit --no-verify
   ```

2. **If real secret**:
   - Remove the hardcoded value
   - Replace with `os.environ.get('SECRET_NAME')` in Python
   - Or `secretKeyRef` in K8s YAML
   - Never commit actual secret values

---

## Security Rules

### ✅ DO

- ✅ Store all secrets in Infisical at `/k8s/mereka-lms`
- ✅ Prefix all keys with `MEREKA_LMS_` in Infisical/GCP SM
- ✅ Use `STRICT=1` validation before production deployment
- ✅ Run `scan-secrets-fast.sh` before committing
- ✅ Use unique JWT secrets per service
- ✅ Rotate secrets every 90 days (or immediately if compromised)
- ✅ Use `*_DEV` suffixes for dev Stripe/MySQL keys
- ✅ Use `os.environ.get()` pattern in Python
- ✅ Use `envFrom.secretRef` in K8s manifests
- ✅ Document rotations in beads

### ❌ DON'T

- ❌ Never commit secrets to git (pre-commit hook will block)
- ❌ Never hardcode secrets in YAML/Python/config files
- ❌ Never share JWT secrets between services
- ❌ Never use `--no-verify` to bypass pre-commit hook (except emergencies)
- ❌ Never run `infisical secrets` without `--output json` or `--silent` (prints secrets to terminal)
- ❌ Never skip `STRICT=1` validation before production
- ❌ Never use placeholder values (`REPLACE_ME`, `CHANGE_ME`) in production
- ❌ Never use production Stripe keys in dev environments

---

## Related Resources

### Specs
- **Full spec**: `specs/secrets-management_spec.md` (18 ACs, complete reference)

### Operations Docs
- **Rotation checklist**: `docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md` (step-by-step)
- **Secrets inventory**: `docs/reference/operations/SECRETS_SNAPSHOT.md` (complete list)
- **Infisical keys**: `docs/reference/operations/INFISICAL_MEREKA_LMS_KEYS.md` (detailed inventory)
- **Domain secrets**: `docs/runbooks/operations/RELEASE_CHECKLIST_DOMAIN_SECRETS.md` (multi-site release)

### Architecture Decisions
- **ADR-004**: `docs/adr/historical/004-secrets-management.md` (why Infisical + ExternalSecrets)

### Scripts
- Validation: `scripts/infra/infisical-validate-mereka-lms.sh`
- Audit: `scripts/infra/infisical-audit-mereka-lms.sh`
- Sync to GCP SM: `scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh`
- Normalize MySQL: `scripts/infra/normalize-mysql-secrets.sh`
- Repair Kind MySQL: `scripts/infra/repair-kind-mysql-users.sh`
- Secret scanning: `scripts/qa/scan-secrets-fast.sh`

### External Resources
- **Infisical**: https://secrets.mereka.io
- **GCP Secret Manager**: https://console.cloud.google.com/security/secret-manager?project=bbi-k8
- **ExternalSecrets Operator**: https://external-secrets.io/

---

## Quick Command Reference

```bash
# ===== VALIDATION =====
# Validate secrets exist (both environments)
STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh

# Check for secret sprawl
./scripts/infra/infisical-audit-mereka-lms.sh

# Scan for hardcoded secrets in git
STRICT=1 ./scripts/qa/scan-secrets-fast.sh

# ===== SYNC =====
# Sync Infisical → GCP Secret Manager
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh

# Force ExternalSecrets refresh
kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite

# ===== STATUS =====
# Check ExternalSecret sync status
kubectl get externalsecrets -n mereka-lms

# Check K8s secret key count
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys | length'
kubectl get secret database-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys | length'

# ===== ROTATION =====
# After updating in Infisical, full rotation:
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
kubectl rollout restart deployment -n mereka-lms
CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod

# ===== TROUBLESHOOTING =====
# Fix MySQL auth (trailing whitespace)
APPLY=1 ./scripts/infra/normalize-mysql-secrets.sh

# Fix Kind MySQL after rotation
K8S_CONTEXT=kind-dev ./scripts/infra/repair-kind-mysql-users.sh

# Check ESO operator logs
kubectl logs -n external-secrets deployment/external-secrets -f
```
