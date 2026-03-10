# Wave 10 Source Of Truth Map
_Audience: Reviewers, operators, and agents • Owner: Platform Team • Last verified: 2026-03-10 • Status: canonical_

## Purpose

This map defines which repo is authoritative for each major cross-repo operational truth domain and which human-facing surfaces are projections only.

Use it before changing:

- release lanes
- topology
- service identity
- promotion semantics
- runtime review and evidence expectations
- deployment contract surfaces

## Rules

1. The authoritative repo wins.
2. Human-facing front doors are projections unless explicitly named authoritative here.
3. Agents should start from machine-readable contracts and generated packs first, then read projection docs.
4. If a projection drifts from its source contract, the projection is wrong.

## Domain map

### Release lanes

- authoritative repo: `platform-control-plane`
- authoritative files:
  - `/home/gurpreet/projects/platform-control-plane/contracts/release-contracts.yaml`
  - `/home/gurpreet/projects/platform-control-plane/contracts/service-identity-contract.yaml`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/docs/guides/PROMOTION-WORKFLOW.md`
  - `/home/gurpreet/projects/k8s/mereka-lms/docs/reference/operations/RELEASE_PROCESS.md`
- drift risk: `high`

### Service identity / aliases

- authoritative repo: `platform-control-plane`
- authoritative files:
  - `/home/gurpreet/projects/platform-control-plane/contracts/service-identity-contract.yaml`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/CLAUDE.md`
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/docs/reference/SERVICE_IDENTITY_REFERENCE.md`
- drift risk: `high`

### Domain registry / hostnames

- authoritative repo: `bbi-infrastructure`
- authoritative files:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/config/domain-registry.yaml`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/docs/reference/CANONICAL_TOPOLOGY.md`
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/ENVIRONMENTS.md`
- drift risk: `medium`

### Bootstrap lane topology

- authoritative repo: `bbi-infrastructure`
- authoritative files:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/config/bootstrap-lane-topology.yaml`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/docs/reference/CANONICAL_TOPOLOGY.md`
  - `/home/gurpreet/projects/k8s/mereka-lms/docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
- drift risk: `high`

### Promotion workflow semantics

- authoritative repo: `bbi-infrastructure`
- authoritative files:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/scripts/promote.sh`
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/.github/workflows/promote-image.yml`
  - `/home/gurpreet/projects/platform-control-plane/contracts/release-contracts.yaml`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/docs/guides/PROMOTION-WORKFLOW.md`
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/CLAUDE.md`
- drift risk: `high`

### Runtime review / evidence rules

- authoritative repo: `mereka-lms`
- authoritative files:
  - `/home/gurpreet/projects/k8s/mereka-lms/docs/ops/runbooks/DEPLOY_EVIDENCE_GATES.md`
  - `/home/gurpreet/projects/k8s/mereka-lms/docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
  - `/home/gurpreet/projects/k8s/mereka-lms/tools/knowledge/verify_review_runtime.py`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/mereka-lms/docs/meta/docs-program/WAVE9_REVIEW_HANDOFF.md`
- drift risk: `high`

### OpenTofu backend / workspace rules

- authoritative repo: `platform-control-plane`
- authoritative files:
  - `/home/gurpreet/projects/platform-control-plane/specs/SPEC-CP-002-state-and-workspace-model.md`
  - `/home/gurpreet/projects/platform-control-plane/scripts/plan-all.sh`
- derived human surfaces:
  - `/home/gurpreet/projects/platform-control-plane/docs/RELEASE-CONTROL-IMPLEMENTER-PLAYBOOK.md`
- drift risk: `medium`

### App deployment contracts

- authoritative repo: `mereka-lms`
- authoritative files:
  - `/home/gurpreet/projects/k8s/mereka-lms/deploy/k8s/contract.json`
  - `/home/gurpreet/projects/k8s/mereka-lms/config/lane-identity.yaml`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/mereka-lms/docs/reference/operations/CANONICAL_DEPLOY_CONTRACT.md`
- drift risk: `high`

### Canonical entrypoints

- authoritative repo: `mereka-lms`
- authoritative files:
  - `/home/gurpreet/projects/k8s/mereka-lms/scripts/governance/canonical-entrypoints.yaml`
- derived human surfaces:
  - `/home/gurpreet/projects/k8s/mereka-lms/docs/README.md`
  - `/home/gurpreet/projects/k8s/bbi-infrastructure/docs/README.md`
- drift risk: `medium`

## Validation entrypoints

- `mereka-lms`: `python3 tools/docs/verify/verify-doc-catalog-governance.py --range origin/main...HEAD`
- `mereka-lms`: `bash scripts/qa/run-review-runtime-gates.sh`
- `bbi-infrastructure`: `make verify`
- `platform-control-plane`: `./scripts/plan-all.sh --validate-only`
