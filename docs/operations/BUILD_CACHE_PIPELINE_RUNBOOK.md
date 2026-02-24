# Build & Cache Pipeline Hardening Runbook

> **Audience**: Platform Eng · **Owner**: Infra Team · **Last verified**: 2026-02-19
>
> Covers: cache hygiene, fast rebuild paths, image-tagging strategy, RKE2→GKE migration
> notes, and artifact verification before production rollout.
>
> AC-OPS-211, AC-OPS-212, AC-OPS-213, AC-OPS-214

---

## Quick Reference

| Scenario | Command |
|---|---|
| Full rebuild (no cache) | `tutor images build openedx -a PIP_COMMAND=pip` |
| Incremental rebuild (with cache) | `DOCKER_BUILDKIT=1 docker build --cache-from <prior-tag> ...` |
| Tag both images | See [Step 2: Tag Strategy](#step-2-tag-strategy) |
| Push to Artifact Registry | `docker push "${GAR}/openedx:${TAG}"` |
| GitOps rollout | `./scripts/infra/release-openedx-gitops.sh ...` |
| Verify image overrides contract | `./scripts/qa/verify-gitops-image-overrides.sh --check-infra` |

---

## Step 1: Canonical Rebuild Sequence (AC-OPS-211)

### 1a. When to do a full rebuild

Trigger a full rebuild when:
- Open edX base image has changed (Tutor version bump, `requirements.txt` changes)
- `infrastructure/tutor/apply-patches.sh` has new patches affecting Dockerfile layers
- `tutor_env/` config has changed (e.g., new plugin, MFE branding changes)
- Security advisory for a dependency in the image

```bash
export TUTOR_ROOT="$(pwd)/tutor_env"
source infrastructure/tutor/tutor-env.sh

# Full rebuild: LMS/CMS/workers (30–45 min, needs ≥12 GB Docker RAM)
tutor images build openedx -a PIP_COMMAND=pip

# Full rebuild: MFE (15–20 min)
tutor images build mfe

# Verify images are present
docker images | grep -E "overhangio/openedx|overhangio/openedx-mfe"
```

> **PIP_COMMAND=pip**: Tutor v21 defaults to `uv pip` which breaks `loremipsum==1.0.5`
> (needs `pkg_resources`). Always pass `PIP_COMMAND=pip` for the openedx image build.

### 1b. When to use cache (incremental build)

Use `--cache-from` when only theme/static files have changed and you want to skip
re-running the 20+ min pip install layer:

```bash
GAR="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"
PRIOR_TAG="mereka-brand-hotfix-full-v2"   # last known-good tag

# Pull prior image to warm local Docker cache
docker pull "${GAR}/openedx:${PRIOR_TAG}"

# Build with cache
DOCKER_BUILDKIT=1 docker build \
  --cache-from "${GAR}/openedx:${PRIOR_TAG}" \
  --tag docker.io/overhangio/openedx:latest \
  "$(tutor config printroot)/env/build/openedx"
```

> **Cache busting**: If `requirements/edx/base.txt` or any Dockerfile `RUN pip install`
> layer changed, Docker will miss the cache anyway. In that case fall back to full rebuild.

### 1c. Cache hygiene — when to bust

Force a fresh layer even with `--cache-from` by adding `--no-cache` or by touching
the `Dockerfile` when:

- A base OS/Python image (`FROM`) had a CVE patch
- `loremipsum`, `mongoengine`, or any pinned dep version changed
- You suspect a stale wheel from a prior broken build is being reused

```bash
# Bust all layers (safest option before a production release)
tutor images build openedx -a PIP_COMMAND=pip --no-cache
```

### 1d. Post-build artifact check

```bash
# Confirm image exists and check size
docker images docker.io/overhangio/openedx:latest --format "{{.Size}}"
# Expected: ~3–4 GB for openedx, ~500 MB for mfe

# Inspect entrypoint to catch silent build failures
docker inspect docker.io/overhangio/openedx:latest \
  --format '{{.Config.Entrypoint}}'
# Expected: [/usr/local/bin/uwsgi ...]

# Quick smoke: start container and check HTTP
docker run --rm -d --name smoke-lms \
  -p 18001:8000 \
  docker.io/overhangio/openedx:latest lms
sleep 5 && curl -sI http://localhost:18001/ | head -1
docker stop smoke-lms
```

---

## Step 2: Tag Strategy (AC-OPS-212)

### Standard tags (CI / routine releases)

Use `{sha7}-{YYYYMMDDHHmmSS}` for all routine releases. This makes every tag
traceable to a commit and build time.

```bash
TAG="$(git rev-parse --short HEAD)-$(date +%Y%m%d%H%M%S)"
GAR="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"

# Tag both images with the same TAG
docker tag docker.io/overhangio/openedx:latest "${GAR}/openedx:${TAG}"
docker tag docker.io/overhangio/openedx-mfe:latest "${GAR}/openedx-mfe:${TAG}"

# Push
docker push "${GAR}/openedx:${TAG}"
docker push "${GAR}/openedx-mfe:${TAG}"

echo "TAG=${TAG}"  # record for release-openedx-gitops.sh
```

### Hotfix tags (manual branching fix)

When fixing a branding or config issue without a full code change (e.g., after
`apply-patches.sh` adds a new patch), use the `mereka-brand-hotfix-full-vN`
naming convention. Increment `N` for each successive hotfix build.

```bash
# Find current hotfix number
PREV_TAG=$(grep "mereka-brand-hotfix-full" \
  deploy/k8s/overlays/production/kustomization.yaml | grep newTag | \
  awk '{print $2}' | head -1)
# e.g. mereka-brand-hotfix-full-v2

N=$(echo "$PREV_TAG" | grep -o 'v[0-9]*$' | tr -d v)
NEXT_N=$((N + 1))
HOTFIX_TAG="mereka-brand-hotfix-full-v${NEXT_N}"

docker tag docker.io/overhangio/openedx:latest "${GAR}/openedx:${HOTFIX_TAG}"
docker push "${GAR}/openedx:${HOTFIX_TAG}"

echo "HOTFIX_TAG=${HOTFIX_TAG}"
```

> **Use standard tags when possible.** Hotfix tags are for emergency fixes between
> regular CI runs. They do not include the MFE image — only tag/push MFE separately
> if MFE was actually rebuilt.

### Fallback path: deploy without rebuilding

If an image tag already exists in Artifact Registry (e.g., from a CI build), skip
local build and push only the kustomization update:

```bash
# Verify tag exists in Artifact Registry before using it
gcloud artifacts docker tags list \
  asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx \
  --filter="tag:${TAG}" --format="value(tag)"

# If tag exists, go straight to GitOps rollout
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "${TAG}" --mfe-tag "${MFE_TAG}" \
  --target-env production --apply --commit --push
```

### Canonical release orchestration

```bash
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "${TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --target-env production \
  --apply --commit --push --verify-runtime
```

> **Known bug (fixed 2026-02-19):** Earlier versions of `release-openedx-gitops.sh`
> missed the double-override entry in bbi-infrastructure (`asia-southeast1-docker.pkg.dev/.../openedx`
> without `-mfe`). This is now fixed — the script updates all four image entries.
> If you see the LMS deployment not rolling after a release, check that the
> `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx` entry in
> `bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml` was updated.

---

## Step 3: RKE2 → GKE Migration Notes (AC-OPS-213)

### Architecture compatibility

Both RKE2 (VPS/Kind) and GKE use `linux/amd64`. Images built on either platform
can be pushed to the same Artifact Registry and deployed to either cluster **without
rebuilding**, as long as:

- The base image is `linux/amd64` (Tutor's upstream images are amd64-only)
- No ARM-specific binary was accidentally linked (rare, but verify with `docker inspect`)

```bash
# Verify image architecture before cross-env deploy
docker inspect "${GAR}/openedx:${TAG}" \
  --format '{{.Architecture}}/{{.Os}}'
# Expected: amd64/linux
```

### What to rebuild vs copy

| Scenario | Rebuild? | Copy from registry? |
|---|---|---|
| Same code, new K8s cluster | No | Yes — pull tag, push to same GAR |
| New Tutor version (Ulmo patch) | Yes | No |
| Only kustomization/config change | No | Yes — reuse existing tag |
| Theme/CSS change (apply-patches) | Yes (openedx only) | MFE can be reused |
| MFE frontend code change | Yes (mfe only) | openedx can be reused |
| Base OS security patch | Yes (both) | No |

### Registry separation

RKE2 (VPS) cluster points to the **same** Artifact Registry as GKE. No separate
registry per cluster. Tag naming convention is shared. Key difference:

```
GKE production:   bbi-infrastructure/overlays/prod  → mereka-brand-hotfix-full-v3
RKE2 / Kind dev:  deploy/k8s/overlays/local         → uses base tag (latest)
```

> Dev cluster (`local` overlay) typically relies on the Tutor `latest` tag rather than
> a pinned release tag. Pin the dev tag explicitly when testing a specific build:
> ```bash
> # Override local overlay for specific build testing
> kustomize edit set image \
>   docker.io/overhangio/openedx=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG}
> ```

### Cross-cluster smoke after image reuse

After reusing an image from one cluster on another, verify:

```bash
# 1. Confirm pod is using expected image
kubectl get pod -n mereka-lms -l app.kubernetes.io/name=lms \
  -o jsonpath='{.items[0].spec.containers[0].image}'

# 2. Quick endpoint smoke
curl -sI https://academyv2.mereka.io/ | head -2
curl -sI https://studio.academyv2.mereka.io/ | head -2

# 3. Check for known RKE2→GKE migration gotchas in logs
kubectl logs -n mereka-lms -l app.kubernetes.io/name=lms --tail=50 \
  | grep -iE "error|exception|failed|refused" | head -20
```

---

## Step 4: CI Hooks and Verification (AC-OPS-211)

### Pre-push: image override contract

Before committing a new tag to any kustomization file, verify the cross-repo
image override contract is consistent:

```bash
# Checks all four image entries across app repo + bbi-infrastructure are aligned
INFRA_PROD_OVERLAY=/home/gurpreet/projects/k8s/bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml \
APP_BASE=deploy/k8s/base/kustomization.yaml \
APP_PROD_OVERLAY=deploy/k8s/overlays/production/kustomization.yaml \
  ./scripts/qa/verify-gitops-image-overrides.sh --check-infra
```

Expected output: `✓ GitOps image override contract checks passed`

### Post-deploy: ArgoCD health gate

```bash
# Wait for ArgoCD to sync and deployment to stabilize
kubectl rollout status deployment/lms -n mereka-lms --timeout=300s
kubectl rollout status deployment/cms -n mereka-lms --timeout=300s

# Confirm ArgoCD Synced+Healthy
kubectl get application mereka-lms-prod -n argocd \
  -o jsonpath='{.status.sync.status} {.status.health.status}'
# Expected: Synced Healthy   (or Synced Degraded if known pre-existing CronJob errors)
```

### Post-deploy: endpoint smoke matrix

```bash
./scripts/qa/verify-post-deploy-smoke.sh --env prod \
  --evidence-dir "var/evidence/release-$(date +%Y%m%d)"
```

---

## Troubleshooting

### LMS pods not rolling after release

Most common cause: the bbi-infrastructure overlay has a double-override entry
that the release script missed (fixed in 2026-02-19 release). Check manually:

```bash
grep "newTag" /home/gurpreet/projects/k8s/bbi-infrastructure/apps/mereka-lms/overlays/prod/kustomization.yaml
# All four entries should show the same openedx tag and same mfe tag
```

If one entry is stale, edit and push bbi-infrastructure, then re-annotate ArgoCD:
```bash
kubectl annotate application mereka-lms-prod -n argocd \
  argocd.argoproj.io/sync-force="$(date +%s)" --overwrite
```

### Docker build OOM during webpack

```bash
# Increase node memory via Tutor build arg
tutor images build mfe -a NODE_OPTIONS="--max-old-space-size=6144"
```

### Cache miss on incremental build

If `--cache-from` shows all layers as MISS, the prior image may have been built
on a different Docker daemon or the layer hashes diverged. Fall back to full build:
```bash
tutor images build openedx -a PIP_COMMAND=pip --no-cache
```

### `loremipsum==1.0.5` build failure

```
ERROR: loremipsum==1.0.5 requires pkg_resources, not available under uv pip
```

Fix: always pass `-a PIP_COMMAND=pip` to `tutor images build openedx`.

---

## Reference

- Branding release runbook (full deploy flow): `docs/operations/BRANDING_RELEASE_RUNBOOK.md`
- Release orchestrator: `scripts/infra/release-openedx-gitops.sh`
- Image override contract verifier: `scripts/qa/verify-gitops-image-overrides.sh`
- Post-deploy smoke: `scripts/qa/verify-post-deploy-smoke.sh`
- BRANDING.md (theme sync guide): `docs/BRANDING.md`
- Tutor configuration runbook: `docs/operations/runbooks/TUTOR_CONFIGURATION_RUNBOOK.md`
