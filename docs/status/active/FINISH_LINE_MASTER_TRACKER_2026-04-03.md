# Finish-Line Master Tracker

_Audience: Contributors and reviewers • Owner: Platform Team • Last verified:
2026-04-03T06:58:00Z • Status: active_

Use this tracker with:

- [`TENANT_OPERATING_SYSTEM_BLUEPRINT_2026-04-03.md`](./TENANT_OPERATING_SYSTEM_BLUEPRINT_2026-04-03.md)
- [`DOMAIN_TRUTH_CONVERGENCE_TRACKER_2026-03-31.md`](./DOMAIN_TRUTH_CONVERGENCE_TRACKER_2026-03-31.md)
- [`FINISH_LINE_TAKEOVER_PROMPT_2026-04-03.md`](./FINISH_LINE_TAKEOVER_PROMPT_2026-04-03.md)

## Current verified state

### repo_truth

- `mereka-lms#1302` merged the runtime-routing lane.
- `mereka-lms#1303` merged the truth-ledger / proof-plane lane.
- `mereka-lms#1304` merged the CI truth-control / cache-policy lane.
- `mereka-lms#1308` merged the app-side non-primary `apps.*` host repair.
- `mereka-lms#1309` merged the severity-aware CI baseline policy at
  `53ae16b4921d8824ac64a498b51a10c0ef5e269a`.
- `mereka-lms#1310` is open as the release-object foundation lane at head `5ca6da315`.

### infra_truth

- `bbi-infrastructure#2392` merged the GitOps-side realization repair at
  `995b15708370fe92b8d1b48536877c232565a967`.
- Dev Argo realization picked up the repaired non-primary `apps.*`
  runtime data after `#2392`.
- Release-object consumption in GitOps does not exist yet.
  Promotion is still human-joined across app SHA, digests, overlay,
  and runtime proof.

### runtime_truth

- Fresh dev runtime proof passed after the paired app+infra repair:
  - command: `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
  - status: pass for primary + `biji-biji` + `skillourfuture`
- Fresh staging runtime proof passed for the active tenant matrix:
  - command: `bash scripts/tenants/verify-staging-runtime-proof.sh --namespace stg-mereka-lms`
  - status: pass for primary + `biji-biji` + `skillourfuture`
- Prod is not closed. The all-tenant prod runtime-routing proof sweep
  has not been completed.

## Current control point

Do not spend another tranche rediscovering routing. The control point is now
authority convergence:

1. finish the release-object lane
2. bind promotion to that release object
3. collapse duplicate multisite runtime-data mutation paths
4. expand the same runtime-routing proof across the full tenant × environment matrix

## Authority convergence map

- Outer Caddy tenant routing
  - canonical owner repo: `mereka-lms`
  - consumer surface: `bbi-infrastructure` overlays and rendered manifests
  - live runtime authority: `caddy` deployment in the target namespace
  - proof command:
    `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
  - drift detector: `bash scripts/qa/verify-rke2-tenant-routes.sh --online`
  - current status: dev and staging verified, prod open
  - duplicate paths to retire: vendored Caddy copies without explicit provenance
- Multisite runtime data (`Site` / `SiteConfiguration`)
  - canonical owner repo: `mereka-lms`
  - consumer surface: seed/apply wrappers and Django bootstrap
  - live runtime authority: Django DB rows plus `/api/mfe_config/v1` behavior
  - proof command:
    `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
  - drift detector: `bash scripts/qa/verify-mfe-config-api.sh`
  - current status: improved, not converged; multiple seed paths still live
  - duplicate paths to retire:
    `seed-dev-sites.sh`, `seed-siteconfigs.sh`, `apply-multisite-config.sh`,
    `multisite_bootstrap_django.py`, `site-reconcile-common.sh`
- CI generated surfaces
  - canonical owner repo: `mereka-lms` script registry
  - consumer surface: inventories, verification catalog, CI precheck
  - live runtime authority: GitHub Actions `Static Validation Precheck`
  - proof command: `bash scripts/qa/verify-generated-surfaces.sh`
  - drift detector:
    `python3 scripts/qa/generate-verification-catalog.py --check` plus
    inventory `--check`
  - current status: converging; canonical front door exists
  - duplicate paths to retire: sidecar checks that bypass the front door
- Baseline debt authority
  - canonical owner repo: `mereka-lms` severity policy
  - consumer surface: PR merge policy and reviewer decision
  - live runtime authority: latest `main` CI fail set
  - proof command:
    `python3 scripts/ci/generate_ci_failure_baseline.py ...`
  - drift detector: baseline artifact plus
    `verification/manifests/ci_failure_severity_policy.json`
  - current status: severity policy merged, burn-down still open
  - duplicate paths to retire: hand-waved baseline-only decisions without
    machine artifact
- Release object
  - canonical owner repo: `mereka-lms`
  - consumer surface: future GitOps promotion path
  - live runtime authority: build artifact, then environment promotion
  - proof command: `bash scripts/qa/verify-release-object.sh <path>`
  - drift detector: pending `#1310` merge
  - current status: in flight on `#1310`
  - duplicate paths to retire:
    manual joining of commit SHA, digests, overlay, and proof
- Runtime target identity
  - canonical owner repo: cross-repo
  - consumer surface: operators, proof runners, GitOps
  - live runtime authority: current kubectl context, Argo app, namespace, and
    expected hosts
  - proof command: `bash scripts/qa/ops-preflight.sh --strict`
  - drift detector:
    `bash scripts/infra/verify-release-preflight.sh --env <dev|staging|prod>`
  - current status: partial; no single target-identity preflight yet
  - duplicate paths to retire: ad hoc context and namespace reasoning in shell
    history

## Paired rollout units

- Non-primary `apps.*` runtime repair
  - app PR: `#1308`
  - infra PR: `#2392`
  - target env: dev
  - proof after merge:
    `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
  - status: verified
- Release-object foundation
  - app PR: `#1310`
  - infra PR: not started
  - target env: build artifact / next GitOps consumer
  - proof after merge: `bash scripts/qa/verify-release-object.sh <artifact>`
  - status: in flight

## Dependency graph

The finish line is gated, not chronological.

1. high-severity baseline blockers removed or explicitly policy-classified
2. app repo runtime truth fixed
3. GitOps consumer truth fixed
4. runtime data reconciled by one canonical path
5. Argo realizes the intended revision
6. live proof passes
7. then expand across tenant matrix and environments

## Baseline debt program

- `verify-secret-classification`
  - severity: `high`
  - merge policy: `must_block_even_if_baseline`
  - disposition: fixed by `#1307`, keep enforced
- `verify-tutor-version-pin`
  - severity: `high`
  - merge policy: `must_block_even_if_baseline`
  - disposition: keep enforced
- `verify-certificate-branding`
  - severity: `low`
  - merge policy: `allow_if_baseline_only`
  - disposition: inherited debt; move to branding lane or cleanup lane
- `job::Static Validation*` wrappers
  - severity: `medium`
  - merge policy: `review_required_if_baseline`
  - disposition: keep classified, avoid treating job wrappers as root cause
- Shared shard failures such as:
  - `verify-a11y-contrast-focus`
  - `verify-brand-asset-drift`
  - `verify-catalog-discovery`
  - `verify-mfe-reduced-motion`
  - `verify-migration-lock`
  - `verify-theming-generated-artifacts`
  - `verify-verify-script-reachability`
  - severity: default `medium` until reclassified
  - merge policy: `review_required_if_baseline`
  - disposition: move to explicit burn-down lane after `#1310`

## Execution board

- `F-01`
  - priority: `P0`
  - owner: app repo
  - outcome: merge `#1310` or classify it as baseline-only with no branch
    failures
  - current state: in flight
- `F-02`
  - priority: `P0`
  - owner: cross-repo
  - outcome: build the GitOps consumer for release objects
  - current state: open
- `F-03`
  - priority: `P0`
  - owner: app repo
  - outcome: collapse multisite seeding to one canonical runtime-data
    reconciler
  - current state: open
- `F-04`
  - priority: `P0`
  - owner: app repo
  - outcome: add a runtime target identity preflight that prints cluster, Argo,
    namespace, and host expectation
  - current state: open
- `F-05`
  - priority: `P0`
  - owner: app repo
  - outcome: run full dev runtime-routing matrix for all active tenants after
    current `main` settles
  - current state: open
- `F-06`
  - priority: `P1`
  - owner: app repo
  - outcome: run the same matrix on staging
  - current state: open
- `F-07`
  - priority: `P1`
  - owner: app repo
  - outcome: build current-site / MFE-config / ingress regression coverage for
    each host type
  - current state: open
- `F-08`
  - priority: `P1`
  - owner: app repo
  - outcome: burn down medium baseline static debt in a dedicated lane
  - current state: open
- `F-09`
  - priority: `P2`
  - owner: docs
  - outcome: retire stale duplicate trackers once this authority-linked tracker
    is the active board
  - current state: open

## Exact verification commands

### Runtime proof

- `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
- `bash scripts/tenants/verify-staging-runtime-proof.sh --namespace stg-mereka-lms`
- `bash scripts/qa/verify-rke2-tenant-routes.sh --online`
- `bash scripts/qa/verify-mfe-config-api.sh`

### Release / CI truth

- `python3 scripts/ci/generate_ci_failure_baseline.py --repo`
  `Biji-Biji-Initiative/mereka-lms --branch-run-id <run>`
  `--baseline-run-id <run> --output <file>`
- `bash scripts/qa/verify-generated-surfaces.sh`
- `bash scripts/qa/verify-ci-cache-policy.sh`
- `bash scripts/qa/verify-release-object.sh <path-to-release-object.json>`

### Target identity / preflight

- `bash scripts/qa/ops-preflight.sh --strict`
- `bash scripts/infra/verify-release-preflight.sh --env <dev|staging|prod>`

## Do not claim this program closed unless

1. every active tenant passes runtime-routing proof across dev, staging, and prod
2. release-object build is merged and GitOps consumes it
3. promotion evidence, truth ledger, and runtime proof all point at the
   same release ID
4. high-severity baseline debt is zero
5. one canonical runtime-data reconciler owns `Site` / `SiteConfiguration` mutation
6. runtime target identity is proven before mutation or proof runs
7. no critical repair exists only as an unmerged app/infra pair
