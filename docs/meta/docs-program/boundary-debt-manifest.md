# Boundary Debt Manifest

Tracks scripts and resources in mereka-lms that reference deprecated overlays
or contain logic that belongs in bbi-infrastructure or platform-control-plane.

## Status: Wave 6 (documented), Wave 9 (deletion)

## Deprecated Overlays

ArgoCD deploys from `bbi-infrastructure/apps/mereka-lms/overlays/{dev,staging,prod}/`.
These overlays in mereka-lms are dead code:

| Overlay | Files | ArgoCD Source |
|---------|-------|---------------|
| `deploy/k8s/overlays/rke2-nonprod/` | 21 | `bbi-infrastructure:apps/mereka-lms/overlays/dev/` |
| `deploy/k8s/overlays/staging/` | 19 | `bbi-infrastructure:apps/mereka-lms/overlays/staging/` |
| `deploy/k8s/overlays/production/` | 11 | `bbi-infrastructure:apps/mereka-lms/overlays/prod/` |

## Scripts Referencing Deprecated Overlays

### Release/Infra Scripts (rewire to bbi-infrastructure)

| Script | References | Action |
|--------|-----------|--------|
| `scripts/infra/release-openedx-gitops.sh` | production | Reads image tags for promotion |
| `scripts/infra/sync-gitops-prod-image-tags.sh` | production | Syncs tags between repos |
| `scripts/infra/bump-image-tags.sh` | rke2-nonprod, production | Writes image tags |
| `scripts/infra/assemble-release-evidence.sh` | production | Reads overlay for evidence |
| `scripts/infra/verify-release-preflight.sh` | production | Preflight checks |

### QA/Verify Scripts (update or accept as-is)

| Script | References | Action |
|--------|-----------|--------|
| `scripts/qa/verify-kustomize-structure.sh` | all | Keep for base validation |
| `scripts/qa/verify-deployment-lanes.sh` | all | Update to use lane-identity.yaml |
| `scripts/qa/verify-no-latest-tags.sh` | rke2-nonprod, production | Keep for base checks |
| `scripts/qa/verify-secrets-isolation.sh` | all | Keep, not deployment-specific |
| `scripts/qa/verify-repo-structure.sh` | all | Keep, directory existence is valid |
| `scripts/qa/verify-release-readiness.sh` | production | Should check bbi-infrastructure |
| `scripts/qa/verify-dev-prod-image-parity.sh` | rke2-nonprod, production | Should compare bbi-infrastructure |
| `scripts/qa/verify-gitops-drift.sh` | production | Should compare bbi-infrastructure |
| `scripts/qa/verify-gitops-image-overrides.sh` | production | Should check bbi-infrastructure |

## Infrastructure Resources (future extraction)

| Directory | Owner | Files | Priority |
|-----------|-------|-------|----------|
| `infrastructure/terraform/` | platform-control-plane | ~30 | Low |
| `infrastructure/cloudflare/` | platform-control-plane | 4 | Low |
| `infrastructure/monitoring/` | bbi-infrastructure (platform parts) | ~20 | Low |
| `deploy/k8s/base/arc/` | bbi-infrastructure | 6 | Medium |
| `deploy/k8s/base/network-policies/` | bbi-infrastructure | 11 | Medium |

## Triage Rules

1. **Rewire**: Script reads/writes to deprecated overlays for deployment
2. **Accept**: Script checks structural validity of kustomize base
3. **Deprecate**: Script duplicates a check bbi-infrastructure CI already runs
4. **Delete**: Script is orphaned with no callers
