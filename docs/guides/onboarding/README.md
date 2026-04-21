# Onboarding Documentation
_Audience: Developers + Agent Operators • Owner: Platform Team • Last verified: 2026-04-21 • Status: canonical_

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

Current proof snapshot from 2026-04-21:

- Static validation PR proof `24727872257` on `8ce05a308`: success.
- App-cache-cold image build run `24721668598` on `39ae0fb86`: success.
- Last accepted bootstrap baseline run `24711453019` on `e7a4472cd`: success.
- Current-main bootstrap rerun `24730265503` on `12db1b6`: success after Buildx cleanup and fastlane hook repair. This is initialized-state proof, not MFE authn route or branded theme asset proof.
- Earlier current-main bootstrap runner failure evidence on `9a1090657` and `4754a8cd` was fastlane Docker/containerd pull/extract failure while pulling `mirror.gcr.io/overhangio/openedx:21.0.4`, not local guide contract failure.
- Known coverage gaps from the green rerun (current-main run `24730265503`): `http://apps.localhost/authn/login` returned HTTP 400 during a direct runner probe because Django rejected `apps.localhost`, and LMS logs reported `Theme 'mereka' not found` while using the upstream bootstrap image. This branch fixes the MFE host source contract, makes the route fail closed in local readiness, and skips SiteTheme convergence when the running image lacks the repo-owned theme directory.
- Branch bootstrap run `24736358890` on `1506f9d90` was cancelled by the runner/control plane during active migrations. Rerun `24737898005` then exposed stale `tutor_local` Docker project state from that cancellation on the persistent runner. This branch now removes stale Tutor containers/volumes/networks before checkout and makes canonical Tutor plugin enablement idempotent when the plugin is already listed in `TUTOR_ROOT/config.yml`.
- Branch bootstrap run `24738471266` on `878994d0c`: success on `lane_mode=fallback`. It passed pre-clean, render, image refresh, `tutor local launch -I --skip-build`, image provenance, and local readiness. Readiness proved `http://apps.localhost/authn/login` returned HTTP 302. The launch phase took about 56 minutes, so timing/heartbeat artifacts remain follow-up debt for operator feedback.

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
