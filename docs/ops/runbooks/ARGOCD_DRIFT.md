# ArgoCD Drift Detection Runbook
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-03-27 • Status: active_

## Overview

This runbook covers “Synced but wrong” drift for the live Mereka LMS GitOps
resources.

The current authoritative app set is:

| App | Kind | GitOps manifest | Overlay path | Namespace |
|-----|------|-----------------|--------------|-----------|
| `mereka-lms-dev` | `ApplicationSet` | `argocd/applicationsets/mereka-lms-dev.yaml` | `apps/mereka-lms/overlays/profiles/dev` | `mereka-lms-dev` |
| `mereka-lms-staging` | `Application` | `argocd/applications/mereka-lms-staging.yaml` | `apps/mereka-lms/overlays/staging` | `stg-mereka-lms` |
| `mereka-lms-prod` | `Application` | `argocd/applications/mereka-lms-prod.yaml` | `apps/mereka-lms/overlays/prod` | `mereka-lms` |

Production remains parked. Drift detection still matters there, but runtime
health for prod is not interpreted the same way as the active dev/staging lanes.

## Quick Commands

```bash
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-dev --offline
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-staging --offline
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-staging --online
./scripts/qa/verify-argocd-drift.sh --app mereka-lms-prod --offline
```

Use `--online` only when your kube context targets the cluster that actually
hosts the selected app.

## What The Script Checks

### Offline

- the expected GitOps overlay path exists
- the overlay has a `kustomization.yaml`
- the authoritative Argo manifest exists at the current path
- `source.path`, `source.repoURL`, and `destination.namespace` match the live contract
- prod overlay warm-park mode is still surfaced as an informational signal

### Online

- the Argo Application exists
- sync status is `Synced`
- health status is `Healthy`
- in-cluster `source.path`, `source.repoURL`, and `destination.namespace` match git
- manual refresh annotations are surfaced
- degraded managed resources are enumerated
- automated sync settings remain enabled
- for dev, the owning `ApplicationSet` template still matches the git contract

## Resolution Rules

1. Do not patch the Application or ApplicationSet in-cluster.
2. Fix the source manifest in `bbi-infrastructure`.
3. Let ArgoCD reconcile from git.
4. Re-run the drift checker.

If the cluster object is wrong while git is correct, delete only the child
Application and let the owning Application or ApplicationSet recreate it.

## Workflow Coverage

`.github/workflows/argocd-drift-check.yml` runs the offline drift checker for:

- `mereka-lms-dev`
- `mereka-lms-staging`
- `mereka-lms-prod`

The workflow’s online coverage is intentionally narrower than local/manual
checks until the runtime auth path for each live cluster is explicit and proven.

## Related Runbooks

- `docs/ops/runbooks/STAGING_ACTIVATION.md`
- `docs/ops/runbooks/POST_DEPLOY_GATE.md`
- `docs/ops/runbooks/PROD_PARKED_MODE.md`
