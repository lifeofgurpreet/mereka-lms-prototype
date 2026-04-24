# Mereka LMS Kubernetes Manifests

> **PARTIALLY SUPERSEDED**: The directory structure described below is outdated. The canonical
> reference for what belongs in this directory vs `bbi-infrastructure` is:
> - [docs/reference/architecture/DEPLOYMENT_CONTRACT.md](../../docs/reference/architecture/DEPLOYMENT_CONTRACT.md) — authoritative boundary ADR
> - [docs/reference/architecture/DEPLOYMENT_CONTRACT.md](../../docs/reference/architecture/DEPLOYMENT_CONTRACT.md) — interface contract
> - [docs/reference/architecture/RESOURCE_OWNERSHIP_MATRIX.md](../../docs/reference/architecture/RESOURCE_OWNERSHIP_MATRIX.md) — per-file classification
>
> Key differences from the description below: `overlays/local/`, `overlays/rke2-nonprod/`, and
> `overlays/staging/` exist (production was not "to be created" — it exists and is frozen at 0
> replicas). `base/arc/`, `base/logging/`, and `base/policies/` exist and are classified for
> migration to `bbi-infrastructure`. Ecommerce has been deprecated; Purchase Gateway replaces it.

This directory contains the Kubernetes manifests for deploying Mereka LMS (OpenEdX via Tutor) in the BBI-K8 GitOps environment.

## Directory Structure

```
deploy/k8s/
├── base/                       # Base Kustomize configuration
│   ├── kustomization.yaml      # Main kustomization file
│   ├── namespace.yml           # Namespace definition (mereka-lms)
│   ├── deployments.yml         # All deployment resources
│   ├── services.yml            # All service resources
│   ├── volumes.yml             # PersistentVolumeClaim definitions
│   ├── apps/                   # Application configuration files
│   │   ├── caddy/              # Caddy reverse proxy config
│   │   ├── openedx/            # OpenEdX settings (LMS/CMS)
│   │   ├── permissions/        # Permission scripts
│   │   └── redis/              # Redis configuration
│   └── plugins/                # OpenEdX plugin configurations
│       ├── discovery/          # Course discovery service
│       ├── credentials/        # Credentials service
│       ├── ecommerce/          # E-commerce service
│       ├── mfe/                # Micro-frontends
│       ├── notes/              # Notes service
│       └── xqueue/             # Xqueue service
└── overlays/                   # Environment-specific overlays (to be created)
    ├── local/                  # Local development
    └── production/             # Production environment
```

## Key Changes from Tutor Defaults

1. **Namespace**: Changed from `openedx` to `mereka-lms`
2. **Labels**: Updated instance and part-of labels to `mereka-lms`
3. **Initialization is in-graph**: Init/migration paths are encoded via `initContainers` and dedicated `Job`/`CronJob` manifests under `base/`
4. **ConfigMaps**: All config files are managed via configMapGenerator in kustomization.yaml

## Deployments Included

The base configuration includes the following deployments:

- **caddy**: Reverse proxy and ingress controller
- **cms**: OpenEdX Studio (Content Management System)
- **lms**: OpenEdX LMS (Learning Management System)
- **lms-worker**: Celery workers for LMS
- **cms-worker**: Celery workers for CMS
- **redis**: Redis cache and message broker
- **mysql**: MySQL database
- **elasticsearch**: Search functionality
- **smtp**: Email service
- **discovery**: Course discovery service
- **credentials**: Credentials service
- **ecommerce**: E-commerce service
- **ecommerce-worker**: E-commerce celery workers
- **mfe**: Micro-frontend applications
- **notes**: Student notes service
- **xqueue**: External grading queue
- **forum**: Discussion forums (uses MongoDB Atlas: cluster-mereka-lms.2pjex4s.mongodb.net)

**Note**: MongoDB is provided by MongoDB Atlas (cluster-mereka-lms.2pjex4s.mongodb.net), not deployed in-cluster.

## Updating from Tutor

When you make changes to the Tutor configuration and need to re-export manifests:

```bash
# 1. Update Tutor configuration
cd /home/dev/bbi-meta/mereka-lms
./scripts/infra/tutor-config-save.sh

# 2. Re-export manifests to GitOps structure
./scripts/export-k8s-manifests.sh
```

The export script will:
- Copy manifests from `tutor_env/env/` to `deploy/k8s/base/`
- Update namespace from `openedx` to `mereka-lms`
- Create the kustomization.yaml with all configMapGenerators
- Preserve your apps/ and plugins/ directories

## Testing the Manifests

To verify the kustomization builds correctly:

```bash
cd /home/dev/bbi-meta/mereka-lms/deploy/k8s/base
kubectl kustomize .
```

To apply to a cluster:

```bash
kubectl apply -k /home/dev/bbi-meta/mereka-lms/deploy/k8s/base
```

## Creating Overlays

For environment-specific configurations, create overlays:

```bash
mkdir -p deploy/k8s/overlays/local
cd deploy/k8s/overlays/local

# Create kustomization.yaml that references base
cat > kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base

# Add environment-specific patches here
patchesStrategicMerge:
- patches/ingress.yaml
- patches/resources.yaml
EOF
```

## Integration with BBI-K8

To integrate with the BBI-K8 GitOps repository:

1. This `deploy/k8s/` directory serves as the source for BBI-K8
2. BBI-K8 will reference these manifests and apply environment-specific overlays
3. ArgoCD will watch BBI-K8 and sync to clusters automatically

See the main BBI-K8 repository for details on the GitOps workflow.

## Notes

- The base configuration uses hostPath volumes for local development
- For production, you'll need to configure proper PersistentVolumes
- Schema/data initialization contracts are versioned in manifests (`initContainers`, `base/jobs/`, `base/plugins/aspects/jobs.yml`)
- Do not run ad-hoc manual migration commands as a deployment substitute; use declared GitOps/Tutor flows
