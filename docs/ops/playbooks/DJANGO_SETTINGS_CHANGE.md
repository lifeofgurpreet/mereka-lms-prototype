# Django Settings Change Playbook

_Audience: Developers, Operators · Owner: Platform Team · Status: active_

## Layer Ownership

| Layer | Owner | Artifact |
|---|---|---|
| **Source** | App repo (`mereka-lms`) | `infrastructure/tutor/plugins/mereka_lms.py` |
| **Build/Render** | Tutor config save | `tutor_env/env/apps/openedx/settings/` (generated) |
| **Promotion** | Kustomize overlays | `deploy/k8s/base/apps/`, `deploy/k8s/overlays/*/` |
| **Realization** | ArgoCD | ConfigMap → Pod mount → Django reads settings |
| **Runtime proof** | Django shell + smoke scripts | `scripts/qa/verify-*.sh`, live endpoint checks |

## Before You Start

- [ ] `git status` — worktree is clean on a feature branch off `main`
- [ ] Identify setting scope: LMS only, CMS only, or both
- [ ] Identify setting type: Tutor plugin variable, ConfigMap patch, or overlay-specific
- [ ] `export TUTOR_ROOT="$(pwd)/tutor_env"`
- [ ] Know if this is a **local Docker** change or **K8s** change — they have different paths

## Steps

### 1. Edit source

**For Tutor plugin settings (most common):**

```bash
vim infrastructure/tutor/plugins/mereka_lms.py
# Add/modify settings in the appropriate hook:
#   - lms.env.features / cms.env.features (feature flags)
#   - lms.env.common / cms.env.common (settings)
#   - OPENEDX_EXTRA_PIP_REQUIREMENTS (packages)
```

**For Kustomize ConfigMap patches (K8s-specific overrides):**

```bash
vim deploy/k8s/base/apps/lms/configmap.yaml    # LMS settings
vim deploy/k8s/base/apps/cms/configmap.yaml    # CMS settings
```

**For overlay-specific settings (per-environment):**

```bash
vim deploy/k8s/overlays/rke2-nonprod/patches/  # Dev overrides
vim deploy/k8s/overlays/production/patches/     # Prod overrides
```

### 2. Render and verify locally

```bash
# Regenerate Tutor config with patches
./scripts/infra/tutor-config-save.sh
./scripts/infra/verify-tutor-config.sh

# Verify the setting landed in rendered output
grep -r "YOUR_SETTING" tutor_env/env/apps/openedx/settings/

# For local Docker testing
tutor local restart lms
tutor local logs --tail=50 lms
```

### 3. Verify setting is active (local)

```bash
# Django shell check
tutor local run lms ./manage.py lms shell -c \
  "from django.conf import settings; print(settings.YOUR_SETTING)"

# Or for feature flags
tutor local run lms ./manage.py lms shell -c \
  "from django.conf import settings; print(settings.FEATURES.get('YOUR_FLAG'))"
```

### 4. Verify Kustomize renders correctly (K8s path)

```bash
# Render the overlay and inspect
kubectl kustomize deploy/k8s/overlays/rke2-nonprod/ | grep -A5 "YOUR_SETTING"
# OR
./scripts/qa/verify-kustomize-render.sh
```

### 5. Push and wait for ArgoCD sync

```bash
git add -A
git commit -m "fix(settings): <describe change>"
git push origin HEAD
# After merge → ArgoCD detects ConfigMap change → rolls pods
```

### 6. Verify in target environment

```bash
# Check ConfigMap is updated
kubectl get configmap -n mereka-lms-dev -o yaml | grep "YOUR_SETTING"
# Check pods restarted with new config
kubectl get pods -n mereka-lms-dev -l app.kubernetes.io/name=lms
# Run relevant smoke tests
./scripts/qa/verify-tutor-config-safety.sh
```

## Verify

1. **Render proof**: `grep` confirms setting in `tutor_env/env/apps/openedx/settings/lms/production.py`
2. **Kustomize proof**: `kubectl kustomize` output contains the setting
3. **ConfigMap proof**: `kubectl get configmap` in target namespace shows updated value
4. **Runtime proof**: Django shell confirms `settings.YOUR_SETTING` returns expected value
5. **Endpoint proof**: Affected endpoint behaves correctly (e.g., CORS, CSRF, auth flow)
6. **Smoke proof**: relevant `scripts/qa/verify-*.sh` exits 0

## Never Do

- **Never edit rendered ConfigMap in-cluster** (`kubectl edit configmap`) — it will be overwritten by ArgoCD
- **Never edit `tutor_env/` generated files** — they are overwritten on next `tutor config save`
- **Never confuse local Docker settings with K8s settings** — local uses `tutor_env/`, K8s uses ConfigMaps from overlays
- **Never skip the governed Tutor refresh path** — use `tutor-config-save.sh` for config changes or `prepare-tutor-build-context.sh --target ...` for manual post-render refresh
- **Never add secrets as Django settings** — use environment variables via ExternalSecrets
- **Never assume a merged PR means the setting is live** — verify ConfigMap + pod restart + runtime check

## Rollback

### ConfigMap rollback (ArgoCD)

```bash
# Revert the commit in the app repo or GitOps overlay
git revert <commit-sha>
git push origin HEAD
# ArgoCD syncs reverted ConfigMap → pods restart
```

### Emergency pod restart

```bash
# Force pods to re-read ConfigMap
kubectl rollout restart deployment/lms -n mereka-lms-dev
kubectl rollout status deployment/lms -n mereka-lms-dev
```

### Emergency setting override (temporary — never permanent)

```bash
# Set env var on deployment (overrides ConfigMap setting)
kubectl set env deployment/lms -n mereka-lms-dev YOUR_SETTING=old_value
# MUST be followed by proper source fix and removal of override
```
