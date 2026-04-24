# Cold-start Onboarding Takeover Prompt - 2026-04-20

Status: active
Last verified: 2026-04-20

## Read First

1. `docs/status/active/COLD_START_ONBOARDING_PROOF_LANE_2026-04-20.md`
2. `README.md`
3. `docs/guides/onboarding/QUICK_START_LOCAL.md`
4. `scripts/shared/setup-local.sh`
5. `.github/workflows/bootstrap-local-readiness.yml`

## Immediate First Task

Confirm the branch has the latest local fixes, including the governed Docker Compose installer, bounded rendered-image pull retry, mirror-backed bootstrap dependency acquisition, dependency-image mirror normalization for known Tutor-emitted hardcoded Docker Hub refs, local setup image/service authority (`openedx:nightly`, `openedx-mfe:nightly`, `RUN_MONGODB=true`), multi-line config redaction, app/infra Kustomize ownership correction, GitOps-owned Velero repair boundary, Paragon tracked-core guard, secret classification cleanup, and TruffleHog manual-dispatch/fallback hardening. Then rerun the source checks from repo root if anything changed:

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
```

If these pass and no current-head proof lanes exist, push the branch and dispatch both proof lanes:

```bash
gh workflow run bootstrap-local-readiness.yml --ref fix/cold-start-onboarding-proof-20260420
gh run list --workflow bootstrap-local-readiness.yml --limit 5

gh workflow run build-benchmark.yml --ref fix/cold-start-onboarding-proof-20260420 \
  -f runner_class=arc-heavy \
  -f benchmark_class=app-cache-cold \
  -f image_family=both
```

If the fastlane selector is needed later and fails before measurement with `fallback-queue-full`, classify it as runner capacity. Do not call the fastlane benchmark green from an ARC run; treat ARC and fastlane as separate runner-class evidence over the same app-cache-cold build contract.

## Non-negotiable Rules

- Keep `repo_truth`, `infra_truth`, and `runtime_truth` separate.
- Do not call docs fixed unless the contract verifier passes.
- Do not call cold-start fixed unless a clean Tutor bootstrap proof is green.
- Do not call cold builds fixed unless app-cache-cold Open edX and MFE build proof is green, or the waiver is explicit and fresh. The legacy `benchmark_class=true-cold` alias is not a machine-cold clean-room claim and should not be used for new evidence.
- Do not grow `build-optimizations.sh` unless the change is classified and added to `build-optimizations.allowed-delta.yaml` plus the mutation ledger.
- Do not change verifier expectations without classifying the edit as an authority correction, obsolete expectation removal, temporary compatibility layer, or intentional architecture change.
- Do not reintroduce `apply-patches.sh` as a quick-start front door.
- Do not add fixed local passwords or hardcoded Tutor database credentials.
- Do not upload raw `tutor_env/config.yml` as CI evidence; it contains generated local secrets.
- Do not call `config.redacted.yml` safe unless multi-line secret continuation lines are suppressed.
- Do not reintroduce anonymous Docker Hub pulls for local/bootstrap service and helper images when the mirrored `mirror.gcr.io` refs are available.
- Do not let local setup build `openedx:nightly` / `openedx-mfe:nightly` without also pointing Tutor at those exact tags, applying the dependency-image mirror normalization patch, and selecting the BuildKit dependency-mirror builder as a fallback guard.
- Do not let the quick start touch live clusters or production sync paths.
- Do not create a new build strategy for Devspace or k8s preview. Those lanes must consume the same Tutor source contracts, `docker-bake.hcl`, helper scripts, image tags, caches, and verifier catalog.
- Do not treat fastlane or ARC cache state as authority. Caches may accelerate the canonical build path, but they cannot change the source -> render -> artifact chain.
- Do not accept a green benchmark job if its uploaded `benchmark-context-*.env` records `OUTCOME=failure`; that class of false-green is a proof-harness defect.

## Current Heads And Paths

- App repo branch: `fix/cold-start-onboarding-proof-20260420`
- Base head changes frequently; check with `git rev-parse --short origin/main` before merging or rebasing.
- Current pushed head: resolve with `gh pr view 1925 --json headRefOid --jq .headRefOid`.
- Current proof rule: ignore any GitHub run whose `headSha` does not equal the current PR `headRefOid`.
- Current truth: Tutor Plugin / Render Contract, Bootstrap Local Readiness, ARC Build Benchmark, and CI must all be rechecked against the current PR head after every amend/push.
- Current truth: Fastlane Build Benchmark run `24665878609` failed before measurement with `fallback-queue-full`. That is runner capacity, not build evidence.
- Current truth: bootstrap runs `24658314059` and `24659264126` failed because the runner lacked Docker Compose; run `24661010696` then failed on a transient registry pull reset during rendered image refresh. Rerun the workflow after the pinned Compose install and bounded image-pull retry commit lands.
- Current truth: bootstrap run `24661898414` reached `tutor local launch -I --skip-build` and failed during LMS migration because `infrastructure/tutor/plugins/_mereka_lms/lms_settings.py` referenced removed module `openedx.core.lib.api.throttle.ScopedRateThrottle`. Rerun after the DRF-owned `rest_framework.throttling.ScopedRateThrottle` fix lands.
- Current truth: bootstrap run `24675535840` on head `bf0233a73` failed before Tutor launch because `docker.io/mongo:7.0.28` hit Docker Hub anonymous pull rate limits. Rerun after the `mirror.gcr.io` dependency-acquisition fix lands.
- Current truth: artifact `bootstrap-readiness-24675535840-1` showed the old redactor leaked generated multi-line `JWT_RSA_PRIVATE_KEY` continuation lines after redacting the first key line. Rerun after the multi-line redaction fix lands.
- Current truth: run `24658449366` failed before measuring real builds because the benchmark harness omitted required helper args and used cache-importing bake targets for the nominal cold lane; rerun after the no-cache/app-cache-cold benchmark commit lands.
- Current truth: run `24661350400` was denied before measurement by fastlane queue capacity (`fallback-queue-full`). That is not build evidence; rerun when fastlane capacity is available or dispatch the separate `runner_class=arc-heavy` app-cache-cold proof.
- Current truth: run `24678695027` on head `15ecf6d35` exposed a benchmark proof-harness defect: the MFE measured-build job concluded success while its artifact recorded `OUTCOME=failure` after Docker Hub rate limiting on `docker.io/library/node:24.11.0-bullseye-slim` / `docker.io/library/caddy:2.7.4`. The run was canceled; rerun after measured-build fail-closed behavior and mirrored CI render prep land.
- Current truth: run `24680694038` on head `dfd1664bf` failed correctly after artifact upload, proving the measured-build fail-closed fix, but showed BuildKit `docker.io` registry mirror config alone still fell back to Docker Hub for hardcoded upstream Open edX/MFE dependency refs. Rerun after `dependency-image-mirrors.sh` lands and the render artifact shows the mirror refs.
- Current truth: PR CI run `24661889580` failed generated-surface validation because `verification/catalogs/*` did not include the new release-blocking verifiers, and failed workflow-script reference validation because `scripts/shared/setup-local.sh` was not executable. Rerun after regenerating the verification catalog and committing the executable bit.
- Current truth: PR CI runs `24660993310` and `24660995309` failed `Render Contract Preflight` because `tutor-plugin-test.yml` open-coded `python3 -m venv .ci-venv` on a runner without `ensurepip`; rerun after the isolated `setup-python-env` fix lands.
- Current truth: CI run `24669168383` on stale head `e5ea59c91` failed shard-03 because `scripts/qa/verify-restore-drill.sh` was active but unregistered. The fix registers it as runtime/live-cluster proof, regenerates `.github/ci-scripts-runtime.txt`, and updates the verification catalog.
- Primary files:
  - `README.md`
  - `docs/guides/onboarding/README.md`
  - `docs/guides/onboarding/QUICK_START_LOCAL.md`
  - `docs/guides/onboarding/LOCAL_SETUP.md`
  - `scripts/shared/setup-local.sh`
  - `scripts/qa/verify-setup.sh`
  - `scripts/qa/verify-cold-start-onboarding-contract.sh`
  - `.github/workflows/bootstrap-local-readiness.yml`
  - `.github/workflows/ci.yml`
  - `infrastructure/tutor/patches/build-optimizations.allowed-delta.yaml`
  - `docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md`
  - `docs/reference/contracts/DEVELOPER_ENVIRONMENT_PROOF_MATRIX.md`
  - `scripts/qa/verify-cicd-merge-gates-and-secrets.sh`

## Minimum Acceptable Success Before Stopping

- Source contract green.
- Bootstrap workflow contract green.
- Markdown onboarding links resolve.
- PR includes a clear note that runtime proof is pending until the heavy workflow completes.
- `verify-multi-brand-site.sh` domain/Caddy failures are tracked separately from cold-start onboarding proof.
- Any unrelated `.beads/**` worktree noise stays out of the commit.
