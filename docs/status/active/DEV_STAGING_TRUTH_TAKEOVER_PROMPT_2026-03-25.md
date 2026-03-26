# DEV / Staging Truth Takeover Prompt

You are taking over DEV/staging truth closure for `mereka-lms`, `bbi-infrastructure`, and `platform-control-plane`.

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

Current blocker chain:

- staging canary secrets now exist
- the workflow-parse defect on `operations-gates-runtime.yml` is already fixed on `origin/main`
- the app-side repair tranche is already published as `mereka-lms#1048`
- the control-plane host-contract repair is already merged as `platform-control-plane#65`
- the GitOps host-realization repair is already merged as `bbi-infrastructure#2128`
- the active-owner cert-manager repair is now also merged as `bbi-infrastructure#2131`
- the Biji-Biji staging TLS lane is live:
  - `letsencrypt-bijibiji-staging` is `Ready=True`
  - `openedx-biji-biji-lms-tls`, `openedx-biji-biji-mfe-tls`, and `openedx-biji-biji-studio-tls` are all `Ready=True`
- scoped staging governance/auth/config gates now pass from the clean worktree
- the remaining open work is narrower:
  - merge or explicitly classify `mereka-lms#1048`
  - produce fresh tracked staging browser/runtime proof
  - classify any residual Argo health state after the tracked proof rather than treating cert-manager as the active blocker
  - keep the control-plane “pending external dependency” posture distinct from runtime/app truth

Your first job is to work from a clean branch/worktree off `origin/main`, then shepherd `mereka-lms#1048` through merge and run a fresh tracked staging proof. Do not start by reopening dedicated staging cluster planning.

## Files to inspect immediately

### App repo

- `deploy/k8s/tenancy/tenant-registry.yaml`
- `deploy/k8s/tenancy/STAGING_TENANT_CONTRACT.md`
- `scripts/tenants/env/staging.env`
- `scripts/qa/run-operations-gates.sh`
- `scripts/qa/audit-auth-access.sh`
- `scripts/qa/run-multisite-governance-gates.sh`
- `scripts/qa/verify-mfe-config-contract.sh`
- `scripts/tenants/verify-staging-tenant-proof.sh`
- `scripts/shared/multisite_bootstrap.py`
- `scripts/shared/multisite_bootstrap_django.py`
- `scripts/tenants/lib/site-reconcile-common.sh`
- `scripts/tenants/provision-mfe-config.sh`
- `.github/workflows/operations-gates-runtime.yml`
- `.github/workflows/smoke-authenticated.yml`

### Infra repo

- `apps/mereka-lms/overlays/staging/patches/caddy-config-staging.yaml`
- `apps/mereka-lms/overlays/staging/patches/certificates.yaml`
- `config/domain-registry.yaml`
- `config/nonprod-execution-state.yaml`

### Control-plane repo

- `contracts/staging-dns-cert-readiness.yaml`
- `scripts/guardrails/verify-staging-dns-cert-readiness.sh`
- `scripts/guardrails/verify-control-plane-merge-safety.sh`

## Non-negotiable rules

- Do not treat local `var/proof/**` as canonical closure by itself.
- Do not claim staging is “ready” without a fresh tracked runtime/browser proof run.
- Do not flip `ready_for_execution: false` early.
- Do not paper over boundary contradictions by updating only docs or only runtime.
- Do not stop at repo-only QA while runtime host realization is still contradictory.
- Do not restart dedicated staging cluster work before `2026-05-01`; that is explicitly deferred by operator decision.

## Required rerun commands

### App repo

- `bash scripts/qa/verify-deployment-contract.sh`
- `bash scripts/qa/verify-runtime-authority-map.sh`
- `bash scripts/qa/verify-lane-identity.sh`
- `bash scripts/qa/verify-staging-vocabulary-drift.sh`
- `bash scripts/qa/verify-mfe-config-contract.sh --env staging`
- `bash scripts/qa/audit-auth-access.sh --env staging --mode public`
- `bash scripts/qa/run-multisite-governance-gates.sh --env staging`
- `bash scripts/tenants/verify-staging-tenant-proof.sh --namespace stg-mereka-lms`

### Infra repo

- `bash scripts/qa/verify-nonprod-gate-readiness.sh`
- `ENABLE_STAGING_CHECKS=1 bash scripts/qa/verify-staging-activation-gate.sh`
- `make verify`

### Control-plane repo

- `./scripts/guardrails/verify-staging-dns-cert-readiness.sh`
- `./scripts/guardrails/verify-control-plane-merge-safety.sh`
- `./scripts/plan-all.sh --validate-only`

## Deliverables

Before stopping, leave behind all of the following:

1. code changes or PRs for the work you completed
2. updated `DEV_STAGING_TRUTH_TRACKER_2026-03-25.md`
3. exact command outputs summarized in the tracker
4. explicit statement of which truth dimensions are now closed vs still open
5. clear classification of whether the remaining blocker is app-owned, GitOps-owned, or workflow-owned

## What counts as success

Minimum acceptable success for the next tranche:

- `mereka-lms#1048` is merged or explicitly classified by blocker, and `platform-control-plane#65` plus `bbi-infrastructure#2128` are verified as merged/applied or explicitly blocked at runtime
- the remaining hostname blocker is either fixed live or explicitly proven to still be live after the PR chain
- the old Biji-Biji cert-manager blocker is not restated as current if live runtime already shows it closed
- at least one fresh tracked staging runtime/browser proof attempt exists once the contract stops contradicting itself
- tracker is updated so the next handoff does not have to rediscover the state
