# Build Pipeline Runbook — Tutor Image Builds

**Workflow**: `.github/workflows/build-tutor-images.yml`
**Cluster**: rke2-nonprod (Contabo VPS, `154.26.132.35`)
**Registry**: `ghcr.io/biji-biji-initiative/mereka-lms`
**Runner label**: `mereka-k8s-heavy-builders` (4 CPU, 12 GB RAM + DinD sidecar)

> **NEVER fall back to GitHub-hosted runners.** All builds MUST use ARC. — User directive, March 2026

---

## Quick Reference

### Trigger a build manually
```bash
gh workflow run build-tutor-images.yml --ref main
```

### Monitor a running build
```bash
# GitHub side
gh run list --workflow=build-tutor-images.yml --limit 3
gh run view <run-id> --json jobs --jq '.jobs[] | {name, status, conclusion}'

# Cluster side — runner pods
kubectl --context rke2-nonprod get pods -n arc-runners -l actions.github.com/scale-set-name=mereka-k8s-heavy-builders

# DinD logs (if Docker operations fail)
kubectl --context rke2-nonprod logs <pod-name> -n arc-runners -c dind --tail=50
```

### Verify ARC is healthy
```bash
# Controller running
kubectl --context rke2-nonprod get pods -n arc-systems

# Runner scale sets registered
kubectl --context rke2-nonprod get autoscalingrunnerset -n arc-runners

# ArgoCD Application status
kubectl --context rke2-nonprod get app arc-runners-heavy -n argocd -o jsonpath='{.status.sync.status}{" "}{.status.health.status}'
```

---

## Architecture

```
GitHub Actions ─── HTTPS ──► ARC Controller (arc-systems)
                                     │
                         AutoscalingRunnerSet
                         mereka-k8s-heavy-builders
                         (arc-runners namespace)
                                     │
                         ┌───────────┴───────────┐
                         │ Pod (per build job)    │
                         │  ├─ runner container   │
                         │  │  └─ DOCKER_HOST     │
                         │  │     unix:///var/run/ │
                         │  │     docker.sock      │
                         │  ├─ dind init container │
                         │  │  └─ --mtu=1280       │
                         │  └─ init-dind-externals │
                         └─────────────────────────┘
                                     │
                           docker build → push
                                     │
                           GHCR (ghcr.io)
```

**Image tagging strategy**:
- `<git-sha>` — immutable, 40-char full SHA
- `<short-sha>` — immutable, 8-char
- `mereka-brand` — mutable, updated on main branch pushes (dev auto-deploy tag)

---

## Critical Rules (Learned the Hard Way)

### 1. DinD Double-Injection Bug (CRITICAL)

**Problem**: ARC Helm chart v0.13.x auto-injects DinD init containers when `containerMode.type: "dind"` is set. If you ALSO manually define DinD init containers in the template, you get duplicates:
```
Failed to create the pod: spec.volumes[3].name: Duplicate value: "dind-sock"
spec.volumes[4].name: Duplicate value: "dind-externals"
spec.initContainers[2].name: Duplicate value: "init-dind-externals"
spec.initContainers[3].name: Duplicate value: "dind"
```

**Root cause**: The Helm chart docs explicitly state:
> "If any customization is required for dind or kubernetes mode, containerMode should remain empty, and configuration should be applied to the template."

**Correct configuration**: Do NOT set `containerMode` at all. Define the full DinD template manually:
```yaml
# In ArgoCD Application Helm values (bbi-infrastructure):
# DO NOT set containerMode. Define template directly.
template:
  spec:
    initContainers:
      - name: init-dind-externals
        image: ghcr.io/actions/actions-runner:2.332.0
        command: ["cp", "-r", "/home/runner/externals/.", "/home/runner/tmpDir/"]
        volumeMounts:
          - name: dind-externals
            mountPath: /home/runner/tmpDir
      - name: dind
        image: docker:dind
        args:
          - dockerd
          - --host=unix:///var/run/docker.sock
          - --group=$(DOCKER_GROUP_GID)
          - --mtu=1280
        # ...
    containers:
      - name: runner
        image: ghcr.io/actions/actions-runner:2.332.0
        env:
          - name: DOCKER_HOST
            value: unix:///var/run/docker.sock
```

**Where this lives**: `bbi-infrastructure/clusters/dev/rke2/apps/arc-runners-heavy.yaml` (ArgoCD Application with Helm values). See also ADR-002 in bbi-infrastructure.

**containerMode option matrix**:
| Setting | Behavior | Works? |
|---------|----------|--------|
| `containerMode.type: "dind"` | Auto-generates DinD + duplicates with manual template | NO |
| `containerMode.type: "kubernetes"` | Requires `container:` key in every workflow job | NO (breaks most jobs) |
| **omit containerMode entirely** | No auto-injection, use manual template | YES |

### 2. MTU Must Be 1280 (CRITICAL)

**Why**: rke2-nonprod uses Cilium with VXLAN tunneling. Default Docker bridge MTU (1500) exceeds the tunnel MTU, causing silent packet drops during image pulls and pushes.

**How it's set**: `--mtu=1280` flag on the `dind` init container's `dockerd` args. NOT via daemon.json.

**Verification in CI** (the workflow includes this step):
```bash
MTU=$(docker network inspect bridge --format '{{json .Options}}' \
  | grep -o '"com.docker.network.driver.mtu":"[0-9]*"' \
  | grep -o '[0-9]*')
[[ "${MTU}" == "1280" ]] || exit 1
```

### 3. No `load: true` with docker-container Buildx Driver

**Problem**: `docker/build-push-action` with `driver: docker-container` buildx does not support `load: true` + `push: true` simultaneously.

**Fix**: Use `push: true` only. If you need the image locally (e.g., to retag), use `docker pull` after push:
```yaml
- name: Push mutable mereka-brand tag
  run: |
    docker pull ${{ env.REGISTRY }}/openedx:${{ steps.meta.outputs.tag }}
    docker tag ... mereka-brand
    docker push ...
```

### 4. GHCR Auth Uses GITHUB_TOKEN (No GCP SA Key)

```yaml
- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

**Permissions required**: `packages: write` on the job. No `id-token: write` needed (that's only for cosign in the SLSA provenance job).

### 5. Tutor Version Pinning (CRITICAL)

**File**: `requirements-tutor.txt` at repo root
```
tutor[full]==21.0.0
tutor-mfe==21.0.0
```

**All Tutor usage MUST install from this file**:
```yaml
- uses: ./.github/actions/setup-python-env
  with:
    requirements-file: 'requirements-tutor.txt'
```

**Never hardcode Tutor version in workflow YAML.** Previous incident: `ci.yml`, `setup-local.sh`, and `build-optimizations.sh` all had `tutor[full]==18.2.2` hardcoded while `requirements-tutor.txt` had moved to 21.0.0.

### 6. Python 3.12 Paths (Tutor Ulmo)

Tutor v21 (Ulmo) uses Python 3.12. Any path referencing `site-packages` must use `python3.12`, not `python3.11`:
```
/openedx/venv/lib/python3.12/site-packages/
```

### 7. ArgoCD Manages ARC Resources

The `arc-runners-heavy` ArgoCD Application deploys the heavy runner AutoscalingRunnerSet via Helm chart `gha-runner-scale-set` v0.13.1. Changes to runner config must go through:

```
Edit bbi-infrastructure/clusters/dev/rke2/apps/arc-runners-heavy.yaml
  → Push to main
  → ArgoCD auto-syncs (selfHeal: true, 3-min poll)
```

**Emergency bypass** (if you must patch the cluster directly):
```bash
kubectl --context rke2-nonprod \
  --as=system:serviceaccount:argocd:argocd-application-controller \
  apply -f <file>
```

Then commit the same change to git within 5 minutes.

---

## Troubleshooting Decision Tree

```
Build failed?
├─ Jobs never start (queued forever)?
│  ├─ Check: kubectl get autoscalingrunnerset -n arc-runners
│  │  └─ Missing? → ArgoCD may have failed to sync. Check argocd app status.
│  ├─ Check: kubectl get pods -n arc-systems
│  │  └─ Controller not running? → Check arc-systems events/logs.
│  └─ Check: kubectl logs -n arc-systems -l app.kubernetes.io/component=controller --tail=50
│     └─ Auth errors? → arc-github-app-secret may be expired/wrong.
│
├─ Pod creation fails?
│  ├─ "Duplicate value: dind-sock" → containerMode is set. Remove it. See Rule #1.
│  ├─ "Insufficient resources" → Node is full. Check: kubectl top nodes
│  └─ "ImagePullBackOff" → GHCR rate limit or network. Check DinD MTU.
│
├─ DinD not ready (DOCKER_HOST fails)?
│  ├─ Check dind init container logs: kubectl logs <pod> -c dind -n arc-runners
│  ├─ MTU wrong? → Check Rule #2. Network drops cause Docker daemon to hang.
│  └─ RUNNER_WAIT_FOR_DOCKER_IN_SECONDS=120 gives 2 min. If DinD takes longer, increase.
│
├─ Docker build fails mid-way?
│  ├─ OOM? → Check container limits (12 GB for runner, 4 GB for dind)
│  ├─ Network timeout during pip/npm? → MTU issue (Rule #2) or DNS failure
│  └─ "context canceled"? → Another build cancelled this one (concurrency group)
│
├─ Push to GHCR fails?
│  ├─ 403? → Check `packages: write` permission on the job
│  ├─ Auth error? → GITHUB_TOKEN not passed to docker/login-action
│  └─ Network? → MTU issue or GHCR outage (check https://githubstatus.com)
│
└─ Trivy/SBOM step fails?
   ├─ Trivy install fails? → curl to raw.githubusercontent.com blocked. MTU or DNS.
   └─ CRITICAL vulns found? → Legitimate. Check var/ci/trivy-*.json artifact.
```

---

## Build Pipeline Steps (Reference)

### OpenEdX Image (`build-openedx` job)
1. Checkout code
2. Set up Python 3.12 + install Tutor from `requirements-tutor.txt`
3. Render Tutor environment (`tutor config save` + `apply-patches.sh`)
4. Verify DinD MTU = 1280
5. Set up Docker Buildx (docker-container driver)
6. Login to GHCR
7. Build + push image with registry cache
8. Retag as `mereka-brand` (main branch only)
9. Verify branding contract (staticfiles.json has mereka-overrides.css)
10. Generate SBOM (CycloneDX)
11. Scan with Trivy (fail on CRITICAL)
12. Resolve and output digest

### MFE Image (`build-mfe` job)
Same steps but with MFE-specific context/Dockerfile and MFE branding verification.

### Post-build
- **SLSA Provenance**: cosign keyless attestation (Sigstore OIDC) — runs on ubuntu-24.04
- **GitOps Update**: (manual dispatch only) Updates `bbi-infrastructure` with new digests

---

## Related Files

| File | Purpose |
|------|---------|
| `.github/workflows/build-tutor-images.yml` | The workflow |
| `requirements-tutor.txt` | Pinned Tutor version (source of truth) |
| `infrastructure/tutor/apply-patches.sh` | Post-config-save patches |
| `scripts/ci/preflight-check.sh` | Pre-build Dockerfile validation |
| `scripts/infra/resolve-image-digest.sh` | Digest resolution helper |
| `scripts/qa/verify-mfe-image-branding.sh` | MFE branding contract check |
| `deploy/k8s/base/arc/` | ARC manifests (local reference) |
| `bbi-infrastructure/clusters/dev/rke2/apps/arc-runners-heavy.yaml` | Actual ARC config (ArgoCD) |
| `bbi-infrastructure/docs/adr/002-arc-dind-mtu-configuration.md` | ADR for DinD MTU fix |

---

## Related Docs

- [CI_CD_RUNNERS.md](../ci-cd/CI_CD_RUNNERS.md) — ARC architecture, runner labels, PVC caching, GitHub App setup
- [CI_OPTIMIZATION_TRACKER.md](../ci-cd/CI_OPTIMIZATION_TRACKER.md) — Phase tracker for CI cost optimization
- [CI_PIPELINE_COST_OPTIMIZATION.md](../ci-cd/CI_PIPELINE_COST_OPTIMIZATION.md) — Cost analysis
- GitHub Issue #150 — March 2026 lessons learned

---

## Changelog

| Date | Change | Issue |
|------|--------|-------|
| 2026-03-03 | Migrated from GCP Artifact Registry to GHCR | #150 |
| 2026-03-03 | Fixed DinD double-injection (removed containerMode) | #150 |
| 2026-03-03 | Upgraded Tutor 18.2.2 → 21.0.0 (Ulmo), Python 3.11 → 3.12 | #150 |
| 2026-03-03 | Removed `load: true` (incompatible with docker-container driver) | #150 |
