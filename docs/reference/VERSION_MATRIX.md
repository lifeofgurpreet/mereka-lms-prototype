# Version Matrix

Canonical version baseline for Mereka Academy LMS. CI validates that
configuration files match these values.

**Platform version**: See `deploy/k8s/VERSION`

## Core Stack

| Component | Version | Source | Notes |
|-----------|---------|--------|-------|
| Open edX | Ulmo | Named release | Current supported release line |
| Tutor | 21.0.3 | `requirements-tutor.txt` | Deployment tool for Open edX |
| Python | 3.12 | CI workflows, local dev | Minimum: 3.10 |
| Node.js | 24.11.0 | `infrastructure/tutor/mfe-build/Dockerfile` | MFE build toolchain |
| MySQL | 8.4 | Tutor default | Course data, user data |
| MongoDB | 7.0 (Atlas) | `cluster-mereka-lms.2pjex4s.mongodb.net` | Forum, modulestore |
| Redis | 7.x | Tutor default | Caching, Celery broker |
| Meilisearch | 1.x | Forum search | Replaces Elasticsearch |

## Build Toolchain

| Component | Version | Source | Notes |
|-----------|---------|--------|-------|
| Webpack | 5 | MFE build | Memory limit: 6144 MB |
| Docker | 24+ | Build runners | Image builds |
| Cosign | latest | `scripts/infra/install-cosign.sh` | Image signing |
| Kustomize | 5.x | kubectl built-in | Manifest rendering |

## Infrastructure

| Component | Version | Source | Notes |
|-----------|---------|--------|-------|
| Kubernetes | 1.30 (RKE2) | Contabo VPS cluster | `rke2-nonprod` |
| ArgoCD | 2.x | bbi-infrastructure | GitOps reconciler |
| Cilium | 1.16 | CNI on RKE2 | Network policy |
| Ingress-nginx | 1.x | hostNetwork on worker nodes | External traffic |
| Caddy | 2.x | In-pod reverse proxy | Route LMS/MFE/API traffic |
| cert-manager | 1.x | Let's Encrypt | TLS certificates |

## Tutor Plugin

| Component | Version | Source | Notes |
|-----------|---------|--------|-------|
| Mereka LMS Plugin | 1.0.0 | `infrastructure/tutor/plugins/mereka_lms.py` | Custom Tutor plugin |
| MFE Plugin | 21.0.0 | `requirements-tutor.txt` | Official MFE build plugin |

## MFE Versions

See `docs/reference/architecture/MFE_VERSIONS.md` for detailed MFE
component versions and build configuration.

## Update Process

1. Update this file with the new version
2. Update the corresponding source file (requirements, Dockerfile, etc.)
3. Run `make lint` to verify consistency
4. Test locally with `make tutor-start`
5. Submit PR — CI validates version parity
