# Domain Truth Convergence Takeover Prompt

You are taking over the cross-repo tenant/domain truth convergence lane for:

- `mereka-lms`
- `bbi-infrastructure`
- `platform-control-plane`
- live DNS / HTTPS / runtime proof

Use these skills first:

1. `domain-truth-convergence`
2. `domain-management`
3. `platform-truth-tracking`

Read these in order before changing anything:

1. `docs/reference/architecture/DOMAIN_AUTHORITY_END_STATE.md`
2. `docs/status/active/DOMAIN_TRUTH_CONVERGENCE_TRACKER_2026-03-31.md`
3. `docs/status/active/DOMAIN_TRUTH_CONVERGENCE_TAKEOVER_PROMPT_2026-03-31.md`
4. `deploy/k8s/tenancy/tenant-registry.yaml`
5. `infrastructure/tenants/tenant-contracts.yml`
6. `scripts/shared/config.sh`
7. `tools/docs/build_domain_access_reference.py`
8. `scripts/qa/verify-domain-url-invariants.sh`
9. `scripts/qa/verify-mfe-config-api.sh`
10. `scripts/qa/verify-rke2-tenant-routes.sh`
11. `scripts/tenants/verify-dev-runtime-proof.sh`
12. `scripts/tenants/verify-staging-runtime-proof.sh`

Then inspect these cross-repo surfaces:

- `bbi-infrastructure/config/domain-registry.yaml`
- `bbi-infrastructure/config/service-topology-catalog.yaml`
- `bbi-infrastructure/config/cluster-topology-catalog.yaml`
- `platform-control-plane/contracts/staging-dns-cert-readiness.yaml`

## Mission

Build one machine-verifiable authority chain for tenant/domain truth across:

- Mereka Academy
- Biji-Biji
- Skill Our Future
- dev
- staging
- production
- cluster placement
- GitOps realization
- DNS/TLS realization
- live runtime proof

The job is not "fix a hostname."

The job is:

- eliminate parallel hand-edited truth
- generate joined operator truth
- make drift obvious and CI-verifiable
- prove runtime from declared host intent

## Core operating model

One truth does not mean one giant YAML.

It means:

- one canonical contract per concern
- one generated joined matrix for operators
- one runtime audit artifact
- zero silent parallel registries

Current canonical boundaries:

- host intent: `deploy/k8s/tenancy/tenant-registry.yaml`
- tenant metadata only: `infrastructure/tenants/tenant-contracts.yml`
- infra placement: `bbi-infrastructure/config/service-topology-catalog.yaml` + `cluster-topology-catalog.yaml`
- DNS/TLS readiness: `platform-control-plane/contracts/staging-dns-cert-readiness.yaml`

## Immediate priorities

Work the tracker in order, starting with `D-01` through `D-04`.

### D-01 Freeze authority boundaries

Classify every relevant surface as one of:

- canonical
- generated
- derived helper
- descriptive / historical

If two files appear to own the same hostname truth, that is drift debt to remove.

### D-02 Strengthen canonical app host intent

Extend `tenant-registry.yaml` so environment placement is machine-readable, not inferred from docs.

Target fields include:

- `cluster_ref`
- `cluster_class`
- `gitops_repo`
- `gitops_overlay_path`
- `argocd_app`
- `runtime_proof_script`
- `dns_zone`

### D-03 Repair or remove false `contract.json` claims

`deploy/k8s/contract.json` must either:

- expose a generated `domain_registry` projection, or
- stop claiming it does

Do not leave the current hollow contract in place.

### D-04 Separate tenant metadata from host truth cleanly

Make sure `tenant-contracts.yml` does not act like a second hostname registry.

Update consumers so:

- hostnames come from `tenant-registry.yaml`
- metadata comes from `tenant-contracts.yml`
- any merged output is generated, not hand-maintained

## Next tranche after D-01 to D-04

### D-05 GitOps must stop acting like a second host registry

`bbi-infrastructure/config/domain-registry.yaml` must become one of:

- generated from canonical app truth
- narrowed to platform metadata only
- deleted

GitOps may realize host intent. It may not redefine it.

### D-06 Control-plane readiness must consume canonical host intent

`staging-dns-cert-readiness.yaml` must stop drifting by hand.

The contract and generated references must match the hostnames declared in `tenant-registry.yaml`.

### D-07 to D-10 Generate the joined truth surfaces

Target artifacts:

- `generated/domain/domain-authority-matrix.json`
- `docs/reference/generated/domain-authority-matrix.md`
- `generated/domain/domain-runtime-audit.json`
- `docs/reference/operations/DOMAIN_RUNTIME_AUDIT.md`

The joined matrix must answer, for every declared host:

- tenant
- environment
- hostname
- surface role
- intended status
- namespace
- Argo app
- cluster
- DNS/TLS readiness status
- live DNS status
- live HTTPS status
- proof script / audit result

## Non-negotiable rules

- Do not collapse `repo_truth`, `infra_truth`, and `runtime_truth` into one claim.
- Do not add new hand-maintained host lists unless they are explicitly canonical.
- Do not let `scripts/shared/config.sh` become a second source of truth.
- Do not let GitOps become a second tenant hostname authority.
- Do not let control-plane invent or rename tenant hosts independently.
- Do not patch tenant-by-tenant runtime issues as the primary strategy while authority drift still exists.
- Do not claim closure from docs alone.
- Do not claim closure from runtime probes alone.
- Do not touch unrelated frontend, analytics, or tenant UI work in this lane.

## Files most likely to change

### app repo

- `deploy/k8s/tenancy/tenant-registry.yaml`
- `infrastructure/tenants/tenant-contracts.yml`
- `deploy/k8s/contract.json`
- `scripts/shared/config.sh`
- `scripts/tenants/env/staging.env`
- `scripts/tenants/sync-tenant-registry-configmap.sh`
- `scripts/qa/verify-domain-url-invariants.sh`
- `scripts/qa/verify-mfe-config-api.sh`
- `scripts/qa/verify-rke2-tenant-routes.sh`
- `scripts/tenants/verify-dev-runtime-proof.sh`
- `scripts/tenants/verify-staging-runtime-proof.sh`
- `tools/docs/build_domain_access_reference.py`
- generated matrix / audit scripts and outputs under `generated/domain/`

### GitOps repo

- `config/domain-registry.yaml`
- `config/service-topology-catalog.yaml`
- `config/cluster-topology-catalog.yaml`
- `apps/mereka-lms/README.md`

### control-plane repo

- `contracts/staging-dns-cert-readiness.yaml`
- generated references under `docs/reference/generated/`
- guardrail scripts that validate DNS / TLS readiness

## Minimum verification commands

### app repo static truth

- `bash scripts/qa/verify-domain-url-invariants.sh`
- `bash scripts/qa/verify-mfe-config-api.sh`
- `bash scripts/tenants/sync-tenant-registry-configmap.sh --check`

### app repo runtime truth

- `bash scripts/qa/verify-rke2-tenant-routes.sh --online`
- `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
- `bash scripts/tenants/verify-staging-runtime-proof.sh --namespace stg-mereka-lms`

### cross-repo inspection

- `rg -n "domain-registry|tenant-registry|staging-dns-cert-readiness|DOMAIN_MATRIX|build_domain_access_reference" . ../bbi-infrastructure ../platform-control-plane`

## Deliverables before stopping

1. updated tracker with exact `repo_truth`, `infra_truth`, and `runtime_truth`
2. code or PRs for the current tranche completed
3. explicit classification of:
   - canonical surfaces
   - generated surfaces
   - derived helpers
   - stale / historical surfaces
4. first machine-readable joined authority matrix plan or artifact
5. first machine-readable full runtime audit plan or artifact
6. exact remaining blockers with owner repo called out

## What counts as success

Minimum acceptable success for this lane:

- `tenant-registry.yaml` is the only hand-edited Open edX tenant hostname contract
- cluster / namespace / Argo placement is machine-readable from canonical data
- GitOps no longer hand-maintains Open edX host truth
- control-plane validates DNS/TLS against canonical host intent
- generated references replace hand-maintained projections
- runtime audit covers MEREKA, Biji-Biji, and Skill Our Future across dev, staging, and prod
- CI fails on unapproved duplicate domain authority surfaces
