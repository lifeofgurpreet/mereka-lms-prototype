# Canonical Deploy Contract

> **Beads**: mereka-lms-36va.5, mereka-lms-36va.2, mereka-lms-36va.1
> **Date**: 2026-02-18
> **Canonical path**: `/home/gurpreet/projects/k8s/mereka-lms` on `main`

## 1. Canonical Command Chain (AC-OPS-111, AC-OPS-061)

### Single Source of Truth

All builds and releases MUST originate from:
- **Path**: `/home/gurpreet/projects/k8s/mereka-lms`
- **Branch**: `main`
- **Worktree**: Single (no parallel worktrees)
- **Validation**: `./scripts/infra/canonical-release.sh --check-only`

### Build → Tag → Push → GitOps Flow

```bash
# 0. Preflight (AC-OPS-113, AC-OPS-063)
./scripts/infra/canonical-release.sh --check-only

# 1. Build (if cache miss)
source infrastructure/tutor/tutor-env.sh
./infrastructure/tutor/apply-patches.sh
tutor images build openedx -a PIP_COMMAND=pip     # ~30-45min, 12GB+ RAM
tutor images build mfe                             # ~15-20min

# 2. Tag
OPENEDX_TAG="$(date +%Y%m%d)-openedx-$(git rev-parse --short HEAD)"
MFE_TAG="$(date +%Y%m%d)-mfe-$(git rev-parse --short HEAD)"
docker tag docker.io/overhangio/openedx:latest \
  ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}
docker tag docker.io/overhangio/openedx-mfe:latest \
  ghcr.io/biji-biji-initiative/mereka-lms/mfe:${MFE_TAG}

# 3. Push
docker push ghcr.io/biji-biji-initiative/mereka-lms/openedx:${OPENEDX_TAG}
docker push ghcr.io/biji-biji-initiative/mereka-lms/mfe:${MFE_TAG}

# 4. GitOps update (both repos, dry-run first)
./scripts/infra/canonical-release.sh --dry-run \
  --openedx-tag ${OPENEDX_TAG} --mfe-tag ${MFE_TAG}

# 5. Apply + commit + push
./scripts/infra/canonical-release.sh \
  --openedx-tag ${OPENEDX_TAG} --mfe-tag ${MFE_TAG} \
  --apply --commit --push --verify-runtime

# 5b. Branding/theme release (optional): include frontend cache purge
# Requires Cloudflare credentials in env.
./scripts/infra/canonical-release.sh \
  --openedx-tag ${OPENEDX_TAG} --mfe-tag ${MFE_TAG} \
  --apply --commit --push --verify-runtime \
  --purge-frontend-cache
```

## 2. Environment Deltas (AC-OPS-062)

| Property | Kind (dev) | RKE2 (staging) | GKE (production) |
|----------|-----------|----------------|-------------------|
| **Context** | `kind-dev` | `rke2-nonprod` | `gke_bbi-k8_...` |
| **Namespace** | `mereka-lms` | `mereka-lms` | `mereka-lms` |
| **Domain** | `*.localhost` | `*.staging.mereka.dev` (planned) | `*.academyv2.mereka.io` |
| **MySQL** | In-cluster PVC | In-cluster PVC | In-cluster PVC |
| **MongoDB** | Atlas (shared) | Atlas (separate DB) | Atlas (production) |
| **Redis** | In-cluster | In-cluster | In-cluster |
| **Secrets** | Manual / ConfigMap | ExternalSecrets (GCP SM) | ExternalSecrets (GCP SM, `bbi-k8` project) |
| **Images** | Local build or AR pull | AR pull | AR pull |
| **Ingress** | NGINX Ingress | NGINX Ingress | NGINX Ingress |
| **SSL** | Self-signed | Let's Encrypt (cert-manager) | Let's Encrypt (cert-manager) |
| **Kyverno** | Active (non-root, no-latest, limits) | Active | Not deployed |
| **Overlay** | `deploy/k8s/overlays/local/` | `infrastructure:apps/.../staging/` | `infrastructure:apps/.../prod/` |
| **Enterprise** | Scaled to 0 | TBD | Running (7 services) |
| **Release script flag** | `--target-env staging` | `--target-env staging` | `--target-env production` |

## 3. Cache Preservation Rules (AC-OPS-112)

### Docker Layer Cache

| Layer | Cache Key | Invalidation Trigger |
|-------|-----------|---------------------|
| Base image (`ubuntu:22.04`) | Docker layer hash | Ubuntu release or CVE |
| Python deps (`requirements/`) | requirements file hash | `pip install` changes |
| Node deps (`package.json`) | package-lock hash | `npm install` changes |
| Static assets (webpack) | Source file hash | Theme/MFE code changes |
| Tutor patches | `apply-patches.sh` hash | Patch file modification |

### `tutor_env` Image Reuse

The `tutor_env/` directory is gitignored. Docker images are cached locally:
- `docker.io/overhangio/openedx:latest` → local Tutor build output
- `docker.io/overhangio/openedx-mfe:latest` → local MFE build output

**Reuse rule**: If `canonical-release.sh --dry-run` shows "cache hit" for a tag, the AR image is identical — skip build.

**Invalidation rule**: Delete `var/build-cache/` and rebuild when:
- `apply-patches.sh` content changes
- `requirements/` files change
- Theme assets change
- Security advisory requires fresh base layers

### Expected Runtimes and Artifact Sizes (AC-OPS-114)

| Step | Duration | Artifact Size |
|------|----------|---------------|
| `tutor images build openedx` | 30-45 min | ~3.5 GB image |
| `tutor images build mfe` | 15-20 min | ~800 MB image |
| `docker push` (openedx) | 5-10 min | ~1.5 GB compressed |
| `docker push` (mfe) | 2-5 min | ~400 MB compressed |
| Tag update + commit | <1 min | N/A |
| ArgoCD sync | 2-5 min | N/A |
| Runtime convergence | 3-10 min | N/A |

## 4. Gate-by-Gate Matrix (AC-OPS-051)

| Gate | Name | Command | Expected Output | Abort If |
|------|------|---------|-----------------|----------|
| 0 | Preflight | `canonical-release.sh --check-only` | All OK | Any HARD FAIL |
| 1 | Build | `tutor images build openedx` | Exit 0 | OOM, build error |
| 2 | Tag | `docker tag ...` | Exit 0 | Wrong source image |
| 3 | Push | `docker push ...` | Exit 0 | 403 (re-auth) |
| 4 | Dry-run | `canonical-release.sh --dry-run` | Shows expected diffs | Unexpected files changed |
| 5 | Apply | `canonical-release.sh --apply --commit --push` | Both repos pushed | Merge conflict |
| 6 | Verify | `canonical-release.sh --verify-runtime` | Tag matches in cluster | Timeout (10min) |
| 7 | Smoke | `curl -sI` on all URLs | HTTP 200/302 | Any 502/503 |

### Rollback Criteria Per Gate (AC-OPS-052)

| Gate | Rollback Action | Recovery Time |
|------|----------------|---------------|
| 0-3 | No state changed; fix and retry | Immediate |
| 4 | `git checkout -- .` in both repos | Immediate |
| 5 | `git revert HEAD && git push` in both repos | <2 min |
| 6 | Same as 5; ArgoCD auto-reverts | <5 min |
| 7 | Same as 5; investigate root cause | <15 min |

## 5. Evidence Naming Convention (AC-OPS-053)

| Artifact Type | Path Pattern | Example |
|---------------|-------------|---------|
| Release evidence | `docs/evidence/operations/YYYY-MM-DD-<tag>.md` | `2026-02-18-mereka-brand.md` |
| Incident report | `docs/status/incidents/YYYY-MM-DD-<slug>.md` | `2026-02-18-cms-oom.md` |
| Dry-run log | PR body or `var/release-logs/` (gitignored) | Inline in PR |
| Recovery evidence | `docs/evidence/operations/*_EVIDENCE.md` | `GKE_WORKLOAD_TRIAGE_EVIDENCE.md` |

## 6. Dependency Map with Owner Handoff (AC-OPS-054)

| Artifact | Owner | Location | Handoff To |
|----------|-------|----------|------------|
| Base manifests | LMS team | `deploy/k8s/base/` | Platform team (via GitOps) |
| Production overlay | Platform team | `infrastructure:apps/.../prod/` | ArgoCD |
| Image tags | LMS team | `kustomization.yaml` (both repos) | ArgoCD |
| Secrets | Security team | GCP SM (`bbi-k8` project) | ExternalSecrets |
| DNS records | Platform team | Cloudflare | NGINX Ingress |
| SSL certs | cert-manager | Cluster-internal | NGINX Ingress |

## Related

- Architecture: `docs/adr/rfc/027-deployment-contract-ownership-lanes.md` — authoritative boundary: what stays vs moves to infra repo
- Architecture: `docs/reference/architecture/DEPLOYMENT_CONTRACT.md` — interface contract between app repo and GitOps repo
- Script: `scripts/infra/canonical-release.sh`
- Script: `scripts/infra/release-openedx-gitops.sh`
- Runbook: `docs/ops/runbooks/RELEASE_EXECUTE_RUNBOOK.md`
- Runbook: `docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`
- Handoff: `reports/2026/closures/RKE2_LMS_HANDOFF.md`
