# ADR-025: Deployment Boundary — App Repo vs Infrastructure/GitOps Repo

**Status:** Proposed
**Date:** 2026-03-06
**Deciders:** Platform Engineering
**Related:** `docs/concepts/architecture/RESOURCE_OWNERSHIP_MATRIX.md`, `scripts/qa/inventory_k8s_resources.sh`

---

## Context

The `deploy/k8s/` tree in this repository (mereka-lms) contains a mix of concerns:

1. App workloads and configuration that change with every code release (LMS, CMS, enterprise services, purchase gateway, settings, secrets).
2. Platform-level resources that belong to cluster administration and outlive any single application release (ARC, Promtail, Kyverno policies, ClusterSecretStore, ArgoCD config).
3. Environment-specific overlays that encode domain names, image digests, and provider-specific secrets — currently duplicated between this repo and `infrastructure` (historical alias: `infrastructure`).
4. Dead or placeholder manifests that are not rendered by any active kustomization and create confusion about intended scope.

Without a defined boundary, every agent and engineer must guess which files they are allowed to modify and which are owned by the platform team or the infrastructure GitOps repo. This ADR defines that boundary.

---

## Decision

### The Boundary Rule

> **This repo owns app runtime behaviour. The infrastructure repo owns cluster configuration.**

| Question | App Repo (here) | Infrastructure/GitOps Repo |
|---|---|---|
| What image runs? | Yes — Dockerfiles, image tags | Yes — pins for prod overlays (`infrastructure`) |
| How does the app behave? | Yes — Django settings, Caddy config, secrets mapping | No |
| Which cluster is it on? | No | Yes — ArgoCD Applications, overlays |
| How does the cluster log? | No | Yes — Promtail DaemonSet |
| Are containers hardened? | Partially — app-level securityContext patches | Yes — Kyverno ClusterPolicies |
| Who provides secrets? | Yes — ExternalSecret definitions | Yes — ClusterSecretStore, Infisical/GCP SM setup |

### Classification Model

Every file in `deploy/k8s/` is assigned one of six classifications:

| Classification | Meaning | Home |
|---|---|---|
| **APP_RUNTIME** | App workloads, Services, PVCs, app-local NetworkPolicy, HPA, PDB, app ConfigMaps/settings | Stays in app repo |
| **APP_RELEASE** | Migrations, bootstrap jobs, one-time init jobs, sync CronJobs | Stays in app repo |
| **APP_LOCAL_ONLY** | Local developer support (Kind patches, dev secrets, local ClusterIssuer) | Stays in app repo; never promoted to prod |
| **PLATFORM_SHARED** | Cluster logging, ARC runners, Kyverno policies, ClusterSecretStore, ArgoCD app config | Move to infrastructure repo |
| **ENVIRONMENT_SPECIFIC** | Domain names, ingresses, provider-specific image digests, overlay patches | Move to `infrastructure` repo |
| **DEAD_REFERENCE** | Placeholder images, commented-out resources, contradictory or obsolete files | Quarantine or delete |

---

## What Stays in This Repo

The following categories belong here because they travel with the application code and change on every release:

- `base/deployments.yml`, `base/services.yml`, `base/volumes.yml` — core app workload definitions
- `base/apps/openedx/settings/**` — LMS/CMS Django settings (Python)
- `base/apps/caddy/Caddyfile` — Caddy reverse proxy routing (app-level)
- `base/apps/enterprise/**` — Enterprise service deployments, services, worker deployments
- `base/apps/multi-tenancy/configmap-tenants.yaml` — Tenant registry ConfigMap
- `base/apps/preview-redirect/**` — Preview redirect app
- `base/apps/lms/hpa.yaml`, `base/apps/cms/hpa.yaml` — App-owned HPAs
- `base/secrets/external-secrets.yaml`, `base/secrets/openedx-secrets.yaml` — Secret mappings (not the store)
- `base/secrets/SECRET_CLASSIFICATION.yaml` — Secret registry documentation
- `base/monitoring/**` — ServiceMonitors and PrometheusRules for app metrics
- `base/network-policies/**` — App namespace network policies
- `base/operational/pdb.yaml`, `base/operational/hpa-baselines.yaml` — App reliability
- `base/patches/**` — App-level hardening patches
- `base/jobs/discovery-sync-cronjob.yaml` — Recurring catalog sync
- `services/purchase-gateway/k8s/**` — Purchase gateway (referenced by base kustomization)
- `overlays/local/**` — Local Kind developer environment

## What Moves to the Infrastructure Repo

These resources are cluster-level concerns. They do not change when the application code changes. They belong in `infrastructure` (or an equivalent cluster management repo):

### Platform-Shared Resources (cluster-scoped)

- `base/logging/**` — Promtail DaemonSet, ClusterRole, ClusterRoleBinding. These log from ALL namespaces. Cluster infra team owns them.
- `base/arc/**` — Actions Runner Controller namespaces, RunnerScaleSets, PVCs. CI infrastructure, not app infrastructure.
- `base/policies/**` — Kyverno ClusterPolicies (`require-non-root`, `disallow-privileged`, `require-seccomp`, `restrict-capabilities`). Cluster-wide admission policies; app team should not unilaterally change them.
- `base/secrets/cluster-secret-store.yaml` — ClusterSecretStore for GCP Secret Manager. One per cluster, owned by platform.
- `patches/argocd-configmap-ignore.yaml` — ArgoCD Application spec patch. ArgoCD configuration belongs with the ArgoCD Application manifests in the infra repo.

### Environment-Specific Resources (per-environment overlays)

- `overlays/production/**` — Production GKE ingresses, image digests, replica counts. Managed by infrastructure.
- `overlays/rke2-nonprod/**` — Dev/staging RKE2 ingresses, Infisical patches, domain env. Managed by infrastructure.
- `overlays/staging/**` — Staging overlay duplicating rke2-nonprod with different domains. This overlay has no independent cluster — it shares rke2-nonprod. Consolidate into rke2-nonprod or delete.

## What Needs Action (Dead References and Quarantine)

- `base/apps/hubspot-webhook/**` — Uses `placeholder/hubspot-webhook:latest` image. The actual implementation lives in `services/hubspot-webhook/` (Firebase Cloud Function) and is NOT ready for K8s. This directory is NOT referenced by any active kustomization. **Action: quarantine (move to `_quarantine/`) until K8s migration is ready.**
- `base/apps/xqueue-graders/**` — Has full deployment, HPA, PrometheusRule, and NetworkPolicy, but xqueue is set to `count: 0` in all overlays. The deployment uses `imagePullPolicy: Always` with `:latest` tag (violates immutable tag policy). NOT referenced by base kustomization. **Action: assess — either register in base kustomization with proper image tag or quarantine.**
- `base/apps/permissions/setowners.sh` — A shell script orphan. No kustomization references this file. It is not a Kubernetes resource. **Action: move to `scripts/` or delete.**
- `patches/caddy-staging-fix.yaml` — Labelled "legacy emergency patch." Contains hardcoded production domain names. NOT referenced by any kustomization. **Action: delete after confirming it is not needed.**
- `patches/smtp-ses-relay.yaml` — Manual apply patch for SES relay. NOT referenced by any kustomization. **Action: integrate into proper overlay or delete.**
- `base/secrets/openedx-secrets.yaml` — Commented out in `base/secrets/kustomization.yaml`. Only for local reference. **Action: document status; do not re-enable without review.**

---

## Consequences

### Positive

- Agents and engineers have a clear rule: "if it touches the cluster beyond the mereka-lms namespace, it belongs in the infra repo."
- Kyverno ClusterPolicies and Promtail can be upgraded by the platform team without touching app manifests.
- ARC runner configuration is decoupled from application deployments.
- Dead files are quarantined or removed, reducing confusion.

### Negative

- Moving files requires coordination with the infrastructure repo and ArgoCD Application updates.
- During the transition, both repos may temporarily contain duplicate resources.
- The `overlays/staging/` consolidation requires a decision: does staging share the rke2-nonprod namespace or get a dedicated namespace?

### Migration Order

1. **Phase 1 (no-op, documentation):** This ADR. No file moves. Inventory and classify.
2. **Phase 2 (quarantine dead files):** Move placeholder/obsolete manifests to `_quarantine/` with a README.
3. **Phase 3 (PLATFORM_SHARED extraction):** Move `logging/`, `arc/`, `policies/`, `cluster-secret-store.yaml` to infrastructure. Update kustomization references.
4. **Phase 4 (overlay consolidation):** Move `overlays/production/` and `overlays/rke2-nonprod/` into infrastructure. `overlays/local/` stays here for developer workflow.
5. **Phase 5 (staging decision):** Consolidate or formalize the staging overlay.

---

## Resource Ownership Matrix

See `docs/concepts/architecture/RESOURCE_OWNERSHIP_MATRIX.md` for the full per-file classification table.
