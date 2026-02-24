# RKE2/GKE Image Build, Deploy, Push, and Rollback Package

> **Bead**: mereka-lms-8ex4
> **ACs**: AC-OPS-RK-A through AC-OPS-RK-D
> **Date**: 2026-02-19

---

## AC-OPS-RK-A: Release Script Command Transcript

### Script: `scripts/infra/release-openedx-gitops.sh`

**Dry-run with current production tags:**

```
App repo:   /home/gurpreet/projects/k8s/mereka-lms
Infra repo: /home/gurpreet/projects/k8s/bbi-infrastructure
Target env: production
OpenedX tag: mereka-brand
MFE tag:     20260208-mfe-discussions-pass4-c17df16
OpenedX digest: <unchanged>
MFE digest:     <unchanged>
Require digests: no
Update app base image overrides: yes
Update GitOps base ref: yes
Mode: dry-run

~ deploy/k8s/base/kustomization.yaml: 1 tag update(s)
    L22 docker.io/overhangio/openedx: 20260210-v21-mfe-only-b988d63 -> mereka-brand
= deploy/k8s/overlays/production/kustomization.yaml: already up-to-date

App SHA for GitOps base ref: 833690f0db96acaa6113f3913b3fa853b4666de5
~ bbi-infrastructure/apps/mereka-lms/base/kustomization.yaml: base ref fc344182... -> 833690f0...
~ bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml: 2 tag update(s)
    L18 docker.io/overhangio/openedx-mfe: b732a7d-20260210161437 -> 20260208-mfe-discussions-pass4-c17df16
    L21 asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe: b732a7d-20260210161437 -> 20260208-mfe-discussions-pass4-c17df16
Done.
```

### Full Release Command (when deploying new tags)

```bash
# Dry-run first (always):
bash scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <NEW_TAG> \
  --mfe-tag <NEW_MFE_TAG> \
  --target-env production

# Apply + commit + push (after verifying dry-run output):
bash scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <NEW_TAG> \
  --mfe-tag <NEW_MFE_TAG> \
  --target-env production \
  --apply \
  --commit \
  --push \
  --verify-runtime

# With digest pinning (recommended for production):
bash scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <NEW_TAG> \
  --openedx-digest sha256:<DIGEST> \
  --mfe-tag <NEW_MFE_TAG> \
  --mfe-digest sha256:<MFE_DIGEST> \
  --require-digests \
  --target-env production \
  --apply --commit --push --verify-runtime
```

---

## AC-OPS-RK-B: Cache Reuse vs Rebuild — Timing Baselines

### Current Image State (Production)

| Image | Tag | Registry | Size/Notes |
|-------|-----|----------|-----------|
| openedx (LMS/CMS/workers) | `mereka-brand` | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx` | ~3-4 GB, full platform |
| openedx-mfe | `20260208-mfe-discussions-pass4-c17df16` | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe` | ~1.5 GB, all MFEs |
| payments-gateway | `0.1.1` | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/payments-gateway` | ~200 MB |

### Build Time Baselines

| Build | Condition | Estimated Time |
|-------|-----------|---------------|
| `tutor images build openedx` (full rebuild) | No cache | 45–60 min (webpack 6–8 GB RAM) |
| `tutor images build openedx` (layer cache hit) | Pip deps unchanged | 20–30 min |
| `tutor images build mfe` (full rebuild) | No cache | 20–30 min |
| `tutor images build mfe` (node_modules cached) | package.json unchanged | 10–15 min |
| `payments-gateway` Docker build | Fresh | 3–5 min |

### Cache Assumptions

- **Docker layer cache**: Valid only on same build machine. CI builds use `--no-cache` for reproducibility.
- **Pip deps**: `requirements/edx/base.txt` changes → full pip reinstall layer invalidated.
- **Node modules**: `package.json` changes → full npm install layer invalidated.
- **Stale cache risk**: Running `docker system prune -a` before build eliminates all cache — avoid unless intentional.

---

## AC-OPS-RK-C: RKE2-Specific Execution Differences

### Current Cluster: GKE (not RKE2)

The production cluster runs on GKE (`gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`). RKE2 refers to the potential migration target. Key differences:

| Aspect | GKE (current) | RKE2 (target) |
|--------|---------------|---------------|
| Ingress controller | NGINX Ingress (GKE managed) | NGINX Ingress (self-managed) |
| Load balancer | GCP Cloud LB (automatic) | MetalLB or NodePort |
| Cert manager | cert-manager + letsencrypt-prod | cert-manager + letsencrypt-prod (same) |
| Image registry | GCP Artifact Registry | GCP Artifact Registry (same) |
| ArgoCD | External (bbi-infrastructure) | Same pattern |
| kubectl context | `gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster` | New context name |
| Node autoscaling | GKE node pools | RKE2 node groups |

### Gating Checkpoints for RKE2 Migration

1. **Registry access**: Confirm RKE2 nodes can pull from `asia-southeast1-docker.pkg.dev` (GCP Workload Identity or service account key)
2. **Ingress parity**: Verify NGINX Ingress class is `nginx` on RKE2 (matches `ingressClassName: nginx` in manifests)
3. **ExternalSecrets**: ClusterSecretStore `gcp-secret-manager` uses Workload Identity → verify WI binding on RKE2 nodes
4. **PVC parity**: Storage class names may differ — verify `standard` or `standard-rwo` availability
5. **ArgoCD base ref**: Update `bbi-infrastructure/apps/mereka-lms/base/kustomization.yaml` with new cluster context

### Pre-Migration Checklist

```bash
# 1. Verify kubectl context switch
kubectl config use-context <rke2-context>
kubectl get nodes

# 2. Verify registry pull works
kubectl run test-pull --image=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:mereka-brand \
  --restart=Never --command -- echo ok
kubectl logs test-pull
kubectl delete pod test-pull

# 3. Verify ExternalSecrets operator installed
kubectl get crd externalsecrets.external-secrets.io

# 4. Verify cert-manager installed
kubectl get crd certificates.cert-manager.io

# 5. Apply namespace + base resources
kubectl apply -k deploy/k8s/overlays/production
```

---

## AC-OPS-RK-D: Rollback Decision Matrix

| Scenario | Severity | Rollback Action | Command |
|----------|----------|----------------|---------|
| New pod crashloops immediately | P0 | Revert kustomization tag | `git revert HEAD && git push origin main` |
| Gradual memory leak / OOM | P1 | Scale down + revert | `kubectl scale deploy/lms --replicas=0 -n mereka-lms` then revert |
| ArgoCD stuck OutOfSync | P2 | Force sync or hard reset | `argocd app sync mereka-lms --force` |
| Wrong image deployed | P2 | Pin previous tag via GitOps | Edit `kustomization.yaml` newTag → previous, commit, push |
| Database migration failed | P0 | Stop rollout, restore DB backup | `kubectl rollout undo deployment/lms -n mereka-lms` + DB restore |

### Rollback Commands

```bash
# 1. Immediate pod rollback (no GitOps):
kubectl rollout undo deployment/lms -n mereka-lms
kubectl rollout undo deployment/cms -n mereka-lms

# 2. GitOps rollback (canonical):
cd /home/gurpreet/projects/k8s/mereka-lms
git log --oneline deploy/k8s/overlays/production/kustomization.yaml  # find previous commit
git show <PREV_SHA>:deploy/k8s/overlays/production/kustomization.yaml | grep newTag  # verify previous tag
git revert HEAD && git push origin main  # ArgoCD auto-syncs

# 3. Image pin revert (manual):
bash scripts/infra/release-openedx-gitops.sh \
  --openedx-tag <PREVIOUS_TAG> \
  --mfe-tag <PREVIOUS_MFE_TAG> \
  --target-env production \
  --apply --commit --push

# 4. Verify rollback complete:
kubectl rollout status deployment/lms -n mereka-lms
kubectl get pods -n mereka-lms | grep lms
```

### Rollback Signal Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| Pod restart count | >3 in 5 min | Immediate rollback |
| LMS HTTP 5xx rate | >5% over 2 min | Alert → rollback if sustained |
| DB migration errors | Any | Stop rollout immediately |
| Readiness probe failures | Pod not Ready after 5 min | Rollback |
