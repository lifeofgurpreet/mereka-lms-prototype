# RKE2 Deployment Blockers — Post-Sync State

> **Date**: 2026-02-19T22:40 UTC
> **Context**: rke2-nonprod
> **ArgoCD app**: mereka-lms-local — **Synced / Degraded**
> **Beads**: mereka-lms-20eb, mereka-lms-288f, mereka-lms-5ngf.2

---

## Progress Since Last Report

ArgoCD `mereka-lms-local` is now **Synced** (SSH fix applied by bbi-infrastructure). Pods are deploying. Two new blockers:

---

## Blocker 1: ExternalSecrets — `gcp-secret-manager` ClusterSecretStore Invalid

### Error
```
ClusterSecretStore gcp-secret-manager: InvalidProviderConfig
  failed to create GCP secretmanager client: ServiceAccount "external-secrets-gcp" not found
```

### Root Cause
The ExternalSecrets in `deploy/k8s/base/secrets/external-secrets.yaml` reference `gcp-secret-manager` ClusterSecretStore. This store uses Workload Identity with SA `external-secrets-gcp@bbi-k8.iam.gserviceaccount.com` — which only exists on GKE clusters, not rke2.

Available stores on rke2-nonprod:
```
NAME                     STATUS    READY
gcp-secret-manager       False     ← Invalid (no GKE Workload Identity)
infisical-secret-store   True      ← Valid/ReadOnly ✅
```

### Fix Required (bbi-infrastructure)
Create an rke2-specific ExternalSecrets overlay that uses `infisical-secret-store` instead of `gcp-secret-manager`. The Infisical store is already Valid/Ready on rke2-nonprod.

OR: Configure `gcp-secret-manager` with a service account key file (JSON key instead of Workload Identity) in an rke2-specific secret.

### Affected ExternalSecrets (all 4 fail)
```
database-secrets           SecretSyncedError
enterprise-sso-secrets     SecretSyncedError
openedx-secrets            SecretSyncedError
payments-gateway-secrets   SecretSyncedError
```

---

## Blocker 2: ImagePullBackOff — No GCP Artifact Registry Credentials

### Error
```
failed to authorize: failed to fetch anonymous token:
unexpected status from GET request to
https://asia-southeast1-docker.pkg.dev/v2/token?scope=...: 403 Forbidden
Image: asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:mereka-brand-hotfix-full-v3
```

### Root Cause
rke2-nonprod has no `imagePullSecret` for `asia-southeast1-docker.pkg.dev`. No `kubernetes.io/dockerconfigjson` secrets exist in `mereka-lms` namespace.

### Fix Required (bbi-infrastructure)
Create an image pull secret with GCP Artifact Registry credentials:
```bash
# Option A: Service account JSON key
kubectl --context rke2-nonprod create secret docker-registry artifact-registry-key \
  -n mereka-lms \
  --docker-server=asia-southeast1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat /path/to/sa-key.json)" \
  --docker-email=ci@mereka.io

# Option B: Access token (short-lived)
kubectl --context rke2-nonprod create secret docker-registry artifact-registry-key \
  -n mereka-lms \
  --docker-server=asia-southeast1-docker.pkg.dev \
  --docker-username=oauth2accesstoken \
  --docker-password="$(gcloud auth print-access-token)" \
  --docker-email=ci@mereka.io
```

Then patch the relevant Deployments (or ServiceAccount default) to use `imagePullSecrets: [{name: artifact-registry-key}]`.

### Affected Pods (ImagePullBackOff)
```
lms, lms-worker, cms, mfe
enterprise-admin-portal, enterprise-learner-portal
enterprise-access-worker, enterprise-catalog-worker
```

### Running Pods (images from public registries — unaffected)
```
caddy            1/1 Running  ✅
elasticsearch    1/1 Running  ✅
mongodb-exporter 1/1 Running  ✅
```

---

## Blocker 3: CreateContainerConfigError — Secrets Missing

`meilisearch` and `postgresql-payments` pods fail with `CreateContainerConfigError` — they reference secrets from ExternalSecrets that haven't synced (Blocker 1 cascade).

Resolves automatically when Blocker 1 is fixed.

---

## Current Pod State (22:40 UTC)

| Pod | Status | Blocker |
|-----|--------|---------|
| caddy | ✅ Running | — |
| elasticsearch | ✅ Running | — |
| mongodb-exporter | ✅ Running | — |
| lms | ❌ ImagePullBackOff | Blocker 2 |
| lms-worker | ❌ ImagePullBackOff | Blocker 2 |
| cms | ❌ ImagePullBackOff | Blocker 2 |
| mfe | ❌ ImagePullBackOff | Blocker 2 |
| enterprise-admin-portal | ❌ ImagePullBackOff | Blocker 2 |
| enterprise-learner-portal | ❌ ImagePullBackOff | Blocker 2 |
| enterprise-access-worker | ❌ ImagePullBackOff | Blocker 2 |
| enterprise-catalog-worker | ❌ ImagePullBackOff | Blocker 2 |
| meilisearch | ❌ CreateContainerConfigError | Blocker 1 |
| postgresql-payments | ❌ CreateContainerConfigError | Blocker 1 |
| promtail | ContainerCreating | — |

---

## Actions Required from bbi-infrastructure

| # | Action | Owner | Blocker |
|---|--------|-------|---------|
| 1 | Create `imagePullSecret` for `asia-southeast1-docker.pkg.dev` in `mereka-lms` ns | bbi-infra | Blocker 2 |
| 2 | Patch Deployments (or default SA) to use `imagePullSecrets` | bbi-infra | Blocker 2 |
| 3 | Create rke2-specific ExternalSecrets overlay using `infisical-secret-store` | bbi-infra | Blocker 1 |

## Resume Gate for 288f / 5ngf.2

Will run smoke matrix immediately when:
1. `kubectl --context rke2-nonprod get pods -n mereka-lms` → lms/cms/caddy all `Running`
2. `kubectl --context rke2-nonprod get externalsecret -n mereka-lms` → all `SecretSynced`
