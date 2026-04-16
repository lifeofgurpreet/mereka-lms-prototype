# Production Infrastructure Plan (Current)

<!-- Last verified: 2026-02-13 -->

This document captures the **current** production/development model for the
Mereka LMS stack. There is **no staging environment**. Historical planning that
references staging has been archived at:
`docs/archive/PRODUCTION_INFRASTRUCTURE_PLAN_LEGACY.md`.

## Environment model

- **Production (GKE)**: `academyv2.mereka.io`
- **Development (VPS kind)**: `academyv2.mereka.dev`

## Public domains (production)

- LMS: `https://academyv2.mereka.io`
- Studio: `https://studio.academyv2.mereka.io`
- MFEs: `https://apps.academyv2.mereka.io`
- Discovery: `https://discovery.academyv2.mereka.io`
- Ecommerce: `https://ecommerce.academyv2.mereka.io` (legacy Oscar, being replaced by Purchase Gateway per ADR-018)
- Notes: `https://notes.academyv2.mereka.io`
- Credentials: `https://credentials.academyv2.mereka.io`
- Forum: `https://forum.academyv2.mereka.io`
- Microsites: `https://skillourfuture.academy.mereka.io`,
  `https://academy.biji-biji.com`

## Data plane

- **MySQL**: in-cluster (PVC-backed) in production and dev.
- **Redis**: in-cluster (PVC-backed) in production and dev.
- **MongoDB**:
  - Target state: Atlas-only (see `docs/adr/historical/001-mongodb-atlas.md`).
  - Current production reality: modulestore + forum are Atlas-backed; legacy deployment is retired and production overlay removes `Service/mongodb` to prevent drift (see `docs/guides/admin/MONGODB_ATLAS_GUIDE.md`).

## Secrets

Single source of truth is **Infisical**:

```
Infisical → GCP Secret Manager → ExternalSecrets → Pods
           ↓
          VPS apps (infisical run)
```

Canonical path for this stack: `/k8s/mereka-lms` (prod + dev).

## Build & deploy

1. Publish the merged target SHA through `.github/workflows/build-tutor-images.yml`.
   - Prefer the automatic push-to-`main` run.
   - Use `workflow_dispatch` only for deterministic rebuilds with an explicit `image_tag`.
2. Treat the workflow-emitted immutable tags/digests plus the `release-bundle` and `build-provenance` artifacts as the release inputs.
3. Promote those exact coordinates through `./scripts/infra/release-openedx-gitops.sh --require-digests --apply --commit --push --verify-runtime`.
4. Let ArgoCD reconcile the GitOps change and verify runtime convergence.
5. Use local Tutor builds only for dev parity, bootstrap, or debugging. They are not the canonical production source of truth.

See:
- `docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
- `docs/ops/runbooks/RELEASE_EXECUTE_RUNBOOK.md`
- `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md`

## Monitoring & health checks

- Synthetic checks: `scripts/qa/public-health-check.sh`
- Cron entrypoint: `scripts/infra/cron-public-health-check.sh`
- Optional VPS cron installers:
  - `scripts/infra/setup-vps-health-cron.sh`
  - `scripts/infra/setup-vps-atlas-allowlist-cron.sh`
- GCP Monitoring configs: `infrastructure/monitoring/`

## Backups

- **Source of truth**: Velero schedules + restore drills (GitOps-managed outside this repo).
- Audit posture with: `./scripts/qa/audit-velero.sh --context rke2-prod`
- Evidence bundles (recommended): `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
- Monthly automation: `.github/workflows/dr-evidence-bundle.yml`

References:
- `docs/ops/runbooks/VELERO_BACKUP_AUDIT.md`
- `docs/ops/runbooks/DISASTER_RECOVERY.md`
- `docs/reference/operations/BACKUP_COVERAGE_MATRIX.md`

## References

- `docs/ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md`
- `docs/ops/runbooks/RELEASE_CHECKLIST_DOMAIN_SECRETS.md`
- `docs/guides/admin/K8S_OPERATIONS_GUIDE.md`
- `docs/ops/runbooks/DISASTER_RECOVERY.md`
