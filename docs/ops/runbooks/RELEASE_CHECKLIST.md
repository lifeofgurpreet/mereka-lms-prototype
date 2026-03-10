# Open edX Release Checklist

<!-- Last verified: 2026-02-13 -->

Use this checklist for every `mereka-lms` release to production.

## 1. Preflight

- Ensure you are on `main` and clean:
  - `git status`
- Confirm target tags are immutable and final:
  - `OPENEDX_TAG=<tag>`
  - `MFE_TAG=<tag>`
- Confirm this repo and active GitOps repo (`BBI-K8`; legacy name `infrastructure`) are reachable from your environment.

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

## 3. Generate Evidence Bundle (Recommended)

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

## 4. Build and Push Images

Use `build-tutor-images.yml` (manual trigger) with:
- `build_openedx=true` (if backend/theme changed)
- `build_mfe=true` (if MFE changed)
- `update_gitops=false` (recommended if you want explicit manual promotion)
- `image_tag=<release-tag>`

If you want one workflow to update GitOps immediately:
- `update_gitops=true`
- `target_environment=production`
- `build_openedx=true` and `build_mfe=true` (required for digest capture)

Staging note:
- `target_environment=staging` is intentionally blocked unless repository variable `ENABLE_STAGING_ENV=true`.
- With current infrastructure constraints, use `production` for real rollouts and use dev/local for pre-prod validation.

## 5. GitOps Rollout (Canonical)

```bash
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --apply --commit --push --verify-runtime
```

By default, production release postflights now enforce strict runtime PARAGON theme contract checks
(`verify-paragon-runtime.sh --require-runtime`) against `https://apps.academyv2.mereka.io`.
Use `--paragon-runtime-url <origin>` to override; use `--skip-paragon-runtime-guard` only for controlled emergencies.

Branding/theme release option (requires Cloudflare credentials):

```bash
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
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
  --require-digests \
  --apply --commit --push --verify-runtime
```

Do not use direct `kubectl set image` for normal production rollouts.

## 6. Post-Release Verification (MANDATORY)

- Confirm Argo app and rollout:
  - `kubectl -n argocd get application mereka-lms-local`
  - `kubectl -n mereka-lms rollout status deployment/lms`
  - `kubectl -n mereka-lms rollout status deployment/cms`
  - `kubectl -n mereka-lms rollout status deployment/mfe`
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
