# Kubernetes Environment Overlays

This directory contains Kustomize overlays for different deployment environments.

## Usage

```bash
# Deploy to production
kubectl apply -k deploy/k8s/overlays/production

# Deploy locally (Kind/Minikube)
kubectl apply -k deploy/k8s/overlays/local

# Legacy staging overlay (do not use)
# kubectl apply -k deploy/k8s/overlays/staging
```

## Environments

| Environment | Description | Replicas |
|-------------|-------------|----------|
| `local` | Local development (Kind/Minikube) | 1 each |
| `staging` | Legacy overlay (deprecated) | N/A |
| `production` | Production GKE cluster | 2 LMS, 1 CMS |

## Customizing

Each overlay can be customized with:
- `images` - Container image tags
- `replicas` - Pod counts
- `patches` - Environment-specific patches
- `configMapGenerator` - Environment-specific config
