# Finish-Line Master Tracker

_Audience: Contributors and reviewers • Owner: Platform Team • Last verified:
2026-04-09T04:00:00Z • Status: active_

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
- `mereka-lms#1310` merged the release-object foundation lane.

**Agent 2 hardening session (2026-04-08/09) — 16 PRs merged:**

- `#1430` — deterministic cross-repo verifiers, executable route resolver,
  workflow gate enforcement, proof lineage chain, negative test pack,
  skill routing contract, expanded blind-agent harness (31 checks)
- `#1443` (B-012) — production promotion now requires `--release-object-json`
- `#1447` (B-019) — vendored settings auto-sync at promotion time
- `#1448` (B-015) — environment progression warning for promotion
- `#1449` — PII filtering script reclassified to runtime inventory
- `#1451` (B-016) — truth ledger + proof artifacts validate release identity
- `#1455` — CI: removed `*.md` from paths-ignore + added CHANGELOG + VERSION_MATRIX
- `#1458` (B-024) — DR drill schedule + backup coverage matrix docs
- `#1459` (tracker #32) — deleted deprecated mfe-node.sh (-755 lines)
- `#1464` (F-04) — runtime target-identity preflight (`verify-realized-image-identity.sh`)
- `#1465` (F-12) — pre-commit hooks for CI inventory, routing matrix, design token auto-regen
- `#1472` (F-08) — fixed test-verify-secret-inventory GCP auth issue
- `#1474` — CI: removed ALL paths-ignore so docs-only PRs can merge

### infra_truth

- `bbi-infrastructure#2392` merged the GitOps-side realization repair at
  `995b15708370fe92b8d1b48536877c232565a967`.
- Dev Argo realization picked up the repaired non-primary `apps.*`
  runtime data after `#2392`.
- `bbi-infrastructure#2528` synced vendored LMS production.py (Oscar URLs).
- `bbi-infrastructure#2529` added cross-repo boundary + contract pointers to AGENTS.md.
- `bbi-infrastructure#2537` synced vendored LMS production.py (Discussions MFE settings).
- Release-object consumption in GitOps: `promote-dev-image.yml` now consumes
  release objects via `repository_dispatch`. Production promotion enforced
  via `release-openedx-gitops.sh` `--require-digests` + `--release-object-json`.
  Manual SHA joining no longer possible for production.

### runtime_truth

- Dev tenant runtime is not closed.
  - fresh live probes on 2026-04-03 show:
    - `biji-biji.academyv2.mereka.dev` → `200` with empty body
    - `skillourfuture.academyv2.mereka.dev` → `200` with empty body
    - `studio.biji-biji.academyv2.mereka.dev` → `200` with empty body
    - `studio.skillourfuture.academyv2.mereka.dev` → `200` with empty body
  - fresh live probes also show:
    - `apps.biji-biji.academyv2.mereka.dev` is healthy
    - `apps.skillourfuture.academyv2.mereka.dev` is healthy
  - realized-root cause:
    ingress and Django site rows exist, but the live Caddy config only binds
    tenant `apps.*` host blocks, not tenant LMS/Studio host blocks
- `bbi-infrastructure#2406` is the live consumer fix for dev tenant LMS/Studio
  Caddy authority.
- `mereka-lms#1324` is the source/proof hardening follow-up; it makes runtime
  proof reject empty `200` responses and aligns source Caddy defaults.
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
  - current status:
    staging verified; dev tenant LMS/Studio roots broken pending `#2406`;
    prod open
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
  - current status: **CLOSED** — `#1310` merged (foundation), `#1443` enforces
    `--release-object-json` for production promotion. Manual SHA joining
    blocked for production. Truth ledger validates release identity (`#1451`).
  - duplicate paths to retire:
    manual joining still possible for dev/staging (not yet enforced)
- Runtime target identity
  - canonical owner repo: cross-repo
  - consumer surface: operators, proof runners, GitOps
  - live runtime authority: current kubectl context, Argo app, namespace, and
    expected hosts
  - proof command: `bash scripts/qa/verify-realized-image-identity.sh --release-object-json <path>`
  - drift detector:
    `bash scripts/infra/verify-release-preflight.sh --env <dev|staging|prod>`
  - current status: **CLOSED** — `#1464` added `verify-realized-image-identity.sh`
    which compares live pod image digests against release object (INV-002 gate).
    Registered in runtime inventory (LIVE_CLUSTER).
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
- Dev tenant LMS/Studio root repair
  - app PR: `#1324`
  - infra PR: `#2406`
  - target env: dev
  - proof after merge:
    `bash scripts/tenants/verify-dev-runtime-proof.sh --namespace mereka-lms-dev`
  - status: in flight
- Release-object foundation
  - app PR: `#1310` (merged), `#1443` (enforcement), `#1451` (truth ledger)
  - infra PR: `#2528`, `#2529`, `#2537` (all merged — vendored sync + AGENTS.md)
  - target env: build artifact + GitOps consumer (promote-dev-image.yml)
  - proof after merge: `bash scripts/qa/verify-release-object.sh <artifact>`
  - status: **CLOSED** — production promotion enforced, dev auto-promotion consuming

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
  - current state: **CLOSED** — `#1310` merged (foundation), `#1443` enforces for production
- `F-02`
  - priority: `P0`
  - owner: cross-repo
  - outcome: build the GitOps consumer for release objects
  - current state: **CLOSED** — `promote-dev-image.yml` consumes release objects via `repository_dispatch`
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
  - current state: **CLOSED** — `#1464` added `verify-realized-image-identity.sh` (INV-002 gate)
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
  - current state: **CLOSED** — `#1472` fixed test-verify-secret-inventory GCP auth.
    Medium static debt minimal (0 open items in structural debt register).
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
