# Cold-start Onboarding Proof Lane - 2026-04-20

Status: active
Last verified: 2026-04-21

## Supersession Note - 2026-04-23

This file remains a historical baseline for the cold-start/onboarding proof
lane. It is no longer the current build-authority closure board. Use
[`BUILD_AUTHORITY_CLOSURE_TRACKER_2026-04-23.md`](./BUILD_AUTHORITY_CLOSURE_TRACKER_2026-04-23.md)
for the active closure plan and
[`DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`](../../reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md)
for current proof-class definitions and accepted evidence snapshots.

## Current Verified State

- `repo_truth`: current `main` is `48dc97927` after PR #2000. The local quick-start source contract, bounded build-optimization delta contract, repo-owned runner Buildx cleanup, Bootstrap Local Readiness timing artifact contract, k8s/onboarding truth-alignment contracts, and Build Tutor Images diagnostics coverage remain the app-repo truth surfaces.
- `infra_truth`: `.github/workflows/bootstrap-local-readiness.yml` is the clean bootstrap proof lane. `build-benchmark.yml` with `benchmark_class=app-cache-cold` / `image_family=both` is the separate app-cache-cold image-build proof lane. The old `true-cold` input remains a legacy alias only; the proof class disables app-level BuildKit cache imports but does not prove a pristine Docker daemon or absent base images on persistent runners. App repo Kustomize proof owns base/local contracts; production and rke2 environment overlays are infra-owned unless an explicit require flag is set.
- `proof_truth`: app-cache-cold image-build proof `24721668598` is green on `39ae0fb86`; last accepted bootstrap baseline `24711453019` is green on `e7a4472cd`; then-current-main bootstrap rerun `24730265503` is green on `12db1b6` after Buildx cleanup and fastlane hook repair; PR #1991 branch bootstrap `24738471266` is green on `878994d0c`; post-#1991-merge Bootstrap Local Readiness `24743995049` is green on `2b86de83`; PR #1998 static CI `24747204826` is green and proves the bootstrap timing artifact contract only; PR #1997 CI was green before merge and local isolated validation passed the k8s/onboarding truth contracts before merge. Post-#1998 Bootstrap Local Readiness `24747538663` is still in progress, post-#1997 Bootstrap Local Readiness `24748203836` is still queued/pending, and neither is closure evidence until completed green. Build Tutor Images runs remain separate image-build proof and must not be collapsed into bootstrap proof; current rerun `24749060617` is still in progress on `4f6b75175`.
- `runtime_truth`: local/bootstrap proof is green for the last completed main bootstrap evidence as initialized-state proof only, not for the latest `main` head until a current-head Bootstrap Local Readiness run completes. PR #1991 branch and post-merge main proof are green for the local MFE authn HTTP route (`http://apps.localhost/authn/login` returned HTTP 302) and upstream-image unbranded behavior. It does not prove GitOps realization, live cluster runtime, browser-rendered MFE login, or branded theme assets in a repo-built image.

## What We Achieved Already

- Found a real quick-start defect: `scripts/shared/setup-local.sh` resolved `REPO_ROOT` to `scripts/` instead of the repo root.
- Found real proof-lane debt: the bootstrap proof assumed `docker compose`, and the legacy `true-cold` benchmark lane was not actually capable of proving its app-cache-cold contract from the requested inputs.
- Removed legacy and unsafe quick-start behavior from the setup path:
  - no direct `apply-patches.sh` front door
  - no hardcoded Tutor MySQL root password
  - no fixed local admin password
  - no opportunistic production-sync prompt
- Added an offline source/docs contract: `./scripts/qa/verify-cold-start-onboarding-contract.sh`.
- Updated onboarding docs to name the source contract, initialized-state verifier, and heavy clean-run workflow separately.
- Added a canonical post-render Tutor patch for local MySQL `MYSQL_ROOT_HOST` and tightened the workflow to upload `config.redacted.yml` instead of raw local Tutor secrets.
- Tightened local image detection from broad `docker images | grep` matching to exact `docker image inspect openedx:nightly` / `openedx-mfe:nightly`, with `FORCE_LOCAL_IMAGE_BUILD=1` for explicit rebuild proof.
- Found and fixed a real local source/render mismatch: the quick-start path built `openedx:nightly` but did not force Tutor to use `DOCKER_IMAGE_OPENEDX=openedx:nightly`; it also copied a config example that disabled local MongoDB while the guide expected `mongodb`. Local setup now explicitly enables local backing services and points Tutor at the local Open edX/MFE tags it builds.
- Current-head bootstrap run `24675535840` failed before Tutor launch because the ARC runner hit Docker Hub anonymous pull limits on `docker.io/mongo:7.0.28`. CI and local first-run dependency acquisition now use mirrored image refs under `mirror.gcr.io`; this is a dependency-acquisition correction, not a new build strategy.
- The failed bootstrap artifact also showed that the redacted config snapshot did not suppress a generated multi-line private key after a blank line. The workflow redactor now skips blank and indented continuation lines for secret keys before artifact upload.
- Fixed Tutor 21 hook drift: LMS/CMS asset safe_join now renders through `openedx-common-assets-settings`, and dead `mfe-dockerfile-npm-install` ownership moved to `patches/mfe-npm-install-resilience.sh`.
- Proved an isolated local Tutor render and render verifier with `TUTOR_ROOT=/tmp/mereka-lms-coldstart-render` and `TUTOR_PLUGINS_ROOT=/tmp/mereka-lms-coldstart-plugins`.
- Reclassified stale Kustomize/static checks so the app repo enforces base/local manifests while production and rke2 overlays remain infra-owned. This is an authority correction, not a waiver.
- Removed the app-repo live Velero CronJob patcher path from DR docs/spec plans and made restore-test repair GitOps-owned. The app repo now keeps audit and verification scripts, not source-of-truth production mutations.
- Repaired secret classification to match active ExternalSecret keys, repaired Paragon token verification so it does not refresh tracked core CSS in CI, and guarded manual TruffleHog runs so they use a Git diff range and never scan stale `.git` object packs.
- Registered `scripts/qa/verify-restore-drill.sh` as runtime/live-cluster DR proof and regenerated the runtime inventory/catalog. This is a script-governance authority correction, not a new static CI lane.
- Added a developer environment proof matrix that reserves future k8s preview and Devspace lanes as consumers of the same source/build contracts, not new build strategies.
- Found and fixed a current-head benchmark proof defect: run `24678695027` let the MFE measured-build job conclude green while its uploaded context recorded `OUTCOME=failure`. Measured build failure now exits non-zero after writing diagnostic artifacts.
- Current-head benchmark run `24680694038` proved the fail-closed behavior but also proved BuildKit registry mirror config is insufficient by itself: Open edX and MFE still fell back to Docker Hub for hardcoded upstream dependency refs and hit anonymous pull limits. The follow-up fix is explicit, named dependency-image mirror normalization for the known Tutor-emitted Dockerfile frontend/base/helper refs, plus the BuildKit mirror as a fallback guard.
- Current-main bootstrap run `24730265503` closed the runner/containerd blocker but exposed two proof-coverage gaps: `http://apps.localhost/authn/login` returned HTTP 400 during a direct runner probe because Django rejected `apps.localhost` as an `ALLOWED_HOSTS` value, and the LMS logged `Theme 'mereka' not found` while serving from the upstream bootstrap image. This branch fixes the MFE authn source contract, makes the route fail-closed in local readiness, and skips SiteTheme convergence when the running image lacks `/openedx/themes/mereka`; branch bootstrap run `24738471266` proved that updated path.
- Branch bootstrap run `24736358890` on fastlane reached migrations and then received GitHub's `The operation was canceled` without a source stack trace. Treat that result as runner/workflow substrate cancellation. The bootstrap workflow now exposes `lane_mode=fallback` so the same source/render/artifact proof can be forced onto ARC while fastlane is investigated; this is not a new build path.
- Branch bootstrap rerun `24737898005` then failed during render because the previous cancelled run left stale `tutor_local` Docker project state on the persistent runner and the wrapper suppressed the underlying Tutor plugin-enable output. The source fix is bounded runner hygiene plus plugin idempotence: pre-checkout cleanup now removes stale Tutor containers/volumes/networks, the cleanup helper image is mirror-backed, and `scripts/infra/tutor-config-save.sh` logs Tutor output while accepting the already-enabled canonical-plugin state.
- Exact-head branch bootstrap rerun `24738471266` on `878994d0c` passed with `lane_mode=fallback`: pre-clean, render, image refresh, `tutor local launch -I --skip-build`, image provenance, and local readiness were all green. Readiness proved `http://apps.localhost/authn/login` returned HTTP 302.

## Current Control Point

Current truth: the lane is locally source-green, PR #1991 branch bootstrap
proof is green on `878994d0c`, the latest completed main Bootstrap Local
Readiness proof is green on `2b86de83`, and PR #1998 has merged the phase
timing artifact contract with static CI proof only, PR #1997 merged the
k8s/onboarding truth alignment at `addb05cb0`, and PR #2000 merged the
proof-state guard at `48dc97927`. In this branch, a clean manual local render
also passed after creating `.venv` and installing `requirements-tutor.txt`:
`tutor-config-save.sh` completed plugin sync, retired local `indigo`, config
save, build-context prep, and `verify-tutor-config`. The next control point is
to keep these contracts green on any build-path edit, preserve one source ->
render -> artifact chain, wait for queued/in-progress Bootstrap Local Readiness
runs before calling newer heads closed, wait for Build Tutor Images rerun
`24749060617` before calling the image-build lane closed, dispatch
`bootstrap-local-readiness.yml` with `lane_mode=fallback` if fastlane remains
under investigation, and classify any red result by authority:

```bash
bash -n scripts/shared/setup-local.sh scripts/qa/verify-setup.sh scripts/qa/verify-cold-start-onboarding-contract.sh scripts/qa/verify-cicd-merge-gates-and-secrets.sh
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/qa/verify-bootstrap-workflow-contract.sh
./scripts/qa/test-verify-bootstrap-workflow-contract.sh
./scripts/qa/verify-build-optimizations-render-delta-contract.sh
./scripts/qa/test-verify-build-optimizations-render-delta-contract.sh
./scripts/qa/test-install-docker-compose.sh
./scripts/qa/test-mfe-npm-install-resilience-patch.sh
./scripts/qa/test-mfe-prune-deprecated-shells.sh
./scripts/qa/verify-cicd-tutor-plugin-test.sh
./scripts/qa/verify-cicd-merge-gates-and-secrets.sh
./scripts/qa/verify-k8s-images.sh
./scripts/qa/verify-kustomize-structure.sh
./scripts/qa/verify-kustomize-render.sh
./scripts/qa/verify-network-policies.sh
./scripts/qa/verify-secrets-isolation.sh
./scripts/qa/verify-secret-classification.sh
./scripts/qa/verify-paragon-tokens.sh
./scripts/qa/verify-disaster-recovery.sh --skip-cluster
python3 scripts/governance/generate-ci-static-inventory.py --check
python3 scripts/qa/spec-tools/validate_testmap_format.py specs/_generated/testmaps/
python3 scripts/qa/spec-tools/mereka_spec_lint.py specs/ --severity-filter error
./scripts/qa/verify-new-ci-static-entries.sh
./scripts/qa/verify-generated-surfaces.sh
./scripts/qa/lint-repo-conventions.sh
git diff --check
```

Current-head GitHub proof examples:

```bash
CURRENT_HEAD="$(git rev-parse origin/main)"
gh run list --branch main --limit 20 \
  --json databaseId,workflowName,status,conclusion,headSha,createdAt,event \
  --jq ".[] | select(.headSha == \"${CURRENT_HEAD}\") | [.databaseId,.workflowName,.status,(.conclusion//\"\"),.event,.createdAt] | @tsv"
```

## Execution Board

| Priority | Work | Owner | State | Proof |
|---|---|---|---|---|
| P0 | Fix setup script root/path/security drift | app repo | local green | `bash -n`, contract verifier |
| P0 | Make quick-start docs copy-paste truthful | docs | local green | contract verifier markdown link check |
| P0 | Keep local setup image/service authority truthful | app repo + docs | local render proved: `openedx:nightly`, `openedx-mfe:nightly`, local services enabled, mirrored third-party pulls, BuildKit dependency-mirror builder selected before local builds | isolated Tutor render + `verify-cold-start-onboarding-contract.sh` |
| P0 | Remove Docker Hub anonymous quota from bootstrap dependency acquisition | CI | latest completed main bootstrap proof green on `2b86de83` (`24743995049`); PR #1998 static CI `24747204826` proves the timing artifact contract only, not bootstrap closure | `verify-bootstrap-workflow-contract.sh`, bootstrap workflow green run |
| P0 | Ensure heavy workflow covers doc/setup drift | CI | local green | `verify-bootstrap-workflow-contract.sh`, workflow path trigger review |
| P1 | Run clean Tutor bootstrap proof | CI runner | latest completed main bootstrap proof green on `2b86de83` (`24743995049`); PR #1991 branch proof green on `878994d0c` (`24738471266`); newer bootstrap runs `24747538663` and `24748203836` are not closure evidence until completed green | `bootstrap-local-readiness.yml` green run + redacted artifact |
| P0 | Keep `build-optimizations.sh` as bounded J-exit layer | app repo | local contract green; prior Build Tutor Images proof green on `e7a4472cd` (`24711505579`) | `verify-build-optimizations-render-delta-contract.sh`, `test-verify-build-optimizations-render-delta-contract.sh` |
| P0 | Fix render preflight venv portability | CI | prior Build Tutor Images render preflight green on `e7a4472cd` (`24711505579`) | `verify-cicd-tutor-plugin-test.sh`, `tutor-plugin-test.yml` green |
| P0 | Correct app-vs-infra Kustomize ownership checks | app repo + infra repo boundary | local green; static CI proof should be checked when this surface changes | `verify-k8s-images.sh`, `verify-kustomize-structure.sh`, `verify-kustomize-render.sh`, `verify-network-policies.sh`, `verify-secrets-isolation.sh` |
| P0 | Remove app-repo live Velero patch authority | app repo docs/specs; infra repo owns CronJob realization | local green; runtime restore-drill proof registered as runtime inventory, not static CI | `verify-disaster-recovery.sh --skip-cluster`, generated DR testmap, spec lint, `verify-restore-drill.sh` runtime proof |
| P0 | Repair CI secret-scan harness truth | CI | local green; static CI proof should be checked when this surface changes | `verify-cicd-merge-gates-and-secrets.sh` |
| P0 | Repair secret classification and Paragon token verification drift | app repo | local green; static CI proof should be checked when this surface changes | `verify-secret-classification.sh`, `verify-paragon-tokens.sh` |
| P1 | Run app-cache-cold image-build proof | CI runner | accepted app-cache-cold proof green on `39ae0fb86` (`24721668598`) after dependency-image mirror normalization; this proves app-level cache imports disabled on a persistent runner, not pristine-daemon cold. Build Tutor Images rerun `24749060617` is separate current-main image-build proof and is still in progress. | `build-benchmark.yml` with `benchmark_class=app-cache-cold`, `image_family=both`; Build Tutor Images diagnostics artifact inspection |
| P1 | Gather dev feedback after guide update | humans | pending | one new developer follows guide without out-of-band steps |

## Ownership Boundary

- App repo owns local setup docs, setup scripts, source contract checks, and the GitHub workflow definition.
- Runner infrastructure owns self-hosted runner availability and Docker capacity.
- Local developer machines own host resource availability, but the guide must state the resource requirements plainly.

## Do Not Claim Closed Unless

- `./scripts/qa/verify-cold-start-onboarding-contract.sh` passes from repo root.
- `./scripts/infra/verify-local-bootstrap-readiness.sh` passes after setup.
- `.github/workflows/bootstrap-local-readiness.yml` completes green for the branch or merge commit.
- App-cache-cold image build proof is green for Open edX and MFE, or explicitly waived with fresh evidence explaining why bootstrap proof is sufficient for the change.
- Every verifier change in this lane is classified as an authority correction, obsolete expectation removal, temporary compatibility layer, or intentional architecture change. Unclassified verifier edits are merge blockers.
- `build-optimizations.sh` has no new mutation outside `infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml` and the remaining mutation ledger in `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`.
- The guide contains no missing internal links and no secret-like fixed local credentials.
- A new developer can follow the quick start without needing undocumented Slack/agent context.
- Future k8s preview and Devspace lanes consume `docker-bake.hcl`, Tutor source contracts, and the same verifier/catalog surfaces. A second Dockerfile generator, second image tag convention, or undocumented preview-only build path is a blocker.

## Transitional Debt Notes

- `scripts/qa/verify-setup.sh` is now a legacy user-facing verifier that delegates initialized-state truth to `verify-local-bootstrap-readiness.sh`; future work can retire duplicate checks once developer workflows stop referencing it.
- The bootstrap workflow proves `tutor local launch -I --skip-build` against rendered images. It does not prove local image build from empty cache; that proof belongs to `build-benchmark.yml` app-cache-cold runs.
- The benchmark workflow now has a no-cache proof target contract. If future edits reintroduce cache imports in the `app-cache-cold` lane or its legacy `true-cold` alias, `./scripts/qa/verify-cold-start-onboarding-contract.sh` and `./scripts/qa/verify-ci-cache-policy.sh` should fail.
- Benchmark measured-build jobs are fail-closed: an uploaded `benchmark-context-*.env` with `OUTCOME=failure` must also fail the workflow job. A green artifact upload after a failed build is diagnostic only and is not proof.
- `build-optimizations.sh` remains a controlled compatibility layer, not source authority. Current allowed deltas live in `infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml`; any growth without an updated authority class, retirement trigger, and fixture test is a regression.
- The heavy workflows cannot prove every host laptop has enough Docker resources, so host requirements stay explicit in docs.
- `mirror.gcr.io` is dependency acquisition for local/bootstrap/benchmark service, helper, frontend, and base images. Tutor-exposed refs should stay in Tutor config; hardcoded upstream Dockerfile refs must only be normalized by the named `dependency-image-mirrors.sh` compatibility patch with fixture coverage and a retirement trigger. It must not become a separate Dockerfile, Compose generator, or artifact semantics layer.
- Fastlane and ARC caches are acceleration layers only. GHCR registry cache, ARC PVC/cache state, and fastlane host-local cache may make builds faster, but they are not source authority and must not change artifact semantics.
- Bootstrap Local Readiness runs `24738471266` and `24743995049` spent most of
  their wall time inside `tutor local launch -I --skip-build` before readiness
  passed. That is acceptable proof evidence, but it needs better operator
  feedback. PR #1998 added `bootstrap-phase-timings.tsv`,
  `bootstrap-phase-summary.md`, and phase heartbeat notices to the same
  bootstrap artifact so long runs are diagnosable before completion.
- Post-merge bootstrap runs must be reported by exact run id and commit. A
  queued or in-progress run is not evidence; it only proves the workflow was
  dispatched and accepted by GitHub.
- Production/rke2 overlay proof moved out of this app-repo static lane. That proof belongs in `bbi-infrastructure` and must be reported separately as infra/runtime truth.
- `./scripts/qa/verify-multi-brand-site.sh` still fails on Caddy/domain coverage for public tenant hosts. That is domain routing debt outside this cold-start onboarding lane; do not hide it, but do not treat it as proof that local quick start is still broken.
