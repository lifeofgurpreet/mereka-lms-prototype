# Domain Authority End State
_Audience: Platform architects, operators, and reviewers • Owner: Platform Team • Status: proposed reference design_

This document defines the target state for tenant/domain truth across:

- `mereka-lms` (app-owned tenant and runtime contract)
- `bbi-infrastructure` (GitOps environment realization)
- `platform-control-plane` (DNS / TLS / control-plane realization)
- live runtime proof (DNS, HTTPS, browser, cluster)

It exists because the current system has multiple machine-readable domain surfaces,
but not one coherent authority chain.

## Current truth

### What is already strong

- `deploy/k8s/tenancy/tenant-registry.yaml` is the best current canonical source for tenant host intent.
- `scripts/qa/verify-domain-url-invariants.sh` already enforces important static alignment between:
  - `tenant-registry.yaml`
  - `scripts/shared/config.sh`
  - `scripts/tenants/env/staging.env`
  - Django and Caddy surfaces
- `scripts/tenants/verify-dev-runtime-proof.sh` and `scripts/tenants/verify-staging-runtime-proof.sh` already prove important runtime behavior from the registry.
- `scripts/qa/verify-mfe-config-api.sh` already checks tenant-scoped MFE config behavior.

### What is drifting

- `tools/docs/build_domain_access_reference.py` still treats `bbi-infrastructure/config/domain-registry.yaml` as canonical input.
- `bbi-infrastructure/config/domain-registry.yaml` is descriptive metadata, but it is functioning like a second registry in practice.
- `platform-control-plane/contracts/staging-dns-cert-readiness.yaml` contains hand-maintained host lists that have already drifted from live runtime.
- human-readable docs overlap and disagree:
  - `docs/reference/operations/DOMAIN_MATRIX.md`
  - `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md`
  - `docs/reference/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md`
- `scripts/tenants/sync-tenant-registry-configmap.sh` still calls `infrastructure/tenants/tenant-contracts.yml` the canonical input for the tenant registry ConfigMap, which is a different authority plane than host intent.
- `deploy/k8s/contract.json` does not currently expose a `domain_registry` payload even though `tenant-registry.yaml` claims it is consumed there.

## Architectural decision

The domain system must have one authority chain per truth plane.

### 1. Canonical host intent

**Canonical file:** `deploy/k8s/tenancy/tenant-registry.yaml`

This file remains the single source of truth for:

- tenant slugs
- environment names
- hostnames
- host role
- host status (`active`, `planned`, etc.)
- cookie expectations
- auth classification
- proof priority
- environment namespace

This file must also become explicit about environment placement instead of leaving
cluster ownership implicit in docs.

### 2. Canonical tenant metadata

**Canonical file:** `infrastructure/tenants/tenant-contracts.yml`

This file remains the source of truth for tenant metadata that is not host-routing
truth, for example:

- display name
- org code
- contact details
- tenant aliases
- enterprise/MFE metadata

It must not become a second domain registry.

### 3. Canonical DNS / TLS realization

**Canonical repo:** `platform-control-plane`

The control-plane repo is authoritative for:

- DNS records
- TLS issuers
- DNS/TLS readiness state
- control-plane guardrails

But it must consume hostnames from the app-owned canonical host contract rather
than duplicating them by hand.

### 4. Canonical environment realization

**Canonical repo:** `bbi-infrastructure`

The GitOps repo is authoritative for:

- ArgoCD applications
- overlay host realization
- ingress patches
- image pinning
- namespace realization

It must consume host intent, not redefine it.

### 5. Canonical runtime truth

**Canonical source:** generated proof artifacts from live probes

Repo truth and overlay truth are not runtime truth. Runtime truth must come from
machine-executed probes:

- DNS resolution
- HTTPS status
- runtime proof scripts
- browser auth proof where required

## End-state authority chain

```text
tenant-registry.yaml
  -> canonical host intent for all tenants / envs / roles
  -> exported machine-readable projection(s)

tenant-contracts.yml
  -> canonical tenant metadata only

platform-control-plane
  -> consumes canonical host intent
  -> owns DNS/TLS realization state
  -> generates readiness references

bbi-infrastructure
  -> consumes canonical host intent
  -> owns environment/Argo realization
  -> does not maintain a second hand-edited registry

runtime audit scripts
  -> probe declared hosts
  -> emit machine-readable live truth

generated docs
  -> project canonical + realized + runtime proof
  -> never become hand-edited authority
```

## Required end-state changes

### A. Strengthen `tenant-registry.yaml`

Add environment/cluster realization metadata so cluster ownership is machine-readable.

Minimum new fields:

- `cluster_ref`
- `cluster_class`
- `gitops_repo`
- `gitops_overlay_path`
- `argocd_app`
- `runtime_proof_script`
- `dns_zone`

Suggested model:

```yaml
environments:
  dev:
    scheme: https
    root_domain: mereka.dev
    auth_host: auth0.mereka.dev
    namespace: mereka-lms-dev
    cluster_ref: rke2-nonprod
    cluster_class: shared-nonprod
    gitops_repo: Biji-Biji-Initiative/bbi-infrastructure
    gitops_overlay_path: apps/mereka-lms/overlays/profiles/dev
    argocd_app: mereka-lms-dev
    runtime_proof_script: scripts/tenants/verify-dev-runtime-proof.sh
  staging:
    ...
```

This removes the need to infer environment placement from scattered docs.

### B. Make `contract.json` carry domain truth

`deploy/k8s/contract.json` must either:

- embed a generated `domain_registry` projection, or
- explicitly stop claiming to do so

The current mismatch is a trust break.

### C. Separate metadata truth from host truth

`scripts/tenants/sync-tenant-registry-configmap.sh` must stop describing
`tenant-contracts.yml` as the canonical tenant/domain source.

It should instead use one of two clean models:

1. `tenant-registry.yaml` is canonical for host/domain fields and `tenant-contracts.yml`
   is canonical for tenant metadata, with the sync script merging the two.
2. A generated intermediary JSON/YAML contract is emitted from both sources and
   consumed by the ConfigMap sync.

Model 1 is simpler and should be preferred.

### D. Kill the second registry in GitOps

`bbi-infrastructure/config/domain-registry.yaml` must become one of:

- generated from `tenant-registry.yaml`
- a narrow platform helper file with no Open edX tenant hosts in it
- deleted

It should not remain a second hand-edited source for Open edX host truth.

### E. Stop hand-editing human-facing matrices

These should become generated or clearly marked derivative-only:

- `docs/reference/operations/DOMAIN_MATRIX.md`
- `docs/reference/platform/DOMAIN_AND_ACCESS_REFERENCE.md`
- `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md`
- `docs/reference/architecture/TENANT_DOMAIN_AUTHORITY_MATRIX.md`

Recommended split:

- keep one generated operator matrix:
  - `docs/reference/operations/DOMAIN_MATRIX.md`
- keep one narrative architecture explainer:
  - `docs/reference/architecture/TENANT_DOMAIN_SURFACE_AUTHORITY.md`
- retire or fold duplicate authority matrices once the generated operator matrix is stable

### F. Add one generated live audit artifact

Add a new canonical runtime audit output for all declared hosts.

Recommended outputs:

- `generated/domain/domain-runtime-audit.json`
- `docs/reference/operations/DOMAIN_RUNTIME_AUDIT.md`

Generated from a new script such as:

- `scripts/qa/generate-domain-runtime-audit.py`

Inputs:

- `tenant-registry.yaml`
- optional control-plane readiness projection

Checks:

- DNS resolution
- HTTPS status
- redirect behavior
- optional TLS metadata
- optional authn / MFE config checks per host role

## Drift prevention rules

### Rule 1: no unapproved domain lists

Any new hand-maintained file containing Open edX tenant hostnames must be treated
as drift unless it is one of:

- canonical host intent
- generated output
- explicit evidence artifact

### Rule 2: generated docs must declare their inputs

Every generated domain reference must name:

- canonical input(s)
- generator script
- last generation time

### Rule 3: repo truth, infra truth, runtime truth must stay separate

No report or generated page should collapse:

- declared host intent
- DNS/TLS realization
- live runtime reachability

into one status word.

### Rule 4: cluster placement must be machine-readable

No operator should need to infer “is this on rke2 or GKE?” from prose or tribal
knowledge.

### Rule 5: control-plane readiness must be consumable, not isolated

`platform-control-plane` readiness contracts must be regenerated or validated
against canonical app host intent. They must not drift independently.

## Script changes required

### Keep and strengthen

- `scripts/qa/verify-domain-url-invariants.sh`
- `scripts/qa/verify-mfe-config-api.sh`
- `scripts/qa/verify-rke2-tenant-routes.sh`
- `scripts/tenants/verify-dev-runtime-proof.sh`
- `scripts/tenants/verify-staging-runtime-proof.sh`
- `scripts/tenants/sync-tenant-registry-configmap.sh`

### Add

- `scripts/qa/verify-domain-authority-chain.sh`
  - checks that only approved files act as domain authorities
  - fails when generated surfaces drift or hand-edited duplicates appear

- `scripts/qa/generate-domain-runtime-audit.py`
  - emits machine-readable DNS/HTTPS truth for all declared hosts

- `scripts/qa/verify-domain-generated-surfaces.sh`
  - checks generated docs/json are current

### Update outside this repo

- `platform-control-plane/scripts/guardrails/verify-staging-dns-cert-readiness.sh`
- `platform-control-plane/scripts/guardrails/verify-control-plane-merge-safety.sh`

These should validate host coverage against exported canonical app host intent.

## Files to touch in the convergence program

### App repo

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
- any environment-specific host patch surfaces that still duplicate canonical hostnames

### Control-plane repo

- `contracts/staging-dns-cert-readiness.yaml`
- generated references under `docs/reference/generated/`
- guardrails that validate DNS/TLS readiness

## Success criteria

The domain truth system is only considered converged when all of the following are true:

1. There is one canonical app-owned host contract.
2. Cluster / namespace / Argo placement is machine-readable from that contract.
3. GitOps no longer maintains a second hand-edited Open edX host registry.
4. Control-plane readiness contracts validate against canonical app host intent.
5. Human-facing matrices are generated or explicitly derivative.
6. A full runtime audit exists for all declared tenant hosts across dev, staging, and prod.
7. CI fails when an unapproved duplicate domain authority surface appears.

## Immediate recommendation

Do not start by patching more tenant hosts ad hoc.

Start by converging the authority chain:

1. classify and freeze the current sources
2. strengthen `tenant-registry.yaml`
3. eliminate the second registry in GitOps
4. generate the human matrices
5. add the full runtime audit harness

Only then should tenant-specific runtime remediation proceed as part of a single
machine-verifiable domain program.
