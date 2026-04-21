# Domain Truth Convergence Tracker
_Audience: Contributors and reviewers • Owner: Platform Team • Last verified: 2026-03-31 • Status: active_

This tracker is the active execution board for converging tenant/domain truth across:

- `mereka-lms`
- `bbi-infrastructure`
- `platform-control-plane`
- live DNS / HTTPS / runtime proof

Use this with:

- `docs/reference/architecture/DOMAIN_AUTHORITY_END_STATE.md`
- `docs/status/active/DOMAIN_TRUTH_CONVERGENCE_TAKEOVER_PROMPT_2026-03-31.md`

## Current verified state

### repo_truth

- `deploy/k8s/tenancy/tenant-registry.yaml` is the strongest current canonical host-intent source and already declares itself canonical.
- `scripts/qa/verify-domain-url-invariants.sh` already enforces important alignment from the registry into derived shell and Django/Caddy surfaces.
- `scripts/qa/verify-mfe-config-api.sh`, `scripts/qa/verify-rke2-tenant-routes.sh`, `scripts/tenants/verify-dev-runtime-proof.sh`, and `scripts/tenants/verify-staging-runtime-proof.sh` are real executable truth checks.
- `scripts/tenants/sync-tenant-registry-configmap.sh` still says `infrastructure/tenants/tenant-contracts.yml` is the canonical input for the registry ConfigMap, which conflicts with the host-intent authority chain.
- `deploy/k8s/contract.json` does not currently expose a `domain_registry` payload even though `tenant-registry.yaml` claims it is consumed there.
- `tools/docs/build_domain_access_reference.py` still compiles from `bbi-infrastructure/config/domain-registry.yaml` plus hand-maintained docs.
- `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md` and `docs/reference/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md` still contain stale dev claims.

### infra_truth

- `bbi-infrastructure/config/domain-registry.yaml` exists and explicitly describes itself as descriptive metadata, not DNS authority.
- `bbi-infrastructure/apps/mereka-lms/README.md` still says the deployment chain is app repo → overlays → ArgoCD → GKE cluster, which no longer cleanly describes the current nonprod reality.
- Argo application paths and namespaces for dev/staging are already machine-readable in GitOps, but that placement is not yet surfaced from the app-owned tenant registry.

### runtime_truth

- We have direct SOF probe evidence from this lane:
  - `staging.skillourfuture.academy.mereka.io` resolves and returns `200`
  - `studio.staging.skillourfuture.academy.mereka.io` resolves and returns `502`
  - `apps.staging.skillourfuture.academy.mereka.io` resolves and returns `502`
  - `skillourfuture.academy.mereka.io` resolves and returns `503`
  - `studio.skillourfuture.academy.mereka.io` has no DNS
  - `apps.skillourfuture.academy.mereka.io` has no DNS
- We have earlier repo-local runtime proof scripts for dev and staging tenant surfaces, but this lane has not yet emitted one fresh full-environment matrix artifact for MEREKA + Biji-Biji + SOF together.
- `platform-control-plane/contracts/staging-dns-cert-readiness.yaml` and its generated staging reference still describe the SOF staging hosts as pending even though live DNS exists.
- Full cross-tenant live audit for MEREKA + Biji-Biji + Skill Our Future across dev/staging/prod has not yet been generated from the registry.

## What we achieved already

- Proved the current system does not have one single canonical machine-verifiable domain list.
- Identified the least-wrong current authority chain:
  - app host intent: `tenant-registry.yaml`
  - control-plane DNS/TLS readiness: control-plane contracts
  - live runtime truth: DNS / HTTPS / runtime proof scripts
- Identified the major duplicate or stale surfaces:
  - GitOps `config/domain-registry.yaml`
  - generated access reference using GitOps registry as primary input
  - stale architecture docs
  - stale control-plane staging readiness contract

## Current control point

Converge the authority chain before further tenant-by-tenant remediation.

Do not fix domain breakage in batches while the system still allows multiple
registries, hand-edited projections, and stale generated references.

## Execution board

| ID | Priority | Owner | Outcome | Current state |
|---|---|---|---|---|
| D-01 | P0 | app repo | Freeze the authority chain: canonical vs derived vs stale | open |
| D-02 | P0 | app repo | Extend `tenant-registry.yaml` with machine-readable cluster / GitOps placement | open |
| D-03 | P0 | app repo | Make `contract.json` either export domain registry truth or stop claiming it does | open |
| D-04 | P0 | app repo | Reconcile `tenant-contracts.yml` vs `tenant-registry.yaml` so metadata truth and host truth are cleanly separated | open |
| D-05 | P0 | infra repo | Eliminate `bbi-infrastructure/config/domain-registry.yaml` as a hand-edited Open edX host registry | open |
| D-06 | P0 | control-plane | Make DNS/TLS readiness contracts validate against canonical app host intent instead of drifting by hand | open |
| D-07 | P1 | app repo | Convert human-facing matrices into generated or explicit derivative outputs | open |
| D-08 | P1 | app repo | Add a full generated runtime audit for all declared tenant hosts | open |
| D-09 | P1 | cross-repo | Reconcile cluster / namespace / Argo placement into one machine-readable surface | open |
| D-10 | P1 | cross-repo | Run a full cross-tenant live audit and record the first complete truth matrix | open |
| D-11 | P2 | docs | Retire or collapse duplicate authority docs after generated replacements exist | open |

## Files that must be touched

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
- `docs/reference/operations/DOMAIN_MATRIX.md`
- `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md`
- `docs/reference/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md`
- `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`

### GitOps repo

- `config/domain-registry.yaml`
- `apps/mereka-lms/README.md`
- any Open edX host surfaces that duplicate app-owned canonical host intent

### control-plane repo

- `contracts/staging-dns-cert-readiness.yaml`
- generated references under `docs/reference/generated/`
- guardrail scripts validating DNS/TLS readiness

## Exact verification commands

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

## Ownership boundary

- App repo owns tenant host intent and runtime contract.
- GitOps owns environment realization, not host re-definition.
- Control-plane owns DNS/TLS realization, not tenant host invention.
- Runtime proof owns live truth and must remain distinct from repo and overlay truth.

## Do not claim this lane closed unless

1. `tenant-registry.yaml` is the only hand-edited Open edX tenant hostname contract.
2. cluster / namespace / Argo placement is machine-readable from the canonical app contract.
3. GitOps no longer maintains a hand-edited duplicate registry for Open edX hostnames.
4. control-plane readiness contracts validate against canonical host intent.
5. human-readable domain matrices are generated or explicitly derivative-only.
6. a full runtime audit exists for MEREKA, Biji-Biji, and Skill Our Future across dev, staging, and prod.
7. CI fails on unapproved duplicate domain authority surfaces.
