# RKE2 Deployment Runbook — Mereka LMS

> **Version**: 1.0
> **Date**: 2026-02-19
> **Author**: BoldBadger (via bead mereka-lms-3st7)
> **Status**: LIVE — reflects blockers discovered on first full rke2-nonprod deploy run

This runbook covers deploying Mereka LMS to rke2-nonprod from zero. It consolidates all
hard-won lessons from the 2026-02-19 deployment session into repeatable, non-brittle steps.

---

## Table of Contents

1. [Pre-conditions Checklist](#1-pre-conditions-checklist)
2. [Top 3 Long-Hold Blockers (with Owners)](#2-top-3-long-hold-blockers-with-owners)
3. [Deployment Command Sequence](#3-deployment-command-sequence)
4. [Expected Signatures at Each Step](#4-expected-signatures-at-each-step)
5. [Rollback Paths](#5-rollback-paths)
6. [Resume Gate for Smoke Tests](#6-resume-gate-for-smoke-tests)
7. [Rollout Timing Reference](#7-rollout-timing-reference)
8. [Cluster Differences: rke2 vs GKE](#8-cluster-differences-rke2-vs-gke)
9. [Follow-up Beads for Unresolved Risk Items](#9-follow-up-beads-for-unresolved-risk-items)

---

## 1. Pre-conditions Checklist

Run these before attempting a deployment. All must pass.

### 1.1 Infrastructure Requirements

- [ ] `kubectl --context rke2-nonprod cluster-info` returns without error
- [ ] ArgoCD running: `kubectl --context rke2-nonprod get pods -n argocd | grep Running`
- [ ] ExternalSecrets operator running: `kubectl --context rke2-nonprod get pods -n external-secrets | grep Running`
- [ ] `infisical-secret-store` ClusterSecretStore is **Valid/Ready**:
  ```bash
  kubectl --context rke2-nonprod get clustersecretstore infisical-secret-store
  # Expected: STATUS=Valid, READY=True
  ```
- [ ] **NOT required on rke2**: `gcp-secret-manager` ClusterSecretStore (GKE-only, uses Workload Identity)

### 1.2 ArgoCD Connectivity

- [ ] ArgoCD repo-server can reach GitHub via SSH (port 22):
  ```bash
  kubectl --context rke2-nonprod exec -n argocd deploy/argocd-repo-server -- \
    ssh -T git@github.com 2>&1 | grep -E "Hi|successfully authenticated"
  ```
  If this fails: see [Blocker A — SSH Connectivity](#blocker-a-ssh-deploy-key-for-argocd)

- [ ] ArgoCD repo secret `argocd-repo-mereka-lms` uses SSH format:
  ```bash
  kubectl --context rke2-nonprod get secret argocd-repo-mereka-lms -n argocd \
    -o jsonpath='{.data.url}' | base64 -d
  # Expected: git@github.com:Biji-Biji-Initiative/mereka-lms.git
  # (NOT https://github.com — port 443 is blocked by Cilium)
  ```
  If wrong: see [Blocker A — SSH Connectivity](#blocker-a-ssh-deploy-key-for-argocd)

### 1.3 Secrets Store

- [ ] ExternalSecrets overlay uses `infisical-secret-store` (not `gcp-secret-manager`):
  ```bash
  kubectl --context rke2-nonprod get externalsecret -n mereka-lms \
    -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.secretStoreRef.name}{"\n"}{end}'
  # Expected: all lines show infisical-secret-store
  ```
  If wrong: see [Blocker B — ExternalSecrets Store](#blocker-b-externalsecrets-store-mismatch)

### 1.4 Image Pull Credentials

- [ ] `artifact-registry-key` secret exists in `mereka-lms` namespace:
  ```bash
  kubectl --context rke2-nonprod get secret artifact-registry-key -n mereka-lms
  ```
  If missing: see [Blocker C — ImagePullBackOff](#blocker-c-imagepullbackoff--artifact-registry)

- [ ] Default ServiceAccount or relevant Deployments reference `imagePullSecrets: [{name: artifact-registry-key}]`

### 1.5 Namespace

- [ ] `mereka-lms` namespace exists:
  ```bash
  kubectl --context rke2-nonprod get ns mereka-lms
  ```

---

## 2. Top 3 Long-Hold Blockers (with Owners)

These are the blockers that caused the most delay in the 2026-02-19 deployment session.
Ordered by time cost.

### Blocker A: SSH Deploy Key for ArgoCD

**Hold time**: ~3 hours (root cause diagnosis + bbi-infrastructure fix)
**Owner**: bbi-infrastructure team
**Symptom**:
```
mereka-lms-local: ComparisonError
Error: hit 27s timeout running git fetch https://github.com/Biji-Biji-Initiative/mereka-lms.git
```
**Root cause**: Cilium NetworkPolicy on rke2-nonprod blocks HTTPS (port 443) egress from `argocd`
namespace to `github.com`. SSH port 22 works.

**One-time fix** (bbi-infrastructure):
1. Generate deploy key and add to GitHub:
   ```bash
   ssh-keygen -t ed25519 -C "argocd-rke2-mereka-lms" -f /tmp/mereka-lms-deploy-key -N ""
   # Add public key as Deploy Key in GitHub:
   # Biji-Biji-Initiative/mereka-lms → Settings → Deploy Keys → Add key
   ```
2. Update ArgoCD repo secret:
   ```bash
   kubectl --context rke2-nonprod delete secret argocd-repo-mereka-lms -n argocd 2>/dev/null || true
   kubectl --context rke2-nonprod create secret generic argocd-repo-mereka-lms \
     -n argocd \
     --from-literal=url=git@github.com:Biji-Biji-Initiative/mereka-lms.git \
     --from-literal=sshPrivateKey="$(cat /tmp/mereka-lms-deploy-key)" \
     --from-literal=insecureIgnoreHostKey=true
   kubectl --context rke2-nonprod label secret argocd-repo-mereka-lms \
     -n argocd "argocd.argoproj.io/secret-type=repository"
   ```
3. In `bbi-infrastructure: apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`,
   change the remote resource from HTTPS to SSH:
   ```yaml
   # Before (broken):
   resources:
     - https://github.com/Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=<commit>
   # After (fixed):
   resources:
     - git@github.com:Biji-Biji-Initiative/mereka-lms.git//deploy/k8s/base?ref=<commit>
   ```
4. Trigger hard refresh: `argocd app get mereka-lms-local --hard-refresh`

**Prevention**: Deploy key is now in place. Future deploys just need to update `?ref=<commit>`.
**Evidence**: `docs/operations/evidence/rke2/20260219T2120-rke2-github-connectivity.md`

---

### Blocker B: ExternalSecrets Store Mismatch

**Hold time**: ~1 hour (diagnosis + escalation to bbi-infrastructure)
**Owner**: bbi-infrastructure team
**Symptom**:
```
ClusterSecretStore gcp-secret-manager: InvalidProviderConfig
  failed to create GCP secretmanager client: ServiceAccount "external-secrets-gcp" not found
```
All 4 ExternalSecrets in `mereka-lms` namespace stuck in `SecretSyncedError`.

**Root cause**: `deploy/k8s/base/secrets/external-secrets.yaml` references `gcp-secret-manager`
ClusterSecretStore, which uses GKE Workload Identity. On rke2, there is no Workload Identity.
The `infisical-secret-store` ClusterSecretStore is already Valid/Ready on rke2-nonprod.

**Fix** (bbi-infrastructure, rke2-specific overlay):
Create `deploy/k8s/overlays/rke2-nonprod/secrets-patch.yaml`:
```yaml
# Patch all ExternalSecrets to use infisical-secret-store instead of gcp-secret-manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
  namespace: mereka-lms
spec:
  secretStoreRef:
    name: infisical-secret-store
    kind: ClusterSecretStore
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: database-secrets
  namespace: mereka-lms
spec:
  secretStoreRef:
    name: infisical-secret-store
    kind: ClusterSecretStore
# (repeat for enterprise-sso-secrets, payments-gateway-secrets)
```

**Prevention**: Maintain separate ExternalSecrets overlays per cluster type (GKE vs rke2).
**Evidence**: `docs/operations/evidence/rke2/20260219T2240-rke2-deployment-blockers.md`

---

### Blocker C: ImagePullBackOff / Artifact Registry

**Hold time**: ~1 hour (diagnosis + bbi-infrastructure action)
**Owner**: bbi-infrastructure team
**Symptom**:
```
failed to authorize: failed to fetch anonymous token:
unexpected status from GET request to https://asia-southeast1-docker.pkg.dev/v2/token?...: 403 Forbidden
```
All LMS pods stuck in `ImagePullBackOff`.

**Root cause**: `asia-southeast1-docker.pkg.dev` is a private GCP Artifact Registry. rke2-nonprod
has no `imagePullSecret` to authenticate against it.

**Fix** (bbi-infrastructure):
```bash
# Option A (long-lived): Service account JSON key
kubectl --context rke2-nonprod create secret docker-registry artifact-registry-key \
  -n mereka-lms \
  --docker-server=asia-southeast1-docker.pkg.dev \
  --docker-username=_json_key \
  --docker-password="$(cat /path/to/gcp-sa-key.json)" \
  --docker-email=ci@mereka.io

# Option B (short-lived, ~1hr): OAuth access token
kubectl --context rke2-nonprod create secret docker-registry artifact-registry-key \
  -n mereka-lms \
  --docker-server=asia-southeast1-docker.pkg.dev \
  --docker-username=oauth2accesstoken \
  --docker-password="$(gcloud auth print-access-token)" \
  --docker-email=ci@mereka.io

# Then patch default ServiceAccount to use it (applies to all pods in namespace):
kubectl --context rke2-nonprod patch serviceaccount default \
  -n mereka-lms \
  -p '{"imagePullSecrets": [{"name": "artifact-registry-key"}]}'
```

**Prevention**: Use Option A (SA key), store key in Infisical, create via ExternalSecret → imagePullSecret.
A `Job` or `CronJob` can rotate the OAuth token periodically if Option B is preferred.
**Evidence**: `docs/operations/evidence/rke2/20260219T2240-rke2-deployment-blockers.md`

---

## 3. Deployment Command Sequence

This is the full deployment sequence once all pre-conditions pass.

```bash
CONTEXT=rke2-nonprod
NS=mereka-lms

# Step 1: Verify ArgoCD app exists and source is correct
kubectl --context $CONTEXT get app mereka-lms-local -n argocd \
  -o jsonpath='{.spec.source.repoURL}{"\n"}{.spec.source.targetRevision}'
# Expected: git@github.com:Biji-Biji-Initiative/mereka-lms.git + target revision

# Step 2: Hard refresh to pick up latest commit
argocd --kubeconfig ~/.kube/config app get mereka-lms-local \
  --server argocd.rke2-nonprod.mereka.dev \
  --hard-refresh
# OR via kubectl annotation:
kubectl --context $CONTEXT annotate app mereka-lms-local \
  -n argocd argocd.argoproj.io/refresh=hard --overwrite

# Step 3: Wait for Synced state
kubectl --context $CONTEXT wait app mereka-lms-local \
  -n argocd --for=condition=Synced --timeout=120s

# Step 4: Verify ExternalSecrets synced
kubectl --context $CONTEXT get externalsecret -n $NS
# Expected: all STATUS=SecretSynced

# Step 5: Verify pods starting
kubectl --context $CONTEXT get pods -n $NS --watch
# Wait for caddy, lms, cms to reach Running/Ready

# Step 6: Verify endpoints populated
kubectl --context $CONTEXT get endpoints -n $NS
# Expected: non-empty ENDPOINTS for caddy, lms, cms
# Empty endpoints = service selector mismatch = site down (check labels)

# Step 7: DNS smoke
curl -I https://lms.staging.mereka.dev 2>&1 | head -5
# Expected: HTTP/2 200

# Step 8: LMS health check
curl -s https://lms.staging.mereka.dev/heartbeat/ | python3 -m json.tool
# Expected: {"OK": true} or similar healthy response
```

---

## 4. Expected Signatures at Each Step

| Step | Command | Expected Output |
|------|---------|-----------------|
| ArgoCD app synced | `kubectl get app mereka-lms-local -n argocd` | `STATUS=Synced HEALTH=Healthy` |
| ExternalSecrets | `kubectl get externalsecret -n mereka-lms` | All `SecretSynced` |
| Pods running | `kubectl get pods -n mereka-lms` | `caddy/lms/cms` → `1/1 Running` |
| Endpoints | `kubectl get endpoints caddy -n mereka-lms` | Non-empty `ENDPOINTS` column |
| LMS reachable | `curl -I https://lms.staging.mereka.dev` | `HTTP/2 200` |
| LMS health | `curl https://lms.staging.mereka.dev/heartbeat/` | `{"OK": true}` |
| Studio reachable | `curl -I https://studio.staging.mereka.dev` | `HTTP/2 200` |
| MFE authn | `curl -I https://apps.staging.mereka.dev/authn/login` | `HTTP/2 200` |

---

## 5. Rollback Paths

### 5.1 Pod-Level Rollback (image tag rollback)

```bash
# Roll back a single deployment to previous image tag
kubectl --context rke2-nonprod rollout undo deployment/lms -n mereka-lms

# Check rollout history
kubectl --context rke2-nonprod rollout history deployment/lms -n mereka-lms
```

### 5.2 ArgoCD Rollback (commit-level)

```bash
# List history
argocd app history mereka-lms-local

# Roll back to specific revision
argocd app rollback mereka-lms-local <REVISION_ID>
```

### 5.3 Full Namespace Nuke (last resort)

```bash
# Delete all resources in namespace (keeps namespace itself)
kubectl --context rke2-nonprod delete all --all -n mereka-lms

# Re-sync from ArgoCD to restore
kubectl --context rke2-nonprod annotate app mereka-lms-local \
  -n argocd argocd.argoproj.io/refresh=hard --overwrite
```

**Warning**: Full nuke destroys PVCs. Only use if PVCs are ephemeral/test data.

### 5.4 ExternalSecrets Force Resync

```bash
# Annotate secret to force immediate resync
kubectl --context rke2-nonprod annotate externalsecret openedx-secrets \
  -n mereka-lms force-sync="$(date +%s)" --overwrite
```

---

## 6. Resume Gate for Smoke Tests

**Do not run smoke matrix until ALL conditions pass:**

```bash
# Gate 1: All core pods Running
kubectl --context rke2-nonprod get pods -n mereka-lms \
  -l "app.kubernetes.io/name in (lms,cms,caddy)" \
  --field-selector=status.phase=Running
# Expected: 3 pods shown (lms, cms, caddy)

# Gate 2: ExternalSecrets all synced
kubectl --context rke2-nonprod get externalsecret -n mereka-lms \
  -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[0].reason
# Expected: all STATUS=SecretSynced

# Gate 3: DNS resolves
curl -s -o /dev/null -w "%{http_code}" https://lms.staging.mereka.dev
# Expected: 200

# Gate 4: LMS health
curl -s https://lms.staging.mereka.dev/heartbeat/ | grep -q '"OK"'
# Expected: exits 0
```

---

## 7. Rollout Timing Reference

Based on the 2026-02-19 first-deploy session:

| Phase | Duration | Notes |
|-------|----------|-------|
| ArgoCD SSH root cause diagnosis | ~2h | Novel — one-time per cluster |
| bbi-infrastructure SSH fix | ~1h | Operator action outside this repo |
| Post-SSH: ExternalSecrets diagnosis | ~20min | ClusterSecretStore mismatch |
| Post-SSH: ImagePullBackOff diagnosis | ~20min | Missing credential secret |
| **Estimated re-run time** (all fixes in place) | **~15 min** | ArgoCD sync + pod startup |

**First deploy** from cold cluster: budget 4-6 hours (mostly blocked on external operator actions).
**Subsequent deploys** (all one-time fixes applied): budget 15-30 minutes.

---

## 8. Cluster Differences: rke2 vs GKE

| Aspect | GKE (Production) | rke2-nonprod |
|--------|------------------|--------------|
| Secrets store | `gcp-secret-manager` (Workload Identity) | `infisical-secret-store` |
| Image pull auth | Workload Identity (automatic) | `artifact-registry-key` secret (manual) |
| ArgoCD GitHub | HTTPS port 443 (works) | SSH port 22 only (HTTPS blocked by Cilium) |
| MongoDB | Atlas SRV (`mongodb+srv://`) | Same Atlas (shared) |
| DNS | `*.mereka.io` (Cloudflare → GKE LB) | `*.staging.mereka.dev` (rke2 Ingress) |
| Cert management | cert-manager + GKE Ingress | cert-manager + rke2 Ingress |
| Storage class | `standard-rwo` (GKE) | `local-path` or `longhorn` (rke2) |

---

## 9. Follow-up Beads for Unresolved Risk Items

The following items require explicit follow-up beads (not hand-waved):

| Risk | Description | Severity | Action |
|------|-------------|----------|--------|
| **imagePullSecret rotation** | Option B (OAuth token) expires in ~1hr. Option A (SA key) has no auto-rotation. | HIGH | Create bead: automate SA key rotation via ExternalSecret + Kubernetes `docker-registry` secret |
| **infisical path mapping** | ExternalSecrets using `infisical-secret-store` must have correct `remoteRef.key` values matching Infisical secret paths. If GKE uses different path prefixes, secrets will 404. | HIGH | Verify `infisical-secret-store` secret path mapping before marking 288f complete |
| **Staging DNS not configured** | `lms.staging.mereka.dev` DNS records not confirmed to exist. If absent, smoke tests will fail on DNS resolution. | MEDIUM | Verify Cloudflare has `*.staging.mereka.dev → rke2-nonprod Ingress IP` before 288f |
| **patchesJson6902 deprecation** | bbi-infrastructure kustomization uses deprecated field. No functional impact but adds warning noise. | LOW | `kustomize edit fix` in bbi-infrastructure overlay dir |

---

*Last updated: 2026-02-19 by BoldBadger (bead mereka-lms-3st7)*
