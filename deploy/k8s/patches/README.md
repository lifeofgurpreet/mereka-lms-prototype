# Kubernetes Patches

> **Status per ADR-025**: The patches in this directory have the following classifications:
> - `argocd-configmap-ignore.yaml` — PLATFORM_SHARED: belongs with ArgoCD Application manifest
>   in `bbi-infrastructure`. Will move there in Phase 3 of the ADR-025 migration.
> - `caddy-staging-fix.yaml` — DEAD_REFERENCE: legacy emergency patch with hardcoded prod
>   domains, not referenced by any kustomization. Pending deletion.
> - `smtp-ses-relay.yaml` — DEAD_REFERENCE: manual-apply patch not integrated into any overlay.
>   Needs assessment before deletion.
>
> See [docs/architecture/DEPLOYMENT_BOUNDARY.md](../../../docs/architecture/DEPLOYMENT_BOUNDARY.md) for details.

This directory contains Kubernetes patches for fixing deployment issues that can't be resolved through Tutor configuration alone.

## Available Patches

### 1. `argocd-configmap-ignore.yaml` (mereka-lms-dcd)
**Problem**: ArgoCD triggers pod rolling updates every 3-5 minutes due to CSS ConfigMap hash changes.

**Root Cause**: ConfigMaps `openedx-overrides-runtime-css` and `openedx-theme-head-extra-patched` have hash suffixes that change between commits. ArgoCD's `selfHeal=true` detects drift and rolls pods.

**Solution**: Add `ignoreDifferences` configuration to tell ArgoCD to ignore these specific ConfigMap changes.

**Apply**:
```bash
# Option A: Patch existing ArgoCD Application
kubectl patch application mereka-lms -n argocd --type=merge --patch-file=deploy/k8s/patches/argocd-configmap-ignore.yaml

# Option B: Add to your ArgoCD Application manifest
# Copy the spec.ignoreDifferences section from argocd-configmap-ignore.yaml
# into your Application manifest under spec:
```

**Verify**:
```bash
# Check ArgoCD Application for ignoreDifferences
kubectl get application mereka-lms -n argocd -o yaml | grep -A 10 ignoreDifferences

# Monitor pod stability (should stop rolling)
kubectl get pods -n mereka-lms -w
```

### 2. `caddy-staging-fix.yaml` (legacy)
**Note**: This is a legacy emergency patch for restoring domain routing. Should be replaced by proper Tutor configuration.

**Apply**:
```bash
kubectl apply -f deploy/k8s/patches/caddy-staging-fix.yaml
kubectl rollout restart deploy/caddy -n mereka-lms
```

### 3. `smtp-ses-relay.yaml`
**Purpose**: Configures SMTP relay for AWS SES email delivery.

**Apply**:
```bash
kubectl apply -f deploy/k8s/patches/smtp-ses-relay.yaml
```

## General Patch Workflow

1. **Test locally first**: Always test patches in a local Kind cluster before production
2. **Document the fix**: Add a comment header explaining what the patch fixes
3. **Update patch-manifest.yml**: Document the patch in `infrastructure/tutor/patch-manifest.yml`
4. **Verify the fix**: Include verification commands in the patch header

## When to Use Patches vs Tutor Config

**Use Tutor config** (`infrastructure/tutor/apply-patches.sh`) for:
- Django settings changes
- Dockerfile modifications
- Service configuration
- Reverse proxy rules
- MFE build fixes

**Use K8s patches** (this directory) for:
- ArgoCD configuration
- Ingress annotations
- Service selectors
- ConfigMap/Secret overrides
- Resource limits
- PodDisruptionBudgets

## Related Documentation

- Tutor patches: `infrastructure/tutor/README.md`
- Patch manifest: `infrastructure/tutor/patch-manifest.yml`
- Troubleshooting: `docs/operations/TROUBLESHOOTING.md`
