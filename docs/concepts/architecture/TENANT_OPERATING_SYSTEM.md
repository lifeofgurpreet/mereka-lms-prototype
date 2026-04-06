---
title: Tenant Operating System
owner: Platform Team
status: canonical
last_reviewed: 2026-04-03
last_verified: 2026-04-03
canonical_root: docs/concepts/architecture
doc_class: architecture-standard
audience:
  - Engineering Team
  - Platform Operators
  - Reviewers
summary: Defines the target tenant platform operating model: one contract plane, one acceptance plane, one proof plane, one delivery plane, and one review plane.
tags:
  - architecture
  - tenant.platform
  - runtime.truth
  - release.control
governs:
  - tenant.contract-plane
  - tenant.acceptance-plane
  - tenant.proof-plane
  - tenant.delivery-plane
  - tenant.review-plane
---
# Tenant Operating System

## Governs

- tenant.contract-plane
- tenant.acceptance-plane
- tenant.proof-plane
- tenant.delivery-plane
- tenant.review-plane

## Non-goals

- replacing every helper script immediately
- redesigning all product behavior in one tranche
- using CI green as the primary runtime oracle

## Problem Statement

The platform currently has too many loosely coupled truth layers:

1. app repo truth
2. generated artifact truth
3. CI and governance truth
4. image publication truth
5. infra repo and GitOps truth
6. Argo/controller truth
7. runtime config truth
8. browser truth

Each layer can be green while the product is still wrong. The goal of this operating system is to collapse those layers into one coherent pipeline where a tenant-facing change moves from contract edit to runtime proof with minimal ambiguity.

## Standard

### 1. Truth hierarchy

- Browser and runtime truth outrank static repo truth.
- Route, auth, and session truth outrank controller status.
- Controller and deployment truth outrank merge hygiene.
- Static repo truth remains necessary, but it is merge hygiene rather than product truth.

### 2. One contract plane

- Tenant-specific behavior MUST be defined in one canonical machine-readable contract.
- The tenant contract MUST explicitly define, per tenant and per environment:
  - LMS host
  - apps host
  - Studio host
  - allowed redirect destinations
  - forbidden cross-tenant hosts
  - dashboard and profile destinations
  - auth and session expectations
  - Studio SSO expectations
  - footer variant and payload expectations
  - branding variant and theme identity
- Generators MAY derive outputs from the contract, but they MUST NOT invent product rules that do not already exist in the contract.
- Tracked generated contract artifacts MUST be deterministic. They MUST NOT contain volatile fields such as generation timestamps.
- Proof bundles MAY include timestamps and runtime metadata because they are evidence artifacts, not tracked contract files.

### 3. One acceptance plane

- Every lane MUST expose exactly one human-facing acceptance command through [`bin/accept`](../../../bin/accept).
- [`bin/lms-ops`](../../../bin/lms-ops) MAY wrap the same lane internally as a platform control-plane entrypoint, but operator-facing documentation MUST bless [`bin/accept`](../../../bin/accept) as the public surface.
- The first institutional lane taxonomy is:
  - `runtime-routing`
  - `identity-session`
  - `tenant-branding`
  - `infra-realization`
  - `seed-bootstrap`
- New lane names MUST NOT be invented ad hoc in PRs, runbooks, or chat.

### 4. One proof plane

- Every lane acceptance run MUST emit one proof bundle with a stable schema.
- Proof bundles MUST separate:
  - contract snapshot
  - acceptance results
  - runtime evidence
  - final verdict
- Operators MUST be able to answer “is this working?” by reading the proof bundle without reconstructing chat history.

### 5. One delivery plane

- Work MUST move through lane trains rather than a stream of unrelated micro-PRs.
- At a given time, the system SHOULD have only one active lane blocker per lane and SHOULD keep the number of active lanes small enough that reviewers can reason about them.
- A merged commit is NOT live truth.
- A built image is NOT live truth.
- A GitOps mutation is NOT live truth.
- The durable promotion unit MUST become a release object that links:
  - app commit SHA
  - image digests
  - contract version
  - generated artifact hashes
  - proof bundle references
  - provenance metadata

### 6. One review plane

- Review MUST happen at tranche boundaries, not after every tiny correction.
- Delivery-impacting review MUST include:
  - lane
  - contract delta
  - proof delta
  - risk class
  - rollout notes
  - rollback plan
- Status updates MUST be blocker-first:
  - what changed
  - current blocker
  - next action

## Current canonical surfaces to keep

- [`deploy/k8s/tenancy/tenant-registry.yaml`](../../../deploy/k8s/tenancy/tenant-registry.yaml) as the current seed for tenant contract authority
- Playwright-based browser/runtime checks under [`tests/e2e/`](../../../tests/e2e)
- release/proof helpers such as [`scripts/release/emit-proof-envelope.sh`](../../../scripts/release/emit-proof-envelope.sh)
- script governance under [`scripts/governance/script-registry.yaml`](../../../scripts/governance/script-registry.yaml)
- Argo/GitOps realization in `bbi-infrastructure`

## Required structural corrections

- Remove volatile timestamps from tracked generated contract files.
- Move route, auth, and session rules out of generator-only logic and into the tenant contract.
- Keep one public human entrypoint per lane through [`bin/accept`](../../../bin/accept).
- Stabilize proof bundle schema before multiplying lanes.
- Prefer validators that inspect declared surfaces rather than one historical file layout.

## Target command surfaces

- `bin/accept runtime-routing --env <dev|staging|prod>`
- `bin/accept identity-session --env <dev|staging|prod>`
- `bin/accept tenant-branding --env <dev|staging|prod>`
- `bin/accept infra-realization --env <dev|staging|prod>`
- `bin/accept seed-bootstrap --env <dev|staging|prod>`

## Target release object

The release object is the promotion unit. A minimum viable schema is:

```yaml
schema_version: v1
release_id: rl_2026_04_03_runtime_routing_001
lane: runtime-routing
environment: dev
app_commit: 6cca8ce947a692c2e30fb42c5c6bd516ca16a2ae
tenant_contract_ref: tenant-registry@<sha>
generated_contracts:
  browser_matrix_sha256: <sha256>
images:
  openedx:
    repository: ghcr.io/biji-biji-initiative/mereka-lms/openedx
    tag: <git sha>
    digest: sha256:<digest>
  mfe:
    repository: ghcr.io/biji-biji-initiative/mereka-lms/mfe
    tag: <git sha>
    digest: sha256:<digest>
proof:
  acceptance_bundle: <uri-or-path>
  post_deploy_bundle: <uri-or-path>
provenance:
  build_run_id: <github run id>
  promoted_by: <actor or automation>
```

## Target proof bundle

A minimum viable lane proof bundle schema is:

```yaml
schema_version: v1
lane: runtime-routing
environment: dev
release_id: <release object id>
contract_snapshot:
  tenant_contract_ref: <path-or-sha>
  browser_matrix_ref: <path-or-sha>
assertions:
  - id: dashboard-route
    verdict: pass
    expected: apps tenant host
    observed: https://apps.biji-biji.academyv2.mereka.dev/dashboard
artifacts:
  logs: [...]
  screenshots: [...]
  traces: [...]
  runtime_config: [...]
verdict:
  result: pass
  failed_assertions: 0
```

## CI tiering

### Tier 0 — deterministic pre-merge, required

- syntax and lint
- deterministic generated drift
- contract consistency
- offline manifest validation
- changed-scope static checks

### Tier 1 — lane-specific acceptance, required

- run only the lane acceptance that matches the change surface
- keep time-bounded and environment-specific

### Tier 2 — post-merge deploy proof

- deploy the release object
- run post-deploy browser/runtime proof
- attach proof bundle to the lane board

### Tier 3 — nightly broad audits

- broad matrix checks
- expensive drift scans
- remote dependency heavy audits
- repo-wide confidence sweeps

## Review policy

- Review SHOULD target coherent lane tranches, not confetti PR streams.
- A lane tranche SHOULD be reviewed only when:
  - contract delta is explicit
  - acceptance bundle exists
  - rollout notes are concrete
  - rollback plan is concrete

## Deprecations to start now

- direct operator-facing use of opaque `scripts/qa/verify-*.sh` names
- tracked generated contract artifacts that contain timestamps
- hidden product rules encoded only in generators
- lane naming invented in PR descriptions or chat without taxonomy approval
- status updates that do not state the blocker and next action

## Fitness Functions

- `bin/accept runtime-routing --env dev`
- `scripts/qa/verify-deployment-lanes.sh`
- `scripts/release/emit-proof-envelope.sh --concern release-gate --lane dev --skip-cluster`

## Source ADRs

- `ADR-027`
- `ADR-028`
