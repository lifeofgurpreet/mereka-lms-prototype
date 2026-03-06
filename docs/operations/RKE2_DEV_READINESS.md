# RKE2 Dev Readiness Runbook

> **Cluster**: `rke2-nonprod` (single-node, v1.34.3+rke2r3)
> **Namespace**: `mereka-lms`
> **ArgoCD source**: `infrastructure` repo (legacy name: `infrastructure`), path `apps/mereka-lms/overlays/profiles/dev`

## Architecture

```
infrastructure repo
  apps/mereka-lms/
    base/                         # Shared Tutor-generated manifests
    overlays/
      dev/                        # Dev overlay (domain patches, Infisical ESO, Caddy config)
      profiles/
        dev/                      # Dev profile (resource limits, replica policy, governance)
          kustomization.yaml      # References ../../local as base
          patches/
            workload-profile.yaml # Deployment replica policy + resource limits
          limitrange.yaml         # Container min/max/default
          resourcequota.yaml      # Namespace-level CPU/memory/pod caps
          runtime-secrets-placeholder.yaml
          default-serviceaccount.yaml  # imagePullSecrets: dev-image-puller
```

The `profiles/dev` overlay layers on top of `overlays/dev`, adding resource governance and an explicit deployment replica policy appropriate for the single-node RKE2 cluster.

## Root Cause Analysis

### CreateContainerConfigError (LMS/CMS pods)

**Cause**: Pods reference `mereka-lms-runtime-secrets` secret via `envFrom`, but the secret does not exist in the namespace.

**Fix**: The `profiles/dev` overlay includes `runtime-secrets-placeholder.yaml` which creates a minimal placeholder secret. Ensure ArgoCD points to `profiles/dev` (not `overlays/dev`).

### ImagePullBackOff (all pods)

**Cause**: Images are hosted in GCP Artifact Registry (`ghcr.io/biji-biji-initiative/mereka-lms/`). RKE2 nodes lack GCP Workload Identity, so they cannot pull without an explicit imagePullSecret.

**Fix**: Create a `dev-image-puller` secret with a GCP service account key, and patch the default ServiceAccount (done by `profiles/dev/default-serviceaccount.yaml`).

### CrashLoopBackOff (MySQL)

**Cause**: MySQL container requires `MYSQL_ROOT_PASSWORD` from `database-secrets`. If the ExternalSecret has not synced or the Infisical key is missing, MySQL gets an empty password and refuses to start.

**Fix**: Ensure `MEREKA_LMS_MYSQL_ROOT_PASSWORD` is set in Infisical for the dev environment, and the ExternalSecret syncs successfully.

## Step-by-Step Fix Instructions

### 1. Switch ArgoCD to profiles/dev path

In `infrastructure`, update the ArgoCD Application for `mereka-lms`:

```yaml
spec:
  source:
    path: apps/mereka-lms/overlays/profiles/dev   # NOT overlays/dev
```

Commit and push. Wait for ArgoCD to reconcile (up to 3 minutes).

Verify:
```bash
kubectl --context rke2-nonprod get app mereka-lms-dev -n argocd \
  -o jsonpath='{.spec.source.path}'
# Expected: apps/mereka-lms/overlays/profiles/dev
```

### 2. Set MYSQL_ROOT_PASSWORD in Infisical

```bash
INFISICAL=/home/gurpreet/projects/vps/infrastructure/scripts/infisical
${INFISICAL} secrets set MEREKA_LMS_MYSQL_ROOT_PASSWORD="<password>" \
  --domain https://secrets.mereka.io/api --env dev --path /
```

Trigger ExternalSecret refresh:
```bash
kubectl --context rke2-nonprod annotate externalsecret database-secrets \
  -n mereka-lms force-sync="$(date +%s)" --overwrite
```

Verify:
```bash
kubectl --context rke2-nonprod get externalsecret database-secrets \
  -n mereka-lms -o jsonpath='{.status.conditions[0].type}'
# Expected: Ready
```

### 3. Add ses-smtp-credentials placeholder

The base manifests reference `ses-smtp-credentials`. In dev, create a placeholder:

```bash
kubectl --context rke2-nonprod create secret generic ses-smtp-credentials \
  -n mereka-lms \
  --from-literal=RELAY_USERNAME=dev \
  --from-literal=RELAY_PASSWORD=dev \
  --dry-run=client -o yaml | kubectl --context rke2-nonprod apply -f -
```

Or add it to the `profiles/dev/kustomization.yaml` as a `secretGenerator` entry (preferred, GitOps-compliant).

### 4. Create dev-image-puller registry secret

Generate a GCP SA key with Artifact Registry Reader permissions:

```bash
# Create key (one-time)
gcloud iam service-accounts keys create /tmp/ar-key.json \
  --iam-account=artifact-reader@mereka-lms.iam.gserviceaccount.com

# Create K8s secret
kubectl --context rke2-nonprod create secret docker-registry dev-image-puller \
  -n mereka-lms \
  --docker-server=asia-southeast1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat /tmp/ar-key.json)" \
  --docker-email=artifact-reader@mereka-lms.iam.gserviceaccount.com

# Clean up
rm /tmp/ar-key.json
```

The `profiles/dev/default-serviceaccount.yaml` patches the default ServiceAccount to reference this secret.

## Verification

Run the automated readiness check:

```bash
# Offline only (no cluster needed)
./scripts/qa/verify-rke2-dev-readiness.sh --offline

# Full check (requires rke2-nonprod context)
./scripts/qa/verify-rke2-dev-readiness.sh

# Custom context
KUBE_CONTEXT=my-context ./scripts/qa/verify-rke2-dev-readiness.sh
```

Quick manual checks:

```bash
# All pods healthy
kubectl --context rke2-nonprod get pods -n mereka-lms

# No error states
kubectl --context rke2-nonprod get pods -n mereka-lms \
  --field-selector=status.phase!=Running,status.phase!=Succeeded

# ExternalSecrets synced
kubectl --context rke2-nonprod get externalsecret -n mereka-lms

# LMS responding
kubectl --context rke2-nonprod exec -n mereka-lms deploy/caddy -- \
  wget -qO- --timeout=5 http://lms:8000/heartbeat
```

## Known Issues and Workarounds

| Issue | Workaround |
|-------|------------|
| `kubectl kustomize` fails on profiles/dev | Ensure `yq` and `kubectl` >= 1.27 are installed; check `BBI_INFRA_DIR` path is correct |
| ExternalSecret `SecretSyncError` | Verify `infisical-secret-store` ClusterSecretStore is Ready: `kubectl get clustersecretstore -A` |
| MySQL init loop after PVC wipe | `workload-profile.yaml` sets `MYSQL_ALLOW_EMPTY_PASSWORD=yes` for fresh init; set real password in Infisical after first boot |
| 110-pod limit on single node | Keep the `profiles/dev/patches/workload-profile.yaml` replica policy minimal and adjust only with capacity review |
| Caddy 502 after deploy | LMS/CMS take 2-3 minutes to start; check `kubectl logs -n mereka-lms deploy/lms --tail=20` for uWSGI ready message |
