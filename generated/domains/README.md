# Generated Domain Artifacts

Generated from `deploy/k8s/tenancy/tenant-registry.yaml` — the canonical host-intent source.

**Regenerate:** `make domains-generate`
**Verify freshness:** `make domains-check`

## Files per Environment

| File | Purpose | Infra counterpart |
|------|---------|-------------------|
| `domain-env.yaml` | Per-deployment env vars (lms, cms, workers, caddy, mfe, satellites) | Split across caddy-env-patch + satellite-services-domain in bbi-infrastructure |
| `caddy-env-patch.yaml` | Caddy Deployment env vars (9 host vars) | `overlays/{env}/patches/caddy-env-patch.yaml` |
| `lms-env-patch.yaml` | openedx-config ConfigMap patch (LMS_HOST, CMS_HOST, etc.) | `overlays/{env}/patches/lms-env-patch.yaml` |
| `mfe-env-patch.yaml` | MFE Deployment env vars (CSP hosts) | `overlays/{env}/patches/mfe-env-patch.yaml` |
| `config-domains.sh` | Shell exports for all environments | Lines 36-46 of `scripts/shared/config.sh` (sources this file) |

## Workflow

1. Edit `deploy/k8s/tenancy/tenant-registry.yaml`
2. Run `make domains-generate`
3. Commit both the registry change and regenerated output
4. For bbi-infrastructure: copy the relevant per-env files to the overlay patches

## Parity Verification

bbi-infrastructure has a parity script that compares its hand-maintained patches
against these generated files:

```bash
# In bbi-infrastructure repo:
bash scripts/qa/verify-domain-consumer-parity.sh
```

## Authority Chain

```
tenant-registry.yaml (canonical host intent)
  → generated/domains/ (deterministic output)
    → bbi-infrastructure overlays (consumer, should match)
      → ArgoCD → live cluster
```

The generated files are committed and deterministic. Runtime-dependent outputs
(domain-runtime-audit) are gitignored.
