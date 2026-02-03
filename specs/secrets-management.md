# Secrets Management Specification

**Status**: Active
**Last Updated**: 2026-02-03

## Overview

This spec defines the secrets management architecture for Mereka LMS.

## Architecture

```
Infisical (source of truth)
    |  manual sync
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

#### openedx-secrets (24 keys)
| K8s Key | GCP SM Key | Purpose |
|---------|------------|---------|
| OPENEDX_SECRET_KEY | MEREKA_LMS_OPENEDX_SECRET_KEY | LMS Django secret |
| CMS_SECRET_KEY | MEREKA_LMS_CMS_SECRET_KEY | CMS Django secret |
| JWT_SECRET_KEY_LMS | MEREKA_LMS_JWT_SECRET_KEY | LMS JWT signing |
| JWT_SECRET_KEY_CMS | MEREKA_LMS_JWT_SECRET_KEY_CMS | CMS JWT signing |
| JWT_SECRET_KEY_DISCOVERY | MEREKA_LMS_JWT_SECRET_KEY_DISCOVERY | Discovery JWT |
| JWT_SECRET_KEY_ECOMMERCE | MEREKA_LMS_JWT_SECRET_KEY_ECOMMERCE | Ecommerce JWT |
| JWT_SECRET_KEY_NOTES | MEREKA_LMS_JWT_SECRET_KEY_NOTES | Notes JWT |
| JWT_SECRET_KEY_XQUEUE | MEREKA_LMS_JWT_SECRET_KEY_XQUEUE | XQueue JWT |
| EDX_API_KEY | MEREKA_LMS_EDX_API_KEY | Platform API key |
| DISCOVERY_SECRET_KEY | MEREKA_LMS_DISCOVERY_SECRET_KEY | Discovery Django |
| ECOMMERCE_SECRET_KEY | MEREKA_LMS_ECOMMERCE_SECRET_KEY | Ecommerce Django |
| NOTES_SECRET_KEY | MEREKA_LMS_NOTES_SECRET_KEY | Notes Django |
| XQUEUE_SECRET_KEY | MEREKA_LMS_XQUEUE_SECRET_KEY | XQueue Django |
| *_OAUTH2_SECRET | MEREKA_LMS_*_OAUTH2_SECRET | OAuth2 client secrets |

#### database-secrets (6 keys)
| K8s Key | GCP SM Key | Purpose |
|---------|------------|---------|
| MYSQL_ROOT_PASSWORD | MEREKA_LMS_MYSQL_ROOT_PASSWORD | MySQL root |
| OPENEDX_MYSQL_PASSWORD | MEREKA_LMS_MYSQL_PASSWORD | OpenEdX DB |
| MYSQL_DISCOVERY_PASSWORD | MEREKA_LMS_MYSQL_DISCOVERY_PASSWORD | Discovery DB |
| MYSQL_ECOMMERCE_PASSWORD | MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD | Ecommerce DB |
| MYSQL_NOTES_PASSWORD | MEREKA_LMS_MYSQL_NOTES_PASSWORD | Notes DB |
| MYSQL_XQUEUE_PASSWORD | MEREKA_LMS_MYSQL_XQUEUE_PASSWORD | XQueue DB |

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

# Check pods have envFrom
kubectl get deploy lms -n mereka-lms -o yaml | grep -A3 envFrom  # MUST show secretRef
```
