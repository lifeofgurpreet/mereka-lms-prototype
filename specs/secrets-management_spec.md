---
title: Secrets Management Specification
type: feature_spec
status: completed
owner: engineering
vehicle: talent_platform
version: 1.0.0
depends_on:
- specs/repository-structure_spec.md
links:
  related_docs:
  - docs/reference/operations/SECRETS_SNAPSHOT.md
  - docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md
  - docs/reference/operations/INFISICAL_MEREKA_LMS_KEYS.md
  - docs/runbooks/operations/RELEASE_CHECKLIST_DOMAIN_SECRETS.md
  - docs/adr/004-secrets-management.md
  related_specs:
  - specs/k8s-deployment_spec.md
  - specs/observability-stack_spec.md
  - specs/disaster-recovery-business-continuity_spec.md
  - specs/cross-cutting-requirements_spec.md
id: SPEC-SECRETS-MANAGEMENT
spec_class: security
created: '2026-02-10'
last_reviewed: '2026-02-10'
review_due: '2026-05-11'
domain: platform
normativity: normative
summary: Normative contract for secret storage, delivery, and rotation across Mereka
  LMS environments.
---

# Human Summary

## What we're building

A layered secrets management architecture for the Mereka Academy Open edX platform that flows credentials from a single source of truth (Infisical) through GCP Secret Manager and the ExternalSecrets Operator into Kubernetes Secrets, where application pods consume them as environment variables. The system manages 51+ secrets across three K8s secret objects (`openedx-secrets` with 33+ keys, `database-secrets` with 7 keys, `enterprise-secrets` with 11 keys), plus auxiliary secrets for Atlas automation and data migrations (MCT/Kajabi). The architecture covers both production (GKE) and development (Kind) environments, with environment-specific separation for Stripe and MySQL credentials.

## Why it matters

Secrets mismanagement is a top-tier operational risk. A hardcoded password committed to git requires emergency rotation across every downstream system. A missing or empty secret causes MySQL `1045 Access Denied` errors or JWT validation failures that take the entire LMS offline for learners and instructors. Trailing whitespace in a password value -- invisible to the human eye -- has historically caused production authentication failures. This spec establishes machine-verifiable contracts so that validation scripts, CI guards, and pre-commit hooks can catch these failures before they reach production.

## Success looks like

- All 51+ secrets (33 openedx, 7 database, 11 enterprise) exist in Infisical under the canonical path `/k8s/mereka-lms` with non-empty, non-placeholder values.
- ExternalSecrets sync to K8s within 1 hour of changes, reaching `SecretSynced` status without manual intervention.
- Zero hardcoded secrets in any file committed to the repository, enforced by pre-commit hooks and CI scanning.
- Secret rotation completes end-to-end (Infisical to running pods) in under 30 minutes with zero downtime.
- The validation script (`infisical-validate-mereka-lms.sh`) passes in both `prod` and `dev` environments with `STRICT=1`.

# Agent Contract

## Scope

- In scope:
  - The end-to-end secrets pipeline: Infisical -> GCP Secret Manager -> ExternalSecrets Operator -> K8s Secrets -> Pod environment variables -> Python `os.environ.get()`
  - Naming conventions for all secret keys (`MEREKA_LMS_` prefix in Infisical/GCP SM)
  - Infisical folder structure and path rules (`/k8s/mereka-lms`, `/k8s/mereka-lms/atlas`, `/k8s/mereka-lms/migrations/*`)
  - Complete inventory of `openedx-secrets` (33+ keys), `database-secrets` (7 keys), and `enterprise-secrets` (11 keys)
  - Migration secrets inventory (MCT and Kajabi)
  - Atlas automation secrets inventory
  - Shared admin/test credentials governance (`/shared/oauth`)
  - ExternalSecret resource configuration (refresh interval, deletion policy, store reference)
  - ClusterSecretStore configuration for GCP Secret Manager
  - Secret validation tooling (`infisical-validate-mereka-lms.sh`, `infisical-audit-mereka-lms.sh`, `infisical-sync-mereka-lms.sh`)
  - Pre-commit secret scanning (pattern-based detection)
  - CI secret validation guardrails
  - Dev/prod secret separation for Stripe and MySQL keys
  - Secret rotation procedures and checklist
  - Trailing whitespace detection and normalization for password-type secrets
- Out of scope:
  - Infisical server installation and administration (managed service at `secrets.mereka.io`)
  - GCP IAM policy management for the GKE service account (handled by infra team)
  - Application-level secret consumption logic (Django settings, uWSGI configuration)
  - Third-party provider credential creation (Stripe dashboard, Atlas console, AWS SES)
  - Secret value generation algorithms (entropy requirements, key length)

## Non-goals

- Automated secret rotation (secrets are rotated manually via the rotation checklist; automated rotation is a future enhancement)
- Vault-style dynamic secrets or short-lived credentials (current scale does not justify the operational complexity)
- Encryption at rest within git (Sealed Secrets pattern was explicitly rejected per ADR-004)
- Secret versioning or rollback within Infisical (Infisical handles this internally; we do not spec it)
- Multi-tenant secret isolation (single-team ownership; no noisy-neighbor risk)
- Hardware Security Module (HSM) integration for key storage

## Assumptions

- Infisical is operational and reachable at `secrets.mereka.io` with authenticated CLI access
- GCP Secret Manager is enabled in the `bbi-k8` project with appropriate IAM roles (`roles/secretmanager.secretAccessor` and `roles/secretmanager.viewer`)
- ExternalSecrets Operator v1 is installed in the GKE cluster with a working `gcp-secret-manager` ClusterSecretStore
- The `infisical` CLI, `jq`, and `rg` (ripgrep) are installed on all operator workstations
- Kind clusters for dev use the same ExternalSecrets Operator pattern with the same GCP SM backend
- Pre-commit hooks are installed via `git config --local include.path ../.gitconfig`

## Requirements

### Functional

#### Pipeline Architecture

- The system MUST implement a four-stage secrets pipeline: Infisical (source of truth) -> GCP Secret Manager (bridge) -> ExternalSecrets Operator (sync) -> K8s Secrets (runtime).
- Application code MUST consume secrets exclusively via environment variables using the `os.environ.get()` pattern.
- Deployments MUST inject secrets via `envFrom` with `secretRef`, never via inline `env` values containing secret data.

#### Naming Convention

- All Open edX secrets MUST be prefixed with `MEREKA_LMS_` in Infisical and GCP Secret Manager.
- K8s secret keys MUST match the environment variable names expected by the Python application code (without the `MEREKA_LMS_` prefix).
- The ExternalSecret `data` mappings MUST translate from `MEREKA_LMS_*` remote keys to application-expected local keys.

#### Infisical Organization

- All `MEREKA_LMS_*` secrets MUST reside under the Infisical path `/k8s/mereka-lms` in both `prod` and `dev` environments.
- The system MUST NOT store `MEREKA_LMS_*` secrets at the Infisical root path `/` or in any other folder.
- Atlas CLI keys MUST reside under `/k8s/mereka-lms/atlas`.
- MCT migration keys MUST reside under `/k8s/mereka-lms/migrations/mct`.
- Kajabi migration keys MUST reside under `/k8s/mereka-lms/migrations/kajabi`.
- Shared admin/test credentials MUST reside under `/shared/oauth`.
- Legacy `/mereka-lms` folders (without the `/k8s/` prefix) MUST be removed to prevent path drift.
- Operators MUST NOT run `infisical secrets` without `--output json` or `--silent` flags, because the default output prints secret values to the terminal.

#### Required Secret Inventory -- openedx-secrets (33+ keys)

- The `openedx-secrets` K8s Secret MUST contain all of the following key mappings:

  | K8s Key | GCP SM Key | Purpose |
  |---------|------------|---------|
  | OPENEDX_SECRET_KEY | MEREKA_LMS_OPENEDX_SECRET_KEY | LMS Django secret |
  | SECRET_KEY | MEREKA_LMS_OPENEDX_SECRET_KEY | Legacy alias used by some services |
  | CMS_SECRET_KEY | MEREKA_LMS_CMS_SECRET_KEY | CMS Django secret |
  | MONGODB_USERNAME | MEREKA_LMS_MONGODB_USERNAME | MongoDB Atlas username |
  | MONGODB_PASSWORD | MEREKA_LMS_MONGODB_PASSWORD | MongoDB Atlas password |
  | FORUM_MONGODB_SRV | MEREKA_LMS_FORUM_MONGODB_SRV | MongoDB Atlas SRV for forum |
  | FORUM_API_KEY | MEREKA_LMS_FORUM_API_KEY | Forum service API key |
  | JWT_SECRET_KEY_LMS | MEREKA_LMS_JWT_SECRET_KEY | LMS JWT signing |
  | JWT_SECRET_KEY_CMS | MEREKA_LMS_JWT_SECRET_KEY_CMS | CMS JWT signing |
  | JWT_SECRET_KEY_DISCOVERY | MEREKA_LMS_JWT_SECRET_KEY_DISCOVERY | Discovery JWT |
  | JWT_SECRET_KEY_ECOMMERCE | MEREKA_LMS_JWT_SECRET_KEY_ECOMMERCE | Ecommerce JWT |
  | JWT_SECRET_KEY_NOTES | MEREKA_LMS_JWT_SECRET_KEY_NOTES | Notes JWT |
  | JWT_SECRET_KEY_XQUEUE | MEREKA_LMS_JWT_SECRET_KEY_XQUEUE | XQueue JWT |
  | JWT_SECRET_KEY_CREDENTIALS | MEREKA_LMS_JWT_SECRET_KEY_CREDENTIALS | Credentials JWT |
  | JWT_PRIVATE_SIGNING_JWK | MEREKA_LMS_JWT_PRIVATE_SIGNING_JWK | JWT private signing key |
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
  | STRIPE_SECRET_KEY | MEREKA_LMS_STRIPE_SECRET_KEY | Stripe payment processing |
  | STRIPE_PUBLISHABLE_KEY | MEREKA_LMS_STRIPE_PUBLISHABLE_KEY | Stripe client-side key |
  | STRIPE_WEBHOOK_SECRET | MEREKA_LMS_STRIPE_WEBHOOK_SECRET | Stripe webhook verification |

#### Required Secret Inventory -- database-secrets (7 keys)

- The `database-secrets` K8s Secret MUST contain all of the following key mappings:

  | K8s Key | GCP SM Key | Purpose |
  |---------|------------|---------|
  | MYSQL_ROOT_PASSWORD | MEREKA_LMS_MYSQL_ROOT_PASSWORD | MySQL root |
  | OPENEDX_MYSQL_PASSWORD | MEREKA_LMS_MYSQL_PASSWORD | OpenEdX DB |
  | MYSQL_DISCOVERY_PASSWORD | MEREKA_LMS_MYSQL_DISCOVERY_PASSWORD | Discovery DB |
  | MYSQL_ECOMMERCE_PASSWORD | MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD | Ecommerce DB |
  | MYSQL_NOTES_PASSWORD | MEREKA_LMS_MYSQL_NOTES_PASSWORD | Notes DB |
  | MYSQL_XQUEUE_PASSWORD | MEREKA_LMS_MYSQL_XQUEUE_PASSWORD | XQueue DB |
  | MYSQL_CREDENTIALS_PASSWORD | MEREKA_LMS_MYSQL_CREDENTIALS_PASSWORD | Credentials DB |

#### Required Secret Inventory -- enterprise-secrets (11 keys)

- The `enterprise-secrets` K8s Secret MUST contain all of the following key mappings:

  | K8s Key | GCP SM Key | Purpose |
  |---------|------------|---------|
  | ENTERPRISE_CATALOG_SECRET_KEY | MEREKA_LMS_ENTERPRISE_CATALOG_SECRET_KEY | Enterprise Catalog Django secret |
  | ENTERPRISE_CATALOG_OAUTH2_SECRET | MEREKA_LMS_ENTERPRISE_CATALOG_OAUTH2_SECRET | Enterprise Catalog OAuth2 client secret |
  | MYSQL_ENTERPRISE_CATALOG_PASSWORD | MEREKA_LMS_MYSQL_ENTERPRISE_CATALOG_PASSWORD | Enterprise Catalog DB password |
  | ENTERPRISE_SUBSIDY_SECRET_KEY | MEREKA_LMS_ENTERPRISE_SUBSIDY_SECRET_KEY | Enterprise Subsidy Django secret |
  | ENTERPRISE_SUBSIDY_OAUTH2_SECRET | MEREKA_LMS_ENTERPRISE_SUBSIDY_OAUTH2_SECRET | Enterprise Subsidy OAuth2 client secret |
  | MYSQL_ENTERPRISE_SUBSIDY_PASSWORD | MEREKA_LMS_MYSQL_ENTERPRISE_SUBSIDY_PASSWORD | Enterprise Subsidy DB password |
  | ENTERPRISE_ACCESS_SECRET_KEY | MEREKA_LMS_ENTERPRISE_ACCESS_SECRET_KEY | Enterprise Access Django secret |
  | ENTERPRISE_ACCESS_OAUTH2_SECRET | MEREKA_LMS_ENTERPRISE_ACCESS_OAUTH2_SECRET | Enterprise Access OAuth2 client secret |
  | MYSQL_ENTERPRISE_ACCESS_PASSWORD | MEREKA_LMS_MYSQL_ENTERPRISE_ACCESS_PASSWORD | Enterprise Access DB password |
  | LICENSE_MANAGER_SECRET_KEY | MEREKA_LMS_LICENSE_MANAGER_SECRET_KEY | License Manager Django secret |
  | LICENSE_MANAGER_OAUTH2_SECRET | MEREKA_LMS_LICENSE_MANAGER_OAUTH2_SECRET | License Manager OAuth2 client secret |

#### Migration Secrets (Not Synced to K8s)

- MCT migration secrets MUST exist under `/k8s/mereka-lms/migrations/mct` with keys: `MCT_BASE_URL`, `MCT_ENDPT`, `MCT_API_URI`, `MCT_CLIENT_ID`, `MCT_CLIENT_SECRET`, `MCT_TENANT_ID`, `MCT_API_VERSION`, and optionally `MCT_ACCESS_TOKEN`.
- Kajabi migration secrets MUST exist under `/k8s/mereka-lms/migrations/kajabi` with keys: `KAJABI_CLIENT_ID`, `KAJABI_CLIENT_SECRET`, `KAJABI_SITE_ID`, `KAJABI_WEBHOOK_SECRET`, `KAJABI_EMAIL`, `KAJABI_PASSWORD`.
- Migration secrets MUST NOT be synced to K8s Secrets (they are consumed only by migration scripts running on operator workstations).
- Migration secrets seeded with `REPLACE_ME` placeholders MUST be replaced with real values before running migration pipelines.

#### Atlas Automation Secrets

- Atlas secrets MUST exist under `/k8s/mereka-lms/atlas` with keys: `ATLAS_PUBLIC_KEY`, `ATLAS_PRIVATE_KEY`, `ATLAS_ORG_ID`, `ATLAS_PROJECT_ID`, and optionally `ATLAS_PROFILE` (defaults to `mereka-lms` if empty).
- Atlas secrets MUST NOT be synced to K8s Secrets (they are consumed by Atlas CLI automation scripts).

#### ExternalSecrets Configuration

- All three ExternalSecrets (`openedx-secrets`, `database-secrets`, `enterprise-secrets`) MUST set `refreshInterval: 1h`.
- All ExternalSecrets MUST reference `secretStoreRef.kind: ClusterSecretStore` with `name: gcp-secret-manager`.
- All ExternalSecrets MUST set `target.deletionPolicy: Retain` to prevent secret loss on accidental ExternalSecret resource deletion.
- All ExternalSecrets MUST set `target.creationPolicy: Owner`.
- The ClusterSecretStore MUST reference GCP project `bbi-k8` with `secretVersionSelectionPolicy: LatestOrFail`.

#### Security Rules

- Operators MUST NOT commit hardcoded secrets (passwords, API keys, tokens, private keys, JWTs) to the git repository.
- The pre-commit hook MUST scan for hardcoded secret patterns before each commit and block commits containing detected secrets.
- CI pipelines SHOULD run `trufflehog` or equivalent scanning on every push.
- Each Open edX service MUST use a unique JWT secret key (no sharing of JWT secrets between services).
- The `os.environ.get()` pattern MUST be the only mechanism for accessing secrets in Python application code.
- Shared admin credentials (`GOOGLE_IMPERSONATE_EMAIL`, `GOOGLE_IMPERSONATE_PASSWORD` at `/shared/oauth`) MUST NOT be copied into repository files or issue comments.

#### Dev/Prod Separation

- Dev (Kind) environments MUST use `*_DEV` suffixed keys in GCP SM for Stripe secrets to prevent production key usage in development.
- Dev environments MUST use `*_DEV` suffixed keys for MySQL passwords to prevent production password rotation from breaking local MySQL PVCs.
- The local overlay MUST rewrite ExternalSecret references to point to the `*_DEV` key variants.

#### Validation Tooling

- The `infisical-validate-mereka-lms.sh` script MUST verify that every `MEREKA_LMS_*` key referenced in `external-secrets.yaml` exists in Infisical at the canonical path.
- The validation script MUST fail if any required secret has an empty value or a placeholder value (`REPLACE_ME`, `CHANGE_ME`, `TODO`, `TBD`).
- The validation script MUST detect and warn on trailing CR/LF bytes in password-type secrets, and MUST fail when `STRICT=1` is set.
- The validation script SHOULD report additional secrets present in Infisical that are not referenced in `external-secrets.yaml`.
- The `infisical-audit-mereka-lms.sh` script MUST detect `MEREKA_LMS_*` keys outside the canonical `/k8s/mereka-lms` path.
- The `infisical-sync-mereka-lms.sh` script MUST consolidate scattered secrets into the canonical path.

#### Sprawl Cleanup

- If any `MEREKA_LMS_*` keys appear outside `/k8s/mereka-lms`, operators MUST re-sync from the authoritative path using the audit, sync, and validate scripts in sequence.

### Non-Functional Requirements

#### Security

- Secret values MUST NOT appear in terminal output, shell history, CI logs, or documentation files.
- The system MUST support secret rotation without application downtime (rolling restarts absorb new values within one ExternalSecrets refresh cycle).
- The pre-commit hook MUST detect at least: hardcoded passwords, API keys, secret keys with values, AWS credentials (`AKIA*`), private keys (`BEGIN RSA PRIVATE KEY`), JWTs (`eyJ*`), database URIs with embedded credentials, and placeholder values (`CHANGE_ME`, `changeme`).

#### Availability

- ExternalSecrets MUST reach `SecretSynced` status within 5 minutes of initial creation.
- ExternalSecrets MUST re-sync within 1 hour of upstream changes in GCP Secret Manager.
- Existing K8s Secrets MUST survive ExternalSecret resource deletion (`deletionPolicy: Retain`).
- Secret sync failures MUST NOT cause running pods to lose their current secret values.

#### Compliance

- The validation script (`STRICT=1`) MUST pass in both `prod` and `dev` environments before any production deployment.
- CI SHOULD run validation on every push to `main` when `INFISICAL_TOKEN` and `INFISICAL_PROJECT_ID` are configured as GitHub Actions secrets.

#### Operational

- Secret rotation from Infisical to running pods SHOULD complete within 30 minutes (1 hour maximum, bounded by ExternalSecrets refresh interval).
- The GCP SM service account MUST have both `roles/secretmanager.secretAccessor` and `roles/secretmanager.viewer` to prevent misleading 404 errors during sync.
- The sync script (`sync-mereka-lms-secrets-to-gcpsm.sh`) MUST strip trailing CR/LF bytes from values during sync to prevent authentication failures.

## Acceptance Criteria

### Pipeline Integrity

- [ ] AC-001: Given the production GKE cluster, when `kubectl get externalsecrets -n mereka-lms` is run, then both `openedx-secrets` and `database-secrets` show `STATUS=SecretSynced`.
- [ ] AC-002: Given a Deployment (e.g., `lms`), when its pod spec is inspected, then `envFrom` references `openedx-secrets` and `database-secrets` via `secretRef`.
- [ ] AC-003: Given a running LMS pod, when `echo $OPENEDX_SECRET_KEY` is executed inside the container, then a non-empty value is returned (confirming the pipeline delivers secrets to application code).

### Naming Convention Enforcement

- [ ] AC-004: Given the file `deploy/k8s/base/secrets/external-secrets.yaml`, when all `remoteRef.key` values are extracted, then every key starts with `MEREKA_LMS_`.
- [ ] AC-005: Given the `openedx-secrets` ExternalSecret, when its `data` array is inspected, then each entry maps a `MEREKA_LMS_*` remote key to an application-expected local `secretKey` (without the prefix).

### Infisical Path Compliance

- [ ] AC-006: Given the Infisical CLI, when `infisical-audit-mereka-lms.sh` is run, then zero `MEREKA_LMS_*` keys are found outside the `/k8s/mereka-lms` path.
- [ ] AC-007: Given both `prod` and `dev` Infisical environments, when `infisical-validate-mereka-lms.sh` is run, then it exits 0 confirming all expected keys exist.
- [ ] AC-008: Given `STRICT=1`, when `infisical-validate-mereka-lms.sh` is run in both `prod` and `dev`, then it exits 0 confirming no empty values, no placeholders, and no trailing CR/LF bytes.

### Secret Inventory Completeness

- [ ] AC-009: Given the `openedx-secrets` K8s Secret in production, when its keys are listed, then at least 33 keys are present matching the inventory table in this spec.
- [ ] AC-010: Given the `database-secrets` K8s Secret in production, when its keys are listed, then exactly 7 keys are present: `MYSQL_ROOT_PASSWORD`, `OPENEDX_MYSQL_PASSWORD`, `MYSQL_DISCOVERY_PASSWORD`, `MYSQL_ECOMMERCE_PASSWORD`, `MYSQL_NOTES_PASSWORD`, `MYSQL_XQUEUE_PASSWORD`, `MYSQL_CREDENTIALS_PASSWORD`.
- [ ] AC-011: Given the Infisical path `/k8s/mereka-lms/atlas`, when its keys are listed, then `ATLAS_PUBLIC_KEY`, `ATLAS_PRIVATE_KEY`, `ATLAS_ORG_ID`, and `ATLAS_PROJECT_ID` exist.

### No Hardcoded Secrets

- [ ] AC-012: Given the entire `deploy/k8s/` directory, when scanned with `grep -r` for known secret patterns (excluding `secretKeyRef`, `secretRef`, `remoteRef`, `SecretStore`, `ExternalSecret`, `secretName`, `secretGenerator`, and comments), then zero matches are returned.
- [ ] AC-013: Given a test commit containing a hardcoded password pattern, when `git commit` is run with the pre-commit hook active, then the commit is blocked.

### JWT Secret Uniqueness

- [ ] AC-014: Given all JWT secret keys in `openedx-secrets` (`JWT_SECRET_KEY_LMS`, `JWT_SECRET_KEY_CMS`, `JWT_SECRET_KEY_DISCOVERY`, `JWT_SECRET_KEY_ECOMMERCE`, `JWT_SECRET_KEY_NOTES`, `JWT_SECRET_KEY_XQUEUE`, `JWT_SECRET_KEY_CREDENTIALS`), when their GCP SM remote keys are inspected, then each maps to a distinct `MEREKA_LMS_JWT_SECRET_KEY_*` value (no two services share the same JWT secret).

### ExternalSecrets Configuration

- [ ] AC-015: Given both ExternalSecrets, when their specs are inspected, then `refreshInterval: 1h`, `secretStoreRef.name: gcp-secret-manager`, `target.deletionPolicy: Retain`, and `target.creationPolicy: Owner` are set.
- [ ] AC-016: Given the ClusterSecretStore `gcp-secret-manager`, when its spec is inspected, then `projectID: bbi-k8` and `secretVersionSelectionPolicy: LatestOrFail` are configured.

### Dev/Prod Separation

- [ ] AC-017: Given the local Kustomize overlay, when ExternalSecret patches are inspected, then Stripe and MySQL keys reference `*_DEV` suffixed GCP SM keys.

### Rotation Verification

- [ ] AC-018: Given a rotated secret value in Infisical, when `sync-mereka-lms-secrets-to-gcpsm.sh` is run followed by `kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync=$(date +%s) --overwrite`, then pods restarted after the sync receive the new value.

## Edge Cases

### Trailing Whitespace in Passwords

- MySQL and other services fail authentication (`ERROR 1045 Access denied`) if password values contain trailing `\r` or `\n` bytes. The validation script detects this pattern on password-type and OAuth secret keys. The `normalize-mysql-secrets.sh` script strips trailing whitespace from Infisical, GCP SM, and K8s values. Run with `APPLY=1` to fix, or dry-run without it to preview affected keys.

### ExternalSecret Sync Failure

- If the GCP SM ClusterSecretStore becomes unreachable (expired credentials, API disabled, IAM role revoked), ExternalSecrets enter `SecretSyncedError` state. Existing K8s Secrets are retained (`deletionPolicy: Retain`), so running pods continue to function. New pods cannot start if K8s Secrets are missing. Resolution: verify ClusterSecretStore credentials, check ESO pod logs, confirm IAM roles include both `secretAccessor` and `viewer`.

### Key Sprawl Outside Canonical Path

- If `MEREKA_LMS_*` keys are created at the Infisical root `/` or under `/mereka-lms` (without `/k8s/` prefix), the validation script will not find them and ExternalSecrets may read stale values. Detection: run `infisical-audit-mereka-lms.sh`. Resolution: run `infisical-sync-mereka-lms.sh prod` and `dev` to consolidate, then re-validate.

### Placeholder Values in Production

- Migration secrets and newly added keys are sometimes seeded with `REPLACE_ME` placeholders. If these propagate to production K8s Secrets (for migration keys that are not synced this is safe; for `openedx-secrets` it causes service failures). The validation script (`STRICT=1`) rejects placeholder values for all non-optional keys. Optional keys (currently `STRIPE_WEBHOOK_SECRET`) are allowed to have placeholders until the feature is enabled.

### GCP SM Secret Missing

- If a secret exists in Infisical but has not been synced to GCP SM, ExternalSecrets will fail to refresh with a `SecretNotFound` error. The `sync-mereka-lms-secrets-to-gcpsm.sh` script operates in create-if-missing mode by default. For keys that need update (e.g., Stripe rotation), the script supports selective overwrite via `OVERWRITE_ALLOWED_REGEX`.

### Kind MySQL Auth Drift After Rotation

- When production MySQL passwords are rotated in Infisical, the dev Kind cluster's MySQL PVC retains the old passwords, causing `1045 Access denied` errors. Resolution: run `K8S_CONTEXT=kind-dev ./scripts/infra/repair-kind-mysql-users.sh` to align MySQL users with current `database-secrets` values. Prevention: dev environments use `*_DEV` suffixed keys to isolate from production rotations.

### Concurrent Secret Updates

- If two operators modify the same secret in Infisical simultaneously, the last write wins. Infisical provides version history, but there is no merge mechanism. Coordination: use the rotation checklist and communicate rotations via the team channel.

### ESO Service Account IAM Drift

- The GCP service account `external-secrets-gcp` requires both `roles/secretmanager.secretAccessor` (read payload) and `roles/secretmanager.viewer` (read metadata). If the `viewer` role is removed, ESO returns misleading `404 / Secret does not exist` errors even though the secret exists. Resolution: re-grant both roles via `gcloud projects add-iam-policy-binding`.

## Observability

### Logs

- ExternalSecrets Operator pod logs MUST be collected by Promtail and forwarded to Loki with labels `namespace=external-secrets`, `pod`, `container`.
- Secret sync events (success and failure) SHOULD be queryable in Loki using the label filter `{namespace="external-secrets"} |= "SecretSynced" or |= "SecretSyncedError"`.
- The `infisical-validate-mereka-lms.sh` script logs timestamped progress messages and MUST output missing/empty/placeholder key names to stderr on failure.
- The `sync-mereka-lms-secrets-to-gcpsm.sh` script SHOULD log which keys were created, skipped, or updated without printing values.

### Metrics

- The ExternalSecrets Operator exposes Prometheus metrics at `/metrics`. The following SHOULD be scraped:
  - `externalsecret_status_condition{type="Ready",status="True"}` -- count of synced ExternalSecrets
  - `externalsecret_status_condition{type="Ready",status="False"}` -- count of failed ExternalSecrets
  - `externalsecret_reconcile_duration_seconds` -- reconciliation latency
- A custom metric or probe SHOULD track the total number of keys in `openedx-secrets` and `database-secrets` to detect unexpected key count changes.

### Alerts

- An alert MUST fire if any ExternalSecret in `mereka-lms` namespace has `status.condition.type=Ready` with `status=False` for more than 10 minutes (severity: critical).
- An alert SHOULD fire if `externalsecret_reconcile_duration_seconds` p95 exceeds 5 minutes (severity: warning).
- The `OpenEdxSyntheticOrBackupJobFailures` PrometheusRule (defined in `specs/k8s-deployment_spec.md`) covers synthetic verification CronJobs that indirectly validate secrets by testing authentication flows.

### Dashboards

- A Grafana dashboard panel SHOULD display ExternalSecret sync status (synced vs. error count) for the `mereka-lms` namespace.
- The panel SHOULD include time-series of reconciliation duration to detect sync degradation trends.

## Rollout & Rollback

### Adding a New Secret

1. Create the secret in Infisical under `/k8s/mereka-lms` (or the appropriate sub-path) in both `prod` and `dev` environments.
2. Create the corresponding secret in GCP Secret Manager with the `MEREKA_LMS_` prefix:
   ```bash
   ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```
3. Add the key mapping to `deploy/k8s/base/secrets/external-secrets.yaml` under the appropriate ExternalSecret (`openedx-secrets` or `database-secrets`).
4. Run validation:
   ```bash
   STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
   STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh
   ```
5. Apply the updated ExternalSecret: `kubectl apply -f deploy/k8s/base/secrets/external-secrets.yaml`
6. Force sync: `kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite`
7. Verify: `kubectl get externalsecrets -n mereka-lms` shows `SecretSynced`.
8. Restart affected Deployments to pick up the new env var.

### Rotating an Existing Secret

Follow `docs/runbooks/operations/SECRET_ROTATION_CHECKLIST.md`:

1. **Contain**: Identify the compromised or expired credential and its blast radius.
2. **Rotate in Infisical**: Update the value at `/k8s/mereka-lms` (source of truth only).
3. **Propagate to GCP SM**:
   ```bash
   ./scripts/infra/sync-mereka-lms-secrets-to-gcpsm.sh
   ```
4. **Validate**:
   ```bash
   STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh
   ```
5. **Force ESO refresh and rolling restart**:
   ```bash
   kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite
   kubectl rollout restart deployment/lms deployment/cms -n mereka-lms
   ```
6. **Verify runtime health**:
   ```bash
   CHECK_CERTS=1 CHECK_BRANDING=1 ./scripts/qa/public-health-check.sh prod
   ./scripts/qa/verify-auth-hardening.sh
   ```
7. **Invalidate old credential** at the provider (Stripe dashboard, Atlas console, AWS IAM, etc.).
8. **Evidence**: Run `STRICT=1 ./scripts/qa/scan-secrets-fast.sh` and document in a bead.

### Backward Compatibility

- ExternalSecrets `deletionPolicy: Retain` ensures K8s Secrets survive accidental ExternalSecret resource deletion.
- Pods with `envFrom` continue using cached env vars until restarted; a rotation does not force-restart pods.
- The `sync-mereka-lms-secrets-to-gcpsm.sh` script uses create-if-missing by default, preventing accidental overwrites of production database passwords during routine Stripe rotations.

### Rollback Steps

1. If a rotated secret causes application failures, revert the value in Infisical to the previous version (Infisical maintains version history).
2. Re-run `sync-mereka-lms-secrets-to-gcpsm.sh` to propagate the reverted value.
3. Force ESO refresh: `kubectl annotate externalsecret openedx-secrets -n mereka-lms force-sync="$(date +%s)" --overwrite`
4. Restart affected pods: `kubectl rollout restart deployment/<name> -n mereka-lms`
5. Verify: `kubectl get externalsecrets -n mereka-lms` shows `SecretSynced` and application health checks pass.

### Emergency Procedures

- **Secret leaked in git**: Immediately rotate the credential in Infisical, propagate to GCP SM and K8s, invalidate the old credential at the provider, run `scan-secrets-fast.sh`, and file an incident bead.
- **All ExternalSecrets in error state**: Check ESO operator pod logs, verify ClusterSecretStore credentials, verify GCP IAM roles. Running pods retain their current secrets and are unaffected.
- **MySQL 1045 after rotation**: Run `./scripts/infra/normalize-mysql-secrets.sh` to detect trailing CR/LF; run with `APPLY=1` to fix. For Kind dev, run `K8S_CONTEXT=kind-dev ./scripts/infra/repair-kind-mysql-users.sh`.

## Verification

```bash
# 1. ExternalSecrets are synced
kubectl get externalsecrets -n mereka-lms  # STATUS: SecretSynced for both

# 2. K8s secrets exist with correct key counts
kubectl get secret openedx-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys | length'  # >= 33
kubectl get secret database-secrets -n mereka-lms -o jsonpath='{.data}' | jq 'keys | length'  # == 7

# 3. Pods have envFrom referencing secrets
kubectl get deploy lms -n mereka-lms -o yaml | grep -A3 envFrom  # MUST show secretRef

# 4. No hardcoded secrets in manifests
grep -rn "password\|secret_key\|api_key" deploy/k8s/base/ --include="*.yml" --include="*.yaml" \
  | grep -v "secretKeyRef\|secretRef\|remoteRef\|SecretStore\|ExternalSecret\|secretName\|Secret\|secretGenerator" \
  | grep -v "#"
# MUST return empty

# 5. Naming convention compliance
grep -oP 'key: \K[A-Z_]+' deploy/k8s/base/secrets/external-secrets.yaml | sort -u | grep -v '^MEREKA_LMS_'
# MUST return empty (all remote keys start with MEREKA_LMS_)

# 6. Infisical path compliance (prod + dev)
INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh   # MUST exit 0
INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh   # MUST exit 0

# 7. Strict validation (no empty values, no placeholders, no trailing whitespace)
STRICT=1 INFISICAL_ENV=prod ./scripts/infra/infisical-validate-mereka-lms.sh  # MUST exit 0
STRICT=1 INFISICAL_ENV=dev  ./scripts/infra/infisical-validate-mereka-lms.sh  # MUST exit 0

# 8. Infisical key sprawl check
./scripts/infra/infisical-audit-mereka-lms.sh  # MUST find zero keys outside canonical path

# 9. Secret hygiene scan
STRICT=1 ./scripts/qa/scan-secrets-fast.sh  # MUST pass

# 10. ExternalSecret configuration compliance
kubectl get externalsecret openedx-secrets -n mereka-lms -o jsonpath='{.spec.refreshInterval}'   # 1h
kubectl get externalsecret openedx-secrets -n mereka-lms -o jsonpath='{.spec.target.deletionPolicy}'  # Retain
```

## Open Questions

- Should ExternalSecrets `refreshInterval` be reduced from `1h` to `15m` to shorten the window between secret rotation and pod consumption? This trades faster propagation for higher GCP SM API costs.
- Should CI validation via `infisical-validate-mereka-lms.sh` be made a required check (blocking merge) rather than an optional advisory check? This requires `INFISICAL_TOKEN` and `INFISICAL_PROJECT_ID` as GitHub Actions secrets.
- Should we implement automated secret rotation for database passwords using a CronJob or external automation tool? Current manual rotation via the checklist works but introduces human error risk.
- What is the minimum acceptable entropy for generated secrets (e.g., 256-bit for JWT keys, 128-bit for database passwords)? Currently there is no formal entropy requirement.
- ~~Should we add a `mereka-lms-runtime-secrets` ExternalSecret to this spec?~~ **RESOLVED**: `mereka-lms-runtime-secrets` is referenced in `deploy/k8s/base/deployments.yml` envFrom (4 deployments: lms, lms-worker, cms, cms-worker) with `optional: true`. No ExternalSecret definition exists. **Decision**: Keep the reference with `optional: true` as a forward-compatible hook for future runtime secrets (e.g., feature flags, A/B test configs). Define the ExternalSecret when the first runtime secret is needed. No action required now.
