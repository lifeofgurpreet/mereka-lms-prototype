# Open edX Release Checklist

Use this checklist for every `mereka-lms` release to production.

## 1. Preflight

- Ensure you are on `main` and clean:
  - `git status`
- Confirm target tags are immutable and final:
  - `OPENEDX_TAG=<tag>`
  - `MFE_TAG=<tag>`
- Confirm this repo and `bbi-infrastructure` are reachable from your environment.

## 2. Run Policy Checks (Required)

Run the manual workflow:
- `.github/workflows/policy-checks.yml` (`workflow_dispatch`)

Or run locally:
```bash
./scripts/qa/verify-release-automation.sh
./scripts/qa/verify-build-workflow-contract.sh
./scripts/qa/verify-release-workflow-invocation.sh
./scripts/qa/verify-no-latest-prod-tags.sh
./scripts/qa/lint-active-docs-env-model.sh
```

All checks must pass before release.

## 3. Build and Push Images

Use `build-tutor-images.yml` (manual trigger) with:
- `build_openedx=true` (if backend/theme changed)
- `build_mfe=true` (if MFE changed)
- `update_gitops=false` (recommended if you want explicit manual promotion)
- `image_tag=<release-tag>`

If you want one workflow to update GitOps immediately:
- `update_gitops=true`
- `target_environment=production`

## 4. GitOps Rollout (Canonical)

```bash
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${OPENEDX_TAG}" \
  --mfe-tag "${MFE_TAG}" \
  --apply --commit --push --verify-runtime
```

Do not use direct `kubectl set image` for normal production rollouts.

## 5. Post-Release Verification

- Confirm Argo app and rollout:
  - `kubectl -n argocd get application mereka-lms-local`
  - `kubectl -n mereka-lms rollout status deployment/lms`
  - `kubectl -n mereka-lms rollout status deployment/cms`
  - `kubectl -n mereka-lms rollout status deployment/mfe`
- Run branding and health checks if release affects UI:
  - `./scripts/branding/run-branding-gates.sh prod`
  - `./scripts/qa/public-health-check.sh prod`

## 6. Rollback

If production is unhealthy:
1. Re-run release orchestrator with prior known-good tags.
2. Verify runtime convergence.
3. Document incident + root cause.
