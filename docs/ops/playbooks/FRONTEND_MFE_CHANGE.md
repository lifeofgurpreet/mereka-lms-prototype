# Frontend MFE Change Playbook

_Audience: Developers, Operators · Owner: Platform Team · Status: active_

## Layer Ownership

| Layer | Owner | Artifact |
|---|---|---|
| **Source** | App repo (`mereka-lms`) | `infrastructure/tutor/plugins/mereka_lms.py`, MFE source patches |
| **Build/Render** | Tutor image build | `tutor images build mfe` → `ghcr.io/biji-biji-initiative/mereka-lms` |
| **Promotion** | Release workflow | `.github/workflows/release.yml` → release object |
| **Realization** | ArgoCD + Kustomize | `deploy/k8s/overlays/*/kustomization.yaml` → pod image tag |
| **Runtime proof** | Smoke scripts + browser canary | `scripts/qa/verify-mfe-*.sh`, live DOM inspection |

## Before You Start

- [ ] `git status` — worktree is clean on a feature branch off `main`
- [ ] Understand which MFE is affected (authn, learning, profile, account, etc.)
- [ ] Read `docs/adr/021-openedx-tutor-methodology.md` — customization via plugin API only
- [ ] Confirm Docker has ≥12 GB RAM allocated
- [ ] `export TUTOR_ROOT="$(pwd)/tutor_env"`
- [ ] Know the target: plugin slot, `env.config.jsx` injection, `@edx/brand`, or design token

## Steps

### 1. Edit source (plugin)

```bash
# All MFE customization goes through the Tutor plugin
vim infrastructure/tutor/plugins/mereka_lms.py
```

Common injection points inside the plugin:
- **Plugin Slots**: `PLUGIN_SLOTS` configuration in plugin hooks
- **env.config.jsx**: `MFE_CONFIG` overrides via Tutor hooks (not Dockerfile-level edits)
- **Brand package**: `@edx/brand` overrides via `infrastructure/tutor/patches/brand-package.sh` (debt — migrating)
- **Design tokens**: Paragon token overrides in brand package

### 2. Render and build locally

```bash
# Regenerate Tutor environment from plugin
./scripts/infra/tutor-config-save.sh
# Verify patches applied
./scripts/infra/verify-tutor-config.sh
# Build the MFE image locally
tutor images build mfe
```

### 3. Verify local build

```bash
tutor local start -d
# Wait for MFE container to be healthy
tutor local logs --tail=50 mfe
# Test in browser
curl -sI http://apps.localhost/authn/login | head -5
```

### 4. Push and promote

```bash
git add infrastructure/tutor/plugins/mereka_lms.py
git commit -m "feat(mfe): <describe change>"
git push origin HEAD
# CI builds image; release workflow creates release object
# Do NOT manually join SHA to overlay — use release object
```

### 5. Verify in target environment

```bash
# After ArgoCD syncs the new image tag
kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=mfe
kubectl logs -n mereka-lms-dev -l app.kubernetes.io/name=mfe --tail=20
# Run MFE smoke verification
./scripts/qa/verify-mfe-route-smoke.sh
./scripts/qa/verify-mfe-branding.sh
./scripts/qa/verify-mfe-runtime-config.sh
```

## Verify

1. **Build proof**: CI workflow green; image pushed to `ghcr.io`
2. **Render proof**: `tutor config save` + `verify-tutor-config.sh` passes
3. **Route proof**: MFE routes return 200: `curl -sI https://apps.academyv2.mereka.io/authn/login`
4. **Asset proof**: Browser DevTools → Network tab → confirm JS/CSS bundles are served from new build
5. **DOM proof**: Inspect rendered DOM for expected plugin slot content or brand change
6. **Smoke proof**: `./scripts/qa/verify-mfe-route-smoke.sh` exits 0

## Never Do

- **Never edit `tutor_env/` files directly** — they are regenerated on every `tutor config save`
- **Never patch the generated MFE Dockerfile** without fixing the generator (`mereka_lms.py`)
- **Never trust build success as proof of served asset** — a built image ≠ a deployed image
- **Never edit `env.config.jsx` at Dockerfile level** — use plugin hooks in `mereka_lms.py`
- **Never skip `prepare-tutor-build-context.sh --target mfe`** after `tutor config save` — it is the governed wrapper that refreshes the rendered MFE build context and runs the bounded patch helper path
- **Never promote without a release object** — no manual SHA joins in overlays

## Rollback

### Image rollback (fast)

```bash
# In bbi-infrastructure GitOps repo, revert the image tag in the overlay
# ArgoCD will sync back to the previous image
# OR: use ArgoCD UI to roll back to previous revision
```

### Source rollback

```bash
git revert <commit-sha>
git push origin HEAD
# Let CI rebuild and release workflow promote the reverted image
```

### Emergency (pod-level)

```bash
# Scale down broken MFE, Caddy will serve fallback or cached version
kubectl scale deployment mfe -n mereka-lms-dev --replicas=0
# Investigate, then restore
kubectl scale deployment mfe -n mereka-lms-dev --replicas=1
```
