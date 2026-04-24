# Stabilization: Authority and Rollout Plan

> Priority 1 — make runtime-affecting config changes deterministic and explainable.

## Problem

Every overlay sets `disableNameSuffixHash: true`. When config content changes, ConfigMaps
update in-place but pods keep running with stale config. ArgoCD shows "Synced" while the
live state diverges. This has caused real incidents.

## Critical Stable-Name Config Surfaces

| # | ConfigMap | Source | Pod Consumer | Impact if Stale |
|---|-----------|--------|-------------|-----------------|
| 1 | `caddy-config` | `base/apps/caddy/Caddyfile` | caddy | **HIGH** — routing wrong, portals unreachable |
| 2 | `openedx-config` (LMS settings) | `base/apps/openedx/settings/lms/*` | lms, lms-worker | **HIGH** — CSRF, JWT, ALLOWED_HOSTS stale |
| 3 | `openedx-config` (CMS settings) | `base/apps/openedx/settings/cms/*` | cms, cms-worker | **HIGH** — Studio auth/settings stale |
| 4 | `enterprise-mfe-env` | `base/apps/enterprise/mfe/enterprise-mfe-env.js` | enterprise-admin-portal, enterprise-learner-portal | **MEDIUM** — MFE URLs/config stale |
| 5 | `enterprise-admin-portal-caddy-config` | `base/apps/enterprise/mfe/admin-portal-Caddyfile` | enterprise-admin-portal | **MEDIUM** — portal routing wrong |
| 6 | `enterprise-learner-portal-caddy-config` | `base/apps/enterprise/mfe/learner-portal-Caddyfile` | enterprise-learner-portal | **MEDIUM** — portal routing wrong |
| 7 | `openedx-theme` | `base/apps/openedx/theme/*` | lms | **LOW** — theme stale (needs collectstatic too) |
| 8 | `mux-delivery-monitor-script` | monitoring | CronJob | **SKIP** — CronJobs get new pods each run |

### Overlays That Disable Hash Suffixes

| Overlay | File | Effect |
|---------|------|--------|
| `overlays/local/` | `kustomization.yaml` L14 | `disableNameSuffixHash: true` |
| `overlays/rke2-nonprod/` | `kustomization.yaml` L93 | `disableNameSuffixHash: true` |
| `overlays/staging/` | `kustomization.yaml` L80 | `disableNameSuffixHash: true` |

### bbi-infrastructure Overlays

| Overlay | File | Effect |
|---------|------|--------|
| `overlays/dev/` | `kustomization.yaml` | Replaces `enterprise-mfe-env` via `configMapGenerator` with `behavior: replace` |
| `overlays/profiles/dev/` | `patches/caddy-config-dev.yaml` | Strategic merge patch on caddy ConfigMap |

## Chosen Rollout Strategy

**Option A: Re-enable hash suffixes** — selected for all non-CronJob ConfigMaps.

### Why This Option

| Factor | Hash Suffixes | Checksum Annotations | ArgoCD Hooks |
|--------|--------------|---------------------|--------------|
| Automatic restart on config change | Yes | Yes | Yes |
| Kustomize-native | Yes | Needs transformer | No |
| ArgoCD compatible | Yes (with GC) | Yes | Needs RBAC |
| Complexity | Lowest | Medium | Highest |
| Risk | ConfigMap name changes | None | Job failure risk |

### Implementation Steps

#### Phase 1: mereka-lms repo (app-owned config)

| Step | File | Change |
|------|------|--------|
| 1a | `overlays/local/kustomization.yaml` | Remove `disableNameSuffixHash: true` |
| 1b | `overlays/rke2-nonprod/kustomization.yaml` | Remove `disableNameSuffixHash: true` |
| 1c | `overlays/staging/kustomization.yaml` | Remove `disableNameSuffixHash: true` |
| 1d | All Deployments | Verify volume references use kustomize-generated names (not hardcoded) |
| 1e | `base/monitoring/kustomization.yaml` | KEEP `disableNameSuffixHash: true` (CronJobs) |

#### Phase 2: bbi-infrastructure (infra-owned patches)

| Step | File | Change |
|------|------|--------|
| 2a | `overlays/dev/kustomization.yaml` | Ensure `configMapGenerator` entries work with hashed names |
| 2b | `overlays/profiles/dev/patches/caddy-config-dev.yaml` | Verify patch targets work with hash suffixes |
| 2c | Deployment patches | Remove any hardcoded ConfigMap name references in volume patches |

#### Phase 3: Verification

| Check | Command |
|-------|---------|
| Render test | `kubectl kustomize overlays/local/ \| grep configMap` — verify hashed names |
| No hardcoded refs | `grep -r 'configMap:' overlays/ \| grep -v kustomization` — none should exist |
| ArgoCD GC | Confirm `argocd.argoproj.io/compare-options: IgnoreExtraneous` not set on ConfigMaps |

### Rollout Truth Table

| Config Surface | Source File | Rendered Object | Pod Consumer | Rollout Trigger (After Fix) | Verify Live Uptake |
|---------------|-------------|-----------------|--------------|---------------------------|-------------------|
| Caddy routing | `apps/caddy/Caddyfile` | `caddy-config-<hash>` | caddy | Hash change → Deployment update → rolling restart | `kubectl exec caddy -- cat /etc/caddy/Caddyfile \| md5sum` |
| LMS settings | `apps/openedx/settings/lms/*` | `openedx-config-<hash>` | lms, workers | Hash change → rolling restart | `kubectl exec lms -- cat /openedx/config/lms/production.py \| md5sum` |
| CMS settings | `apps/openedx/settings/cms/*` | `openedx-config-<hash>` | cms, workers | Hash change → rolling restart | Same pattern |
| Enterprise MFE env | `enterprise/mfe/enterprise-mfe-env.js` | `enterprise-mfe-env-<hash>` | admin-portal, learner-portal | Hash change → rolling restart | `kubectl exec admin-portal -- cat /openedx/dist/env.config.js \| md5sum` |
| Enterprise Caddyfiles | `enterprise/mfe/*-Caddyfile` | `*-caddy-config-<hash>` | admin/learner portal | Hash change → rolling restart | Same |
| Theme | `apps/openedx/theme/*` | `openedx-theme-<hash>` | lms | Hash change → rolling restart (+ collectstatic needed) | Theme files present in container |

### Pre-Requisite Checks

Before implementing, verify no Deployment has hardcoded ConfigMap names:

```bash
# In mereka-lms repo:
grep -rn 'configMap:' deploy/k8s/base/ deploy/k8s/overlays/ | grep -v kustomization | grep -v '#'

# In bbi-infrastructure:
grep -rn 'configMap:' apps/mereka-lms/ | grep -v kustomization | grep -v '#'
```

Any match is a hardcoded reference that must be removed before hash suffixes work.

### First PR

**PR scope**: Remove `disableNameSuffixHash: true` from local overlay only (safest — no cluster impact until ArgoCD syncs).

**File**: `deploy/k8s/overlays/local/kustomization.yaml`

**Risk**: LOW — local overlay is not deployed to any live cluster.

**Follow-up PRs**:
1. `overlays/rke2-nonprod/` (dev cluster — verify ArgoCD handles it)
2. `overlays/staging/`
3. bbi-infrastructure overlay patches (coordinate with infra repo)

## Acceptance Criteria

- [ ] No critical runtime config remains in "content changed but pod didn't roll" limbo
- [ ] `kubectl kustomize` renders hashed ConfigMap names for all non-monitoring configs
- [ ] Deployment volume references are kustomize-managed (no hardcoded names)
- [ ] ArgoCD sync after config change causes pod restart within sync interval
- [ ] Rollout truth table matches live cluster behavior
