# Build & Cache Pipeline Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-12 • Status: active_

> **Audience**: Platform Eng · **Owner**: Infra Team · **Last verified**: 2026-03-03
>
> Covers: CI architecture, ARC runner setup, registry (GHCR), tag strategy, cache
> strategy, triggering builds, post-build GitOps, and a troubleshooting tree for
> every failure mode we have hit.
>
> Production release authority is the governed workflow
> `.github/workflows/build-tutor-images.yml` followed by
> `./scripts/infra/release-openedx-gitops.sh --require-digests`. Any `docker push`
> examples in this runbook describe workflow internals or local debugging, not the
> normal production operator path.
>
> AC-OPS-211, AC-OPS-212, AC-OPS-213, AC-OPS-214

---

## Architecture Overview

### Registry: GHCR

Images are published to the GitHub Container Registry. No GCP service account key
is required — the workflow uses `GITHUB_TOKEN` for both push and pull.

```
Registry:  ghcr.io/biji-biji-initiative/mereka-lms
Images:    ghcr.io/biji-biji-initiative/mereka-lms/openedx:<tag>
           ghcr.io/biji-biji-initiative/mereka-lms/mfe:<tag>
```

Auth in workflow:

```yaml
- name: Log in to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

No `gcloud auth configure-docker`, no `GCP_SA_KEY`. The `id-token: write` permission
is only present on the `slsa-provenance` job (needed for Sigstore keyless signing).

### CI Runners: ARC on rke2-nonprod

Heavy build jobs run on self-hosted ARC (Actions Runner Controller) runners deployed
on the `rke2-nonprod` cluster:

| Runner label | Resources | Node |
|---|---|---|
| `mereka-k8s-heavy-builders` | 4 CPU / 12 GB RAM + DinD sidecar | rke2-nonprod |

Runners scale 0 → 3. When idle, no pods exist. A queued build triggers the scale-up.

**DinD sidecar** (`docker:24-dind`):
- Provides a full Docker daemon for `tutor images build`
- Communicates over TLS TCP socket (`tcp://localhost:2376`)
- MTU is **1280** (required for Cilium VXLAN tunneling on RKE2)
- `--data-root=/cache/docker/daemon` (persistent PVC)

**PVC caches** (survive pod restarts, reduce build time from 30-45 min to ~5 min warm):

| PVC | Size | Mount | Contents |
|---|---|---|---|
| `arc-docker-cache` | 50 Gi | `/cache/docker` (DinD) | Docker layer cache |
| `arc-dep-cache` | 10 Gi | `/cache/deps` (runner) | pip / npm / Playwright |

Manifests: `deploy/k8s/base/arc/`

### Workflow: `.github/workflows/build-tutor-images.yml`

Four jobs, executed in this order:

```
lint ──┬──► build-openedx ──► slsa-provenance
       └──► build-mfe     ──┘
                               update-gitops (manual bridge, if enabled)
```

`build-openedx` and `build-mfe` run in parallel on `mereka-k8s-heavy-builders`.
`slsa-provenance` runs on `ubuntu-24.04` (GitHub-hosted) after both build jobs.

**Triggers**:
- `push` to `main` on governed Tutor/build paths. Push runs now resolve a
  conservative build scope first:
  - obvious Open edX-only changes build only `build-openedx`
  - obvious MFE-only changes build only `build-mfe`
  - shared or ambiguous changes still build both images
- `workflow_dispatch` (manual) with inputs: `build_openedx`, `build_mfe`,
  `update_gitops`, `target_environment`, `openedx_runner`, `image_tag`

**Important**:
- `workflow_dispatch` remains the canonical dual-image release/proof path when
  you need both digests and the `release-bundle` artifact.
- partial `push` builds are an iteration-speed optimization, not a substitute
  for the explicit release/promotion lane.

---

## Tag Strategy (AC-OPS-212)

### Immutable tags (always produced)

Every successful build produces two immutable tags per image:

| Tag | Example | Description |
|---|---|---|
| Full SHA | `abc123def456...` (40 chars) | Exact commit, used for digest pinning |
| Short SHA | `abc123de` (8 chars) | Used in kustomization overrides |

```bash
TAG="${{ inputs.image_tag || github.sha }}"      # full SHA or manual override
SHORT_SHA="${GITHUB_SHA::8}"

docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:${TAG}
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:${SHORT_SHA}
```

### Mutable tag: `mereka-brand` (main push only, compatibility alias)

On `push` to `main`, an additional mutable `mereka-brand` tag is pushed as a
compatibility/debug alias. It is no longer the canonical dev deployment
contract. Dev promotion now happens through the infra-owned
`bbi-infrastructure/.github/workflows/promote-dev-image.yml` workflow, which
consumes immutable tags/digests and writes the overlay PR explicitly.

```bash
# Only on: github.event_name == 'push' && github.ref == 'refs/heads/main'
docker pull ghcr.io/biji-biji-initiative/mereka-lms/openedx:${TAG}
docker tag  ghcr.io/biji-biji-initiative/mereka-lms/openedx:${TAG} \
            ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:mereka-brand
```

Note: The pull before retag is required — the image is not in the local daemon
after a push-only workflow step.

### Cache tag: `buildcache`

Registry-backed BuildKit cache uses a dedicated tag per image:

```
ghcr.io/biji-biji-initiative/mereka-lms/openedx:buildcache
ghcr.io/biji-biji-initiative/mereka-lms/mfe:buildcache
```

Configured as `type=registry,ref=...:buildcache,mode=max`. This persists across
runner pod restarts and is used automatically by `docker buildx build`.

### No `mereka-brand-hotfix-full-vN` tags

The old sequential hotfix tag convention (`mereka-brand-hotfix-full-v1`,
`mereka-brand-hotfix-full-v2`, etc.) is **retired**. All images are now identified
by SHA. For an emergency re-tag, just push the existing SHA-tagged image to a new
tag:

```bash
docker pull ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OLD_SHA}
docker tag  ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OLD_SHA} \
            ghcr.io/biji-biji-initiative/mereka-lms/openedx:${NEW_SHA_OR_LABEL}
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:${NEW_SHA_OR_LABEL}
```

### Promotion boundary

- `build-tutor-images.yml` owns build outputs, digests, and signed release artifacts.
- `update-gitops` is a guarded manual bridge job, not the default dev path.
- Standard dev/staging/prod promotion is infra-owned in `bbi-infrastructure`
  (`promote-dev-image.yml` / `promote-image.yml`).

---

## Critical Rules (AC-OPS-211)

These rules encode lessons learned from production failures. Violating any of them
has caused broken builds or wasted hours of debugging.

### 1. NEVER set `containerMode` in ARC Helm values when using a custom DinD template

`containerMode.type: "dind"` is a convenience shortcut that auto-injects a DinD
container. If you also have a manually declared `dind` container in the pod
template, ARC injects a second one — both try to mount `dind-sock`, which fails
with `Duplicate value: "dind-sock"`.

The `runner-scale-set-heavy.yaml` manifest uses a hand-crafted DinD sidecar. Do
not add `containerMode` to the ARC Helm values for this runner set.

### 2. MTU must be 1280

RKE2 uses Cilium with VXLAN encapsulation. The overlay adds a 50-byte overhead.
If the DinD daemon uses the default MTU (1500), large TCP packets inside the DinD
network get silently dropped, causing build failures that look like network timeouts
or corrupted package downloads.

Set via `--mtu=1280` in the DinD container's `args`:

```yaml
args:
  - --storage-driver=overlay2
  - --mtu=1280
  - --data-root=/cache/docker/daemon
```

Or via a `daemon.json` ConfigMap mounted into the DinD container. Either works.
Do not remove this setting.

### 3. `load: true` and `push: true` are incompatible with `docker-container` buildx driver

The `docker-container` buildx driver runs in a separate container; it cannot export
directly to the local Docker daemon (`load: true`). Combining both flags causes:

```
ERROR: docker exporter does not currently support exporting manifest lists
```

The workflow uses `push: true` only. To inspect the image locally, pull it from
GHCR after the push.

### 4. NEVER hardcode Python version in Dockerfile paths

The Open edX Dockerfile (managed by Tutor) installs Python packages into a path
that includes the Python version (e.g., `/usr/local/lib/python3.11/site-packages`).

The Docker image uses Python **3.11**. The CI runner uses Python **3.12**. Any
patch that hardcodes `python3.12/site-packages` will create a valid path on the
runner but a non-existent path inside the built image, causing silent failures
at container startup.

Use `sysconfig.get_path('purelib')` for dynamic resolution:

```python
import sysconfig
site_packages = sysconfig.get_path('purelib')
# Returns /usr/local/lib/python3.11/site-packages inside the image
# Returns /usr/local/lib/python3.12/site-packages on the CI runner
```

This is how `build-optimizations.sh` writes the `mereka-plugins.pth` file.

### 5. Tutor version is pinned in `requirements-tutor.txt` — do not duplicate it

`requirements-tutor.txt` is the single source of truth for the Tutor version:

```
tutor==21.0.3
```

Do not specify the version anywhere else: not in workflow YAML, not in scripts,
not in shell aliases. The setup-python-env composite action installs from this
file. Hardcoding in multiple places causes drift.

### 6. Do NOT add `RUN mv node_modules` in Dockerfile patches

A previous `build-optimizations.sh` patch contained:

```bash
RUN mv /openedx/app/node_modules /openedx/node_modules && \
    ln -s /openedx/node_modules /openedx/app/node_modules
```

This was a workaround for a path issue in Tutor 17 (Redwood). Tutor 21 (Ulmo)
fixed the paths natively. If this patch is present, it **breaks** the Ulmo build
because it tries to move a directory that no longer exists at that path, failing
with `mv: cannot stat '/openedx/app/node_modules': No such file or directory`.

If you see this patch in `infrastructure/tutor/patches/build-optimizations.sh`,
remove it.

### 7. ARC runners are non-root — install tools to `$HOME/.local/bin`

The official ARC runner image (`ghcr.io/actions/actions-runner`) runs as a
non-root user. Attempting to install binaries to `/usr/local/bin` fails with:

```
Permission denied: /usr/local/bin/trivy
```

Install CLI tools to `$HOME/.local/bin` and add that to `PATH`:

```bash
mkdir -p "$HOME/.local/bin"
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
```

### 8. Concurrency group blocks parallel `workflow_dispatch` runs

The workflow uses a per-`github.event_name`-and-`github.ref` concurrency group.
For `workflow_dispatch`, `cancel-in-progress` is `false`, so a second manual
trigger queues behind the first one. If the first run is stuck (e.g., ARC runner
pod is deadlocked), the second run stays queued indefinitely.

To unblock:

```bash
# Find the stuck runner pod
kubectl --context rke2-nonprod get pods -n arc-runners

# Delete it — ARC will replace it and the queued run will pick up
kubectl --context rke2-nonprod delete pod <runner-pod-name> -n arc-runners
```

---

## Triggering a Build (AC-OPS-211)

### Manual trigger

```bash
# Build both images (default)
gh workflow run build-tutor-images.yml --ref main

# Build openedx only
gh workflow run build-tutor-images.yml --ref main \
  -f build_openedx=true -f build_mfe=false

# Build MFE only
gh workflow run build-tutor-images.yml --ref main \
  -f build_openedx=false -f build_mfe=true

# Build with a custom tag (overrides git SHA)
gh workflow run build-tutor-images.yml --ref main \
  -f image_tag=my-custom-tag

# Build and update GitOps (triggers kustomization update in infrastructure / BBI-K8 repo)
gh workflow run build-tutor-images.yml --ref main \
  -f update_gitops=true -f target_environment=production
```

### Check run status

```bash
gh run list --workflow=build-tutor-images.yml --limit 5
gh run view <run-id>
gh run watch <run-id>     # live log streaming
```

### Automatic trigger (push to main)

Any push to `main` that touches `infrastructure/tutor/**`, `assets/branding/**`,
or the workflow file itself triggers a build automatically. This is the standard
deployment path.

---

## After Build Succeeds (AC-OPS-212)

### If `update_gitops` was NOT enabled

You need to manually update the image tags in the GitOps repo (`infrastructure`):

1. Edit `https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/apps/mereka-lms/overlays/dev/kustomization.yaml`
2. Edit `https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/apps/mereka-lms/overlays/profiles/dev/kustomization.yaml`
3. Update both `newTag` fields to the new short SHA (8 chars from the build summary)

```yaml
images:
  - name: ghcr.io/biji-biji-initiative/mereka-lms/openedx
    newTag: "abc123de"  # 8-char short SHA from build
  - name: ghcr.io/biji-biji-initiative/mereka-lms/mfe
    newTag: "abc123de"
```

4. Commit and push infrastructure repo
5. ArgoCD auto-syncs within 3 minutes

### Verify rollout

```bash
# Watch deployment rolling update
kubectl rollout status deployment/lms -n mereka-lms --timeout=300s
kubectl rollout status deployment/cms -n mereka-lms --timeout=300s
kubectl rollout status deployment/mfe -n mereka-lms --timeout=300s

# Confirm ArgoCD is Synced+Healthy
kubectl get application mereka-lms-dev -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}'
# Expected: Synced Healthy

# Confirm pods are using the expected image
kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[0].spec.containers[0].image}'
```

### Pre-push: image override contract check

Before committing a new tag to any kustomization file:

```bash
APP_REPO="${APP_REPO:-$(pwd)}"
INFRA_REPO="${INFRA_REPO:-<path-to-bbi-infrastructure>}"
```

```bash
INFRA_PROD_OVERLAY="${INFRA_REPO}/apps/mereka-lms/overlays/prod/kustomization.yaml" \
APP_BASE=deploy/k8s/base/kustomization.yaml \
APP_PROD_OVERLAY=deploy/k8s/overlays/production/kustomization.yaml \
  ./scripts/qa/verify-gitops-image-overrides.sh --check-infra
```

Expected output: `✓ GitOps image override contract checks passed`

---

## Monitoring ARC Runners (AC-OPS-213)

```bash
# Check runner pods (empty = no jobs running, scale=0)
kubectl --context rke2-nonprod get pods -n arc-runners

# Check scale set status
kubectl --context rke2-nonprod get autoscalingrunnersets -n arc-runners

# Tail logs from an active runner
kubectl --context rke2-nonprod logs <runner-pod> -n arc-runners -c runner --tail=50

# Check DinD sidecar logs (useful for MTU/networking issues)
kubectl --context rke2-nonprod logs <runner-pod> -n arc-runners -c dind --tail=50

# Check PVC usage (if builds start OOMing, cache may need pruning)
kubectl --context rke2-nonprod get pvc -n arc-runners
```

### Manual cache pruning

If the 50 Gi docker cache PVC fills up:

```bash
# Exec into the DinD sidecar of a running job (or spawn a temp pod)
kubectl --context rke2-nonprod exec -it <runner-pod> -n arc-runners -c dind -- sh

# Inside the container
docker system prune -af --volumes
# or just prune build cache
docker builder prune -af
```

---

## Troubleshooting (AC-OPS-214)

| Symptom | Cause | Fix |
|---|---|---|
| `Duplicate value: "dind-sock"` | `containerMode.type: "dind"` set in Helm values | Remove `containerMode` from ARC Helm values; the pod template already has a hand-crafted DinD container |
| `node_modules not found` in COPY | Stale `RUN mv node_modules` patch from Redwood era | Remove the mv/ln block from `infrastructure/tutor/patches/build-optimizations.sh` |
| `python3.12/site-packages: No such file or directory` | Hardcoded Python version in a patch (runner is 3.12, image is 3.11) | Replace hardcoded path with `sysconfig.get_path('purelib')` |
| `SyntaxError` in apply-patches.sh | Triple-quote collision: shell `"` inside Python `"""` heredoc | Ensure `"""` appears on its own line, not adjacent to shell-quoted content |
| `Permission denied: /usr/local/bin/trivy` | ARC runner is non-root | Install to `$HOME/.local/bin`, add to `PATH` |
| Build queued forever, never starts | Concurrency group blocked by a stuck cancelled run | Delete the stuck ARC runner pod; the queued run will claim the next fresh pod |
| Silent packet drops, npm/pip downloads hang or corrupt | MTU > 1280 on Cilium overlay | Set `--mtu=1280` on DinD `args` |
| GitHub HTTP 500 during git clone | Transient GitHub infrastructure issue | Retry the run; not a local issue |
| `docker exporter does not currently support exporting manifest lists` | `load: true` + `push: true` with `docker-container` buildx driver | Remove `load: true`; use `push: true` only |
| LMS pods not rolling after GitOps update | GitOps repo has stale tag on one of two override entries | Check all image entries in the prod kustomization: `grep newTag infrastructure/.../kustomization.yaml` |
| `mereka-brand` tag stale after manual trigger | `mereka-brand` is only pushed on `push` to `main`, not on `workflow_dispatch` | Trigger via push, or manually retag and push after a `workflow_dispatch` build |
| DinD container does not start in time | Timing race between runner start and DinD daemon readiness | Add a readiness poll at the start of steps that need Docker: `until docker info >/dev/null 2>&1; do sleep 1; done` |
| `loremipsum==1.0.5` build failure | `uv pip` does not provide `pkg_resources`; Tutor 21 default is `uv pip` | Always pass `-a PIP_COMMAND=pip` to `tutor images build openedx` |
| Swap provisioning skipped on ARC | ARC container runners lack `CAP_SYS_ADMIN`; swap step is non-fatal | Expected behavior; build continues. OOM risk is reduced by DinD having 8 Gi RAM limit and the 50 Gi cache |

### Detailed: LMS pods not rolling after release

Most common cause: two separate `newImage`/`newTag` entries in the infrastructure
overlay for the same base image name. If the release script only updates one, the
other stays pinned to the old tag and ArgoCD sees a diff-free state for the pods
that reference the stale entry.

```bash
# Show all newTag lines in the prod overlay
grep "newTag" https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/apps/mereka-lms/overlays/prod/kustomization.yaml

# All openedx entries must match; all mfe entries must match
```

If one entry is stale, edit and push infrastructure, then force ArgoCD refresh:

```bash
kubectl annotate application mereka-lms-prod -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

### Detailed: `python3.12/site-packages: No such file or directory`

The symptom is a container that starts and immediately exits with an ImportError or
a pth file that silently does nothing. Cause: `build-optimizations.sh` (or another
patch file) wrote:

```bash
echo "mereka_plugins" > "${SITE_PACKAGES}/python3.12/site-packages/mereka-plugins.pth"
```

This path exists on the CI runner (Python 3.12) but not inside the image (Python 3.11).
The fix is in `infrastructure/tutor/patches/build-optimizations.sh` — use Python to
resolve the path dynamically at build time:

```bash
SITE_PACKAGES=$(python3 -c "import sysconfig; print(sysconfig.get_path('purelib'))")
echo "mereka_plugins" > "${SITE_PACKAGES}/mereka-plugins.pth"
```

### Detailed: triple-quote collision in apply-patches.sh

`apply-patches.sh` writes Python content into shell heredocs. When the Python
content itself contains `"""`, and the shell heredoc is delimited by `EOF`, there
is no issue. But if the script uses Python `"""` inside a shell string, the parser
can misinterpret it.

Safe pattern:

```bash
python3 - <<'EOF'
content = """
line one
line two
"""
with open(target, 'w') as f:
    f.write(content)
EOF
```

Unsafe pattern (breaks on some shells):

```bash
python3 -c "content = \"\"\"line one\"\"\"; ..."
```

---

## Local Development Builds

For local iterative development, build images directly with Tutor. The CI pipeline
is not required for local testing.

These commands are for local reproduction, cache diagnosis, and parity checks.
Do not use them as a substitute for the governed production publish path.

### When to do a full local build

- Tutor version bump or `requirements.txt` changes
- `apply-patches.sh` has new patches affecting Dockerfile layers
- `tutor_env/` config changed (new plugin, MFE branding changes)
- Security advisory for a dependency

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Full rebuild: LMS/CMS/workers (30-45 min, needs >=12 GB Docker RAM)
tutor images build openedx -a PIP_COMMAND=pip

# Full rebuild: MFE (15-20 min)
tutor images build mfe

# Verify images are present
docker images | grep -E "tutor_local/openedx|tutor_local/openedx-mfe"
```

`PIP_COMMAND=pip` is required because Tutor 21 defaults to `uv pip`, which does
not provide `pkg_resources`. `loremipsum==1.0.5` (a transitive dep) requires it.

### When to use cache (incremental build)

When only theme or static files changed and you want to skip the 20+ min pip install
layer:

```bash
# BuildKit reuses cached layers automatically when Dockerfile layers are unchanged
DOCKER_BUILDKIT=1 tutor images build openedx -a PIP_COMMAND=pip
```

Force a complete rebuild with `--no-cache`:

```bash
tutor images build openedx -a PIP_COMMAND=pip --no-cache
```

### Post-build local artifact check

```bash
# Confirm image size (expected: ~3-4 GB for openedx, ~500 MB for mfe)
docker images tutor_local/openedx:latest --format "{{.Size}}"

# Inspect entrypoint
docker inspect tutor_local/openedx:latest --format '{{.Config.Entrypoint}}'
# Expected: [/usr/local/bin/uwsgi ...]

# Quick smoke (bring up LMS in isolation)
docker run --rm -d --name smoke-lms \
  -p 18001:8000 \
  tutor_local/openedx:latest lms
sleep 5 && curl -sI http://localhost:18001/ | head -1
docker stop smoke-lms
```

### MFE memory during local build

If the MFE webpack build OOMs locally:

```bash
tutor images build mfe -a NODE_OPTIONS="--max-old-space-size=6144"
```

This is also applied automatically in CI via the `NODE_OPTIONS` env var in the
workflow.

---

## Key Files

| File | Purpose |
|---|---|
| `.github/workflows/build-tutor-images.yml` | Main build + push + SLSA workflow |
| `scripts/infra/prepare-tutor-build-context.sh` | Canonical post-render refresh path after manual `tutor config save` |
| `infrastructure/tutor/patches/build-optimizations.sh` | Dockerfile patches (sysconfig path, PIP_COMMAND) |
| `infrastructure/tutor/plugins/mereka_lms.py` | Tutor plugin — ENV_PATCHES for all environment customizations |
| `deploy/k8s/base/arc/runner-scale-set-heavy.yaml` | ARC runner + DinD sidecar + PVC definitions |
| `deploy/k8s/base/arc/` | Full ARC manifests directory (namespaces, Helm values, RunnerScaleSets) |
| `requirements-tutor.txt` | Tutor version pin — single source of truth |
| `https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/apps/mereka-lms/overlays/dev/kustomization.yaml` | Dev image tag overrides (updated after build) |
| `https://github.com/Biji-Biji-Initiative/BBI-K8/blob/main/apps/mereka-lms/overlays/profiles/dev/kustomization.yaml` | Profile-based dev overlay image tags |
| `scripts/infra/release-openedx-gitops.sh` | Release orchestrator (updates kustomization + commits + pushes) |
| `scripts/qa/verify-gitops-image-overrides.sh` | Pre-push image override contract verifier |
| `scripts/qa/verify-post-deploy-smoke.sh` | Post-deploy endpoint smoke matrix |

---

## Reference

- ARC runner setup guide: `docs/ops/ci-cd/CI_CD_RUNNERS.md`
- CI optimization tracker: `docs/status/active/CI_OPTIMIZATION_TRACKER.md`
- CI cost analysis: `reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md`
- Branding release runbook: `docs/ops/runbooks/BRANDING_RELEASE_RUNBOOK.md`
- Tutor configuration runbook: `docs/ops/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md`
- ADR-021 (Tutor methodology): `docs/adr/021-openedx-tutor-methodology.md`
- BRANDING.md (theme sync guide): `docs/guides/branding/BRANDING.md`
