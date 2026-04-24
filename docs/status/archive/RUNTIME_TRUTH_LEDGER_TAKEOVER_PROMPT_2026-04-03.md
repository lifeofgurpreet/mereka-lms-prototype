# Runtime Truth Ledger Takeover Prompt — 2026-04-03

Read first:

1. [`docs/status/active/RUNTIME_TRUTH_LEDGER_TRACKER_2026-04-03.md`](RUNTIME_TRUTH_LEDGER_TRACKER_2026-04-03.md)
2. [`docs/ops/EXECUTION_DOCTRINE.md`](../../ops/EXECUTION_DOCTRINE.md)
3. [`scripts/acceptance/runtime-routing.sh`](../../../scripts/acceptance/runtime-routing.sh)
4. [`scripts/release/generate_truth_ledger.py`](../../../scripts/release/generate_truth_ledger.py)

Immediate first task:

- Read `mereka-lms#1326` on the latest pushed head, not the older
  checkpoint named earlier in this doc.
- Latest pushed branch head is `d8d110e74`; the staging learner blank-page
  source fix remains commit `5b1c9efb06ae882bb9ca02140fcb8a3f94e3166d`:
  - it patches the account-only MFE Dockerfile hook so fetched
    `frontend-app-account` source tolerates `social_links: null`
  - it adds `tests/test_mfe_build_snapshot.py`
  - local validation for that branch slice is:
    `pytest -q tests/test_mfe_build_snapshot.py tests/test_runtime_routing_acceptance.py tests/test_truth_ledger.py`
    → `10 passed`
- Preserve the now-proved dev truth:
  - `/tmp/dev-runtime-routing-20260404/summary.json` is green
  - `/tmp/dev-studio-sso-canary-20260404-rerun` passed authenticated Studio
    proof after fixing the verifier to avoid the `Continue with Google` trap
- Re-run the staging runtime-routing lane with
  `TRUTH_LEDGER_RELEASE_OBJECT_JSON=/tmp/release-artifacts/23943796722/release-object.json`
  if you need fresh artifacts.
- Then classify only the remaining operational ledger failures; do not reopen
  the release-identity problem unless the raw `release_id` disappears again.
- Treat the new account MFE fix as branch truth only until it is merged and
  staging is reproved. Do not mark the staging learner/dashboard lane closed
  from the branch commit alone.
- Preserve the proved staging journey split:
  - `/tmp/staging-studio-sso-canary-20260404` passed authenticated Studio
    proof on live staging
  - `/tmp/staging-oidc-sso-canary-20260404` failed after successful OIDC
    callback because `/dashboard` redirected into
    `https://staging.apps.academyv2.mereka.io/account/`, where the account MFE
    crashed into a blank white page
  - `/tmp/staging-oidc-sso-canary-20260404-v5` reproduces the same failure
    after the tenant apps-root seam was fixed live:
    - OIDC login succeeds
    - callback completes
    - `post_callback_url=https://staging.apps.academyv2.mereka.io/account/`
    - final render is still a blank white page with zero branded learner
      dashboard markers
  - treat that rerun as proof that the remaining live learner/dashboard blocker
    is inside the account/dashboard app runtime, not the GitOps-owned apps-root
    redirect seam
  - historical red: `https://apps.staging.academy.biji-biji.com/` and
    `https://apps.staging.skillourfuture.academy.mereka.io/` previously
    returned empty-body `200` at the tenant apps root
  - the canonical acceptance lane proved that red directly:
    - `/tmp/runtime-routing-staging-biji-contract-20260404/summary.json`
    - `/tmp/runtime-routing-staging-sof-contract-20260404/summary.json`
    - `/tmp/runtime-routing-staging-biji-contract-20260404-v2/summary.json`
  - the strengthened rerun proved the bug was not only `/`: direct tenant apps
    `/dashboard` is also an empty-body `200`, and the contract now marks both
    `apps-root` and `apps-dashboard` red
  - live `stg-mereka-lms/caddy-config-staging` explained that symptom: its
    `@mfe` block previously proxied `/api/mfe_config/v1*` and `/login_refresh*`
    to LMS, then sent everything else directly to `mfe:8002` without the
    tenant apps-root redirect or `/dashboard`/`/account` normalizers
  - owner-layer patch landed as merged `bbi-infrastructure#2411`
    (`459c7be7516e91516c92695298f4d50fab457dd2`)
  - Argo compared the merged revision but did not realize the live config until
    a manual sync request plus `caddy` rollout restart
  - the mounted `stg-mereka-lms/caddy-config-staging` object now carries
    `staging.bbi.mereka.io/contract-revision=2026-04-04-01`
  - direct live probes now show the tenant apps-root seam is fixed:
    - `https://apps.staging.academy.biji-biji.com/` →
      `/authn/login?next=%2Fdashboard`, `text/html`, non-empty
    - `https://apps.staging.academy.biji-biji.com/dashboard` →
      `/learner-dashboard/`, `text/html`, non-empty
    - `https://apps.staging.skillourfuture.academy.mereka.io/` →
      `/authn/login?next=%2Fdashboard`, `text/html`, non-empty
    - `https://apps.staging.skillourfuture.academy.mereka.io/dashboard` →
      `/learner-dashboard/`, `text/html`, non-empty
  - controller logs at `2026-04-04T01:19:11Z` say:
    `Skipping auto-sync: need to prune extra resources only but automated prune
    is disabled`
  - treat that as the reason the merged config did not realize automatically;
    the current open runtime lane is learner/dashboard auth, not tenant
    apps-root
- Treat staging as a layered blocker set, not a single app bug:
  - learner/dashboard post-login runtime defect on the primary staging LMS host
  - the learner canary was rerun successfully by reusing the staging Studio
    canary account; proof access is no longer the blocker for this lane
  - `aspects-router-config-init` is currently stuck before process start on
    `mereka-np-k8s-wk-02-sin1`
  - `infisical-secret-store-staging` is `Ready=False`, and staging
    `ExternalSecret` resources are runtime-failing even though Argo still shows
    them as `Synced`
  - the staging store failure is explicit:
    `CallUniversalAuthLogin ... [POST https://secrets.mereka.io/api/v1/auth/universal-auth/login] [status-code=403]`
  - this has staging-wide blast radius beyond `stg-mereka-lms`, so do not
    treat it as an app-only blocker

Non-negotiable rules:

- Do not claim runtime closure from PR merge alone.
- Do not claim live truth from Argo sync alone.
- Do not hand-join repo, infra, Argo, and runtime state in chat when the
  ledger can record it.
- Keep `bin/accept` as the human front door.
- Keep release continuity and operational closure separate. The same-ID chain
  can be fixed while the ledger is still red on Argo state.
- Do not regress the authenticated Studio canary back to a generic
  `Continue` matcher. The live Authentik page combines credential login with a
  `Continue with Google` button, so proof must prefer deterministic credential
  submit controls.
- Do not let footer parity block routing-core acceptance by default. Footer
  parity is now opt-in via `--with-footer` because MFE bare-root `200` with an
  empty shell is not a routing defect.
- Do not let the old host-stability check hide this failure again. `apps-root`
  and `apps-dashboard` now require non-empty HTML, so empty-body `200` is a
  hard red.
- Do not regress the new staging truth split back into a generic “staging is
  just red on secrets.” Studio auth is green, tenant apps-root is now green,
  and learner/dashboard auth remains the live app-runtime lane.
- Treat the remaining Argo red concretely:
  - `OutOfSync` is stale prunable hashed `ConfigMap`s under `Prune=false`
  - `Degraded` is not enough by itself; also check the staging
    `ClusterSecretStore` and real `ExternalSecret` readiness because Argo sync
    status hides provider failures there

Current branch/worktree:

- app follow-on branch: `feat/runtime-truth-ledger`
- worktree: `/tmp/mereka-truth-ledger`

Minimum acceptable success before stopping:

- runtime-routing proof bundle emits both `summary.json` and `truth-ledger.json`
  with the same raw `release_id` and `release_bundle_id` from the supplied
  `release-object.json`
- truth ledger is schema-stable and test-covered
- routing-core acceptance is either green or any remaining red is named as
  routing/session truth, not branding-shell noise
- any remaining ledger red is named as operational truth with exact failing
  checks, not collapsed back into release continuity ambiguity
