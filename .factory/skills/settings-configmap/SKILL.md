---
name: settings-configmap
description: Verify rendered Django settings, ConfigMaps, and Kustomize output. Use when changing LMS/CMS settings, debugging ConfigMap drift, or tracing the settings render path in Mereka LMS.
---

# Django Settings / ConfigMap Verification

## Render Path

```
Source settings (mereka_lms.py plugin)
  → Tutor render (scripts/infra/tutor-config-save.sh)
    → Build-context preparation (scripts/infra/prepare-tutor-build-context.sh)
    → Kustomize build (deploy/k8s/base + overlays)
      → Argo realization (bbi-infrastructure)
        → Live ConfigMap (mounted in pods)
          → Runtime behavior
```

## Where Settings Live

| Setting type | Source file | Rendered artifact |
|---|---|---|
| LMS production settings | `infrastructure/tutor/plugins/mereka_lms.py` | `tutor_env/env/apps/openedx/settings/lms/production.py` |
| CMS production settings | `infrastructure/tutor/plugins/mereka_lms.py` | `tutor_env/env/apps/openedx/settings/cms/production.py` |
| CSRF/allowed hosts | `infrastructure/tutor/plugins/mereka_lms.py` + governed Tutor config | rendered settings + Caddyfile |
| Multi-tenant domains | `deploy/k8s/tenancy/tenant-registry.yaml` | Caddyfile + settings |
| K8s ConfigMaps | `deploy/k8s/base/apps/` | Kustomize-rendered ConfigMaps |

## Steps for Settings Change

1. Edit source: `infrastructure/tutor/plugins/mereka_lms.py`
2. Render: `./scripts/infra/tutor-config-save.sh`
3. Verify rendered output: check `tutor_env/env/apps/openedx/settings/lms/production.py`
4. Verify Kustomize: `kubectl kustomize deploy/k8s/base/ | grep YOUR_SETTING`
5. Commit and push
6. After Argo realization: verify live ConfigMap matches
7. Verify runtime behavior

## Verification Commands

```bash
# Check rendered settings
grep 'YOUR_SETTING' tutor_env/env/apps/openedx/settings/lms/production.py

# Check Kustomize output
kubectl kustomize deploy/k8s/base/ 2>/dev/null | grep 'YOUR_SETTING'

# Check live ConfigMap (after deployment)
kubectl get configmap -n mereka-lms-dev openedx-settings-lms -o yaml | grep 'YOUR_SETTING'

# Check pod sees it
kubectl exec -n mereka-lms-dev deploy/lms -- python -c "from django.conf import settings; print(settings.YOUR_SETTING)"
```

## Never Do

- Edit rendered settings in `tutor_env/` without fixing `mereka_lms.py`
- Edit live ConfigMap via `kubectl edit` (will be overwritten by Argo)
- Confuse local Docker service names with K8s DNS names
- Bypass the governed Tutor wrapper or build-context preparation path
- Assume local config matches cloud config (different DB hosts, service names)

## Common Pitfall: Cloud IPs in Local Config

If `MYSQL_HOST: "10.97.0.2"` appears in local config:
```bash
./scripts/infra/tutor-config-save.sh --set MYSQL_HOST=mysql --set MONGODB_HOST=mongodb --set REDIS_HOST=redis
```

## Required Companions

> Source: `config/skills-graph.yaml`

- **Requires**: `layer-triage`, `cross-repo-authority`
- **Recommended**: `runtime-proof`

## References

- [DJANGO_SETTINGS_CHANGE.md](docs/ops/playbooks/DJANGO_SETTINGS_CHANGE.md)
- [PLATFORM_AUTHORITY_MAP.md](docs/architecture/PLATFORM_AUTHORITY_MAP.md)
