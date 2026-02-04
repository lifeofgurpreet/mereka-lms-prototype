# Mereka LMS Deployment Guide

This document describes the Kubernetes deployment structure for Mereka LMS (OpenEdX via Tutor) in the BBI-K8 GitOps environment.

## Overview

The deployment has been structured to follow BBI-K8 GitOps patterns:

- **Source of Truth**: `deploy/k8s/base/` contains base Kustomize manifests exported from Tutor
- **Namespace**: All resources deploy to `mereka-lms` namespace (not `openedx`)
- **ConfigMaps**: Application configs managed via Kustomize configMapGenerator
- **Environment Overlays**: Local (kind/VPS) and production (GKE). The staging overlay is legacy reference-only (no staging environment).

## What Was Created

### 1. Directory Structure

```
/home/dev/bbi-meta/mereka-lms/
├── deploy/
│   └── k8s/
│       ├── README.md           # Detailed documentation
│       ├── base/               # Base Kustomize configuration
│       │   ├── kustomization.yaml
│       │   ├── namespace.yml   # mereka-lms namespace
│       │   ├── deployments.yml # 17 deployments
│       │   ├── services.yml    # All services
│       │   ├── volumes.yml     # PersistentVolumeClaims
│       │   ├── apps/           # 14 config files
│       │   └── plugins/        # 13 plugin config files
│       └── overlays/
│           ├── local/
│           ├── production/
│           └── staging/        # Legacy (reference only; no staging env)
└── scripts/
    └── export-k8s-manifests.sh # Re-export script
```

### 2. Base Manifests (`deploy/k8s/base/`)

**Core Files:**
- `namespace.yml` - Namespace definition (mereka-lms)
- `deployments.yml` - All deployment resources
- `services.yml` - All service resources
- `volumes.yml` - PersistentVolumeClaim definitions
- `kustomization.yaml` - Main Kustomize configuration

**Deployments (18 total):**
- caddy - Reverse proxy
- cms - OpenEdX Studio
- cms-worker - Studio celery workers
- lms - OpenEdX LMS
- lms-worker - LMS celery workers
- elasticsearch - Search functionality
- mysql - Relational database
- smtp - Email service
- redis - Cache/message broker
- discovery - Course discovery
- ecommerce - E-commerce service
- ecommerce-worker - E-commerce workers
- credentials - Credentials service
- forum - Discussion forums (uses MongoDB Atlas)
- mfe - Micro-frontends
- notes - Student notes
- xqueue - External grading queue

**Note**: MongoDB is provided by MongoDB Atlas (cluster-mereka-lms.2pjex4s.mongodb.net), not deployed in-cluster.

**ConfigMaps (13 generated):**
- caddy-config - Caddyfile
- openedx-settings-lms - LMS Django settings
- openedx-settings-cms - CMS Django settings
- openedx-config - LMS/CMS environment configs
- openedx-uwsgi-config - uWSGI configuration
- redis-config - Redis configuration
- discovery-settings - Discovery service settings
- credentials-settings - Credentials service settings
- ecommerce-settings - E-commerce settings
- ecommerce-worker-settings - E-commerce worker settings
- mfe-caddy-config - MFE reverse proxy config
- notes-settings - Notes service settings
- xqueue-settings - Xqueue service settings

### 3. Export Script

**Location:** `/home/dev/bbi-meta/mereka-lms/scripts/export-k8s-manifests.sh`

**Purpose:** Re-export manifests from Tutor when configuration changes

**Usage:**
```bash
cd /home/dev/bbi-meta/mereka-lms
./scripts/export-k8s-manifests.sh
```

**What it does:**
1. Copies manifests from `tutor_env/env/k8s/` to `deploy/k8s/base/`
2. Updates namespace from `openedx` to `mereka-lms`
3. Copies apps/ and plugins/ directories
4. Generates kustomization.yaml with all configMapGenerators

## Key Changes from Tutor Defaults

1. **Namespace**: Changed from `openedx` to `mereka-lms`
2. **Labels**: Updated `app.kubernetes.io/instance` and `app.kubernetes.io/part-of` to `mereka-lms`
3. **Jobs Excluded**: One-time initialization jobs are NOT included in base manifests
4. **Directory Structure**: Organized for GitOps with base/overlays pattern

## Testing the Deployment

### Verify Kustomize Build

```bash
cd /home/dev/bbi-meta/mereka-lms/deploy/k8s/base
kubectl kustomize .
```

Expected output:
- 1 Namespace
- 18 Deployments
- 13 ConfigMaps
- Services and PVCs

All resources should have `namespace: mereka-lms`

### Validation Checklist

- [x] Directory structure created
- [x] Base manifests copied and updated
- [x] Namespace changed to mereka-lms
- [x] ConfigMap generators configured
- [x] Apps/ directory with 14 files
- [x] Plugins/ directory with 13 files
- [x] Export script created and executable
- [x] Kustomize build validates successfully
- [x] README documentation created

## Next Steps

### 1. Create Environment Overlays

Create overlays for each active environment:

```bash
# Local development
mkdir -p deploy/k8s/overlays/local
# Create kustomization.yaml referencing base
# Add local-specific patches

# Production
mkdir -p deploy/k8s/overlays/production
# Create kustomization.yaml referencing base
# Add production-specific patches
```

### 2. Handle Database Initialization

Before first deployment, run Tutor initialization jobs:

```bash
# These are in tutor_env/env/k8s/jobs.yml
# Run separately, not part of base manifests
kubectl apply -f tutor_env/env/k8s/jobs.yml
```

### 3. Configure Persistent Storage

For production:
- Replace hostPath volumes with proper PersistentVolumes
- Configure StorageClasses
- Set up backup strategies

### 4. Integrate with BBI-K8

In the BBI-K8 repository:
1. Create `apps/mereka-lms/` directory
2. Create base/kustomization.yaml referencing this repo
3. Create overlays for local + production (staging deprecated; reference only)
4. Add to ArgoCD ApplicationSet

## Maintenance

### When Tutor Config Changes

```bash
# 1. Update Tutor configuration
cd /home/dev/bbi-meta/mereka-lms
tutor config save

# 2. Re-export manifests
./scripts/export-k8s-manifests.sh

# 3. Review changes
git diff deploy/k8s/base/

# 4. Commit if satisfied
git add deploy/k8s/base/
git commit -m "Update manifests from Tutor config"
```

### Monitoring

After deployment, monitor:
- All pods are running: `kubectl get pods -n mereka-lms`
- Services are accessible: `kubectl get svc -n mereka-lms`
- Persistent volumes bound: `kubectl get pvc -n mereka-lms`
- Logs for errors: `kubectl logs -n mereka-lms <pod-name>`

## Files Reference

All file paths are absolute from repository root:

- Base manifests: `/home/dev/bbi-meta/mereka-lms/deploy/k8s/base/`
- Export script: `/home/dev/bbi-meta/mereka-lms/scripts/export-k8s-manifests.sh`
- Source (Tutor): `/home/dev/bbi-meta/mereka-lms/tutor_env/env/`
- Documentation: `/home/dev/bbi-meta/mereka-lms/deploy/k8s/README.md`

## Support

For issues:
1. Check Tutor documentation: https://docs.tutor.edly.io/
2. Review BBI-K8 GitOps patterns: `/home/dev/bbi-meta/BBI-K8/CLAUDE.md`
3. Verify Kustomize build: `kubectl kustomize deploy/k8s/base/`
