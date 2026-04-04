---
name: cross-repo-authority
description: Enforce the boundary between app repo (mereka-lms) and infrastructure repo (bbi-infrastructure). Use when working with overlays, ArgoCD application wiring, Kustomize contract consumption, environment realization, or boundary violations. Prevents agents from fixing infra symptoms in the wrong repo.
---

# Cross-Repo Authority

The platform spans three repos. Each owns a different layer. Mixing them is the
most common source of cascading failures.

## Repo Ownership Map

| Repo | Owns | Does NOT own |
|---|---|---|
| `mereka-lms` | App source, Tutor plugins, build scripts, base K8s manifests (`deploy/k8s/base/`), QA scripts, specs | Environment overlays (prod/staging), ArgoCD applications, image tag pinning |
| `bbi-infrastructure` | ArgoCD apps, env overlays, image tag overrides, cluster services, platform stack | App source code, Tutor configuration, QA scripts, build logic |
| `platform-control-plane` | Release contracts, service identity contracts, staging DNS/cert readiness | Runtime code, deployment manifests, QA scripts |

## The Boundary Rule

```
mereka-lms produces base manifests + images
bbi-infrastructure consumes them and applies to clusters
platform-control-plane governs contracts
```

If you are editing something and it requires changes in TWO repos, stop and think:
- Am I crossing the boundary correctly?
- Am I making the producer change (app repo) and letting the consumer repo pick it up?
- Or am I patching the consumer directly (wrong)?

## Allowed vs Forbidden in mereka-lms

| Action | Allowed in mereka-lms? |
|---|---|
| Edit `deploy/k8s/base/**` | Yes (app base manifests) |
| Edit `deploy/k8s/overlays/local/` | Yes (local dev) |
| Edit `deploy/k8s/overlays/rke2-nonprod/` | Transitional only (will move to bbi-infra) |
| Edit `deploy/k8s/overlays/production/` | Transitional only (will move to bbi-infra) |
| Pin image tags | No (bbi-infrastructure owns this) |
| Edit ArgoCD application manifests | No (bbi-infrastructure owns this) |
| Edit platform services (Authentik, Grafana) | No (bbi-infrastructure owns this) |

## When to Touch Which Repo

| Symptom | Fix in |
|---|---|
| Build/image wrong | `mereka-lms` (build path) |
| Settings wrong in rendered config | `mereka-lms` (Tutor plugin) |
| Caddyfile routing wrong | `mereka-lms` (`deploy/k8s/base/apps/caddy/`) |
| ArgoCD not syncing | `bbi-infrastructure` (app definition) |
| Wrong image tag in prod | `bbi-infrastructure` (overlay) |
| DNS/TLS wrong | DNS provider + `bbi-infrastructure` |
| Release contract violation | `platform-control-plane` |

## How Promotion Crosses Repos

1. `mereka-lms` CI builds image → pushes to `ghcr.io`
2. `mereka-lms` release workflow creates release object
3. `bbi-infrastructure` promotion job updates overlay image tag
4. ArgoCD in `bbi-infrastructure` syncs to cluster
5. Runtime proof runs from `mereka-lms` scripts

Steps 1-2 are app-repo. Step 3-4 are infra-repo. Step 5 is app-repo again.

## Never Do

- Fix live cluster symptoms by editing mereka-lms overlays that bbi-infrastructure owns
- Pin image tags in mereka-lms (infra repo owns pinning)
- Edit ArgoCD app definitions from mereka-lms
- Assume `kubectl apply` from mereka-lms is the canonical deploy path (Argo is)
- Apply ARC manifests through the main overlay namespace transformer

## Required Companions

> Source: `config/skills-graph.yaml`

- **Requires**: `layer-triage`
- **Recommended**: none

## References

- [REPO_BOUNDARIES.md](docs/policies/operations/REPO_BOUNDARIES.md)
- [DEPLOYMENT_CONTRACT.md](docs/reference/architecture/DEPLOYMENT_CONTRACT.md)
