---
id: ADR-027
title: Deployment Contract — Ownership Lanes Between App and GitOps Repos
decision_status: proposed
decision_type: foundation
rollout_state: planned
owner: engineering
created: '2026-03-06'
last_reviewed: '2026-03-07'
review_due: '2026-06-30'
supersedes: []
amends: []
depends_on:
- ADR-028
read_next:
- ADR-028
governs:
- platform.repo-boundary
- platform.control-plane
does_not_govern: []
related_oep: []
related_tutor_docs:
- https://docs.openedx.org
- https://docs.tutor.edly.io
related_specs: []
related_runbooks: []
related_evidence: []
fitness_functions: []
expiry_date: null
removal_condition: null
---

# ADR-027: Deployment Contract — Ownership Lanes Between App and GitOps Repos

**Status**: Proposed
**Date**: 2026-03-06
**Deciders**: Gurpreet Singh (Founder / Platform Owner)

## Context

The Mereka LMS deployment spans two Git repositories:

1. **mereka-lms** (this repo) — application code, Tutor configuration, Docker images, base
   Kustomize manifests, and CI/CD pipelines.
2. **BBI-K8 / bbi-infrastructure** (GitOps repo) — ArgoCD ApplicationSets, environment overlays,
   ingress, TLS certificates, image pins with digests, and cluster-scoped operator configuration.

Over time, the boundary between these repos has blurred:

- **mereka-lms contains environment overlays it should not own.** The `deploy/k8s/overlays/`
  directory has `rke2-nonprod/`, `staging/`, and `production/` overlays that contain
  cluster-specific concerns: Infisical secret store patches, storage class overrides, SHA-pinned
  image digests, domain-specific ingress rules, and environment-specific configmap overrides.
  These change on the cluster/environment cadence, not the application cadence.

- **Cross-repo references are hardcoded.** Scripts like `park-prod.sh` and `unpark-prod.sh`
  hardcode `BBI_INFRA=/home/gurpreet/projects/k8s/bbi-infrastructure`. The CI pipeline spec
  references `Biji-Biji-Initiative/bbi-infrastructure` for GitOps image tag updates.

- **No machine-readable contract exists.** The GitOps repo must reverse-engineer the LMS repo's
  base kustomization to know what secrets are required, what services exist, what ports are
  exposed, and what health endpoints to probe. This knowledge is tribal, not encoded.

- **ARC manifests are application-adjacent but cluster-scoped.** The `deploy/k8s/base/arc/`
  directory contains GitHub Actions Runner Controller configuration that uses its own namespaces
  (`arc-systems`, `arc-runners`) and cannot be included in any overlay that sets
  `namespace: mereka-lms`. This is already documented as a pitfall (CLAUDE.md item 11).

The result is that changes to the deployment topology require coordinated commits across both
repos, with no formal interface to validate compatibility.

## Decision

### 1. Ownership Lanes

**mereka-lms repo owns:**

| Asset | Path | Rationale |
|-------|------|-----------|
| Application source code | `services/`, `infrastructure/tutor/` | App-cadence changes |
| Base Kustomize manifests | `deploy/k8s/base/` | Declares the app's K8s shape |
| Local dev overlay | `deploy/k8s/overlays/local/` | Developer reference implementation |
| Deployment contract | `deploy/k8s/contract.json` | Machine-readable interface |
| Contract documentation | `deploy/k8s/CONTRACTS.md` | Human-readable interface |
| Package version | `deploy/k8s/VERSION` | Semver for the deployment package |
| Network policies | `deploy/k8s/base/network-policies/` | App security posture |
| Monitoring definitions | `deploy/k8s/base/monitoring/` | App-aware alerting rules |
| CI/CD pipelines | `.github/workflows/` | Build, test, push images |

**GitOps repo (BBI-K8) owns:**

| Asset | Current LMS Path (to migrate) | Rationale |
|-------|-------------------------------|-----------|
| Dev overlay | `deploy/k8s/overlays/rke2-nonprod/` | Cluster-specific config |
| Staging overlay | `deploy/k8s/overlays/staging/` | Cluster-specific config |
| Production overlay | `deploy/k8s/overlays/production/` | Cluster-specific config |
| ARC manifests | `deploy/k8s/base/arc/` | Cluster-scoped CI runners |
| Ingress resources | Within each overlay | Domain/TLS per environment |
| Image pins (tag + digest) | Within each overlay | Promotion cadence |
| Secret store patches | Within each overlay | Cluster secret backend |
| ArgoCD ApplicationSets | (already in BBI-K8) | Deployment orchestration |
| ClusterSecretStore selection | Overlay patches | Cluster operator choice |

### 2. Deployment Contract (`contract.json`)

The LMS repo publishes a `deploy/k8s/contract.json` file that is the **formal interface** between
the two repos. The GitOps repo MAY validate its overlays against this contract in CI.

The contract declares:
- **Workloads**: Every Deployment/StatefulSet name with its container ports
- **Required secrets**: Every ExternalSecret name and its expected keys
- **Required configmaps**: Every configMapGenerator-produced ConfigMap
- **Health endpoints**: Per-service liveness/readiness paths and ports
- **Namespace**: The expected namespace for all resources
- **Kustomize compatibility**: Minimum kustomize version for the base
- **Base path**: Relative path to the base kustomization

The contract version follows semver:
- **PATCH**: New secret key added to existing ExternalSecret, new PrometheusRule
- **MINOR**: New Deployment/Service added, new ExternalSecret added, new ConfigMap
- **MAJOR**: Deployment renamed/removed, secret structure changed, namespace changed

### 3. Migration Strategy

Overlays are **moved, not copied**. Old locations receive a README tombstone:

```
deploy/k8s/overlays/rke2-nonprod/kustomization.yaml
deploy/k8s/overlays/staging/kustomization.yaml
deploy/k8s/overlays/production/kustomization.yaml
deploy/k8s/base/arc/kustomization.yaml
```

Each tombstone contains:
- Where the content moved to (repo + path)
- The GitHub issue or PR that performed the migration
- The contract.json version at time of migration

The migration is executed in phases:
1. **Phase 0** (this ADR): Establish the decision and contract schema
2. **Phase 1**: Create `contract.json`, `CONTRACTS.md`, `VERSION` in mereka-lms
3. **Phase 2**: Copy overlays to BBI-K8, validate they build against the base via remote ref
4. **Phase 3**: Delete overlays from mereka-lms, replace with tombstones
5. **Phase 4**: Add contract validation to both repos' CI pipelines

### 4. Logging and Policies

- `deploy/k8s/base/logging/` (Promtail DaemonSet + RBAC) stays in the LMS repo. The DaemonSet
  is namespace-scoped and application-aware (it collects logs from `mereka-lms` pods). However,
  if the GitOps repo deploys a cluster-wide logging stack, the LMS repo's logging resources
  should be disabled via overlay patch.
- `deploy/k8s/base/policies/` (Kyverno ClusterPolicies) stays in the LMS repo as the app's
  declared security posture. The GitOps repo may enforce additional cluster-wide policies.
- `deploy/k8s/base/network-policies/` stays — these are namespace-scoped and app-specific.

### 5. Cross-Repo Script References

Scripts that reference `bbi-infrastructure` by path MUST use an environment variable with a
documented default:

```bash
BBI_INFRA="${BBI_INFRA:-/home/gurpreet/projects/k8s/infrastructure}"
```

The contract.json does NOT encode paths in the other repo. Each repo is responsible for knowing
how to consume the other's published artifacts.

## Scope

This proposal governs the decision boundary described by ADR-027.

## Non-goals

This document does not replace broader platform standards, runbooks, or implementation evidence.

## Verification

- No dedicated automated fitness function is registered yet; use linked specs and runbooks for review.

## Consequences

### Positive

- **Clear ownership**: Every file has exactly one owner. No more "which repo do I change?"
- **Machine-readable interface**: `contract.json` enables automated compatibility checks
- **Independent cadence**: App changes (base manifests) and environment changes (overlays) can
  be committed, reviewed, and deployed independently
- **Reduced drift**: Environment overlays no longer accumulate in a repo where they are not
  validated against a live cluster
- **Tombstones prevent confusion**: Developers finding old overlay paths get a clear redirect
- **CI validation**: Both repos can validate their side of the contract independently

### Negative

- **Two-repo coordination for structural changes**: Adding a new service requires updating
  `contract.json` in the LMS repo AND adding overlay entries in the GitOps repo. This is
  mitigated by the contract making the required changes explicit.
- **Migration effort**: Moving 50+ files across repos requires careful sequencing to avoid
  breaking ArgoCD sync during the transition
- **Contract maintenance**: `contract.json` must be kept in sync with the base kustomization.
  A CI check will enforce this, but it adds a maintenance step.

## Alternatives Considered

### Keep All Overlays in LMS Repo

Leave everything as-is.

**Rejected because**: The overlays already contain cluster-specific concerns (Infisical vs GCP
secret stores, storage classes, image pull secret names) that change when the cluster changes,
not when the app changes. The rke2-nonprod overlay header already documents this split
informally. Formalizing it reduces cognitive overhead.

### Move Base Manifests to GitOps Repo

Move everything — base + overlays — to the GitOps repo. LMS repo only has app code.

**Rejected because**: The base kustomization is tightly coupled to application code. Its
configMapGenerators reference Python settings files, uwsgi configs, Caddyfiles, and theme files.
These files change with application releases. Splitting them from the app repo would require
publishing them as an artifact, adding complexity without proportional benefit at our scale.

### Helm Chart as Contract

Package the base as a Helm chart with `values.yaml` as the contract.

**Rejected because**: The existing manifests are Kustomize-native. Tutor generates Kustomize
resources. Converting to Helm would require rewriting all manifests and maintaining Helm
templates alongside Tutor's generation pipeline. The contract.json approach achieves the same
goal (machine-readable interface) without changing the deployment toolchain.

### Git Submodule

GitOps repo includes LMS repo as a submodule.

**Rejected because**: Submodules add operational complexity, ArgoCD handles submodules poorly,
and the pinning semantics conflict with our image promotion workflow.
