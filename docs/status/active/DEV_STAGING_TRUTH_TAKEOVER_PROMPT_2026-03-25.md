# DEV / Staging Truth Takeover Prompt

You are taking over DEV/staging truth closure for `mereka-lms` and `bbi-infrastructure`.

Start by reading:

1. `docs/status/active/DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
2. `docs/stabilization/STABILIZATION_CONTROL_BOARD.md`
3. `deploy/k8s/tenancy/tenant-registry.yaml`
4. `deploy/k8s/tenancy/STAGING_TENANT_CONTRACT.md`

Then work from the tracker in order. Do not re-invent the queue.

## Mission

Make DEV and staging operational in a way that is truthful across:

- runtime behavior
- tenant host/domain contract
- browser-auth behavior
- release/evidence closure
- GitOps ownership boundaries
- topology / cutover state

The objective is not “more green.” The objective is “no false closure.”

## Immediate first task

Start with `T-01` from the tracker: resolve the staging hostname contract split.

Current contradiction:

- canonical tenant contract says `studio.staging...` / `apps.staging...`
- staging env seed data and staging Python settings still use `staging.studio...` / `staging.apps...`
- GitOps staging ingress/certs route the canonical `studio.staging...` / `apps.staging...` shape
- live staging proof on 2026-03-25 returned `5/9`

Your first job is to choose and enforce one hostname convention, then rerun staging proof until it reaches `9/9`.

## Files to inspect immediately

### App repo

- `deploy/k8s/tenancy/tenant-registry.yaml`
- `deploy/k8s/tenancy/STAGING_TENANT_CONTRACT.md`
- `scripts/tenants/env/staging.env`
- `scripts/tenants/verify-staging-tenant-proof.sh`
- `deploy/k8s/overlays/staging/patches/production-staging.py`

### Infra repo

- `apps/mereka-lms/overlays/staging/patches/ingress.yaml`
- `apps/mereka-lms/overlays/staging/patches/certificates.yaml`
- `apps/mereka-lms/overlays/staging/patches/caddy-env-patch.yaml`
- `config/nonprod-execution-state.yaml`
- `docs/reference/staging-cluster-provisioning-pack.md`

## Non-negotiable rules

- Do not treat local `var/proof/**` as canonical closure by itself.
- Do not claim staging is “ready” while host acceptance is below `9/9`.
- Do not flip `ready_for_execution: false` early.
- Do not paper over boundary contradictions by updating only docs or only runtime.
- Do not optimize repo-only QA while runtime truth is still contradictory.

## Required rerun commands

### App repo

- `bash scripts/qa/verify-deployment-contract.sh`
- `bash scripts/qa/verify-runtime-authority-map.sh`
- `bash scripts/qa/verify-lane-identity.sh`
- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`

### Infra repo

- `bash scripts/qa/verify-nonprod-gate-readiness.sh`
- `ENABLE_STAGING_CHECKS=1 bash scripts/qa/verify-staging-activation-gate.sh`
- `bash scripts/qa/verify-staging-cutover-prereqs.sh --no-color`
- `bash scripts/ops/staging-cutover-preflight.sh`

## Deliverables

Before stopping, leave behind all of the following:

1. code changes or PRs for the work you completed
2. updated `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
3. exact command outputs summarized in the tracker
4. explicit statement of which truth dimensions are now closed vs still open

## What counts as success

Minimum acceptable success for the next tranche:

- staging hostname contract split is resolved across app repo, GitOps, and live proof
- staging tenant proof becomes `9/9`
- cookie/browser behavior is either fixed or explicitly proven safe
- tracker is updated so the next handoff does not have to rediscover the state
