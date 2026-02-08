---
title: Secrets Management Specification
type: feature_spec
status: draft
owner: engineering
vehicle: talent_platform
last_updated: '2026-02-08'
---

# Secrets Management Specification

**Status**: Active
**Last Updated**: 2026-02-03

## Overview

This spec defines the secrets management architecture for Mereka LMS.

## Architecture

```
Infisical (source of truth)
    |  automated sync (GitHub Actions)
    v
GCP Secret Manager
    |  ExternalSecrets Operator
    v
Kubernetes Secrets
    |  envFrom
    v
Pod Environment Variables
    |  os.environ.get()
    v
Python Application Code
```

## MUST Requirements

### Secret Naming Convention
- All OpenEdX secrets MUST be prefixed with `MEREKA_LMS_` in Infisical/GCP SM
- K8s secret keys MUST match the environment variable names expected by Python code

### Required Secrets

### Infisical Folder Rules
- **Prod and Dev** secrets live under `/k8s/mereka-lms`.
- Do **not** store `MEREKA_LMS_*` secrets in `/` or other folders.
- Legacy `/mereka-lms` folders are removed to avoid path drift.
- Non-K8s secrets:
  - Atlas CLI keys live under `/k8s/mereka-lms/atlas`.
  - Migration (MCT/Kajabi) keys live under `/k8s/mereka-lms/migrations/*`.
- **Safety:** Never run `infisical secrets` without `--output json` because it prints secret values.

### Current Inventory (2026-02-05)
- `/k8s/mereka-lms` contains **56 keys** in both prod and dev.
- Categories present:
  - `MEREKA_LMS_*` (Open edX + DB + JWT + OAuth)
  - `ATLAS_*` (API access + org/project IDs)
  - `MCT_*` and `KAJABI_*` (migration inputs)

### Sprawl Cleanup (Required)
If any `MEREKA_LMS_*` keys appear outside `/k8s/mereka-lms`, re-sync from the
authoritative path and re-run validation:

```bash
./scripts/infra/infisical-audit-mereka-lms.sh
./scripts/infra/infisical-sync-mereka-lms.sh prod
./scripts/infra/infisical-sync-mereka-lms.sh dev
./scripts/infra/infisical-validate-mereka-lms.sh
```

### Shared Admin/Test Credentials
- Stored in Infisical `/shared/oauth`.
- `GOOGLE_IMPERSONATE_EMAIL` + `GOOGLE_IMPERSONATE_PASSWORD` are the shared
  admin credentials for LMS + Authentik (GKE + VPS kind).
- Do not copy these values into repo files or issue comments.

### Migration Secrets (MCT + Kajabi)
- **Path:** `/k8s/mereka-lms/migrations/mct` and `/k8s/mereka-lms/migrations/kajabi`
- **Purpose:** Used by migration/export scripts (not synced to K8s secrets).
**Required keys (MCT):**
  - `MCT_BASE_URL`, `MCT_ENDPT`, `MCT_API_URI`
  - `MCT_CLIENT_ID`, `MCT_CLIENT_SECRET`, `MCT_TENANT_ID`
  - `MCT_API_VERSION`, `MCT_ACCESS_TOKEN` (optional token override)
**Required keys (Kajabi):**
  - `KAJABI_CLIENT_ID`, `KAJABI_CLIENT_SECRET`, `KAJABI_SITE_ID`
  - `KAJABI_WEBHOOK_SECRET`, `KAJABI_EMAIL`, `KAJABI_PASSWORD`
- **Note:** These are seeded with `REPLACE_ME` placeholders. Replace before running
  `scripts/migrations/mct/*` or `scripts/migrations/kajabi/*` pipelines.

### Atlas Automation Secrets
- **Path:** `/k8s/mereka-lms/atlas`
- **Purpose:** Used by `scripts/infra/atlas-config-from-infisical.sh` and Atlas allowlist automation.
- **Required keys:**
  - `ATLAS_PUBLIC_KEY`
  - `ATLAS_PRIVATE_KEY`
  - `ATLAS_ORG_ID`
  - `ATLAS_PROJECT_ID`
  - `ATLAS_PROFILE` (defaults to `mereka-lms` if empty)

#### openedx-secrets (30+ keys)
| K8s Key | GCP SM Key | Purpose |
|---------|------------|---------|
| OPENEDX_SECRET_KEY | MEREKA_LMS_OPENEDX_SECRET_KEY | LMS Django secret |
| SECRET_KEY | MEREKA_LMS_OPENEDX_SECRET_KEY | Legacy alias used by some services |
| CMS_SECRET_KEY | MEREKA_LMS_CMS_SECRET_KEY | CMS Django secret |
| MONGODB_PASSWORD | MEREKA_LMS_MONGODB_PASSWORD | MongoDB Atlas password |
| FORUM_MONGODB_SRV | MEREKA_LMS_FORUM_MONGODB_SRV | MongoDB Atlas SRV for forum |
| JWT_SECRET_KEY_LMS | MEREKA_LMS_JWT_SECRET_KEY | LMS JWT signing |
| JWT_SECRET_KEY_CMS | MEREKA_LMS_JWT_SECRET_KEY_CMS | CMS JWT signing |
| JWT_SECRET_KEY_DISCOVERY | MEREKA_LMS_JWT_SECRET_KEY_DISCOVERY | Discovery JWT |
| JWT_SECRET_KEY_ECOMMERCE | MEREKA_LMS_JWT_SECRET_KEY_ECOMMERCE | Ecommerce JWT |
| JWT_SECRET_KEY_NOTES | MEREKA_LMS_JWT_SECRET_KEY_NOTES | Notes JWT |
| JWT_SECRET_KEY_XQUEUE | MEREKA_LMS_JWT_SECRET_KEY_XQUEUE | XQueue JWT |
| JWT_SECRET_KEY_CREDENTIALS | MEREKA_LMS_JWT_SECRET_KEY_CREDENTIALS | Credentials JWT |
| JWT_PRIVATE_SIGNING_JWK | MEREKA_LMS_JWT_PRIVATE_SIGNING_JWK | JWT signing key |
| EDX_API_KEY | MEREKA_LMS_EDX_API_KEY | Platform API key |
| ECOMMERCE_API_SIGNING_KEY | MEREKA_LMS_ECOMMERCE_API_SIGNING_KEY | Ecommerce API signing |
| ECOMMERCE_EDX_API_KEY | MEREKA_LMS_EDX_API_KEY | Ecommerce API key alias |
| DISCOVERY_SECRET_KEY | MEREKA_LMS_DISCOVERY_SECRET_KEY | Discovery Django |
| DISCOVERY_SOCIAL_AUTH_EDX_OAUTH2_SECRET | MEREKA_LMS_DISCOVERY_OAUTH2_SECRET | Discovery SSO OAuth |
| DISCOVERY_BACKEND_OAUTH2_SECRET | MEREKA_LMS_DISCOVERY_BACKEND_OAUTH2_SECRET | Discovery backend OAuth |
| ECOMMERCE_SECRET_KEY | MEREKA_LMS_ECOMMERCE_SECRET_KEY | Ecommerce Django |
| ECOMMERCE_SOCIAL_AUTH_EDX_OAUTH2_SECRET | MEREKA_LMS_ECOMMERCE_OAUTH2_SECRET | Ecommerce SSO OAuth |
| ECOMMERCE_BACKEND_OAUTH2_SECRET | MEREKA_LMS_ECOMMERCE_BACKEND_OAUTH2_SECRET | Ecommerce backend OAuth |
| NOTES_SECRET_KEY | MEREKA_LMS_NOTES_SECRET_KEY | Notes Django |
| NOTES_CLIENT_SECRET | MEREKA_LMS_NOTES_CLIENT_SECRET | Notes OAuth secret |
| XQUEUE_SECRET_KEY | MEREKA_LMS_XQUEUE_SECRET_KEY | XQueue Django |
| XQUEUE_LMS_PASSWORD | MEREKA_LMS_XQUEUE_PASSWORD | XQueue service user |
| CMS_SOCIAL_AUTH_EDX_OAUTH2_SECRET | MEREKA_LMS_CMS_OAUTH2_SECRET | CMS SSO OAuth |
| OIDC_CLIENT_SECRET | MEREKA_LMS_OIDC_CLIENT_SECRET | OIDC client secret |
| CREDENTIALS_SECRET_KEY | MEREKA_LMS_CREDENTIALS_SECRET_KEY | Credentials Django |
| CREDENTIALS_BACKEND_OAUTH2_SECRET | MEREKA_LMS_CREDENTIALS_BACKEND_OAUTH2_SECRET | Credentials backend OAuth |
| CREDENTIALS_SSO_OAUTH2_SECRET | MEREKA_LMS_CREDENTIALS_SSO_OAUTH2_SECRET | Credentials SSO OAuth |

#### database-secrets (7 keys)
| K8s Key | GCP SM Key | Purpose |
|---------|------------|---------|
| MYSQL_ROOT_PASSWORD | MEREKA_LMS_MYSQL_ROOT_PASSWORD | MySQL root |
| OPENEDX_MYSQL_PASSWORD | MEREKA_LMS_MYSQL_PASSWORD | OpenEdX DB |
| MYSQL_DISCOVERY_PASSWORD | MEREKA_LMS_MYSQL_DISCOVERY_PASSWORD | Discovery DB |
| MYSQL_ECOMMERCE_PASSWORD | MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD | Ecommerce DB |
| MYSQL_NOTES_PASSWORD | MEREKA_LMS_MYSQL_NOTES_PASSWORD | Notes DB |
| MYSQL_XQUEUE_PASSWORD | MEREKA_LMS_MYSQL_XQUEUE_PASSWORD | XQueue DB |
| MYSQL_CREDENTIALS_PASSWORD | MEREKA_LMS_MYSQL_CREDENTIALS_PASSWORD | Credentials DB |

### Security Requirements
- MUST NOT commit hardcoded secrets to git
- MUST use unique JWT secrets per service (no sharing)
- MUST use os.environ.get() pattern in Python code
- MUST have envFrom in K8s deployments referencing secrets

## SHOULD Requirements
- SHOULD rotate secrets quarterly
- SHOULD use ExternalSecrets for automatic sync
- SHOULD document secret purpose in Infisical

## Verification

```bash
# Check no hardcoded secrets in deploy/
grep -r "UeCMQQglnc0O68rTJQezNNSt" deploy/  # MUST return 0 results

# Check ExternalSecrets are synced
kubectl get externalsecrets -n mereka-lms  # Status: SecretSynced

# Check K8s secrets exist
kubectl get secret openedx-secrets -n mereka-lms  # MUST exist
kubectl get secret database-secrets -n mereka-lms  # MUST exist

# Infisical path sanity (prod + dev)
cd /home/gurpreet/projects/k8s/reka-slackbot
infisical secrets --domain https://secrets.mereka.io/api --env prod --path /k8s/mereka-lms --output json --silent | jq -r '.[].secretKey'
infisical secrets --domain https://secrets.mereka.io/api --env dev --path /k8s/mereka-lms --output json --silent | jq -r '.[].secretKey'

# Folder inventory (safe, no values printed)
infisical secrets folders get --domain https://secrets.mereka.io/api --env prod --path / --output json --silent | jq -r '.[].folderName'

# Contract drift check (Infisical + GCP)
cd /home/gurpreet/projects/secrets-management
python3 scripts/validate/check_drift.py --full

# Check pods have envFrom
kubectl get deploy lms -n mereka-lms -o yaml | grep -A3 envFrom  # MUST show secretRef
```


## Scope

_Defines the boundaries of this specification._

## Non-goals

_Explicitly out of scope for this specification._

## Requirements

- This section requires review to add MUST/SHOULD/MAY requirements.

## Acceptance Criteria

- [ ] Acceptance criteria to be defined.

## Edge Cases

_Edge cases to be documented._

## Observability

_Logging, metrics, and alerting requirements to be defined._

## Rollout & Rollback

_Rollout strategy and rollback procedures to be defined._

## Open Questions

_No open questions at this time._
