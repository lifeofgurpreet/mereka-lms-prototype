# Kubernetes Environment Overlays

This directory contains Kustomize overlays for different deployment environments.

> **Boundary note (ADR-025)**: Only `overlays/local/` permanently belongs in this app repo.
> `overlays/production/`, `overlays/rke2-nonprod/`, and `overlays/staging/` are classified
> ENVIRONMENT_SPECIFIC and will migrate to `bbi-infrastructure` in a future phase. All three
> currently remain here for operational continuity during the transition period.
> See [docs/architecture/DEPLOYMENT_BOUNDARY.md](../../docs/architecture/DEPLOYMENT_BOUNDARY.md).

See **`docs/operations/DEPLOYMENT_LANES.md`** for the canonical reference on active lanes,
promotion path, and differences between environments.

## Active Lanes

| Overlay | Cluster | Domain | Secrets | Status |
|---------|---------|--------|---------|--------|
| `local` | Kind / Minikube | `localhost` | dev literals | Active |
| `rke2-nonprod` | RKE2 VPS (`154.26.132.35`) | `*.academyv2.mereka.dev` | Infisical | Active — canonical non-prod |
| `production` | GKE (`bbi-k8`) | `*.academyv2.mereka.io` | GCP Secret Manager | Active |
| ~~`staging`~~ | *(never activated)* | — | — | **DEPRECATED** |

## Promotion Path

```
local → rke2-nonprod → production
```

## Usage

```bash
# Deploy to production (via ArgoCD GitOps — do not apply directly)
kubectl apply -k deploy/k8s/overlays/production

# Deploy to rke2-nonprod (via ArgoCD GitOps — do not apply directly)
kubectl apply -k deploy/k8s/overlays/rke2-nonprod

# Deploy locally (Kind/Minikube)
kubectl apply -k deploy/k8s/overlays/local
```

## Customizing

Each overlay can be customized with:
- `images` — Container image tags
- `replicas` — Pod counts
- `patches` — Environment-specific patches
- `configMapGenerator` — Environment-specific config
