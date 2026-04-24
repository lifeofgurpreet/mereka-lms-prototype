# Stable Config Rollout Debt

> Documents where ConfigMap/Secret stable-name patterns exist, why they are dangerous,
> and the recommended fix for each class.
>
> **Purpose**: Make the debt explicit and implementation-ready so it can be fixed
> in a future PR without discovery overhead.

## The Problem

Kustomize `configMapGenerator` can produce ConfigMap names with content-hash suffixes
(e.g., `caddy-config-k8f5t2h`) or stable names (with `disableNameSuffixHash: true`).

**Hashed names** are safe: when config content changes, a new ConfigMap name is generated,
and Deployments that reference it get a rolling update automatically.

**Stable names** are dangerous: when config content changes, the ConfigMap is updated
in-place, but Deployments referencing it do NOT restart. Pods continue running with
the OLD config until manually restarted.

## Current State

### Base kustomization (`deploy/k8s/base/kustomization.yaml`)

**Does NOT set `disableNameSuffixHash`** — generates hashed names by default.

ConfigMaps generated:
| ConfigMap | Source | Used by |
|-----------|--------|---------|
| `caddy-config` | `apps/caddy/Caddyfile` | Caddy deployment |
| `openedx-config` | `apps/openedx/settings/**` | LMS, CMS deployments |
| `openedx-theme` | `apps/openedx/theme/**` | LMS deployment |

These would get hashed names, but...

### Overlays override to stable names

Every overlay sets `disableNameSuffixHash: true`:

| Overlay | File | Line |
|---------|------|------|
| `overlays/local/` | `kustomization.yaml` | L14 |
| `overlays/rke2-nonprod/` | `kustomization.yaml` | L93 |
| `overlays/staging/` | `kustomization.yaml` | L80 |

**Result**: All ConfigMaps in all environments use stable names. Config changes
do NOT trigger pod restarts.

### Enterprise MFE ConfigMaps

| ConfigMap | Source | Generator | Hash disabled? |
|-----------|--------|-----------|---------------|
| `enterprise-admin-portal-caddy-config` | `admin-portal-Caddyfile` | base enterprise MFE kustomization | No (base doesn't disable) |
| `enterprise-learner-portal-caddy-config` | `learner-portal-Caddyfile` | base enterprise MFE kustomization | No |
| `enterprise-mfe-env` | `enterprise-mfe-env.js` | base enterprise MFE kustomization | No |

BUT: overlays replace `enterprise-mfe-env` with `behavior: replace` AND have
`disableNameSuffixHash: true` at the overlay level. So the overlay's `generatorOptions`
wins — stable names for enterprise MFE too.

### Monitoring ConfigMaps

| ConfigMap | Source | Hash disabled? |
|-----------|--------|---------------|
| `mux-delivery-monitor-script` | `mux_delivery_monitor.py` | Yes (monitoring kustomization sets it) |

## Specific Danger Points

### 1. Caddy config changes don't restart Caddy

**Impact**: HIGH. Caddy routing changes (new domains, new backends, route ordering)
are invisible until someone manually restarts the Caddy deployment.

**Past incident**: Enterprise admin portal API routing was wrong. Config was updated
in git but Caddy kept serving stale routes until manual restart.

**Affected ConfigMap**: `caddy-config`
**Affected Deployment**: `caddy`

### 2. OpenEdX settings changes don't restart LMS/CMS

**Impact**: HIGH. Django settings (ALLOWED_HOSTS, CSRF_TRUSTED_ORIGINS, JWT config,
enterprise integration settings) are invisible until pod restart.

**Affected ConfigMap**: `openedx-config`
**Affected Deployments**: `lms`, `cms`, all workers

### 3. Enterprise MFE env.config.js changes don't restart MFE pods

**Impact**: MEDIUM. Enterprise portal URL configuration, branding, and feature flags
stay stale until restart. This was a contributing factor to the current runtime confusion.

**Affected ConfigMap**: `enterprise-mfe-env`
**Affected Deployments**: `enterprise-admin-portal`, `enterprise-learner-portal`

### 4. Theme changes don't restart LMS

**Impact**: LOW-MEDIUM. Theme HTML/CSS changes require collectstatic + pod restart.
ConfigMap update alone is insufficient (Django caches the staticfiles manifest).

**Affected ConfigMap**: `openedx-theme`
**Affected Deployment**: `lms`

## Why This Matters for ArgoCD

ArgoCD syncs manifests to the cluster. When a ConfigMap's content changes but its
name stays the same:

1. ArgoCD updates the ConfigMap (content changes, metadata stays same)
2. ArgoCD sees the Deployment as "in sync" (nothing changed in the Deployment spec)
3. Pods keep running with old config
4. Operator sees "Synced" in ArgoCD but the running state is stale

The divergence between "rendered truth" (what ArgoCD applied) and "live mounted truth"
(what pods are actually serving) is invisible and creates debugging nightmares.

## Recommended Fixes

### Option A: Re-enable hash suffixes (Recommended)

Remove `disableNameSuffixHash: true` from all overlays. Let Kustomize generate
content-hashed names. When config changes, the Deployment's volume reference
changes → automatic rolling update.

**Pros**: Zero-effort rollout on config change. ArgoCD sync = live truth.
**Cons**: ConfigMap names are less readable. Old ConfigMaps need garbage collection.

**Implementation**:
1. Remove `generatorOptions.disableNameSuffixHash: true` from all overlays
2. Verify all Deployment volume references use the generated name (not hardcoded)
3. Test with `kubectl kustomize` to confirm name generation
4. Deploy and verify rolling update on next config change

### Option B: Checksum annotations

Add a pod template annotation with the ConfigMap content hash:
```yaml
spec:
  template:
    metadata:
      annotations:
        checksum/caddy-config: {{ sha256sum of Caddyfile }}
        checksum/openedx-config: {{ sha256sum of settings }}
```

**Pros**: Stable names preserved. Explicit restart trigger.
**Cons**: Requires a mechanism to compute and inject checksums. Kustomize doesn't
natively support this. Would need a custom transformer or Helm-style templating.

### Option C: Explicit rollout hooks

Use ArgoCD resource hooks or a post-sync hook to restart deployments when
specific ConfigMaps change:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
spec:
  template:
    spec:
      containers:
      - name: restart
        command: ["kubectl", "rollout", "restart", "deployment/caddy"]
```

**Pros**: Fine-grained control. Works with stable names.
**Cons**: More moving parts. Job must have RBAC to restart deployments.

### Recommendation

**Use Option A (hash suffixes) for all ConfigMaps** except monitoring.

Monitoring ConfigMaps (`mux-delivery-monitor-script`) can stay stable-named because
they are consumed by CronJobs, not long-running Deployments.

## Implementation Checklist (Future PR)

- [ ] Remove `generatorOptions.disableNameSuffixHash: true` from `overlays/local/kustomization.yaml`
- [ ] Remove `generatorOptions.disableNameSuffixHash: true` from `overlays/rke2-nonprod/kustomization.yaml`
- [ ] Remove `generatorOptions.disableNameSuffixHash: true` from `overlays/staging/kustomization.yaml`
- [ ] Keep `disableNameSuffixHash: true` in `base/monitoring/kustomization.yaml` (CronJobs)
- [ ] Verify no Deployment has hardcoded ConfigMap names in volume references
- [ ] Verify ArgoCD handles the name change gracefully (old ConfigMaps cleaned up)
- [ ] Test: change Caddyfile content → verify Caddy pods restart automatically
- [ ] Test: change LMS settings → verify LMS pods restart automatically
- [ ] Document in CONTRACTS.md: "ConfigMaps use content-hashed names"

## Do NOT implement in this lane

This document captures the debt and makes it implementation-ready.
The actual fix requires coordination with ArgoCD sync and should be done
as a standalone PR after the runtime blocker is resolved.
