# CI/CD Setup Guide

**Last Updated:** 2026-02-08

## Overview

This repository uses GitHub Actions for CI/CD with the following workflows:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PRs, push to main | Linting, validation, security scans |
| `build-tutor-images.yml` | Push to main (tutor changes), manual | Build and push OpenEdX/MFE images |
| `build-ios-app.yml` | Manual | Build iOS app for TestFlight |
| `cloud-sql-backup.yml` | Legacy, gated | Cloud SQL exports (only relevant if/when MySQL runs in Cloud SQL). Enable by setting repo variable `ENABLE_CLOUD_SQL_BACKUPS=true`. |
| `observability-audit.yml` | Daily schedule, manual | Runs observability audits and uploads JSON artifacts. |

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

### Build Tutor Images (`build-tutor-images.yml`)

Triggered by:
- Push to main that modifies `infrastructure/tutor/**` or `assets/branding/**`
- Manual workflow dispatch

Options:
- `build_openedx` - Build LMS/CMS/worker image
- `build_mfe` - Build micro-frontends image
- `update_gitops` - Update GitOps tags after build
- `target_environment` - GitOps target environment (`production` default, `staging` optional)
- `deploy_to_staging` - **Legacy input name** retained for backwards compatibility
- `image_tag` - Custom tag (default: git SHA)

Images pushed to:
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<tag>`
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe:<tag>`

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
```

Do not use direct `kubectl set image` for normal rollouts; production is ArgoCD/GitOps managed.

### On-demand Policy Checks

Use workflow `.github/workflows/policy-checks.yml` via `workflow_dispatch` to run:
- release automation contract checks
- build workflow contract checks
- release workflow invocation contract checks (`--target-env --apply --commit --push`)
- production tag guard (`no latest`)
- active docs env-model lint

For full operator flow, see:
- `docs/operations/RELEASE_CHECKLIST.md`

### Observability Audit (`observability-audit.yml`)

Runs:
- Daily (scheduled)
- Manually via workflow dispatch

What it does:
1. Runs `./scripts/qa/audit-observability.sh --mode local`
2. Runs runtime audit when `GCP_SA_KEY` is available
3. Uploads JSON artifacts (`observability-audit-local`, `observability-audit-runtime`)

Optional repo variables for runtime cluster access:
- `GKE_CLUSTER_PROJECT` (default: `bbi-k8`)
- `GKE_CLUSTER_LOCATION` (default: `asia-southeast1-c`)
- `GKE_CLUSTER_NAME` (default: `bbi-k8-cluster`)

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

1. Check GKE credentials: `gcloud container clusters get-credentials mereka-lms --region asia-southeast1`
2. Verify service account has `roles/container.developer`
3. Check pod events: `kubectl describe pod -n mereka-lms -l app.kubernetes.io/name=lms`
