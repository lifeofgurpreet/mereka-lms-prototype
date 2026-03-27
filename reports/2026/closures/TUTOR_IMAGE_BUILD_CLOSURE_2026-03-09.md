# Build Closure Truth
_Audience: Operators and reviewers • Owner: Platform Team • Last verified: 2026-03-09 • Status: canonical_

Single source of truth for the Mereka LMS Tutor image build pipeline. Written during the experience-closure wave on 2026-03-09 to close the gap between "the build works" and "we understand exactly what the build does."

---

## 1. Build Topology

### Pipeline Identity

| Property | Value |
|----------|-------|
| Workflow | `.github/workflows/build-tutor-images.yml` |
| Trigger | Push to `main` touching `infrastructure/tutor/**`, `assets/branding/**`, or the workflow file itself |
| Manual | `workflow_dispatch` with toggles for openedx/mfe/gitops-update |
| Registry | `ghcr.io/biji-biji-initiative/mereka-lms` |
| Concurrency | Never cancels in-progress builds on `main` |

### Job Graph

```
lint (mereka-k8s-runners)
  ├── build-openedx (mereka-k8s-heavy-builders, 200min timeout)
  ├── build-mfe    (mereka-k8s-heavy-builders, 120min timeout)
  └── slsa-provenance (mereka-k8s-runners, after both builds)
        └── update-gitops (mereka-k8s-runners, optional, after provenance)
```

### What Each Job Builds

| Job | Tutor Command | Output Image | Tags |
|-----|---------------|--------------|------|
| `build-openedx` | `tutor images build openedx --no-registry-cache` | `openedx:${SHA}`, `openedx:${SHORT_SHA}`, `openedx:mereka-brand` (main only) | Immutable SHA + mutable brand |
| `build-mfe` | `tutor images build mfe --no-registry-cache` | `mfe:${SHA}`, `mfe:${SHORT_SHA}`, `mfe:mereka-brand` (main only) | Same pattern |

### Pre-Build Setup (Both Jobs)

1. Checkout repo
2. Free disk space (remove dotnet/android/ghc)
3. Enable swap (8GB, best-effort — fails silently on ARC)
4. Install Python 3.12 + `requirements-tutor.txt` (Tutor)
5. Copy plugin package (`_mereka_lms/`) to Tutor plugins dir
6. `tutor plugins enable mereka_lms`
7. `tutor config save` with LMS_HOST/CMS_HOST/MFE_HOST
8. `./infrastructure/tutor/apply-patches.sh`
9. Set up Docker Buildx (driver: `docker`, NOT `docker-container`)
10. Fix DinD network MTU (1280, via nsenter into DinD PID namespace)

### Post-Build Steps (Both Jobs)

1. Retag Tutor's `overhangio/*` image → `tutor_local/*:latest`
2. Verify branding contract (continue-on-error)
3. Generate SBOM via syft (continue-on-error)
4. Trivy vulnerability scan — CRITICAL vulns block push
5. Tag with SHA, SHORT_SHA, and `mereka-brand` (main only)
6. Push to GHCR
7. Resolve digest via `scripts/infra/resolve-image-digest.sh`
8. SLSA provenance attestation via cosign (keyless Sigstore OIDC)

---

## 2. Cache Truth

### What the workflow claims

> "Registry cache-to is NOT used: requires docker-container driver which is incompatible with --output=type=docker."

### What actually happens

| Cache Layer | Mechanism | Effective? |
|-------------|-----------|------------|
| Registry pull cache (`--cache-from=type=registry`) | **Disabled** — `--no-registry-cache` flag used | No |
| Registry push cache (`--cache-to=type=registry`) | Not configured | No |
| Docker layer cache (DinD volume) | ARC PVC `arc-docker-cache` (50Gi) | **Yes, but fragile** |
| pip cache | No explicit caching | Rebuilt every time |
| npm cache | No explicit caching | Rebuilt every time |
| webpack output | No explicit caching | Rebuilt every time |

### The Real Cache

The only effective cache is the **DinD Docker layer cache** persisted on the ARC runner's PVC (`arc-docker-cache`, 50Gi, RWO). This survives across builds on the same runner pod but is:

- **Lost** if the runner pod is rescheduled to a different node (RWO = ReadWriteOnce)
- **Lost** if the PVC is deleted or the runner scale set is recreated
- **Not shared** between openedx and mfe build jobs (they run on separate runner pods)
- **Prone to bloat** — no automatic cleanup, fills to capacity over time

### Cache Miss Cost

A full cold build (no layer cache):
- **OpenEdX**: ~45-90 min (pip install 200+ packages, collectstatic, compile-sass)
- **MFE**: ~30-60 min (npm install per MFE, webpack build with 6GB heap)

### First Expensive Cache Miss Point

**OpenEdX Dockerfile line ~56**: `ADD --keep-git-dir=true . /openedx/edx-platform`

This ADD busts the cache on ANY change to the edx-platform context. Since Tutor regenerates the Dockerfile on every run (via `tutor config save`), the content hash of the Dockerfile itself changes, invalidating all layers after the base image. This means the pip install, collectstatic, and compile-sass layers are effectively rebuilt every time unless the DinD PVC has the exact same layers from a previous run of the same Dockerfile content.

**MFE Dockerfile**: Similar pattern — `ADD` of the MFE source busts cache for npm install + webpack.

---

## 3. Runner Throughput

### ARC Runner Pools

| Pool | Runner Label | Resources | Max Concurrent | PVC |
|------|-------------|-----------|----------------|-----|
| Standard | `mereka-k8s-runners` | 2 CPU / 4GB RAM | 10 | None |
| Heavy Builders | `mereka-k8s-heavy-builders` | 4 CPU / 12GB RAM + DinD sidecar | 1 | `arc-docker-cache` (50Gi) + `arc-dep-cache` (10Gi) |

### Serialization Bottleneck

**maxRunners=1** for heavy builders + **RWO PVC** = all image builds are strictly serialized. If a build takes 90 minutes, the next build waits 90+ minutes (queue time + build time).

The `build-openedx` and `build-mfe` jobs both require `mereka-k8s-heavy-builders`, but they have `needs: lint` (not each other). In theory they could run in parallel, but **maxRunners=1** forces them to serialize. The current ordering is non-deterministic — whichever gets scheduled first runs, the other waits.

### Throughput Math

- Worst case (cold cache, both images): ~3-4 hours (openedx 90min + mfe 60min + queue/overhead)
- Best case (warm cache, both images): ~1-2 hours
- Current reality: 1 build per 3-4 hours, 4-6 builds per day max

---

## 4. Rebuild Scope — What Triggers a Build

### Path Triggers

```yaml
paths:
  - 'infrastructure/tutor/**'
  - 'assets/branding/**'
  - '.github/workflows/build-tutor-images.yml'
```

### Overly Broad Trigger

Any change to `infrastructure/tutor/**` triggers BOTH openedx AND mfe builds. This includes:
- Plugin Python files (`_mereka_lms/*.py`) — affects both
- Patch scripts (`apply-patches.sh`) — affects both
- Theme SCSS (`themes/mereka/`) — affects openedx only
- MFE-specific configs — affects mfe only
- Config templates — affects both

There is no path-based split to build only the affected image. A CSS-only change rebuilds both images (~3-4 hours).

---

## 5. Migration Truth

### Migrations Are Decoupled from Build

Database migrations (Django `manage.py migrate`) are NOT run during image build. They are:
- Run manually via `kubectl exec` on first deploy
- Run by init containers in some K8s deployments
- Never triggered automatically by a new image push

A new image with schema-changing code requires manual migration before or after deploy. There is no automated migration gate in the build pipeline.

---

## 6. Chosen Architecture

### Current: (B) Stateful Persistent BuildKit Cache

The pipeline uses the DinD Docker layer cache on ARC PVCs as its primary (and only) cache mechanism. This is a deliberate choice:

**Why not registry cache?**
- `--cache-to=type=registry` requires `docker-container` buildx driver
- Tutor uses `--output=type=docker` to load images into the local daemon
- These are incompatible — `docker-container` driver cannot load back into host daemon
- `--no-registry-cache` flag explicitly disables even `--cache-from=type=registry`

**Why not GitHub Actions cache?**
- ARC runners don't have native Actions cache support
- Would need to configure S3-compatible cache backend

**Why stateful PVC?**
- Simplest mechanism that works
- Docker layer cache is the most effective for Dockerfile builds
- No additional infrastructure required

**Known weaknesses**:
- Single point of failure (one PVC, one node)
- No cache sharing between builds
- Cache invalidation is all-or-nothing (Dockerfile change → full rebuild)

---

## 7. What the Plugin Hooks Do During Build

### OpenEdX Build

The `mereka_lms` plugin contributes via Tutor hooks:

1. **`openedx-dockerfile-pre-assets`**: Copies theme directory into image, creates SCSS entry points
2. **`openedx-dockerfile-post-python-requirements`**: Adds extra pip packages (pymongo[srv], etc.)
3. **`openedx-common-settings`**: Injects Django settings (multi-tenancy, CSP, etc.)
4. **`openedx-lms-production-settings`**: LMS-specific production settings (via `lms_settings.py`)
5. **`openedx-cms-production-settings`**: CMS-specific production settings

### MFE Build

1. **`mfe-dockerfile-post-npm-install`**: Copies brand package, runs npm install for brand CSS
2. **`mfe-dockerfile-post-npm-build`**: Injects PARAGON_THEME post-processing into built MFE
3. **Plugin sys.path fix (PR #776)**: `_mereka_lms/__init__.py` adds parent dir to `sys.path` so sibling modules can import each other

### Critical Dependency

Both `apply-patches.sh` (build context setup) AND plugin hooks (Dockerfile injection) are required. CI runs `apply-patches.sh` in step 8 of pre-build setup, which copies brand assets into the build context. Plugin hooks then reference these assets during the Docker build.

If either is missing:
- No `apply-patches.sh` → brand assets not in build context → COPY fails or brand missing
- No plugin hooks → Dockerfile doesn't COPY brand assets or run npm install → brand missing

---

## 8. Recent Build Failures and Fixes

| Build Run | SHA | Failure | Root Cause | Fix |
|-----------|-----|---------|------------|-----|
| 22835438544 | `a5cd7fc2` | `Template syntax error: Encountered unknown tag 'csp_nonce'` | `{% csp_nonce %}` in Python comment parsed as Jinja2 by Tutor | PR #794: escaped to plain text |
| (earlier) | `712f815d` | `ModuleNotFoundError` | Plugin sibling modules couldn't import each other | PR #776: sys.path fix in `__init__.py` |
| (earlier) | pre-776 | `ModuleNotFoundError` | Same | Same |

### Current Build

- **Run**: 22836392215
- **SHA**: `efc0dc60` (includes both PR #776 sys.path fix + PR #794 Jinja2 escape)
- **Status**: OpenEdX building, MFE queued
- **Expected**: First build with all fixes — should succeed

---

## 9. Closure Tests

A build is **closed** (fully understood and reliable) when:

| # | Test | Status |
|---|------|--------|
| 1 | OpenEdX image builds to completion | PENDING (run 22836392215) |
| 2 | MFE image builds to completion | PENDING |
| 3 | OpenEdX branding contract passes (collectstatic, CSS in staticfiles.json) | PENDING |
| 4 | MFE branding contract passes (PARAGON_THEME brand URLs non-empty) | PENDING |
| 5 | SLSA provenance attests both images | PENDING |
| 6 | Trivy scan finds no CRITICAL vulns | PENDING |
| 7 | Image digests are captured and resolvable | PENDING |
| 8 | `mereka-brand` mutable tag is pushed (main branch) | PENDING |
| 9 | No Jinja2 template errors from plugin settings | EXPECTED PASS (PR #794) |
| 10 | No ModuleNotFoundError from plugin imports | EXPECTED PASS (PR #776) |

### Post-Build Closure (GitOps + Runtime)

| # | Test | Status |
|---|------|--------|
| 11 | ArgoCD picks up new `mereka-brand` tag | PENDING |
| 12 | Dev MFE shows non-empty PARAGON_THEME brand URLs | PENDING |
| 13 | Dev CSP shows real hostnames (not localhost) | DONE (PR #1349) |
| 14 | Staging MFE shows non-empty PARAGON_THEME brand URLs | PENDING |
| 15 | Staging CSP shows real hostnames | DONE (PR #1349) |

---

## Appendix: File Map

| File | Role |
|------|------|
| `.github/workflows/build-tutor-images.yml` | Build workflow (770+ lines) |
| `infrastructure/tutor/plugins/mereka_lms.py` | Main plugin entry point |
| `infrastructure/tutor/plugins/_mereka_lms/` | Plugin package (settings, hooks, Dockerfile patches) |
| `infrastructure/tutor/apply-patches.sh` | Build context setup (brand assets, Node fixes, etc.) |
| `infrastructure/tutor/themes/mereka/` | Comprehensive theme (LMS + CMS + MFE SCSS) |
| `assets/branding/` | Brand assets (logos, favicons) |
| `scripts/infra/resolve-image-digest.sh` | Digest resolution for pushed images |
| `scripts/qa/verify-mfe-image-branding.sh` | MFE branding contract verification |
| `deploy/k8s/base/arc/` | ARC runner manifests (namespaces, Helm values, PVCs) |
