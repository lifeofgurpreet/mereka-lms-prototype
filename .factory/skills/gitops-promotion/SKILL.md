---
name: gitops-promotion
description: Promote a build through dev, staging, production via release objects and ArgoCD. Use when deploying changes, promoting images, or verifying Argo realization in Mereka LMS.
---

# GitOps Promotion

## Layer Ownership

Build → Release object → Promotion → Argo realization → Runtime proof → Truth ledger

## Four Truths (never collapse)

| Truth type | Meaning | Example |
|---|---|---|
| Branch truth | Fix exists on branch | PR diff |
| Merged truth | Fix merged to main | Merged commit SHA |
| Realized truth | Fix applied live | Argo sync + live image/config hash |
| Proved truth | User-visible behavior validated | Browser/runtime proof artifact |

A fix is **live only after proved truth**, not after branch or merge truth.

## Promotion Steps

1. Get release bundle from CI build (image digest + metadata)
2. Create release object (bundle SHA + image digest + build metadata)
3. Update bbi-infrastructure overlay with release object reference
4. Push to bbi-infrastructure, Argo picks up the change
5. Verify Argo sync status: `argocd app get mereka-lms-<env>`
6. Verify live image hash matches release object
7. Run runtime proof against the realized bundle
8. Record proof in truth ledger

## Key Paths

| Artifact | Location |
|---|---|
| App build | `mereka-lms` CI workflows |
| Image tags | `ghcr.io/biji-biji-initiative/mereka-lms` |
| Promotion target | bbi-infrastructure `apps/mereka-lms/overlays/<env>/kustomization.yaml` |
| Argo apps | ArgoCD dashboard or `argocd` CLI |

## Verification

```bash
# Check Argo sync
argocd app get mereka-lms-dev --refresh

# Check live image
kubectl get pods -n mereka-lms-dev -o jsonpath='{.items[*].spec.containers[*].image}' | tr ' ' '\n' | sort -u

# Runtime proof
./scripts/qa/verify-rke2-tenant-routes.sh
```

## Never Do

- Manually join SHA + digest + env patch (use release object)
- Call a fix "live" after merge without proved truth
- Promote from a dirty worktree
- Skip runtime proof after realization
- Force-sync Argo without understanding what changed

## Stale Operation Recovery

If Argo shows "stale operation" or sync seems stuck:
1. Check `argocd app get <app>` for operation state
2. If stale: `argocd app terminate-op <app>` then re-sync
3. Never assume "synced" means "correct" without checking live pod state

## Required Companions

> Source: `config/skills-graph.yaml`

- **Requires**: `layer-triage`, `cross-repo-authority`
- **Recommended**: `runtime-proof`

## References

- [RELEASE_PROMOTION.md](docs/ops/playbooks/RELEASE_PROMOTION.md)
- [PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md](docs/architecture/PROMOTION_REALIZATION_AND_INCIDENT_FLOW.md)
