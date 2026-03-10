# ArgoCD Drift Detection Runbook

## Overview

ArgoCD can report "Synced" while the in-cluster Application spec has been manually modified. This is the "Synced but wrong" scenario: the rendered resources match git, but the Application itself (source path, repo URL, sync policy) was patched directly.

**Real incident**: An agent manually patched the ApplicationSet in-cluster. ArgoCD showed Synced because the destination resources hadn't changed, but the source path was wrong and the next git change would have deployed from the wrong overlay.

## Quick Diagnostic

```bash
# Offline only (no cluster access)
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-prod --offline

# Live cluster
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-prod --online

# Both
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-prod --online --offline
```

## What the Script Checks

### Offline (git manifests)

| Check | What it verifies |
|-------|-----------------|
| Overlay path exists | `infrastructure/apps/mereka-lms/overlays/{overlay}` is a real directory |
| kustomization.yaml present | The overlay has a valid kustomization entry point |
| Application manifest matches | Git-defined source.path and repoURL are correct |
| ApplicationSet integrity (dev) | mereka-lms entry exists with correct overlay reference |
| Warm-park status (prod) | Whether warm-park-mode.yaml is active |

### Online (live cluster)

| Check | What it verifies |
|-------|-----------------|
| Sync status | Application reports `Synced` |
| Health status | Application reports `Healthy` |
| Source path drift | In-cluster `spec.source.path` matches git-defined value |
| Repo URL drift | In-cluster `spec.source.repoURL` matches git-defined value |
| Manual refresh annotations | Detects `argocd.argoproj.io/refresh` annotations from manual overrides |
| Last sync initiator | Whether last sync was automated or manual |
| Resource health | Finds Degraded, Missing, or Unknown child resources |
| Sync policy | Confirms automated prune and selfHeal are enabled |
| ApplicationSet drift (dev) | Compares in-cluster ApplicationSet template against expected pattern |

## Known App Configurations

| App Name | Source Path | Repo |
|----------|------------|------|
| `mereka-lms-dev` | `apps/mereka-lms/overlays/profiles/dev` | `infrastructure.git` |
| `mereka-lms-prod` | `apps/mereka-lms/overlays/prod` | `infrastructure.git` |

## Resolution Steps

### Drift in Application spec (source path, repoURL, namespace)

1. **Do NOT** `kubectl patch` the Application. ArgoCD manages it from git.
2. Verify the correct values in the GitOps [`applicationsets`](https://github.com/Biji-Biji-Initiative/BBI-K8/tree/main/infrastructure/applicationsets):
   - `mereka-lms-prod.yaml` (standalone Application)
   - `kustomize-apps.yaml` (ApplicationSet for dev)
3. If the git values are correct and the cluster is wrong, delete the Application and let ArgoCD recreate it:
   ```bash
   # ArgoCD will recreate from the ApplicationSet or from the manifest in git
   kubectl delete application mereka-lms-dev -n argocd
   ```
4. Wait 3 minutes for ArgoCD to reconcile.

### Automated sync disabled

Someone may have disabled `automated.prune` or `automated.selfHeal` while debugging.

1. Check if there's an active incident requiring manual sync control.
2. If not, restore the sync policy by reapplying the Application from git:
   ```bash
    kubectl apply -f https://raw.githubusercontent.com/Biji-Biji-Initiative/BBI-K8/main/infrastructure/applicationsets/mereka-lms-prod.yaml
   ```

### Degraded child resources

1. Check pod logs: `kubectl logs -n mereka-lms -l app.kubernetes.io/name=<resource>`
2. Check events: `kubectl get events -n mereka-lms --sort-by=.lastTimestamp | tail -20`
3. Common causes: image pull errors, CrashLoopBackOff, missing secrets.

## Automation

The drift check runs every 6 hours via `.github/workflows/argocd-drift-check.yml`. On failure, it creates a GitHub issue labeled `argocd-drift`. Subsequent failures comment on the existing issue to avoid duplicates.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `BBI_INFRA` | `<path-to-bbi-infrastructure>` | Path to infrastructure repo clone |
