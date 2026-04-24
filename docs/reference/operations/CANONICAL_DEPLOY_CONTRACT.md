# Canonical Deploy Contract

> **Beads**: mereka-lms-36va.5, mereka-lms-36va.2, mereka-lms-36va.1
> **Date**: 2026-02-18
> **Canonical source**: this repository on `main`

## 1. Canonical Command Chain (AC-OPS-111, AC-OPS-061)

### Single Source of Truth

All builds and releases MUST originate from:
- **Repository**: `mereka-lms`
- **Branch**: `main`
- **Worktree**: a clean worktree rooted at this repository
- **Validation**: `./scripts/infra/canonical-release.sh --check-only`
- **Publish path**: a successful `.github/workflows/build-tutor-images.yml` run for the target SHA
- **Release inputs**: the workflow-emitted immutable tags/digests plus the `release-bundle` and `build-provenance` artifacts

### Publish → GitOps Flow

```bash
# 0. Preflight (AC-OPS-113, AC-OPS-063)
./scripts/infra/canonical-release.sh --check-only

# 1. Publish images for the merged target SHA.
# Preferred: use the push-to-main run emitted by the merge itself.
# Deterministic rebuilds may use workflow_dispatch on main with an explicit image_tag.
APP_SHA="$(git rev-parse origin/main)"
gh workflow run build-tutor-images.yml \
  --ref main \
  -f build_openedx=true \
  -f build_mfe=true \
  -f update_gitops=false \
  -f target_environment=production \
  -f image_tag="${APP_SHA}"

# 2. Wait for the successful run, then download the canonical release artifacts.
RUN_ID="<build-tutor-images run id>"
gh run watch "${RUN_ID}"
gh run download "${RUN_ID}" --name release-bundle --dir "var/release-artifacts/${RUN_ID}"
gh run download "${RUN_ID}" --name build-provenance --dir "var/release-artifacts/${RUN_ID}"

# 3. Use the immutable tags/digests emitted by the workflow summary/artifacts.
OPENEDX_TAG="${APP_SHA}"
MFE_TAG="${APP_SHA}"
OPENEDX_DIGEST="sha256:<openedx_digest>"
MFE_DIGEST="sha256:<mfe_digest>"

# 4. Preview the GitOps rollout from those exact release coordinates.
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --openedx-digest "${OPENEDX_DIGEST}" \
  --mfe-digest "${MFE_DIGEST}" \
  --require-digests

# 5. Apply + commit + push the GitOps rollout
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "${OPENEDX_TAG}" --mfe-tag "${MFE_TAG}" \
  --openedx-digest "${OPENEDX_DIGEST}" --mfe-digest "${MFE_DIGEST}" \
  --require-digests --apply --commit --push --verify-runtime

# 5b. Branding/theme release (optional): include frontend cache purge
# Requires Cloudflare credentials in env.
./scripts/infra/release-openedx-gitops.sh \
  --openedx-tag "${OPENEDX_TAG}" --mfe-tag "${MFE_TAG}" \
  --openedx-digest "${OPENEDX_DIGEST}" --mfe-digest "${MFE_DIGEST}" \
  --require-digests --apply --commit --push --verify-runtime \
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

### Local Tutor Builds Are Debug-Only

The `tutor_env/` directory is gitignored and local Tutor builds may still be used for reproduction, cache debugging, or kind parity work.

Production release truth does **not** come from local `docker.io/overhangio/*` tags. It comes from the successful `build-tutor-images.yml` workflow run, the pushed GHCR digests it resolves, and the signed release artifacts it emits.

**Reuse rule**: If the successful workflow run already produced the exact immutable tag/digest pair required for the rollout, skip rebuilding and reuse that published release coordinate.

**Invalidation rule**: Delete `var/build-cache/` and rebuild when:
- `apply-patches.sh` content changes
- `requirements/` files change
- Theme assets change
- Security advisory requires fresh base layers

### Expected Runtimes and Artifact Sizes (AC-OPS-114)

| Step | Duration | Artifact Size |
|------|----------|---------------|
| `Build Tutor Images` / `Build OpenEdX Image` job | 30-45 min | ~3.5 GB image |
| `Build Tutor Images` / `Build MFE Image` job | 15-20 min | ~800 MB image |
| Release bundle + provenance emission | <5 min | small JSON artifacts |
| GitOps update + commit | <5 min | N/A |
| ArgoCD sync | 2-5 min | N/A |
| Runtime convergence | 3-10 min | N/A |

## 4. Gate-by-Gate Matrix (AC-OPS-051)

| Gate | Name | Command | Expected Output | Abort If |
|------|------|---------|-----------------|----------|
| 0 | Preflight | `canonical-release.sh --check-only` | All OK | Any HARD FAIL |
| 1 | Publish | `gh workflow run build-tutor-images.yml ...` | Successful image-build run for target SHA | Build failure, digest missing |
| 2 | Artifact capture | `gh run download <run-id> --name release-bundle` | Release bundle + provenance downloaded | Bundle missing or inconsistent |
| 3 | Dry-run | `release-openedx-gitops.sh --openedx-tag ... --mfe-tag ... --openedx-digest ... --mfe-digest ... --require-digests` | Shows expected diffs | Unexpected files changed |
| 4 | Apply | `release-openedx-gitops.sh ... --apply --commit --push` | Both repos pushed | Merge conflict, push rejected |
| 5 | Verify | `release-openedx-gitops.sh ... --verify-runtime` | Tag matches in cluster | Timeout (10min) |
| 6 | Smoke | `curl -sI` on all URLs | HTTP 200/302 | Any 502/503 |

### Rollback Criteria Per Gate (AC-OPS-052)

| Gate | Rollback Action | Recovery Time |
|------|----------------|---------------|
| 0-3 | No state changed; fix and retry | Immediate |
| 4 | `git revert HEAD && git push` in both repos | <2 min |
| 5 | Same as 4; ArgoCD auto-reverts | <5 min |
| 6 | Same as 4; investigate root cause | <15 min |

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
