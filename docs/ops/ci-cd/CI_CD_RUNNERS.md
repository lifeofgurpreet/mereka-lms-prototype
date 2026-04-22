# CI/CD Self-Hosted Runners — Actions Runner Controller (ARC)

**Parent docs**: [CI optimization tracker](../../status/active/CI_OPTIMIZATION_TRACKER.md) | [CI pipeline cost analysis](../../reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md)
**Runner policy**: [../../policies/operations/CI_RUNNER_POLICY.md](../../policies/operations/CI_RUNNER_POLICY.md) — which job type uses which runner class
**Tracker tasks**: Phase 1, T150 (Tasks 1.1–1.5)
**Cluster**: rke2-nonprod (Contabo VPS, `154.26.132.35`)

---

## Overview

ARC (Actions Runner Controller) runs ephemeral GitHub Actions runner pods on the rke2-nonprod
Kubernetes cluster. Each workflow job that targets a self-hosted runner label spawns a fresh pod,
runs to completion, then terminates. No runner sits idle between jobs (minRunners: 0).

This eliminates GitHub-hosted runner minutes for all workloads that can reach the cluster,
driving costs from ~$81/month to near-zero (see cost projection in
[../../status/active/CI_OPTIMIZATION_TRACKER.md](../../status/active/CI_OPTIMIZATION_TRACKER.md)).

---

## Architecture

```
GitHub Actions ──HTTPS──► ARC Controller (arc-systems ns)
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
         AutoscalingRunnerSet      AutoscalingRunnerSet
         mereka-k8s-runners        mereka-k8s-heavy-builders
         (arc-runners ns)          (arc-runners ns)
                    │                       │
          Ephemeral pods          Ephemeral pods + DinD sidecar
          2 CPU / 4 GB            4 CPU / 12 GB + PVC caches
```

**Controller** (`arc-systems` namespace): Watches GitHub for queued jobs, creates/deletes
runner pods in `arc-runners` namespace. Deployed via Helm.

**Runner pods** (`arc-runners` namespace): One pod per job. Pod terminates after job completes.
The work directory (`/runner/_work`) uses an `emptyDir` volume — always clean per job.

**Manifests**: `deploy/k8s/base/arc/`
**Overlay**: `deploy/k8s/overlays/rke2-nonprod/` (includes `../../base/arc`)

---

## Available Runner Labels

| Label | Resource limits | Use for |
|-------|----------------|---------|
| `mereka-k8s-runners` | 2 CPU, 4 GB RAM | Linting, spec verification, cron audits, YAML/Markdown checks, Python scripts |
| `mereka-k8s-heavy-builders` | 4 CPU, 12 GB RAM + DinD | `build-tutor-images.yml`, Playwright E2E, any workload needing Docker |

Usage in a workflow file:

```yaml
jobs:
  verify:
    runs-on: mereka-k8s-runners    # or mereka-k8s-heavy-builders

  build:
    runs-on: mereka-k8s-heavy-builders
```

---

## PVC Caching Strategy (Heavy Runners Only)

The heavy runner set uses two `local-path` PersistentVolumeClaims that survive pod restarts:

### arc-docker-cache (50 Gi)

Mounted at `/cache/docker` inside the DinD sidecar. Docker daemon data root is set to
`/cache/docker/daemon`, preserving image layers across runs.

For Tutor builds, use the repo-owned Bake-backed helpers. They select the
canonical BuildKit cache policy from `docker-bake.hcl`; do not invoke raw
`tutor images build` with ad hoc cache flags.

```bash
./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast
./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast
```

Expected effect: Tutor build time drops from 30–45 min to ~5 min on warm cache (only changed
layers rebuild).

### arc-dep-cache (10 Gi)

Mounted at `/cache/deps` inside the runner container. Environment variables pre-configure
standard toolchain cache paths:

| Tool | Env var | Cache path |
|------|---------|------------|
| pip | `PIP_CACHE_DIR` | `/cache/deps/pip` |
| npm | `npm_config_cache` | `/cache/deps/npm` |
| Playwright | `PLAYWRIGHT_BROWSERS_PATH` | `/cache/deps/playwright` |

Playwright browser download (~300 MB for Chromium) is cached after the first run.

**Cache invalidation**: PVCs persist indefinitely. To clear a stale cache:

```bash
kubectl delete pvc arc-docker-cache -n arc-runners
kubectl delete pvc arc-dep-cache -n arc-runners
# Kustomize will recreate them on next apply
kubectl apply -k deploy/k8s/overlays/rke2-nonprod
```

---

## GitHub App Setup (Manual Human Task)

ARC authenticates to GitHub using a GitHub App (not a PAT). This is a one-time setup.

### Step 1: Create the GitHub App

1. Go to: https://github.com/organizations/Biji-Biji-Initiative/settings/apps/new
2. Fill in:
   - **App name**: `mereka-lms-arc`
   - **Homepage URL**: `https://github.com/Biji-Biji-Initiative/mereka-lms`
   - **Webhook**: disabled (ARC uses polling, not webhooks)
3. **Permissions** (Repository):
   - Actions: Read & Write
   - Checks: Read & Write
   - Contents: Read
   - Metadata: Read
4. **Permissions** (Organization):
   - Self-hosted runners: Read & Write
5. Click "Create GitHub App"

### Step 2: Generate a private key

On the App settings page: "Generate a private key" → download the `.pem` file.

Note the **App ID** (shown on the App settings page).

### Step 3: Install the App on the repository

On the App settings page → "Install App" → select `Biji-Biji-Initiative/mereka-lms` → Install.

Note the **Installation ID** from the URL after install
(`https://github.com/organizations/.../installations/<INSTALLATION_ID>`).

### Step 4: Create the K8s Secret

```bash
# Replace values with actual App ID, Installation ID, and private key content
kubectl create secret generic arc-github-app-secret \
  --namespace arc-runners \
  --from-literal=github_app_id=<APP_ID> \
  --from-literal=github_app_installation_id=<INSTALLATION_ID> \
  --from-literal=github_app_private_key="$(cat path/to/private-key.pem)"
```

This secret is referenced by both RunnerScaleSet manifests via `spec.githubConfigSecret`.

**Do not commit the private key to git.** Store it in Infisical as `MEREKA_LMS_ARC_APP_PRIVATE_KEY`.

---

## Deploy Sequence

ARC CRDs must exist before RunnerScaleSet resources can be applied. ARC resources live in
`arc-systems` and `arc-runners` namespaces — they must be applied separately from the main
`mereka-lms` overlay, which sets `namespace: mereka-lms` globally and would override ARC's namespaces.

```bash
# 1. Apply ARC namespaces first (no CRD dependency)
kubectl apply -f deploy/k8s/base/arc/namespace.yaml

# 2. Install ARC controller via Helm (installs CRDs + controller into arc-systems)
helm install arc \
  --namespace arc-systems \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --version 0.9.3 \
  -f deploy/k8s/base/arc/helm-values.yaml

# 3. Wait for controller to be ready
kubectl rollout status deployment/arc-gha-runner-scale-set-controller -n arc-systems

# 4. Create the GitHub App secret (see GitHub App Setup above)

# 5. Apply ARC RunnerScaleSets and PVCs (separate from mereka-lms overlay)
kubectl apply -k deploy/k8s/base/arc/

# 6. Apply the mereka-lms overlay as normal (does not include ARC resources)
kubectl apply -k deploy/k8s/overlays/rke2-nonprod

# 7. Verify runners registered
kubectl get autoscalingrunnersets -n arc-runners

# 8. Verify PVC storage class is local-path
kubectl get pvc -n arc-runners -o custom-columns='NAME:.metadata.name,SC:.spec.storageClassName'
```

**Why separate apply**: The rke2-nonprod overlay sets `namespace: mereka-lms` as a global
Kustomize namespace transformer. Including `../../base/arc` in that overlay would override
`arc-runners` and `arc-systems` namespaces on all ARC resources, breaking the deployment.
The ARC base is applied directly with `kubectl apply -k deploy/k8s/base/arc/`.

---

## Security Model

**Private repository**: `Biji-Biji-Initiative/mereka-lms` is private. GitHub does not send
pull request code from forks to self-hosted runners unless explicitly configured. This is the
primary security boundary that makes self-hosted runners safe for this project.

**No outbound secrets exposure**: Runner pods do not have `automountServiceAccountToken`, so
they cannot access the Kubernetes API. Workflow secrets from GitHub are injected as environment
variables per-job, not persisted to the node.

**DinD isolation**: The DinD sidecar runs privileged (required for Docker daemon), but the
Docker socket is not shared with the host — it runs inside the pod's network namespace. The
runner container accesses Docker via a TLS-authenticated TCP socket, not a host socket mount.

**Ephemeral pods**: Every job starts with a clean filesystem (emptyDir work dir). No state
leaks between jobs. PVCs contain only cache data (no secrets).

**Network policy**: Runners are in `arc-runners` namespace. Apply a NetworkPolicy to restrict
egress to GitHub API (`api.github.com:443`) and internal cluster services if tighter isolation
is required.

---

## Troubleshooting

### Runners not appearing in GitHub repository settings

```bash
# Check ARC controller logs
kubectl logs -n arc-systems -l app.kubernetes.io/component=controller --tail=50

# Check RunnerScaleSet status
kubectl describe autoscalingrunnersets -n arc-runners mereka-k8s-runners

# Common causes:
# - arc-github-app-secret missing or wrong keys
# - GitHub App not installed on the repository
# - ARC controller CRDs not yet applied (install Helm chart first)
```

### Jobs queued but no runner pod spawns

```bash
# Check EphemeralRunner objects (ARC creates one per queued job)
kubectl get ephemeralrunners -n arc-runners

# Check controller events
kubectl get events -n arc-systems --sort-by='.lastTimestamp' | tail -20

# Common causes:
# - minRunners=0 with no queued jobs (expected — pods only spawn on demand)
# - Insufficient cluster resources (check node capacity)
# - Image pull failure (check imagePullPolicy and registry access)
```

### DinD sidecar fails to start (heavy runners)

```bash
kubectl logs <runner-pod-name> -n arc-runners -c dind --tail=50

# Common causes:
# - Node does not support overlay2 storage driver (try vfs as fallback)
# - docker-cache PVC not bound (check PVC status)
kubectl get pvc -n arc-runners
```

### PVC stuck in Pending

```bash
kubectl describe pvc arc-docker-cache -n arc-runners

# Verify local-path-provisioner is installed
kubectl get pods -n kube-system | grep local-path

# local-path provisions PVCs lazily (first pod to mount them triggers provisioning)
# Pending is normal until a runner pod starts and mounts the volume.
```

### Helm upgrade fails

```bash
# Check current chart version
helm list -n arc-systems

# Upgrade (always provide values file)
helm upgrade arc \
  --namespace arc-systems \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  -f deploy/k8s/base/arc/helm-values.yaml
```

---

## Verification Commands

```bash
# After Phase 1 deploy: verify namespaces exist
kubectl get namespaces arc-systems arc-runners

# Verify ARC controller running
kubectl get pods -n arc-systems

# Verify runner scale sets registered
kubectl get autoscalingrunnersets -n arc-runners

# Verify PVCs created (heavy set)
kubectl get pvc -n arc-runners

# After Phase 5 (runner migration): verify jobs run on cluster
kubectl get pods -n arc-runners   # Should show runner pods during active CI runs

# Full CI pipeline verification (after all phases)
./scripts/qa/verify-ci-cd-pipeline.sh
./scripts/qa/verify-github-actions-cost.sh
```

---

## Related Documentation

- [../../policies/operations/CI_RUNNER_POLICY.md](../../policies/operations/CI_RUNNER_POLICY.md) — runner class definitions, job-type routing rules, full workflow audit table, migration checklist
- [../../reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md](../../reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md) — cost analysis and rationale
- [../../status/active/CI_OPTIMIZATION_TRACKER.md](../../status/active/CI_OPTIMIZATION_TRACKER.md) — phase-by-phase implementation tracker
- [../../reference/operations/TUTOR_CONFIG_CI.md](../../reference/operations/TUTOR_CONFIG_CI.md) — Tutor configuration CI reference
- [ALLOWED_ACTIONS_POLICY.md](../security/ALLOWED_ACTIONS_POLICY.md) — GitHub Actions security policy
- ARC upstream docs: https://github.com/actions/actions-runner-controller
- ARC scale set docs: https://github.com/actions/actions-runner-controller/blob/main/docs/scale-set-runner.md
