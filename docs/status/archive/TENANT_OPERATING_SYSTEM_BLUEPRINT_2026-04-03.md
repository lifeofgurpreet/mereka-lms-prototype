# Tenant Operating System Blueprint — 2026-04-03

**Audience**: Platform owners, reviewers, and operators  
**Status**: active  
**Parent standard**: [`../../concepts/architecture/TENANT_OPERATING_SYSTEM.md`](../../concepts/architecture/TENANT_OPERATING_SYSTEM.md)

## Goal

Turn tenant work into a release-centered operating model where one contract edit leads to one acceptance command, one proof bundle, and one promotion path.

## Current blocker

The platform still allows too many layers to advance independently:

- merged PRs that are not live
- synced Argo apps running stale images
- generated contracts with nondeterministic churn
- validators bound to historical file layouts
- too many operator-facing verifier names

## North-star operating rules

- One canonical tenant contract
- One public human entrypoint per lane through `bin/accept`
- One proof bundle schema per lane
- One release object promoted between environments
- One blocker-first board per active lane

## Lane taxonomy to institutionalize first

### Lane 1: `runtime-routing`

Purpose:
- tenant host routing
- cross-tenant leakage prevention
- dashboard and profile destination truth
- Studio redirect host truth
- footer parity on user-facing tenant surfaces

Canonical command:
- `bin/accept runtime-routing --env <dev|staging|prod>`

Existing building blocks to promote:
- `deploy/k8s/tenancy/tenant-registry.yaml`
- `tests/e2e/`
- `scripts/qa/verify-studio-sso-flow.sh`
- `scripts/qa/verify-footer-parity.sh`
- `scripts/release/emit-proof-envelope.sh`

Public helpers to deprecate:
- direct operator use of `scripts/qa/verify-*.sh` for routing decisions

### Lane 2: `identity-session`

Purpose:
- login flow continuity
- tenant-local auth/session expectations
- Studio SSO expectations
- cookie/session continuity across the right hosts

Canonical command:
- `bin/accept identity-session --env <dev|staging|prod>`

### Lane 3: `tenant-branding`

Purpose:
- DOM tenant identity hook
- rendered shell class/data attributes
- footer variant
- copy and visual differentiation

Canonical command:
- `bin/accept tenant-branding --env <dev|staging|prod>`

### Lane 4: `infra-realization`

Purpose:
- release object promotion
- GitOps pin correctness
- Argo controller convergence
- runtime deployment proof

Canonical command:
- `bin/accept infra-realization --env <dev|staging|prod>`

### Lane 5: `seed-bootstrap`

Purpose:
- tenant bootstrap data
- footer/config payloads
- first-run environment readiness

Canonical command:
- `bin/accept seed-bootstrap --env <dev|staging|prod>`

## Files to promote first

- Promote [`deploy/k8s/tenancy/tenant-registry.yaml`](../../../deploy/k8s/tenancy/tenant-registry.yaml) from “registry plus inference seed” to explicit tenant behavior contract.
- Promote [`bin/accept`](../../../bin/accept) to the only operator-documented human lane entrypoint.
- Promote [`scripts/release/emit-proof-envelope.sh`](../../../scripts/release/emit-proof-envelope.sh) from proof helper to proof-plane contract anchor.
- Promote [`docs/reference/operations/DEPLOYMENT_LANES.md`](../../reference/operations/DEPLOYMENT_LANES.md) and runtime lane docs so they describe release-object movement, not only overlay facts.

## Files and patterns to deprecate first

- Deprecate direct operator-facing references to opaque verifier names under `scripts/qa/verify-*.sh`.
- Deprecate volatile fields in tracked generated contract outputs.
- Deprecate generator-only route/auth rules that are not explicitly represented in the tenant contract.
- Deprecate tranche review spread across many tiny PRs when one coherent lane PR would do.

## 30/60/90 plan

### Days 1–30: make `runtime-routing` trustworthy

Success condition:
- `bin/accept runtime-routing --env dev|staging|prod` is the agreed truth surface.

Work:
1. Remove nondeterministic fields from tracked generated contract artifacts.
2. Extend tenant contract to carry explicit route/auth/session expectations rather than inferring them only in generators.
3. Freeze the runtime-routing proof bundle schema.
4. Update operator docs so public guidance always points to `bin/accept runtime-routing`.
5. Classify current runtime-routing validators into:
   - canonical internal helpers
   - compatibility shims
   - deprecations
6. Push flaky remote schema dependencies out of required CI or neutralize them with vendored/cached bundles.

Required outputs:
- deterministic browser matrix contract
- stable proof bundle schema
- blocker board template for active lanes

### Days 31–60: make promotion proof-driven

Success condition:
- environments consume release objects, not commit myths.

Work:
1. Define the release object schema in app repo and infra repo.
2. Make image publication emit one release object that binds:
   - app commit
   - image digests
   - tenant contract version
   - proof references
3. Make dev realization consume that release object.
4. Gate staging promotion on green dev proof.
5. Gate prod promotion on green staging proof plus tranche review.

Required outputs:
- release object schema
- promotion control path for dev, staging, prod
- post-deploy proof binding to release IDs

### Days 61–90: institutionalize `tenant-branding`

Success condition:
- tenant differentiation becomes a governed lane, not a subjective cleanup pass.

Work:
1. Define branding contract fields in the tenant contract.
2. Build `bin/accept tenant-branding --env <env>`.
3. Emit screenshot/trace-backed branding proof bundles.
4. Make branding review happen at tranche boundaries with proof deltas.
5. Remove remaining operator-facing dependence on raw verifier names for branding decisions.

Required outputs:
- tenant-branding proof schema
- branding DOM/render assertions
- stable screenshot/traces artifact layout

## CI tiering for this blueprint

### Required pre-merge

- syntax and lint
- deterministic generated drift
- changed-scope static validation
- lane-specific acceptance

### Required post-merge

- release object build
- environment deploy
- post-deploy proof

### Advisory or nightly

- broad repo audits
- expensive global drift scans
- remote dependency-heavy checks
- redundant confidence sweeps

## Review policy for this blueprint

- Review lane tranches, not tiny runtime confetti.
- Every lane PR must carry:
  - lane name
  - contract delta
  - proof delta
  - risk class
  - rollout notes
  - rollback plan

## Operator board template

For each active lane, keep exactly:

- Goal
- Current blocker
- Evidence
- Branch / PR / SHA
- Runtime state
- CI state
- Review state
- Next action

No diary updates. No “still pending” updates without blocker change.
