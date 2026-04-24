# Open edX Release Checklist
_Audience: Operators and developers • Owner: Platform Team • Last verified: 2026-04-09 • Status: active_

<!-- Last verified: 2026-04-09 -->

Use this checklist for every `mereka-lms` release to production.

> Canonical note: the release-object contract and promotion gates now live in
> [../../reference/operations/RELEASE_PROCESS.md](../../reference/operations/RELEASE_PROCESS.md).
> Treat this file as the execution checklist layered on top of that contract.

## 1. Preflight

- Ensure you are on `main` and clean:
  - `git status`
- Confirm target tags are immutable and final:
  - `OPENEDX_TAG=<tag>`
  - `MFE_TAG=<tag>`
- Confirm this repo and the active GitOps repo (`bbi-infrastructure`; historical names in older docs include `BBI-K8` and `infrastructure`) are reachable from your environment.

## 2. Run Policy Checks (Required)

Run the manual workflow:
- `.github/workflows/ci.yml` (dispatch from an issue/release branch workflow run)

Or run locally:
```bash
./scripts/qa/verify-release-automation.sh
./scripts/qa/verify-build-workflow-contract.sh
./scripts/qa/verify-release-workflow-invocation.sh
./scripts/qa/verify-release-dry-run-contract.sh
./scripts/qa/verify-no-latest-prod-tags.sh
./scripts/qa/lint-active-docs-env-model.sh
```

All checks must pass before release.

## 3. Generate Supplementary Release Evidence (Recommended)

Run `.github/workflows/release-evidence.yml` (`workflow_dispatch`) with:
- `openedx_tag`
- `mfe_tag`
- `target_environment`
- `require_runtime_theme` (`true` once PARAGON_THEME_URLS rollout is expected live)
- `runtime_theme_url` (optional override; empty uses environment default)
- `run_npm_start_smoke` (optional screenshot lane in the same evidence artifact)
- `learning_path` (optional route override for smoke)
- `npm_start_project` (`chromium`, `firefox`, or `mobile-chrome`)

Keep the uploaded artifact with release notes/change record.

This workflow is supplementary:

- canonical release identity still comes from the `build-tutor-images.yml` artifacts
  (`release-bundle`, `release-object`, `truth-ledger`, `build-provenance`)
- use `release-evidence.yml` for an attached review/audit bundle, not as the primary
  release identity source
- the tag-triggered `.github/workflows/release-evidence-bundle.yml` is a separate
  archival bundle workflow, not the operator preflight/evidence workflow described here

## 4. Build and Push Images

Use `build-tutor-images.yml` (manual trigger) with:
- `build_openedx=true` (if backend/theme changed)
- `build_mfe=true` (if MFE changed)
- `update_gitops=false` (recommended; keep build/proof separate from GitOps mutation)
- `image_tag=<release-tag>`

If you intentionally use the guarded manual bridge path inside the workflow:
- `update_gitops=true`
- `target_environment=production`
- `build_openedx=true` and `build_mfe=true` (required for digest capture)

Do not treat `update_gitops=true` as the default release path. The canonical operator flow is:
1. build/prove
2. generate or inspect release object
3. promote through `release-openedx-gitops.sh`

The bridge path exists for controlled exceptions only. Normal operator releases
should leave GitOps mutation to the explicit promotion command and evidence
bundle, not to the build workflow itself.

Staging note:
- `target_environment=staging` is intentionally blocked unless repository variable `ENABLE_STAGING_ENV=true`.
- With current infrastructure constraints, use `production` for real rollouts and use dev/local for pre-prod validation.

Interpretation rule:
- workflow `target_environment` selects the build-side release artifact context
- release-object `promotion_target_environment` stays empty until promotion evidence links the build to a real environment

Artifact capture rule:

```bash
RUN_ID="<build-tutor-images run id>"
gh run download "${RUN_ID}" --name release-bundle --dir "var/release-artifacts/${RUN_ID}"
gh run download "${RUN_ID}" --name build-provenance --dir "var/release-artifacts/${RUN_ID}"
```

Interpretation rule:
- `release-bundle` is the signed workflow bundle and already contains:
  - `var/ci/release-bundle.json`
  - `var/ci/release-object.json`
  - `var/ci/truth-ledger.json`
  - `var/ci/release-bundle.sig`
  - `var/ci/release-bundle.pem`
- `build-provenance` is the separate provenance/gate artifact and contains:
  - `var/ci/build-provenance.json`
  - `var/ci/release-gate-envelope.json`

Do not promote from tags alone when the workflow artifacts are available.

## 5. GitOps Rollout (Canonical)

```bash
RUN_ID="<build-tutor-images run id>"

./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --openedx-digest "sha256:<openedx-digest>" \
  --mfe-digest "sha256:<mfe-digest>" \
  --release-object-json "var/release-artifacts/${RUN_ID}/var/ci/release-object.json" \
  --require-digests \
  --apply --commit --push --verify-runtime
```

Production rule:
- use the workflow-emitted release object and immutable digests as the normal governed path
- do not treat the shorter tag-only form as the standard production invocation

By default, production release postflights now enforce strict runtime PARAGON theme contract checks
(`verify-paragon-runtime.sh --require-runtime`) against `https://apps.academyv2.mereka.io`.
Use `--paragon-runtime-url <origin>` to override; use `--skip-paragon-runtime-guard` only for controlled emergencies.

Branding/theme release option (requires Cloudflare credentials):

```bash
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --openedx-digest "sha256:<openedx-digest>" \
  --mfe-digest "sha256:<mfe-digest>" \
  --release-object-json "var/release-artifacts/${RUN_ID}/var/ci/release-object.json" \
  --require-digests \
  --apply --commit --push --verify-runtime \
  --purge-frontend-cache
```

Digest pinning (recommended when digests are available):

```bash
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --openedx-digest "sha256:<openedx-digest>" \
  --mfe-digest "sha256:<mfe-digest>" \
  --release-object-json "var/release-artifacts/${RUN_ID}/var/ci/release-object.json" \
  --require-digests \
  --apply --commit --push --verify-runtime
```

Do not use direct `kubectl set image` for normal production rollouts.

## 6. Post-Release Verification (MANDATORY)

- Confirm Argo app and rollout:
  - `ARGO_APP="${ARGO_APP:-mereka-lms-prod}"; kubectl -n argocd get applications.argoproj.io "${ARGO_APP}"`
  - `kubectl -n mereka-lms rollout status deployment/lms`
  - `kubectl -n mereka-lms rollout status deployment/cms`
  - `kubectl -n mereka-lms rollout status deployment/mfe`
- The release script auto-resolves the production Argo app. Current script preference is `mereka-lms-prod`, with `mereka-lms-local` as a continuity fallback if that is still the live app name in your lane.
- Run branding and health checks (**always**, not just UI releases):
  - `./scripts/branding/run-branding-gates.sh prod`
  - `./scripts/qa/public-health-check.sh prod`
  - Frontend closure lane:
    - local: `./scripts/qa/run-branding-evidence-pipeline.sh --env prod --frontend-only --cross-browser`
    - workflow: `.github/workflows/frontend-branding-closure.yml` (`workflow_dispatch`)
    - when runtime theme rollout is expected live, set:
      - `require_runtime_theme=true`
      - `run_runtime_theme_contract_gate=true`
  - NPM-start screenshot lane:
    - local: `./scripts/qa/verify-npm-start-mfe-smoke.sh --base-url https://academyv2.mereka.io --learning-path /learning`
    - workflow: `.github/workflows/npm-start-mfe-smoke.yml` (`workflow_dispatch`)
- Why mandatory: The 2026-02-10 incident showed that branding regressions can be silent
  (no pod crashes, no log errors). Only post-deploy branding verification catches them.
  See [ADR-012](../../adr/historical/012-no-runtime-css-overlay.md).

## 7. Observability and Parity Sign-off (MANDATORY)

Run the observability controls with strict evidence capture:

- `./scripts/qa/run-observability-first-class.sh --mode local --strict`
- `./scripts/qa/build-observability-parity-delta.sh --env dev --evidence-dir var/ci/parity-dev`
- `./scripts/qa/build-observability-parity-delta.sh --env nonprod --evidence-dir var/ci/parity-nonprod`
- `./scripts/qa/build-observability-parity-delta.sh --env prod --evidence-dir var/ci/parity-prod`
- `./scripts/qa/build-observability-parity-rollup.sh --artifacts-dir var/ci/parity-artifacts --out-md var/ci/observability-parity-rollup.md --out-json var/ci/observability-parity-rollup.json --require-no-skips`
- `./scripts/qa/verify-observability-evidence-identity.sh --dir var/ci`
- `./scripts/qa/verify-observability-evidence-identity.sh --dir var/ci/parity-dev`
- `./scripts/qa/verify-observability-evidence-identity.sh --dir var/ci/parity-nonprod`
- `./scripts/qa/verify-observability-evidence-identity.sh --dir var/ci/parity-prod`
- `./scripts/qa/test-observability-parity-contracts.sh`
- `./scripts/qa/build-observability-coverage-matrix.sh --mode runtime --strict --out-json var/ci/observability-coverage-runtime.json --out-md var/ci/observability-coverage-runtime.md`

### 7.1 Observability GA Gate

- `docs/policies/operations/OBSERVABILITY_GA_READINESS_GATE.md`
- Sign-off fields:
  - evidence bundle links are attached and complete
  - no open high-severity observability gaps
  - parity rollup trend stability shows `PAR-001`/`PAR-002` closed
  - alert ownership ack is recorded for all critical rule changes since prior release
  - one completed monthly operator drill in the last 30 days with attendance artifact

Store in release notes:
- link to `var/ci/observability-compliance-runtime.json`
- link to `var/ci/observability-correlation-headers-runtime.txt`
- link to `var/ci/observability-parity-rollup.json`
- local parity review artifacts from each environment (`observability-parity-review.md`)
- release owner and sign-off timestamp

Release does not pass if any of the above checks fails or if required evidence links are missing.

## 8. Rollback

If production is unhealthy:
1. Re-run release orchestrator with prior known-good tags.
2. Verify runtime convergence.
3. Document incident + root cause.

For the canonical rollback path and release-identity rules, read:
- [../../reference/operations/RELEASE_PROCESS.md](../../reference/operations/RELEASE_PROCESS.md)
- [emergency-rollback.md](emergency-rollback.md)

### Rollback Procedure

Use this when the current production rollout is unhealthy after promotion.

1. Identify the last known-good production release object / immutable tag pair.
2. Re-run `release-openedx-gitops.sh` with that prior release identity.
3. Wait for Argo/rollout convergence.
4. Re-run the same mandatory post-release verification lane.
5. Record the rollback reason and the exact reverted release identity.

### Time expectation

- target rollback completion: about 10 minutes once the prior known-good
  release identity is identified

### Minimum evidence

- prior known-good Open edX and MFE tags/digests
- rollback invocation transcript
- post-rollback rollout status
- post-rollback branding/health/runtime proof
