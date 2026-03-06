# Kyverno ClusterPolicies — PENDING MIGRATION TO GITOPS

These Kyverno `ClusterPolicy` resources are **cluster-scoped** and belong in
`bbi-infrastructure`, not in the app repo.

Per `docs/architecture/DEPLOYMENT_CONTRACT.md` and `DEPLOYMENT_BOUNDARY.md`,
cluster-scoped resources are owned by the GitOps repo.

## Migration plan

1. Copy these files to `bbi-infrastructure/apps/mereka-lms/policies/`
2. Reference them from the appropriate overlay kustomization
3. Remove the `policies` entry from this repo's `deploy/k8s/base/kustomization.yaml`
4. Delete these files from the app repo

## Current policies

| File | Kind | Scope |
|------|------|-------|
| `disallow-privileged.yaml` | ClusterPolicy | mereka-lms namespace |
| `require-non-root.yaml` | ClusterPolicy | mereka-lms namespace |
| `require-seccomp.yaml` | ClusterPolicy | mereka-lms namespace |
| `restrict-capabilities.yaml` | ClusterPolicy | mereka-lms namespace |

Tracked in: https://github.com/Biji-Biji-Initiative/bbi-infrastructure/issues/1164
