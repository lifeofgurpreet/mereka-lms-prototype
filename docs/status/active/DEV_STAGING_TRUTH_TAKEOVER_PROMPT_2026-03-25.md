# DEV / Staging Truth Takeover Prompt

You are taking over DEV/staging truth closure for `mereka-lms` and `bbi-infrastructure`.

Start by reading:

1. `docs/status/active/TODAY_WORKLOAD_TRACKER_2026-03-25.md`
2. `docs/status/active/DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
3. `docs/stabilization/STABILIZATION_CONTROL_BOARD.md`
4. `deploy/k8s/tenancy/tenant-registry.yaml`
5. `deploy/k8s/tenancy/STAGING_TENANT_CONTRACT.md`

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

Start with `W-01` from the daily tracker and then `T-01` from the deeper tracker.

Current blocker:

- staging canary secrets now exist
- the clean tracked staging-proof lane is still blocked because `.github/workflows/operations-gates-runtime.yml` is `disabled_manually`
- when manually enabled for a dispatch probe, GitHub rejects it with `HTTP 422` because the workflow currently defines top-level `permissions` twice

Your first job is to work from a clean branch/worktree off `origin/main`, repair the proof lane, and only then run a fresh tracked staging proof. Do not start by reopening dedicated staging cluster planning.

## Files to inspect immediately

### App repo

- `deploy/k8s/tenancy/tenant-registry.yaml`
- `deploy/k8s/tenancy/STAGING_TENANT_CONTRACT.md`
- `scripts/tenants/env/staging.env`
- `scripts/tenants/verify-staging-tenant-proof.sh`
- `deploy/k8s/overlays/staging/patches/production-staging.py`
- `.github/workflows/operations-gates-runtime.yml`
- `.github/workflows/smoke-authenticated.yml`

### Infra repo

- `apps/mereka-lms/overlays/staging/patches/ingress.yaml`
- `apps/mereka-lms/overlays/staging/patches/certificates.yaml`
- `apps/mereka-lms/overlays/staging/patches/caddy-env-patch.yaml`
- `config/nonprod-execution-state.yaml`

## Non-negotiable rules

- Do not treat local `var/proof/**` as canonical closure by itself.
- Do not claim staging is “ready” without a fresh tracked runtime/browser proof run.
- Do not flip `ready_for_execution: false` early.
- Do not paper over boundary contradictions by updating only docs or only runtime.
- Do not optimize repo-only QA while runtime truth is still contradictory.
- Do not restart dedicated staging cluster work before `2026-05-01`; that is explicitly deferred by operator decision.

## Required rerun commands

### App repo

- `bash scripts/qa/verify-deployment-contract.sh`
- `bash scripts/qa/verify-runtime-authority-map.sh`
- `bash scripts/qa/verify-lane-identity.sh`
- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`

### Infra repo

- `bash scripts/qa/verify-nonprod-gate-readiness.sh`
- `ENABLE_STAGING_CHECKS=1 bash scripts/qa/verify-staging-activation-gate.sh`

## Deliverables

Before stopping, leave behind all of the following:

1. code changes or PRs for the work you completed
2. updated `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
3. exact command outputs summarized in the tracker
4. explicit statement of which truth dimensions are now closed vs still open

## What counts as success

Minimum acceptable success for the next tranche:

- `operations-gates-runtime.yml` is syntax-valid and no longer parse-blocked
- at least one fresh tracked staging runtime/browser proof attempt exists
- cookie/browser behavior is either fixed or explicitly proven safe
- tracker is updated so the next handoff does not have to rediscover the state
