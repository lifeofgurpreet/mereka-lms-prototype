# Mereka Academy Open edX

[![CI](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/workflows/ci.yml/badge.svg)](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/workflows/ci.yml)
[![Tutor Config Verification](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/workflows/tutor-config-verify.yml/badge.svg)](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/workflows/tutor-config-verify.yml)
[![Tutor Plugin Tests](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/workflows/tutor-plugin-test.yml/badge.svg)](https://github.com/Biji-Biji-Initiative/mereka-lms/actions/workflows/tutor-plugin-test.yml)

This repository tracks the infrastructure-as-code, configuration, and runbooks for the Mereka Academy Open edX deployment. The goals are:

- provision a repeatable local sandbox using Tutor and the nightly Open edX release;
- operate production through GitOps-managed RKE2 infrastructure with clear local, source, and runtime proof boundaries;
- keep documentation and automation in sync with upstream Open edX updates.

> Prerequisite: configure Docker Desktop with at least **12 GB RAM** and **2 GB+ swap** (Settings -> Resources) before the first Open edX image build. The Ulmo asset pipeline freely uses 6-8 GB during webpack and will OOM if the daemon stays on the default 2 GB cap.

## Structure

- `docs/` – Documentation organized by category:
  - `guides/onboarding/` – Setup guides and getting started (start with [`docs/guides/onboarding/QUICK_START_LOCAL.md`](docs/guides/onboarding/QUICK_START_LOCAL.md))
  - `ops/` – Canonical operations runbooks and quick references
  - `operations/` – Compatibility transitional docs (canonical mirrors in `docs/ops/`)
  - `migrations/` – Migration playbooks for Kajabi and MCT
  - `architecture/` – Current platform authority maps and stable system model
  - `archive/reports/status/` – Status trackers and backlog (see [`docs/archive/reports/status/NEXT10_TASKS.md`](docs/archive/reports/status/NEXT10_TASKS.md))
- `infrastructure/` – Tutor and support infrastructure:
  - `tutor/` – Tutor plugin source, local config examples, and the governed render-prep compatibility layer
  - `terraform/` – Terraform modules and configs
  - `themes/` – Mereka branding themes
- `deploy/k8s/` – App-repo Kubernetes manifests and local/staging/production overlays
- `scripts/` – Automation scripts organized by domain:
  - `infra/` – Infrastructure operations (RKE2, Cloudflare, MongoDB, etc.)
  - `migrations/` – Data migration scripts (Kajabi, MCT)
  - `branding/` – Branding asset sync and theme helpers
  - `analytics/` – Analytics exports and reconciliation
  - `qa/` – Quality assurance and testing
- `services/` – Standalone microservices and webhooks
- `var/` – Runtime artifacts (gitignored): logs, exports, migration outputs

## Quick Start

For a new local sandbox, use the one-click setup from the repo root:

```bash
git clone git@github.com:Biji-Biji-Initiative/mereka-lms.git
cd mereka-lms
git submodule update --init --recursive
./scripts/qa/verify-cold-start-onboarding-contract.sh
./scripts/shared/setup-local.sh
./scripts/infra/verify-local-bootstrap-readiness.sh
```

For day-to-day work after the sandbox exists:

```bash
make bootstrap
make tutor-start
```

The source-level onboarding contract is [`scripts/qa/verify-cold-start-onboarding-contract.sh`](scripts/qa/verify-cold-start-onboarding-contract.sh).
The local setup path initializes required submodules, builds `openedx:nightly` and `openedx-mfe:nightly`, points Tutor at those exact tags, and pulls third-party service images through `mirror.gcr.io` to avoid anonymous Docker Hub quota during first-run setup.
The clean bootstrap proof lane is [`bootstrap-local-readiness.yml`](.github/workflows/bootstrap-local-readiness.yml), which launches a fresh repo-scoped Tutor environment and then runs [`scripts/infra/verify-local-bootstrap-readiness.sh`](scripts/infra/verify-local-bootstrap-readiness.sh). The image-build proof lane is [`build-benchmark.yml`](.github/workflows/build-benchmark.yml) with `benchmark_class=app-cache-cold` and `image_family=both`; that means app-level BuildKit cache imports are disabled, not that the persistent runner has a pristine Docker daemon or no base images.

For detailed setup instructions, see [`docs/guides/onboarding/QUICK_START_LOCAL.md`](docs/guides/onboarding/QUICK_START_LOCAL.md) and [`docs/guides/onboarding/LOCAL_SETUP.md`](docs/guides/onboarding/LOCAL_SETUP.md).

## Submodules

The official authentication micro-frontend, `frontend-app-authn`, is tracked as a Git submodule under `tmp/frontend-app-authn`. After cloning or pulling, run:

```bash
git submodule update --init --recursive
```

This ensures the login experience stays in sync with upstream Open edX changes. Treat changes inside the submodule as upstream contributions—commit them from within `tmp/frontend-app-authn` and push to its origin before updating the pointer in this repo (`git submodule update --remote` + commit).

## Container Images

Tutor now pulls most runtime images from GHCR (`ghcr.io/biji-biji-initiative/mereka-lms`):

| Service | Image | Notes |
|---------|-------|-------|
| LMS/CMS + workers | `openedx` | Built via `./scripts/infra/build-openedx-image.sh --local-defaults --build-profile fast`. |
| Micro-frontends | `openedx-mfe` | Built on the current Tutor/Ulmo Node 24 MFE toolchain. |
| Discovery | `openedx-discovery` | Uses in-cluster MySQL + in-cluster Elasticsearch. |
| Forum (cs_comments_service) | `openedx-forum` | Uses MongoDB Atlas (managed service). |
| Notes service | `openedx-notes` | Handles ORA notes. |
| **New:** Ecommerce web/worker | `openedx-ecommerce`, `openedx-ecommerce-worker` | Mirrored from Tutor 12.0.4. |
| **New:** XQueue | `openedx-xqueue` | Mirrored from Tutor 12.1.0. |

Remaining images (MySQL init job, Android builder, etc.) still come from the upstream Tutor repositories; mirror them later if we need tighter control.

## Automation

- **Makefile**: Common tasks (`make tutor-start`, `make tutor-apply`, `make branding-sync`, etc.)
- **Pre-commit hooks**: Automatic code formatting and linting
- **CI/CD**: `.github/workflows/public-health-check.yml` runs scheduled public checks + TLS SAN validation.
- **Backups**: production backups are Velero-driven (see `docs/ops/runbooks/VELERO_BACKUP_AUDIT.md`). The Cloud SQL export workflow is legacy and gated via `ENABLE_CLOUD_SQL_BACKUPS=true` (see `.github/workflows/cloud-sql-backup.yml`).

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for development workflow and code style guidelines.
