# Onboarding Documentation
_Audience: Developers + Agent Operators • Owner: Platform Team • Last verified: 2026-04-22 • Status: canonical_

## Scope
This is the canonical onboarding index for local setup and daily development workflow.

## Start here

- Need the fastest local bootstrap:
  - [`QUICK_START_LOCAL.md`](QUICK_START_LOCAL.md)
- Need the full canonical setup:
  - [`LOCAL_SETUP.md`](LOCAL_SETUP.md)
- Need the day-to-day command flow after setup:
  - [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md)
- Working in a devcontainer instead of a host install:
  - [`DEVCONTAINER_GUIDE.md`](DEVCONTAINER_GUIDE.md)
- Coordinating with multiple contributors or agents:
  - [`MULTI_DEVELOPER_WORKFLOW.md`](MULTI_DEVELOPER_WORKFLOW.md)

## Proof lane

- Offline source/docs contract:
  - `./scripts/qa/verify-cold-start-onboarding-contract.sh`
- Initialized local Tutor proof after setup:
  - `./scripts/infra/verify-local-bootstrap-readiness.sh`
- Fresh bootstrap proof:
  - [`.github/workflows/bootstrap-local-readiness.yml`](../../../.github/workflows/bootstrap-local-readiness.yml)
- App-cache-cold image-build proof:
  - [`.github/workflows/build-benchmark.yml`](../../../.github/workflows/build-benchmark.yml) with `benchmark_class=app-cache-cold` and `image_family=both`
- Developer environment proof matrix:
  - [`../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`](../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md)

Do not call onboarding fixed from docs-only review. The contract verifier proves source and guide consistency. The bootstrap workflow proves a clean repo-scoped Tutor launch path. The `benchmark_class=app-cache-cold` benchmark proves image-build helpers with app-level BuildKit cache imports disabled. It is not a machine-cold clean-room build: a persistent runner may still have Docker daemon/base-image state, and a local developer machine can still fail for host-resource reasons.

Current proof contract from 2026-04-22:

- The offline onboarding contract is `./scripts/qa/verify-cold-start-onboarding-contract.sh`.
- Local initialized-state proof is `./scripts/infra/verify-local-bootstrap-readiness.sh`.
- Fresh first-boot CI proof is `.github/workflows/bootstrap-local-readiness.yml`.
- App-cache-cold image proof is `.github/workflows/build-benchmark.yml` with `benchmark_class=app-cache-cold` and `image_family=both`.
- Current GitHub state must be checked live with `gh run list` / `gh run view` or the active tracking issue; this index must not be treated as a frozen latest-run dashboard.

Accepted proof history and current gaps live in
[`../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`](../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md).
If a newer change touches Tutor source, render prep, build helpers, or bootstrap
workflow behavior, re-run the matching proof before calling onboarding fixed.

The local setup path must stay one source chain: Tutor source/config plus `docker-bake.hcl` build helpers. It builds `openedx:nightly` and `openedx-mfe:nightly`, renders Tutor to those local tags, applies the named dependency-image mirror patch for Tutor-emitted hardcoded Docker Hub refs, selects the repo-owned BuildKit dependency-mirror builder as a fallback guard, and uses `mirror.gcr.io` image refs where Tutor exposes them. Mirror use is dependency acquisition, not a second build strategy.

## Canonical onboarding set

- [`README.md`](README.md)
- [`QUICK_START_LOCAL.md`](QUICK_START_LOCAL.md)
- [`LOCAL_SETUP.md`](LOCAL_SETUP.md)
- [`WORKFLOW_LOCAL.md`](WORKFLOW_LOCAL.md)
- [`DEVCONTAINER_GUIDE.md`](DEVCONTAINER_GUIDE.md)
- [`MULTI_DEVELOPER_WORKFLOW.md`](MULTI_DEVELOPER_WORKFLOW.md)
- [`REPOSITORY_GUIDE.md`](REPOSITORY_GUIDE.md)
- [`COURSE_IMPORT_GUIDE.md`](COURSE_IMPORT_GUIDE.md)

## Supporting guide

- [`AGENT_SETUP_CHECKLIST.md`](AGENT_SETUP_CHECKLIST.md) for agent-oriented preflight only

## Security note

Do not store local usernames, passwords, tokens, or copied service credentials in this directory.
Use the local setup flow to create a local-only admin password at bootstrap time, and use
[`../admin/SECRETS_MANAGEMENT_GUIDE.md`](../admin/SECRETS_MANAGEMENT_GUIDE.md) plus
[`../../ops/runbooks/SECRET_ROTATION_CHECKLIST.md`](../../ops/runbooks/SECRET_ROTATION_CHECKLIST.md)
if a credential is ever exposed.

## What this directory is not

Do not use this directory for:
- low-level operator procedures that belong in `docs/ops/**`
- stable architecture front doors that belong in `docs/architecture/**`
- active status or proof that belongs in `docs/status/**` or `docs/evidence/**`
