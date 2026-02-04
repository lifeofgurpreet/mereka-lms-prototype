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

# Check pods have envFrom
kubectl get deploy lms -n mereka-lms -o yaml | grep -A3 envFrom  # MUST show secretRef
```
