# Kubernetes Environment Overlays

This directory contains Kustomize overlays for different deployment environments.

## Ownership Boundary

**ArgoCD deploys from `bbi-infrastructure`, NOT from this repo.**

| Overlay | Owner | ArgoCD Source | Status |
|---------|-------|---------------|--------|
| `local/` | **mereka-lms** (this repo) | N/A (local dev) | Active |
| `rke2-nonprod/` | **bbi-infrastructure** | `apps/mereka-lms/overlays/dev/` | DEPRECATED here |
| `staging/` | **bbi-infrastructure** | `apps/mereka-lms/overlays/staging/` | DEPRECATED here |
| `production/` | **bbi-infrastructure** | `apps/mereka-lms/overlays/prod/` | DEPRECATED here |

The non-local overlays in this repo are **legacy artifacts** retained for reference.
They are NOT consumed by ArgoCD and have drifted from the authoritative overlays
in bbi-infrastructure. Do NOT add new files to deprecated overlays.

**Authoritative deployment overlays**: `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/`

Scheduled for removal in Wave 9 (legacy deletion).

## App-Owned Overlay: local

The `local/` overlay is the only overlay permanently owned by this repo.
Use it for local development with Kind or Minikube.

```bash
kubectl apply -k deploy/k8s/overlays/local
```

## Base (Vendored by bbi-infrastructure)

The `deploy/k8s/base/` directory is vendored into bbi-infrastructure at
`apps/mereka-lms/vendor/mereka-lms/deploy/k8s/base/`. Environment overlays
in bbi-infrastructure reference this vendored base and apply per-env patches
(image tags, secret stores, domains, replicas, etc.).
