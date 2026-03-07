# LMS Agent Standing Order

> You own the application deployment package and the first-class migration surface.

## Mission

Make migrations boring, deterministic, auditable, runtime-identical, and release-gating.

You are not debugging one stuck migration job.
You are building the migration control plane for LMS.

## Implementation Order

### PR1 - Contract Bundle
Create/maintain:
- `deploy/k8s/CONTRACTS.md`
- `deploy/k8s/contract.json`
- `deploy/k8s/VERSION`

Must define: image names, service names and ports, configMap base names, required secret keys, health endpoints, migration entrypoints, GitOps allowed overrides, GitOps forbidden mutations.

### PR2 - Migration Registry
Create/maintain:
- `deploy/k8s/migrations/registry.yaml`

For every migratable component define: service id, owner, migration engine, canonical invocation, settings module, image source, config mounts, secret refs, dependency truth required, lane applicability, preflight checks, zero-pending verification, smoke verification, rollback prerequisite, status class (canonical / legacy / break-glass / deprecated).

Must include at minimum: lms, cms, discovery, credentials, notes, xqueue (if applicable), enterprise-access, enterprise-catalog, enterprise-subsidy, license-manager, purchase-gateway.

### PR3 - Canonical Migration Jobs
Create or normalize:
- `deploy/k8s/base/jobs/lms-migrate.yaml`
- `deploy/k8s/base/jobs/cms-migrate.yaml`

Rules: same effective config as runtime, same image as runtime, same settings module as runtime, same configMaps and secret refs as runtime, `enableServiceLinks: false`, explicit dependency truth output, no hidden defaults, reproducible and versioned.

Do not leave immutable one-shot jobs ambiguously treated as normal steady-state resources.

### PR4 - Migration Preflight and Audits
Create:
- `scripts/release/migration-preflight.sh`
- `scripts/release/verify-zero-pending-migrations.sh`

Preflight must fail hard on: wrong settings module, missing configMaps, missing secrets, config/runtime parity mismatch, wrong dependency target, stale in-cluster mongodb service when externalized, MySQL/Mongo/Redis/Meilisearch reachability problems, DNS/SRV/TLS problems for Atlas.

### PR5 - Smoke and Release Gate
Create:
- `scripts/release/smoke-after-migrate.sh`
- `scripts/release/release-gate.sh`

Release gate sequence: preflight, migration execution, zero-pending verification, smoke verification, proof bundle output.

### PR6 - Boundary Cleanup in LMS Repo
Keep only: `deploy/k8s/base`, `deploy/k8s/overlays/local`, contract bundle, migration registry, release gate and validators.

Remove or move out: non-local environment overlays, cluster-scoped platform resources, mutable base tags, provider-specific secret store assumptions, stale docs.

## Required Artifacts from Every PR
- Rendered manifest proof
- Validator output
- Sample JSON proof artifact
- Note on contract/version impact

## Forbidden
- `kubectl exec` as the standard migration path
- Undocumented ad-hoc steps
- Environment-specific values in base
- Runtime config divergence between app and migration job
- New legacy scripts
