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
  - Target state: Atlas-only (see `docs/adr/001-mongodb-atlas.md`).
  - Current production reality: modulestore + forum are Atlas-backed; legacy deployment is retired and production overlay removes `Service/mongodb` to prevent drift (see `docs/concepts/architecture/ARCHITECTURE_MONGODB.md`).

## Secrets

Single source of truth is **Infisical**:

```
Infisical → GCP Secret Manager → ExternalSecrets → Pods
           ↓
          VPS apps (infisical run)
```

Canonical path for this stack: `/k8s/mereka-lms` (prod + dev).

## Build & deploy

1. Build Tutor images locally on the VPS (`tutor images build openedx` / `mfe`).
2. Push to Artifact Registry:
   `ghcr.io/biji-biji-initiative/mereka-lms`.
3. Update K8s deployments (LMS/CMS/workers/MFE) to new tags.
4. If production is pinned through GitOps (`BBI-K8`, legacy `bbi-infrastructure` naming), bump the pinned `?ref=<sha>` there so Argo can reconcile this repo’s latest manifests.
   - Recommended helper in this repo:
     `./scripts/infra/prepare-bbi-infra-ref-bump.sh --apply`
5. Verify rollouts (`kubectl rollout status ...`).

See `docs/ops/runbooks/DEPLOYMENT_RUNBOOK.md` for the full, step-by-step flow.

## Monitoring & health checks

- Synthetic checks: `scripts/qa/public-health-check.sh`
- Cron entrypoint: `scripts/infra/cron-public-health-check.sh`
- Optional VPS cron installers:
  - `scripts/infra/setup-vps-health-cron.sh`
  - `scripts/infra/setup-vps-atlas-allowlist-cron.sh`
- GCP Monitoring configs: `infrastructure/monitoring/`

## Backups

- **Source of truth**: Velero schedules + restore drills (GitOps-managed outside this repo).
- Audit posture with: `./scripts/qa/audit-velero.sh --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster`
- Evidence bundles (recommended): `STRICT_RUNTIME=1 ./scripts/qa/build-dr-evidence-bundle.sh --tar`
- Monthly automation: `.github/workflows/dr-evidence-bundle.yml`

References:
- `docs/operations/VELERO_BACKUP_AUDIT.md`
- `docs/ops/runbooks/DISASTER_RECOVERY.md`
- `docs/operations/BACKUP_COVERAGE_MATRIX.md`

## References

- `docs/ops/runbooks/DOMAIN_CHANGE_RUNBOOK.md`
- `docs/ops/security/RELEASE_CHECKLIST_DOMAIN_SECRETS.md`
- `docs/guides/admin/K8S_OPERATIONS_GUIDE.md`
- `docs/ops/runbooks/DISASTER_RECOVERY.md`
