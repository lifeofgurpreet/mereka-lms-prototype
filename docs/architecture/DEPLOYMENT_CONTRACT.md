# Deployment Contract: mereka-lms

> Status: DRAFT — establishes the interface between app repo and GitOps repo.
>
> **Canonical reference**: This document and [DEPLOYMENT_BOUNDARY.md](DEPLOYMENT_BOUNDARY.md) are the authoritative sources for all questions about what belongs in this repo vs `bbi-infrastructure`. When in doubt, consult these two docs first.

## Current State (as of 2026-03-06)

### Repos

| Repo | Role | URL |
|------|------|-----|
| `mereka-lms` | App repo (producer) | github.com/Biji-Biji-Initiative/mereka-lms |
| `bbi-infrastructure` | GitOps repo (consumer) | github.com/Biji-Biji-Initiative/bbi-infrastructure |

### How GitOps Consumes Today

**bbi-infrastructure has a full vendored copy** of the app repo's deploy tree at:
```
apps/mereka-lms/base/deploy/k8s/
```

This is NOT a submodule or remote reference. It's a file copy that must be manually synced.

### ArgoCD Applications (Live)

| App | Repo | Path | Namespace |
|-----|------|------|-----------|
| `mereka-lms-dev` | bbi-infrastructure | `apps/mereka-lms/overlays/profiles/dev` | `mereka-lms-dev` |
| `mereka-lms-staging` | bbi-infrastructure | `apps/mereka-lms/overlays/staging` | `mereka-lms-staging` |
| `mereka-lms-prod` | bbi-infrastructure | `apps/mereka-lms/overlays/prod` | `mereka-lms` |

**All ArgoCD apps point to bbi-infrastructure, not mereka-lms.**

### Frozen Paths (Do Not Rename)

These paths are consumed by ArgoCD through bbi-infrastructure:

| Consumer Path (bbi-infra) | Status |
|---------------------------|--------|
| `apps/mereka-lms/overlays/profiles/dev/` | Active (dev) |
| `apps/mereka-lms/overlays/staging/` | Active (staging) |
| `apps/mereka-lms/overlays/prod/` | Active (prod, scaled to zero) |

### App Repo Exported Path

```
mereka-lms/deploy/k8s/base
```

This is the package the GitOps repo should consume. Currently it's vendored (copy-pasted), not referenced.

---

## Contract v1 (Target)

### Producer: mereka-lms

Exports: `deploy/k8s/base/`

Contains ONLY:
- Application workloads (Deployments, StatefulSets)
- Application Services
- Application ConfigMaps and settings
- Application PVCs
- Application-local NetworkPolicies
- Application-local HPA/PDB
- Application-scoped ExternalSecret definitions (environment-neutral)
- Release Jobs (migrations, bootstrap)
- App Namespace definition

Does NOT contain:
- Environment-specific overlays (production, staging, rke2-nonprod)
- Ingress definitions
- Cluster-scoped resources (ClusterSecretStore, ClusterPolicy, ClusterRole)
- Platform integrations (logging, ARC, monitoring operators)
- Environment domains (.mereka.io, .mereka.dev, biji-biji.com)
- Private key material
- Generated artifacts (.pyc, __pycache__)

### Consumer: bbi-infrastructure

Owns:
- Environment overlays (dev, staging, prod)
- Ingress per environment
- Image pinning per environment
- Replica counts per environment
- Secret store/provider selection
- Cluster policies and RBAC
- Monitoring/logging operator wiring
- ArgoCD Application definitions
- Promotion flow

Consumption method (current): vendored copy
Consumption method (target): git remote reference or submodule

---

## Migration Rules

1. ArgoCD application paths are frozen during migration
2. `deploy/k8s/base` remains the stable exported path from app repo
3. Internal restructuring happens behind that export path
4. Environment overlays move to GitOps repo via copy-then-deprecate-then-delete
5. Never change producer path, consumer path, and ArgoCD source in the same PR
6. Every migration PR identifies: what path is live, what changes, whether rollback is path-only or content-only

---

## Ownership Disputes (Resolved)

| Resource | Owner | Reason |
|----------|-------|--------|
| `base/arc/**` | GitOps | Cluster-scoped runner infrastructure |
| `base/logging/**` | GitOps | Platform-shared log shipping |
| `base/policies/**` | GitOps | Cluster-scoped admission policies |
| `base/secrets/cluster-secret-store.yaml` | GitOps | Cluster-scoped secret provider |
| `overlays/production/**` | GitOps | Environment-specific |
| `overlays/rke2-nonprod/**` | GitOps | Environment-specific |
| `overlays/staging/**` | GitOps | Environment-specific |
| `patches/argocd-*.yaml` | GitOps | ArgoCD behavior config |
| `base/monitoring/**` | Split | App owns metrics endpoints; GitOps owns ServiceMonitors/PrometheusRules |
| `base/apps/hubspot-webhook/**` | App (quarantine) | Placeholder image, not deployable |
| `base/apps/xqueue-graders/**` | App (quarantine) | :latest tag, not actively used |

---

## Compatibility Matrix

| Version | App Export | GitOps Overlay Owner | ArgoCD Source |
|---------|-----------|---------------------|---------------|
| v0 (current) | `deploy/k8s/base` (vendored copy in bbi-infra) | bbi-infrastructure | bbi-infrastructure |
| v1 (after cleanup) | `deploy/k8s/base` (cleaned, env-neutral) | bbi-infrastructure | bbi-infrastructure |
| v2 (future) | `deploy/k8s/base` (referenced, not copied) | bbi-infrastructure | bbi-infrastructure |
