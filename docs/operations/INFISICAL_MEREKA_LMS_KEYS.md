# Infisical Keys Inventory (Mereka LMS)

Canonical list of `MEREKA_LMS_*` secrets used by the platform. The authoritative
source is `deploy/k8s/base/secrets/external-secrets.yaml` and all secrets must live
under `/k8s/mereka-lms` in both `prod` and `dev`.

## Quick Commands

```bash
# Validate all expected keys exist (prod/dev)
INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
INFISICAL_ENV=dev ./scripts/infra/infisical-validate-mereka-lms.sh

# Consolidate secrets into /k8s/mereka-lms
./scripts/infra/infisical-sync-mereka-lms.sh prod
./scripts/infra/infisical-sync-mereka-lms.sh dev
```

**Policy:** `/k8s/mereka-lms` is the only allowed path for `MEREKA_LMS_*`.
Remove any root-level duplicates (last cleanup: 2026-02-05).

## GCP Secret Manager bridge

Kubernetes ExternalSecrets reads from GCP Secret Manager (project `bbi-k8` via
`ClusterSecretStore/gcp-secret-manager`). If a secret exists in Infisical but
is missing in GCP SM, ExternalSecrets will stop refreshing.

**Important IAM note (required):** ExternalSecrets calls both Secret Manager
version access and secret metadata APIs. The GCP service account used by ESO
must have BOTH:

- `roles/secretmanager.secretAccessor` (read secret payload)
- `roles/secretmanager.viewer` (read secret metadata; avoids misleading 404/Secret does not exist)

Use this script to restore GCP SM entries from Infisical without printing values:

```bash
./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
kubectl --context kind-dev annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
```

The sync script also strips trailing CR/LF bytes from CLI output to avoid
accidentally introducing newline characters into passwords.

By default, the sync script is **create-if-missing** for safety. It only updates
existing secrets for Stripe keys (to allow routine Stripe rotation without
touching DB passwords) and dev-only MySQL `*_DEV` keys (to keep kind stable).
To override that behavior, set
`OVERWRITE_ALLOWED_REGEX` explicitly.

**Dev Stripe separation:** dev (kind) uses Stripe test keys. Because both
clusters read from the same GCP SM project, dev Stripe secrets are stored as
`*_DEV` in GCP SM and the local overlay rewrites ExternalSecret references.

**Dev MySQL separation:** kind dev uses `*_DEV` MySQL password keys (similar
to Stripe). This prevents production password rotation from breaking the local
MySQL PVC, while still keeping Infisical as the source of truth (dev env).

## Repairing kind MySQL auth drift

If dev starts failing with MySQL `1045 Access denied` after a secret rotation,
repair the MySQL users inside the dev MySQL PVC (non-destructive):

```bash
K8S_CONTEXT=kind-dev ./scripts/infra/repair-kind-mysql-users.sh
```

This aligns `root`, `openedx`, `ecommerce`, `discovery`, `notes`, `xqueue`,
`credentials` to the current `secret/database-secrets` values.

## Required Keys

- `MEREKA_LMS_CMS_OAUTH2_SECRET`
- `MEREKA_LMS_CMS_SECRET_KEY`
- `MEREKA_LMS_CREDENTIALS_BACKEND_OAUTH2_SECRET`
- `MEREKA_LMS_CREDENTIALS_SECRET_KEY`
- `MEREKA_LMS_CREDENTIALS_SSO_OAUTH2_SECRET`
- `MEREKA_LMS_DISCOVERY_BACKEND_OAUTH2_SECRET`
- `MEREKA_LMS_DISCOVERY_OAUTH2_SECRET`
- `MEREKA_LMS_DISCOVERY_SECRET_KEY`
- `MEREKA_LMS_ECOMMERCE_API_SIGNING_KEY`
- `MEREKA_LMS_ECOMMERCE_BACKEND_OAUTH2_SECRET`
- `MEREKA_LMS_ECOMMERCE_OAUTH2_SECRET`
- `MEREKA_LMS_ECOMMERCE_SECRET_KEY`
- `MEREKA_LMS_EDX_API_KEY`
- `MEREKA_LMS_FORUM_MONGODB_SRV`
- `MEREKA_LMS_JWT_PRIVATE_SIGNING_JWK`
- `MEREKA_LMS_JWT_SECRET_KEY`
- `MEREKA_LMS_JWT_SECRET_KEY_CMS`
- `MEREKA_LMS_JWT_SECRET_KEY_CREDENTIALS`
- `MEREKA_LMS_JWT_SECRET_KEY_DISCOVERY`
- `MEREKA_LMS_JWT_SECRET_KEY_ECOMMERCE`
- `MEREKA_LMS_JWT_SECRET_KEY_NOTES`
- `MEREKA_LMS_JWT_SECRET_KEY_XQUEUE`
- `MEREKA_LMS_MONGODB_PASSWORD`
- `MEREKA_LMS_MONGODB_USERNAME`
- `MEREKA_LMS_MYSQL_CREDENTIALS_PASSWORD`
- `MEREKA_LMS_MYSQL_DISCOVERY_PASSWORD`
- `MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD`
- `MEREKA_LMS_MYSQL_NOTES_PASSWORD`
- `MEREKA_LMS_MYSQL_PASSWORD`
- `MEREKA_LMS_MYSQL_ROOT_PASSWORD`
- `MEREKA_LMS_MYSQL_XQUEUE_PASSWORD`
- `MEREKA_LMS_NOTES_CLIENT_SECRET`
- `MEREKA_LMS_NOTES_SECRET_KEY`
- `MEREKA_LMS_OIDC_CLIENT_SECRET`
- `MEREKA_LMS_OPENEDX_SECRET_KEY`
- `MEREKA_LMS_XQUEUE_PASSWORD`
- `MEREKA_LMS_XQUEUE_SECRET_KEY`
- `MEREKA_LMS_STRIPE_PUBLISHABLE_KEY`
- `MEREKA_LMS_STRIPE_SECRET_KEY`
- `MEREKA_LMS_STRIPE_WEBHOOK_SECRET`
