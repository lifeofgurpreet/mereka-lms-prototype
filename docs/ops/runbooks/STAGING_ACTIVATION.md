# Staging Lane Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-27 • Status: active_

This file keeps the legacy `STAGING_ACTIVATION.md` path, but the contract it
documents is the current live staging lane, not a future activation plan.

## Current Topology

| Lane | Cluster | Argo resource | GitOps path | Namespace | Runtime status |
|------|---------|---------------|-------------|-----------|----------------|
| dev | shared nonprod RKE2 | `argocd/applicationsets/mereka-lms-dev.yaml` | `apps/mereka-lms/overlays/profiles/dev` | `mereka-lms-dev` | live |
| staging | shared nonprod RKE2 | `argocd/applications/mereka-lms-staging.yaml` | `apps/mereka-lms/overlays/staging` | `stg-mereka-lms` | live |
| prod | GKE | `argocd/applications/mereka-lms-prod.yaml` | `apps/mereka-lms/overlays/prod` | `mereka-lms` | parked |

Important truth boundaries:

- Dev and staging are the active runtime lanes to validate on now.
- Production is intentionally parked at zero replicas to control cost.
- Production proof currently means `verify-prod-parked-state.sh`, not browser E2E.
- `deploy/k8s/overlays/staging` in this repo is a historical producer-side artifact.
  It is not the live staging overlay consumed by ArgoCD.

## Repository Roles

| Repo | Owns |
|------|------|
| `mereka-lms` | app runtime base, QA verifiers, policy docs, historical producer overlays |
| `bbi-infrastructure` | live environment overlays, ArgoCD Applications/ApplicationSets, bootstrap ownership |

## Canonical Verification

### Offline contract check

```bash
./scripts/qa/verify-staging-activation.sh --offline
```

This verifies:

- the historical app-repo staging overlay remains explicitly non-authoritative
- live GitOps dev/staging/prod manifests exist in `bbi-infrastructure`
- staging bootstrap wiring includes `mereka-lms-staging`
- documentation for the live lane contract still exists

### Online dev/staging check

```bash
./scripts/qa/verify-staging-activation.sh --online --context rke2-nonprod
```

This verifies on the shared nonprod RKE2 cluster:

- `mereka-lms-dev` exists and is `Synced/Healthy`
- `mereka-lms-staging` exists and is `Synced/Healthy`
- core staging workloads (`lms`, `cms`, `caddy`) are ready in `stg-mereka-lms`
- staging has no CrashLoopBackOff pods
- staging `ExternalSecret` resources are ready

### Production parked-state check

```bash
./scripts/qa/verify-prod-parked-state.sh
```

Run this separately. It is the truthful production runtime check while GKE prod
remains parked.

## Promotion Model

The current truthful promotion model is:

```text
local development
  -> dev on shared RKE2
  -> staging on shared RKE2
  -> prod overlay update only when deliberate reactivation work is approved
```

That means:

1. CI/build output may update dev and staging GitOps overlays.
2. Runtime/browser proof should be taken against staging.
3. Production does not become a default proof target while it is parked.

## GitOps Paths

### Dev

```text
bbi-infrastructure/argocd/applicationsets/mereka-lms-dev.yaml
bbi-infrastructure/apps/mereka-lms/overlays/profiles/dev
```

### Staging

```text
bbi-infrastructure/argocd/applications/mereka-lms-staging.yaml
bbi-infrastructure/bootstrap/applicationsets/overlays/staging/kustomization.yaml
bbi-infrastructure/apps/mereka-lms/overlays/staging
```

### Prod

```text
bbi-infrastructure/argocd/applications/mereka-lms-prod.yaml
bbi-infrastructure/apps/mereka-lms/overlays/prod
```

## Rollback

### Staging

Rollback is GitOps-only:

1. Revert the staging overlay/image change in `bbi-infrastructure`.
2. Merge the rollback PR.
3. Wait for ArgoCD to reconcile.
4. Re-run:

```bash
./scripts/qa/verify-staging-activation.sh --online --context rke2-nonprod
```

### Prod

If prod is still parked, rollback is usually unnecessary because runtime is not
active. If prod is being reactivated in a future tranche, use a dedicated prod
runbook plus `verify-prod-parked-state.sh` or its eventual replacement.

## Do Not Do

- Do not treat `deploy/k8s/overlays/staging` in this repo as the live staging source.
- Do not patch Argo Applications in-cluster to “fix” drift.
- Do not treat parked production as a failing browser-proof lane.
- Do not assume staging is on GKE; today it lives on shared RKE2.

## Related Commands

```bash
./scripts/qa/verify-staging-activation.sh --offline
./scripts/qa/verify-staging-activation.sh --online --context rke2-nonprod
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-staging --offline
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-staging --online
./scripts/qa/verify-prod-parked-state.sh
```
