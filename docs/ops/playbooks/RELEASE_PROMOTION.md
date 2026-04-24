# Release Promotion Playbook

_Audience: Operators · Owner: Platform Team · Status: active_

## Layer Ownership

| Layer | Owner | Artifact |
|---|---|---|
| **Build** | CI (`build-tutor-images.yml`) | OCI image at `ghcr.io/biji-biji-initiative/mereka-lms` |
| **Release object** | Release workflow (`.github/workflows/release.yml`) | Git tag + evidence bundle |
| **Promotion** | GitOps (`bbi-infrastructure`) | Image tag in overlay → ArgoCD Application |
| **Realization** | ArgoCD | Synced pods running promoted image |
| **Runtime proof** | Smoke scripts + evidence bundle | `scripts/qa/verify-post-deploy-smoke.sh`, release evidence |
| **Truth ledger** | App repo | `docs/status/active/`, evidence artifacts |

## Before You Start

- [ ] `git status` — app repo worktree is clean, on `main`
- [ ] CI is green on `main` — all static-validation and security jobs pass
- [ ] Image is built and pushed: check `ghcr.io/biji-biji-initiative/mereka-lms` for expected tag
- [ ] Release object exists — `.github/workflows/release.yml` has been run or triggered
- [ ] You have access to the GitOps repo (`bbi-infrastructure`)
- [ ] Target environment is healthy: `kubectl get pods -n <namespace>` shows all Running
- [ ] Smoke accounts are functional (see `docs/status/active/SMOKE_ACCOUNT_REGISTRY_*.md`)

## Steps

### 1. Generate evidence bundle

```bash
# Trigger the release evidence workflow (or run locally)
# .github/workflows/release-evidence-bundle.yml with:
#   openedx_tag: <image-tag>
#   mfe_tag: <mfe-image-tag>
#   target_environment: dev|staging|production
```

### 2. Verify release object

```bash
# Confirm the release tag and evidence exist
gh release view <tag> --repo biji-biji-initiative/mereka-lms
# Check evidence bundle artifacts
./scripts/qa/verify-release-bundle.sh
./scripts/qa/verify-build-provenance.sh
```

### 3. Promote image tag in GitOps repo

```bash
# In bbi-infrastructure repo:
# Update the image tag in the target overlay
# Example: overlays/rke2-nonprod/kustomization.yaml
#   images:
#     - name: ghcr.io/biji-biji-initiative/mereka-lms/openedx
#       newTag: <release-tag>
git add .
git commit -m "promote(mereka-lms): <tag> to <environment>"
git push origin HEAD
```

### 4. Wait for ArgoCD sync

```bash
# Monitor ArgoCD application status
# ArgoCD detects image tag change → triggers sync → rolls pods
# Watch pod rollout
kubectl rollout status deployment/lms -n <namespace> --timeout=300s
kubectl rollout status deployment/cms -n <namespace> --timeout=300s
kubectl rollout status deployment/mfe -n <namespace> --timeout=300s
```

### 5. Run post-deploy verification

```bash
# Run smoke tests against the target environment
./scripts/qa/verify-post-deploy-smoke.sh
./scripts/qa/verify-mfe-route-smoke.sh
./scripts/qa/verify-service-endpoints.sh
./scripts/qa/verify-rke2-tenant-routes.sh

# Verify running image matches promoted tag
kubectl get pods -n <namespace> -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u
```

### 6. Record in truth ledger

```bash
# After runtime proof passes, record the promotion
# Update or create evidence doc in docs/status/active/
# Include: tag, environment, timestamp, proof summary
```

## Promotion Path

```
dev → staging → production
```

Each hop requires:
1. Release object from previous environment's runtime proof
2. Evidence bundle generation
3. Image tag update in GitOps overlay
4. ArgoCD sync + pod rollout
5. Runtime proof in new environment
6. Truth ledger entry

## Verify

1. **Release object proof**: `gh release view <tag>` shows expected artifacts
2. **Image proof**: `kubectl get pods -o jsonpath='{..image}'` matches promoted tag
3. **Pod proof**: all pods are `Running` and `Ready`
4. **Endpoint proof**: `curl -sI https://academyv2.mereka.io/` returns 200
5. **Smoke proof**: `verify-post-deploy-smoke.sh` exits 0
6. **Evidence proof**: release evidence bundle is complete and attached to release

## Never Do

- **Never manually join a SHA to an overlay** — use the release object to determine the promoted tag
- **Never promote without a release object** — no tag, no promotion
- **Never skip runtime proof** — a synced pod ≠ a working service
- **Never call a fix "live" after merge without proved runtime truth** — merge ≠ deployed ≠ verified
- **Never promote from a dirty worktree** — `git status` must be clean
- **Never promote to production without staging proof** — follow `dev → staging → production` path
- **Never rerun runtime proof against a known-bad live bundle** — fix first, then prove

## Rollback

### GitOps rollback (preferred)

```bash
# In bbi-infrastructure: revert the image tag commit
git revert <promotion-commit-sha>
git push origin HEAD
# ArgoCD syncs back to previous image → pods roll back
```

### ArgoCD history rollback

```bash
# Use ArgoCD UI: Applications → mereka-lms → History → select previous revision → Rollback
# Or CLI:
argocd app rollback mereka-lms --revision <previous-revision>
```

### Emergency scale-down

```bash
# If new version is actively harmful, scale to zero immediately
kubectl scale deployment/lms -n <namespace> --replicas=0
kubectl scale deployment/cms -n <namespace> --replicas=0
# Investigate, then restore from known-good image via GitOps revert
```
