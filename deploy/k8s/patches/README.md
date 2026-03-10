# Kubernetes Patches

> **Status per ADR-025**: The patches in this directory have the following classifications:
> - `argocd-configmap-ignore.yaml` — PLATFORM_SHARED: belongs with ArgoCD Application manifest
>   in `bbi-infrastructure`. Will move there in Phase 3 of the ADR-025 migration.
>
> **Deleted in Phase 2 quarantine (2026-03-07)**:
> - `caddy-staging-fix.yaml` — legacy emergency patch with hardcoded prod domains, never referenced by any kustomization.
> - `smtp-ses-relay.yaml` — manual-apply patch never integrated into any overlay.
>
> See [docs/concepts/architecture/DEPLOYMENT_BOUNDARY.md](../../../docs/concepts/architecture/DEPLOYMENT_BOUNDARY.md) for details.

This directory contains Kubernetes patches for fixing deployment issues that can't be resolved through Tutor configuration alone.

## Available Patches

### `argocd-configmap-ignore.yaml` (mereka-lms-dcd)
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

## General Patch Workflow

1. **Test locally first**: Always test patches in a local Kind cluster before production
2. **Document the fix**: Add a comment header explaining what the patch fixes
3. **Verify the fix**: Include verification commands in the patch header

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
- Troubleshooting: `docs/runbooks/operations/TROUBLESHOOTING.md`
