# CI/CD Setup Reference

<!-- Last verified: 2026-02-13 -->

**Last Updated:** 2026-02-08

## Overview

This reference records the current CI/CD workflows, required secrets, and environment expectations for this repository.

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PRs, push to main | Linting, validation, security scans |
| `build-tutor-images.yml` | Push to main (tutor changes), manual | Build and push OpenEdX/MFE images |
| `build-ios-app.yml` | Manual | Build iOS app for TestFlight |
| `cloud-sql-backup.yml` | Legacy, gated | Cloud SQL exports (only relevant if/when MySQL runs in Cloud SQL). Enable by setting repo variable `ENABLE_CLOUD_SQL_BACKUPS=true`. |
| `daily-infrastructure-audit.yml` | Daily schedule, manual | Consolidated observability + alert routing + env parity audits (merged from `observability-audit.yml`, `alert-routing-audit.yml`, `observability-parity-runtime.yml` in Phase 6.4). |
| `smoke-authenticated.yml` (`sso-canary` job) | Every 6h, manual | Credentialed OIDC login + post-login session checks (LMS, MFEs, Studio). |

## Required Secrets

Configure these in GitHub Settings → Secrets and variables → Actions:

| Secret | Description | How to Get |
|--------|-------------|------------|
| `GCP_SA_KEY` | GCP Service Account JSON key | See below |
| `APPLE_API_KEY_ID` | Apple App Store Connect API | Apple Developer Portal |
| `APPLE_API_ISSUER_ID` | Apple API Issuer ID | Apple Developer Portal |
| `APPLE_API_KEY_BASE64` | Apple API Key (base64 encoded) | Apple Developer Portal |
| `MATCH_PASSWORD` | Fastlane match encryption password | Generate with `openssl rand -base64 32` |
| `MATCH_GIT_PRIVATE_KEY` | SSH key for match certificates repo | `ssh-keygen -t ed25519` |
| `SSO_CANARY_EMAIL_PROD` | **Prod** canary user email for Authentik SSO | Infisical (`/shared/oauth`) |
| `SSO_CANARY_PASSWORD_PROD` | **Prod** canary user password for Authentik SSO | Infisical (`/shared/oauth`) |
| `SSO_CANARY_STUDIO_EMAIL_PROD` | **Optional (recommended)**: Prod Studio-access canary (staff) email | Infisical (`/shared/oauth`) |
| `SSO_CANARY_STUDIO_PASSWORD_PROD` | **Optional (recommended)**: Prod Studio-access canary (staff) password | Infisical (`/shared/oauth`) |
| `SSO_CANARY_EMAIL_DEV` | **Optional**: Dev canary user email for Authentik SSO | Infisical or operator-managed secret |
| `SSO_CANARY_PASSWORD_DEV` | **Optional**: Dev canary user password for Authentik SSO | Infisical or operator-managed secret |
| `SSO_CANARY_STUDIO_EMAIL_DEV` | **Optional**: Dev Studio-access canary (staff) email | Infisical or operator-managed secret |
| `SSO_CANARY_STUDIO_PASSWORD_DEV` | **Optional**: Dev Studio-access canary (staff) password | Infisical or operator-managed secret |
| `SSO_CANARY_EMAIL_STAGING` | **Optional**: Staging canary user email for Authentik SSO | Infisical or operator-managed secret |
| `SSO_CANARY_PASSWORD_STAGING` | **Optional**: Staging canary user password for Authentik SSO | Infisical or operator-managed secret |
| `SSO_CANARY_STUDIO_EMAIL_STAGING` | **Optional**: Staging Studio-access canary (staff) email | Infisical or operator-managed secret |
| `SSO_CANARY_STUDIO_PASSWORD_STAGING` | **Optional**: Staging Studio-access canary (staff) password | Infisical or operator-managed secret |

### Creating GCP Service Account Key

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions" \
  --project=mereka-lms

# Grant roles
gcloud projects add-iam-policy-binding mereka-lms \
  --member="serviceAccount:github-actions@mereka-lms.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"

gcloud projects add-iam-policy-binding mereka-lms \
  --member="serviceAccount:github-actions@mereka-lms.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding mereka-lms \
  --member="serviceAccount:github-actions@mereka-lms.iam.gserviceaccount.com" \
  --role="roles/monitoring.viewer"

gcloud projects add-iam-policy-binding mereka-lms \
  --member="serviceAccount:github-actions@mereka-lms.iam.gserviceaccount.com" \
  --role="roles/logging.viewer"

# Create key
gcloud iam service-accounts keys create github-actions-key.json \
  --iam-account=github-actions@mereka-lms.iam.gserviceaccount.com

# Copy contents to GCP_SA_KEY secret
cat github-actions-key.json

# Delete local key file after copying
rm github-actions-key.json
```

## Workflow Details

### CI Workflow (`ci.yml`)

Runs on every PR and push to main:

1. **Lint** - Python (ruff), YAML (yamllint), Shell (shellcheck)
2. **Validate K8s** - Kubernetes manifests with kubeconform
3. **Validate Tutor** - Config syntax, patch script syntax
4. **Monitoring Guardrails** - Local observability audit + offline monitoring plan artifact
5. **Security Scan** - TruffleHog for leaked secrets, Hadolint for Dockerfiles
6. **Branding Source Guard** - Includes Studio authoring selector check and token provenance lock
   via `RUN_LIVE_GATE=0 ./scripts/branding/run-branding-gates.sh prod`
7. **SITE_ID Hardening Guard** - Enforces env-driven `DJANGO_SITE_ID` wiring and multisite
   fallback logic in LMS/CMS production settings (`scripts/qa/verify-site-id-hardening.sh`)

### Build Tutor Images (`build-tutor-images.yml`)

Triggered by:
- Push to main that modifies `infrastructure/tutor/**` or `assets/branding/**`
- Manual workflow dispatch

Options:
- `build_openedx` - Build LMS/CMS/worker image
- `build_mfe` - Build micro-frontends image
- `update_gitops` - Update GitOps tags after build
- `target_environment` - GitOps target environment (`select-environment` default; must be explicitly selected when `update_gitops=true`)
- `deploy_to_staging` - **Legacy input name** retained for backwards compatibility
- `image_tag` - Custom tag (default: git SHA)

Staging safety gate:
- Manual `target_environment=staging` dispatch is blocked unless repository variable `ENABLE_STAGING_ENV=true`.
- Current operating model is `local/dev -> prod`, so leave `ENABLE_STAGING_ENV` unset until staging is actually provisioned.

Images pushed to:
- `ghcr.io/biji-biji-initiative/mereka-lms/openedx:<tag>`
- `ghcr.io/biji-biji-initiative/mereka-lms/mfe:<tag>`

Tag immutability:
- Workflow publishes only immutable tags (`<image_tag>` and short SHA).
- Workflow does **not** publish mutable `:latest` tags to Artifact Registry.
- Workflow resolves pushed image digests and exposes them as job outputs.

Release safety gates:
- Before MFE push, workflow runs `scripts/qa/verify-mfe-image-branding.sh tutor_local/openedx-mfe:latest <expected_rev>`.
- Gate fails if authn `index.html` references unbranded CSS or misses the expected revision marker.
- Verification log is uploaded as artifact: `mfe-branding-contract-log`.

### Deployment Flow (GitOps)

After images are built, deploy via GitOps orchestration:

```bash
TAG="your-tag-or-sha"

./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --apply --commit --push --verify-runtime

# Optional immutable digest pinning (recommended for production):
./scripts/infra/release-openedx-gitops.sh \
  --target-env production \
  --openedx-tag "${TAG}" \
  --mfe-tag "${TAG}" \
  --openedx-digest "sha256:<openedx-digest>" \
  --mfe-digest "sha256:<mfe-digest>" \
  --apply --commit --push --verify-runtime
```

Do not use direct `kubectl set image` for normal rollouts; production is ArgoCD/GitOps managed.

When using `build-tutor-images.yml` with `update_gitops=true`:
- Set both `build_openedx=true` and `build_mfe=true`.
- Workflow captures both digests and passes `--openedx-digest/--mfe-digest` automatically to the release orchestrator.

### On-demand Policy Checks

Use workflow `.github/workflows/docs-policy.yml` via `workflow_dispatch` to run:
- release automation contract checks
- build workflow contract checks
- release workflow invocation contract checks (`--target-env --apply --commit --push`, plus production runtime verify wiring)
- release dry-run contract check (`scripts/infra/release-openedx-gitops.sh` dry-run against fixture infra repo)
- release-evidence workflow contract check (digest resolution + strict dry-run flags)
- kustomize deprecation key guard (`patchesStrategicMerge/commonLabels/patchesJson6902`)
- dev/prod parity guard (image tags + namespace + replica target set + prod replica floor)
- SITE_ID hardening guard (no hardcoded production SITE_ID; multisite fallback present)
- production tag guard (`no latest`)
- active docs env-model lint

### Release Evidence Artifacts

Use workflow `.github/workflows/release-evidence.yml` via `workflow_dispatch` with:
- `openedx_tag`
- `mfe_tag`
- `target_environment`

This generates and uploads an artifact bundle containing:
- policy check logs
- dry-run rollout plan from `release-openedx-gitops.sh`
- resolved immutable digests for provided `openedx_tag`/`mfe_tag`
- release metadata JSON (run id, SHA, actor, tags, target env)

For full operator flow, see:
- `docs/ops/runbooks/RELEASE_CHECKLIST.md`

Digest strictness:
- Release invocations now support `--require-digests`.
- Use `--require-digests` to fail fast unless both `--openedx-digest` and `--mfe-digest` are provided.
- Additional safety gate: in CI, any `production` run with `--apply` fails if digests are missing.

### Daily Infrastructure Audit (`daily-infrastructure-audit.yml`)

> **Note**: This workflow consolidates three previously separate daily workflows:
> `observability-audit.yml`, `alert-routing-audit.yml`, and `observability-parity-runtime.yml`
> (merged in Phase 6.4 of the CI optimization plan). See `docs/status/active/CI_OPTIMIZATION_TRACKER.md`.

Runs:
- Daily (scheduled)
- Manually via workflow dispatch

What it does:
1. Runs `./scripts/qa/audit-observability.sh --mode local` (observability audit)
2. Runs runtime audit when `GCP_SA_KEY` is available
3. Uploads JSON artifacts (`observability-audit-local`, `observability-audit-runtime`)
4. Runs alert routing verification (`scripts/qa/verify-alert-routing.sh`)
5. Runs dev/nonprod/prod parity checks across all three environment lanes

Optional repo variables for runtime cluster access:
- `GKE_CLUSTER_PROJECT` (default: `bbi-k8`)
- `GKE_CLUSTER_LOCATION` (default: `asia-southeast1-c`)
- `GKE_CLUSTER_NAME` (default: `bbi-k8-cluster`)

Runtime IAM requirement:
- The GitHub Actions service account behind `GCP_SA_KEY` MUST have permission to fetch GKE credentials
  in `GKE_CLUSTER_PROJECT` (cluster project), not just in the `mereka-lms` project.
- Minimum required permission for `gcloud container clusters get-credentials ...` is `container.clusters.get`
  (and typically `container.clusters.getCredentials`), usually satisfied by granting:
  `roles/container.clusterViewer` (or broader `roles/container.developer`) on the cluster project.
- If runtime workflows fail with `code=403 ... Required "container.clusters.get"`, fix IAM first; the workflow
  will otherwise skip runtime gates when `strict_runtime=false`.

### Authenticated SSO Canary Wiring

The canary workflows intentionally run a **real, credentialed** Authentik login and then verify:
- LMS session is valid (`/api/user/v1/me` returns 200)
- MFEs do not loop back to `/authn/login` (common cookie / refresh endpoint regressions)
- Studio does not 500 during the LMS OAuth2 completion flow (`/complete/edx-oauth2/`)
- Optional: Studio `/home/` loads for a staff canary (hard regression guard)

Preferred wiring method (does not print secret values):
```bash
SSO_CANARY_EMAIL_PROD='user@example.com' \
SSO_CANARY_PASSWORD_PROD='***' \
SSO_CANARY_STUDIO_EMAIL_PROD='staff@example.com' \
SSO_CANARY_STUDIO_PASSWORD_PROD='***' \
SSO_CANARY_EMAIL_STAGING='staging-user@example.com' \
SSO_CANARY_PASSWORD_STAGING='***' \
SSO_CANARY_STUDIO_EMAIL_STAGING='staging-staff@example.com' \
SSO_CANARY_STUDIO_PASSWORD_STAGING='***' \
./scripts/infra/configure-github-authenticated-sso-canary.sh --enable-runtime-gate
```

### Public Health Workflow (`public-health-check.yml`)

Runs every 30 minutes and enforces branding/runtime parity:
- `STRICT_MFE_BRANDING_REV=1 AUDIT_STRICT=1 ./scripts/branding/run-branding-gates.sh prod`
- `AUDIT_STRICT=1 ./scripts/branding/run-branding-gates.sh dev`
- Includes microsite parity (`academy.biji-biji.com`, `skillourfuture.academy.mereka.io`,
  `apps.academy.biji-biji.com`, `studio.academy.biji-biji.com`) and Studio authoring selector checks.

Manual inputs:
- `mode`: `local`, `runtime`, or `all`
- `strict_runtime`: fail when runtime dependencies are unavailable **or** Velero cronjob freshness checks are stale
- `include_legacy`: include legacy Cloud SQL monitoring templates

## Environments

### Production (GKE)

- **Protection:** Required reviewers, wait timer
- **URL:** https://academyv2.mereka.io
- **Cluster:** bbi-k8 (GKE Autopilot)

### Development (VPS Kind)

- **Protection:** None (manual)
- **URL:** https://academyv2.mereka.dev
- **Cluster:** kind on VPS

## Troubleshooting

### Build Fails with OOM

The OpenEdX build requires significant memory. If builds fail:

1. Check if using GitHub-hosted runners (2-core, 7GB RAM)
2. Consider self-hosted runners with more memory
3. Build images locally and push manually

### Image Push Fails with 403

1. Verify `GCP_SA_KEY` secret is valid
2. Check service account has `roles/artifactregistry.writer`
3. Verify repository exists: `gcloud artifacts repositories list --project=mereka-lms`

### Deployment Fails

1. Check GKE credentials (prod): `gcloud container clusters get-credentials bbi-k8-cluster --zone asia-southeast1-c --project bbi-k8`
2. Verify the CI service account in `GCP_SA_KEY` has GKE access in the **cluster project** (default: `bbi-k8`)
   (recommended roles: `roles/container.clusterViewer` or `roles/container.developer`)
3. Check pod events: `kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=lms`

## Self-Hosted Runners (ARC)

The repository uses Actions Runner Controller (ARC) to provision ephemeral Kubernetes-native runners,
eliminating GitHub-hosted runner costs for scheduled and heavy workloads.

Two runner scale sets are defined:

| Label | Node size | Use for |
|-------|-----------|---------|
| `mereka-k8s-runners` | 2 CPU / 4 GB RAM | Linting, spec verification, cron audits, lightweight checks |
| `mereka-k8s-heavy-builders` | 4 CPU / 12 GB RAM + DinD sidecar | Image builds (Tutor/MFE), Playwright E2E, heavy compute |

ARC manifests live in `deploy/k8s/base/arc/`. They are applied standalone (not through the overlay)
because ARC uses its own namespaces (`arc-systems`, `arc-runners`) that must not be overridden by the
`mereka-lms` namespace transformer.

For full setup instructions (GitHub App creation, Helm install, PVC caching, security model, and
troubleshooting), see `docs/ops/ci-cd/CI_CD_RUNNERS.md`.

## See Also

- **Runner Setup (ARC)**: `docs/ops/ci-cd/CI_CD_RUNNERS.md`
- **Cost Monitoring**: `docs/reference/operations/GITHUB_ACTIONS_COST_MONITORING.md`
- **Cost Optimization Plan**: `reports/2026/learnings/CI_PIPELINE_COST_OPTIMIZATION.md`
- **Optimization Tracker**: `docs/status/active/CI_OPTIMIZATION_TRACKER.md`
