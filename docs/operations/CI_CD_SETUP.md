# CI/CD Setup Guide

**Last Updated:** 2026-02-03

## Overview

This repository uses GitHub Actions for CI/CD with the following workflows:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | PRs, push to main | Linting, validation, security scans |
| `build-tutor-images.yml` | Push to main (tutor changes), manual | Build and push OpenEdX/MFE images |
| `build-ios-app.yml` | Manual | Build iOS app for TestFlight |
| `cloud-sql-backup.yml` | Scheduled, manual | Database backups |

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
4. **Security Scan** - TruffleHog for leaked secrets, Hadolint for Dockerfiles

### Build Tutor Images (`build-tutor-images.yml`)

Triggered by:
- Push to main that modifies `infrastructure/tutor/**` or `assets/branding/**`
- Manual workflow dispatch

Options:
- `build_openedx` - Build LMS/CMS/worker image
- `build_mfe` - Build micro-frontends image
- `deploy_to_staging` - Auto-deploy after build (requires approval)
- `image_tag` - Custom tag (default: git SHA)

Images pushed to:
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:<tag>`
- `asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe:<tag>`

### Manual Deployment

After images are built, deploy manually:

```bash
TAG="your-tag-or-sha"

kubectl set image deployment/lms \
  lms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG} \
  -n mereka-lms

kubectl set image deployment/cms \
  cms=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx:${TAG} \
  -n mereka-lms

kubectl set image deployment/mfe \
  mfe=asia-southeast1-docker.pkg.dev/mereka-lms/openedx/mfe:${TAG} \
  -n mereka-lms
```

## Environments

### Staging

- **Protection:** None (auto-deploys)
- **URL:** https://academyv2.mereka.io
- **Cluster:** mereka-lms (GKE Autopilot)

### Production (Future)

- **Protection:** Required reviewers, wait timer
- **URL:** TBD
- **Cluster:** TBD

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
