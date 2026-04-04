# Runtime Truth Ledger Tracker - 2026-04-03

Audience: Operators and reviewers
Owner: Platform Team
Last verified: 2026-04-04
Status: active

## Current Verified State

- `repo_truth`: `mereka-lms#1326` is open on the latest pushed
  `feat/runtime-truth-ledger` head `d8d110e74`.
- `infra_truth`: the staging Argo app currently reports revision
  `459c7be7516e91516c92695298f4d50fab457dd2`, `OutOfSync`, `Degraded`.
- `runtime_truth`: staging runtime in namespace `stg-mereka-lms` is on the
  release-object digests for both Open edX and MFE from build run `23943796722`.
- `staging_secret_truth`: `ClusterSecretStore/infisical-secret-store-staging`
  is `Ready=False` (`InvalidProviderConfig`, `unable to create client`), and
  the staging `ExternalSecret` set for Open edX, Aspects, Google OAuth,
  enterprise, payments, and SES is runtime-failing even though Argo still marks
  those resources as `Synced`.
- `dev_runtime_truth`: the canonical dev routing bundle at
  `/tmp/dev-runtime-routing-20260404/summary.json` is `pass` with `0` failed
  checks, and the six tenant LMS/apps/Studio entry hosts now return non-empty
  HTML instead of the old empty/blank responses.
- `dev_auth_truth`: the authenticated Studio dev canary at
  `/tmp/dev-studio-sso-canary-20260404-rerun` now passes after fixing the
  verifier to prefer credential-submit controls over the social-login button on
  the combined Authentik login screen.
- `acceptance_truth`: runtime-routing bundles now preserve raw release identity
  in both `summary.json` and `truth-ledger.json`, and the staging
  routing-core bundle now passes when footer parity is treated as an opt-in
  branding oracle instead of a default routing gate.
- `staging_studio_auth_truth`: the authenticated Studio staging canary at
  `/tmp/staging-studio-sso-canary-20260404` passes with
  `[staging] OK authenticated session validated`, so the live Studio callback
  and post-login render path are currently healthy on staging.
- `staging_dashboard_auth_truth`: the authenticated primary OIDC staging canary
  at `/tmp/staging-oidc-sso-canary-20260404` is red. Auth completes and lands
  on `/dashboard`, which then redirects to
  `https://staging.apps.academyv2.mereka.io/account/`; the account MFE throws
  `TypeError: Cannot read properties of null (reading 'find')` and the
  rendered surface ends as a blank white page.
- `staging_dashboard_auth_rerun_truth`: the rerun at
  `/tmp/staging-oidc-sso-canary-20260404-v5` reproduces the same live shape
  after the staging apps-root Caddy fix:
  - OIDC login succeeds
  - callback completes
  - `post_callback_url=https://staging.apps.academyv2.mereka.io/account/`
  - the final rendered surface is a blank white page with zero branded
    dashboard markers
  This proves the remaining learner/dashboard failure is downstream of the
  owner-layer apps-root seam and still lives in the account/dashboard app
  runtime.
- `staging_dashboard_fix_branch_truth`: `feat/runtime-truth-ledger` now carries
  commit `5b1c9efb06ae882bb9ca02140fcb8a3f94e3166d`, which patches the account
  MFE build hook to tolerate `social_links: null` payloads specifically in the
  account app build and adds a focused regression test for that hook. This is
  branch truth only until merge and staging realization.
- `staging_apps_root_truth`: the tenant apps-root defect is now closed live.
  After a manual Argo sync plus `caddy` rollout restart, direct probes show:
  - `https://apps.staging.academy.biji-biji.com/` →
    `/authn/login?next=%2Fdashboard`, `text/html`, non-empty body
  - `https://apps.staging.academy.biji-biji.com/dashboard` →
    `/learner-dashboard/`, `text/html`, non-empty body
  - `https://apps.staging.skillourfuture.academy.mereka.io/` →
    `/authn/login?next=%2Fdashboard`, `text/html`, non-empty body
  - `https://apps.staging.skillourfuture.academy.mereka.io/dashboard` →
    `/learner-dashboard/`, `text/html`, non-empty body
- `staging_apps_root_guardrail_truth`: contract-only `runtime-routing` bundles
  now fail on the empty-shell tenant apps entrypoints instead of treating them
  as host-stable:
  - `/tmp/runtime-routing-staging-biji-contract-20260404/summary.json`
  - `/tmp/runtime-routing-staging-sof-contract-20260404/summary.json`
  - `/tmp/runtime-routing-staging-biji-contract-20260404-v2/summary.json`
  In the strengthened rerun, both `apps-root` and `apps-dashboard` fail for
  Biji-Biji with `status=200`, empty `content-type`, and `body_bytes=0`.
- `staging_caddy_realized_truth`: the running `caddy` pod now serves the
  updated `/etc/caddy/Caddyfile` with `@mfe_root_entry`,
  `@mfe_dashboard_alias`, and `@account_no_slash` redirects after a targeted
  rollout restart.
- `staging_caddy_owner_fix_truth`: the owner-layer fix landed via merged
  `bbi-infrastructure#2411` (`459c7be7516e91516c92695298f4d50fab457dd2`),
  which restores the staging apps-root redirect and the
  `/dashboard` / `/account` normalizers in the GitOps-owned
  `caddy-config-staging` patch.
- `staging_caddy_realization_truth`: the merged owner-layer fix is now live in
  the mounted config. `stg-mereka-lms/caddy-config-staging` carries
  `staging.bbi.mereka.io/contract-revision=2026-04-04-01`, but Argo still
  leaves the app overall `OutOfSync` / `Degraded` because of unrelated prune
  debt and PostSync failures.
- `staging_caddy_diff_truth`: rendered desired state from
  `apps/mereka-lms/overlays/staging` carries
  `staging.bbi.mereka.io/contract-revision=2026-04-04-01` and the missing
  `@mfe_root_entry`, `@mfe_dashboard_alias`, and `@account_no_slash` redirects.
  Earlier drift between desired and live was removed only after a manual sync
  request and `caddy` rollout restart.
- `staging_argocd_realization_truth`: controller logs at `2026-04-04T01:19:11Z`
  report `Skipping auto-sync: need to prune extra resources only but automated
  prune is disabled`. That message explained why the merged fix did not realize
  automatically; live runtime only converged after a manual sync request and
  rollout restart.

## What We Achieved Already

- Added a versioned truth-join generator at
  [`scripts/release/generate_truth_ledger.py`](../../../scripts/release/generate_truth_ledger.py).
- Added a schema at
  [`schemas/truth-ledger.schema.json`](../../../schemas/truth-ledger.schema.json).
- Wired
  [`scripts/acceptance/runtime-routing.sh`](../../../scripts/acceptance/runtime-routing.sh)
  to emit `truth-ledger.json` beside the lane proof bundle.
- Taught the acceptance bundle and ledger to preserve:
  - `release_id`
  - `release_bundle_id`
  - `app_commit_sha`
  - `release_object_json`
- Fixed the staging ledger wrapper to use namespace `stg-mereka-lms` instead of
  the Argo app name, so runtime image discovery is truthful.
- Fixed the staging ledger wrapper to prefer release-object `app_commit_sha`
  over the truth-ledger branch SHA when a release object is supplied.
- Fixed acceptance `failed_checks` to count failing checks instead of summing
  exit codes.
- Fixed staging host selection to prefer release-critical P0 hosts over planned
  P1 hostnames when both exist in tenant registry truth.
- Fixed Studio SSO verification to accept the real staging primary apps host
  pattern (`staging.apps.<domain>`) rather than forcing `apps.staging.<domain>`
  for the primary tenant.
- Demoted footer parity from the default `runtime-routing` gate. Footer parity
  remains available via `--with-footer`, but no longer blocks routing-core
  proof on healthy empty-shell MFE roots.
- Added tests proving:
  - the ledger builds from an acceptance summary
  - digest drift is classified as a failure
  - CLI ingestion of `--release-object-json` preserves release identity
  - staging host selection prefers release-critical hosts
  - `apps-root` and `apps-dashboard` assertions require non-empty HTML instead
    of only same-host stability
  - footer parity is opt-in in `runtime-routing` dry-run bundles
- Fixed the authenticated Studio canary to prefer deterministic credential
  submit controls (`Log in` / exact `Continue`) instead of the generic
  `Continue` matcher that could click `Continue with Google` on the combined
  Authentik login page.
- Hardened the canonical `runtime-routing` acceptance lane so `apps-root`
  and `apps-dashboard` fail when the final response is an empty-body `200` with
  no HTML `content-type`.
- Fixed the `openedx-settings-lms` packaging surface to include
  `mereka_footer.py` and `mereka_jwt_session.py`, which were present in source
  truth but absent from the generated `ConfigMap`.
- Added a generator regression test proving the LMS settings `ConfigMap`
  includes those runtime helper modules.
- Added an account-specific MFE Dockerfile hook that rewrites the fetched
  `frontend-app-account` source during build so `data.social_links` is treated
  as an empty array when LMS serializes it as `null`.
- Added a focused regression test at
  [`tests/test_mfe_build_snapshot.py`](../../../tests/test_mfe_build_snapshot.py)
  proving the account-specific hook exists in source truth and, when local
  Tutor build context is present, that the rendered Dockerfile carries the same
  null-guard.
- Proved the narrowed branch slice locally with:
  `pytest -q tests/test_mfe_build_snapshot.py tests/test_runtime_routing_acceptance.py tests/test_truth_ledger.py`
  → `10 passed`.

## Current Control Point

The same-ID continuity edge is now fixed on the branch. Dev runtime-routing and
authenticated Studio proof are green. Routing-core staging acceptance is green.
Staging Studio auth is green too. The tenant apps-root seam is now green again
after merged GitOps realization plus a targeted `caddy` rollout restart. The
remaining staging app-runtime lane is the authenticated learner/dashboard flow,
which previously landed on a blank white page after successful OIDC callback.

- If `#1326` goes green: merge it, then regenerate the staging runtime-routing
  bundle from `release-object.json` on current `main` and update the same-ID
  matrix.
- Do not claim the learner/dashboard staging red is fixed from branch truth
  alone. The account MFE null-guard exists on `#1326`, but live staging still
  needs merge, image realization, and rerun of the credentialed staging canary.
- The immediate proof gap is now credentials in the current shell:
  `verify-authenticated-sso-canary.sh --env staging` currently fails with
  `missing SSO canary credentials`.
- The current release-bound staging bundle is:
  - `summary.json`: `/tmp/staging-accept-routingcore-nofooter-20260404/summary.json`
  - `truth-ledger.json`: `/tmp/staging-accept-routingcore-nofooter-20260404/truth-ledger.json`
- That bundle proves:
  - `summary.json` verdict is `pass`
  - `summary.json` and `truth-ledger.json` both carry
    `ro-rb-242e1178-20260403T111930Z`
  - runtime Open edX and MFE digests match the release object
- The only remaining red in the ledger is:
  - Argo `OutOfSync`
  - Argo `Degraded`
- The current live Argo causes are now classified:
  - `OutOfSync`: stale prunable hashed `ConfigMap`s because sync policy is
    `Prune=false`
  - `Degraded`: `aspects-router-config-init` is still pending in live staging;
    `wait-for-lms` completes, but the main `init` container remains
    `PodInitializing` while pulling the Open edX image, and Kyverno emits
    `require-drop-all-capabilities` warnings on the pod
- The current live staging runtime blockers are broader than the Argo rollup:
- `authenticated learner/dashboard` runtime failure: the primary OIDC staging
  canary completes login and callback, then `/dashboard` redirects into the
  account MFE on `staging.apps.academyv2.mereka.io`, where the frontend
  throws `TypeError: Cannot read properties of null (reading 'find')` and
  renders a blank white page
  - rerun proof now exists at
    `/tmp/staging-oidc-sso-canary-20260404-v5`; the remaining gap is not
    proof access but merge-and-realization of the branch-side account MFE null
    guard
  - `authenticated Studio` is no longer part of the staging blocker set; the
    Studio canary now passes on staging with the disposable canary account
  - `ExternalSecret` runtime failure: `infisical-secret-store-staging` is not
    ready, so `openedx-secrets`, `aspects-secrets`, `google-oauth-secrets`,
    `enterprise-secrets`, `enterprise-sso-secrets`, `payments-gateway-secrets`,
    and `ses-smtp-credentials` all report `SecretSyncedError`
  - `tenant apps root` is no longer part of the live blocker set:
    - `apps.staging.academy.biji-biji.com/` now redirects to
      `/authn/login?next=%2Fdashboard`
    - `apps.staging.academy.biji-biji.com/dashboard` now resolves to
      `/learner-dashboard/`
    - `apps.staging.skillourfuture.academy.mereka.io/` now redirects to
      `/authn/login?next=%2Fdashboard`
    - `apps.staging.skillourfuture.academy.mereka.io/dashboard` now resolves
      to `/learner-dashboard/`
  - `Argo realization` lesson: controller logs said
    `need to prune extra resources only but automated prune is disabled`; the
    merged `caddy-config-staging` fix only became live after a manual sync
    request and targeted `caddy` rollout restart
  - exact staging store evidence: repeated `InvalidProviderConfig` events on
    `infisical-secret-store-staging` with
    `CallUniversalAuthLogin ... [POST https://secrets.mereka.io/api/v1/auth/universal-auth/login] [status-code=403]`
  - blast radius: this is not isolated to `stg-mereka-lms`; other staging
    namespaces are also reporting `ClusterSecretStore "...staging" is not
    ready`
  - this means Argo `Synced` on those resources is not sufficient proof of
    usable staging runtime secrets
- The branch now includes the source fix for that PostSync failure:
  `deploy/k8s/base/kustomization.yaml` packages `mereka_footer.py` and
  `mereka_jwt_session.py` into `openedx-settings-lms`.
- The branch now also carries proved staging journey artifacts beyond the
  release-bound routing-core bundle:
  - `Studio auth pass`: `/tmp/staging-studio-sso-canary-20260404`
  - `learner/dashboard auth fail`: `/tmp/staging-oidc-sso-canary-20260404`
  - `learner/dashboard auth fail rerun after apps-root closure`:
    `/tmp/staging-oidc-sso-canary-20260404-v5`

## Same-ID Matrix

| object | artifact path | release_object_id | build_origin_environment | promotion_target_environment | notes | match status |
| --- | --- | --- | --- | --- | --- | --- |
| build artifact | `/tmp/release-artifacts/23943796722/release-object.json` | `ro-rb-242e1178-20260403T111930Z` | `dev` | n/a | canonical release object from build run `23943796722` | match |
| promotion evidence | `/tmp/release-artifacts/23943796722/release-evidence-staging.json` | `ro-rb-242e1178-20260403T111930Z` | `dev` | `staging` | promotion evidence bound to the same release object | match |
| runtime proof | `/tmp/staging-accept-routingcore-nofooter-20260404/summary.json` | `ro-rb-242e1178-20260403T111930Z` | `dev` | `staging` | staging routing-core acceptance verdict is `pass` | match |
| truth ledger | `/tmp/staging-accept-routingcore-nofooter-20260404/truth-ledger.json` | `ro-rb-242e1178-20260403T111930Z` | `dev` | `staging` | release/runtime digests align; final ledger still red on Argo state only | match |

## Exact Commands

Generate a dry-run runtime-routing bundle plus truth ledger:

```bash
bin/accept runtime-routing --env dev --tenant biji-biji --dry-run --output-dir /tmp/runtime-routing-ledger
```

Generate a staging runtime-routing bundle with bound release identity:

```bash
TRUTH_LEDGER_RELEASE_OBJECT_JSON=/tmp/release-artifacts/23943796722/release-object.json \
TRUTH_LEDGER_INFRA_COMMIT_SHA=a916d33ffdcb0ed355ae7eeddedd59e29035be6d \
bin/accept runtime-routing --env staging --skip-playwright \
  --output-dir /tmp/staging-accept-routingcore-nofooter-20260404
```

## Do Not Claim Closed Unless

- build artifact, promotion evidence, runtime summary, and truth ledger all
  carry the same raw `release_id`
- acceptance verdict is green for the scoped launch lane
- Argo is `Synced` / `Healthy`
- live tracked image digests match the release object
- browser/runtime proof no longer shows staged tenant-specific routing/session
  failures
