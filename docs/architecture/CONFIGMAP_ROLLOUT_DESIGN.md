# ConfigMap Rollout Semantics — Design Decision

> Status: detailed-reference (proposed design)
> **Owner**: Lane C (Principal Orchestration)
> **Related**: AUTHORITY_MATRIX.md (debt inventory item)

## Problem

Overlays set `generatorOptions.disableNameSuffixHash: true`, creating stable-name
ConfigMaps. When their content changes in Git, Kubernetes does not trigger pod
rollouts because the Deployment spec still references the same ConfigMap name.

### Affected Stable-Name ConfigMaps

| ConfigMap | Overlay | Impact |
|-----------|---------|--------|
| `enterprise-mfe-env` | rke2-nonprod, local, staging | Enterprise MFE runtime config (JS) |
| `openedx-config` | rke2-nonprod, staging | LMS/CMS env vars |
| `openedx-mfe-mfeconfig-compat` | rke2-nonprod | MFE compat config |
| `promtail-config` | monitoring base | Log shipping config |

### Unaffected (Content-Hashed) ConfigMaps

These already trigger rollouts correctly:
`caddy-config-*`, `openedx-settings-lms-*`, `openedx-settings-cms-*`,
`enterprise-admin-portal-caddy-config-*`, `enterprise-learner-portal-caddy-config-*`,
`enterprise-access-settings-*`, etc.

## Options

### Option A: Remove `disableNameSuffixHash: true` (Recommended)

Remove the global `generatorOptions.disableNameSuffixHash: true` from overlay
kustomization files. This restores content-hashed names for all ConfigMaps.

**Pros**:
- Kustomize-native; no custom annotations or tooling
- All ConfigMap references auto-update (kustomize handles name propagation)
- Content changes automatically trigger rollouts
- Eliminates entire class of drift

**Cons**:
- First apply changes ALL ConfigMap names → ArgoCD sees mass diff
- Requires coordinated sync (one-time disruption)
- Any external references to stable ConfigMap names break

**Migration**: Single PR per overlay. ArgoCD sync replaces old ConfigMaps with
new hashed ones. Pods restart with new references. One-time event.

### Option B: Checksum Annotations on Pod Templates

Add `checksum/config: {{ sha256 of ConfigMap data }}` annotation to pod template
metadata. Kustomize doesn't natively support this; requires a custom transformer
or CI-time injection.

**Pros**: ConfigMap names stay stable
**Cons**: Requires custom tooling, not Kustomize-native

### Option C: Per-Generator Override

On specific generators that need rollout triggers, add:
```yaml
configMapGenerator:
  - name: enterprise-mfe-env
    behavior: replace
    options:
      disableNameSuffixHash: false  # Override global setting
```

**Pros**: Surgical, only affects specific ConfigMaps
**Cons**: Mixed naming convention (some stable, some hashed)

## Decision

**Option A** — remove `disableNameSuffixHash: true` from overlays.

Rationale: The setting was likely added for debugging convenience (predictable
names in `kubectl get`). The cost is that config changes silently don't propagate
to pods. Content-hashed names are the Kustomize default for good reason.

## Implementation Plan

1. PR per overlay (rke2-nonprod first, then staging, then local)
2. Remove `generatorOptions.disableNameSuffixHash: true`
3. Verify `kubectl kustomize` renders with hashed names
4. Verify all Deployment volumeMount references resolve
5. ArgoCD sync (one-time mass ConfigMap replacement)
6. Verify pods restart with new config

## Rollback

Re-add `disableNameSuffixHash: true`. ConfigMaps revert to stable names on next sync.
