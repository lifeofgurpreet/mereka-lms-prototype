---
title: "Enterprise Images GHCR Migration"
type: "adr"
status: "accepted"
owner: "engineering"
last_updated: "2026-03-04"
links:
  related_adrs:
    - "docs/adr/003-image-build-pipeline.md"
    - "docs/adr/010-monorepo-architecture.md"
---

# ADR-023: Enterprise Images GHCR Migration

**Status**: Accepted
**Date**: 2026-03-04
**Deciders**: Gurpreet Singh (Founder / Platform Owner)

<!-- Last verified: 2026-03-04 -->

## Context

Six enterprise service images were previously referenced from GCP Artifact Registry (GAR):

| Image | Previous registry |
|---|---|
| `enterprise-catalog` | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-catalog` |
| `enterprise-access` | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-access` |
| `enterprise-subsidy` | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-subsidy` |
| `license-manager` | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/license-manager` |
| `enterprise-admin-portal` (MFE) | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-admin-portal` |
| `enterprise-learner-portal` (MFE) | `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/enterprise-learner-portal` |

Three problems drove this migration.

### Problem 1: GAR requires GCP Workload Identity

Pulling from GAR requires an `imagePullSecret` backed by a GCP service account, or Workload Identity Federation configured on the cluster's node pool. The `rke2-nonprod` cluster (the development and integration target) has neither. Every attempt to schedule an enterprise pod on `rke2-nonprod` resulted in `ImagePullBackOff` because no pull credential was available.

The production GKE cluster has Workload Identity configured, but requiring Workload Identity as a pull credential creates an asymmetry: images that run on GKE cannot be tested on `rke2-nonprod` without significant platform work.

### Problem 2: Upstream repositories are archived

The four backend enterprise services (enterprise-catalog, enterprise-access, enterprise-subsidy, license-manager) were archived by 2U/edX in November 2024. No further releases are expected. The images are frozen at tag `21.0.0`. Maintaining a GAR pipeline for images that will never change is unnecessary overhead.

### Problem 3: Org registry standard is GHCR

All other Mereka LMS images (LMS, CMS, MFEs, purchase-gateway, forum) are published to `ghcr.io/biji-biji-initiative/`. The `ghcr-registry` imagePullSecret is already provisioned in the `mereka-lms` namespace on both GKE and `rke2-nonprod`. Using GAR for enterprise images alone created a two-registry dependency with no benefit.

## Decision

### 1. Migrate all six images to GHCR

All six images are published under `ghcr.io/biji-biji-initiative/`:

| Image | GHCR reference |
|---|---|
| `enterprise-catalog` | `ghcr.io/biji-biji-initiative/enterprise-catalog` |
| `enterprise-access` | `ghcr.io/biji-biji-initiative/enterprise-access` |
| `enterprise-subsidy` | `ghcr.io/biji-biji-initiative/enterprise-subsidy` |
| `license-manager` | `ghcr.io/biji-biji-initiative/license-manager` |
| `enterprise-admin-portal` | `ghcr.io/biji-biji-initiative/enterprise-admin-portal` |
| `enterprise-learner-portal` | `ghcr.io/biji-biji-initiative/enterprise-learner-portal` |

### 2. Backend services are frozen at 21.0.0

`enterprise-catalog`, `enterprise-access`, `enterprise-subsidy`, and `license-manager` are pinned to tag `21.0.0`. The upstream repositories are archived; this tag will not change. A one-time `crane copy` from GAR to GHCR transfers the image layers. No rebuild is required and none is planned.

The `21.0.0` tag in GHCR is immutable. If a security patch is required against an archived upstream, the process is: fork the repository, apply the patch, build a custom image tagged `21.0.0-mereka.N`, and update the K8s base manifests.

### 3. MFE images have a CI rebuild workflow

`enterprise-admin-portal` and `enterprise-learner-portal` are not archived. They receive occasional upstream updates and require Mereka-specific branding. A new workflow, `.github/workflows/build-enterprise-mfe.yml`, handles rebuilds:

- Triggered manually (`workflow_dispatch`) or on push to `infrastructure/docker/enterprise-mfe-clean/`.
- Calls the existing `reusable-build-push.yml` reusable workflow.
- Builds from `infrastructure/docker/enterprise-mfe-clean/Dockerfile.<service>`.
- Pushes to `ghcr.io/biji-biji-initiative/<service>:<tag>`.
- A helper script `scripts/infra/build-enterprise-mfe-clean.sh` wraps the build for local development.

### 4. One-time crane copy

The initial population of GHCR uses `crane copy`:

```bash
# Backend (frozen)
for svc in enterprise-catalog enterprise-access enterprise-subsidy license-manager; do
  crane copy \
    asia-southeast1-docker.pkg.dev/mereka-lms/openedx/${svc}:21.0.0 \
    ghcr.io/biji-biji-initiative/${svc}:21.0.0
done

# MFEs (rebuilt from Dockerfile, not copied)
```

`crane` authenticates to GAR via `gcloud auth configure-docker` and to GHCR via `GITHUB_TOKEN`. This is a one-time operator action, not automated in CI.

### 5. K8s manifest updates

Base manifests under `deploy/k8s/base/apps/enterprise/` (8 Deployment files) are updated to reference GHCR:

- `image:` fields changed from `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/<service>:21.0.0` to `ghcr.io/biji-biji-initiative/<service>:21.0.0`.
- `imagePullSecrets:` already references `ghcr-registry`; no change needed.

The `rke2-nonprod` overlay kustomization (`deploy/k8s/overlays/rke2-nonprod/kustomization.yaml`) is simplified: `images` entries that previously overrode `newName` to redirect from GAR to a local registry are removed where the base manifest now already references GHCR.

### Files changed

| File | Change |
|---|---|
| `deploy/k8s/base/apps/enterprise/*.yaml` (8 files) | `image:` refs changed from GAR to GHCR |
| `deploy/k8s/overlays/rke2-nonprod/kustomization.yaml` | Removed redundant `newName` image pins that duplicated the base ref |
| `.github/workflows/build-enterprise-mfe.yml` | New workflow for MFE image rebuilds |
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.enterprise-admin-portal` | New Dockerfile for admin portal MFE |
| `infrastructure/docker/enterprise-mfe-clean/Dockerfile.enterprise-learner-portal` | New Dockerfile for learner portal MFE |
| `scripts/infra/build-enterprise-mfe-clean.sh` | Local build helper script |

## Consequences

### Positive

- Enterprise pods can be scheduled on `rke2-nonprod` without GCP credential setup.
- Single registry (`ghcr.io/biji-biji-initiative/`) for all Mereka LMS images reduces operator cognitive overhead.
- `ghcr-registry` secret is already present in the namespace; no new secrets provisioning required.
- Frozen backend images will never need to be re-pulled from an archived GAR path that may be garbage-collected.
- MFE build workflow is consistent with how other MFEs are built (same reusable workflow).

### Negative

- `crane copy` is a one-time manual step that must be performed by an operator with access to both GAR and GHCR. It cannot be automated in CI because it requires transient GCP credentials that are not available in the standard CI runner context.
- The `21.0.0` freeze means upstream security patches for backend services require a fork + custom image. This is an accepted trade-off given that the upstream repositories are archived and no official patches will be released.
- GHCR storage is billed against the `biji-biji-initiative` GitHub organization's storage quota. Six images at approximately 800 MB each (compressed) add roughly 5 GB to the organization's storage.

### Risks

- **GHCR package visibility**: GHCR packages default to private. If the `ghcr-registry` secret is ever rotated or deleted from the namespace, enterprise pods will fail to pull. Mitigation: `ghcr-registry` is managed as an ExternalSecret synced from Infisical; rotation is handled automatically.
- **Forking frozen upstreams**: If a CVE is discovered in a frozen enterprise service, a fork-and-rebuild process is required. This process is not yet documented. Mitigation: add a runbook to `docs/operations/` if a CVE event occurs; the Trivy scan in CI will surface CVEs in the base images.
- **MFE upstream divergence**: `enterprise-admin-portal` and `enterprise-learner-portal` are not frozen. If upstream makes a breaking change to the MFE, the Dockerfile in `infrastructure/docker/enterprise-mfe-clean/` will need to be updated. Mitigation: the rebuild workflow is manually triggered, giving the team control over when to adopt upstream changes.

## Alternatives Considered

1. **Configure Workload Identity on rke2-nonprod** — Would allow GAR pulls from the dev cluster. Rejected: `rke2-nonprod` is an RKE2 cluster, not GKE. Workload Identity is a GKE-specific mechanism. Equivalent credential federation on RKE2 requires significant platform work (SPIFFE/SPIRE or a custom admission webhook) with no benefit beyond solving this single problem.

2. **Use a pull-through cache / local registry mirror on rke2-nonprod** — A registry mirror (e.g., Harbor or Zot) could proxy GAR. Rejected: introduces a new infrastructure component to maintain for a problem that is fully solved by using GHCR, which is already in use.

3. **Use `imagePullPolicy: IfNotPresent` + pre-pull DaemonSet** — Pre-pull images onto `rke2-nonprod` nodes so GAR credentials are only needed during node setup. Rejected: fragile; node reprovisioning requires re-running the pre-pull, and it does not address the core registry asymmetry.

4. **Keep GAR for production, use GHCR only for rke2-nonprod** — Maintain a two-registry setup with the nonprod overlay redirecting to GHCR. Rejected: this is the current state (minus the GHCR side). It perpetuates dual-registry complexity and does not eliminate the operator burden of keeping two registries in sync.

## References

- [ADR-003: Image Build Pipeline](003-image-build-pipeline.md)
- [ADR-010: Monorepo Architecture](010-monorepo-architecture.md)
- [GHCR documentation](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [crane copy documentation](https://github.com/google/go-containerregistry/blob/main/cmd/crane/doc/crane_copy.md)
- [docs/ops/ci-cd/CI_CD_RUNNERS.md](../ops/ci-cd/CI_CD_RUNNERS.md)
- [.github/workflows/build-enterprise-mfe.yml](../../.github/workflows/build-enterprise-mfe.yml)
